import { execSync } from "node:child_process";
import { config } from "dotenv";

config({ path: ".env.local" });
config({ path: ".env" });

function loadSupabaseStatusEnv(): void {
  if (process.env.NEXT_PUBLIC_SUPABASE_URL) {
    return;
  }

  try {
    const output = execSync("supabase status -o env", {
      cwd: process.cwd(),
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    });

    for (const line of output.split("\n")) {
      const match = line.match(/^([A-Z0-9_]+)=(.*)$/);
      if (!match) {
        continue;
      }

      const key = match[1];
      const value = match[2].replace(/^"(.*)"$/, "$1");
      if (!process.env[key]) {
        process.env[key] = value;
      }
    }
  } catch {
    // Supabase CLI not running — tests will fail with a clear env error.
  }

  process.env.NEXT_PUBLIC_SUPABASE_URL ??= process.env.API_URL;
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??= process.env.ANON_KEY;
  process.env.SUPABASE_SERVICE_ROLE_KEY ??= process.env.SERVICE_ROLE_KEY;
}

loadSupabaseStatusEnv();

process.env.DEMO_OWNER_EMAIL ??= "owner@eventpulse.demo";
process.env.DEMO_STAFF_EMAIL ??= "staff@eventpulse.demo";
process.env.DEMO_OWNER_PASSWORD ??= "EventPulseDemo1!";
process.env.DEMO_STAFF_PASSWORD ??= "EventPulseDemo1!";
