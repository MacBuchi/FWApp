-- einladungen.sql – Nutzerkonzept Stufe 3, erster Teil (Issue #100):
-- Konten entstehen per Mail-Einladung statt per Zugangszettel.
--
-- Bisher legt ein Kommandant ein Konto `<name>@fw.local` mit einem
-- Initialpasswort an und übergibt einen Zettel. Das trägt für die
-- Truppmannschaft, aber nicht für Kommandanten und Gerätewarte: An
-- `@fw.local` kann niemand etwas schicken, also gibt es dort kein
-- „Passwort vergessen" — der Zettel IST der Wiederherstellungsweg.
--
-- Neu: Der Kommandant lädt eine echte Adresse ein. Die Einladung trägt
-- Rolle, Abteilung und Anzeigename; das Konto zählt erst, wenn die Adresse
-- bestätigt ist (docs/NUTZERKONZEPT.md §3, erster Grundsatz).
--
-- ⚠️ WARUM EINE EIGENE TABELLE UND NICHT `raw_user_meta_data`?
-- GoTrue nimmt beim Einladen frei wählbare Metadaten entgegen, und der
-- bestehende Trigger `handle_new_user()` liest daraus bereits die
-- `abteilung_id`. Diesen Weg auch für die ROLLE zu nutzen, wäre eine
-- Rechteausweitung mit Ansage: Bei eingeschalteter Selbstregistrierung
-- (lokal der Fall, `enable_signup = true`) darf der Client die Metadaten
-- beim Signup selbst mitschicken — er könnte sich `admin` eintragen. Die
-- Wahrheit steht deshalb hier, geschrieben ausschließlich über die RPCs
-- unten. Die Metadaten dienen nur noch dem Mailtext.
--
-- ⚠️ ROLLOUT-REIHENFOLGE (wie jede Stufe, docs/NUTZERKONZEPT.md §7):
-- 1. Migration einspielen, 2. App-Version ausrollen, 3. Mindestversion
-- heben. Vorher niemanden einladen: Ein Alt-Client kennt den Bildschirm
-- „Einladung annehmen" nicht, und der Code aus der Mail lässt sich sonst
-- nirgends eingeben.

-- ── 1) Die Einladung selbst ──────────────────────────────────────────────

create table public.einladungen (
  id            uuid primary key default gen_random_uuid(),
  email         text not null,
  anzeigename   text,
  abteilung_id  uuid not null references public.abteilungen (id) on delete cascade,
  role          text not null check (role in ('admin', 'geraetewart', 'member')),
  als_kommandant boolean not null default false,
  eingeladen_von uuid references auth.users (id) on delete set null,
  -- Das von GoTrue angelegte (noch unbestätigte) Konto. Steht erst, wenn
  -- die Edge Function nach dem Versand nachträgt; beim Zurückziehen wird
  -- genau dieses Konto wieder entfernt.
  auth_user_id  uuid references auth.users (id) on delete set null,
  created_at    timestamptz not null default now(),
  angenommen_am timestamptz,
  zurueckgezogen_am timestamptz
);

-- Höchstens eine offene Einladung je Adresse. Ohne diesen Index könnten
-- zwei Kommandanten dieselbe Person in zwei Abteilungen einladen — beim
-- Bestätigen zöge dann willkürlich eine der beiden, und die andere bliebe
-- als stille Karteileiche stehen.
create unique index einladungen_offen_idx
  on public.einladungen (lower(email))
  where angenommen_am is null and zurueckgezogen_am is null;

create index einladungen_abteilung_idx on public.einladungen (abteilung_id);

comment on table public.einladungen is
  'Offene und erledigte Mail-Einladungen (Nutzerkonzept Stufe 3, Issue '
  '#100). Quelle der Wahrheit für Rolle/Abteilung eines eingeladenen '
  'Kontos — bewusst NICHT raw_user_meta_data, das der Eingeladene bei '
  'eingeschalteter Selbstregistrierung selbst setzen könnte. Geschrieben '
  'ausschliesslich über die RPCs; keine Insert/Update-Policies.';

-- ── 2) Wer darf in einer Abteilung über Mitgliedschaft entscheiden? ──────
-- Zwilling zu `darfVerwalten()` in supabase/functions/admin-users/index.ts.
-- Die Lese-Policy unten braucht die Regel ohnehin in SQL; sie ein zweites
-- Mal in TypeScript zu prüfen, hiesse zwei Definitionen desselben Rechts
-- zu pflegen. Deshalb prüfen die Einladungs-RPCs hier, und die Function
-- ruft sie mit dem JWT des Aufrufers.

create function public.darf_mitglieder_verwalten(
  ziel_abteilung uuid,
  ziel_rolle text
)
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select exists (
    select 1
      from public.abteilungen a
     where a.id = ziel_abteilung
       and (
         -- Feuerwehrkommandant: alles in seiner Gesamtwehr.
         (a.gesamtwehr_id is not null and exists (
            select 1 from public.gesamtwehr_kommandanten k
             where k.user_id = auth.uid()
               and k.gesamtwehr_id = a.gesamtwehr_id))
         or
         -- Abteilungskommandant: nur die eigene Abteilung. 'admin' zu
         -- vergeben bleibt dem Feuerwehrkommandanten vorbehalten — ausser
         -- die Abteilung hängt an keiner Gesamtwehr, sonst käme eine
         -- frische Installation nie zu ihrem zweiten Kommandanten.
         (exists (
            select 1 from public.memberships m
             where m.user_id = auth.uid()
               and m.abteilung_id = ziel_abteilung
               and m.role = 'admin')
          and (ziel_rolle is distinct from 'admin' or a.gesamtwehr_id is null))
       )
  );
$$;

revoke execute on function public.darf_mitglieder_verwalten(uuid, text)
  from public, anon;
grant execute on function public.darf_mitglieder_verwalten(uuid, text)
  to authenticated, service_role;

comment on function public.darf_mitglieder_verwalten(uuid, text) is
  'Darf der Angemeldete in dieser Abteilung eine Mitgliedschaft mit dieser '
  'Rolle vergeben? ziel_rolle = null für reine Verwaltungssichten.';

alter table public.einladungen enable row level security;

-- Sichtbar für die, die dort auch verwalten dürfen. Damit sieht ein
-- Abteilungskommandant die Einladungen seiner Abteilung, der
-- Feuerwehrkommandant die seiner ganzen Gesamtwehr — und niemand die einer
-- fremden Wehr.
create policy "read einladungen der verwalteten abteilungen"
  on public.einladungen
  for select to authenticated
  using (public.darf_mitglieder_verwalten(abteilung_id, null));

grant select on public.einladungen to authenticated;
grant all on public.einladungen to service_role;

-- ── 3) Einladen ──────────────────────────────────────────────────────────

create function public.einladung_anlegen(
  adresse text,
  name text,
  abteilung uuid,
  rolle text,
  kommandant boolean default false
)
returns uuid
language plpgsql
security definer set search_path = ''
as $$
declare
  sauber_mail text := lower(btrim(coalesce(adresse, '')));
  sauber_name text := nullif(btrim(coalesce(name, '')), '');
  ziel_gesamtwehr uuid;
  neue_id uuid;
begin
  -- Absichtlich grob: Verbindlich prüft GoTrue beim Versand. Hier geht es
  -- nur darum, offensichtlichen Unsinn vor dem Rundweg abzufangen.
  if sauber_mail !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]{2,}$' then
    raise exception 'invalid email' using errcode = 'P0001';
  end if;
  -- `@fw.local` ist die Zettel-Form und nimmt keine Post an. Eine Einladung
  -- dorthin verschickte eine Mail ins Nichts und liesse den Eingeladenen
  -- ewig auf einen Code warten.
  if sauber_mail like '%@fw.local' then
    raise exception 'fw.local addresses cannot receive mail'
      using errcode = 'P0001';
  end if;
  if rolle is null or rolle not in ('admin', 'geraetewart', 'member') then
    raise exception 'invalid role' using errcode = 'P0001';
  end if;
  if not public.darf_mitglieder_verwalten(abteilung, rolle) then
    raise exception 'permission denied' using errcode = 'P0001';
  end if;

  select a.gesamtwehr_id into ziel_gesamtwehr
    from public.abteilungen a where a.id = abteilung;

  if coalesce(kommandant, false) then
    if ziel_gesamtwehr is null then
      raise exception 'abteilung has no gesamtwehr' using errcode = 'P0001';
    end if;
    -- Aussperr-Schutz (docs/NUTZERKONZEPT.md §3): Einen zweiten
    -- Feuerwehrkommandanten ernennt nur ein Feuerwehrkommandant.
    if not public.is_gesamtwehr_admin(ziel_gesamtwehr) then
      raise exception 'permission denied: feuerwehrkommandant required'
        using errcode = 'P0001';
    end if;
  end if;

  -- Ein bestätigtes Konto lädt man nicht ein, man gibt ihm eine
  -- Mitgliedschaft. GoTrue lehnte den Versand ohnehin ab; ohne diese
  -- Prüfung bliebe eine Einladungszeile zurück, die nie jemand annimmt.
  if exists (
    select 1 from auth.users u
     where lower(u.email) = sauber_mail and u.email_confirmed_at is not null
  ) then
    raise exception 'account already exists' using errcode = 'P0001';
  end if;

  begin
    insert into public.einladungen
        (email, anzeigename, abteilung_id, role, als_kommandant, eingeladen_von)
    values (sauber_mail, sauber_name, abteilung, rolle,
            coalesce(kommandant, false), auth.uid())
    returning id into neue_id;
  exception when unique_violation then
    raise exception 'invitation already open' using errcode = 'P0001';
  end;

  return neue_id;
end;
$$;

revoke execute on function
  public.einladung_anlegen(text, text, uuid, text, boolean) from public, anon;
grant execute on function
  public.einladung_anlegen(text, text, uuid, text, boolean) to authenticated;

-- Alles, was die Edge Function für den Versand braucht. Eigene Funktion,
-- weil sie zweimal gebraucht wird: beim ersten Versand und beim erneuten.
create function public.einladung_versanddaten(ziel uuid)
returns table (
  email text,
  anzeigename text,
  role text,
  als_kommandant boolean,
  abteilung text,
  wehr text
)
language plpgsql
security definer set search_path = ''
as $$
declare
  e public.einladungen;
begin
  select * into e from public.einladungen where id = ziel;
  if not found then
    raise exception 'invitation not found' using errcode = 'P0001';
  end if;
  if not public.darf_mitglieder_verwalten(e.abteilung_id, null) then
    raise exception 'permission denied' using errcode = 'P0001';
  end if;
  if e.angenommen_am is not null or e.zurueckgezogen_am is not null then
    raise exception 'invitation is not open' using errcode = 'P0001';
  end if;

  return query
    select e.email, e.anzeigename, e.role, e.als_kommandant,
           a.name, g.name
      from public.abteilungen a
      left join public.gesamtwehren g on g.id = a.gesamtwehr_id
     where a.id = e.abteilung_id;
end;
$$;

revoke execute on function public.einladung_versanddaten(uuid) from public, anon;
grant execute on function public.einladung_versanddaten(uuid) to authenticated;

-- Nach dem Versand trägt die Edge Function das angelegte Konto nach.
-- Eigene RPC statt eines direkten PATCH, damit die Tabelle ohne
-- Update-Policy auskommt und der Service-Key nichts Freieres tut als nötig.
create function public.einladung_konto_vermerken(ziel uuid, konto uuid)
returns void
language sql
security definer set search_path = ''
as $$
  update public.einladungen set auth_user_id = konto where id = ziel;
$$;

revoke execute on function public.einladung_konto_vermerken(uuid, uuid)
  from public, anon, authenticated;
-- Das Revoke von PUBLIC nimmt auch service_role das Default-Execute
-- (dieselbe Falle wie bei sync_profile_mirror) — deshalb ausdrücklich zurück.
grant execute on function public.einladung_konto_vermerken(uuid, uuid)
  to service_role;

-- ── 4) Zurückziehen ──────────────────────────────────────────────────────

-- Gibt das angelegte Konto zurück, damit die Edge Function es entfernen
-- kann. Ohne diesen Schritt bliebe die Adresse belegt: Eine erneute
-- Einladung liefe gegen ein vorhandenes (wenn auch unbestätigtes) Konto.
create function public.einladung_zurueckziehen(ziel uuid)
returns uuid
language plpgsql
security definer set search_path = ''
as $$
declare
  e public.einladungen;
begin
  select * into e from public.einladungen where id = ziel;
  if not found then
    raise exception 'invitation not found' using errcode = 'P0001';
  end if;
  if not public.darf_mitglieder_verwalten(e.abteilung_id, null) then
    raise exception 'permission denied' using errcode = 'P0001';
  end if;
  if e.angenommen_am is not null then
    raise exception 'invitation already accepted' using errcode = 'P0001';
  end if;

  update public.einladungen
     set zurueckgezogen_am = coalesce(zurueckgezogen_am, now())
   where id = ziel;

  return e.auth_user_id;
end;
$$;

revoke execute on function public.einladung_zurueckziehen(uuid)
  from public, anon;
grant execute on function public.einladung_zurueckziehen(uuid)
  to authenticated;

-- ── 5) Annehmen: das Konto zählt erst mit der bestätigten Adresse ────────

create function public.einladung_annehmen(ziel_user uuid, adresse text)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  e public.einladungen;
begin
  select * into e from public.einladungen
   where lower(email) = lower(coalesce(adresse, ''))
     and angenommen_am is null
     and zurueckgezogen_am is null
   order by created_at desc
   limit 1;
  if not found then return; end if;

  insert into public.memberships (user_id, abteilung_id, role)
  values (ziel_user, e.abteilung_id, e.role)
  on conflict (user_id, abteilung_id) do update set role = excluded.role;

  if e.als_kommandant then
    insert into public.gesamtwehr_kommandanten (user_id, gesamtwehr_id)
    select ziel_user, a.gesamtwehr_id
      from public.abteilungen a
     where a.id = e.abteilung_id and a.gesamtwehr_id is not null
    on conflict do nothing;
  end if;

  if e.anzeigename is not null then
    update public.profiles set username = e.anzeigename where id = ziel_user;
  end if;

  update public.einladungen
     set angenommen_am = now(), auth_user_id = ziel_user
   where id = e.id;

  perform public.sync_profile_mirror(ziel_user);
end;
$$;

-- Ruft ausschliesslich der Trigger unten (im Definer-Kontext des Eigentümers).
revoke execute on function public.einladung_annehmen(uuid, text)
  from public, anon, authenticated;

comment on function public.einladung_annehmen(uuid, text) is
  'Wendet die offene Einladung zu dieser Adresse an. Wird vom Trigger '
  'on_auth_user_confirmed gerufen, sobald GoTrue die Adresse bestätigt.';

-- Der Auslöser: GoTrue setzt email_confirmed_at, wenn der Code aus der
-- Einladungsmail eingelöst wird. Erst dann entsteht die Mitgliedschaft —
-- eine offene Einladung verschafft keinerlei Recht.
create function public.handle_user_confirmed()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  if new.email_confirmed_at is not null and old.email_confirmed_at is null then
    perform public.einladung_annehmen(new.id, new.email);
  end if;
  return new;
end;
$$;

create trigger on_auth_user_confirmed
  after update of email_confirmed_at on auth.users
  for each row execute function public.handle_user_confirmed();

-- ── 6) Neue Konten: Eingeladene bekommen NOCH KEINE Mitgliedschaft ───────
--
-- `/auth/v1/invite` legt die Zeile in auth.users sofort an — der Trigger
-- feuert also beim Einladen, nicht beim Annehmen. Die bisherige Fassung
-- steckte jedes neue Konto ohne Metadaten in die Spiegel-Abteilung UND gab
-- ihm dort eine member-Mitgliedschaft. Ein Eingeladener hätte damit schon
-- vor dem Bestätigen Lesezugriff auf einen fremden Bestand gehabt.
-- (Am lokalen Stack nachgestellt, bevor diese Migration entstand.)

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
declare
  ziel uuid;
  e public.einladungen;
begin
  select * into e from public.einladungen
   where lower(email) = lower(coalesce(new.email, ''))
     and angenommen_am is null
     and zurueckgezogen_am is null
   order by created_at desc
   limit 1;

  if found then
    -- Profil ja (der Anzeigename soll schon in der Liste stehen),
    -- Abteilung und Mitgliedschaft nein — die setzt erst
    -- einladung_annehmen() nach der Bestätigung.
    insert into public.profiles (id, abteilung_id, username)
    values (new.id, null,
            coalesce(e.anzeigename, split_part(new.email, '@', 1)))
    on conflict do nothing;
    return new;
  end if;

  ziel := coalesce(
    nullif(new.raw_user_meta_data ->> 'abteilung_id', '')::uuid,
    (select id from public.abteilungen where legacy_mirror)
  );
  insert into public.profiles (id, abteilung_id, username)
  values (new.id, ziel, split_part(new.email, '@', 1))
  on conflict do nothing;
  -- Als member; die richtige Rolle setzt admin-users direkt danach über
  -- die Mitgliedschaft (und spiegelt sie ins Profil).
  if ziel is not null then
    insert into public.memberships (user_id, abteilung_id, role)
    values (new.id, ziel, 'member')
    on conflict do nothing;
  end if;
  return new;
end;
$$;
