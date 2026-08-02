-- memberships_kommandanten.sql – Nutzerkonzept Stufe 1 (Issue #98):
-- Rollen werden Mitgliedschaften, der Feuerwehrkommandant wird explizit.
--
-- Bisher: genau EINE Abteilung und EINE Rolle pro Konto (Spalten an
-- `profiles`), und „Gesamtwehr-Admin" war eine Herleitung — jeder
-- Abteilungs-Admin der Gesamtwehr durfte über deren Mitgliedschaft
-- entscheiden. Beides widerspricht dem Zielbild (docs/NUTZERKONZEPT.md):
-- Dieselbe Person kann Gerätewart in zwei Abteilungen sein, und ein
-- Abteilungskommandant ist KEIN Feuerwehrkommandant.
--
-- Neu: `memberships` (wer × Abteilung × Rolle) und
-- `gesamtwehr_kommandanten` (wer × Gesamtwehr) sind die Wahrheit. Die
-- Spalten `profiles.role` / `profiles.abteilung_id` bleiben als
-- ALT-CLIENT-SPIEGEL bestehen (Clients ≤ v1.10.0 lesen sie für ihre UI)
-- und werden über `sync_profile_mirror()` nachgeführt — Schreiber ist
-- ausschließlich die Edge Function `admin-users` bzw. die RPCs hier.
-- Fällt der Spiegel nach der Mindestversions-Anhebung, fallen die Spalten.
--
-- ⚠️ ROLLOUT-REIHENFOLGE (wie #57 Phase 1): 1. Migration einspielen
-- (Backfill erhält das Ist-Verhalten eins zu eins), 2. App-Version mit
-- Mitgliedschafts-UI ausrollen, 3. Mindestversion heben. Vorher keine
-- Mehrfach-Mitgliedschaften anlegen: Alt-Clients zeigen nur die
-- Spiegel-Rolle.
--
-- Einspielen wie gehabt per docker exec psql als supabase_admin, danach
-- NOTIFY pgrst, 'reload schema'.

-- ── 1) Mitgliedschaften: wer × Abteilung × Rolle ─────────────────────────

create table public.memberships (
  user_id uuid not null references public.profiles (id) on delete cascade,
  abteilung_id uuid not null references public.abteilungen (id) on delete cascade,
  role text not null check (role in ('admin', 'geraetewart', 'member')),
  created_at timestamptz not null default now(),
  primary key (user_id, abteilung_id)
);

create index memberships_abteilung_idx on public.memberships (abteilung_id);

comment on table public.memberships is
  'Rolle je Abteilung (Nutzerkonzept Stufe 1, Issue #98). Quelle der '
  'Wahrheit für Schreibrechte; profiles.role/abteilung_id sind nur noch '
  'der Alt-Client-Spiegel. Geschrieben ausschliesslich über admin-users '
  'bzw. die RPCs — bewusst keine Insert/Update-Policies.';

-- Backfill: die bisherige (Abteilung, Rolle) jedes Kontos wird seine erste
-- Mitgliedschaft. Damit ändert diese Migration am wirksamen Recht nichts.
insert into public.memberships (user_id, abteilung_id, role)
select p.id, p.abteilung_id, p.role
  from public.profiles p
 where p.abteilung_id is not null;

-- ── 2) Feuerwehrkommandanten: wer × Gesamtwehr, explizit ─────────────────

create table public.gesamtwehr_kommandanten (
  user_id uuid not null references public.profiles (id) on delete cascade,
  gesamtwehr_id uuid not null references public.gesamtwehren (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, gesamtwehr_id)
);

create index gesamtwehr_kommandanten_gesamtwehr_idx
  on public.gesamtwehr_kommandanten (gesamtwehr_id);

comment on table public.gesamtwehr_kommandanten is
  'Feuerwehrkommandanten (Nutzerkonzept Stufe 1, Issue #98): dürfen in '
  'jeder Abteilung ihrer Gesamtwehr schreiben, Abteilungen anlegen und '
  'über Mitgliedschaft entscheiden. Ersetzt die Herleitung „jeder '
  'Abteilungs-Admin ist Gesamtwehr-Admin".';

-- Backfill: Wer heute Admin einer angeschlossenen Abteilung ist, HATTE die
-- Gesamtwehr-Rechte über die Herleitung — er behält sie als expliziter
-- Kommandant. Zurückstufen geht danach in der App.
insert into public.gesamtwehr_kommandanten (user_id, gesamtwehr_id)
select p.id, a.gesamtwehr_id
  from public.profiles p
  join public.abteilungen a on a.id = p.abteilung_id
 where p.role = 'admin'
   and a.gesamtwehr_id is not null;

-- ── 3) RLS: jeder liest die eigenen Zeilen (die App leitet daraus canEdit
--     je Abteilung ab); alles Weitere läuft über admin-users/service_role ──

alter table public.memberships enable row level security;
alter table public.gesamtwehr_kommandanten enable row level security;

create policy "read own memberships" on public.memberships
  for select to authenticated using (user_id = auth.uid());
create policy "read own kommandant rows" on public.gesamtwehr_kommandanten
  for select to authenticated using (user_id = auth.uid());

grant select on public.memberships, public.gesamtwehr_kommandanten
  to authenticated;
grant all on public.memberships, public.gesamtwehr_kommandanten
  to service_role;

-- ── 4) Spiegel-Pflege für Alt-Clients ────────────────────────────────────
-- Rolle = höchste Mitgliedschaftsrolle (Kommandant zählt als admin),
-- Heimat-Abteilung bleibt, solange dort eine Mitgliedschaft besteht.
-- Nur service_role: Aufrufer ist die Edge Function nach jeder Änderung.

create function public.sync_profile_mirror(target uuid)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  beste_rolle text;
  ist_kommandant boolean;
  heimat uuid;
begin
  select exists (
    select 1 from public.gesamtwehr_kommandanten k where k.user_id = target
  ) into ist_kommandant;

  select m.role into beste_rolle
    from public.memberships m
   where m.user_id = target
   order by case m.role
              when 'admin' then 0
              when 'geraetewart' then 1
              else 2
            end
   limit 1;

  select p.abteilung_id into heimat
    from public.profiles p where p.id = target;
  if heimat is null or not exists (
    select 1 from public.memberships m
     where m.user_id = target and m.abteilung_id = heimat
  ) then
    select m.abteilung_id into heimat
      from public.memberships m
     where m.user_id = target
     order by m.created_at
     limit 1;
  end if;

  update public.profiles
     set role = case when ist_kommandant then 'admin'
                     else coalesce(beste_rolle, 'member') end,
         abteilung_id = heimat
   where id = target;
end;
$$;

revoke execute on function public.sync_profile_mirror(uuid)
  from public, anon, authenticated;
-- Anders als freier_slug() wird diese Funktion per PostgREST-RPC gerufen
-- (von admin-users mit dem Service-Key) — das Revoke von PUBLIC nimmt auch
-- service_role das Default-Execute, deshalb hier ausdrücklich zurückgeben.
-- Ohne den Grant: 403 beim Spiegel-Update (im lokalen Rauchtest gefunden).
grant execute on function public.sync_profile_mirror(uuid) to service_role;

comment on function public.sync_profile_mirror(uuid) is
  'Führt profiles.role/abteilung_id als Alt-Client-Spiegel der '
  'Mitgliedschaften nach. Entfällt mit dem Spiegel selbst.';

-- ── 5) Neue Konten: Profil UND Mitgliedschaft ────────────────────────────

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
declare
  ziel uuid;
begin
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

-- ── 6) RLS-Helfer auf die neue Wahrheit umstellen ────────────────────────
-- CREATE OR REPLACE behält die bestehenden Grants — das Revoke-Muster ist
-- nur bei NEUEN Funktionen nötig (oben bei sync_profile_mirror geschehen).

-- Lesen: jede Abteilung, in der eine Mitgliedschaft besteht, deren
-- Schwestern (Quer-Sicht lesend, Entscheidung 2026-08-01) — und für
-- Kommandanten die ganze Gesamtwehr.
create or replace function public.can_read_abteilung(target uuid)
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.memberships m
    join public.abteilungen mine on mine.id = m.abteilung_id
    join public.abteilungen t on t.id = target
    where m.user_id = auth.uid()
      and (t.id = mine.id
           or (mine.gesamtwehr_id is not null
               and t.gesamtwehr_id = mine.gesamtwehr_id))
  )
  or exists (
    select 1
    from public.gesamtwehr_kommandanten k
    join public.abteilungen t on t.id = target
    where k.user_id = auth.uid()
      and t.gesamtwehr_id = k.gesamtwehr_id
  );
$$;

-- Schreiben/Veröffentlichen: Schreibrolle IN GENAU DIESER Abteilung, oder
-- Feuerwehrkommandant ihrer Gesamtwehr. Der frühere Zusatz „role=admin
-- darf in jeder Schwester schreiben" ist damit bewusst weg — genau die
-- Herleitung, die das Zielbild kippt (Backfill oben erhält den Ist-Stand).
create or replace function public.can_publish_abteilung(target uuid)
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select exists (
    select 1 from public.memberships m
    where m.user_id = auth.uid()
      and m.abteilung_id = target
      and m.role in ('admin', 'geraetewart')
  )
  or exists (
    select 1
    from public.gesamtwehr_kommandanten k
    join public.abteilungen t on t.id = target
    where k.user_id = auth.uid()
      and t.gesamtwehr_id = k.gesamtwehr_id
  );
$$;

-- Fotos hochladen (Storage-Policies): irgendeine Schreibrolle genügt —
-- der Bucket ist nicht mandantenscharf, das war er auch bisher nicht.
create or replace function public.is_editor()
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select exists (
    select 1 from public.memberships
    where user_id = auth.uid() and role in ('admin', 'geraetewart')
  )
  or exists (
    select 1 from public.gesamtwehr_kommandanten where user_id = auth.uid()
  );
$$;

-- „Gesamtwehr-Admin" heißt ab jetzt: explizit ernannter Kommandant.
-- decide_gesamtwehr_verbindung() und offene_verbindungsanfragen() ziehen
-- automatisch mit, sie rufen diese Funktion.
create or replace function public.is_gesamtwehr_admin(ziel uuid)
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select ziel is not null and exists (
    select 1 from public.gesamtwehr_kommandanten
    where user_id = auth.uid() and gesamtwehr_id = ziel
  );
$$;

-- is_admin() hängt an keiner Policy mehr (Storage seit role_geraetewart
-- auf is_editor). Trotzdem umstellen: eine liegengebliebene Definition
-- gegen den Spiegel wäre eine Falle für die nächste Policy, die sie greift.
create or replace function public.is_admin()
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select exists (
    select 1 from public.memberships
    where user_id = auth.uid() and role = 'admin'
  )
  or exists (
    select 1 from public.gesamtwehr_kommandanten where user_id = auth.uid()
  );
$$;

-- ── 7) RPCs auf Mitgliedschaften umstellen ───────────────────────────────

-- Gründen: Abteilungskommandant (admin-Mitgliedschaft in der
-- Heimat-Abteilung) einer noch unverbundenen Abteilung. NEU: Der Gründer
-- wird explizit Feuerwehrkommandant — vorher ergab sich das aus der
-- (jetzt gestrichenen) Herleitung.
create or replace function public.create_gesamtwehr(name text)
returns uuid
language plpgsql
security definer set search_path = ''
as $$
declare
  meine_abteilung uuid;
  meine_rolle text;
  schon_verbunden uuid;
  neue_id uuid;
  sauber text := btrim(coalesce(name, ''));
begin
  if sauber = '' then
    raise exception 'name required' using errcode = 'P0001';
  end if;

  select p.abteilung_id into meine_abteilung
    from public.profiles p where p.id = auth.uid();
  if meine_abteilung is null then
    raise exception 'no abteilung assigned' using errcode = 'P0001';
  end if;

  select m.role into meine_rolle
    from public.memberships m
   where m.user_id = auth.uid() and m.abteilung_id = meine_abteilung;
  if meine_rolle is distinct from 'admin' then
    raise exception 'permission denied: admin role required'
      using errcode = 'P0001';
  end if;

  select gesamtwehr_id into schon_verbunden
    from public.abteilungen where id = meine_abteilung for update;
  if schon_verbunden is not null then
    raise exception 'abteilung already belongs to a gesamtwehr'
      using errcode = 'P0001';
  end if;

  insert into public.gesamtwehren (name, slug, created_by)
  values (sauber, public.freier_slug(sauber, 'gesamtwehren'), auth.uid())
  returning id into neue_id;

  update public.abteilungen
     set gesamtwehr_id = neue_id
   where id = meine_abteilung;

  insert into public.gesamtwehr_kommandanten (user_id, gesamtwehr_id)
  values (auth.uid(), neue_id);

  return neue_id;
end;
$$;

-- Weitere Abteilung anlegen: nur noch der Feuerwehrkommandant (Zielbild
-- §6: „Abteilungen entstehen nur durch den Feuerwehrkommandanten").
create or replace function public.create_abteilung(name text)
returns uuid
language plpgsql
security definer set search_path = ''
as $$
declare
  meine_abteilung uuid;
  meine_gesamtwehr uuid;
  neue_id uuid;
  sauber text := btrim(coalesce(name, ''));
begin
  if sauber = '' then
    raise exception 'name required' using errcode = 'P0001';
  end if;

  select p.abteilung_id into meine_abteilung
    from public.profiles p where p.id = auth.uid();
  if meine_abteilung is null then
    raise exception 'no abteilung assigned' using errcode = 'P0001';
  end if;

  select gesamtwehr_id into meine_gesamtwehr
    from public.abteilungen where id = meine_abteilung;
  if meine_gesamtwehr is null then
    raise exception 'gesamtwehr required: create or join one first'
      using errcode = 'P0001';
  end if;

  if not public.is_gesamtwehr_admin(meine_gesamtwehr) then
    raise exception 'permission denied: feuerwehrkommandant required'
      using errcode = 'P0001';
  end if;

  insert into public.abteilungen (gesamtwehr_id, name, slug, status)
  values (meine_gesamtwehr, sauber,
          public.freier_slug(sauber, 'abteilungen'), 'active')
  returning id into neue_id;

  return neue_id;
end;
$$;

-- Anschluss beantragen: Schreibrolle in der Heimat-Abteilung — jetzt aus
-- der Mitgliedschaft statt aus dem Spiegel gelesen. (Der ganze Pfad
-- entfällt in Stufe 4, Issue #101.)
create or replace function public.request_gesamtwehr_verbindung(
  ziel uuid,
  nachricht text default null
)
returns uuid
language plpgsql
security definer set search_path = ''
as $$
declare
  meine_abteilung uuid;
  meine_rolle text;
  schon_verbunden uuid;
  anfrage_id uuid;
  notiz text := nullif(btrim(coalesce(nachricht, '')), '');
begin
  select p.abteilung_id into meine_abteilung
    from public.profiles p where p.id = auth.uid();
  if meine_abteilung is null then
    raise exception 'no abteilung assigned' using errcode = 'P0001';
  end if;

  select m.role into meine_rolle
    from public.memberships m
   where m.user_id = auth.uid() and m.abteilung_id = meine_abteilung;
  if meine_rolle is null or meine_rolle not in ('admin', 'geraetewart') then
    raise exception 'permission denied: admin or geraetewart role required'
      using errcode = 'P0001';
  end if;

  if not exists (select 1 from public.gesamtwehren where id = ziel) then
    raise exception 'gesamtwehr not found' using errcode = 'P0001';
  end if;

  select gesamtwehr_id into schon_verbunden
    from public.abteilungen where id = meine_abteilung for update;
  if schon_verbunden is not null then
    raise exception 'abteilung already belongs to a gesamtwehr'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.gesamtwehr_anfragen
     where abteilung_id = meine_abteilung and status = 'pending'
  ) then
    raise exception 'a request is already pending for this abteilung'
      using errcode = 'P0001';
  end if;

  insert into public.gesamtwehr_anfragen
      (abteilung_id, gesamtwehr_id, nachricht, created_by)
  values (meine_abteilung, ziel, notiz, auth.uid())
  returning id into anfrage_id;

  return anfrage_id;
end;
$$;

-- ── 8) Spiegel-Hinweis an den Spalten selbst ─────────────────────────────

comment on column public.profiles.role is
  'ALT-CLIENT-SPIEGEL (seit Nutzerkonzept Stufe 1): höchste '
  'Mitgliedschaftsrolle, Kommandant zählt als admin. Wahrheit ist '
  'public.memberships; nachgeführt über sync_profile_mirror().';

comment on column public.profiles.abteilung_id is
  'ALT-CLIENT-SPIEGEL (seit Nutzerkonzept Stufe 1): Heimat-Abteilung. '
  'Wahrheit ist public.memberships; nachgeführt über sync_profile_mirror().';
