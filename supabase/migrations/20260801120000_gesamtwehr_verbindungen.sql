-- gesamtwehr_verbindungen.sql – Phase 3 von Issue #57: die Gesamtwehr wird real.
--
-- Phase 1 hat die Abteilung zum Datenbestand gemacht und `gesamtwehren` als
-- leere Klammer angelegt. Hier bekommt die Klammer ihre Funktion: Abteilungen
-- entstehen und verbinden sich in der App statt per psql auf dem Server.
--
-- Vier Vorgänge, alle als RPC (die Tabellen haben bewusst KEINE
-- insert/update-Policies — Schreiben geht ausschließlich durch diese
-- Funktionen, damit die Regeln an einer Stelle stehen):
--   1. `create_gesamtwehr`      – ein Admin gründet die Klammer, seine eigene
--                                 Abteilung wird Gründungsmitglied.
--   2. `create_abteilung`       – ein Admin legt eine weitere Abteilung in
--                                 SEINER Gesamtwehr an; sie ist sofort aktiv.
--   3. `request_gesamtwehr_verbindung` – eine bestehende Abteilung bittet um
--                                 Anschluss an eine Gesamtwehr.
--   4. `decide_gesamtwehr_verbindung`  – deren Admin gibt frei oder lehnt ab.
--
-- ⚠️ Warum die Freigabe zugleich `pending` → `active` hebt: Der
-- Selbstregistrierungs-Zustand aus Phase 1 wartet genau auf eine Bürgschaft.
-- Ein Gesamtwehr-Admin, der eine Abteilung in seine Klammer aufnimmt, gibt
-- sie damit frei — eine zweite Freigabe wäre dieselbe Entscheidung zweimal.
-- Eine Abteilung, die gar keiner Gesamtwehr beitreten will, bleibt weiterhin
-- Sache des Host-Betreibers (service_role); dafür gibt es bewusst keine RPC,
-- weil es dafür in der App niemanden mit der nötigen Autorität gibt.
--
-- ⚠️ Gesamtwehr-Admin ist keine eigene Rolle, sondern eine Herleitung:
-- `role = 'admin'` in einer Abteilung, die zu dieser Gesamtwehr gehört. Das
-- deckt sich mit `can_publish_abteilung` aus Phase 1 — wer ohnehin überall in
-- der Gesamtwehr veröffentlichen darf, darf auch über Mitgliedschaft
-- entscheiden. Ein eigenes Gesamtwehr-Konto kommt frühestens mit Phase 4
-- (Auth), solange SMTP hängt.
--
-- Einspielen wie gehabt per docker exec psql als supabase_admin, danach
-- NOTIFY pgrst, 'reload schema'.

-- ── 1) Slugs: sprechend, kollisionsfrei, ohne Zutun des Clients ──────────

create function public.slugify(quelle text)
returns text
language sql
immutable
as $$
  select nullif(
    trim(both '-' from
      regexp_replace(
        regexp_replace(
          replace(replace(replace(replace(replace(replace(replace(
            lower(coalesce(quelle, '')),
            'ä', 'ae'), 'ö', 'oe'), 'ü', 'ue'), 'ß', 'ss'),
            'é', 'e'), 'è', 'e'), 'ê', 'e'),
          '[^a-z0-9]+', '-', 'g'),
        '-{2,}', '-', 'g')),
    '');
$$;

comment on function public.slugify(text) is
  'Deutscher Klartext zu URL-Slug (Umlaute ausgeschrieben, nicht transliteriert).';

-- Die Suche nach einem freien Slug muss ALLE Zeilen sehen, auch die von
-- fremden Abteilungen — sonst kollidiert der Unique-Index mit einer Zeile,
-- die RLS gerade versteckt. Deshalb security definer, und deshalb ruft sie
-- niemand von außen auf (execute bleibt beim Eigentümer).
create function public.freier_slug(basis text, tabelle text)
returns text
language plpgsql
security definer set search_path = ''
as $$
declare
  -- Ein Name ganz ohne slugfähige Zeichen (nur Satzzeichen, nur Kyrillisch)
  -- darf den Vorgang nicht sprengen — dann zählt eben der Tabellenname hoch.
  stamm text := coalesce(public.slugify(basis), tabelle);
  versuch text := stamm;
  n int := 1;
  belegt boolean;
begin
  loop
    if tabelle = 'gesamtwehren' then
      select exists (select 1 from public.gesamtwehren where slug = versuch)
        into belegt;
    else
      select exists (select 1 from public.abteilungen where slug = versuch)
        into belegt;
    end if;
    exit when not belegt;
    n := n + 1;
    versuch := stamm || '-' || n;
  end loop;
  return versuch;
end;
$$;

revoke execute on function public.slugify(text),
  public.freier_slug(text, text) from public, anon, authenticated;

-- ── 2) Gesamtwehr: Herkunft festhalten ───────────────────────────────────

alter table public.gesamtwehren
  add column created_by uuid references auth.users (id) on delete set null;

comment on column public.gesamtwehren.created_by is
  'Gründender Admin — reine Herkunftsangabe, verleiht keine Sonderrechte.';

-- ── 3) Wer darf über die Mitgliedschaft entscheiden? ─────────────────────

create function public.is_gesamtwehr_admin(ziel uuid)
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select ziel is not null and exists (
    select 1
    from public.profiles p
    join public.abteilungen a on a.id = p.abteilung_id
    where p.id = auth.uid()
      and p.role = 'admin'
      and a.gesamtwehr_id = ziel
  );
$$;

revoke execute on function public.is_gesamtwehr_admin(uuid) from public, anon;
grant execute on function public.is_gesamtwehr_admin(uuid) to authenticated;

-- ── 4) Verbindungs-Anfragen ──────────────────────────────────────────────

create table public.gesamtwehr_anfragen (
  id uuid primary key default gen_random_uuid(),
  abteilung_id uuid not null references public.abteilungen (id) on delete cascade,
  gesamtwehr_id uuid not null references public.gesamtwehren (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  nachricht text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  decided_by uuid references auth.users (id) on delete set null,
  decided_at timestamptz,
  decided_note text
);

-- Eine Abteilung hat höchstens eine offene Anfrage — sonst könnte sie sich
-- bei mehreren Gesamtwehren gleichzeitig bewerben und der zweite Zuschlag
-- liefe ins Leere.
create unique index gesamtwehr_anfragen_eine_offene
  on public.gesamtwehr_anfragen (abteilung_id) where status = 'pending';

create index gesamtwehr_anfragen_gesamtwehr_idx
  on public.gesamtwehr_anfragen (gesamtwehr_id, status);

comment on table public.gesamtwehr_anfragen is
  'Anschluss-Anfragen an eine Gesamtwehr (Issue #57 Phase 3). Geschrieben '
  'wird ausschliesslich ueber request_/decide_gesamtwehr_verbindung.';

alter table public.gesamtwehr_anfragen enable row level security;

-- Nur die eigene Seite liest mit: die anfragende Abteilung sieht ihren Stand.
-- Die entscheidende Seite bekommt ihre Liste über eine RPC (unten) — sie darf
-- die fremde Abteilung ja noch gar nicht lesen, das ist ja gerade der Antrag.
create policy "read own abteilung requests" on public.gesamtwehr_anfragen
  for select to authenticated
  using (public.can_read_abteilung(abteilung_id));

grant select on public.gesamtwehr_anfragen to authenticated;
grant all on public.gesamtwehr_anfragen to service_role;

-- ── 5) Vorgang 1: Gesamtwehr gründen ─────────────────────────────────────

create function public.create_gesamtwehr(name text)
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

  select p.abteilung_id, p.role into meine_abteilung, meine_rolle
    from public.profiles p where p.id = auth.uid();

  if meine_rolle is distinct from 'admin' then
    raise exception 'permission denied: admin role required'
      using errcode = 'P0001';
  end if;
  if meine_abteilung is null then
    raise exception 'no abteilung assigned' using errcode = 'P0001';
  end if;

  -- Sperren, damit zwei Admins derselben Abteilung nicht zwei Klammern bauen.
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

  return neue_id;
end;
$$;

-- ── 6) Vorgang 2: weitere Abteilung anlegen ──────────────────────────────
-- Bewusst nur INNERHALB der eigenen Gesamtwehr: zwei Abteilungen ohne
-- gemeinsame Klammer sähen einander nicht und niemand könnte die zweite
-- freigeben. Wer eine zweite anlegt, will die Klammer.

create function public.create_abteilung(name text)
returns uuid
language plpgsql
security definer set search_path = ''
as $$
declare
  meine_abteilung uuid;
  meine_gesamtwehr uuid;
  meine_rolle text;
  neue_id uuid;
  sauber text := btrim(coalesce(name, ''));
begin
  if sauber = '' then
    raise exception 'name required' using errcode = 'P0001';
  end if;

  -- Rolle und Abteilung getrennt lesen: ein Join würde ein Profil ohne
  -- Abteilung als „keine Rolle" ausgeben und die Ursache verschleiern.
  select p.abteilung_id, p.role into meine_abteilung, meine_rolle
    from public.profiles p where p.id = auth.uid();

  if meine_rolle is distinct from 'admin' then
    raise exception 'permission denied: admin role required'
      using errcode = 'P0001';
  end if;
  if meine_abteilung is null then
    raise exception 'no abteilung assigned' using errcode = 'P0001';
  end if;

  select gesamtwehr_id into meine_gesamtwehr
    from public.abteilungen where id = meine_abteilung;
  if meine_gesamtwehr is null then
    raise exception 'gesamtwehr required: create or join one first'
      using errcode = 'P0001';
  end if;

  -- Aktiv ab Sekunde eins: Der anlegende Admin darf laut
  -- can_publish_abteilung ohnehin in jeder Abteilung seiner Gesamtwehr
  -- veröffentlichen — eine Freigabe an sich selbst wäre eine Attrappe.
  insert into public.abteilungen (gesamtwehr_id, name, slug, status)
  values (meine_gesamtwehr, sauber,
          public.freier_slug(sauber, 'abteilungen'), 'active')
  returning id into neue_id;

  return neue_id;
end;
$$;

-- ── 7) Vorgang 3: Anschluss beantragen ───────────────────────────────────

create function public.request_gesamtwehr_verbindung(
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
  -- ⚠️ Der Parameter heißt wie die Spalte `gesamtwehr_anfragen.nachricht`.
  -- In einem UPDATE/INSERT-Kontext ist das mehrdeutig und plpgsql bricht mit
  -- 42702 ab. Einmal in eine eigene Variable ziehen, dann nur die verwenden.
  notiz text := nullif(btrim(coalesce(nachricht, '')), '');
begin
  select p.abteilung_id, p.role into meine_abteilung, meine_rolle
    from public.profiles p where p.id = auth.uid();

  if meine_rolle not in ('admin', 'geraetewart') then
    raise exception 'permission denied: admin or geraetewart role required'
      using errcode = 'P0001';
  end if;
  if meine_abteilung is null then
    raise exception 'no abteilung assigned' using errcode = 'P0001';
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

-- ── 8) Vorgang 4: entscheiden ────────────────────────────────────────────

create function public.decide_gesamtwehr_verbindung(
  anfrage uuid,
  freigeben boolean,
  nachricht text default null
)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  a public.gesamtwehr_anfragen%rowtype;
  aktuelle_gesamtwehr uuid;
  -- Gleiche Falle wie oben: `nachricht` heißt wie eine Spalte der Tabelle,
  -- die dieses UPDATE anfasst.
  notiz text := nullif(btrim(coalesce(nachricht, '')), '');
begin
  select * into a from public.gesamtwehr_anfragen
   where id = anfrage for update;
  if not found then
    raise exception 'request not found' using errcode = 'P0001';
  end if;
  if not public.is_gesamtwehr_admin(a.gesamtwehr_id) then
    raise exception 'permission denied: admin of this gesamtwehr required'
      using errcode = 'P0001';
  end if;
  if a.status <> 'pending' then
    raise exception 'request already decided (%)', a.status
      using errcode = 'P0001';
  end if;

  if freigeben then
    -- Zwischenzeitlicher Beitritt anderswo: lieber abbrechen als überschreiben.
    select gesamtwehr_id into aktuelle_gesamtwehr
      from public.abteilungen where id = a.abteilung_id for update;
    if aktuelle_gesamtwehr is not null then
      raise exception 'abteilung already belongs to a gesamtwehr'
        using errcode = 'P0001';
    end if;

    update public.abteilungen
       set gesamtwehr_id = a.gesamtwehr_id,
           -- Die Aufnahme IST die Freigabe, siehe Kopfkommentar.
           status = case when status = 'pending' then 'active' else status end
     where id = a.abteilung_id;
  end if;

  update public.gesamtwehr_anfragen
     set status = case when freigeben then 'approved' else 'rejected' end,
         decided_by = auth.uid(),
         decided_at = now(),
         decided_note = notiz
   where id = anfrage;
end;
$$;

-- ── 9) Die Liste für den entscheidenden Admin ────────────────────────────
-- Muss eine RPC sein: Die anfragende Abteilung ist noch keine Schwester,
-- `abteilungen` gibt ihren Namen über RLS also nicht heraus. Genau das ist
-- der Antrag. Wir geben deshalb hier — und nur hier — Name und Slug der
-- anfragenden Abteilung an den Admin heraus, dem die Entscheidung obliegt.

create function public.offene_verbindungsanfragen()
returns table (
  id uuid,
  abteilung_id uuid,
  abteilung_name text,
  abteilung_slug text,
  nachricht text,
  created_at timestamptz
)
language sql
security definer set search_path = ''
stable
as $$
  select r.id, r.abteilung_id, a.name, a.slug, r.nachricht, r.created_at
    from public.gesamtwehr_anfragen r
    join public.abteilungen a on a.id = r.abteilung_id
   where r.status = 'pending'
     and public.is_gesamtwehr_admin(r.gesamtwehr_id)
   order by r.created_at;
$$;

comment on function public.offene_verbindungsanfragen() is
  'Offene Anfragen an die Gesamtwehr des Aufrufers. Gibt bewusst Name/Slug '
  'einer noch fremden Abteilung heraus — ohne sie waere die Entscheidung blind.';

-- ── 10) Grants: explizit, wegen der frueheren PUBLIC-EXECUTE-Regression ──

revoke execute on function
  public.create_gesamtwehr(text),
  public.create_abteilung(text),
  public.request_gesamtwehr_verbindung(uuid, text),
  public.decide_gesamtwehr_verbindung(uuid, boolean, text),
  public.offene_verbindungsanfragen()
from public, anon;

grant execute on function
  public.create_gesamtwehr(text),
  public.create_abteilung(text),
  public.request_gesamtwehr_verbindung(uuid, text),
  public.decide_gesamtwehr_verbindung(uuid, boolean, text),
  public.offene_verbindungsanfragen()
to authenticated;
