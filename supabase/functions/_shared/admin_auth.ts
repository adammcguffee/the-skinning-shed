import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type AdminAuthResult = {
  ok: boolean;
  status: number;
  error?: string;
  details?: string;
  user?: { id: string; email?: string | null };
  admin?: ReturnType<typeof createClient>;
  auth_debug?: {
    header_present: boolean;
    token_length: number;
  };
};

export async function requireAdmin(req: Request): Promise<AdminAuthResult> {
  const authHeader = req.headers.get("authorization") ?? req.headers.get("Authorization") ?? "";
  const jwt = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  const authDebug = {
    header_present: authHeader.length > 0,
    token_length: jwt.length,
  };

  if (!jwt) {
    return {
      ok: false,
      status: 401,
      error: "Missing Authorization Bearer token",
      auth_debug: authDebug,
    };
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  const { data: { user }, error } = await admin.auth.getUser(jwt);
  if (error || !user) {
    return {
      ok: false,
      status: 401,
      error: "Invalid JWT",
      details: String(error?.message ?? ""),
      auth_debug: authDebug,
    };
  }

  const { data: profile, error: profileError } = await admin
    .from("profiles")
    .select("is_admin")
    .eq("id", user.id)
    .maybeSingle();

  if (profileError) {
    return {
      ok: false,
      status: 500,
      error: "Profile lookup failed",
      details: String(profileError.message ?? ""),
      auth_debug: authDebug,
    };
  }

  if (!profile?.is_admin) {
    return {
      ok: false,
      status: 403,
      error: "Not an admin",
      auth_debug: authDebug,
    };
  }

  return {
    ok: true,
    status: 200,
    user: { id: user.id, email: user.email },
    admin,
    auth_debug: authDebug,
  };
}
