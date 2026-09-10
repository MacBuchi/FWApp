-- lernbereiche_abschalten.sql – Der Gerätewart entscheidet, was gelernt wird.
--
-- Marcus' Wunsch (2026-08-28): „vielleicht sollte der Gerätewart auch
-- befähigt sein einzelne Kapitel zu de-aktivieren."
--
-- ── Warum eine eigene Tabelle und keine Einstellung am Gerät ────────────────
-- Weil die Entscheidung für die WEHR gilt, nicht für ein Handy. Schaltet der
-- Gerätewart den Strahlenschutz ab, weil seine Wehr keinen A-Einsatz fährt,
-- dann darf die Frage auf keinem Gerät der Wehr mehr kommen — sonst übt einer
-- weiter Stoff, den die Wehr bewusst abgewählt hat, und niemand versteht,
-- warum. Vorbild ist `gesamtwehr_branding` (20260803090000): eigene Tabelle,
-- Lesen per RLS über `can_read_gesamtwehr`, Schreiben ausschließlich über eine
-- geprüfte Funktion.
--
-- ── Warum Gebiet UND Kapitel, mit `kapitel = NULL` als „ganzes Gebiet" ──────
-- Unterkapitel tragen heute nur die ABC-Fragen aus #193 (sieben Stück unter
-- „Gefahrgut"); die übrigen zehn Sachgebiete haben keine. Nur Kapitel
-- abschaltbar zu machen hieße also: Die Funktion wirkt in genau einem Gebiet.
-- Eine Wehr ohne Atemschutzgeräteträger will aber „Atemschutz" als Ganzes
-- abwählen können. Eine Zeile mit `kapitel = NULL` heißt deshalb: das ganze
-- Gebiet. Das kostet eine Spalte und keine zweite Tabelle.
--
-- ── Was „abgeschaltet" heißt ───────────────────────────────────────────────
-- Nicht mehr gefragt, aber auffindbar (Marcus, 2026-09-10). Die Fragen kommen
-- im Quiz und im Party-Modus nicht mehr dran und zählen nicht beim
-- Lernfortschritt; in der Wissensdatenbank bleiben sie sichtbar und tragen
-- die Markierung „Abgeschaltet". Wissen wird nicht versteckt, es wird nur
-- nicht abgefragt.
--
-- ── Warum kein `deleted_at` ────────────────────────────────────────────────
-- Anders als bei `quiz_questions` gibt es hier nichts weich zu löschen. Die
-- App zieht IMMER die vollständige Liste einer Wehr (es sind Dutzende Zeilen,
-- keine Tausende) und ersetzt ihren lokalen Spiegel damit. Eine Zeile, die
-- der Server nicht mehr liefert, ist wieder eingeschaltet — genau das soll
-- sie sein. Geschrieben wird ohnehin nur online über die Funktion unten, es
-- gibt also keinen lokalen Stand, den ein voller Zug überfahren könnte.

create table if not exists public.abgeschaltete_lernbereiche (
  id               uuid primary key default gen_random_uuid(),
  gesamtwehr_id    uuid not null
    references public.gesamtwehren (id) on delete cascade,
  -- Schlüssel aus `Wissensgebiet`, z. B. 'gefahrgut'. Bewusst kein Fremd-
  -- schlüssel: Die Gebiete sind eine App-Aufzählung und wandern mit einer
  -- App-Version, nicht mit einer Migration.
  gebiet           text not null,
  -- Klartext wie an der Frage („Strahlenschutz (A-Einsatz)"). NULL = das
  -- ganze Gebiet.
  kapitel          text,
  abgeschaltet_am  timestamptz not null default now(),
  abgeschaltet_von uuid references auth.users (id) on delete set null
);

comment on table public.abgeschaltete_lernbereiche is
  'Was diese Gesamtwehr NICHT abgefragt haben will. Eine Zeile je Gebiet oder '
  'Kapitel; kapitel = NULL meint das ganze Gebiet. Gepflegt ausschliesslich '
  'ueber setze_lernbereich.';
comment on column public.abgeschaltete_lernbereiche.kapitel is
  'NULL = das ganze Gebiet ist abgeschaltet, sonst genau dieses Unterkapitel.';

-- Zweimal dasselbe abschalten ist kein Zustand, sondern ein Fehler. Ein
-- schlichter UNIQUE ginge nicht: In Postgres sind zwei NULL verschieden,
-- „ganzes Gebiet aus" ließe sich also beliebig oft eintragen. Deshalb über
-- den Ausdruck.
create unique index if not exists abgeschaltete_lernbereiche_eindeutig
  on public.abgeschaltete_lernbereiche
     (gesamtwehr_id, gebiet, (coalesce(kapitel, '')));

alter table public.abgeschaltete_lernbereiche enable row level security;

-- Lesen darf jeder, der zur Wehr gehört — die Abschaltung wirkt auf jedem
-- Gerät, also muss jedes Gerät sie kennen. Geschrieben wird per Funktion,
-- deshalb steht hier KEINE Schreib-Policy und es gibt keinen Schreib-Grant
-- (siehe #198: was direkt beschreibbar ist, muss im Guard namentlich stehen —
-- diese Tabelle soll das gerade nicht).
create policy "read own gesamtwehr lernbereiche"
  on public.abgeschaltete_lernbereiche
  for select to authenticated
  using (public.can_read_gesamtwehr(gesamtwehr_id));

grant select on public.abgeschaltete_lernbereiche to authenticated;
grant all    on public.abgeschaltete_lernbereiche to service_role;

-- ⚠️ Der Entzug gehört zu JEDER neuen Tabelle (#198). Ohne ihn verteilt der
-- Stack seine Default-Privileges — Supabase CLI 2.116.0 gibt jeder frischen
-- Tabelle `DELETE, INSERT, TRUNCATE, UPDATE` für beide Rollen, 2.109.1
-- immerhin noch `TRUNCATE, REFERENCES, TRIGGER`. Geschrieben wird hier
-- ausschließlich über die geprüfte Funktion, gelesen nur von
-- `authenticated`; alles andere ist ein Recht, das niemand braucht.
-- `tool/check_schema_grants.sql` prüft genau das und war es auch, der diese
-- Zeilen eingefordert hat.
revoke insert, update, delete, truncate, references, trigger
  on public.abgeschaltete_lernbereiche from anon, authenticated, public;
revoke select on public.abgeschaltete_lernbereiche from anon, public;

-- ── Schreiben ───────────────────────────────────────────────────────────────
-- Gate ist `can_write_gesamtwehr_types` = Gerätewart oder Admin dieser Wehr,
-- dasselbe Recht, das auch die Fragen freigibt. Bewusst NICHT
-- `is_gesamtwehr_admin` (Kommandant): Was gelernt wird, ist Ausbildungssache
-- und gehört zum selben Griff wie die Freigabe einer Frage.
--
-- Ein Aufruf, beide Richtungen: `aus = true` schaltet ab, `aus = false`
-- wieder ein. Zwei Funktionen wären zwei Stellen, an denen das Recht geprüft
-- werden muss.
create or replace function public.setze_lernbereich(
  gw uuid,
  p_gebiet text,
  p_kapitel text,
  aus boolean
)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  -- Leerstring und NULL meinen dasselbe: das ganze Gebiet. Die Normalisierung
  -- steht hier und nicht beim Aufrufer, sonst legt ein Client mit '' eine
  -- zweite Zeile neben die mit NULL.
  k text := nullif(btrim(p_kapitel), '');
begin
  if not public.can_write_gesamtwehr_types(gw) then
    raise exception 'permission denied: geraetewart of this gesamtwehr required';
  end if;

  if btrim(coalesce(p_gebiet, '')) = '' then
    raise exception 'gebiet fehlt';
  end if;

  if aus then
    insert into public.abgeschaltete_lernbereiche
      (gesamtwehr_id, gebiet, kapitel, abgeschaltet_von)
    values (gw, btrim(p_gebiet), k, auth.uid())
    on conflict (gesamtwehr_id, gebiet, (coalesce(kapitel, ''))) do nothing;
  else
    delete from public.abgeschaltete_lernbereiche
     where gesamtwehr_id = gw
       and gebiet = btrim(p_gebiet)
       and coalesce(kapitel, '') = coalesce(k, '');
  end if;
end;
$$;

comment on function public.setze_lernbereich(uuid, text, text, boolean) is
  'Schaltet ein Gebiet (p_kapitel = NULL) oder ein Kapitel fuer diese '
  'Gesamtwehr ab oder wieder ein. Nur Geraetewart/Admin der Wehr.';

-- Die API-Oberfläche ist opt-out: Ohne diese Zeilen stünde die Funktion als
-- /rest/v1/rpc/setze_lernbereich auch `anon` offen.
revoke execute on function public.setze_lernbereich(uuid, text, text, boolean)
  from public, anon;
-- ⚠️ `revoke ... from public` nimmt auch service_role das Recht — Autodeploy
-- und Edge Functions brauchen es explizit zurück.
grant execute on function public.setze_lernbereich(uuid, text, text, boolean)
  to authenticated;
grant execute on function public.setze_lernbereich(uuid, text, text, boolean)
  to service_role;
