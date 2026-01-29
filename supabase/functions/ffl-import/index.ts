import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import * as XLSX from "https://esm.sh/xlsx@0.18.5";

/**
 * FFL Import Edge Function
 * 
 * Downloads ATF Federal Firearms Licensee data from Data.gov mirror
 * (ATF.gov blocks server-side requests), enriches with county from 
 * ZIP->county crosswalk, and upserts into ffl_dealers table.
 * 
 * Data source: https://catalog.data.gov/dataset/federal-firearms-licensees
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

// Data.gov CKAN API for ATF FFL dataset
// Note: The actual dataset slug includes the month/year suffix
const DATA_GOV_DATASET_ID = "federal-firearms-licensees-december-2021";
const DATA_GOV_API_URL = `https://catalog.data.gov/api/3/action/package_show?id=${DATA_GOV_DATASET_ID}`;

// ArcGIS REST API base - used when Data.gov links to ArcGIS item pages
const ARCGIS_REST_BASE = "https://atf-geoplatform.maps.arcgis.com/sharing/rest/content/items";

// Month names for parsing resource names
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

interface DataGovResource {
  id: string;
  name: string;
  url: string;
  format: string;
  created: string;
  last_modified: string;
  description?: string;
}

interface DiscoveredResource {
  url: string;
  format: string;
  name: string;
  year: number;
  month: number;
  lastModified: string;
  arcgisItemId: string | null; // If this is an ArcGIS resource, store the item ID
}

/**
 * Extract ArcGIS item ID from various URL formats
 * Returns null if not an ArcGIS URL
 */
function extractArcGISItemId(url: string): string | null {
  // Pattern: .../home/item.html?id=<ITEM_ID>
  const itemMatch = url.match(/item\.html\?id=([a-zA-Z0-9]+)/);
  if (itemMatch) {
    return itemMatch[1];
  }
  
  // Pattern: .../items/<ITEM_ID>
  const restMatch = url.match(/\/items\/([a-zA-Z0-9]+)(?:\/|$)/);
  if (restMatch) {
    return restMatch[1];
  }
  
  // Pattern: arcgis.com URLs with id param
  const idParamMatch = url.match(/[?&]id=([a-zA-Z0-9]+)/);
  if (idParamMatch && url.includes("arcgis.com")) {
    return idParamMatch[1];
  }
  
  return null;
}

/**
 * Fetch ArcGIS item metadata and return the actual download URL
 * ArcGIS requires fetching metadata JSON first to get the real dataUrl
 * For public binary downloads, ArcGIS requires f=download parameter
 */
async function getArcGISDownloadUrl(itemId: string): Promise<{ url: string; type: string; size: number }> {
  const metadataUrl = `${ARCGIS_REST_BASE}/${itemId}?f=json`;
  console.log(`[ffl-import] Fetching ArcGIS item metadata: ${metadataUrl}`);
  
  const response = await fetch(metadataUrl, {
    headers: {
      "Accept": "application/json",
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch ArcGIS item metadata: HTTP ${response.status} from ${metadataUrl}`);
  }

  const metadata = await response.json();
  
  // Check for error in response
  if (metadata.error) {
    throw new Error(`ArcGIS API error: ${metadata.error.message || JSON.stringify(metadata.error)}`);
  }

  const dataUrl = metadata.url || metadata.dataUrl;
  const itemType = metadata.type || "unknown";
  const size = metadata.size || 0;

  console.log(`[ffl-import] ArcGIS item metadata:`);
  console.log(`[ffl-import]   - itemId: ${itemId}`);
  console.log(`[ffl-import]   - type: ${itemType}`);
  console.log(`[ffl-import]   - size: ${size} bytes`);
  console.log(`[ffl-import]   - dataUrl from metadata: ${dataUrl || "(none)"}`);

  // If dataUrl exists in metadata, use it exactly as-is
  if (dataUrl) {
    console.log(`[ffl-import] Using dataUrl from metadata: ${dataUrl}`);
    return { url: dataUrl, type: itemType, size };
  }

  // No dataUrl in metadata - construct download URL with f=download (required for public binary access)
  const downloadUrl = `${ARCGIS_REST_BASE}/${itemId}/data?f=download`;
  console.log(`[ffl-import] No dataUrl in metadata, using f=download endpoint: ${downloadUrl}`);
  return { url: downloadUrl, type: itemType, size };
}

/**
 * Fetch Data.gov dataset metadata and find FFL resources
 */
async function discoverDataGovResources(): Promise<DiscoveredResource[]> {
  console.log(`[ffl-import] Fetching Data.gov dataset: ${DATA_GOV_API_URL}`);
  console.log(`[ffl-import] Dataset ID: ${DATA_GOV_DATASET_ID}`);
  
  const response = await fetch(DATA_GOV_API_URL, {
    headers: {
      "Accept": "application/json",
    },
  });

  if (!response.ok) {
    console.error(`[ffl-import] Failed to fetch Data.gov API: HTTP ${response.status} from ${DATA_GOV_API_URL}`);
    throw new Error(`Failed to fetch Data.gov dataset '${DATA_GOV_DATASET_ID}': HTTP ${response.status}`);
  }

  const data = await response.json();
  
  if (!data.success || !data.result) {
    console.error(`[ffl-import] Invalid Data.gov API response: success=${data.success}`);
    throw new Error("Invalid Data.gov API response - missing result");
  }

  const resources: DataGovResource[] = data.result.resources || [];
  console.log(`[ffl-import] Found ${resources.length} resources in dataset`);

  // Log all resources for debugging
  for (const r of resources) {
    console.log(`[ffl-import] Resource: "${r.name}" format=${r.format} url=${r.url?.substring(0, 80)}...`);
  }

  const discovered: DiscoveredResource[] = [];

  for (const resource of resources) {
    const format = (resource.format || "").toUpperCase();
    const name = (resource.name || "").toUpperCase();
    let url = resource.url;

    // Skip if no URL
    if (!url) {
      continue;
    }

    // Only consider EXCEL/XLS/XLSX or CSV files
    const isExcel = format.includes("EXCEL") || format.includes("XLS") || format.includes("XLSX") ||
                    name.includes("EXCEL") || name.includes("XLS");
    const isCsv = format.includes("CSV") || name.includes("CSV");
    
    if (!isExcel && !isCsv) {
      console.log(`[ffl-import] Skipping non-data resource: ${resource.name} (format: ${format})`);
      continue;
    }

    // Check if this is an ArcGIS URL and extract item ID
    const arcgisItemId = extractArcGISItemId(url);
    if (arcgisItemId) {
      console.log(`[ffl-import] Detected ArcGIS resource with itemId: ${arcgisItemId}`);
    }

    // Try to extract year/month from resource name or URL
    const dateInfo = parseYearMonthFromText(resource.name || "") || parseYearMonthFromText(url);
    const lastModified = resource.last_modified || resource.created || "";

    const now = new Date();
    discovered.push({
      url,
      format: isExcel ? "xlsx" : "csv",
      name: resource.name || url,
      year: dateInfo?.year || now.getUTCFullYear(),
      month: dateInfo?.month || now.getUTCMonth() + 1,
      lastModified,
      arcgisItemId,
    });

    console.log(`[ffl-import] Found data resource: ${resource.name} (${format})${arcgisItemId ? ` [ArcGIS: ${arcgisItemId}]` : ""}`);
  }

  // Sort: EXCEL first (typically more complete), then by last_modified descending
  discovered.sort((a, b) => {
    // Prefer EXCEL over CSV (ATF EXCEL files are typically more complete)
    if (a.format === "xlsx" && b.format !== "xlsx") return -1;
    if (b.format === "xlsx" && a.format !== "xlsx") return 1;
    
    // Then by last_modified (most recent first)
    if (a.lastModified && b.lastModified) {
      const dateA = new Date(a.lastModified).getTime();
      const dateB = new Date(b.lastModified).getTime();
      if (dateA !== dateB) return dateB - dateA;
    }
    
    // Finally by year/month
    const dateA = a.year * 100 + a.month;
    const dateB = b.year * 100 + b.month;
    return dateB - dateA;
  });

  console.log(`[ffl-import] Total usable data resources found: ${discovered.length}`);
  return discovered;
}

/**
 * Parse year and month from text (resource name or URL)
 */
function parseYearMonthFromText(text: string): { year: number; month: number } | null {
  const lowerText = text.toLowerCase();
  
  // Pattern 1: MMYY or MMYYYY format (0126, 012026, 1225, etc.)
  const mmyyMatch = lowerText.match(/(\d{2})[\-_]?(\d{2,4})(?:\D|$)/);
  if (mmyyMatch) {
    const first = parseInt(mmyyMatch[1], 10);
    let second = parseInt(mmyyMatch[2], 10);
    
    // If second is 2 digits, convert to 4-digit year
    if (second < 100) {
      second = second < 50 ? 2000 + second : 1900 + second;
    }
    
    // Check if first could be a month (1-12)
    if (first >= 1 && first <= 12 && second >= 2020 && second <= 2030) {
      return { year: second, month: first };
    }
  }

  // Pattern 2: Month name + year (january 2026, jan-2026, etc.)
  for (let i = 0; i < MONTH_NAMES_FULL.length; i++) {
    const fullPattern = new RegExp(`${MONTH_NAMES_FULL[i]}[\\s\\-_]*(\\d{4})`);
    const shortPattern = new RegExp(`${MONTH_NAMES_SHORT[i]}[\\s\\-_]*(\\d{4})`);
    
    const yearMatch = lowerText.match(fullPattern) || lowerText.match(shortPattern);
    if (yearMatch) {
      return { year: parseInt(yearMatch[1], 10), month: i + 1 };
    }
  }

  // Pattern 3: Year + month name (2026 january, 2026-jan)
  for (let i = 0; i < MONTH_NAMES_FULL.length; i++) {
    const fullPattern = new RegExp(`(\\d{4})[\\s\\-_]*${MONTH_NAMES_FULL[i]}`);
    const shortPattern = new RegExp(`(\\d{4})[\\s\\-_]*${MONTH_NAMES_SHORT[i]}`);
    
    const yearMatch = lowerText.match(fullPattern) || lowerText.match(shortPattern);
    if (yearMatch) {
      return { year: parseInt(yearMatch[1], 10), month: i + 1 };
    }
  }

  // Pattern 4: Year-month ISO style (2026-01, 202601)
  const isoMatch = lowerText.match(/(\d{4})[\-_]?(\d{2})(?:\D|$)/);
  if (isoMatch) {
    const year = parseInt(isoMatch[1], 10);
    const month = parseInt(isoMatch[2], 10);
    if (year >= 2020 && year <= 2030 && month >= 1 && month <= 12) {
      return { year, month };
    }
  }

  return null;
}

/**
 * Select the best resource (prefer CSV, most recent)
 */
function selectBestResource(resources: DiscoveredResource[]): DiscoveredResource | null {
  if (resources.length === 0) {
    return null;
  }
  // Already sorted by format and date, just pick first
  return resources[0];
}

/**
 * Download file from URL
 */
async function downloadFile(url: string): Promise<ArrayBuffer> {
  console.log(`[ffl-import] Downloading file from: ${url}`);
  
  const response = await fetch(url, {
    headers: {
      "Accept": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/vnd.ms-excel, text/csv, */*",
      "User-Agent": "TheSkiningShed-FFL-Import/1.0",
    },
    redirect: "follow",
  });

  const contentType = response.headers.get("content-type") || "unknown";
  console.log(`[ffl-import] Response status: ${response.status}, content-type: ${contentType}`);

  if (!response.ok) {
    console.error(`[ffl-import] Download failed: HTTP ${response.status} for ${url}`);
    console.error(`[ffl-import] Response content-type: ${contentType}`);
    
    // Try to read error message if it's text/html or json
    if (contentType.includes("text") || contentType.includes("json")) {
      try {
        const errorText = await response.text();
        console.error(`[ffl-import] Error response body (first 500 chars): ${errorText.substring(0, 500)}`);
      } catch {
        // Ignore read errors
      }
    }
    
    throw new Error(`Failed to download file: HTTP ${response.status} from ${url}`);
  }

  // Validate content-type is not HTML (error page)
  if (contentType.includes("text/html")) {
    const htmlContent = await response.text();
    console.error(`[ffl-import] Received HTML instead of data file. First 500 chars: ${htmlContent.substring(0, 500)}`);
    throw new Error(`Received HTML error page instead of data file from ${url}`);
  }

  const buffer = await response.arrayBuffer();
  console.log(`[ffl-import] Downloaded ${buffer.byteLength} bytes (content-type: ${contentType})`);
  
  if (buffer.byteLength < 100) {
    throw new Error(`Downloaded file too small (${buffer.byteLength} bytes) - may not be valid data file`);
  }

  return buffer;
}

/**
 * Parse CSV content into FFL records
 */
function parseCSV(buffer: ArrayBuffer): FFLRecord[] {
  const decoder = new TextDecoder("utf-8");
  const text = decoder.decode(buffer);
  const lines = text.split(/\r?\n/);
  
  console.log(`[ffl-import] Parsing CSV with ${lines.length} lines`);

  if (lines.length < 2) {
    return [];
  }

  // Parse header row
  const headerLine = lines[0];
  const headers = parseCSVLine(headerLine).map(h => h.trim());
  console.log(`[ffl-import] CSV headers: ${headers.slice(0, 10).join(", ")}${headers.length > 10 ? "..." : ""}`);

  const records: FFLRecord[] = [];

  for (let i = 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;

    const values = parseCSVLine(line);
    const row: Record<string, string> = {};
    
    for (let j = 0; j < headers.length && j < values.length; j++) {
      row[headers[j]] = values[j];
    }

    const record = mapRowToFFLRecord(row);
    if (record) {
      records.push(record);
    }
  }

  console.log(`[ffl-import] Parsed ${records.length} valid FFL records from CSV`);
  return records;
}

/**
 * Parse a single CSV line handling quoted fields
 */
function parseCSVLine(line: string): string[] {
  const result: string[] = [];
  let current = "";
  let inQuotes = false;
  
  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    const nextChar = line[i + 1];
    
    if (char === '"') {
      if (inQuotes && nextChar === '"') {
        // Escaped quote
        current += '"';
        i++;
      } else {
        // Toggle quote mode
        inQuotes = !inQuotes;
      }
    } else if (char === "," && !inQuotes) {
      result.push(current.trim());
      current = "";
    } else {
      current += char;
    }
  }
  
  result.push(current.trim());
  return result;
}

/**
 * Parse XLSX and extract FFL records (fallback if no CSV available)
 */
function parseXLSX(buffer: ArrayBuffer): FFLRecord[] {
  console.log(`[ffl-import] Parsing XLSX (${buffer.byteLength} bytes)`);
  
  const workbook = XLSX.read(buffer, { type: "array" });
  const sheetName = workbook.SheetNames[0];
  const sheet = workbook.Sheets[sheetName];
  
  const rows: Record<string, unknown>[] = XLSX.utils.sheet_to_json(sheet, { defval: "" });
  console.log(`[ffl-import] Found ${rows.length} rows in sheet "${sheetName}"`);

  if (rows.length === 0) {
    return [];
  }

  const firstRow = rows[0];
  const keys = Object.keys(firstRow);
  console.log(`[ffl-import] Column headers: ${keys.slice(0, 10).join(", ")}${keys.length > 10 ? "..." : ""}`);

  const records: FFLRecord[] = [];

  for (const row of rows) {
    const stringRow: Record<string, string> = {};
    for (const [key, value] of Object.entries(row)) {
      stringRow[key] = String(value ?? "").trim();
    }
    
    const record = mapRowToFFLRecord(stringRow);
    if (record) {
      records.push(record);
    }
  }

  console.log(`[ffl-import] Parsed ${records.length} valid FFL records from XLSX`);
  return records;
}

/**
 * Map a row object to FFLRecord, handling various column naming conventions
 */
function mapRowToFFLRecord(row: Record<string, string>): FFLRecord | null {
  const getValue = (keys: string[]): string => {
    for (const key of keys) {
      if (row[key] !== undefined && row[key] !== "") {
        return row[key].trim();
      }
      // Case-insensitive match
      const foundKey = Object.keys(row).find(k => k.toLowerCase() === key.toLowerCase());
      if (foundKey && row[foundKey] !== undefined && row[foundKey] !== "") {
        return row[foundKey].trim();
      }
    }
    return "";
  };

  // Extract fields with fallbacks for various column names
  const licenseNumber = getValue([
    "LIC_SEQN", "LICENSE_NUMBER", "License Number", "Lic_Seqn", 
    "LicenseNumber", "FFL", "FFL_NUMBER", "License_Number"
  ]);
  
  const licenseName = getValue([
    "LICENSE_NAME", "License Name", "LicenseName", "License_Name",
    "BUSINESS_NAME", "Business Name", "NAME", "Name", "DBA"
  ]);
  
  const businessName = getValue([
    "BUSINESS_NAME", "Business Name", "BusinessName", "Business_Name", "Trade Name"
  ]);
  
  const licenseType = getValue([
    "LIC_TYPE", "LICENSE_TYPE", "License Type", "License_Type", "Type"
  ]);
  
  const premiseStreet = getValue([
    "PREMISE_STREET", "Premise Street", "PremiseStreet", "Premise_Street",
    "PREM_STREET", "ADDRESS", "Address", "Street", "STREET"
  ]);
  
  const premiseCity = getValue([
    "PREMISE_CITY", "Premise City", "PremiseCity", "Premise_City",
    "PREM_CITY", "CITY", "City"
  ]);
  
  const premiseState = getValue([
    "PREMISE_STATE", "Premise State", "PremiseState", "Premise_State",
    "PREM_STATE", "STATE", "State"
  ]);
  
  const premiseZip = getValue([
    "PREMISE_ZIP_CODE", "PREMISE_ZIP", "Premise Zip", "PremiseZip", "Premise_Zip",
    "PREM_ZIP", "ZIP", "Zip", "ZIP_CODE", "Zip Code", "Zip_Code"
  ]);
  
  const licenseCounty = getValue([
    "LIC_CNTY", "LICENSE_COUNTY", "County", "COUNTY", "License_County"
  ]);
  
  const phone = getValue([
    "VOICE_PHONE", "PHONE", "Phone", "Telephone", "PHONE_NUMBER", "Phone_Number"
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
  } catch {
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
  const startTime = Date.now();
  
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
  let overrideResourceUrl: string | null = null;
  
  try {
    if (req.method === "POST") {
      const body = await req.json();
      if (body.resource_url) {
        overrideResourceUrl = body.resource_url;
        console.log(`[ffl-import] Manual override: using resource URL`);
      }
    }
  } catch {
    // No body or invalid JSON - continue with auto-discover
  }

  // Determine target year/month
  const now = new Date();
  const targetYear = now.getUTCFullYear();
  const targetMonth = now.getUTCMonth() + 1;

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

    let resourceUrl: string;
    let resourceFormat: string;
    let resourceLastModified: string = "";
    let actualYear = targetYear;
    let actualMonth = targetMonth;

    if (overrideResourceUrl) {
      // Use manual override URL
      resourceUrl = overrideResourceUrl;
      resourceFormat = resourceUrl.toLowerCase().includes(".csv") ? "csv" : "xlsx";
      console.log(`[ffl-import] Using manual resource URL: ${resourceUrl}`);
    } else {
      // Discover resources from Data.gov
      console.log(`[ffl-import] Discovering resources from Data.gov...`);
      const resources = await discoverDataGovResources();
      
      if (resources.length === 0) {
        throw new Error("No FFL resources found on Data.gov dataset");
      }

      // Select best resource (prefers CSV, most recent)
      const selectedResource = selectBestResource(resources);
      
      if (!selectedResource) {
        throw new Error("No suitable FFL resource found");
      }

      resourceFormat = selectedResource.format;
      resourceLastModified = selectedResource.lastModified;
      actualYear = selectedResource.year;
      actualMonth = selectedResource.month;
      
      console.log(`[ffl-import] Selected resource: ${selectedResource.name}`);
      console.log(`[ffl-import] Resource format: ${resourceFormat}`);
      console.log(`[ffl-import] Resource last_modified: ${resourceLastModified}`);

      // If this is an ArcGIS resource, fetch metadata to get the real download URL
      if (selectedResource.arcgisItemId) {
        console.log(`[ffl-import] Fetching ArcGIS download URL for item: ${selectedResource.arcgisItemId}`);
        const arcgisInfo = await getArcGISDownloadUrl(selectedResource.arcgisItemId);
        resourceUrl = arcgisInfo.url;
        console.log(`[ffl-import] ArcGIS download URL: ${resourceUrl}`);
      } else {
        resourceUrl = selectedResource.url;
        console.log(`[ffl-import] Direct resource URL: ${resourceUrl}`);
      }
    }

    // Download the file
    const fileBuffer = await downloadFile(resourceUrl);

    // Parse based on format
    let records: FFLRecord[];
    if (resourceFormat === "csv") {
      records = parseCSV(fileBuffer);
    } else {
      records = parseXLSX(fileBuffer);
    }

    if (records.length === 0) {
      throw new Error("No valid FFL records found in file");
    }

    console.log(`[ffl-import] Importing ${records.length} records`);

    // Import records
    const stats = await importRecords(supabase, records, actualYear, actualMonth);

    const duration = Date.now() - startTime;

    // Update run record with success
    await supabase
      .from("ffl_import_runs")
      .update({
        year: actualYear,
        month: actualMonth,
        status: "success",
        rows_total: stats.total,
        rows_inserted: stats.inserted,
        rows_updated: stats.updated,
        rows_skipped: stats.skipped,
        finished_at: new Date().toISOString(),
      })
      .eq("id", runId);

    console.log(`[ffl-import] Import complete in ${duration}ms`);
    console.log(`[ffl-import] Stats: ${stats.inserted} inserted, ${stats.updated} updated, ${stats.skipped} skipped`);

    return new Response(
      JSON.stringify({
        success: true,
        runId,
        dataSource: "data.gov",
        resourceUrl,
        resourceFormat,
        resourceLastModified,
        year: actualYear,
        month: actualMonth,
        stats,
        durationMs: duration,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    const errorMsg = (error as Error).message;
    const duration = Date.now() - startTime;
    console.error(`[ffl-import] Import failed after ${duration}ms:`, errorMsg);

    // Update run record with failure
    await supabase
      .from("ffl_import_runs")
      .update({
        status: "failed",
        error: errorMsg,
        finished_at: new Date().toISOString(),
      })
      .eq("id", runId);

    return new Response(JSON.stringify({ error: errorMsg, runId, durationMs: duration }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
