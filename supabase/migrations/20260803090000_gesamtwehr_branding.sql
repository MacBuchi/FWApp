-- gesamtwehr_branding.sql – Eigener Kopfbereich je Gesamtwehr (#57, P5 Branding).
--
-- Ziel (Marcus in #57): „Der Admin kann den Bereich für die Gesamtfeuerwehr
-- anlegen (schickes Template für Startbildschirm bzw. Header mit eigenem Text
-- und Bild)." Gepflegt wird das vom Feuerwehrkommandanten, gesehen wird es von
-- allen, die zur Wehr gehören.
--
-- Einspielen per docker exec psql als supabase_admin, danach
-- NOTIFY pgrst, 'reload schema'.
--
-- ── Warum eine eigene Tabelle und nicht Spalten an `gesamtwehren`? ──────────
-- `gesamtwehren` ist das öffentliche Verzeichnis: Ihre Lese-Policy ist
-- `using (true)`, weil eine Abteilung, die noch NICHT zu einer Wehr gehört,
-- deren Namen sehen muss, um den Anschluss zu beantragen
-- (20260801000000, Policy „authenticated read"). Ein Willkommenstext und erst
-- recht ein Foto vom Gerätehaus sind aber nichts, was jedes Konto der
-- Installation sehen soll — spätestens mit Stufe ④ (mehrere Gesamtwehren auf
-- einem Host) säßen fremde Wehren sonst voreinander offen. Deshalb liegt das
-- Branding daneben, hinter `can_read_gesamtwehr`, und das Verzeichnis bleibt
-- so schmal wie es ist.

create table if not exists public.gesamtwehr_branding (
  gesamtwehr_id uuid primary key
    references public.gesamtwehren (id) on delete cascade,
  title         text,
  welcome_text  text,
  image_path    text,
  updated_at    timestamptz not null default now(),
  updated_by    uuid references auth.users (id) on delete set null
);

comment on table public.gesamtwehr_branding is
  'Kopfbereich der Startseite je Gesamtwehr (#57 P5). Genau eine Zeile je Wehr; '
  'gepflegt ausschliesslich ueber set_gesamtwehr_branding.';
comment on column public.gesamtwehr_branding.title is
  'Ueberschrift. NULL = die App zeigt den Namen aus gesamtwehren.';
comment on column public.gesamtwehr_branding.image_path is
  'Marker der Form supabase://gesamtwehr-branding/<gw>/<millis>.jpg, wie bei '
  'equipment_items.image_path.';

alter table public.gesamtwehr_branding enable row level security;

-- Nur Lesen per Policy; geschrieben wird über die geprüfte Funktion unten —
-- dieselbe Disziplin wie bei equipment_types und beim Snapshot.
create policy "read own gesamtwehr branding" on public.gesamtwehr_branding
  for select to authenticated
  using (public.can_read_gesamtwehr(gesamtwehr_id));

grant select on public.gesamtwehr_branding to authenticated;
grant all on public.gesamtwehr_branding to service_role;

-- ── Schreiben ───────────────────────────────────────────────────────────────
-- Gate ist `is_gesamtwehr_admin` = Feuerwehrkommandant dieser Wehr. Bewusst
-- NICHT `can_write_gesamtwehr_types`: Den geteilten Gerätebestand pflegt jeder
-- Gerätewart der Wehr (Marcus' Entscheidung zu Stufe ②), aber wie sich die Wehr
-- nach außen darstellt, ist Sache des Kommandanten — so steht die Hierarchie
-- auch in NUTZERKONZEPT.md §2.
--
-- ⚠️ Die Nutzlast trägt IMMER alle drei Felder. Kein `coalesce` auf die
-- übergebenen Werte: NULL heißt „gelöscht", nicht „unverändert". Beim
-- Typ-Sync (push_equipment_types) hat genau diese Verwechslung einmal beinahe
-- das Foto der ganzen Gesamtwehr gekostet — hier ist die Regel deshalb von
-- vornherein die einfache: Wer schreibt, schickt den vollen Datensatz.
create function public.set_gesamtwehr_branding(
  gw uuid,
  neuer_titel text,
  neuer_text text,
  neues_bild text
)
returns public.gesamtwehr_branding
language plpgsql
security definer set search_path = ''
as $$
declare
  ergebnis public.gesamtwehr_branding;
begin
  if not public.is_gesamtwehr_admin(gw) then
    raise exception 'permission denied: feuerwehrkommandant of this gesamtwehr required';
  end if;

  insert into public.gesamtwehr_branding as b
    (gesamtwehr_id, title, welcome_text, image_path, updated_at, updated_by)
  values (gw, nullif(btrim(neuer_titel), ''), nullif(btrim(neuer_text), ''),
          nullif(btrim(neues_bild), ''), now(), auth.uid())
  on conflict (gesamtwehr_id) do update set
    title        = excluded.title,
    welcome_text = excluded.welcome_text,
    image_path   = excluded.image_path,
    updated_at   = now(),
    updated_by   = auth.uid()
  returning * into ergebnis;

  return ergebnis;
end;
$$;

-- ── Storage: eigener Bucket, Ordner je Gesamtwehr ───────────────────────────
-- Der Bucket `equipment-images` wäre der bequeme Weg, ist aber der falsche:
-- Sein Schreibrecht hängt an `is_editor()` (jeder Gerätewart irgendwo), und der
-- Name würde lügen. Hier gilt Ordner = Gesamtwehr, und das Recht wird je Ordner
-- geprüft.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'gesamtwehr-branding',
  'gesamtwehr-branding',
  false,
  1048576, -- 1 MB harte Grenze; die App komprimiert vorher auf <= 300 KB
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- Der Ordnername muss als UUID gelesen werden. Das geschieht bewusst mit
-- Auffangnetz statt als roher `::uuid`-Cast: krummer Name -> NULL -> beide
-- Prüfungen sagen nein.
--
-- Ehrlich dazu: Ein roher Cast lief in allen Wegen, die sich am lokalen Stack
-- erzeugen ließen, ebenfalls fehlerfrei — Postgres hat `bucket_id` stets
-- zuerst ausgewertet, sodass Objektnamen fremder Buckets (`eq_7_1700.jpg`,
-- ein sicherer Wurf beim Cast) nie beim Cast ankamen. Die Reihenfolge der
-- AND-Glieder ist aber **nicht zugesichert**, und der Schadensfall wäre kein
-- kleiner: Wertete der Planer einmal andersherum aus, bräche jede Abfrage auf
-- storage.objects mit „invalid input syntax for type uuid" — und riss die
-- Gerätefotos mit, die mit dem Branding nichts zu tun haben. Eine Funktion
-- kostet nichts; sich auf undokumentierte Auswertungsreihenfolge zu verlassen,
-- kostet im Zweifel alle Bilder. Deshalb bleibt sie.
create function public.branding_objekt_gesamtwehr(objektname text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
begin
  return (string_to_array(objektname, '/'))[1]::uuid;
exception when others then
  return null;
end;
$$;

create policy "gesamtwehr-branding read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'gesamtwehr-branding'
    and public.can_read_gesamtwehr(public.branding_objekt_gesamtwehr(name))
  );

create policy "gesamtwehr-branding kommandant insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'gesamtwehr-branding'
    and public.is_gesamtwehr_admin(public.branding_objekt_gesamtwehr(name))
  );

create policy "gesamtwehr-branding kommandant update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'gesamtwehr-branding'
    and public.is_gesamtwehr_admin(public.branding_objekt_gesamtwehr(name))
  )
  with check (
    bucket_id = 'gesamtwehr-branding'
    and public.is_gesamtwehr_admin(public.branding_objekt_gesamtwehr(name))
  );

create policy "gesamtwehr-branding kommandant delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'gesamtwehr-branding'
    and public.is_gesamtwehr_admin(public.branding_objekt_gesamtwehr(name))
  );

revoke execute on function
  public.set_gesamtwehr_branding(uuid, text, text, text),
  public.branding_objekt_gesamtwehr(text) from public, anon;

-- ⚠️ `revoke ... from public` nimmt auch service_role das Recht — Autodeploy
-- und Edge Functions brauchen es explizit zurück (Lehre aus Stufe ①).
grant execute on function
  public.set_gesamtwehr_branding(uuid, text, text, text),
  public.branding_objekt_gesamtwehr(text) to authenticated;
grant execute on function
  public.set_gesamtwehr_branding(uuid, text, text, text),
  public.branding_objekt_gesamtwehr(text) to service_role;
