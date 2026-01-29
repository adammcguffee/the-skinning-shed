# Link Previews (Open Graph)

When someone shares a link to The Skinning Shed via iMessage, Facebook, Twitter, LinkedIn, or Slack, a preview image and description appear. This is controlled by Open Graph (OG) meta tags.

## How It Works

1. **Meta tags** in `app/web/index.html` tell social platforms what to display
2. **OG image** at `/og-image.png` is the preview image shown
3. Flutter's build process copies `web/*` files to the output root

## File Locations

| File | Source | Built Output |
|------|--------|--------------|
| Meta tags | `app/web/index.html` | `build/web/index.html` |
| OG image | `app/web/og-image.png` | `build/web/og-image.png` → `https://www.theskinningshed.com/og-image.png` |

## OG Image Requirements

- **Size**: 1200×630 pixels (recommended for all platforms)
- **Format**: PNG or JPG
- **File size**: Under 1MB recommended
- **Content**: No text cutoff at edges (some platforms crop)

## Current Meta Tags

```html
<!-- Open Graph / Facebook / iMessage -->
<meta property="og:title" content="The Skinning Shed">
<meta property="og:description" content="Showcase hunting & fishing trophies...">
<meta property="og:image" content="https://www.theskinningshed.com/og-image.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">

<!-- Twitter Card -->
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:image" content="https://www.theskinningshed.com/og-image.png">
```

## Testing Link Previews

### Online Validators
- **Facebook**: https://developers.facebook.com/tools/debug/
- **Twitter**: https://cards-dev.twitter.com/validator
- **LinkedIn**: https://www.linkedin.com/post-inspector/

### Local Verification
```bash
./scripts/verify_link_preview.sh app/build/web
```

## Troubleshooting

### Preview not updating?
Social platforms cache previews aggressively. To force a refresh:

1. **Facebook**: Use the Sharing Debugger and click "Scrape Again"
2. **Twitter**: Twitter caches for ~7 days; wait or use a different URL
3. **iMessage**: Add a query param to bust cache: `https://www.theskinningshed.com/?v=2`
4. **Slack**: Slack re-fetches on each paste (usually works immediately)

### Image not showing?
1. Verify image URL is accessible: `curl -I https://www.theskinningshed.com/og-image.png`
2. Check image isn't behind auth (must be public)
3. Ensure no redirects (use final URL)
4. Check image size is reasonable (under 5MB)

## Updating the OG Image

1. Create a new 1200×630 image
2. Save as `app/web/og-image.png`
3. Build and deploy
4. Clear caches using the validators above

## Future Improvements

- Per-page dynamic OG tags (e.g., individual trophy posts with custom images)
- Automated OG image generation for shared content
- A/B testing different preview images

---

*Last updated: January 2026*
