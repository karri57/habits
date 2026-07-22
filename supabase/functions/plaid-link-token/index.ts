// Creates a Plaid Link token for the calling user. The Flutter client calls
// this (with its Supabase session JWT) to get a token it can hand to the
// plaid_flutter SDK to open Plaid Link on-device. PLAID_CLIENT_ID/PLAID_SECRET
// are Edge Function secrets — see SETUP.md — and never reach the client.

const PLAID_ENV = Deno.env.get("PLAID_ENV") ?? "sandbox";
const PLAID_BASE_URL = `https://${PLAID_ENV}.plaid.com`;

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Content-Type": "application/json",
  };
}

function userIdFromAuthHeader(authHeader: string | null): string | null {
  if (!authHeader) return null;
  const token = authHeader.replace("Bearer ", "");
  const payloadSegment = token.split(".")[1];
  if (!payloadSegment) return null;
  try {
    const payload = JSON.parse(atob(payloadSegment));
    return payload.sub ?? null;
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders() });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: corsHeaders(),
    });
  }

  // Supabase's edge gateway already verified this JWT against the project's
  // anon key before invoking the function, so decoding (without
  // re-verifying) is enough to recover the user id here.
  const userId = userIdFromAuthHeader(req.headers.get("Authorization"));
  if (!userId) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: corsHeaders(),
    });
  }

  const plaidRes = await fetch(`${PLAID_BASE_URL}/link/token/create`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      client_id: Deno.env.get("PLAID_CLIENT_ID"),
      secret: Deno.env.get("PLAID_SECRET"),
      client_name: "Delivery Habits",
      language: "en",
      country_codes: ["US"],
      user: { client_user_id: userId },
      products: ["transactions"],
    }),
  });

  const data = await plaidRes.json();
  return new Response(JSON.stringify(data), {
    status: plaidRes.status,
    headers: corsHeaders(),
  });
});
