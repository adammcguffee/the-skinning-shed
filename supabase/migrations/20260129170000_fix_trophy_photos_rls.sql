-- Fix trophy post related RLS policies
-- Error 42501 (insufficient_privilege) was occurring on INSERT
-- Root cause: weather_snapshots, moon_snapshots, and analytics_buckets were missing INSERT policies

-- ============================================
-- WEATHER SNAPSHOTS - Add INSERT policy
-- ============================================
DROP POLICY IF EXISTS "Users can insert weather for own posts" ON weather_snapshots;

CREATE POLICY "Users can insert weather for own posts"
ON weather_snapshots
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM trophy_posts
    WHERE trophy_posts.id = weather_snapshots.post_id
    AND trophy_posts.user_id = auth.uid()
  )
);

-- ============================================
-- MOON SNAPSHOTS - Add INSERT policy
-- ============================================
DROP POLICY IF EXISTS "Users can insert moon for own posts" ON moon_snapshots;

CREATE POLICY "Users can insert moon for own posts"
ON moon_snapshots
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM trophy_posts
    WHERE trophy_posts.id = moon_snapshots.post_id
    AND trophy_posts.user_id = auth.uid()
  )
);

-- ============================================
-- ANALYTICS BUCKETS - Add INSERT policy
-- ============================================
DROP POLICY IF EXISTS "Users can insert analytics for own posts" ON analytics_buckets;

CREATE POLICY "Users can insert analytics for own posts"
ON analytics_buckets
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM trophy_posts
    WHERE trophy_posts.id = analytics_buckets.post_id
    AND trophy_posts.user_id = auth.uid()
  )
);

-- Note: trophy_photos INSERT policy already exists as "Users can insert photos for own posts"
