import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * openings-notify Edge Function
 *
 * Called when a new club opening is created. Finds matching alerts and sends
 * notifications to users who have subscribed to those areas.
 *
 * Security:
 * - Uses service role to read alerts/tokens and insert notifications
 * - Rate limited: skip if last_notified_at within 30 minutes
 * - Respects user notification preferences
 *
 * Input: { openingId: string }
 */

const RATE_LIMIT_MINUTES = 30;
const MAX_ALERTS_PER_OPENING = 100; // Safety cap

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ClubOpening {
  id: string;
  owner_id: string;
  title: string;
  state_code: string;
  county: string;
  price_cents: number | null;
  is_available: boolean;
  game: string[] | null;
  amenities: string[] | null;
}

interface OpeningAlert {
  id: string;
  user_id: string;
  state_code: string;
  county: string | null;
  available_only: boolean;
  min_price_cents: number | null;
  max_price_cents: number | null;
  game: string[] | null;
  amenities: string[] | null;
  notify_push: boolean;
  notify_in_app: boolean;
  last_notified_at: string | null;
}

interface NotificationPrefs {
  push_enabled: boolean;
  openings_push: boolean;
}

interface DeviceToken {
  token: string;
  platform: 'ios' | 'android';
}

function formatPrice(priceCents: number | null): string {
  if (priceCents === null) return 'Contact for price';
  const dollars = Math.floor(priceCents / 100);
  return `$${dollars.toLocaleString()}`;
}

function formatNotificationBody(opening: ClubOpening): string {
  const parts: string[] = [];
  parts.push(opening.state_code);
  if (opening.county) parts.push(opening.county);
  parts.push(formatPrice(opening.price_cents));
  return parts.join(' • ');
}

function arraysOverlap(arr1: string[] | null, arr2: string[] | null): boolean {
  if (!arr1 || !arr2 || arr1.length === 0 || arr2.length === 0) return true; // No filter = match
  const set1 = new Set(arr1.map(s => s.toLowerCase()));
  return arr2.some(item => set1.has(item.toLowerCase()));
}

function alertMatchesOpening(alert: OpeningAlert, opening: ClubOpening): boolean {
  // State must match exactly
  if (alert.state_code.toUpperCase() !== opening.state_code.toUpperCase()) {
    return false;
  }

  // If alert has county filter, it must match
  if (alert.county && alert.county.toLowerCase() !== (opening.county || '').toLowerCase()) {
    return false;
  }

  // Available only filter
  if (alert.available_only && !opening.is_available) {
    return false;
  }

  // Price filters: null opening price doesn't match alerts with price bounds
  if (opening.price_cents !== null) {
    if (alert.min_price_cents !== null && opening.price_cents < alert.min_price_cents) {
      return false;
    }
    if (alert.max_price_cents !== null && opening.price_cents > alert.max_price_cents) {
      return false;
    }
  } else {
    // If opening has no price, skip alerts that require price bounds
    if (alert.min_price_cents !== null || alert.max_price_cents !== null) {
      return false;
    }
  }

  // Game filter: must overlap if alert specifies games
  if (alert.game && alert.game.length > 0) {
    if (!arraysOverlap(alert.game, opening.game)) {
      return false;
    }
  }

  // Amenities filter: must overlap if alert specifies amenities
  if (alert.amenities && alert.amenities.length > 0) {
    if (!arraysOverlap(alert.amenities, opening.amenities)) {
      return false;
    }
  }

  return true;
}

function isWithinRateLimit(lastNotifiedAt: string | null): boolean {
  if (!lastNotifiedAt) return false; // Never notified = not rate limited
  const lastTime = new Date(lastNotifiedAt).getTime();
  const now = Date.now();
  const diffMinutes = (now - lastTime) / (1000 * 60);
  return diffMinutes < RATE_LIMIT_MINUTES;
}

async function sendFCMPush(
  token: string,
  title: string,
  body: string,
  data: Record<string, string>
): Promise<boolean> {
  // Get FCM server key from environment
  const fcmKey = Deno.env.get('FCM_SERVER_KEY');
  if (!fcmKey) {
    console.log('[openings-notify] FCM_SERVER_KEY not configured, skipping push');
    return false;
  }

  try {
    const response = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Authorization': `key=${fcmKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to: token,
        notification: {
          title,
          body,
          sound: 'default',
        },
        data,
        priority: 'high',
      }),
    });

    if (!response.ok) {
      console.error(`[openings-notify] FCM error: ${response.status}`);
      return false;
    }

    return true;
  } catch (error) {
    console.error('[openings-notify] FCM send error:', error);
    return false;
  }
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Parse input
    const { openingId } = await req.json();
    
    if (!openingId) {
      return new Response(
        JSON.stringify({ error: 'openingId is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`[openings-notify] Processing opening: ${openingId}`);

    // Create Supabase client with service role
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false },
    });

    // 1. Fetch the opening
    const { data: opening, error: openingError } = await supabase
      .from('club_openings')
      .select('id, owner_id, title, state_code, county, price_cents, is_available, game, amenities')
      .eq('id', openingId)
      .single();

    if (openingError || !opening) {
      console.error('[openings-notify] Opening not found:', openingError);
      return new Response(
        JSON.stringify({ error: 'Opening not found', details: openingError?.message }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`[openings-notify] Opening: ${opening.state_code} ${opening.county || ''} - "${opening.title}"`);

    // 2. Find matching enabled alerts for this state
    // We fetch alerts for the matching state, then filter in code
    const { data: alerts, error: alertsError } = await supabase
      .from('opening_alerts')
      .select('*')
      .eq('is_enabled', true)
      .eq('state_code', opening.state_code.toUpperCase())
      .neq('user_id', opening.owner_id) // Don't notify the owner
      .limit(MAX_ALERTS_PER_OPENING);

    if (alertsError) {
      console.error('[openings-notify] Error fetching alerts:', alertsError);
      return new Response(
        JSON.stringify({ error: 'Failed to fetch alerts' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!alerts || alerts.length === 0) {
      console.log('[openings-notify] No matching alerts found');
      return new Response(
        JSON.stringify({ message: 'No alerts to notify', notified: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`[openings-notify] Found ${alerts.length} potential alerts`);

    // 3. Filter alerts by matching criteria and rate limit
    const matchingAlerts = alerts.filter((alert: OpeningAlert) => {
      // Check if matches filters
      if (!alertMatchesOpening(alert, opening as ClubOpening)) {
        return false;
      }

      // Check rate limit
      if (isWithinRateLimit(alert.last_notified_at)) {
        console.log(`[openings-notify] Alert ${alert.id} rate limited`);
        return false;
      }

      return true;
    });

    console.log(`[openings-notify] ${matchingAlerts.length} alerts passed filters`);

    if (matchingAlerts.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No alerts passed filters', notified: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 4. Batch fetch user notification preferences
    const userIds = [...new Set(matchingAlerts.map((a: OpeningAlert) => a.user_id))];
    const { data: prefsData } = await supabase
      .from('user_notification_prefs')
      .select('user_id, push_enabled, openings_push')
      .in('user_id', userIds);

    const prefsMap = new Map<string, NotificationPrefs>();
    for (const pref of (prefsData || [])) {
      prefsMap.set(pref.user_id, {
        push_enabled: pref.push_enabled ?? true,
        openings_push: pref.openings_push ?? true,
      });
    }

    // 5. Process each matching alert
    let notifiedCount = 0;
    let pushCount = 0;
    let inAppCount = 0;
    const now = new Date().toISOString();

    for (const alert of matchingAlerts) {
      const prefs = prefsMap.get(alert.user_id) || { push_enabled: true, openings_push: true };

      // Create in-app notification if enabled
      if (alert.notify_in_app) {
        const notificationBody = formatNotificationBody(opening as ClubOpening);
        
        const { error: insertError } = await supabase
          .from('notifications')
          .insert({
            user_id: alert.user_id,
            type: 'opening_alert',
            title: 'New Club Opening',
            body: `${notificationBody} • "${opening.title}"`,
            data: {
              route: `/openings/${opening.id}`,
              openingId: opening.id,
              state: opening.state_code,
              county: opening.county || null,
            },
          });

        if (!insertError) {
          inAppCount++;
        } else {
          console.error(`[openings-notify] Failed to insert notification for ${alert.user_id}:`, insertError);
        }
      }

      // Send push notification if enabled (alert + global prefs)
      if (alert.notify_push && prefs.push_enabled && prefs.openings_push) {
        // Get device tokens for this user
        const { data: tokens } = await supabase
          .from('device_push_tokens')
          .select('token, platform')
          .eq('user_id', alert.user_id);

        if (tokens && tokens.length > 0) {
          for (const deviceToken of tokens) {
            const pushBody = formatNotificationBody(opening as ClubOpening);
            const success = await sendFCMPush(
              deviceToken.token,
              'New Club Opening',
              pushBody,
              { route: `/openings/${opening.id}` }
            );
            if (success) pushCount++;
          }
        }
      }

      // Update last_notified_at for rate limiting
      await supabase
        .from('opening_alerts')
        .update({ last_notified_at: now })
        .eq('id', alert.id);

      notifiedCount++;
    }

    console.log(`[openings-notify] Complete: ${notifiedCount} alerts, ${inAppCount} in-app, ${pushCount} push`);

    return new Response(
      JSON.stringify({
        message: 'Notifications sent',
        notified: notifiedCount,
        inApp: inAppCount,
        push: pushCount,
        openingId,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('[openings-notify] Error:', error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
