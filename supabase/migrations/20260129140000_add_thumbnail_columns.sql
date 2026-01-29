-- Add thumbnail variant columns for faster feed loading
-- These are optional and existing images will continue to work without them

-- Club photos (trail cam)
ALTER TABLE club_photos
ADD COLUMN IF NOT EXISTS thumb_path TEXT NULL,
ADD COLUMN IF NOT EXISTS medium_path TEXT NULL;

COMMENT ON COLUMN club_photos.thumb_path IS 'Small thumbnail (~400px max dimension) for grid views';
COMMENT ON COLUMN club_photos.medium_path IS 'Medium resolution (~1200px max dimension) for detail views';

-- Trophy photos (additional photos beyond cover)
ALTER TABLE trophy_photos
ADD COLUMN IF NOT EXISTS thumb_path TEXT NULL,
ADD COLUMN IF NOT EXISTS medium_path TEXT NULL;

COMMENT ON COLUMN trophy_photos.thumb_path IS 'Small thumbnail (~400px max dimension) for grid views';
COMMENT ON COLUMN trophy_photos.medium_path IS 'Medium resolution (~1200px max dimension) for detail views';

-- Trophy posts (cover photo)
ALTER TABLE trophy_posts
ADD COLUMN IF NOT EXISTS cover_thumb_path TEXT NULL,
ADD COLUMN IF NOT EXISTS cover_medium_path TEXT NULL;

COMMENT ON COLUMN trophy_posts.cover_thumb_path IS 'Small thumbnail of cover photo for feed cards';
COMMENT ON COLUMN trophy_posts.cover_medium_path IS 'Medium resolution cover for detail views';

-- Club openings (array of paths)
ALTER TABLE club_openings
ADD COLUMN IF NOT EXISTS thumb_paths TEXT[] NULL,
ADD COLUMN IF NOT EXISTS medium_paths TEXT[] NULL;

COMMENT ON COLUMN club_openings.thumb_paths IS 'Thumbnail variants matching photo_paths array order';
COMMENT ON COLUMN club_openings.medium_paths IS 'Medium variants matching photo_paths array order';

-- Swap shop photos
ALTER TABLE swap_shop_photos
ADD COLUMN IF NOT EXISTS thumb_path TEXT NULL,
ADD COLUMN IF NOT EXISTS medium_path TEXT NULL;

COMMENT ON COLUMN swap_shop_photos.thumb_path IS 'Small thumbnail for listing cards';
COMMENT ON COLUMN swap_shop_photos.medium_path IS 'Medium resolution for detail views';

-- Land photos
ALTER TABLE land_photos
ADD COLUMN IF NOT EXISTS thumb_path TEXT NULL,
ADD COLUMN IF NOT EXISTS medium_path TEXT NULL;

COMMENT ON COLUMN land_photos.thumb_path IS 'Small thumbnail for listing cards';
COMMENT ON COLUMN land_photos.medium_path IS 'Medium resolution for detail views';

-- Note: No indexes needed on these columns as they're selected alongside primary keys
-- and not used in WHERE clauses
