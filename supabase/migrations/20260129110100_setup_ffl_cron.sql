-- ============================================================================
-- Supabase Cron Job Setup for FFL Import
-- Schedules monthly automatic ATF data import
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Note: To use pg_cron with Edge Functions, you need to:
-- 1. Store the CRON_SECRET in Supabase Vault (Dashboard -> Settings -> Vault)
-- 2. Set the project URL and Edge Function name correctly below

-- ============================================================================
-- Helper function to call FFL import Edge Function
-- Uses pg_net to make HTTP request
-- ============================================================================

CREATE OR REPLACE FUNCTION call_ffl_import()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    project_url TEXT;
    cron_secret TEXT;
    request_id INT;
BEGIN
    -- Get project URL from settings or environment
    -- In Supabase, this is typically stored in vault or as a constant
    project_url := current_setting('app.settings.supabase_url', true);
    
    -- Fallback if not set in settings
    IF project_url IS NULL OR project_url = '' THEN
        -- You should replace this with your actual Supabase project URL
        project_url := 'https://your-project.supabase.co';
    END IF;
    
    -- Get cron secret from vault
    -- First, try to get from vault (requires vault extension)
    BEGIN
        SELECT decrypted_secret INTO cron_secret
        FROM vault.decrypted_secrets
        WHERE name = 'CRON_SECRET'
        LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
        cron_secret := NULL;
    END;
    
    -- Make HTTP request to Edge Function
    SELECT net.http_post(
        url := project_url || '/functions/v1/ffl-import',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-cron-secret', COALESCE(cron_secret, '')
        ),
        body := '{}'::jsonb
    ) INTO request_id;
    
    RAISE NOTICE 'FFL import triggered, request_id: %', request_id;
END;
$$;

-- ============================================================================
-- Schedule cron jobs
-- ============================================================================

-- Primary schedule: Day 3 of each month at 04:10 UTC
-- This gives ATF time to post their monthly update
SELECT cron.schedule(
    'ffl-import-monthly-primary',
    '10 4 3 * *',  -- minute hour day month weekday
    $$SELECT call_ffl_import()$$
);

-- Backup schedule: Day 10 of each month at 04:10 UTC
-- In case ATF posts late or primary fails
SELECT cron.schedule(
    'ffl-import-monthly-backup',
    '10 4 10 * *',
    $$SELECT call_ffl_import()$$
);

-- ============================================================================
-- Grant permissions
-- ============================================================================

-- Allow cron to execute the function
GRANT EXECUTE ON FUNCTION call_ffl_import() TO postgres;

-- ============================================================================
-- View scheduled jobs (for verification)
-- ============================================================================

-- To view scheduled jobs, run:
-- SELECT * FROM cron.job;

-- To view job run history, run:
-- SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;

-- ============================================================================
-- Manual trigger function (for admin use)
-- ============================================================================

CREATE OR REPLACE FUNCTION trigger_ffl_import_manual()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    is_admin BOOLEAN;
BEGIN
    -- Check if user is admin
    SELECT p.is_admin INTO is_admin
    FROM profiles p
    WHERE p.id = auth.uid();
    
    IF NOT COALESCE(is_admin, false) THEN
        RETURN jsonb_build_object('error', 'Admin access required');
    END IF;
    
    -- Trigger the import
    PERFORM call_ffl_import();
    
    RETURN jsonb_build_object('success', true, 'message', 'FFL import triggered');
END;
$$;

-- ============================================================================
-- Comments
-- ============================================================================

COMMENT ON FUNCTION call_ffl_import IS 'Triggers FFL import Edge Function via HTTP';
COMMENT ON FUNCTION trigger_ffl_import_manual IS 'Admin-only manual trigger for FFL import';

-- ============================================================================
-- IMPORTANT SETUP NOTES
-- ============================================================================
-- 
-- After running this migration, you need to:
-- 
-- 1. Set the CRON_SECRET in Supabase Vault:
--    - Go to Dashboard -> Settings -> Vault
--    - Add a new secret named "CRON_SECRET" with a secure random value
--    - Also set this in your Edge Function environment variables
-- 
-- 2. Update the project URL in call_ffl_import() or set app.settings.supabase_url:
--    ALTER DATABASE postgres SET app.settings.supabase_url = 'https://your-project.supabase.co';
-- 
-- 3. Deploy the ffl-import Edge Function:
--    supabase functions deploy ffl-import
-- 
-- 4. Verify cron jobs are scheduled:
--    SELECT * FROM cron.job WHERE jobname LIKE 'ffl-import%';
-- 
-- 5. Test manually:
--    SELECT trigger_ffl_import_manual();
-- 
