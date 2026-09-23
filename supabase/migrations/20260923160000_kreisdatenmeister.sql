-- kreisdatenmeister.sql – Der Betreiber der Installation und seine Konsole
-- (Nutzerkonzept Stufe ④, Issue #101), Server-Teil.
--
-- Bis hierher ist der KreisDatenMeister niemand Bestimmtes: Wer den
-- Service-Role-Key der VM hat, ist es. Das reicht für einen Betreiber mit
-- SSH-Zugang, aber nicht für eine Konsole in der App — die braucht ein
-- Konto, an dem das Recht hängt, und dieses Recht muss die Datenbank
-- prüfen, nicht die Oberfläche (AGENTS.md: Sicherheit liegt in RLS).
--
-- Entschieden mit Marcus am 2026-09-23 (Kommentar in #101):
--   * KEIN Antragsformular. Eine neue Wehr meldet sich per Mail oder
--     Telefon; der KreisDatenMeister legt sie in der Konsole an und lädt
--     ihren ersten Feuerwehrkommandanten ein. Es gibt damit keinen
--     anonymen Schreibweg auf den Server. Die Login-Seite zeigt nur eine
--     Kontaktzeile (`installation_kontakt`).
--   * Konsole v1: Übersicht, anlegen + einladen, Notfall-Kommandant,
--     stilllegen.
--   * Ein Abteilungs-Admin ohne Gesamtwehr darf WEITERHIN selbst eine
--     gründen (`create_gesamtwehr` bleibt unverändert).
--
-- ⚠️ Der KreisDatenMeister ist KEIN Über-Kommandant. Er bekommt genau die
-- Rechte, die die Konsole braucht (sehen, anlegen, einladen, ernennen,
-- stilllegen) — nicht die Rechte eines Feuerwehrkommandanten in jeder Wehr.
-- `is_gesamtwehr_admin` bleibt deshalb unangetastet: Stünde er dort drin,
-- könnte er in jeder Wehr umbenennen, das Branding setzen, Lernbereiche
-- abschalten und Mitglieder verwalten, ohne dass es je jemand beschlossen
-- hätte. Was er zusätzlich darf, steht einzeln und begründet unten.

-- ── 1) Wer der KreisDatenMeister ist ─────────────────────────────────────

create table public.betreiber (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  -- Die Zeile, die auf der Login-Seite steht („Deine Wehr ist noch nicht
  -- dabei? …"). Freitext, weil es eine Mail-Adresse, eine Telefonnummer
  -- oder beides sein kann. Leer = keine Kontaktzeile.
  --
  -- ⚠️ Sie ist ÖFFENTLICH — jeder mit dem Anon-Key (also jeder mit der App)
  -- kann sie lesen. Genau dafür ist sie da; wer seine private Adresse nicht
  -- zeigen will, trägt eine Funktionsadresse ein.
  kontakt    text check (kontakt is null or length(btrim(kontakt)) between 1 and 200),
  created_at timestamptz not null default now()
);

comment on table public.betreiber is
  'KreisDatenMeister dieser Installation (Issue #101). Gesetzt per '
  'tool/vm/fwapp_betreiber.sh auf dem Server, nie aus der App.';

alter table public.betreiber enable row level security;

-- Jeder sieht höchstens die eigene Zeile — die App fragt damit „bin ich
-- es?" und sonst nichts. Wer außer einem selbst Betreiber ist, geht
-- niemanden etwas an.
create policy "eigene Betreiber-Zeile"
  on public.betreiber for select
  to authenticated
  using (user_id = auth.uid());

grant select on public.betreiber to authenticated;
grant all    on public.betreiber to service_role;
revoke insert, update, delete, truncate, references, trigger
  on public.betreiber from anon, authenticated, public;
revoke select on public.betreiber from anon, public;

-- Policy-Helfer. EXECUTE bleibt für authenticated, weil Policies und die
-- Rechte-Helfer weiter unten mit den Rechten des Aufrufers auswerten.
create function public.ist_betreiber()
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select exists (
    select 1 from public.betreiber b where b.user_id = auth.uid()
  );
$$;

revoke execute on function public.ist_betreiber() from public, anon;
grant execute on function public.ist_betreiber() to authenticated, service_role;

-- Die Kontaktzeile für die Login-Seite. Die einzige Stelle dieser Migration,
-- die `anon` erreicht — vor dem Anmelden gibt es kein anderes Konto.
create function public.installation_kontakt()
returns text
language sql
security definer set search_path = ''
stable
as $$
  select b.kontakt from public.betreiber b
   where b.kontakt is not null
   order by b.created_at
   limit 1;
$$;

comment on function public.installation_kontakt() is
  'Oeffentliche Kontaktzeile des KreisDatenMeisters fuer die Login-Seite '
  '(Issue #101). Absichtlich fuer anon aufrufbar.';

revoke execute on function public.installation_kontakt() from public;
grant execute on function public.installation_kontakt()
  to anon, authenticated, service_role;

-- ── 2) Stilllegen ────────────────────────────────────────────────────────
--
-- ⚠️ STILLGELEGT HEISST: SCHREIBEN GESPERRT, LESEN NICHT.
-- Der naheliegende Entwurf — eine stillgelegte Wehr sieht nichts mehr —
-- wäre ein Datenverlust auf den Geräten: Der nächste Zug bekäme eine leere
-- Antwort und hielte sie für „alles gelöscht" (`_applySnapshot` löscht, was
-- der Server nicht mehr kennt). Local-first heißt: Was auf dem Handy liegt,
-- bleibt dort. Gesperrt wird deshalb nur, was den Bestand der Wehr
-- verändert — Veröffentlichen, Anhänge, Codes, Gerätetypen, die
-- Wissensdatenbank und Einladungen. Lernen geht weiter.
alter table public.gesamtwehren
  add column stillgelegt_am timestamptz;

comment on column public.gesamtwehren.stillgelegt_am is
  'Gesetzt = stillgelegt durch den KreisDatenMeister (Issue #101): '
  'Schreibwege gesperrt, Lesen bleibt. Rueckgaengig ueber die Konsole.';

-- `null` (Abteilung ohne Gesamtwehr) ist aktiv — die eigenständige
-- Abteilung hat niemanden, der sie stilllegen könnte.
create function public.gesamtwehr_aktiv(ziel uuid)
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select ziel is null or not exists (
    select 1 from public.gesamtwehren g
     where g.id = ziel and g.stillgelegt_am is not null
  );
$$;

revoke execute on function public.gesamtwehr_aktiv(uuid) from public, anon;
grant execute on function public.gesamtwehr_aktiv(uuid)
  to authenticated, service_role;

-- Die Schreib-Helfer, jeweils wortgleich zur letzten Fassung plus EINE
-- Bedingung am Ende. Sie hängen an den Policies von Bestand, Anhängen,
-- Fotos und Codes (can_publish_abteilung) bzw. an Gerätetypen und
-- Wissensdatenbank (can_write_gesamtwehr_types) — eine Stelle je Ebene
-- statt einer Bedingung in jeder Policy.

create or replace function public.can_publish_abteilung(target uuid)
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select (
    exists (
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
    )
    or public.hat_temporaeres_recht(target)
  )
  and public.gesamtwehr_aktiv(
    (select a.gesamtwehr_id from public.abteilungen a where a.id = target)
  );
$$;

create or replace function public.can_write_gesamtwehr_types(ziel uuid)
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select (
    exists (
      select 1 from public.memberships m
      join public.abteilungen a on a.id = m.abteilung_id
      where m.user_id = auth.uid()
        and a.gesamtwehr_id = ziel
        and m.role in ('admin', 'geraetewart')
    )
    or exists (
      select 1 from public.gesamtwehr_kommandanten k
      where k.user_id = auth.uid() and k.gesamtwehr_id = ziel
    )
  )
  and public.gesamtwehr_aktiv(ziel);
$$;

-- Einreichen in die Wissensdatenbank hing am LESE-Helfer (jedes Mitglied
-- darf vorschlagen). Den Lese-Helfer anzufassen hieße, einer stillgelegten
-- Wehr das Lesen zu nehmen — also bekommt die eine Policy die Bedingung.
drop policy "jedes mitglied reicht ein" on public.quiz_questions;
create policy "jedes mitglied reicht ein" on public.quiz_questions
  for insert to authenticated
  with check (
    public.can_read_gesamtwehr(gesamtwehr_id)
    and public.gesamtwehr_aktiv(gesamtwehr_id)
    and stand = 'eingereicht'
    and created_by = auth.uid()
  );

-- ── 3) Einladen dürfen ───────────────────────────────────────────────────
--
-- Der KreisDatenMeister lädt ein, damit eine neue Wehr zu ihrem ersten
-- Kommandanten kommt und eine ausgesperrte zu einem neuen. Er bekommt das
-- Einladungsrecht in jeder Abteilung — das ist weniger, als es klingt: Er
-- hat den Service-Role-Key ohnehin, und die Einladung braucht immer noch
-- die Bestätigung der eingeladenen Adresse.
--
-- Die Edge Function `admin-users` prüft das Recht NICHT selbst, sie ruft
-- `einladung_anlegen` mit dem JWT des Aufrufers (siehe ihr Dateikopf). Mit
-- diesen zwei Änderungen funktioniert deshalb der bestehende Mailweg samt
-- Vorlage, Brücke und Zustellauskunft auch für die Konsole — kein zweiter
-- Versandweg, der auseinanderlaufen könnte.

create or replace function public.darf_mitglieder_verwalten(
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
       and public.gesamtwehr_aktiv(a.gesamtwehr_id)
       and (
         -- KreisDatenMeister (Issue #101): in jeder Abteilung.
         public.ist_betreiber()
         or
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

create or replace function public.einladung_anlegen(
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
  if sauber_mail !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]{2,}$' then
    raise exception 'invalid email' using errcode = 'P0001';
  end if;
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
    -- Aussperr-Schutz (docs/NUTZERKONZEPT.md §3): Einen Feuerwehr-
    -- kommandanten ernennt ein Feuerwehrkommandant — oder der
    -- KreisDatenMeister, für den ersten einer neuen Wehr und für den Fall,
    -- dass der einzige nicht mehr herankommt (Issue #101).
    if not (public.is_gesamtwehr_admin(ziel_gesamtwehr)
            or public.ist_betreiber()) then
      raise exception 'permission denied: feuerwehrkommandant required'
        using errcode = 'P0001';
    end if;
  end if;

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

-- ── 4) Die Konsole ───────────────────────────────────────────────────────
--
-- Alle vier Funktionen prüfen als ERSTES `ist_betreiber()`. Die Route in
-- der App ist nicht verlinkt und hat einen Guard — beides Komfort; die
-- Schutzschicht ist diese Zeile.

-- Übersicht: je Gesamtwehr, was man braucht, um zu sehen, ob sie lebt.
-- Bewusst KEINE Namen einfacher Mitglieder: Der KreisDatenMeister betreibt
-- die Instanz, er führt nicht die Mitgliederliste fremder Wehren. Die
-- Kommandanten stehen drin, weil sie seine Ansprechpartner sind.
create function public.kdm_gesamtwehren()
returns table (
  id                      uuid,
  name                    text,
  created_at              timestamptz,
  stillgelegt_am          timestamptz,
  abteilungen             jsonb,
  mitglieder              int,
  kommandanten            jsonb,
  offene_einladungen      int,
  zuletzt_veroeffentlicht timestamptz
)
language plpgsql
security definer set search_path = ''
stable
as $$
#variable_conflict use_column
begin
  if not public.ist_betreiber() then
    raise exception 'Nur fuer den KreisDatenMeister' using errcode = '42501';
  end if;

  return query
  select g.id,
         g.name,
         g.created_at,
         g.stillgelegt_am,
         coalesce((
           select jsonb_agg(jsonb_build_object('id', a.id, 'name', a.name)
                            order by a.name)
             from public.abteilungen a where a.gesamtwehr_id = g.id
         ), '[]'::jsonb),
         (select count(distinct m.user_id)::int
            from public.memberships m
            join public.abteilungen a on a.id = m.abteilung_id
           where a.gesamtwehr_id = g.id),
         coalesce((
           select jsonb_agg(jsonb_build_object(
                    'user_id', k.user_id,
                    'name', coalesce(nullif(btrim(p.anzeigename), ''),
                                     p.username),
                    'email', u.email)
                  order by k.created_at)
             from public.gesamtwehr_kommandanten k
             join public.profiles p on p.id = k.user_id
             left join auth.users u on u.id = k.user_id
            where k.gesamtwehr_id = g.id
         ), '[]'::jsonb),
         (select count(*)::int
            from public.einladungen e
            join public.abteilungen a on a.id = e.abteilung_id
           where a.gesamtwehr_id = g.id
             and e.angenommen_am is null
             and e.zurueckgezogen_am is null),
         (select max(a.published_at)
            from public.abteilungen a where a.gesamtwehr_id = g.id)
    from public.gesamtwehren g
   order by g.name;
end;
$$;

-- Anlegen: Gesamtwehr und ihre erste Abteilung in einem Zug. Ohne
-- Abteilung gäbe es nichts, wohin der erste Kommandant eingeladen werden
-- könnte (`einladungen.abteilung_id` ist Pflicht).
--
-- ⚠️ Der KreisDatenMeister wird dabei NICHT Mitglied oder Kommandant der
-- neuen Wehr. `create_gesamtwehr` macht den Gründer zum Kommandanten — hier
-- wäre das falsch: Er richtet sie für andere ein.
create function public.kdm_lege_gesamtwehr_an(
  p_name text,
  p_abteilung text
)
returns table (gesamtwehr_id uuid, abteilung_id uuid)
language plpgsql
security definer set search_path = ''
as $$
#variable_conflict use_column
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_abt text := btrim(coalesce(p_abteilung, ''));
  v_gw uuid;
  v_ab uuid;
begin
  if not public.ist_betreiber() then
    raise exception 'Nur fuer den KreisDatenMeister' using errcode = '42501';
  end if;
  if v_name = '' or v_abt = '' then
    raise exception 'Name der Wehr und der ersten Abteilung noetig'
      using errcode = '22023';
  end if;

  insert into public.gesamtwehren (name, slug, created_by)
  values (v_name, public.freier_slug(v_name, 'gesamtwehren'), auth.uid())
  returning id into v_gw;

  -- 'active' sofort: Die Wehr ist genehmigt, sonst stünde sie nicht hier.
  insert into public.abteilungen (gesamtwehr_id, name, slug, status)
  values (v_gw, v_abt, public.freier_slug(v_abt, 'abteilungen'), 'active')
  returning id into v_ab;

  return query select v_gw, v_ab;
end;
$$;

-- Notfall: ein VORHANDENES Konto zum Feuerwehrkommandanten machen.
--
-- Der Fall, für den das gebraucht wird: Der einzige Kommandant ist
-- weggezogen oder kommt nicht mehr an sein Konto, und sein Nachfolger ist
-- längst Mitglied der Wehr. Einladen geht dann nicht — `einladung_anlegen`
-- lehnt eine Adresse mit bestätigtem Konto ab. Für eine Adresse OHNE Konto
-- nimmt die Konsole den Einladungsweg; diese Funktion sagt das mit ihrer
-- Meldung.
create function public.kdm_ernenne_kommandant(
  p_gesamtwehr uuid,
  p_email text
)
returns uuid
language plpgsql
security definer set search_path = ''
as $$
declare
  v_user uuid;
begin
  if not public.ist_betreiber() then
    raise exception 'Nur fuer den KreisDatenMeister' using errcode = '42501';
  end if;
  if not exists (select 1 from public.gesamtwehren g where g.id = p_gesamtwehr)
  then
    raise exception 'Diese Gesamtwehr gibt es nicht' using errcode = 'P0002';
  end if;

  select u.id into v_user
    from auth.users u
   where lower(u.email) = lower(btrim(coalesce(p_email, '')))
     and u.email_confirmed_at is not null;
  if v_user is null then
    raise exception 'Kein bestaetigtes Konto zu dieser Adresse - bitte einladen'
      using errcode = 'P0002';
  end if;

  insert into public.gesamtwehr_kommandanten (user_id, gesamtwehr_id)
  values (v_user, p_gesamtwehr)
  on conflict do nothing;
  -- Alt-Clients lesen die Rolle aus dem Profil (wie `set_kommandant` in
  -- der Edge Function).
  perform public.sync_profile_mirror(v_user);
  return v_user;
end;
$$;

create function public.kdm_stilllegen(p_gesamtwehr uuid, p_still boolean)
returns void
language plpgsql
security definer set search_path = ''
as $$
begin
  if not public.ist_betreiber() then
    raise exception 'Nur fuer den KreisDatenMeister' using errcode = '42501';
  end if;
  update public.gesamtwehren g
     set stillgelegt_am = case when p_still then coalesce(g.stillgelegt_am, now())
                               else null end
   where g.id = p_gesamtwehr;
  if not found then
    raise exception 'Diese Gesamtwehr gibt es nicht' using errcode = 'P0002';
  end if;
end;
$$;

comment on function public.kdm_gesamtwehren() is
  'Konsole des KreisDatenMeisters: alle Gesamtwehren mit Kennzahlen (#101).';
comment on function public.kdm_lege_gesamtwehr_an(text, text) is
  'Konsole: Gesamtwehr samt erster Abteilung anlegen (#101). Der Aufrufer '
  'wird bewusst nicht Mitglied.';
comment on function public.kdm_ernenne_kommandant(uuid, text) is
  'Konsole, Notfall: vorhandenes bestaetigtes Konto zum '
  'Feuerwehrkommandanten machen (#101). Ohne Konto: einladen.';
comment on function public.kdm_stilllegen(uuid, boolean) is
  'Konsole: Gesamtwehr stilllegen (true) oder reaktivieren (false). '
  'Stillgelegt sperrt Schreibwege, nicht das Lesen (#101).';

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.kdm_gesamtwehren()',
    'public.kdm_lege_gesamtwehr_an(text, text)',
    'public.kdm_ernenne_kommandant(uuid, text)',
    'public.kdm_stilllegen(uuid, boolean)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated, service_role', f);
  end loop;
end;
$$;
