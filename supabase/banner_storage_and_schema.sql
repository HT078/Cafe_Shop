-- ============================================================
-- BANNER QUANG CAO - CA PHE HAI TIN
-- Tao bang banners, bucket "banners" va quyen Storage.
-- Chay TOAN BO file trong Supabase Dashboard > SQL Editor.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.banners (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  image_url TEXT,
  link_type TEXT,
  link_value TEXT,
  is_active BOOLEAN DEFAULT FALSE,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.banners
  ADD COLUMN IF NOT EXISTS image_url TEXT,
  ADD COLUMN IF NOT EXISTS link_type TEXT DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS link_value TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS subtitle TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS tag TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS start_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS end_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS banners_active_sort_idx
ON public.banners(is_active, sort_order);

ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Banners public select" ON public.banners;
DROP POLICY IF EXISTS "Banners admin insert" ON public.banners;
DROP POLICY IF EXISTS "Banners admin update" ON public.banners;
DROP POLICY IF EXISTS "Banners admin delete" ON public.banners;

CREATE POLICY "Banners public select"
ON public.banners
FOR SELECT
TO public
USING (TRUE);

CREATE POLICY "Banners admin insert"
ON public.banners
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE profiles.id = auth.uid()
      AND LOWER(COALESCE(profiles.role, '')) = 'admin'
  )
);

CREATE POLICY "Banners admin update"
ON public.banners
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE profiles.id = auth.uid()
      AND LOWER(COALESCE(profiles.role, '')) = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE profiles.id = auth.uid()
      AND LOWER(COALESCE(profiles.role, '')) = 'admin'
  )
);

CREATE POLICY "Banners admin delete"
ON public.banners
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE profiles.id = auth.uid()
      AND LOWER(COALESCE(profiles.role, '')) = 'admin'
  )
);

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'banners',
  'banners',
  TRUE,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  public = TRUE,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles as profile
    where profile.id = auth.uid()
      and lower(coalesce(to_jsonb(profile) ->> 'role', '')) = 'admin'
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

DROP POLICY IF EXISTS "banners_products_public_select" ON storage.objects;
DROP POLICY IF EXISTS "banners_products_admin_insert" ON storage.objects;
DROP POLICY IF EXISTS "banners_products_admin_delete" ON storage.objects;
DROP POLICY IF EXISTS "banners_bucket_public_select" ON storage.objects;
DROP POLICY IF EXISTS "banners_bucket_admin_insert" ON storage.objects;
DROP POLICY IF EXISTS "banners_bucket_admin_update" ON storage.objects;
DROP POLICY IF EXISTS "banners_bucket_admin_delete" ON storage.objects;
DROP POLICY IF EXISTS "banners_storage_public_select" ON storage.objects;
DROP POLICY IF EXISTS "banners_storage_admin_insert" ON storage.objects;
DROP POLICY IF EXISTS "banners_storage_admin_update" ON storage.objects;
DROP POLICY IF EXISTS "banners_storage_admin_delete" ON storage.objects;

CREATE POLICY "banners_storage_public_select"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'banners');

CREATE POLICY "banners_storage_admin_insert"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'banners'
  AND public.is_admin()
);

CREATE POLICY "banners_storage_admin_update"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'banners'
  AND public.is_admin()
)
WITH CHECK (
  bucket_id = 'banners'
  AND public.is_admin()
);

CREATE POLICY "banners_storage_admin_delete"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'banners'
  AND public.is_admin()
);

-- Ket qua cuoi phai co mot dong: id = banners, public = true.
SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets
WHERE id = 'banners';
