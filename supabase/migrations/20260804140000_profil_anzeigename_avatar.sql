-- 20260804140000_profil_anzeigename_avatar.sql – Eigener Anzeigename und
-- eigener Avatar (Nutzerkonzept Stufe ③, Issue #100, docs/NUTZERKONZEPT.md §2).
--
-- VIER FESTLEGUNGEN, die den Rest erklären:
--
-- 1. ANZEIGENAME IST NICHT NUTZERNAME. `profiles.username` ist die Kennung
--    des Zettel-Kontos und zugleich der lokale Teil von `<name>@fw.local` —
--    kleingeschrieben, ohne Leerzeichen, vom Kommandanten vergeben. Ein
--    Anzeigename ist „Marcus B."; beides in eine Spalte zu zwingen hieße,
--    entweder die Anmeldung kaputtzumachen oder die Schreibweise zu
--    verbieten. Deshalb eine zweite Spalte, die leer sein darf: Ist sie
--    leer, bleibt es beim Nutzernamen.
--
-- 2. DER AVATAR IST TEXT, KEIN BILD. Acht Werte (Hintergrund, Hautton,
--    Kopfbedeckung, Helmfarbe, Augen, Mund, Bart, Haarfarbe) ergeben einen
--    gezeichneten Kopf. Kein Bucket, kein Upload, kein Bildabgleich, kein
--    Gesicht einer realen Person in der Datenbank — und offline funktioniert
--    es auch, weil gezeichnet statt geladen wird.
--
-- 3. DAS FORMAT GEHÖRT DEM CLIENT. Der Server prüft nur Länge und
--    Zeichenvorrat, damit die Spalte kein Ablageplatz für Beliebiges wird.
--    Was „gear=scba" bedeutet, weiß die App — genau wie beim Ablauf der
--    temporären Rechte (20260804090000) entscheidet die Seite, die es
--    darstellen muss. Ein neuer Wert kostet damit keine Migration.
--
-- 4. JEDER SETZT NUR SICH SELBST. Die RPC kennt kein Ziel-Konto, sie
--    schreibt auf `auth.uid()`. Damit gibt es keinen Weg, jemandem ein
--    Gesicht zu geben, und keine Rechteprüfung, die falsch sein könnte.
--    Den Nutzernamen vergibt weiterhin der Kommandant über admin-users.

alter table public.profiles add column if not exists anzeigename text;
alter table public.profiles add column if not exists avatar text;

comment on column public.profiles.anzeigename is
  'Selbst gewählter Anzeigename (Issue #100). Leer = es bleibt beim '
  'username. NICHT die Anmeldung — die hängt an auth.users.email.';

comment on column public.profiles.avatar is
  'Gezeichneter Feuerwehr-Avatar als „schluessel=wert;…"-Text (Issue #100). '
  'Das Format kennt die App; der Server prüft nur Länge und Zeichen.';

-- ── Selbst setzen ───────────────────────────────────────────────────────────
-- Zwei Parameter, ein Aufruf: Wer im Profil-Screen speichert, hat meist
-- beides angefasst. Zwei RPCs wären zwei Runden über eine Mobilfunkleitung
-- und ein halb gespeichertes Profil, wenn die zweite scheitert.
create function public.mein_profil_setzen(
  neuer_anzeigename text,
  neuer_avatar text
)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  name_sauber text := btrim(coalesce(neuer_anzeigename, ''));
  avatar_sauber text := btrim(coalesce(neuer_avatar, ''));
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = 'P0001';
  end if;

  -- Zeilenumbrüche und Steuerzeichen würden die Liste in der
  -- Nutzerverwaltung zerreißen; 40 Zeichen sind mehr als jeder Name
  -- braucht und wenig genug, dass nichts anderes hineinpasst.
  if name_sauber <> '' then
    if length(name_sauber) > 40 then
      raise exception 'name too long' using errcode = 'P0001';
    end if;
    if name_sauber ~ '[[:cntrl:]]' then
      raise exception 'name has control characters' using errcode = 'P0001';
    end if;
  end if;

  -- Festlegung 3: Grenze statt Grammatik. Was hier durchkommt, ist entweder
  -- ein Avatar oder für die App unlesbar — beides ist harmlos, weil die App
  -- bei Unlesbarem auf den Standardkopf zurückfällt.
  if avatar_sauber <> '' then
    if length(avatar_sauber) > 200 then
      raise exception 'avatar too long' using errcode = 'P0001';
    end if;
    if avatar_sauber !~ '^[A-Za-z0-9=;#_-]+$' then
      raise exception 'avatar has invalid characters' using errcode = 'P0001';
    end if;
  end if;

  update public.profiles
     set anzeigename = nullif(name_sauber, ''),
         avatar = nullif(avatar_sauber, '')
   where id = auth.uid();
end;
$$;

revoke execute on function public.mein_profil_setzen(text, text)
  from public, anon;
grant execute on function public.mein_profil_setzen(text, text)
  to authenticated, service_role;

comment on function public.mein_profil_setzen(text, text) is
  'Setzt Anzeigename und Avatar des ANGEMELDETEN Kontos (Issue #100). '
  'Leerer Wert löscht das jeweilige Feld.';
