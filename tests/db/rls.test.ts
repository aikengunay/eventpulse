import { beforeAll, describe, expect, it } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  getDemoCredentials,
  getServiceRoleClient,
  getVenueIds,
  signInAs,
} from "./helpers";

describe("RLS isolation", () => {
  let staffClient: SupabaseClient;
  let ownerClient: SupabaseClient;
  let staffVenueId: string;
  let otherVenueId: string;
  let allVenueIds: string[];

  beforeAll(async () => {
    const creds = getDemoCredentials();
    const staff = await signInAs(creds.staffEmail, creds.staffPassword);
    const owner = await signInAs(creds.ownerEmail, creds.ownerPassword);

    staffClient = staff.client;
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
    otherVenueId = venueIds.otherVenueId;
    allVenueIds = venueIds.allVenueIds;
  });

  it("staff cannot select guests from another venue", async () => {
    const { data, error } = await staffClient
      .from("guests")
      .select("id")
      .eq("venue_id", otherVenueId);

    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("staff cannot insert events", async () => {
    const { data, error } = await staffClient.from("events").insert({
      org_id: crypto.randomUUID(),
      venue_id: staffVenueId,
      name: "Should fail",
      starts_at: new Date().toISOString(),
      ends_at: new Date(Date.now() + 3_600_000).toISOString(),
      status: "draft",
    });

    expect(error).not.toBeNull();
    expect(error?.code).toBe("42501");
    expect(data).toBeNull();
  });

  it("owner sees all three venues", async () => {
    const { data, error } = await ownerClient.from("venues").select("id");

    expect(error).toBeNull();
    expect(data).toHaveLength(3);
    expect(data?.map((venue) => venue.id).sort()).toEqual(
      allVenueIds.slice(0, 3).sort(),
    );
  });
});
