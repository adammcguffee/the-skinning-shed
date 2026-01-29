-- ============================================================================
-- Remove FFL Feature
-- Drops all FFL-related tables, functions, triggers, and cron jobs
-- ============================================================================

-- ============================================================================
-- 1) Unschedule cron jobs (safe if they don't exist)
-- ============================================================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'ffl-import-monthly-primary') THEN
        PERFORM cron.unschedule('ffl-import-monthly-primary');
    END IF;
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'ffl-import-monthly-backup') THEN
        PERFORM cron.unschedule('ffl-import-monthly-backup');
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Cron: %', SQLERRM;
END;
$$;

-- ============================================================================
-- 2) Drop tables first (CASCADE drops triggers)
-- ============================================================================

DROP TABLE IF EXISTS public.ffl_import_runs CASCADE;
DROP TABLE IF EXISTS public.ffl_dealers CASCADE;

-- ============================================================================
-- 3) Drop functions (CASCADE for any remaining dependencies)
-- ============================================================================

DROP FUNCTION IF EXISTS trigger_ffl_import_manual() CASCADE;
DROP FUNCTION IF EXISTS call_ffl_import() CASCADE;
DROP FUNCTION IF EXISTS get_ffl_cities(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS get_ffl_counties(TEXT) CASCADE;
DROP FUNCTION IF EXISTS get_ffl_states() CASCADE;
DROP FUNCTION IF EXISTS update_ffl_dealers_updated_at() CASCADE;

-- ============================================================================
-- Verification (optional)
-- ============================================================================

-- To verify removal, run:
-- SELECT * FROM information_schema.tables WHERE table_name LIKE 'ffl%';
-- SELECT * FROM information_schema.routines WHERE routine_name LIKE '%ffl%';
-- SELECT * FROM cron.job WHERE jobname LIKE 'ffl%';
