-- ============================================================================
-- Opening Alerts: Premium notification subscriptions for Club Openings
-- ============================================================================

-- 1) Create the opening_alerts table
-- Stores user saved alert subscriptions for club openings

CREATE TABLE IF NOT EXISTS opening_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Location filters (required)
    state_code TEXT NOT NULL,                       -- 2-letter state code (required)
    county TEXT,                                     -- Optional county filter
    
    -- Additional filters
    available_only BOOLEAN NOT NULL DEFAULT true,
    min_price_cents INT,
    max_price_cents INT,
    game TEXT[],                                     -- e.g. ['whitetail', 'turkey']
    amenities TEXT[],                                -- e.g. ['camp', 'lodging']
    
    -- Notification preferences per alert
    notify_push BOOLEAN NOT NULL DEFAULT true,
    notify_in_app BOOLEAN NOT NULL DEFAULT true,
    
    -- State
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    last_notified_at TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_opening_alerts_user_enabled 
    ON opening_alerts(user_id, is_enabled);

CREATE INDEX IF NOT EXISTS idx_opening_alerts_state_county 
    ON opening_alerts(state_code, county);

CREATE INDEX IF NOT EXISTS idx_opening_alerts_enabled 
    ON opening_alerts(is_enabled) WHERE is_enabled = true;

-- Unique constraint: one alert per user per location (state + county combination)
-- Using COALESCE to handle NULL county as empty string for uniqueness
CREATE UNIQUE INDEX IF NOT EXISTS idx_opening_alerts_unique_location 
    ON opening_alerts(user_id, state_code, COALESCE(county, ''));

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_opening_alerts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS opening_alerts_updated_at ON opening_alerts;
CREATE TRIGGER opening_alerts_updated_at
    BEFORE UPDATE ON opening_alerts
    FOR EACH ROW
    EXECUTE FUNCTION update_opening_alerts_updated_at();

-- ============================================================================
-- RLS Policies: Users can only manage their own alerts
-- ============================================================================

ALTER TABLE opening_alerts ENABLE ROW LEVEL SECURITY;

-- Allow users to view only their own alerts
CREATE POLICY opening_alerts_select_own ON opening_alerts
    FOR SELECT
    USING (auth.uid() = user_id);

-- Allow users to create alerts only for themselves
CREATE POLICY opening_alerts_insert_own ON opening_alerts
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Allow users to update only their own alerts
CREATE POLICY opening_alerts_update_own ON opening_alerts
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Allow users to delete only their own alerts
CREATE POLICY opening_alerts_delete_own ON opening_alerts
    FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================================
-- 2) Ensure user_notification_prefs table exists with openings_push column
-- ============================================================================

-- Create the table if it doesn't exist
CREATE TABLE IF NOT EXISTS user_notification_prefs (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    push_enabled BOOLEAN NOT NULL DEFAULT true,
    club_post_push BOOLEAN NOT NULL DEFAULT true,
    stand_push BOOLEAN NOT NULL DEFAULT true,
    message_push BOOLEAN NOT NULL DEFAULT true,
    openings_push BOOLEAN NOT NULL DEFAULT true,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Add openings_push column if it doesn't exist (for existing tables)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_notification_prefs' 
        AND column_name = 'openings_push'
    ) THEN
        ALTER TABLE user_notification_prefs 
        ADD COLUMN openings_push BOOLEAN NOT NULL DEFAULT true;
    END IF;
END $$;

-- Enable RLS on user_notification_prefs
ALTER TABLE user_notification_prefs ENABLE ROW LEVEL SECURITY;

-- RLS policies for user_notification_prefs
DROP POLICY IF EXISTS user_notification_prefs_select_own ON user_notification_prefs;
CREATE POLICY user_notification_prefs_select_own ON user_notification_prefs
    FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS user_notification_prefs_insert_own ON user_notification_prefs;
CREATE POLICY user_notification_prefs_insert_own ON user_notification_prefs
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_notification_prefs_update_own ON user_notification_prefs;
CREATE POLICY user_notification_prefs_update_own ON user_notification_prefs
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- 3) Ensure notifications table exists
-- ============================================================================

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,                              -- 'opening_alert', 'club_post', 'stand_signin', 'message'
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB NOT NULL DEFAULT '{}',               -- { route, openingId, state, county, etc. }
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read 
    ON notifications(user_id, is_read);

CREATE INDEX IF NOT EXISTS idx_notifications_created 
    ON notifications(user_id, created_at DESC);

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- RLS policies for notifications
DROP POLICY IF EXISTS notifications_select_own ON notifications;
CREATE POLICY notifications_select_own ON notifications
    FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS notifications_update_own ON notifications;
CREATE POLICY notifications_update_own ON notifications
    FOR UPDATE
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS notifications_delete_own ON notifications;
CREATE POLICY notifications_delete_own ON notifications
    FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================================
-- 4) Ensure device_push_tokens table exists
-- ============================================================================

CREATE TABLE IF NOT EXISTS device_push_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT NOT NULL,                          -- 'ios' or 'android'
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, token)
);

CREATE INDEX IF NOT EXISTS idx_device_push_tokens_user 
    ON device_push_tokens(user_id);

-- Enable RLS
ALTER TABLE device_push_tokens ENABLE ROW LEVEL SECURITY;

-- RLS policies for device_push_tokens
DROP POLICY IF EXISTS device_push_tokens_select_own ON device_push_tokens;
CREATE POLICY device_push_tokens_select_own ON device_push_tokens
    FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS device_push_tokens_insert_own ON device_push_tokens;
CREATE POLICY device_push_tokens_insert_own ON device_push_tokens
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS device_push_tokens_update_own ON device_push_tokens;
CREATE POLICY device_push_tokens_update_own ON device_push_tokens
    FOR UPDATE
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS device_push_tokens_delete_own ON device_push_tokens;
CREATE POLICY device_push_tokens_delete_own ON device_push_tokens
    FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================================
-- 5) RPC functions for notifications
-- ============================================================================

-- Get unread notification count
CREATE OR REPLACE FUNCTION get_unread_notification_count()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INT
        FROM notifications
        WHERE user_id = auth.uid()
        AND is_read = false
    );
END;
$$;

-- Mark specific notifications as read
CREATE OR REPLACE FUNCTION mark_notifications_read(p_notification_ids UUID[])
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE notifications
    SET is_read = true
    WHERE id = ANY(p_notification_ids)
    AND user_id = auth.uid();
    
    RETURN true;
END;
$$;

-- Mark all notifications as read
CREATE OR REPLACE FUNCTION mark_all_notifications_read()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE notifications
    SET is_read = true
    WHERE user_id = auth.uid()
    AND is_read = false;
    
    RETURN true;
END;
$$;

-- ============================================================================
-- Comments for documentation
-- ============================================================================

COMMENT ON TABLE opening_alerts IS 'User subscription alerts for club openings by location and filters';
COMMENT ON TABLE notifications IS 'In-app notifications for users';
COMMENT ON TABLE device_push_tokens IS 'FCM push notification tokens for mobile devices';
COMMENT ON TABLE user_notification_prefs IS 'User notification preferences (global and per-category toggles)';

COMMENT ON COLUMN opening_alerts.state_code IS 'Required 2-letter state code';
COMMENT ON COLUMN opening_alerts.county IS 'Optional county filter';
COMMENT ON COLUMN opening_alerts.last_notified_at IS 'Used for rate limiting (skip if within 30 min)';
COMMENT ON COLUMN opening_alerts.notify_push IS 'Send push notification for this alert';
COMMENT ON COLUMN opening_alerts.notify_in_app IS 'Create in-app notification for this alert';
