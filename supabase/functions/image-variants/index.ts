import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * image-variants Edge Function
 * 
 * Generates thumbnail and medium variants of uploaded images.
 * Safe and non-blocking - failures don't affect the original upload.
 * 
 * Input:
 *   { bucket, path, recordType?, recordId? }
 * 
 * Output:
 *   { success: true, thumbPath, mediumPath } or { success: false, error }
 */

const THUMB_MAX_DIM = 400;
const MEDIUM_MAX_DIM = 1200;
const JPEG_QUALITY = 85;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface RequestBody {
  bucket: string;
  path: string;
  recordType?: 'club_photos' | 'trophy_posts' | 'trophy_photos' | 'club_openings' | 'swap_shop_photos' | 'land_photos';
  recordId?: string;
  arrayIndex?: number; // For club_openings photo_paths array
}

interface VariantResult {
  success: boolean;
  thumbPath?: string;
  mediumPath?: string;
  error?: string;
}

/**
 * Simple image resizing using Canvas API (available in Deno Deploy)
 * Falls back gracefully if not available
 */
async function resizeImage(
  imageData: ArrayBuffer,
  maxDim: number,
  quality: number = JPEG_QUALITY
): Promise<Uint8Array | null> {
  try {
    // Try using OffscreenCanvas (available in Deno Deploy)
    const blob = new Blob([imageData]);
    const imageBitmap = await createImageBitmap(blob);
    
    const { width, height } = imageBitmap;
    
    // Calculate new dimensions maintaining aspect ratio
    let newWidth = width;
    let newHeight = height;
    
    if (width > maxDim || height > maxDim) {
      if (width > height) {
        newWidth = maxDim;
        newHeight = Math.round((height / width) * maxDim);
      } else {
        newHeight = maxDim;
        newWidth = Math.round((width / height) * maxDim);
      }
    } else {
      // Image already smaller than target, skip resizing
      return null;
    }
    
    // Create canvas and draw resized image
    const canvas = new OffscreenCanvas(newWidth, newHeight);
    const ctx = canvas.getContext('2d');
    if (!ctx) {
      console.error('[image-variants] Failed to get canvas context');
      return null;
    }
    
    ctx.drawImage(imageBitmap, 0, 0, newWidth, newHeight);
    
    // Convert to JPEG blob
    const resizedBlob = await canvas.convertToBlob({
      type: 'image/jpeg',
      quality: quality / 100,
    });
    
    // Convert blob to Uint8Array
    const arrayBuffer = await resizedBlob.arrayBuffer();
    return new Uint8Array(arrayBuffer);
  } catch (error) {
    console.error('[image-variants] Resize error:', error);
    return null;
  }
}

/**
 * Generate variant path from original path
 */
function getVariantPath(originalPath: string, variant: 'thumb' | 'medium'): string {
  const lastSlash = originalPath.lastIndexOf('/');
  const dir = originalPath.substring(0, lastSlash);
  const filename = originalPath.substring(lastSlash + 1);
  
  // Replace extension with .jpg since we're outputting JPEG
  const nameWithoutExt = filename.replace(/\.[^.]+$/, '');
  return `${dir}/${variant}_${nameWithoutExt}.jpg`;
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const startTime = Date.now();
  console.log('[image-variants] Starting...');

  try {
    const body: RequestBody = await req.json();
    const { bucket, path, recordType, recordId, arrayIndex } = body;

    if (!bucket || !path) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing bucket or path' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`[image-variants] Processing: ${bucket}/${path}`);

    // Initialize Supabase client with service role
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Download original image
    const { data: originalData, error: downloadError } = await supabase.storage
      .from(bucket)
      .download(path);

    if (downloadError || !originalData) {
      console.error('[image-variants] Download error:', downloadError);
      return new Response(
        JSON.stringify({ success: false, error: `Download failed: ${downloadError?.message}` }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const originalBuffer = await originalData.arrayBuffer();
    console.log(`[image-variants] Downloaded ${originalBuffer.byteLength} bytes`);

    // Generate variants
    const thumbPath = getVariantPath(path, 'thumb');
    const mediumPath = getVariantPath(path, 'medium');

    const [thumbData, mediumData] = await Promise.all([
      resizeImage(originalBuffer, THUMB_MAX_DIM),
      resizeImage(originalBuffer, MEDIUM_MAX_DIM),
    ]);

    let thumbUploaded = false;
    let mediumUploaded = false;

    // Upload thumb if generated
    if (thumbData) {
      const { error: thumbError } = await supabase.storage
        .from(bucket)
        .upload(thumbPath, thumbData, {
          contentType: 'image/jpeg',
          upsert: true,
        });

      if (thumbError) {
        console.error('[image-variants] Thumb upload error:', thumbError);
      } else {
        thumbUploaded = true;
        console.log(`[image-variants] Thumb uploaded: ${thumbPath}`);
      }
    }

    // Upload medium if generated
    if (mediumData) {
      const { error: mediumError } = await supabase.storage
        .from(bucket)
        .upload(mediumPath, mediumData, {
          contentType: 'image/jpeg',
          upsert: true,
        });

      if (mediumError) {
        console.error('[image-variants] Medium upload error:', mediumError);
      } else {
        mediumUploaded = true;
        console.log(`[image-variants] Medium uploaded: ${mediumPath}`);
      }
    }

    // Update database record if recordType and recordId provided
    if (recordType && recordId && (thumbUploaded || mediumUploaded)) {
      try {
        if (recordType === 'club_openings' && arrayIndex !== undefined) {
          // Handle array columns for club_openings
          // First fetch current arrays
          const { data: current } = await supabase
            .from(recordType)
            .select('thumb_paths, medium_paths')
            .eq('id', recordId)
            .single();

          const thumbPaths = current?.thumb_paths || [];
          const mediumPaths = current?.medium_paths || [];

          // Ensure arrays are long enough
          while (thumbPaths.length <= arrayIndex) thumbPaths.push(null);
          while (mediumPaths.length <= arrayIndex) mediumPaths.push(null);

          if (thumbUploaded) thumbPaths[arrayIndex] = thumbPath;
          if (mediumUploaded) mediumPaths[arrayIndex] = mediumPath;

          await supabase
            .from(recordType)
            .update({ thumb_paths: thumbPaths, medium_paths: mediumPaths })
            .eq('id', recordId);
        } else if (recordType === 'trophy_posts') {
          // Handle cover photo columns
          const updateData: Record<string, string> = {};
          if (thumbUploaded) updateData.cover_thumb_path = thumbPath;
          if (mediumUploaded) updateData.cover_medium_path = mediumPath;

          await supabase
            .from(recordType)
            .update(updateData)
            .eq('id', recordId);
        } else {
          // Standard single-path tables
          const updateData: Record<string, string> = {};
          if (thumbUploaded) updateData.thumb_path = thumbPath;
          if (mediumUploaded) updateData.medium_path = mediumPath;

          await supabase
            .from(recordType)
            .update(updateData)
            .eq('id', recordId);
        }

        console.log(`[image-variants] Updated ${recordType} record ${recordId}`);
      } catch (dbError) {
        console.error('[image-variants] DB update error:', dbError);
        // Don't fail the request - variants are still generated
      }
    }

    const elapsed = Date.now() - startTime;
    console.log(`[image-variants] Complete in ${elapsed}ms`);

    const result: VariantResult = {
      success: true,
      thumbPath: thumbUploaded ? thumbPath : undefined,
      mediumPath: mediumUploaded ? mediumPath : undefined,
    };

    return new Response(
      JSON.stringify(result),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('[image-variants] Error:', error);
    return new Response(
      JSON.stringify({ success: false, error: String(error) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
