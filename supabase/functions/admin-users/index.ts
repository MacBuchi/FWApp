// admin-users – Edge Function für die Nutzerverwaltung (M7 Etappe 3;
// Mitgliedschaften seit Nutzerkonzept Stufe 1, Issue #98).
//
// Aufrufen darf, wer VERWALTER ist: Feuerwehrkommandant (Zeile in
// gesamtwehr_kommandanten) oder Abteilungskommandant (admin-Mitgliedschaft).
// Die Prüfung läuft über das mitgeschickte Nutzer-JWT gegen PostgREST
// (RLS „eigene Zeilen"). Alle privilegierten Operationen nutzen den
// Service-Role-Key, der NUR hier auf dem Server lebt.
//
// Bewusst ohne externe Imports (nur fetch): der Server hat kein
// IPv4-Internet, Modul-Downloads von esm.sh/npm wären ein Risiko.
//
// POST-Body: { "action": "...", ...parameter }
//   list                              → [{id, username, email, role, banned,
//                                         must_change_password,
//                                         last_sign_in_at, abteilung_id,
//                                         memberships: [{abteilung_id, role}],
//                                         kommandant_gesamtwehren: [id]}]
//   create  {username, role, password, abteilung_id?}
//   reset   {user_id, password}       → Initialpasswort + Pflichtwechsel
//   set_membership    {user_id, abteilung_id, role}
//   remove_membership {user_id, abteilung_id}
//   set_kommandant    {user_id, gesamtwehr_id, kommandant: bool}
//   set_role      {user_id, role}          → Alt-App: Rolle der Heimat
//   set_abteilung {user_id, abteilung_id}  → Alt-App: Heimat verschieben
//   set_email {user_id, email}
//   clear_mfa {user_id}
//   disable {user_id} / enable {user_id}
//   delete  {user_id}
//   invite        {email, anzeigename?, abteilung_id, role, als_kommandant?}
//   invite_resend {einladung_id}
//   invite_revoke {einladung_id}
// Selbst-Schutz: eigene Rollen/Mitgliedschaften/Sperre/Löschung sind tabu.
//
// Rechte-Hierarchie (docs/NUTZERKONZEPT.md §2):
//   – Feuerwehrkommandant verwaltet alle Abteilungen seiner Gesamtwehr,
//     ernennt Abteilungskommandanten (role=admin) und Kommandanten.
//   – Abteilungskommandant verwaltet NUR seine Abteilung und vergibt dort
//     höchstens 'geraetewart'. Ausnahme: Eine Abteilung OHNE Gesamtwehr
//     verwaltet sich selbst — dort darf ihr Admin auch Admins ernennen,
//     sonst käme eine frische Installation nie zu einem zweiten.
//   – Wer Konto-Aktionen (reset/delete/…) auf einem Kommandanten ausführen
//     will, muss selbst Kommandant derselben Gesamtwehr sein.
//
// Mandanten-Schutz: Diese Function arbeitet mit dem Service-Role-Key, der
// RLS vollständig umgeht — jede Zuordnung wird deshalb HIER geprüft.
// AUSNAHME: die drei invite*-Aktionen. Deren Recht prüft die Datenbank
// (`darf_mitglieder_verwalten`), weil die Lese-Policy auf `einladungen`
// dieselbe Regel ohnehin in SQL braucht — sie ein zweites Mal hier zu
// prüfen hiesse, zwei Definitionen desselben Rechts zu pflegen. Diese
// Function ruft die RPCs deshalb mit dem JWT des Aufrufers und benutzt den
// Service-Key nur noch für das, was wirklich privilegiert ist: den
// Mailversand über GoTrue.
// Spiegel-Pflege: Nach jeder Mitgliedschafts-Änderung ruft sie
// sync_profile_mirror(), damit Alt-Clients (≤ v1.10.0) in profiles.role/
// abteilung_id weiter das Richtige lesen.

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

type Membership = { abteilung_id: string; role: string };
type Caller = { id: string; memberships: Membership[]; kommandant: string[] };

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

/// Wer ruft an? Identität plus Mitgliedschaften/Kommandanten-Zeilen über
/// PostgREST mit dem Nutzer-JWT (RLS: jeweils nur die eigenen Zeilen).
async function callerInfo(req: Request): Promise<Caller | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return null;
  const userHeaders = { apikey: ANON_KEY, Authorization: auth };
  const [profResp, memResp, komResp] = await Promise.all([
    fetch(`${SUPABASE_URL}/rest/v1/profiles?select=id`, {
      headers: userHeaders,
    }),
    fetch(`${SUPABASE_URL}/rest/v1/memberships?select=abteilung_id,role`, {
      headers: userHeaders,
    }),
    fetch(`${SUPABASE_URL}/rest/v1/gesamtwehr_kommandanten?select=gesamtwehr_id`, {
      headers: userHeaders,
    }),
  ]);
  if (!profResp.ok || !memResp.ok || !komResp.ok) return null;
  const rows = await profResp.json();
  if (!Array.isArray(rows) || rows.length !== 1) return null;
  const memberships = await memResp.json() as Membership[];
  const kommandant = (await komResp.json() as { gesamtwehr_id: string }[])
    .map((k) => k.gesamtwehr_id);
  return { id: rows[0].id as string, memberships, kommandant };
}

function istVerwalter(caller: Caller): boolean {
  return caller.kommandant.length > 0 ||
    caller.memberships.some((m) => m.role === "admin");
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

/// Alt-Client-Spiegel (profiles.role/abteilung_id) nachführen — nach JEDER
/// Mitgliedschafts- oder Kommandanten-Änderung.
async function spiegelNachfuehren(userId: string): Promise<void> {
  const resp = await serviceFetch(`/rest/v1/rpc/sync_profile_mirror`, {
    method: "POST",
    body: JSON.stringify({ target: userId }),
  });
  if (!resp.ok) throw new Error(`Spiegel-Update fehlgeschlagen: ${resp.status}`);
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

/// Gesamtwehr einer Abteilung (null = eigenständig oder unbekannt);
/// `exists` unterscheidet „eigenständig" von „gibt es gar nicht".
async function gesamtwehrOf(
  abteilungId: string,
): Promise<{ exists: boolean; gesamtwehrId: string | null }> {
  const resp = await serviceFetch(
    `/rest/v1/abteilungen?select=id,gesamtwehr_id&id=eq.${abteilungId}`,
  );
  if (!resp.ok) return { exists: false, gesamtwehrId: null };
  const rows = await resp.json() as { gesamtwehr_id: string | null }[];
  if (!Array.isArray(rows) || rows.length !== 1) {
    return { exists: false, gesamtwehrId: null };
  }
  return { exists: true, gesamtwehrId: rows[0].gesamtwehr_id };
}

/// Darf der Aufrufer in dieser Abteilung Nutzer verwalten?
/// `rolle` ist die Rolle, die vergeben werden soll (bei reinen
/// Konto-Aktionen null): 'admin' zu vergeben verlangt den Kommandanten —
/// außer die Abteilung ist eigenständig, dann verwaltet ihr Admin sie
/// selbst (sonst käme eine frische Installation nie zum zweiten Admin).
async function darfVerwalten(
  caller: Caller,
  abteilungId: string,
  rolle: string | null,
): Promise<boolean> {
  const { exists, gesamtwehrId } = await gesamtwehrOf(abteilungId);
  if (!exists) return false;
  if (gesamtwehrId !== null && caller.kommandant.includes(gesamtwehrId)) {
    return true;
  }
  const binAdminDort = caller.memberships.some(
    (m) => m.abteilung_id === abteilungId && m.role === "admin",
  );
  if (!binAdminDort) return false;
  // Abteilungskommandant: admin-Vergabe nur in der eigenständigen Abteilung.
  if (rolle === "admin") return gesamtwehrId === null;
  return true;
}

/// Konto-Aktionen (reset/delete/sperren/…): Ziel muss im Verwaltungsbereich
/// liegen, und einen Kommandanten fasst nur ein Kommandant derselben
/// Gesamtwehr an — sonst könnte der Abteilungskommandant seinen
/// Feuerwehrkommandanten löschen.
async function darfKonto(caller: Caller, userId: string): Promise<boolean> {
  const komResp = await serviceFetch(
    `/rest/v1/gesamtwehr_kommandanten?select=gesamtwehr_id&user_id=eq.${userId}`,
  );
  if (!komResp.ok) return false;
  const zielKommandant = (await komResp.json() as { gesamtwehr_id: string }[])
    .map((k) => k.gesamtwehr_id);
  if (zielKommandant.length > 0) {
    return zielKommandant.every((g) => caller.kommandant.includes(g));
  }
  const heimat = await abteilungOf(userId);
  // Konto ohne Abteilung: sichtbar und verwaltbar, damit es jemand aufräumt.
  if (heimat === null) return true;
  return await darfVerwalten(caller, heimat, null);
}

/// Ein Fehler, den die Datenbank geworfen hat (RAISE in einer RPC). Getrennt
/// vom Rest, weil er dem Aufrufer gehört (400) und nicht dem Server (500).
class RpcFehler extends Error {}

/// PostgREST-RPC mit dem JWT des AUFRUFERS statt mit dem Service-Key —
/// nur so greift die Rechteprüfung in der Funktion (auth.uid()).
async function rpcAlsAufrufer(
  req: Request,
  name: string,
  params: Record<string, unknown>,
): Promise<unknown> {
  const resp = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      apikey: ANON_KEY,
      Authorization: req.headers.get("Authorization") ?? "",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(params),
  });
  const text = await resp.text();
  if (!resp.ok) {
    let grund = text;
    try {
      grund = JSON.parse(text).message ?? text;
    } catch { /* kein JSON — dann eben der Klartext */ }
    throw new RpcFehler(grund);
  }
  return text.length > 0 ? JSON.parse(text) : null;
}

/// Die `raise`-Texte der Einladungs-RPCs in Sätze, die im Gerätehaus
/// weiterhelfen. Unbekanntes reicht der Aufrufer unverändert durch — eine
/// fremde Meldung ist immer noch besser als ein verwischtes „Fehler".
const RPC_TEXTE: Record<string, string> = {
  "permission denied": "Dazu fehlt dir das Recht.",
  "permission denied: feuerwehrkommandant required":
    "Einen Feuerwehrkommandanten ernennt nur ein Feuerwehrkommandant.",
  "invalid email": "Keine gültige E-Mail-Adresse.",
  "fw.local addresses cannot receive mail":
    `@${EMAIL_DOMAIN} ist die interne Zettel-Form — dorthin kann keine Mail ` +
    `zugestellt werden. Bitte eine echte Adresse.`,
  "invalid role": "Ungültige Rolle.",
  "account already exists":
    "Zu dieser Adresse gibt es schon ein Konto. Gib ihm stattdessen eine " +
    "Mitgliedschaft.",
  "invitation already open":
    "Für diese Adresse ist bereits eine Einladung offen.",
  "invitation not found": "Diese Einladung gibt es nicht mehr.",
  "invitation is not open":
    "Diese Einladung ist bereits angenommen oder zurückgezogen.",
  "invitation already accepted": "Diese Einladung wurde bereits angenommen.",
  "abteilung has no gesamtwehr":
    "Diese Abteilung gehört zu keiner Gesamtwehr.",
};

/// Rollenschlüssel → Anzeigename (docs/NUTZERKONZEPT.md §2). Steht hier und
/// nicht in SQL, weil es Text für die Mail ist und kein Recht.
const ROLLEN_TEXT: Record<string, string> = {
  admin: "Abteilungskommandant",
  geraetewart: "Gerätewart",
  member: "Truppführer",
};

/// Verschickt die Einladungsmail zu einer bestehenden Einladungszeile.
/// Dient dem ersten Versand UND dem erneuten: GoTrue lädt eine noch
/// unbestätigte Adresse erneut ein und erzeugt dabei einen frischen Code
/// (am lokalen Stack geprüft, bevor diese Aktion entstand).
async function einladungVersenden(
  req: Request,
  einladungId: string,
): Promise<void> {
  const zeilen = await rpcAlsAufrufer(req, "einladung_versanddaten", {
    ziel: einladungId,
  }) as {
    email: string;
    anzeigename: string | null;
    role: string;
    als_kommandant: boolean;
    abteilung: string;
    wehr: string | null;
  }[];
  if (!Array.isArray(zeilen) || zeilen.length !== 1) {
    throw new RpcFehler("invitation not found");
  }
  const e = zeilen[0];
  const resp = await serviceFetch("/auth/v1/invite", {
    method: "POST",
    body: JSON.stringify({
      email: e.email,
      // NUR für den Mailtext (web/mail/invite.html). Welche Rolle jemand
      // wirklich bekommt, steht in `einladungen` — Metadaten darf der
      // Eingeladene bei eingeschalteter Selbstregistrierung selbst setzen.
      data: {
        wehr: e.wehr ?? "deiner Feuerwehr",
        abteilung: e.abteilung,
        rolle: e.als_kommandant
          ? "Feuerwehrkommandant"
          : (ROLLEN_TEXT[e.role] ?? e.role),
      },
    }),
  });
  const angelegt = await resp.json().catch(() => ({}));
  if (!resp.ok) {
    const msg = angelegt.msg ?? angelegt.message ?? resp.status;
    throw new Error(`Einladung konnte nicht verschickt werden: ${msg}`);
  }
  if (angelegt.id) {
    // Das (noch unbestätigte) Konto an der Einladung vermerken — beim
    // Zurückziehen wird genau dieses wieder entfernt.
    await serviceFetch("/rest/v1/rpc/einladung_konto_vermerken", {
      method: "POST",
      body: JSON.stringify({ ziel: einladungId, konto: angelegt.id }),
    });
  }
}

async function upsertMembership(
  userId: string,
  abteilungId: string,
  role: string,
): Promise<void> {
  const resp = await serviceFetch(
    `/rest/v1/memberships?on_conflict=user_id,abteilung_id`,
    {
      method: "POST",
      headers: { Prefer: "resolution=merge-duplicates" },
      body: JSON.stringify([
        { user_id: userId, abteilung_id: abteilungId, role },
      ]),
    },
  );
  if (!resp.ok) {
    throw new Error(`Mitgliedschaft speichern fehlgeschlagen: ${resp.status}`);
  }
}

async function listUsers(caller: Caller): Promise<unknown[]> {
  const [authResp, profResp, memResp, komResp, abtResp] = await Promise.all([
    serviceFetch("/auth/v1/admin/users?per_page=200"),
    serviceFetch(
      "/rest/v1/profiles?select=id,role,must_change_password,abteilung_id,username,anzeigename,avatar",
    ),
    serviceFetch("/rest/v1/memberships?select=user_id,abteilung_id,role"),
    serviceFetch("/rest/v1/gesamtwehr_kommandanten?select=user_id,gesamtwehr_id"),
    serviceFetch("/rest/v1/abteilungen?select=id,gesamtwehr_id"),
  ]);
  for (const [name, r] of [
    ["Auth-Liste", authResp],
    ["Profil-Liste", profResp],
    ["Mitgliedschaften", memResp],
    ["Kommandanten", komResp],
    ["Abteilungen", abtResp],
  ] as [string, Response][]) {
    if (!r.ok) throw new Error(`${name}: ${r.status}`);
  }
  const users = (await authResp.json()).users ?? [];
  const profiles = new Map(
    (await profResp.json()).map((
      p: {
        id: string;
        role: string;
        must_change_password: boolean;
        abteilung_id: string | null;
        username: string | null;
        anzeigename: string | null;
        avatar: string | null;
      },
    ) => [p.id, p]),
  );
  const membershipsByUser = new Map<string, Membership[]>();
  for (
    const m of await memResp.json() as
      ({ user_id: string } & Membership)[]
  ) {
    const list = membershipsByUser.get(m.user_id) ?? [];
    list.push({ abteilung_id: m.abteilung_id, role: m.role });
    membershipsByUser.set(m.user_id, list);
  }
  const kommandantByUser = new Map<string, string[]>();
  for (
    const k of await komResp.json() as
      { user_id: string; gesamtwehr_id: string }[]
  ) {
    const list = kommandantByUser.get(k.user_id) ?? [];
    list.push(k.gesamtwehr_id);
    kommandantByUser.set(k.user_id, list);
  }
  const gesamtwehrVon = new Map(
    (await abtResp.json() as { id: string; gesamtwehr_id: string | null }[])
      .map((a) => [a.id, a.gesamtwehr_id]),
  );

  // Sichtbarkeit: die Abteilungen, die der Aufrufer verwaltet — als
  // Kommandant seine Gesamtwehren, als Abteilungskommandant seine
  // Abteilungen. Konten ganz ohne Mitgliedschaft bleiben sichtbar, damit
  // sie jemand aufräumen kann; fremde Gesamtwehren bleiben draußen.
  const sichtbar = (userId: string): boolean => {
    const mems = membershipsByUser.get(userId) ?? [];
    if (mems.length === 0 && (kommandantByUser.get(userId) ?? []).length === 0) {
      return true;
    }
    for (const g of kommandantByUser.get(userId) ?? []) {
      if (caller.kommandant.includes(g)) return true;
    }
    for (const m of mems) {
      const g = gesamtwehrVon.get(m.abteilung_id) ?? null;
      if (g !== null && caller.kommandant.includes(g)) return true;
      if (
        caller.memberships.some(
          (cm) => cm.abteilung_id === m.abteilung_id && cm.role === "admin",
        )
      ) {
        return true;
      }
    }
    return false;
  };

  return users
    // Eingeladen, aber noch nicht angenommen: Diese Konten stehen in der
    // Einladungsliste und gehören nicht in die Kontoliste — sie haben weder
    // Rolle noch Abteilung und wären dort nur eine Zeile, die niemand
    // einordnen kann.
    .filter((u: Record<string, unknown>) =>
      !(u.invited_at != null && u.email_confirmed_at == null)
    )
    .filter((u: Record<string, unknown>) => sichtbar(u.id as string))
    .map((u: Record<string, unknown>) => {
      const email = (u.email as string) ?? "";
      const p = profiles.get(u.id as string) as
        | {
          role: string;
          must_change_password: boolean;
          abteilung_id: string | null;
          username: string | null;
          anzeigename: string | null;
          avatar: string | null;
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
        // role/abteilung_id = Alt-Client-Spiegel; die Wahrheit steht in
        // memberships/kommandant_gesamtwehren daneben.
        role: p?.role ?? "member",
        must_change_password: p?.must_change_password ?? false,
        banned: bannedUntil != null && new Date(bannedUntil) > new Date(),
        last_sign_in_at: u.last_sign_in_at ?? null,
        abteilung_id: p?.abteilung_id ?? null,
        // Selbst gewählt (Issue #100), deshalb hier nur mitgelesen: Setzen
        // kann sie ausschliesslich das Konto selbst über mein_profil_setzen.
        anzeigename: p?.anzeigename ?? null,
        avatar: p?.avatar ?? null,
        memberships: membershipsByUser.get(u.id as string) ?? [],
        kommandant_gesamtwehren: kommandantByUser.get(u.id as string) ?? [],
      };
    });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "POST erwartet" }, 405);

  const caller = await callerInfo(req);
  if (caller === null) return json({ error: "Nicht angemeldet" }, 401);
  if (!istVerwalter(caller)) {
    return json({
      error: "Nur Kommandanten dürfen die Nutzerverwaltung nutzen",
    }, 403);
  }
  // Zweiter Faktor eingerichtet? Dann gilt er auch hier. Bewusst NUR dann:
  // Eine harte aal2-Pflicht würde jeden aussperren, der noch nicht
  // eingerichtet hat — und die Nutzerverwaltung ist genau der Ort, an dem
  // man sich dabei gegenseitig hilft.
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
        return json({ users: await listUsers(caller) });

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
        // Auth-Konto ohne Zuordnung zurücklassen. Ohne Angabe landet das
        // Konto in der Heimat-Abteilung des Anlegenden.
        const abteilung = body.abteilung_id == null
          ? await abteilungOf(caller.id)
          : String(body.abteilung_id);
        if (abteilung === null) {
          return json({ error: "Keine Abteilung bestimmbar" }, 400);
        }
        if (!(await darfVerwalten(caller, abteilung, role))) {
          return json({
            error: "Diese Rolle darfst du in dieser Abteilung nicht vergeben",
          }, 403);
        }

        const resp = await serviceFetch("/auth/v1/admin/users", {
          method: "POST",
          body: JSON.stringify({
            email: `${username}@${EMAIL_DOMAIN}`,
            password,
            email_confirm: true,
            // Der DB-Trigger legt Profil UND member-Mitgliedschaft in
            // dieser Abteilung an; die Rolle heben wir gleich darunter.
            user_metadata: { abteilung_id: abteilung },
          }),
        });
        const created = await resp.json();
        if (!resp.ok || !created.id) {
          const msg = created.msg ?? created.message ?? resp.status;
          return json({ error: `Anlegen fehlgeschlagen: ${msg}` }, 400);
        }
        await upsertMembership(created.id, abteilung, role);
        await setProfile(created.id, {
          username,
          must_change_password: true,
        });
        await spiegelNachfuehren(created.id);
        return json({ ok: true, id: created.id, username });
      }

      case "reset": {
        if (!userId) return json({ error: "user_id fehlt" }, 400);
        if (!(await darfKonto(caller, userId))) {
          return json({ error: "Dieses Konto verwaltest du nicht" }, 403);
        }
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

      case "set_membership": {
        if (!userId) return json({ error: "user_id fehlt" }, 400);
        if (self) {
          return json({ error: "Eigene Rollen nicht änderbar" }, 400);
        }
        const role = String(body.role ?? "");
        const abteilung = String(body.abteilung_id ?? "");
        if (!ROLES.includes(role)) return json({ error: "Ungültige Rolle" }, 400);
        if (!abteilung) return json({ error: "abteilung_id fehlt" }, 400);
        if (!(await darfVerwalten(caller, abteilung, role))) {
          return json({
            error: "Diese Rolle darfst du in dieser Abteilung nicht vergeben",
          }, 403);
        }
        await upsertMembership(userId, abteilung, role);
        await spiegelNachfuehren(userId);
        return json({ ok: true });
      }

      case "remove_membership": {
        if (!userId) return json({ error: "user_id fehlt" }, 400);
        if (self) {
          return json({ error: "Eigene Mitgliedschaft nicht entfernbar" }, 400);
        }
        const abteilung = String(body.abteilung_id ?? "");
        if (!abteilung) return json({ error: "abteilung_id fehlt" }, 400);
        if (!(await darfVerwalten(caller, abteilung, null))) {
          return json({ error: "Diese Abteilung verwaltest du nicht" }, 403);
        }
        const resp = await serviceFetch(
          `/rest/v1/memberships?user_id=eq.${userId}&abteilung_id=eq.${abteilung}`,
          { method: "DELETE" },
        );
        if (!resp.ok) return json({ error: `Entfernen: ${resp.status}` }, 400);
        await spiegelNachfuehren(userId);
        return json({ ok: true });
      }

      case "set_kommandant": {
        if (!userId) return json({ error: "user_id fehlt" }, 400);
        if (self) {
          return json({ error: "Eigenes Kommando nicht änderbar" }, 400);
        }
        const gesamtwehr = String(body.gesamtwehr_id ?? "");
        const ernennen = body.kommandant === true;
        if (!gesamtwehr) return json({ error: "gesamtwehr_id fehlt" }, 400);
        if (!caller.kommandant.includes(gesamtwehr)) {
          return json({
            error: "Nur der Feuerwehrkommandant dieser Gesamtwehr darf das",
          }, 403);
        }
        if (ernennen) {
          const resp = await serviceFetch(
            `/rest/v1/gesamtwehr_kommandanten?on_conflict=user_id,gesamtwehr_id`,
            {
              method: "POST",
              headers: { Prefer: "resolution=merge-duplicates" },
              body: JSON.stringify([
                { user_id: userId, gesamtwehr_id: gesamtwehr },
              ]),
            },
          );
          if (!resp.ok) return json({ error: `Ernennen: ${resp.status}` }, 400);
        } else {
          const resp = await serviceFetch(
            `/rest/v1/gesamtwehr_kommandanten?user_id=eq.${userId}&gesamtwehr_id=eq.${gesamtwehr}`,
            { method: "DELETE" },
          );
          if (!resp.ok) return json({ error: `Entlassen: ${resp.status}` }, 400);
        }
        await spiegelNachfuehren(userId);
        return json({ ok: true });
      }

      case "set_role": {
        // Alt-App-Weg (≤ v1.10.0): Rolle galt global — heute heißt das:
        // Rolle der Heimat-Abteilung.
        if (!userId) return json({ error: "user_id fehlt" }, 400);
        if (self) return json({ error: "Eigene Rolle nicht änderbar" }, 400);
        const role = String(body.role ?? "");
        if (!ROLES.includes(role)) return json({ error: "Ungültige Rolle" }, 400);
        const heimat = await abteilungOf(userId);
        if (heimat === null) {
          return json({ error: "Konto hat keine Abteilung" }, 400);
        }
        if (!(await darfVerwalten(caller, heimat, role))) {
          return json({
            error: "Diese Rolle darfst du in dieser Abteilung nicht vergeben",
          }, 403);
        }
        await upsertMembership(userId, heimat, role);
        await spiegelNachfuehren(userId);
        return json({ ok: true });
      }

      case "set_abteilung": {
        // Alt-App-Weg (≤ v1.10.0): genau eine Abteilung pro Konto — die
        // Verschiebung nimmt die bisherige Mitgliedschaft mit.
        if (!userId) return json({ error: "user_id fehlt" }, 400);
        if (self) return json({ error: "Eigene Abteilung nicht änderbar" }, 400);
        const target = String(body.abteilung_id ?? "");
        if (!target) return json({ error: "abteilung_id fehlt" }, 400);
        const heimat = await abteilungOf(userId);
        const memResp = await serviceFetch(
          `/rest/v1/memberships?select=role&user_id=eq.${userId}&abteilung_id=eq.${heimat}`,
        );
        const heimatRollen = memResp.ok
          ? await memResp.json() as { role: string }[]
          : [];
        const rolle = heimatRollen.length === 1 ? heimatRollen[0].role : "member";
        if (!(await darfVerwalten(caller, target, rolle))) {
          return json({
            error: "Diese Abteilung gehört nicht zu deinem Verwaltungsbereich",
          }, 403);
        }
        await upsertMembership(userId, target, rolle);
        if (heimat !== null && heimat !== target) {
          await serviceFetch(
            `/rest/v1/memberships?user_id=eq.${userId}&abteilung_id=eq.${heimat}`,
            { method: "DELETE" },
          );
        }
        await setProfile(userId, { abteilung_id: target });
        await spiegelNachfuehren(userId);
        return json({ ok: true });
      }

      case "set_email": {
        // Echte Adresse für Verwalter und Gerätewarte (Issue #57 Phase 4):
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
        if (!self && !(await darfKonto(caller, userId))) {
          return json({ error: "Dieses Konto verwaltest du nicht" }, 403);
        }
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
          // email_confirm: Der Verwalter trägt die Adresse bewusst ein; ein
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
        // Funktion ohnehin nicht aufrufen; der Ausweg für den letzten
        // Verwalter steht in docs/SERVER-SETUP.md.
        if (!userId) return json({ error: "user_id fehlt" }, 400);
        if (self) {
          return json({
            error: "Eigenen Faktor nicht zurücksetzbar — das geht unter " +
              "Zwei-Faktor-Anmeldung selbst",
          }, 400);
        }
        if (!(await darfKonto(caller, userId))) {
          return json({ error: "Dieses Konto verwaltest du nicht" }, 403);
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

      case "disable":
      case "enable": {
        if (!userId) return json({ error: "user_id fehlt" }, 400);
        if (self) return json({ error: "Eigenes Konto nicht sperrbar" }, 400);
        if (!(await darfKonto(caller, userId))) {
          return json({ error: "Dieses Konto verwaltest du nicht" }, 403);
        }
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
        if (!(await darfKonto(caller, userId))) {
          return json({ error: "Dieses Konto verwaltest du nicht" }, 403);
        }
        const resp = await serviceFetch(`/auth/v1/admin/users/${userId}`, {
          method: "DELETE",
        });
        if (!resp.ok) return json({ error: `Löschen: ${resp.status}` }, 400);
        return json({ ok: true });
      }

      case "invite": {
        // Rechteprüfung macht die RPC (siehe Kopf). Hier nur die
        // Vorprüfungen, die einen Rundweg sparen.
        const abteilung = String(body.abteilung_id ?? "");
        const role = String(body.role ?? "member");
        if (!abteilung) return json({ error: "abteilung_id fehlt" }, 400);
        if (!ROLES.includes(role)) return json({ error: "Ungültige Rolle" }, 400);
        const neu = await rpcAlsAufrufer(req, "einladung_anlegen", {
          adresse: String(body.email ?? ""),
          name: body.anzeigename == null ? null : String(body.anzeigename),
          abteilung,
          rolle: role,
          kommandant: body.als_kommandant === true,
        }) as string;
        try {
          await einladungVersenden(req, neu);
        } catch (e) {
          // Kein Versand, keine Einladung. Sonst bliebe eine Zeile stehen,
          // die niemand annehmen kann — und der Eindeutigkeits-Index
          // sperrte die Adresse für jeden weiteren Versuch.
          await rpcAlsAufrufer(req, "einladung_zurueckziehen", { ziel: neu })
            .catch(() => {});
          throw e;
        }
        return json({ ok: true, id: neu });
      }

      case "invite_resend": {
        const ziel = String(body.einladung_id ?? "");
        if (!ziel) return json({ error: "einladung_id fehlt" }, 400);
        await einladungVersenden(req, ziel);
        return json({ ok: true });
      }

      case "invite_revoke": {
        const ziel = String(body.einladung_id ?? "");
        if (!ziel) return json({ error: "einladung_id fehlt" }, 400);
        const konto = await rpcAlsAufrufer(req, "einladung_zurueckziehen", {
          ziel,
        }) as string | null;
        // Das unbestätigte Konto muss mit weg, sonst bleibt die Adresse
        // belegt und die nächste Einladung läuft in „User already
        // registered". Angenommene Einladungen kommen hier nie an — die
        // RPC lehnt sie ab.
        if (konto) {
          await serviceFetch(`/auth/v1/admin/users/${konto}`, {
            method: "DELETE",
          });
        }
        return json({ ok: true });
      }

      default:
        return json({ error: `Unbekannte Aktion: ${action}` }, 400);
    }
  } catch (e) {
    if (e instanceof RpcFehler) {
      return json({ error: RPC_TEXTE[e.message] ?? e.message }, 400);
    }
    return json({ error: String(e) }, 500);
  }
});
