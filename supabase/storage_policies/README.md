# Supabase Storage Policies

Templates and notes for storage bucket policies.

## Buckets

| Bucket | Purpose | Read | Write |
|--------|---------|------|-------|
| `avatars` | User profile photos | Public | Owner only (uid path) |
| `trophy_photos` | Trophy post images | With trophy access | Owner only |
| `land_photos` | Land listing images | With listing access | Owner only |
| `swap_shop_photos` | Swap shop images | With listing access | Owner only |

## Path Conventions

```
avatars/{user_id}/avatar.{ext}
trophy_photos/{user_id}/{trophy_id}/{filename}
land_photos/{user_id}/{listing_id}/{filename}
swap_shop_photos/{user_id}/{listing_id}/{filename}
```

## Policy Template

```sql
-- Allow users to upload to their own path
CREATE POLICY "Users can upload own files"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'bucket_name' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow public read
CREATE POLICY "Public can read files"
ON storage.objects FOR SELECT
USING (bucket_id = 'bucket_name');
```
