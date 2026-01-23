-- Create custom ENUM types for The Skinning Shed MVP
-- Migration: 20260123033813_create_enums_and_types

-- Trophy visibility levels
CREATE TYPE visibility_type AS ENUM ('public', 'private', 'followers_only');

-- Trophy categories (first-class species)
CREATE TYPE trophy_category AS ENUM ('deer', 'turkey', 'bass', 'other_game', 'other_fishing');

-- Time of day buckets
CREATE TYPE time_bucket AS ENUM ('morning', 'midday', 'evening', 'night');

-- Species categories
CREATE TYPE species_category AS ENUM ('game', 'fish');

-- Land listing types
CREATE TYPE land_type AS ENUM ('lease', 'sale');

-- Contact methods
CREATE TYPE contact_method AS ENUM ('email', 'phone', 'external_link');

-- Listing status
CREATE TYPE listing_status AS ENUM ('active', 'inactive', 'expired', 'removed');

-- Reaction types (Respect-first community)
CREATE TYPE reaction_type AS ENUM ('respect', 'well_earned');

-- Moderation report targets
CREATE TYPE report_target AS ENUM ('post', 'listing', 'comment', 'user');

-- Moderation report status
CREATE TYPE report_status AS ENUM ('open', 'reviewed', 'closed');

-- Wind direction buckets for analytics
CREATE TYPE wind_direction AS ENUM ('N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'VAR');
