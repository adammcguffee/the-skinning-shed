import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { requireAdmin } from "../_shared/admin_auth.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const auth = await requireAdmin(req);
  if (!auth.ok) {
    return new Response(JSON.stringify(auth), {
      status: auth.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({
    ok: true,
    status: 200,
    user_id: auth.user?.id,
    auth_debug: auth.auth_debug,
  }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
