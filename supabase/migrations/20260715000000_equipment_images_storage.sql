-- equipment_images_storage.sql – Storage bucket for central equipment photos (M2).
-- Private bucket: authenticated users read, only admins write. The app stores
-- markers of the form supabase://equipment-images/<object> in imagePath and
-- resolves them to /storage/v1/object/authenticated/... at display time.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'equipment-images',
  'equipment-images',
  false,
  1048576, -- 1 MB hard cap; the app compresses to <= 300 KB before upload
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create policy "equipment-images authenticated read" on storage.objects
  for select to authenticated
  using (bucket_id = 'equipment-images');

create policy "equipment-images admin insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'equipment-images' and public.is_admin());

create policy "equipment-images admin update" on storage.objects
  for update to authenticated
  using (bucket_id = 'equipment-images' and public.is_admin())
  with check (bucket_id = 'equipment-images' and public.is_admin());

create policy "equipment-images admin delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'equipment-images' and public.is_admin());
