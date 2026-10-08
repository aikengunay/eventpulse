import { createClient, type SupabaseClient } from "@supabase/supabase-js";

let anonClient: SupabaseClient | null = null;
let serviceRoleClient: SupabaseClient | null = null;

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

export function getAnonClient(): SupabaseClient {
  if (!anonClient) {
    anonClient = createClient(
      requireEnv("NEXT_PUBLIC_SUPABASE_URL"),
      requireEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY"),
    );
  }
  return anonClient;
}

export function getServiceRoleClient(): SupabaseClient {
  if (!serviceRoleClient) {
    serviceRoleClient = createClient(
      requireEnv("NEXT_PUBLIC_SUPABASE_URL"),
      requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
      {
        auth: { persistSession: false, autoRefreshToken: false },
      },
    );
  }
  return serviceRoleClient;
}

export async function signInAs(
  email: string,
  password: string,
): Promise<{ client: SupabaseClient; accessToken: string }> {
  const url = requireEnv("NEXT_PUBLIC_SUPABASE_URL");
  const anonKey = requireEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY");

  const authClient = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await authClient.auth.signInWithPassword({
    email,
    password,
  });

  if (error) {
    throw error;
  }
  if (!data.session) {
    throw new Error("No session returned after sign in");
  }

  const accessToken = data.session.access_token;

  const client = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    },
  });

  return { client, accessToken };
}

export async function getVenueIds(staffUserId: string): Promise<{
  allVenueIds: string[];
  staffVenueId: string;
  otherVenueId: string;
}> {
  const serviceClient = getServiceRoleClient();

  const { data: venues, error: venuesError } = await serviceClient
    .from("venues")
    .select("id")
    .order("id");

  if (venuesError) {
    throw venuesError;
  }
  if (!venues || venues.length < 3) {
    throw new Error("Expected at least 3 seeded venues");
  }

  const { data: membership, error: membershipError } = await serviceClient
    .from("memberships")
    .select("venue_id")
    .eq("user_id", staffUserId)
    .eq("role", "staff")
    .single();

  if (membershipError) {
    throw membershipError;
  }
  if (!membership?.venue_id) {
    throw new Error("Staff membership has no venue_id");
  }

  const staffVenueId = membership.venue_id;
  const otherVenueId = venues.find((venue) => venue.id !== staffVenueId)?.id;

  if (!otherVenueId) {
    throw new Error("Could not find a venue outside staff assignment");
  }

  return {
    allVenueIds: venues.map((venue) => venue.id),
    staffVenueId,
    otherVenueId,
  };
}

export function getDemoCredentials(): {
  ownerEmail: string;
  ownerPassword: string;
  staffEmail: string;
  staffPassword: string;
} {
  return {
    ownerEmail: requireEnv("DEMO_OWNER_EMAIL"),
    ownerPassword: requireEnv("DEMO_OWNER_PASSWORD"),
    staffEmail: requireEnv("DEMO_STAFF_EMAIL"),
    staffPassword: requireEnv("DEMO_STAFF_PASSWORD"),
  };
}
