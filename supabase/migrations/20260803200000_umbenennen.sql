-- 20260803200000_umbenennen.sql – Abteilung und Gesamtwehr umbenennen (#119).
--
-- Bis hierher entstand der Name einmal beim Anlegen und war danach
-- unerreichbar: `abteilungen` und `gesamtwehren` tragen nur Lese-Policies,
-- geschrieben wird ausschliesslich ueber SECURITY-DEFINER-RPCs, und ein
-- Gegenstueck zum Aendern gab es nicht. Ein Tippfehler im Abteilungsnamen war
-- damit nur vom Betreiber an der Datenbank zu heilen — im Feld genau bei der
-- Neuanlegung einer Wehr aufgefallen.
--
-- ZWEI Funktionen statt einer, weil die Rechtefrage eine andere ist — und die
-- ist der eigentliche Inhalt, nicht das `update`:
--
--   rename_abteilung   Feuerwehrkommandant der Gesamtwehr ODER
--                      Abteilungskommandant GENAU DIESER Abteilung
--   rename_gesamtwehr  nur der Feuerwehrkommandant
--
-- Der Abteilungskommandant darf die Gesamtwehr ausdruecklich NICHT umbenennen:
-- Sonst aendert der Kommandant der kleinsten Abteilung den Auftritt der ganzen
-- Wehr. Dieselbe Grenze zieht schon `darf_mitglieder_verwalten`, deshalb wird
-- sie hier wiederverwendet statt nachgebaut — eine zweite Fassung derselben
-- Regel driftet.
--
-- DER KENNZEICHNER (slug) BLEIBT STEHEN. Ihn mitzuziehen waere naheliegend und
-- waere falsch: Er ist eindeutig, wuerde beim Umbenennen wieder frei, eine
-- andere Abteilung koennte ihn spaeter bekommen — und ein alter Verweis zeigte
-- dann auf die falsche Zeile. Ein Bezeichner darf sich nicht aendern, nur weil
-- sich eine Beschriftung aendert. Im Client kommt er ohnehin nicht vor
-- (nachgesehen: null Fundstellen), er dient nur der Lesbarkeit auf dem Server.

-- ── Abteilung ───────────────────────────────────────────────────────────────
create function public.rename_abteilung(ziel uuid, neuer_name text)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  sauber text := btrim(coalesce(neuer_name, ''));
begin
  if sauber = '' then
    raise exception 'name required' using errcode = 'P0001';
  end if;

  -- ziel_rolle = null heisst „darf hier ueberhaupt verwalten“. Eine Abteilung,
  -- die es nicht gibt, faellt hier ebenfalls durch — die Absage nennt deshalb
  -- bewusst keinen Unterschied zwischen „darfst du nicht“ und „gibt es nicht“.
  if not public.darf_mitglieder_verwalten(ziel, null) then
    raise exception 'permission denied: abteilung umbenennen'
      using errcode = 'P0001';
  end if;

  update public.abteilungen set name = sauber where id = ziel;
end;
$$;

revoke execute on function public.rename_abteilung(uuid, text)
  from public, anon;
grant execute on function public.rename_abteilung(uuid, text)
  to authenticated, service_role;

comment on function public.rename_abteilung(uuid, text) is
  'Benennt eine Abteilung um. Feuerwehrkommandant der Gesamtwehr oder '
  'Abteilungskommandant dieser Abteilung. Kennung und Kennzeichner bleiben.';

-- ── Gesamtwehr ──────────────────────────────────────────────────────────────
create function public.rename_gesamtwehr(ziel uuid, neuer_name text)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  sauber text := btrim(coalesce(neuer_name, ''));
begin
  if sauber = '' then
    raise exception 'name required' using errcode = 'P0001';
  end if;

  if not public.is_gesamtwehr_admin(ziel) then
    raise exception 'permission denied: gesamtwehr umbenennen'
      using errcode = 'P0001';
  end if;

  update public.gesamtwehren set name = sauber where id = ziel;
end;
$$;

revoke execute on function public.rename_gesamtwehr(uuid, text)
  from public, anon;
grant execute on function public.rename_gesamtwehr(uuid, text)
  to authenticated, service_role;

comment on function public.rename_gesamtwehr(uuid, text) is
  'Benennt eine Gesamtwehr um. Nur ihr Feuerwehrkommandant.';
