// Exchanges a Plaid Link `public_token` for a permanent `access_token`,
// fetches the linked accounts from Plaid, and writes them into
// public.accounts. The access_token itself is stored in public.plaid_items
// (service-role only, see migration 0002) — it never reaches the Flutter
// client, per the "Plaid secret key ... server-side only" requirement.

import { createClient } from "npm:@supabase/supabase-js@2";

const PLAID_ENV = Deno.env.get("PLAID_ENV") ?? "sandbox";
const PLAID_BASE_URL = `https://${PLAID_ENV}.plaid.com`;

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Content-Type": "application/json",
  };
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

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Verifying the JWT here (rather than just decoding it, as the link-token
  // function does) because this function performs writes.
  const authHeader = req.headers.get("Authorization");
  const { data: userData, error: userError } = await supabase.auth.getUser(
    authHeader?.replace("Bearer ", ""),
  );
  if (userError || !userData.user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: corsHeaders(),
    });
  }
  const userId = userData.user.id;

  const { public_token: publicToken, institution_name: institutionName } = await req.json();
  if (!publicToken) {
    return new Response(JSON.stringify({ error: "public_token is required" }), {
      status: 400,
      headers: corsHeaders(),
    });
  }

  const exchangeRes = await fetch(`${PLAID_BASE_URL}/item/public_token/exchange`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      client_id: Deno.env.get("PLAID_CLIENT_ID"),
      secret: Deno.env.get("PLAID_SECRET"),
      public_token: publicToken,
    }),
  });
  const exchangeData = await exchangeRes.json();
  if (!exchangeRes.ok) {
    return new Response(JSON.stringify(exchangeData), {
      status: exchangeRes.status,
      headers: corsHeaders(),
    });
  }
  const { access_token: accessToken, item_id: itemId } = exchangeData;

  await supabase.from("plaid_items").upsert(
    {
      user_id: userId,
      item_id: itemId,
      access_token: accessToken,
      institution_name: institutionName ?? "Linked institution",
    },
    { onConflict: "item_id" },
  );

  const accountsRes = await fetch(`${PLAID_BASE_URL}/accounts/get`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      client_id: Deno.env.get("PLAID_CLIENT_ID"),
      secret: Deno.env.get("PLAID_SECRET"),
      access_token: accessToken,
    }),
  });
  const accountsData = await accountsRes.json();
  if (!accountsRes.ok) {
    return new Response(JSON.stringify(accountsData), {
      status: accountsRes.status,
      headers: corsHeaders(),
    });
  }

  const rows = (accountsData.accounts ?? []).map((account: {
    account_id: string;
    name: string;
    type: string;
    balances: { current: number | null };
  }) => ({
    user_id: userId,
    plaid_account_id: account.account_id,
    institution_name: institutionName ?? "Linked institution",
    account_name: account.name,
    type: account.type,
    current_balance: account.balances.current ?? 0,
    last_synced_at: new Date().toISOString(),
  }));

  if (rows.length > 0) {
    await supabase.from("accounts").upsert(rows, { onConflict: "plaid_account_id" });
  }

  return new Response(JSON.stringify({ linked_accounts: rows.length }), {
    status: 200,
    headers: corsHeaders(),
  });
});
