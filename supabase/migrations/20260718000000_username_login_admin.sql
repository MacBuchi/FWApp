-- username_login_admin.sql – M7 Etappe 3: individuelle Konten mit
-- Nutzername-Login und Initialpasswort-Pflichtwechsel.
--
-- Konvention: Der Nutzername ist der lokale Teil der E-Mail-Form
-- `<nutzername>@fw.local` (die App mappt die Login-Eingabe automatisch).
-- Konten legt ausschließlich der Admin über die Edge Function `admin-users`
-- an (Service-Role bleibt serverseitig); dabei wird `must_change_password`
-- gesetzt, die App erzwingt nach dem Login den Passwortwechsel.
--
-- Einspielen wie gehabt per docker exec psql als supabase_admin, danach
-- NOTIFY pgrst, 'reload schema'.

-- 1) Flag: Initialpasswort muss noch geändert werden.
alter table public.profiles
  add column must_change_password boolean not null default false;

-- 2) Nach erfolgreichem Wechsel löscht der Nutzer sein eigenes Flag.
--    (Direkte Updates auf profiles bleiben verboten — kein Update-Grant/RLS;
--    diese Funktion ist der einzige Weg und wirkt nur auf die eigene Zeile.)
create function public.clear_must_change_password()
returns void
language sql
security definer set search_path = ''
as $$
  update public.profiles
  set must_change_password = false
  where id = auth.uid();
$$;

revoke execute on function public.clear_must_change_password from public, anon;
grant execute on function public.clear_must_change_password to authenticated;
