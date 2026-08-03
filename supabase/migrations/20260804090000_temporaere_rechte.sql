-- 20260804090000_temporaere_rechte.sql – Temporäre Gerätewart-Rechte
-- (Nutzerkonzept Stufe ③, Issue #100).
--
-- Zweck: Bei einer Übung soll ein Truppführer Geräte, Fächer und Fahrzeuge
-- anlegen dürfen, ohne dass daraus eine dauerhafte Rolle wird. Der Gerätewart
-- (oder höher) erteilt das AKTIV, mit Ablauf, sichtbar beim Empfänger und
-- protokolliert.
--
-- VIER FESTLEGUNGEN, die den Rest erklären:
--
-- 1. DIE TABELLE IST DAS PROTOKOLL. Zeilen werden nie gelöscht; Zurückziehen
--    setzt eine Spalte. „Wer wem wann" ist damit nicht ein Nebenprodukt,
--    sondern der Datentyp selbst — ein separates Log könnte auseinanderlaufen.
--
-- 2. TEMPORÄRE RECHTE SCHALTEN NUR DAS BEARBEITEN FREI, NIE DAS VERWALTEN.
--    `can_publish_abteilung` und `is_editor` berücksichtigen sie,
--    `darf_mitglieder_verwalten` und `is_gesamtwehr_admin` ausdrücklich NICHT.
--    Sonst könnte sich ein Übungsteilnehmer für zwölf Stunden selbst zum
--    Kommandanten machen — und das Recht danach behalten.
--
-- 3. DER EMPFÄNGER MUSS SCHON MITGLIED DER ABTEILUNG SEIN. Ein temporäres
--    Recht ist eine Erweiterung, kein Zugang: Es darf niemandem Lesezugriff
--    auf einen fremden Bestand verschaffen, den er vorher nicht hatte.
--
-- 4. DER ABLAUF KOMMT VOM CLIENT, NICHT AUS SQL. „Bis Tagesende" hängt an der
--    Zeitzone des Geräts; der Server kennt sie nicht und läge in der Nacht
--    daneben. Er prüft stattdessen nur die Grenzen: in der Zukunft, höchstens
--    24 Stunden. Was „Tagesende" heißt, entscheidet das Gerät.

create table public.temporaere_rechte (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  abteilung_id  uuid not null references public.abteilungen (id) on delete cascade,
  -- Heute gibt es nur eine temporäre Rolle. Die Spalte steht trotzdem da:
  -- Ohne sie wäre eine zweite später eine Tabellenänderung samt
  -- Alt-Client-Choreografie, mit ihr ein zusätzlicher Wert.
  rolle         text not null default 'geraetewart'
                  check (rolle in ('geraetewart')),
  erteilt_von   uuid references auth.users (id) on delete set null,
  erteilt_am    timestamptz not null default now(),
  laeuft_ab     timestamptz not null,
  zurueckgezogen_am  timestamptz,
  zurueckgezogen_von uuid references auth.users (id) on delete set null
);

-- Höchstens ein LAUFENDES Recht je Person und Abteilung. Abgelaufene und
-- zurückgezogene Zeilen bleiben liegen — sie sind das Protokoll.
create unique index temporaere_rechte_laufend_idx
  on public.temporaere_rechte (user_id, abteilung_id)
  where zurueckgezogen_am is null;

create index temporaere_rechte_abteilung_idx
  on public.temporaere_rechte (abteilung_id, erteilt_am desc);

-- ── Der Rechte-Helfer ───────────────────────────────────────────────────────
-- Bewusst ohne `zurueckgezogen_am is null`-Index-Abhängigkeit formuliert:
-- Die Frage ist „gilt gerade", und das sind beide Bedingungen zusammen.
create function public.hat_temporaeres_recht(ziel uuid)
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select exists (
    select 1 from public.temporaere_rechte r
     where r.user_id = auth.uid()
       and r.abteilung_id = ziel
       and r.zurueckgezogen_am is null
       and r.laeuft_ab > now()
  );
$$;

revoke execute on function public.hat_temporaeres_recht(uuid) from public, anon;
grant execute on function public.hat_temporaeres_recht(uuid)
  to authenticated, service_role;

comment on function public.hat_temporaeres_recht(uuid) is
  'Gilt für den Angemeldeten in dieser Abteilung gerade ein temporäres '
  'Gerätewart-Recht? Schaltet NUR Bearbeiten frei, nie Verwalten.';

-- ── Die bestehenden Schreibrecht-Helfer erweitern ───────────────────────────
-- ⚠️ NUR diese beiden. can_read_abteilung braucht es nicht (der Empfänger ist
-- ohnehin Mitglied, siehe Festlegung 3), darf_mitglieder_verwalten und
-- is_gesamtwehr_admin bekommen es NICHT (Festlegung 2).
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
  )
  or public.hat_temporaeres_recht(target);
$$;

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
  )
  or exists (
    select 1 from public.temporaere_rechte r
     where r.user_id = auth.uid()
       and r.zurueckgezogen_am is null
       and r.laeuft_ab > now()
  );
$$;

-- ── Wer darf erteilen ───────────────────────────────────────────────────────
-- Gerätewart ODER Abteilungskommandant DIESER Abteilung, oder der
-- Feuerwehrkommandant der Gesamtwehr. Also genau die, die dort ohnehin
-- schreiben dürfen — ein Recht weitergeben kann nur, wer es selbst hat.
create function public.darf_temporaeres_recht_erteilen(ziel_abteilung uuid)
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select exists (
    select 1 from public.memberships m
     where m.user_id = auth.uid()
       and m.abteilung_id = ziel_abteilung
       and m.role in ('admin', 'geraetewart')
  )
  or exists (
    select 1
      from public.gesamtwehr_kommandanten k
      join public.abteilungen a on a.id = ziel_abteilung
     where k.user_id = auth.uid()
       and a.gesamtwehr_id = k.gesamtwehr_id
  );
$$;

revoke execute on function public.darf_temporaeres_recht_erteilen(uuid)
  from public, anon;
grant execute on function public.darf_temporaeres_recht_erteilen(uuid)
  to authenticated, service_role;

-- ── RLS ─────────────────────────────────────────────────────────────────────
alter table public.temporaere_rechte enable row level security;

-- Lesen: die eigenen Rechte (der Hinweis beim Empfänger hängt daran) und
-- alles in den Abteilungen, in denen man selbst erteilen darf (das Protokoll).
create policy "eigene und verwaltete temporaere rechte lesen"
  on public.temporaere_rechte
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.darf_temporaeres_recht_erteilen(abteilung_id)
  );

-- Geschrieben wird ausschließlich über die RPCs darunter. Keine
-- Schreib-Policy — wie bei abteilungen und gesamtwehren.

-- ⚠️ Tabellenrechte müssen ausdrücklich vergeben werden: Eine RLS-Policy
-- ERLAUBT Zeilen, sie ersetzt aber kein GRANT. Ohne diese beiden Zeilen
-- antwortet PostgREST mit „permission denied for table" — auch dem
-- service_role, der RLS sonst umgeht. Gleiches Muster wie bei einladungen.
grant select on public.temporaere_rechte to authenticated;
grant all on public.temporaere_rechte to service_role;

-- ── Erteilen ────────────────────────────────────────────────────────────────
create function public.temp_recht_erteilen(
  ziel_user uuid,
  ziel_abteilung uuid,
  bis timestamptz
)
returns uuid
language plpgsql
security definer set search_path = ''
as $$
declare
  neue_id uuid;
begin
  if not public.darf_temporaeres_recht_erteilen(ziel_abteilung) then
    raise exception 'permission denied: temporaeres recht erteilen'
      using errcode = 'P0001';
  end if;

  -- Festlegung 3: Erweiterung, kein Zugang.
  if not exists (
    select 1 from public.memberships m
     where m.user_id = ziel_user and m.abteilung_id = ziel_abteilung
  ) then
    raise exception 'not a member' using errcode = 'P0001';
  end if;

  -- Wer dort ohnehin schreiben darf, braucht nichts Temporäres. Das
  -- abzufangen ist keine Schikane: Sonst stünde bei einem Gerätewart ein
  -- Hinweis „Rechte laufen um 18 Uhr ab", der schlicht nicht stimmt.
  if exists (
    select 1 from public.memberships m
     where m.user_id = ziel_user and m.abteilung_id = ziel_abteilung
       and m.role in ('admin', 'geraetewart')
  ) then
    raise exception 'already permanent' using errcode = 'P0001';
  end if;

  if bis is null or bis <= now() then
    raise exception 'expiry must be in the future' using errcode = 'P0001';
  end if;
  -- Festlegung 4: Der Client bestimmt den Zeitpunkt, der Server die Grenze.
  -- Länger als einen Tag ist keine Übung mehr, sondern eine Rolle.
  if bis > now() + interval '24 hours' then
    raise exception 'expiry too far away' using errcode = 'P0001';
  end if;

  -- Ein zweites Erteilen verlängert, statt an der Eindeutigkeit zu scheitern
  -- — im Gerätehaus ist „nochmal bis 20 Uhr" der Normalfall.
  insert into public.temporaere_rechte
    (user_id, abteilung_id, erteilt_von, laeuft_ab)
  values (ziel_user, ziel_abteilung, auth.uid(), bis)
  on conflict (user_id, abteilung_id) where zurueckgezogen_am is null
  do update set laeuft_ab = excluded.laeuft_ab,
                erteilt_von = excluded.erteilt_von,
                erteilt_am = now()
  returning id into neue_id;

  return neue_id;
end;
$$;

revoke execute on function public.temp_recht_erteilen(uuid, uuid, timestamptz)
  from public, anon;
grant execute on function public.temp_recht_erteilen(uuid, uuid, timestamptz)
  to authenticated, service_role;

comment on function public.temp_recht_erteilen(uuid, uuid, timestamptz) is
  'Erteilt temporäre Gerätewart-Rechte bis zum angegebenen Zeitpunkt '
  '(höchstens 24 h). Erneutes Erteilen verlängert.';

-- ── Zurückziehen ────────────────────────────────────────────────────────────
create function public.temp_recht_zurueckziehen(ziel uuid)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  abteilung uuid;
begin
  select r.abteilung_id into abteilung
    from public.temporaere_rechte r
   where r.id = ziel and r.zurueckgezogen_am is null;
  if abteilung is null then
    raise exception 'not found' using errcode = 'P0001';
  end if;
  if not public.darf_temporaeres_recht_erteilen(abteilung) then
    raise exception 'permission denied: temporaeres recht erteilen'
      using errcode = 'P0001';
  end if;

  update public.temporaere_rechte
     set zurueckgezogen_am = now(),
         zurueckgezogen_von = auth.uid()
   where id = ziel;
end;
$$;

revoke execute on function public.temp_recht_zurueckziehen(uuid)
  from public, anon;
grant execute on function public.temp_recht_zurueckziehen(uuid)
  to authenticated, service_role;
