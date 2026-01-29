-- ============================================================================
-- FFL Dealers Directory: ATF Federal Firearms Licensee listings
-- ============================================================================

-- 1) Create ffl_dealers table
-- Stores ATF FFL holder data, enriched with county from ZIP->county crosswalk

CREATE TABLE IF NOT EXISTS ffl_dealers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- License info
    license_number TEXT,                             -- ATF license number if present
    license_name TEXT NOT NULL,                      -- Business/licensee name
    license_type TEXT,                               -- FFL type code if present
    
    -- Premises address
    premise_street TEXT NOT NULL,
    premise_city TEXT NOT NULL,
    premise_state TEXT NOT NULL,                     -- 2-letter state code
    premise_zip TEXT NOT NULL,                       -- 5-digit ZIP
    premise_county TEXT NOT NULL,                    -- Derived from ZIP->county crosswalk
    
    -- Contact
    phone TEXT,                                      -- Only if present in ATF source
    
    -- Source tracking for idempotent imports
    source_year INT NOT NULL,
    source_month INT NOT NULL,
    source_row_hash TEXT NOT NULL,                   -- SHA256 of key fields for dedupe
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- Indexes for fast filtering
-- ============================================================================

-- Primary filter path: state -> county -> city
CREATE INDEX IF NOT EXISTS idx_ffl_dealers_state_county_city 
    ON ffl_dealers(premise_state, premise_county, premise_city);

-- State + ZIP filtering
CREATE INDEX IF NOT EXISTS idx_ffl_dealers_state_zip 
    ON ffl_dealers(premise_state, premise_zip);

-- State + county only
CREATE INDEX IF NOT EXISTS idx_ffl_dealers_state_county 
    ON ffl_dealers(premise_state, premise_county);

-- Single state index for dropdowns
CREATE INDEX IF NOT EXISTS idx_ffl_dealers_state 
    ON ffl_dealers(premise_state);

-- Name search (trigram for ILIKE)
-- First ensure pg_trgm extension is enabled
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_ffl_dealers_name_trgm 
    ON ffl_dealers USING gin (license_name gin_trgm_ops);

-- Unique constraint on source hash for idempotent upserts
CREATE UNIQUE INDEX IF NOT EXISTS idx_ffl_dealers_source_hash_unique 
    ON ffl_dealers(source_row_hash);

-- ============================================================================
-- Updated_at trigger
-- ============================================================================

CREATE OR REPLACE FUNCTION update_ffl_dealers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS ffl_dealers_updated_at ON ffl_dealers;
CREATE TRIGGER ffl_dealers_updated_at
    BEFORE UPDATE ON ffl_dealers
    FOR EACH ROW
    EXECUTE FUNCTION update_ffl_dealers_updated_at();

-- ============================================================================
-- RLS Policies: Public read, service role write
-- ============================================================================

ALTER TABLE ffl_dealers ENABLE ROW LEVEL SECURITY;

-- Anyone can read (public directory)
CREATE POLICY ffl_dealers_select_public ON ffl_dealers
    FOR SELECT
    USING (true);

-- Only service role can insert (no user writes)
CREATE POLICY ffl_dealers_insert_service ON ffl_dealers
    FOR INSERT
    WITH CHECK (false);  -- Blocked for anon/authenticated; service role bypasses RLS

-- Only service role can update
CREATE POLICY ffl_dealers_update_service ON ffl_dealers
    FOR UPDATE
    USING (false)
    WITH CHECK (false);

-- Only service role can delete
CREATE POLICY ffl_dealers_delete_service ON ffl_dealers
    FOR DELETE
    USING (false);

-- ============================================================================
-- 2) Create ffl_import_runs table for tracking import jobs
-- ============================================================================

CREATE TABLE IF NOT EXISTS ffl_import_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    year INT NOT NULL,
    month INT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('running', 'success', 'failed')),
    rows_total INT DEFAULT 0,
    rows_inserted INT DEFAULT 0,
    rows_updated INT DEFAULT 0,
    rows_skipped INT DEFAULT 0,
    error TEXT,
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_ffl_import_runs_status 
    ON ffl_import_runs(status);

CREATE INDEX IF NOT EXISTS idx_ffl_import_runs_year_month 
    ON ffl_import_runs(year, month);

-- RLS: admin/service read only
ALTER TABLE ffl_import_runs ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read import runs (for admin UI)
CREATE POLICY ffl_import_runs_select_authenticated ON ffl_import_runs
    FOR SELECT
    USING (auth.role() = 'authenticated');

-- Only service role can write
CREATE POLICY ffl_import_runs_insert_service ON ffl_import_runs
    FOR INSERT
    WITH CHECK (false);

CREATE POLICY ffl_import_runs_update_service ON ffl_import_runs
    FOR UPDATE
    USING (false);

-- ============================================================================
-- 3) Helper RPC functions for efficient filtering
-- ============================================================================

-- Get distinct states that have FFL dealers
CREATE OR REPLACE FUNCTION get_ffl_states()
RETURNS TABLE(state TEXT, dealer_count BIGINT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT premise_state, COUNT(*) as dealer_count
    FROM ffl_dealers
    GROUP BY premise_state
    ORDER BY premise_state;
$$;

-- Get counties for a given state
CREATE OR REPLACE FUNCTION get_ffl_counties(p_state TEXT)
RETURNS TABLE(county TEXT, dealer_count BIGINT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT premise_county, COUNT(*) as dealer_count
    FROM ffl_dealers
    WHERE premise_state = UPPER(p_state)
    GROUP BY premise_county
    ORDER BY premise_county;
$$;

-- Get cities for a given state and county
CREATE OR REPLACE FUNCTION get_ffl_cities(p_state TEXT, p_county TEXT)
RETURNS TABLE(city TEXT, dealer_count BIGINT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT premise_city, COUNT(*) as dealer_count
    FROM ffl_dealers
    WHERE premise_state = UPPER(p_state)
      AND premise_county = p_county
    GROUP BY premise_city
    ORDER BY premise_city;
$$;

-- ============================================================================
-- Comments
-- ============================================================================

COMMENT ON TABLE ffl_dealers IS 'ATF Federal Firearms Licensee directory, imported monthly from ATF Complete Listing';
COMMENT ON TABLE ffl_import_runs IS 'Tracking table for FFL import job runs';

COMMENT ON COLUMN ffl_dealers.premise_county IS 'County derived from ZIP->county HUD crosswalk';
COMMENT ON COLUMN ffl_dealers.source_row_hash IS 'SHA256 hash of key fields for idempotent upsert';

COMMENT ON FUNCTION get_ffl_states IS 'Returns distinct states with FFL dealers and counts';
COMMENT ON FUNCTION get_ffl_counties IS 'Returns counties with FFL dealers for a given state';
COMMENT ON FUNCTION get_ffl_cities IS 'Returns cities with FFL dealers for a given state and county';
