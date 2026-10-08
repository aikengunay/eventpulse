import { beforeAll, describe, expect, it } from "vitest";
import {
  getDemoCredentials,
  getServiceRoleClient,
  getVenueIds,
  signInAs,
} from "./helpers";

describe("hostile PostgREST access with staff JWT", () => {
  let staffJwt: string;
  let staffVenueId: string;
  let otherVenueId: string;
  let orgId: string;

  beforeAll(async () => {
    const creds = getDemoCredentials();
    const staff = await signInAs(creds.staffEmail, creds.staffPassword);
    staffJwt = staff.accessToken;

    const serviceClient = getServiceRoleClient();
    const { data: staffUser, error: userError } = await serviceClient
      .from("memberships")
      .select("user_id, org_id")
      .eq("role", "staff")
      .limit(1)
      .single();

    if (userError) {
      throw userError;
    }

    orgId = staffUser.org_id;
    const venueIds = await getVenueIds(staffUser.user_id);
    staffVenueId = venueIds.staffVenueId;
    otherVenueId = venueIds.otherVenueId;
  });

  it("GET guests filtered to another venue returns 0 rows", async () => {
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
    const url = `${supabaseUrl}/rest/v1/guests?venue_id=eq.${otherVenueId}&select=id`;

    const response = await fetch(url, {
      headers: {
        Authorization: `Bearer ${staffJwt}`,
        apikey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      },
    });

    expect(response.status).toBe(200);

    const data = await response.json();
    expect(Array.isArray(data)).toBe(true);
    expect(data).toHaveLength(0);
  });

  it("POST events as staff is denied with 42501", async () => {
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
    const url = `${supabaseUrl}/rest/v1/events`;

    const response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${staffJwt}`,
        apikey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: JSON.stringify({
        org_id: orgId,
        venue_id: staffVenueId,
        name: "Should fail via REST",
        starts_at: new Date().toISOString(),
        ends_at: new Date(Date.now() + 3_600_000).toISOString(),
        status: "draft",
      }),
    });

    expect(response.ok).toBe(false);

    const body = await response.json();
    const errorCode = Array.isArray(body) ? body[0]?.code : body.code;
    expect(errorCode).toBe("42501");
  });
});
