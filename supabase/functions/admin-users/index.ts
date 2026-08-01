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
//                                       must_change_password, last_sign_in_at,
//                                       abteilung_id}]
//   create  {username, role, password, abteilung_id?}
//   reset   {user_id, password}     → setzt Initialpasswort + Pflichtwechsel
//   set_role{user_id, role}
//   set_email {user_id, email}    → echte Adresse; sie WIRD die Anmeldung
//   clear_mfa {user_id}           → zweiten Faktor zurücksetzen (Telefon weg)
//   set_abteilung {user_id, abteilung_id}
//   disable {user_id} / enable {user_id}
//   delete  {user_id}
// Selbst-Schutz: eigene Rolle/Abteilung/Sperre/Löschung sind verboten.
//
// Mandanten-Schutz (Issue #57 Phase 3): Eine Abteilung darf nur zugewiesen
// werden, wenn sie zur Gesamtwehr des Aufrufers gehört — sonst könnte ein
// Admin Konten in eine fremde Gesamtwehr schieben und ihnen damit Lesezugriff
// auf fremde Bestände verschaffen. Die RLS auf `abteilungen` allein reicht
// dafür NICHT: Diese Function arbeitet mit dem Service-Role-Key, der RLS
// vollständig umgeht.

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
// Absichtlich grob: Die verbindliche Prüfung macht GoTrue beim Setzen. Hier
// geht es nur darum, offensichtlichen Unsinn vor dem Rundweg abzufangen.
const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]{2,}$/;
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

/// Welche Anmeldestufe hat der Aufrufer erreicht?
///
/// Der `aal`-Anspruch steht im JWT. Wir lesen ihn OHNE Signaturprüfung —
/// zulässig, weil callerInfo() das Token unmittelbar davor gegen PostgREST
/// verifiziert hat; ein gefälschtes Token käme dort nicht durch.
function aalOf(req: Request): string {
  const auth = req.headers.get("Authorization") ?? "";
  const teile = auth.replace("Bearer ", "").split(".");
  if (teile.length !== 3) return "aal1";
  try {
    const payload = JSON.parse(
      atob(teile[1].replace(/-/g, "+").replace(/_/g, "/")),
    );
    return String(payload.aal ?? "aal1");
  } catch {
    return "aal1";
  }
}

/// Hat dieses Konto einen bestätigten zweiten Faktor?
async function hatFaktor(userId: string): Promise<boolean> {
  const resp = await serviceFetch(`/auth/v1/admin/users/${userId}/factors`);
  if (!resp.ok) return false;
  const factors = await resp.json();
  return Array.isArray(factors) &&
    factors.some((f: { status?: string }) => f.status === "verified");
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

/// Heimat-Abteilung eines Kontos (null, wenn keine zugeordnet ist).
async function abteilungOf(userId: string): Promise<string | null> {
  const resp = await serviceFetch(
    `/rest/v1/profiles?select=abteilung_id&id=eq.${userId}`,
  );
  if (!resp.ok) return null;
  const rows = await resp.json();
  return Array.isArray(rows) && rows.length === 1
    ? (rows[0].abteilung_id as string | null)
    : null;
}

/// Darf `callerId` Konten in die Abteilung `target` legen? Erlaubt ist die
/// eigene Abteilung und jede Schwester derselben Gesamtwehr — genau der
/// Bereich, in dem der Admin laut `can_publish_abteilung` ohnehin arbeitet.
/// Eine Abteilung ohne Gesamtwehr steht für sich allein: dort darf nur, wer
/// selbst darin ist.
async function darfZuordnen(
  callerId: string,
  target: string,
): Promise<boolean> {
  const meine = await abteilungOf(callerId);
  if (meine === null) return false;
  if (meine === target) return true;

  const resp = await serviceFetch(
    `/rest/v1/abteilungen?select=id,gesamtwehr_id&id=in.(${meine},${target})`,
  );
  if (!resp.ok) return false;
  const rows = await resp.json() as { id: string; gesamtwehr_id: string | null }[];
  const eigene = rows.find((r) => r.id === meine);
  const ziel = rows.find((r) => r.id === target);
  // Zielabteilung muss existieren UND dieselbe (nicht-leere) Klammer haben.
  if (!eigene || !ziel) return false;
  return eigene.gesamtwehr_id !== null &&
    eigene.gesamtwehr_id === ziel.gesamtwehr_id;
}

async function listUsers(): Promise<unknown[]> {
  const [authResp, profResp] = await Promise.all([
    serviceFetch("/auth/v1/admin/users?per_page=200"),
    serviceFetch(
      "/rest/v1/profiles?select=id,role,must_change_password,abteilung_id,username",
    ),
  ]);
  if (!authResp.ok) throw new Error(`Auth-Liste: ${authResp.status}`);
  if (!profResp.ok) throw new Error(`Profil-Liste: ${profResp.status}`);
  const users = (await authResp.json()).users ?? [];
  const profiles = new Map(
    (await profResp.json()).map((
      p: {
        id: string;
        role: string;
        must_change_password: boolean;
        abteilung_id: string | null;
        username: string | null;
      },
    ) => [p.id, p]),
  );
  return users.map((u: Record<string, unknown>) => {
    const email = (u.email as string) ?? "";
    const p = profiles.get(u.id as string) as
      | {
        role: string;
        must_change_password: boolean;
        abteilung_id: string | null;
        username: string | null;
      }
      | undefined;
    const bannedUntil = u.banned_until as string | undefined;
    return {
      id: u.id,
      email,
      // Der Anzeigename steht seit Phase 4 im Profil, weil die Adresse auf
      // eine echte E-Mail wechseln kann. Die Ableitung bleibt als
      // Rückfallebene für Konten, die vor der Migration entstanden sind.
      username: p?.username ??
        (email.endsWith(`@${EMAIL_DOMAIN}`)
          ? email.slice(0, -EMAIL_DOMAIN.length - 1)
          : email),
      role: p?.role ?? "member",
      must_change_password: p?.must_change_password ?? false,
      banned: bannedUntil != null && new Date(bannedUntil) > new Date(),
      last_sign_in_at: u.last_sign_in_at ?? null,
      abteilung_id: p?.abteilung_id ?? null,
      // Ob ein zweiter Faktor aktiv ist, holt die Liste NICHT einzeln pro
      // Konto — das wären N zusätzliche Rundwege. Die Verwaltung fragt
      // stattdessen beim Zurücksetzen nach.
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
  // Zweiter Faktor eingerichtet? Dann gilt er auch hier. Bewusst NUR dann:
  // Eine harte aal2-Pflicht würde jeden Admin aussperren, der noch nicht
  // eingerichtet hat — und die Nutzerverwaltung ist genau der Ort, an dem
  // man sich dabei gegenseitig hilft. Die Frist erzwingt die App.
  if (await hatFaktor(caller.id) && aalOf(req) !== "aal2") {
    return json({
      error: "Bitte zuerst mit dem zweiten Faktor anmelden",
    }, 403);
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
        // Abteilung VOR dem Anlegen klären: Eine Absage danach würde ein
        // Auth-Konto ohne Profil-Zuordnung zurücklassen.
        // Ohne Angabe landet das Konto in der Abteilung des Anlegenden —
        // nicht in der Bestands-Abteilung, in die der DB-Trigger es sonst
        // legt. Wer aus Grombach heraus anlegt, meint Grombach.
        const gewuenschte = body.abteilung_id == null
          ? null
          : String(body.abteilung_id);
        if (
          gewuenschte !== null && !(await darfZuordnen(caller.id, gewuenschte))
        ) {
          return json({
            error: "Diese Abteilung gehört nicht zu deiner Gesamtwehr",
          }, 403);
        }
        const abteilung = gewuenschte ?? await abteilungOf(caller.id);

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
        await setProfile(created.id, {
          role,
          username,
          must_change_password: true,
          ...(abteilung !== null ? { abteilung_id: abteilung } : {}),
        });
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

      case "set_email": {
        // Echte Adresse für Admins und Gerätewarte (Issue #57 Phase 4):
        // Erst damit kann jemand sein Passwort selbst zurücksetzen — GoTrue
        // verschickt ausschließlich an die Adresse des Kontos.
        //
        // Folge, die der Aufrufer kennen muss: Die Adresse IST ab dann die
        // Anmeldung. Der Zettel-Name bleibt als Anzeigename im Profil
        // stehen, taugt aber nicht mehr zum Anmelden. Die App warnt davor.
        //
        // Bewusst auch für das eigene Konto erlaubt — anders als Rolle oder
        // Sperre ist das kein Weg, sich selbst auszusperren: Wer die Adresse
        // einträgt, kennt sie.
        if (!userId) return json({ error: "user_id fehlt" }, 400);
        const neu = String(body.email ?? "").trim().toLowerCase();
        if (!EMAIL_RE.test(neu)) {
          return json({ error: "Keine gültige E-Mail-Adresse" }, 400);
        }
        if (neu.endsWith(`@${EMAIL_DOMAIN}`)) {
          return json({
            error:
              `@${EMAIL_DOMAIN} ist die interne Zettel-Form — dorthin kann ` +
              `keine Mail zugestellt werden. Bitte eine echte Adresse.`,
          }, 400);
        }
        const resp = await serviceFetch(`/auth/v1/admin/users/${userId}`, {
          method: "PUT",
          // email_confirm: Der Admin trägt die Adresse bewusst ein; ein
          // Bestätigungsumweg würde das Konto bis zum Klick unbrauchbar
          // machen. Ob die Adresse wirklich erreichbar ist, zeigt die erste
          // Zugangsmail — die verschickt die App direkt danach.
          body: JSON.stringify({ email: neu, email_confirm: true }),
        });
        if (!resp.ok) {
          const fehler = await resp.json().catch(() => ({}));
          const msg = fehler.msg ?? fehler.message ?? resp.status;
          return json({ error: `Adresse setzen: ${msg}` }, 400);
        }
        return json({ ok: true, email: neu });
      }

      case "clear_mfa": {
        // Telefon verloren, App gelöscht, Gerät getauscht: Ohne diesen Weg
        // wäre ein Konto mit zweitem Faktor unrettbar. Bewusst NICHT für
        // das eigene Konto — wer selbst nicht mehr hineinkommt, kann diese
        // Funktion ohnehin nicht aufrufen; der Ausweg für den letzten Admin
        // steht in docs/SERVER-SETUP.md.
        if (!userId) return json({ error: "user_id fehlt" }, 400);
        if (self) {
          return json({
            error: "Eigenen Faktor nicht zurücksetzbar — das geht unter " +
              "Zwei-Faktor-Anmeldung selbst",
          }, 400);
        }
        const liste = await serviceFetch(
          `/auth/v1/admin/users/${userId}/factors`,
        );
        if (!liste.ok) return json({ error: `Faktoren: ${liste.status}` }, 400);
        const factors = await liste.json();
        let entfernt = 0;
        for (const f of (Array.isArray(factors) ? factors : [])) {
          const weg = await serviceFetch(
            `/auth/v1/admin/users/${userId}/factors/${f.id}`,
            { method: "DELETE" },
          );
          if (weg.ok) entfernt++;
        }
        return json({ ok: true, entfernt });
      }

      case "set_abteilung": {
        if (!userId) return json({ error: "user_id fehlt" }, 400);
        // Wie bei set_role: Wer sich selbst verschiebt, verliert womöglich
        // den Zugriff auf den Bestand, den er gerade verwaltet.
        if (self) return json({ error: "Eigene Abteilung nicht änderbar" }, 400);
        const target = String(body.abteilung_id ?? "");
        if (!target) return json({ error: "abteilung_id fehlt" }, 400);
        if (!(await darfZuordnen(caller.id, target))) {
          return json({
            error: "Diese Abteilung gehört nicht zu deiner Gesamtwehr",
          }, 403);
        }
        await setProfile(userId, { abteilung_id: target });
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
