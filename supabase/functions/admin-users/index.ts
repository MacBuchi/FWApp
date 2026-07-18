// admin-users – Edge Function für die Nutzerverwaltung (M7 Etappe 3).
//
// Nur Admins (profiles.role = 'admin') dürfen sie aufrufen; die Prüfung
// läuft über das mitgeschickte Nutzer-JWT gegen PostgREST (RLS „read own
// profile“). Alle privilegierten Operationen nutzen den Service-Role-Key,
// der NUR hier auf dem Server lebt (Env der edge-functions-Container).
//
// Bewusst ohne externe Imports (nur fetch): der Server hat kein
// IPv4-Internet, Modul-Downloads von esm.sh/npm wären ein Risiko.
//
// POST-Body: { "action": "...", ...parameter }
//   list                            → [{id, username, email, role, banned,
//                                       must_change_password, last_sign_in_at}]
//   create  {username, role, password}
//   reset   {user_id, password}     → setzt Initialpasswort + Pflichtwechsel
//   set_role{user_id, role}
//   disable {user_id} / enable {user_id}
//   delete  {user_id}
// Selbst-Schutz: eigene Rolle/Sperre/Löschung sind verboten.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const USERNAME_RE = /^[a-z0-9](?:[a-z0-9._-]{1,30})[a-z0-9]$/;
const EMAIL_DOMAIN = "fw.local";
const ROLES = ["admin", "geraetewart", "member"];

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

async function serviceFetch(path: string, init: RequestInit = {}) {
  return await fetch(`${SUPABASE_URL}${path}`, {
    ...init,
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
}

/// Wer ruft an? Rolle über PostgREST mit dem Nutzer-JWT (RLS: eigene Zeile).
async function callerInfo(
  req: Request,
): Promise<{ id: string; role: string } | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return null;
  const resp = await fetch(
    `${SUPABASE_URL}/rest/v1/profiles?select=id,role`,
    { headers: { apikey: ANON_KEY, Authorization: auth } },
  );
  if (!resp.ok) return null;
  const rows = await resp.json();
  if (!Array.isArray(rows) || rows.length !== 1) return null;
  return rows[0] as { id: string; role: string };
}

async function setProfile(
  userId: string,
  patch: Record<string, unknown>,
): Promise<void> {
  const resp = await serviceFetch(
    `/rest/v1/profiles?id=eq.${userId}`,
    { method: "PATCH", body: JSON.stringify(patch) },
  );
  if (!resp.ok) throw new Error(`Profil-Update fehlgeschlagen: ${resp.status}`);
}

async function listUsers(): Promise<unknown[]> {
  const [authResp, profResp] = await Promise.all([
    serviceFetch("/auth/v1/admin/users?per_page=200"),
    serviceFetch("/rest/v1/profiles?select=id,role,must_change_password"),
  ]);
  if (!authResp.ok) throw new Error(`Auth-Liste: ${authResp.status}`);
  if (!profResp.ok) throw new Error(`Profil-Liste: ${profResp.status}`);
  const users = (await authResp.json()).users ?? [];
  const profiles = new Map(
    (await profResp.json()).map((
      p: { id: string; role: string; must_change_password: boolean },
    ) => [p.id, p]),
  );
  return users.map((u: Record<string, unknown>) => {
    const email = (u.email as string) ?? "";
    const p = profiles.get(u.id as string) as
      | { role: string; must_change_password: boolean }
      | undefined;
    const bannedUntil = u.banned_until as string | undefined;
    return {
      id: u.id,
      email,
      username: email.endsWith(`@${EMAIL_DOMAIN}`)
        ? email.slice(0, -EMAIL_DOMAIN.length - 1)
        : email,
      role: p?.role ?? "member",
      must_change_password: p?.must_change_password ?? false,
      banned: bannedUntil != null && new Date(bannedUntil) > new Date(),
      last_sign_in_at: u.last_sign_in_at ?? null,
    };
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "POST erwartet" }, 405);

  const caller = await callerInfo(req);
  if (caller === null) return json({ error: "Nicht angemeldet" }, 401);
  if (caller.role !== "admin") {
    return json({ error: "Nur der Admin darf die Nutzerverwaltung nutzen" }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Ungültiger JSON-Body" }, 400);
  }
  const action = body.action as string;
  const userId = body.user_id as string | undefined;
  const self = userId === caller.id;

  try {
    switch (action) {
      case "list":
        return json({ users: await listUsers() });

      case "create": {
        const username = String(body.username ?? "").trim().toLowerCase();
        const role = String(body.role ?? "member");
        const password = String(body.password ?? "");
        if (!USERNAME_RE.test(username)) {
          return json({
            error:
              "Ungültiger Nutzername (3–32 Zeichen: a-z, 0-9, Punkt, _ , -)",
          }, 400);
        }
        if (!ROLES.includes(role)) return json({ error: "Ungültige Rolle" }, 400);
        if (password.length < 8) {
          return json({ error: "Passwort braucht mindestens 8 Zeichen" }, 400);
        }
        const resp = await serviceFetch("/auth/v1/admin/users", {
          method: "POST",
          body: JSON.stringify({
            email: `${username}@${EMAIL_DOMAIN}`,
            password,
            email_confirm: true,
          }),
        });
        const created = await resp.json();
        if (!resp.ok || !created.id) {
          const msg = created.msg ?? created.message ?? resp.status;
          return json({ error: `Anlegen fehlgeschlagen: ${msg}` }, 400);
        }
        await setProfile(created.id, { role, must_change_password: true });
        return json({ ok: true, id: created.id, username });
      }

      case "reset": {
        if (!userId) return json({ error: "user_id fehlt" }, 400);
        const password = String(body.password ?? "");
        if (password.length < 8) {
          return json({ error: "Passwort braucht mindestens 8 Zeichen" }, 400);
        }
        const resp = await serviceFetch(`/auth/v1/admin/users/${userId}`, {
          method: "PUT",
          body: JSON.stringify({ password }),
        });
        if (!resp.ok) return json({ error: `Reset: ${resp.status}` }, 400);
        await setProfile(userId, { must_change_password: true });
        return json({ ok: true });
      }

      case "set_role": {
        if (!userId) return json({ error: "user_id fehlt" }, 400);
        if (self) return json({ error: "Eigene Rolle nicht änderbar" }, 400);
        const role = String(body.role ?? "");
        if (!ROLES.includes(role)) return json({ error: "Ungültige Rolle" }, 400);
        await setProfile(userId, { role });
        return json({ ok: true });
      }

      case "disable":
      case "enable": {
        if (!userId) return json({ error: "user_id fehlt" }, 400);
        if (self) return json({ error: "Eigenes Konto nicht sperrbar" }, 400);
        const resp = await serviceFetch(`/auth/v1/admin/users/${userId}`, {
          method: "PUT",
          body: JSON.stringify({
            ban_duration: action === "disable" ? "87600h" : "none",
          }),
        });
        if (!resp.ok) return json({ error: `Sperren: ${resp.status}` }, 400);
        return json({ ok: true });
      }

      case "delete": {
        if (!userId) return json({ error: "user_id fehlt" }, 400);
        if (self) return json({ error: "Eigenes Konto nicht löschbar" }, 400);
        const resp = await serviceFetch(`/auth/v1/admin/users/${userId}`, {
          method: "DELETE",
        });
        if (!resp.ok) return json({ error: `Löschen: ${resp.status}` }, 400);
        return json({ ok: true });
      }

      default:
        return json({ error: `Unbekannte Aktion: ${action}` }, 400);
    }
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
