-- Fix trophy_photos RLS policies to allow users to insert photos for their own posts
-- Error 42501 (insufficient_privilege) was occurring on INSERT

-- Drop existing insert policy if it exists
DROP POLICY IF EXISTS "Users can insert photos for their posts" ON trophy_photos;
DROP POLICY IF EXISTS "insert_own_post_photos" ON trophy_photos;

-- Create proper INSERT policy
-- Users can insert photos for trophy posts they own
CREATE POLICY "Users can insert photos for own posts"
ON trophy_photos
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM trophy_posts
    WHERE trophy_posts.id = trophy_photos.post_id
    AND trophy_posts.user_id = auth.uid()
  )
);

-- Ensure UPDATE and DELETE policies exist
DROP POLICY IF EXISTS "Users can update own post photos" ON trophy_photos;
DROP POLICY IF EXISTS "Users can delete own post photos" ON trophy_photos;

CREATE POLICY "Users can update own post photos"
ON trophy_photos
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM trophy_posts
    WHERE trophy_posts.id = trophy_photos.post_id
    AND trophy_posts.user_id = auth.uid()
  )
);

CREATE POLICY "Users can delete own post photos"
ON trophy_photos
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM trophy_posts
    WHERE trophy_posts.id = trophy_photos.post_id
    AND trophy_posts.user_id = auth.uid()
  )
);

-- Ensure SELECT policy allows viewing photos for visible posts
DROP POLICY IF EXISTS "Users can view photos for visible posts" ON trophy_photos;

CREATE POLICY "Users can view photos for visible posts"
ON trophy_photos
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM trophy_posts
    WHERE trophy_posts.id = trophy_photos.post_id
    AND (
      trophy_posts.visibility = 'public'
      OR trophy_posts.user_id = auth.uid()
    )
  )
);

-- Allow anonymous users to view public post photos
DROP POLICY IF EXISTS "Anyone can view public post photos" ON trophy_photos;

CREATE POLICY "Anyone can view public post photos"
ON trophy_photos
FOR SELECT
TO anon
USING (
  EXISTS (
    SELECT 1 FROM trophy_posts
    WHERE trophy_posts.id = trophy_photos.post_id
    AND trophy_posts.visibility = 'public'
  )
);

COMMENT ON POLICY "Users can insert photos for own posts" ON trophy_photos IS 'Allow authenticated users to add photos to their own trophy posts';
