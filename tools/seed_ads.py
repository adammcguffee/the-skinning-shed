#!/usr/bin/env python3
"""
Ad Seeding Script for The Skinning Shed

This script:
1. Creates sample ad images (placeholder PNGs)
2. Uploads them to Supabase Storage (ad_share bucket)
3. Seeds the ad_slots table with entries for all pages

USAGE:
    export SUPABASE_URL="https://your-project.supabase.co"
    export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
    python tools/seed_ads.py

IMPORTANT: 
- Use SERVICE ROLE key (not anon key) for this script
- NEVER commit service role keys
- Run locally or in CI with proper secrets
"""

import os
import sys
from io import BytesIO

try:
    from supabase import create_client
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Missing dependencies. Install with:")
    print("  pip install supabase pillow")
    sys.exit(1)


# Ad slot registry - must match app/lib/ads/ad_slot_registry.dart
PAGES = [
    'feed',
    'explore',
    'trophy_wall',
    'land',
    'messages',
    'weather',
    'research',
    'regulations',
    'settings',
    'swap_shop',
]

POSITIONS = ['left', 'right']

# Sample ad configurations
SAMPLE_ADS = [
    {
        'filename': 'sample_01.png',
        'title': 'Sample Ad',
        'subtitle': 'The Skinning Shed',
        'bg_color': '#1B3D36',
        'accent_color': '#CD8232',
    },
    {
        'filename': 'sample_02.png',
        'title': 'Gear Sale',
        'subtitle': '(Sample)',
        'bg_color': '#2D4A44',
        'accent_color': '#E8A54B',
    },
    {
        'filename': 'sample_03.png',
        'title': 'Land Lease',
        'subtitle': '(Sample)',
        'bg_color': '#243832',
        'accent_color': '#7CB342',
    },
    {
        'filename': 'sample_04.png',
        'title': 'Swap Shop',
        'subtitle': 'Promo (Sample)',
        'bg_color': '#1E3530',
        'accent_color': '#4FC3F7',
    },
]


def hex_to_rgb(hex_color: str) -> tuple:
    """Convert hex color to RGB tuple."""
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))


def create_sample_ad(config: dict, width: int = 400, height: int = 200) -> bytes:
    """Create a sample ad image with the given configuration."""
    bg_color = hex_to_rgb(config['bg_color'])
    accent_color = hex_to_rgb(config['accent_color'])
    
    # Create image
    img = Image.new('RGB', (width, height), bg_color)
    draw = ImageDraw.Draw(img)
    
    # Add accent bar at top
    draw.rectangle([0, 0, width, 6], fill=accent_color)
    
    # Add border
    draw.rectangle([0, 0, width-1, height-1], outline=accent_color, width=2)
    
    # Add title text
    title = config['title']
    subtitle = config.get('subtitle', '')
    
    # Use default font (Pillow's built-in)
    try:
        title_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 28)
        subtitle_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 16)
    except OSError:
        # Fallback to default font
        title_font = ImageFont.load_default()
        subtitle_font = ImageFont.load_default()
    
    # Calculate text positions (centered)
    title_bbox = draw.textbbox((0, 0), title, font=title_font)
    title_width = title_bbox[2] - title_bbox[0]
    title_x = (width - title_width) // 2
    title_y = height // 2 - 30
    
    # Draw title
    draw.text((title_x, title_y), title, fill=(248, 246, 243), font=title_font)
    
    # Draw subtitle
    if subtitle:
        sub_bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
        sub_width = sub_bbox[2] - sub_bbox[0]
        sub_x = (width - sub_width) // 2
        sub_y = title_y + 40
        draw.text((sub_x, sub_y), subtitle, fill=(154, 168, 163), font=subtitle_font)
    
    # Convert to bytes
    buffer = BytesIO()
    img.save(buffer, format='PNG')
    buffer.seek(0)
    return buffer.getvalue()


def main():
    # Get credentials from environment
    supabase_url = os.environ.get('SUPABASE_URL')
    service_key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY')
    
    if not supabase_url or not service_key:
        print("ERROR: Missing environment variables")
        print("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY")
        sys.exit(1)
    
    print(f"Connecting to Supabase: {supabase_url}")
    client = create_client(supabase_url, service_key)
    
    # Step 1: Create and upload sample images
    print("\n--- Uploading sample ad images ---")
    uploaded_paths = []
    
    for ad in SAMPLE_ADS:
        filename = ad['filename']
        storage_path = f"sample/{filename}"
        
        print(f"Creating {filename}...")
        image_data = create_sample_ad(ad)
        
        print(f"Uploading to {storage_path}...")
        try:
            # Delete existing file if present (upsert)
            try:
                client.storage.from_('ad_share').remove([storage_path])
            except Exception:
                pass
            
            result = client.storage.from_('ad_share').upload(
                storage_path,
                image_data,
                file_options={'content-type': 'image/png', 'upsert': 'true'}
            )
            print(f"  Uploaded: {storage_path}")
            uploaded_paths.append(storage_path)
        except Exception as e:
            print(f"  ERROR uploading {filename}: {e}")
    
    if not uploaded_paths:
        print("ERROR: No images uploaded. Check bucket permissions.")
        sys.exit(1)
    
    print(f"\nUploaded {len(uploaded_paths)} sample images")
    
    # Step 2: Seed ad_slots table
    print("\n--- Seeding ad_slots table ---")
    
    # First, clear existing sample ads
    print("Removing existing sample ad slots...")
    try:
        client.table('ad_slots').delete().like('storage_path', 'sample/%').execute()
    except Exception as e:
        print(f"  Warning: {e}")
    
    # Insert new ad slots
    slots_to_insert = []
    image_index = 0
    
    for page in PAGES:
        for position in POSITIONS:
            # Cycle through sample images
            storage_path = uploaded_paths[image_index % len(uploaded_paths)]
            image_index += 1
            
            slots_to_insert.append({
                'page': page,
                'position': position,
                'storage_path': storage_path,
                'enabled': True,
                'priority': 100,
                'label': f'Sample ad for {page}:{position}',
                'click_url': 'https://example.com',
            })
    
    print(f"Inserting {len(slots_to_insert)} ad slots...")
    
    try:
        result = client.table('ad_slots').insert(slots_to_insert).execute()
        print(f"  Inserted {len(result.data)} slots")
    except Exception as e:
        print(f"  ERROR inserting slots: {e}")
        sys.exit(1)
    
    # Summary
    print("\n" + "=" * 50)
    print("AD SEEDING COMPLETE")
    print("=" * 50)
    print(f"Images uploaded: {len(uploaded_paths)}")
    print(f"Ad slots created: {len(slots_to_insert)}")
    print("\nSlots created:")
    for page in PAGES:
        print(f"  - {page}: left, right")
    print("\nTo verify, run the app and enable 'Show Ad Slot Overlay' in Settings > Developer")


if __name__ == '__main__':
    main()
