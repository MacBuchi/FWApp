-- lerngruppen_namen.sql – Wer sitzt eigentlich mit in der Gruppe? (Issue #136)
--
-- ⚠️ WARUM ES DAFÜR EINE FUNKTION BRAUCHT
-- `lerngruppen_mitglieder` gibt Mitgliedern die Zeilen ihrer Gruppe heraus —
-- aber darin steht nur `user_id`, eine UUID. Der Name daneben liegt in
-- `profiles`, und `profiles` hat seit dem Ur-Schema genau EINE Lese-Policy:
--
--     create policy "read own profile" on profiles for select
--       to authenticated using (id = auth.uid());
--
-- Keine spätere Migration erweitert sie. Ein `select … profiles(anzeigename)`
-- über die Mitgliederliste käme deshalb für alle außer einem selbst leer
-- zurück — die Mitgliederliste und später das Ranking wären eine Liste von
-- UUIDs.
--
-- ⚠️ UND WARUM NICHT EINFACH DIE POLICY AUFMACHEN
-- „Sieh die Profile derer, die mit dir in einer Gruppe sind" wäre eine Zeile
-- weniger und gibt zu viel her: An derselben Zeile hängen `role` und
-- `must_change_password`. Eine Lerngruppe ist ein freiwilliger Zusammenschluss
-- auf acht Wochen und kein Grund, den Rechte- und Kontozustand daneben zu
-- öffnen. Die Funktion gibt genau das heraus, was man selbst gewählt hat, um
-- erkannt zu werden: Anzeigename und Avatar.
--
-- ⚠️ Der Rückfall auf `username` ist eine bewusste Ausnahme davon: Den
-- Anzeigenamen setzt man freiwillig, die meisten haben keinen, und eine Liste
-- aus fünfmal „Unbenannt" wäre kein Ranking. Der Nutzername ist zugleich die
-- Anmeldekennung — das ist vertretbar, weil er innerhalb der Wehr ohnehin
-- bekannt ist (der Kommandant vergibt ihn) und weil das Konto am Passwort
-- hängt, nicht an der Kennung. Dieselbe Reihenfolge zeigt die App im eigenen
-- Profil (`MeinProfil.name`).
--
-- Diese Migration ändert für niemanden etwas, solange keine App sie aufruft
-- (docs/NUTZERKONZEPT.md §7: Migration → App-Version → Mindestversion).

create function public.lerngruppen_mitglieder_namen(p_gruppe uuid)
returns table (
  user_id        uuid,
  anzeigename    text,
  avatar         text,
  beigetreten_am timestamptz
)
language sql
security definer set search_path = ''
stable
as $$
  select m.user_id,
         -- Derselbe Rückfall wie im Profil-Screen: Wer keinen Anzeigenamen
         -- gesetzt hat, steht unter seinem Nutzernamen da — und nicht als
         -- leere Zeile. `nullif` fängt den Namen, der nur aus Leerzeichen
         -- besteht.
         coalesce(nullif(btrim(p.anzeigename), ''), p.username),
         p.avatar,
         m.beigetreten_am
    from public.lerngruppen_mitglieder m
    join public.profiles p on p.id = m.user_id
   -- Der Zugang hängt an derselben Bedingung wie die Lese-Policies der beiden
   -- Tabellen. Wer nicht Mitglied ist, bekommt eine leere Liste statt eines
   -- Fehlers — genau das sieht er heute auch, wenn er die Tabelle direkt
   -- abfragt. Eine Ausnahme wäre eine zusätzliche Auskunft: „diese Gruppe
   -- gibt es" ist schon mehr, als ein Fremder wissen muss.
   where public.ist_lerngruppen_mitglied(p_gruppe)
     and m.gruppe_id = p_gruppe
   order by m.beigetreten_am, m.user_id;
$$;

comment on function public.lerngruppen_mitglieder_namen(uuid) is
  'Mitglieder einer Lerngruppe mit Anzeigename und Avatar (Issue #136). '
  'Noetig, weil profiles nur die eigene Zeile herausgibt. Gibt Anzeigename '
  '(Rueckfall Nutzername) und Avatar heraus, bewusst nicht role oder '
  'must_change_password.';

revoke execute on function public.lerngruppen_mitglieder_namen(uuid)
  from public, anon;
grant execute on function public.lerngruppen_mitglieder_namen(uuid)
  to authenticated;
grant execute on function public.lerngruppen_mitglieder_namen(uuid)
  to service_role;
