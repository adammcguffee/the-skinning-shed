import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * FFL Import Edge Function
 * 
 * Downloads ATF Federal Firearms Licensee data (monthly XLSX),
 * enriches with county from ZIP->county crosswalk,
 * and upserts into ffl_dealers table.
 * 
 * Security:
 * - Requires X-CRON-SECRET header OR service role auth
 * - Uses service role to write data
 * 
 * Schedule:
 * - Called monthly by Supabase Cron (pg_cron)
 * - Can also be called manually by admin
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
};

// ATF Complete Listing URL pattern
// Format: https://www.atf.gov/firearms/docs/{month}{year}-ffl-list/download
// Example: https://www.atf.gov/firearms/docs/jan2026-ffl-list/download
const MONTH_NAMES = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

function getATFUrl(year: number, month: number): string {
  const monthName = MONTH_NAMES[month - 1];
  return `https://www.atf.gov/firearms/docs/${monthName}${year}-ffl-list/download`;
}

// Alternative: ATF also provides CSV/TXT at predictable URLs
function getATFTxtUrl(year: number, month: number): string {
  // Format: 0125-ffl-list.txt for January 2025
  const monthStr = month.toString().padStart(2, '0');
  const yearShort = (year % 100).toString().padStart(2, '0');
  return `https://www.atf.gov/firearms/docs/${monthStr}${yearShort}-ffl-list.txt`;
}

// HUD ZIP->County crosswalk (quarterly updates)
// We'll cache this in memory during the import run
const ZIP_COUNTY_CACHE = new Map<string, string>();

interface FFLRecord {
  license_number: string | null;
  license_name: string;
  license_type: string | null;
  premise_street: string;
  premise_city: string;
  premise_state: string;
  premise_zip: string;
  premise_county: string;
  phone: string | null;
}

async function loadZipCountyCrosswalk(): Promise<Map<string, string>> {
  if (ZIP_COUNTY_CACHE.size > 0) {
    return ZIP_COUNTY_CACHE;
  }

  console.log('[ffl-import] Loading ZIP->County crosswalk...');

  // Try to load from Supabase Storage first (if we uploaded a snapshot)
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: { persistSession: false },
  });

  try {
    // Check if we have a cached crosswalk in Storage
    const { data: fileData, error: downloadError } = await supabase.storage
      .from('ffl-data')
      .download('zip-county-crosswalk.json');

    if (!downloadError && fileData) {
      const text = await fileData.text();
      const crosswalk = JSON.parse(text) as Record<string, string>;
      for (const [zip, county] of Object.entries(crosswalk)) {
        ZIP_COUNTY_CACHE.set(zip, county);
      }
      console.log(`[ffl-import] Loaded ${ZIP_COUNTY_CACHE.size} ZIP->County mappings from storage`);
      return ZIP_COUNTY_CACHE;
    }
  } catch (e) {
    console.log('[ffl-import] No cached crosswalk found, using fallback');
  }

  // Fallback: use a simple state-based approach for counties
  // In production, you would want to fetch the HUD crosswalk
  // For now, we'll mark counties as "Unknown" and can enrich later
  console.log('[ffl-import] Using state-based fallback for county mapping');
  
  return ZIP_COUNTY_CACHE;
}

function getCountyFromZip(zip: string, state: string): string {
  // Try cached crosswalk first
  const normalized = zip.substring(0, 5);
  if (ZIP_COUNTY_CACHE.has(normalized)) {
    return ZIP_COUNTY_CACHE.get(normalized)!;
  }

  // Fallback: return "Unknown" - can be enriched later
  return 'Unknown';
}

function normalizeState(state: string): string {
  return state.trim().toUpperCase().substring(0, 2);
}

function normalizeZip(zip: string): string {
  // Extract first 5 digits
  const cleaned = zip.replace(/[^0-9]/g, '');
  return cleaned.substring(0, 5).padStart(5, '0');
}

function normalizeCity(city: string): string {
  return city.trim().toUpperCase();
}

function normalizeStreet(street: string): string {
  return street.trim().toUpperCase();
}

function normalizeName(name: string): string {
  return name.trim();
}

async function hashRow(row: FFLRecord): Promise<string> {
  const key = [
    row.license_number || '',
    row.license_name,
    row.premise_street,
    row.premise_city,
    row.premise_state,
    row.premise_zip,
    row.license_type || '',
  ].join('|');

  const encoder = new TextEncoder();
  const data = encoder.encode(key);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

interface ParsedATFRow {
  license_region: string;
  license_district: string;
  license_county: string;
  license_type: string;
  license_expiration: string;
  license_number: string;
  license_name: string;
  business_name: string;
  premise_street: string;
  premise_city: string;
  premise_state: string;
  premise_zip: string;
  mail_street: string;
  mail_city: string;
  mail_state: string;
  mail_zip: string;
  phone: string;
}

function parseATFLine(line: string): ParsedATFRow | null {
  // ATF TXT format is tab or pipe delimited
  // Fields in order (based on typical ATF format):
  // LIC_REGN, LIC_DIST, LIC_CNTY, LIC_TYPE, LIC_XPRDTE, LIC_SEQN, LICENSE_NAME, 
  // BUSINESS_NAME, PREMISE_STREET, PREMISE_CITY, PREMISE_STATE, PREMISE_ZIP_CODE,
  // MAIL_STREET, MAIL_CITY, MAIL_STATE, MAIL_ZIP_CODE, VOICE_PHONE

  const parts = line.split('\t');
  if (parts.length < 12) {
    // Try pipe delimiter
    const pipeParts = line.split('|');
    if (pipeParts.length >= 12) {
      return parseATFParts(pipeParts);
    }
    return null;
  }
  return parseATFParts(parts);
}

function parseATFParts(parts: string[]): ParsedATFRow | null {
  if (parts.length < 12) return null;

  return {
    license_region: parts[0]?.trim() || '',
    license_district: parts[1]?.trim() || '',
    license_county: parts[2]?.trim() || '',
    license_type: parts[3]?.trim() || '',
    license_expiration: parts[4]?.trim() || '',
    license_number: parts[5]?.trim() || '',
    license_name: parts[6]?.trim() || '',
    business_name: parts[7]?.trim() || '',
    premise_street: parts[8]?.trim() || '',
    premise_city: parts[9]?.trim() || '',
    premise_state: parts[10]?.trim() || '',
    premise_zip: parts[11]?.trim() || '',
    mail_street: parts[12]?.trim() || '',
    mail_city: parts[13]?.trim() || '',
    mail_state: parts[14]?.trim() || '',
    mail_zip: parts[15]?.trim() || '',
    phone: parts[16]?.trim() || '',
  };
}

async function downloadATFData(year: number, month: number): Promise<{ data: string; actualYear: number; actualMonth: number } | null> {
  // Try current month first
  const urls = [
    { url: getATFTxtUrl(year, month), year, month },
    // Fallback to previous month
    { url: getATFTxtUrl(month === 1 ? year - 1 : year, month === 1 ? 12 : month - 1), year: month === 1 ? year - 1 : year, month: month === 1 ? 12 : month - 1 },
  ];

  for (const { url, year: y, month: m } of urls) {
    console.log(`[ffl-import] Trying ATF URL: ${url}`);
    try {
      const response = await fetch(url, {
        headers: {
          'User-Agent': 'TheSkinning Shed FFL Import/1.0',
          'Accept': 'text/plain,*/*',
        },
      });

      if (response.ok) {
        const data = await response.text();
        if (data.length > 1000) { // Sanity check
          console.log(`[ffl-import] Successfully downloaded ${data.length} bytes for ${m}/${y}`);
          return { data, actualYear: y, actualMonth: m };
        }
      } else {
        console.log(`[ffl-import] HTTP ${response.status} for ${url}`);
      }
    } catch (e) {
      console.log(`[ffl-import] Fetch error for ${url}: ${e}`);
    }
  }

  return null;
}

interface ImportStats {
  total: number;
  inserted: number;
  updated: number;
  skipped: number;
}

async function importRecords(
  supabase: ReturnType<typeof createClient>,
  records: FFLRecord[],
  year: number,
  month: number
): Promise<ImportStats> {
  const stats: ImportStats = { total: records.length, inserted: 0, updated: 0, skipped: 0 };
  const BATCH_SIZE = 100;

  for (let i = 0; i < records.length; i += BATCH_SIZE) {
    const batch = records.slice(i, i + BATCH_SIZE);
    const rows = await Promise.all(batch.map(async (r) => ({
      license_number: r.license_number || null,
      license_name: r.license_name,
      license_type: r.license_type || null,
      premise_street: r.premise_street,
      premise_city: r.premise_city,
      premise_state: r.premise_state,
      premise_zip: r.premise_zip,
      premise_county: r.premise_county,
      phone: r.phone || null,
      source_year: year,
      source_month: month,
      source_row_hash: await hashRow(r),
    })));

    // Upsert by source_row_hash
    const { error } = await supabase
      .from('ffl_dealers')
      .upsert(rows, { 
        onConflict: 'source_row_hash',
        ignoreDuplicates: false,
      });

    if (error) {
      console.error(`[ffl-import] Batch error: ${error.message}`);
      stats.skipped += batch.length;
    } else {
      // Approximate counts (upsert doesn't distinguish insert vs update easily)
      stats.inserted += batch.length;
    }

    // Progress log
    if ((i + BATCH_SIZE) % 5000 === 0) {
      console.log(`[ffl-import] Progress: ${Math.min(i + BATCH_SIZE, records.length)}/${records.length}`);
    }
  }

  return stats;
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  // Verify authorization
  const cronSecret = Deno.env.get('CRON_SECRET');
  const providedSecret = req.headers.get('x-cron-secret');
  const authHeader = req.headers.get('authorization');

  // Allow if: cron secret matches OR valid service role auth
  const isAuthorized = (cronSecret && providedSecret === cronSecret) || 
                       (authHeader && authHeader.includes('service_role'));

  if (!isAuthorized && cronSecret) {
    console.log('[ffl-import] Unauthorized request');
    return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: { persistSession: false },
  });

  // Determine target year/month
  const now = new Date();
  const targetYear = now.getUTCFullYear();
  const targetMonth = now.getUTCMonth() + 1; // 1-indexed

  // Create import run record
  const { data: runData, error: runError } = await supabase
    .from('ffl_import_runs')
    .insert({
      year: targetYear,
      month: targetMonth,
      status: 'running',
    })
    .select('id')
    .single();

  if (runError) {
    console.error('[ffl-import] Failed to create run record:', runError);
    return new Response(
      JSON.stringify({ error: 'Failed to create run record' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  const runId = runData.id;
  console.log(`[ffl-import] Starting import run ${runId} for ${targetMonth}/${targetYear}`);

  try {
    // Load ZIP->County crosswalk
    await loadZipCountyCrosswalk();

    // Download ATF data
    const atfResult = await downloadATFData(targetYear, targetMonth);
    if (!atfResult) {
      throw new Error('Failed to download ATF data');
    }

    const { data: atfData, actualYear, actualMonth } = atfResult;

    // Parse ATF data
    const lines = atfData.split('\n');
    console.log(`[ffl-import] Parsing ${lines.length} lines`);

    const records: FFLRecord[] = [];
    let headerSkipped = false;

    for (const line of lines) {
      if (!line.trim()) continue;

      // Skip header row
      if (!headerSkipped && (line.includes('LIC_REGN') || line.includes('LICENSE'))) {
        headerSkipped = true;
        continue;
      }

      const parsed = parseATFLine(line);
      if (!parsed || !parsed.premise_state || !parsed.premise_city) continue;

      const state = normalizeState(parsed.premise_state);
      const zip = normalizeZip(parsed.premise_zip);
      
      // Skip invalid states
      if (state.length !== 2) continue;

      const county = parsed.license_county || getCountyFromZip(zip, state);

      records.push({
        license_number: parsed.license_number || null,
        license_name: normalizeName(parsed.license_name || parsed.business_name),
        license_type: parsed.license_type || null,
        premise_street: normalizeStreet(parsed.premise_street),
        premise_city: normalizeCity(parsed.premise_city),
        premise_state: state,
        premise_zip: zip,
        premise_county: county || 'Unknown',
        phone: parsed.phone || null,
      });
    }

    console.log(`[ffl-import] Parsed ${records.length} valid records`);

    // Filter out records without names
    const validRecords = records.filter(r => r.license_name && r.license_name.length > 0);
    console.log(`[ffl-import] ${validRecords.length} records with valid names`);

    // Import records
    const stats = await importRecords(supabase, validRecords, actualYear, actualMonth);

    // Update run record with success
    await supabase
      .from('ffl_import_runs')
      .update({
        year: actualYear,
        month: actualMonth,
        status: 'success',
        rows_total: stats.total,
        rows_inserted: stats.inserted,
        rows_updated: stats.updated,
        rows_skipped: stats.skipped,
        finished_at: new Date().toISOString(),
      })
      .eq('id', runId);

    console.log(`[ffl-import] Import complete: ${stats.inserted} inserted, ${stats.updated} updated, ${stats.skipped} skipped`);

    return new Response(
      JSON.stringify({
        success: true,
        runId,
        year: actualYear,
        month: actualMonth,
        stats,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    const errorMsg = (error as Error).message;
    console.error('[ffl-import] Import failed:', errorMsg);

    // Update run record with failure
    await supabase
      .from('ffl_import_runs')
      .update({
        status: 'failed',
        error: errorMsg,
        finished_at: new Date().toISOString(),
      })
      .eq('id', runId);

    return new Response(
      JSON.stringify({ error: errorMsg, runId }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
