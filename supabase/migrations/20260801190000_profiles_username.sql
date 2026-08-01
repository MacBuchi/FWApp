-- profiles_username.sql – Der Anzeigename überlebt den Adresswechsel
-- (Issue #57 Phase 4, Etappe 2).
--
-- Bisher wurde der Nutzername in der Nutzerverwaltung aus der Auth-Adresse
-- abgeleitet: `wart.stadt@fw.local` → `wart.stadt`. Sobald ein Konto eine
-- echte E-Mail-Adresse bekommt (Admins und Gerätewarte, damit sie ihr
-- Passwort selbst zurücksetzen können), fällt diese Ableitung in sich
-- zusammen — in der Liste stünde plötzlich `vorname.nachname@example.org`
-- statt des Namens, unter dem die Person in der Wehr bekannt ist.
--
-- Deshalb wandert der Name in eine eigene Spalte. Die Auth-Adresse ist ab
-- dann nur noch die Anmeldung, nicht mehr die Identität.

alter table public.profiles add column if not exists username text;

-- Bestand füllen: Für alle heutigen Konten IST der Adressanfang der Name.
update public.profiles p
   set username = split_part(u.email, '@', 1)
  from auth.users u
 where u.id = p.id
   and p.username is null;

-- Neue Konten bringen den Namen gleich mit. Sonst stünde ein frisch
-- angelegtes Konto so lange namenlos in der Liste, bis jemand nachträgt.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, abteilung_id, username)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'abteilung_id', '')::uuid,
      (select id from public.abteilungen where legacy_mirror)
    ),
    split_part(new.email, '@', 1)
  )
  on conflict do nothing;
  return new;
end;
$$;

comment on column public.profiles.username is
  'Anzeigename aus dem Zugangszettel. Bleibt bestehen, wenn die '
  'Auth-Adresse auf eine echte E-Mail wechselt (Issue #57 Phase 4).';
