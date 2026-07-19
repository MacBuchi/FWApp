-- feedback.sql – In-App-Feedback (Feature-Wünsche / Bug-Reports).
--
-- Die App schreibt Meldungen in diese Tabelle; der GitHub-Actions-Bot
-- (tool/feedback_bot.py, Workflow feedback.yml) liest sie mit dem
-- Service-Role-Key über das öffentliche API-Gateway und erzeugt daraus
-- Issues im Repo (öffentlich!), danach stempelt er processed_at.
-- user_name ist der von der App mitgeschickte Nutzername (Localpart der
-- fw.local-Adresse) — rein informativ für die Issue-Zuordnung.
--
-- Einspielen wie gehabt per docker exec psql als supabase_admin, danach
-- NOTIFY pgrst, 'reload schema'.

create table public.feedback (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles (id) on delete cascade,
  user_name    text check (user_name is null or char_length(user_name) <= 40),
  type         text not null check (type in ('feature', 'bug')),
  message      text not null check (char_length(message) between 3 and 2000),
  created_at   timestamptz not null default now(),
  processed_at timestamptz
);

alter table public.feedback enable row level security;

-- Jeder Angemeldete darf nur im eigenen Namen melden und nur Eigenes lesen;
-- alles Weitere (lesen/patchen aller Zeilen) macht der Bot per service_role.
create policy "insert own feedback" on public.feedback
  for insert to authenticated with check (user_id = auth.uid());
create policy "read own feedback" on public.feedback
  for select to authenticated using (user_id = auth.uid());

grant select, insert on public.feedback to authenticated;
grant all on public.feedback to service_role;
