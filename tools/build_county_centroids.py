#!/usr/bin/env python3
"""
Build script to generate county_centroids.json from US Census Gazetteer data.

Downloads the Census Bureau's county gazetteer file and extracts:
- GEOID (5-digit FIPS code): unique county identifier
- USPS: 2-letter state code
- NAME: county name
- INTPTLAT: internal point latitude (centroid-like)
- INTPTLONG: internal point longitude

Output: app/assets/data/county_centroids.json

Usage:
    python tools/build_county_centroids.py

The generated JSON is committed to the repo so the app works offline.
"""

import json
import os
import sys
import urllib.request
import zipfile
import io
import re

# Census Gazetteer URL (2023 data - pinned for reproducibility)
GAZETTEER_URL = "https://www2.census.gov/geo/docs/maps-data/data/gazetteer/2023_Gazetteer/2023_Gaz_counties_national.zip"

# Output path relative to repo root
OUTPUT_PATH = "app/assets/data/county_centroids.json"

def normalize_county_name(name: str) -> str:
    """
    Normalize county name for lookup matching.
    Strips common suffixes like County, Parish, Borough, etc.
    """
    name = name.strip()
    # Remove common suffixes for normalized matching
    suffixes = [
        " County", " Parish", " Borough", " Census Area",
        " Municipality", " city", " City and Borough"
    ]
    normalized = name
    for suffix in suffixes:
        if normalized.endswith(suffix):
            normalized = normalized[:-len(suffix)]
            break
    return normalized.strip()

def download_gazetteer() -> str:
    """Download and extract the gazetteer TSV file."""
    print(f"Downloading Census Gazetteer from {GAZETTEER_URL}...")
    
    try:
        with urllib.request.urlopen(GAZETTEER_URL, timeout=60) as response:
            zip_data = response.read()
    except Exception as e:
        print(f"Error downloading: {e}")
        sys.exit(1)
    
    print("Extracting ZIP...")
    with zipfile.ZipFile(io.BytesIO(zip_data)) as zf:
        # Find the text file in the ZIP
        txt_files = [f for f in zf.namelist() if f.endswith('.txt')]
        if not txt_files:
            print("Error: No .txt file found in ZIP")
            sys.exit(1)
        
        txt_name = txt_files[0]
        print(f"Found: {txt_name}")
        return zf.read(txt_name).decode('utf-8')

def parse_gazetteer(content: str) -> dict:
    """
    Parse the gazetteer TSV into a dictionary keyed by FIPS code.
    
    Expected columns (tab-separated):
    USPS, GEOID, ANSICODE, NAME, ALAND, AWATER, ALAND_SQMI, AWATER_SQMI, INTPTLAT, INTPTLONG
    """
    lines = content.strip().split('\n')
    if not lines:
        print("Error: Empty gazetteer file")
        sys.exit(1)
    
    # Parse header
    header = lines[0].strip().split('\t')
    header = [h.strip() for h in header]
    
    # Find column indices
    try:
        idx_usps = header.index('USPS')
        idx_geoid = header.index('GEOID')
        idx_name = header.index('NAME')
        idx_lat = header.index('INTPTLAT')
        idx_lon = header.index('INTPTLONG')
    except ValueError as e:
        print(f"Error: Missing expected column: {e}")
        print(f"Found columns: {header}")
        sys.exit(1)
    
    counties = {}
    skipped = 0
    
    for line in lines[1:]:
        if not line.strip():
            continue
        
        parts = line.strip().split('\t')
        if len(parts) <= max(idx_usps, idx_geoid, idx_name, idx_lat, idx_lon):
            skipped += 1
            continue
        
        try:
            usps = parts[idx_usps].strip()
            geoid = parts[idx_geoid].strip()
            name = parts[idx_name].strip()
            lat = float(parts[idx_lat].strip())
            lon = float(parts[idx_lon].strip())
            
            # Ensure GEOID is 5 digits (zero-padded)
            geoid = geoid.zfill(5)
            
            # Create normalized name for lookup
            normalized = normalize_county_name(name).lower()
            
            counties[geoid] = {
                "state": usps,
                "name": name,
                "normalized": normalized,
                "lat": round(lat, 4),  # 4 decimal places = ~11m precision
                "lon": round(lon, 4),
            }
        except (ValueError, IndexError) as e:
            skipped += 1
            continue
    
    print(f"Parsed {len(counties)} counties, skipped {skipped} invalid rows")
    return counties

def build_lookup_index(counties: dict) -> dict:
    """
    Build a secondary index for state+name lookup.
    Key: "STATE:normalized_name" -> FIPS
    """
    index = {}
    for fips, data in counties.items():
        key = f"{data['state']}:{data['normalized']}"
        index[key] = fips
    return index

def main():
    # Determine repo root (script is in tools/)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)
    output_file = os.path.join(repo_root, OUTPUT_PATH)
    
    # Ensure output directory exists
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    # Download and parse
    content = download_gazetteer()
    counties = parse_gazetteer(content)
    
    if not counties:
        print("Error: No counties parsed")
        sys.exit(1)
    
    # Build lookup index
    lookup_index = build_lookup_index(counties)
    
    # Combine into output structure
    output = {
        "source": "US Census Bureau Gazetteer 2023",
        "generated": True,
        "counties": counties,
        "lookup": lookup_index,  # state:name -> fips
    }
    
    # Write JSON
    print(f"Writing to {output_file}...")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(output, f, separators=(',', ':'))  # Compact JSON
    
    # Stats
    file_size = os.path.getsize(output_file)
    print(f"Done! Generated {len(counties)} counties")
    print(f"File size: {file_size / 1024:.1f} KB")
    
    # Sample output
    print("\nSample entries:")
    for i, (fips, data) in enumerate(list(counties.items())[:3]):
        print(f"  {fips}: {data['name']}, {data['state']} ({data['lat']}, {data['lon']})")

if __name__ == "__main__":
    main()
