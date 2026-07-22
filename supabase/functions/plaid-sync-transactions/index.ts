// Syncs new/changed transactions for every Plaid item the calling user has
// linked, auto-tags food-delivery merchants (same brand list as
// lib/services/merchant_matcher.dart), upserts them, then recomputes
// daily_summaries for any month touched — the same derived-cache logic as
// SupabaseService.recomputeMonthSummaries, reimplemented here since Edge
// Functions run on Deno and can't import the Dart service.

import { createClient } from "npm:@supabase/supabase-js@2";

const PLAID_ENV = Deno.env.get("PLAID_ENV") ?? "sandbox";
const PLAID_BASE_URL = `https://${PLAID_ENV}.plaid.com`;

const BRAND_KEYWORDS: Record<string, string[]> = {
  doordash: ["DOORDASH", "DOOR DASH"],
  ubereats: ["UBER EATS", "UBEREATS", "UBER *EATS"],
  grubhub: ["GRUBHUB", "GRUB HUB", "SEAMLESS"],
  other: ["POSTMATES", "INSTACART", "GOPUFF"],
};

function matchPlatform(merchantName: string): { platform: string | null; isFoodDelivery: boolean } {
  const normalized = merchantName.toUpperCase();
  for (const [platform, keywords] of Object.entries(BRAND_KEYWORDS)) {
    if (keywords.some((k) => normalized.includes(k))) {
      return { platform, isFoodDelivery: true };
    }
  }
  return { platform: null, isFoodDelivery: false };
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Content-Type": "application/json",
  };
}

function daysInMonth(year: number, month: number): number {
  return new Date(year, month, 0).getDate();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders() });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

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

  const { data: items, error: itemsError } = await supabase
    .from("plaid_items")
    .select("id, access_token, sync_cursor")
    .eq("user_id", userId);
  if (itemsError) {
    return new Response(JSON.stringify({ error: itemsError.message }), {
      status: 500,
      headers: corsHeaders(),
    });
  }

  const { data: accountRows } = await supabase
    .from("accounts")
    .select("id, plaid_account_id")
    .eq("user_id", userId);
  const accountIdByPlaidId = new Map(
    (accountRows ?? []).map((a: { id: string; plaid_account_id: string | null }) => [
      a.plaid_account_id,
      a.id,
    ]),
  );

  const touchedMonths = new Set<string>(); // "YYYY-MM"
  let totalSynced = 0;

  for (const item of items ?? []) {
    let cursor: string | null | undefined = item.sync_cursor;
    let hasMore = true;

    while (hasMore) {
      const syncRes = await fetch(`${PLAID_BASE_URL}/transactions/sync`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          client_id: Deno.env.get("PLAID_CLIENT_ID"),
          secret: Deno.env.get("PLAID_SECRET"),
          access_token: item.access_token,
          cursor: cursor ?? undefined,
        }),
      });
      const syncData = await syncRes.json();
      if (!syncRes.ok) break;

      const added = [...(syncData.added ?? []), ...(syncData.modified ?? [])];
      const rows = added.map((t: {
        transaction_id: string;
        account_id: string;
        merchant_name: string | null;
        name: string;
        amount: number;
        date: string;
      }) => {
        const merchantName = t.merchant_name ?? t.name;
        const { platform, isFoodDelivery } = matchPlatform(merchantName);
        const [year, month] = t.date.split("-");
        touchedMonths.add(`${year}-${month}`);
        return {
          user_id: userId,
          account_id: accountIdByPlaidId.get(t.account_id) ?? null,
          merchant_name: merchantName,
          amount: t.amount,
          date: t.date,
          platform,
          is_food_delivery: isFoodDelivery,
          source: "plaid",
          plaid_transaction_id: t.transaction_id,
        };
      });

      if (rows.length > 0) {
        await supabase.from("transactions").upsert(rows, { onConflict: "plaid_transaction_id" });
        totalSynced += rows.length;
      }

      cursor = syncData.next_cursor;
      hasMore = syncData.has_more ?? false;
    }

    await supabase.from("plaid_items").update({ sync_cursor: cursor }).eq("id", item.id);
  }

  // Recompute daily_summaries for every month a synced transaction landed in.
  const { data: budgetRow } = await supabase
    .from("budgets")
    .select("monthly_budget_amount")
    .eq("user_id", userId)
    .maybeSingle();
  const monthlyBudget = budgetRow?.monthly_budget_amount ?? 0;

  for (const monthKey of touchedMonths) {
    const [year, month] = monthKey.split("-").map(Number);
    const dim = daysInMonth(year, month);
    const dailyAllocation = monthlyBudget / dim;
    const monthStart = `${monthKey}-01`;
    const monthEnd = `${monthKey}-${String(dim).padStart(2, "0")}`;

    const { data: txns } = await supabase
      .from("transactions")
      .select("date, amount")
      .eq("user_id", userId)
      .eq("is_food_delivery", true)
      .gte("date", monthStart)
      .lte("date", monthEnd);

    const spentByDay = new Map<number, number>();
    for (const t of txns ?? []) {
      const day = Number(t.date.split("-")[2]);
      spentByDay.set(day, (spentByDay.get(day) ?? 0) + Number(t.amount));
    }

    const summaryRows = [];
    for (let day = 1; day <= dim; day++) {
      const spent = spentByDay.get(day) ?? 0;
      summaryRows.push({
        user_id: userId,
        date: `${monthKey}-${String(day).padStart(2, "0")}`,
        amount_spent: spent,
        amount_saved: dailyAllocation - spent,
      });
    }
    await supabase.from("daily_summaries").upsert(summaryRows, { onConflict: "user_id,date" });
  }

  return new Response(JSON.stringify({ synced: totalSynced, months_recomputed: [...touchedMonths] }), {
    status: 200,
    headers: corsHeaders(),
  });
});
