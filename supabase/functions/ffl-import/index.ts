import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import * as XLSX from "https://esm.sh/xlsx@0.18.5";

/**
 * FFL Import Edge Function
 * 
 * Discovers and downloads ATF Federal Firearms Licensee XLSX from the ATF website,
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

// Browser-like User-Agent to avoid 403 blocks
const BROWSER_UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

// ATF data page where XLSX links are listed
const ATF_DATA_PAGE = "https://www.atf.gov/firearms/listing-federal-firearms-licensees";

// Month names for matching links
const MONTH_NAMES_FULL = ['january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december'];
const MONTH_NAMES_SHORT = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

// HUD ZIP->County crosswalk cache
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

interface DiscoveredXLSX {
  url: string;
  year: number;
  month: number;
}

/**
 * Fetch ATF data page and discover XLSX links
 */
async function discoverXLSXLinks(): Promise<DiscoveredXLSX[]> {
  console.log(`[ffl-import] Fetching ATF data page: ${ATF_DATA_PAGE}`);
  
  const response = await fetch(ATF_DATA_PAGE, {
    headers: {
      "User-Agent": BROWSER_UA,
      "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "Accept-Language": "en-US,en;q=0.5",
    },
  });

  if (!response.ok) {
    console.error(`[ffl-import] Failed to fetch ATF page: HTTP ${response.status}`);
    throw new Error(`Failed to fetch ATF data page: HTTP ${response.status}`);
  }

  const html = await response.text();
  console.log(`[ffl-import] Received ${html.length} bytes of HTML`);

  // Find all links containing "ffl" and ending with .xlsx
  const linkRegex = /href=["']([^"']*ffl[^"']*\.xlsx)["']/gi;
  const links: DiscoveredXLSX[] = [];
  let match;

  while ((match = linkRegex.exec(html)) !== null) {
    let url = match[1];
    
    // Make absolute URL if relative
    if (url.startsWith("/")) {
      url = `https://www.atf.gov${url}`;
    } else if (!url.startsWith("http")) {
      url = `https://www.atf.gov/${url}`;
    }

    // Try to extract year and month from URL
    const { year, month } = parseYearMonthFromUrl(url);
    
    if (year && month) {
      links.push({ url, year, month });
      console.log(`[ffl-import] Found XLSX link: ${url} (${month}/${year})`);
    } else {
      console.log(`[ffl-import] Found XLSX link (unknown date): ${url}`);
      // Still add it with current date as fallback
      const now = new Date();
      links.push({ url, year: now.getUTCFullYear(), month: now.getUTCMonth() + 1 });
    }
  }

  // Also try alternative patterns for links
  const altLinkRegex = /href=["']([^"']*\.xlsx[^"']*)["'][^>]*>[^<]*ffl/gi;
  while ((match = altLinkRegex.exec(html)) !== null) {
    let url = match[1];
    if (url.startsWith("/")) {
      url = `https://www.atf.gov${url}`;
    }
    
    // Check if we already have this URL
    if (!links.some(l => l.url === url)) {
      const { year, month } = parseYearMonthFromUrl(url);
      const now = new Date();
      links.push({ 
        url, 
        year: year || now.getUTCFullYear(), 
        month: month || now.getUTCMonth() + 1 
      });
      console.log(`[ffl-import] Found alt XLSX link: ${url}`);
    }
  }

  console.log(`[ffl-import] Total XLSX links found: ${links.length}`);
  return links;
}

/**
 * Parse year and month from ATF XLSX URL
 * Examples:
 * - /firearms/docs/0126-ffl-list/download -> 01/2026
 * - /firearms/docs/jan2026-ffl-list.xlsx -> 01/2026
 * - /files/ffl-january-2026.xlsx -> 01/2026
 */
function parseYearMonthFromUrl(url: string): { year: number | null; month: number | null } {
  const lowerUrl = url.toLowerCase();
  
  // Pattern 1: MMYY format (0126, 1225, etc.)
  const mmyyMatch = lowerUrl.match(/(\d{2})(\d{2})-ffl/);
  if (mmyyMatch) {
    const month = parseInt(mmyyMatch[1], 10);
    let year = parseInt(mmyyMatch[2], 10);
    // Convert 2-digit year to 4-digit (assume 2000s)
    year = year < 50 ? 2000 + year : 1900 + year;
    if (month >= 1 && month <= 12) {
      return { year, month };
    }
  }

  // Pattern 2: Month name + year (jan2026, january-2026, etc.)
  for (let i = 0; i < MONTH_NAMES_FULL.length; i++) {
    const fullPattern = new RegExp(`${MONTH_NAMES_FULL[i]}[\\-_]?(\\d{4})`);
    const shortPattern = new RegExp(`${MONTH_NAMES_SHORT[i]}[\\-_]?(\\d{4})`);
    
    let yearMatch = lowerUrl.match(fullPattern) || lowerUrl.match(shortPattern);
    if (yearMatch) {
      return { year: parseInt(yearMatch[1], 10), month: i + 1 };
    }
  }

  // Pattern 3: Year-month (2026-01, 202601)
  const isoMatch = lowerUrl.match(/(\d{4})[\\-_]?(\d{2})/);
  if (isoMatch) {
    const year = parseInt(isoMatch[1], 10);
    const month = parseInt(isoMatch[2], 10);
    if (year >= 2020 && year <= 2030 && month >= 1 && month <= 12) {
      return { year, month };
    }
  }

  return { year: null, month: null };
}

/**
 * Find best XLSX link for target year/month with fallbacks
 */
function findBestXLSXLink(
  links: DiscoveredXLSX[],
  targetYear: number,
  targetMonth: number
): DiscoveredXLSX | null {
  // Try exact match first
  let match = links.find(l => l.year === targetYear && l.month === targetMonth);
  if (match) {
    console.log(`[ffl-import] Found exact match for ${targetMonth}/${targetYear}`);
    return match;
  }

  // Try previous month
  let prevMonth = targetMonth - 1;
  let prevYear = targetYear;
  if (prevMonth < 1) {
    prevMonth = 12;
    prevYear--;
  }
  match = links.find(l => l.year === prevYear && l.month === prevMonth);
  if (match) {
    console.log(`[ffl-import] Found previous month match: ${prevMonth}/${prevYear}`);
    return match;
  }

  // Try 2 months back
  prevMonth--;
  if (prevMonth < 1) {
    prevMonth = 12;
    prevYear--;
  }
  match = links.find(l => l.year === prevYear && l.month === prevMonth);
  if (match) {
    console.log(`[ffl-import] Found 2-months-back match: ${prevMonth}/${prevYear}`);
    return match;
  }

  // Return most recent available
  if (links.length > 0) {
    // Sort by date descending
    const sorted = [...links].sort((a, b) => {
      const dateA = a.year * 100 + a.month;
      const dateB = b.year * 100 + b.month;
      return dateB - dateA;
    });
    console.log(`[ffl-import] Using most recent available: ${sorted[0].month}/${sorted[0].year}`);
    return sorted[0];
  }

  return null;
}

/**
 * Download XLSX file from ATF
 */
async function downloadXLSX(url: string): Promise<ArrayBuffer> {
  console.log(`[ffl-import] Downloading XLSX from: ${url}`);
  
  const response = await fetch(url, {
    headers: {
      "User-Agent": BROWSER_UA,
      "Accept": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/octet-stream,*/*",
      "Accept-Language": "en-US,en;q=0.5",
      "Referer": ATF_DATA_PAGE,
    },
    redirect: "follow",
  });

  if (!response.ok) {
    console.error(`[ffl-import] XLSX download failed: HTTP ${response.status} for ${url}`);
    throw new Error(`Failed to download XLSX: HTTP ${response.status} from ${url}`);
  }

  const buffer = await response.arrayBuffer();
  console.log(`[ffl-import] Downloaded ${buffer.byteLength} bytes`);
  
  if (buffer.byteLength < 1000) {
    throw new Error(`Downloaded file too small (${buffer.byteLength} bytes) - may not be valid XLSX`);
  }

  return buffer;
}

/**
 * Parse XLSX and extract FFL records
 */
function parseXLSX(buffer: ArrayBuffer): FFLRecord[] {
  console.log(`[ffl-import] Parsing XLSX (${buffer.byteLength} bytes)`);
  
  const workbook = XLSX.read(buffer, { type: "array" });
  const sheetName = workbook.SheetNames[0];
  const sheet = workbook.Sheets[sheetName];
  
  // Convert to JSON rows
  const rows: Record<string, unknown>[] = XLSX.utils.sheet_to_json(sheet, { defval: "" });
  console.log(`[ffl-import] Found ${rows.length} rows in sheet "${sheetName}"`);

  if (rows.length === 0) {
    return [];
  }

  // Log first row keys to understand structure
  const firstRow = rows[0];
  const keys = Object.keys(firstRow);
  console.log(`[ffl-import] Column headers: ${keys.slice(0, 10).join(", ")}${keys.length > 10 ? "..." : ""}`);

  const records: FFLRecord[] = [];

  for (const row of rows) {
    // Try to map columns (ATF uses various column names)
    const record = mapRowToFFLRecord(row);
    if (record) {
      records.push(record);
    }
  }

  console.log(`[ffl-import] Parsed ${records.length} valid FFL records`);
  return records;
}

/**
 * Map a row object to FFLRecord, handling various ATF column naming conventions
 */
function mapRowToFFLRecord(row: Record<string, unknown>): FFLRecord | null {
  // Common column name variations
  const getValue = (keys: string[]): string => {
    for (const key of keys) {
      // Try exact match
      if (row[key] !== undefined && row[key] !== null) {
        return String(row[key]).trim();
      }
      // Try case-insensitive match
      const foundKey = Object.keys(row).find(k => k.toLowerCase() === key.toLowerCase());
      if (foundKey && row[foundKey] !== undefined && row[foundKey] !== null) {
        return String(row[foundKey]).trim();
      }
    }
    return "";
  };

  // Extract fields with fallbacks for various column names
  const licenseNumber = getValue([
    "LIC_SEQN", "LICENSE_NUMBER", "License Number", "Lic_Seqn", 
    "LicenseNumber", "FFL", "FFL_NUMBER"
  ]);
  
  const licenseName = getValue([
    "LICENSE_NAME", "License Name", "LicenseName", "BUSINESS_NAME", 
    "Business Name", "NAME", "Name", "DBA"
  ]);
  
  const businessName = getValue([
    "BUSINESS_NAME", "Business Name", "BusinessName", "Trade Name"
  ]);
  
  const licenseType = getValue([
    "LIC_TYPE", "LICENSE_TYPE", "License Type", "Type"
  ]);
  
  const premiseStreet = getValue([
    "PREMISE_STREET", "Premise Street", "PremiseStreet", "PREM_STREET",
    "ADDRESS", "Address", "Street"
  ]);
  
  const premiseCity = getValue([
    "PREMISE_CITY", "Premise City", "PremiseCity", "PREM_CITY", 
    "CITY", "City"
  ]);
  
  const premiseState = getValue([
    "PREMISE_STATE", "Premise State", "PremiseState", "PREM_STATE",
    "STATE", "State"
  ]);
  
  const premiseZip = getValue([
    "PREMISE_ZIP_CODE", "PREMISE_ZIP", "Premise Zip", "PremiseZip",
    "PREM_ZIP", "ZIP", "Zip", "ZIP_CODE", "Zip Code"
  ]);
  
  const licenseCounty = getValue([
    "LIC_CNTY", "LICENSE_COUNTY", "County", "COUNTY"
  ]);
  
  const phone = getValue([
    "VOICE_PHONE", "PHONE", "Phone", "Telephone", "PHONE_NUMBER"
  ]);

  // Validate required fields
  const state = normalizeState(premiseState);
  if (!state || state.length !== 2) {
    return null;
  }

  const city = normalizeCity(premiseCity);
  if (!city) {
    return null;
  }

  const name = normalizeName(licenseName || businessName);
  if (!name) {
    return null;
  }

  const zip = normalizeZip(premiseZip);
  const county = licenseCounty || getCountyFromZip(zip, state);

  return {
    license_number: licenseNumber || null,
    license_name: name,
    license_type: licenseType || null,
    premise_street: normalizeStreet(premiseStreet),
    premise_city: city,
    premise_state: state,
    premise_zip: zip,
    premise_county: county || "Unknown",
    phone: phone || null,
  };
}

async function loadZipCountyCrosswalk(): Promise<Map<string, string>> {
  if (ZIP_COUNTY_CACHE.size > 0) {
    return ZIP_COUNTY_CACHE;
  }

  console.log("[ffl-import] Loading ZIP->County crosswalk...");

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: { persistSession: false },
  });

  try {
    const { data: fileData, error: downloadError } = await supabase.storage
      .from("ffl-data")
      .download("zip-county-crosswalk.json");

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
    console.log("[ffl-import] No cached crosswalk found, using fallback");
  }

  console.log("[ffl-import] Using state-based fallback for county mapping");
  return ZIP_COUNTY_CACHE;
}

function getCountyFromZip(zip: string, _state: string): string {
  const normalized = zip.substring(0, 5);
  if (ZIP_COUNTY_CACHE.has(normalized)) {
    return ZIP_COUNTY_CACHE.get(normalized)!;
  }
  return "Unknown";
}

function normalizeState(state: string): string {
  return state.trim().toUpperCase().substring(0, 2);
}

function normalizeZip(zip: string): string {
  const cleaned = zip.replace(/[^0-9]/g, "");
  return cleaned.substring(0, 5).padStart(5, "0");
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
    row.license_number || "",
    row.license_name,
    row.premise_street,
    row.premise_city,
    row.premise_state,
    row.premise_zip,
    row.license_type || "",
  ].join("|");

  const encoder = new TextEncoder();
  const data = encoder.encode(key);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
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
    const rows = await Promise.all(
      batch.map(async (r) => ({
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
      }))
    );

    const { error } = await supabase.from("ffl_dealers").upsert(rows, {
      onConflict: "source_row_hash",
      ignoreDuplicates: false,
    });

    if (error) {
      console.error(`[ffl-import] Batch error: ${error.message}`);
      stats.skipped += batch.length;
    } else {
      stats.inserted += batch.length;
    }

    if ((i + BATCH_SIZE) % 5000 === 0) {
      console.log(`[ffl-import] Progress: ${Math.min(i + BATCH_SIZE, records.length)}/${records.length}`);
    }
  }

  return stats;
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  // Verify authorization
  const cronSecret = Deno.env.get("CRON_SECRET");
  const providedSecret = req.headers.get("x-cron-secret");
  const authHeader = req.headers.get("authorization");

  const isAuthorized =
    (cronSecret && providedSecret === cronSecret) ||
    (authHeader && authHeader.includes("service_role"));

  if (!isAuthorized && cronSecret) {
    console.log("[ffl-import] Unauthorized request");
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: { persistSession: false },
  });

  // Parse request body for manual override
  let overrideYear: number | null = null;
  let overrideMonth: number | null = null;
  
  try {
    if (req.method === "POST") {
      const body = await req.json();
      if (body.year && body.month) {
        overrideYear = parseInt(body.year, 10);
        overrideMonth = parseInt(body.month, 10);
        console.log(`[ffl-import] Manual override: targeting ${overrideMonth}/${overrideYear}`);
      }
    }
  } catch {
    // No body or invalid JSON - continue with auto-detect
  }

  // Determine target year/month
  const now = new Date();
  const targetYear = overrideYear || now.getUTCFullYear();
  const targetMonth = overrideMonth || now.getUTCMonth() + 1;

  // Create import run record
  const { data: runData, error: runError } = await supabase
    .from("ffl_import_runs")
    .insert({
      year: targetYear,
      month: targetMonth,
      status: "running",
    })
    .select("id")
    .single();

  if (runError) {
    console.error("[ffl-import] Failed to create run record:", runError);
    return new Response(JSON.stringify({ error: "Failed to create run record" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const runId = runData.id;
  console.log(`[ffl-import] Starting import run ${runId} for ${targetMonth}/${targetYear}`);

  try {
    // Load ZIP->County crosswalk
    await loadZipCountyCrosswalk();

    // Discover XLSX links from ATF page
    const xlsxLinks = await discoverXLSXLinks();
    
    if (xlsxLinks.length === 0) {
      throw new Error("No ATF XLSX links found on data page");
    }

    // Find best match for target date
    const selectedLink = findBestXLSXLink(xlsxLinks, targetYear, targetMonth);
    
    if (!selectedLink) {
      throw new Error("No ATF XLSX found for last 3 months");
    }

    console.log(`[ffl-import] Selected XLSX: ${selectedLink.url} (${selectedLink.month}/${selectedLink.year})`);

    // Download XLSX
    const xlsxBuffer = await downloadXLSX(selectedLink.url);

    // Parse XLSX
    const records = parseXLSX(xlsxBuffer);

    if (records.length === 0) {
      throw new Error("No valid FFL records found in XLSX");
    }

    console.log(`[ffl-import] Importing ${records.length} records`);

    // Import records
    const stats = await importRecords(supabase, records, selectedLink.year, selectedLink.month);

    // Update run record with success
    await supabase
      .from("ffl_import_runs")
      .update({
        year: selectedLink.year,
        month: selectedLink.month,
        status: "success",
        rows_total: stats.total,
        rows_inserted: stats.inserted,
        rows_updated: stats.updated,
        rows_skipped: stats.skipped,
        finished_at: new Date().toISOString(),
      })
      .eq("id", runId);

    console.log(
      `[ffl-import] Import complete: ${stats.inserted} inserted, ${stats.updated} updated, ${stats.skipped} skipped`
    );

    return new Response(
      JSON.stringify({
        success: true,
        runId,
        xlsxUrl: selectedLink.url,
        year: selectedLink.year,
        month: selectedLink.month,
        stats,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    const errorMsg = (error as Error).message;
    console.error("[ffl-import] Import failed:", errorMsg);

    // Update run record with failure
    await supabase
      .from("ffl_import_runs")
      .update({
        status: "failed",
        error: errorMsg,
        finished_at: new Date().toISOString(),
      })
      .eq("id", runId);

    return new Response(JSON.stringify({ error: errorMsg, runId }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
