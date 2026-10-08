import { beforeAll, describe, expect, it } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  getDemoCredentials,
  getServiceRoleClient,
  getVenueIds,
  signInAs,
} from "./helpers";

describe("dashboard_stats RPC", () => {
  let ownerClient: SupabaseClient;
  let staffVenueId: string;

  beforeAll(async () => {
    const creds = getDemoCredentials();
    const owner = await signInAs(creds.ownerEmail, creds.ownerPassword);
    ownerClient = owner.client;

    const serviceClient = getServiceRoleClient();
    const { data: staffUser, error: userError } = await serviceClient
      .from("memberships")
      .select("user_id")
      .eq("role", "staff")
      .limit(1)
      .single();

    if (userError) {
      throw userError;
    }

    const venueIds = await getVenueIds(staffUser.user_id);
    staffVenueId = venueIds.staffVenueId;
  });

  it("totals match raw count(*) for the same venue filter", async () => {
    const now = new Date();
    const from = new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000);
    const to = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000);

    const { data: stats, error: rpcError } = await ownerClient.rpc(
      "dashboard_stats",
      {
        p_from: from.toISOString(),
        p_to: to.toISOString(),
        p_venue_id: staffVenueId,
        p_status: null,
      },
    );

    expect(rpcError).toBeNull();
    expect(stats).not.toBeNull();

    const serviceClient = getServiceRoleClient();

    const countByStatus = async (status: string) => {
      const { count, error } = await serviceClient
        .from("guests")
        .select("*", { count: "exact", head: true })
        .eq("venue_id", staffVenueId)
        .eq("status", status);

      if (error) {
        throw error;
      }

      return count ?? 0;
    };

    const checkedIn = await countByStatus("checked_in");
    const pending = await countByStatus("pending");
    const noShow = await countByStatus("no_show");

    expect(stats.total_checked_in).toBe(checkedIn);
    expect(stats.total_pending).toBe(pending);
    expect(stats.total_no_show).toBe(noShow);
    expect(stats.filtered_count).toBe(checkedIn + pending + noShow);
  });

  it("respects status filter in filtered_count", async () => {
    const now = new Date();
    const from = new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000);
    const to = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000);

    const { data: stats, error: rpcError } = await ownerClient.rpc(
      "dashboard_stats",
      {
        p_from: from.toISOString(),
        p_to: to.toISOString(),
        p_venue_id: staffVenueId,
        p_status: "pending",
      },
    );

    expect(rpcError).toBeNull();
    expect(stats).not.toBeNull();

    const { count, error } = await getServiceRoleClient()
      .from("guests")
      .select("*", { count: "exact", head: true })
      .eq("venue_id", staffVenueId)
      .eq("status", "pending");

    if (error) {
      throw error;
    }

    expect(stats.filtered_count).toBe(count ?? 0);
    expect(stats.total_pending).toBe(count ?? 0);
  });
});
