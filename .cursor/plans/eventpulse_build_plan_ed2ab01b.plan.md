---
name: EventPulse build plan
overview: "Turn Project 1 in `portfolio-employer-demand.md` into a concrete public proof app: Next.js 16 + Supabase (Auth, Postgres, RLS) multi-venue event check-in and analytics admin with demo login, deployed on Vercel. Schema, RLS strategy, routes, phase checklist with verification, DeepSeek worker codegen, and First messages per implement chat. v1.1 adds magic link, Storage + signed URLs, activity trail after the live URL exists."
todos:
  - id: p0-scaffold
    content: "Phase 0: create eventpulse repo (Next 16, Tailwind, shadcn, Supabase CLI, lint/typecheck, AGENTS.md from project-stub), push to aikengunay/eventpulse, link Vercel"
    status: pending
  - id: gate-0
    content: "Gate 0: pnpm typecheck && pnpm lint green on empty app; supabase start works; repo public; Vercel preview URL loads"
    status: pending
  - id: p1a-tests-first
    content: "Phase 1a: write failing Vitest DB tests for RLS isolation (incl. hostile REST call with staff JWT) and dashboard_stats correctness"
    status: pending
  - id: p1b-schema
    content: "Phase 1b: migrations (tables, denormalization trigger, helper fns, RLS policies, dashboard_stats RPC, reset_demo) + seed; tests green"
    status: pending
  - id: gate-1
    content: "Gate 1: pnpm test green against local Supabase; seed loads; staff JWT REST call to other venue returns 0 rows (automated)"
    status: pending
  - id: p2-auth-shell
    content: "Phase 2: Supabase SSR auth, login page (password), demo-login server action, role-aware app shell"
    status: pending
  - id: gate-2
    content: "Gate 2: Try as owner / Try as staff both land on /app; sign out works; owner-only nav hidden for staff"
    status: pending
  - id: p3-events-checkin
    content: "Phase 3: events CRUD (owner), event detail guest list with check-in toggle; venues + staff read-only lists"
    status: pending
  - id: gate-3
    content: "Gate 3: owner creates event; staff checks in guest (optimistic); staff cannot open /app/venues; checked_in_by stored"
    status: pending
  - id: p4-dashboard-export
    content: "Phase 4: dashboard filters (URL state), summary cards, Recharts chart, table, CSV export with matching counts"
    status: pending
  - id: gate-4
    content: "Gate 4: card total = table rows = CSV rows for venue + last-7-days filter; empty + loading states render"
    status: pending
  - id: p5-ship
    content: "Phase 5: Supabase cloud + Vercel deploy, cron reset, README (schema, RLS, correctness note, ops section), Loom walkthrough"
    status: pending
  - id: gate-5
    content: "Gate 5: live Vercel URL loads without sign-up; demo buttons work after a cron reset; Lighthouse quick pass on / and /app"
    status: pending
  - id: post-ship-docs
    content: "After ship (applications workspace): update proof-inventory, portfolio-employer-demand links, candidate gaps, portfolio site, Upwork/OLJ profiles"
    status: pending
  - id: v11-magic-link
    content: "v1.1: magic-link (OTP email) login path on /login alongside password; demo buttons unchanged"
    status: pending
  - id: v11-storage
    content: "v1.1: event poster upload to Storage bucket with RLS on storage.objects; render via short-lived signed URL"
    status: pending
  - id: v11-activity
    content: "v1.1: activity list on event page from checked_in_by / checked_in_at (who, whom, when)"
    status: pending
  - id: gate-v11
    content: "Gate v1.1: magic link signs in a real account; staff cannot read another venue's poster via signed URL; activity list matches guest statuses"
    status: pending
isProject: false
---

# EventPulse build plan

Source spec: [freelance/applications/portfolio-employer-demand.md](/Users/aikengunay/Developer/Projects/freelance/applications/portfolio-employer-demand.md) (Project 1). Decisions locked: **Tailwind + shadcn/ui**, **event / venue** domain.

**Revised 2026-10-07** after re-checking live Upwork posts (Next.js + Supabase, payment verified, recency) and public Supabase-RLS portfolio repos. Changes: venues/staff pages read-only in MVP; hostile-access REST check becomes an automated test; README gains an ops section; **v1.1** section (magic link, Storage + signed URLs, activity trail) after the live URL ships; P2 default flipped to a trimmed client portal (see After shipping); **DeepSeek worker is the mandatory codegen path**; First messages per chat added.

## Repo and stack

- **Path:** `/Users/aikengunay/Developer/Projects/eventpulse` (new, separate from portfolio and from any `reiinnprojects` code)
- **GitHub:** `aikengunay/eventpulse`, public. Use `gh auth switch --user aikengunay` before `gh repo create`.
- **Identity file:** copy `~/Documents/cursor/how-to-use-cursor/project-stub/AGENTS.md` to the repo root in Phase 0 and fill run / verify / 5 stack facts. No model names in it.
- **Stack (match portfolio versions):** Next.js 16.2 App Router, React 19, TypeScript, Tailwind v4, shadcn/ui, `@supabase/ssr` + `supabase-js`, Recharts, Supabase CLI (local dev + migrations), Vitest for DB-level tests, pnpm, Vercel.
- **Data access:** server components + server actions using the user-session Supabase client so **RLS is the only authorization layer**. Service-role key used only in the seed/reset cron route.

## Schema

Check-ins live on `guests` (status + timestamp) instead of a separate `checkins` table. Fewer joins, no fan-out risk in MVP; a history table can come with Realtime later.

```mermaid
erDiagram
    orgs ||--o{ venues : has
    orgs ||--o{ memberships : has
    orgs ||--o{ events : has
    venues ||--o{ events : hosts
    venues o|--o{ memberships : "staff assigned to"
    events ||--o{ guests : invites
    auth_users ||--o{ memberships : "user_id"

    orgs { uuid id PK; text name; text plan "free|pro"; timestamptz created_at }
    venues { uuid id PK; uuid org_id FK; text name; text city; int capacity }
    memberships { uuid id PK; uuid user_id FK; uuid org_id FK; text role "owner|staff"; uuid venue_id FK "null for owner" }
    events { uuid id PK; uuid org_id FK; uuid venue_id FK; text name; timestamptz starts_at; timestamptz ends_at; text status "draft|published|done"; text poster_path "v1.1, nullable" }
    guests { uuid id PK; uuid event_id FK; text full_name; text email; text status "pending|checked_in|no_show"; timestamptz checked_in_at; uuid checked_in_by }
```

**Denormalize `org_id` and `venue_id` onto `guests`** (set by trigger from `events`) so RLS policies and the dashboard aggregate never need a 3-table join.

### RLS strategy

- Helper SQL functions (`security definer`, `stable`): `my_org_ids()`, `is_org_owner(org_id)`, `my_staff_venue_ids()`.
- Policies:
  - `orgs`, `venues`, `events`, `guests`: **select** if `org_id in my_org_ids()` and (owner or `venue_id in my_staff_venue_ids()`).
  - `events`, `venues`: **insert/update/delete** only `is_org_owner(org_id)`.
  - `guests`: **update** allowed for staff of that venue (check-in toggle) and owners; insert/delete owners only.
  - `memberships`: select own rows; owners can manage rows in their org.
- Dashboard aggregate = one RPC `dashboard_stats(from, to, venue_id, status)` returning summary counts + per-day series + filtered rows count. Implemented as `security invoker` SQL so RLS still applies. Totals are computed with `count(*) filter (...)` over `guests` directly, never after joining events. README documents this as the "no join fan-out" note.
- **Hostile-access test (automated, Phase 1a):** a Vitest case signs in as staff, calls PostgREST directly with that JWT for `guests?venue_id=eq.<other venue>` and asserts 0 rows. Same for `events` insert as staff (expects 42501). This replaces the manual click-path check.

## Demo login and data reset

- Seed creates two auth users: `owner@eventpulse.demo`, `staff@eventpulse.demo` (passwords in Supabase project env, exposed to server actions only).
- Landing page buttons "Try as owner" / "Try as staff" call a server action that runs `signInWithPassword` with those credentials and redirects to `/app`.
- Nightly reset: Vercel Cron hits `/api/cron/reset-demo` (checks `CRON_SECRET`), which runs SQL function `reset_demo()` with the service role: truncate org data, re-run seed.
- Seed shape: 1 org, 3 venues, 12 events spread over the last 60 days and next 14, ~300 guests with a realistic status mix.

## Routes

- `/` landing: what it is, the two demo buttons, link to repo and Loom
- `/login` email + password (real accounts optional). v1.1 adds "email me a link" (Supabase OTP).
- `/app` owner dashboard: date range, venue, status filters -> 3 summary cards, check-ins-per-day bar chart, guests table, "Export CSV"
- `/app/events` list (owner CRUD via dialog) and `/app/events/[id]` guest list with check-in toggle (staff + owner). v1.1 adds poster + activity list.
- `/app/venues`, `/app/staff` owner-only **read-only lists** in MVP (seeded data). Owner write path is already proven by events CRUD. Full CRUD only if a post asks.
- `/app/export` route handler streams CSV for the current filter set
- Staff landing after login: `/app/events?today=1` scoped to their venue by RLS; owner-only nav items hidden by role, enforced by RLS regardless

## Phases (evenings, about 2 h each)

**Phase 0 - Scaffold (1 evening)**
- `pnpm create next-app`, Tailwind, `shadcn init`, add button, card, table, dialog, select, calendar/date-range, badge, toast
- `supabase init`, `supabase start`, `.env.local` + `.env.example`
- ESLint + Prettier same as portfolio; `pnpm typecheck` script
- Copy `project-stub/AGENTS.md`, fill run / verify / stack facts
- `gh repo create aikengunay/eventpulse --public`, first push, link Vercel project

**Phase 1 - Schema, RLS, seed (2 evenings)**
- Write **failing Vitest DB tests first** (run against local Supabase with two seeded sessions): staff cannot select guests from another venue; staff cannot insert events; owner sees all three venues; `dashboard_stats` totals equal a raw `count(*)` for the same filter; **hostile REST call with staff JWT returns 0 rows**
- Migrations: enums, tables, `org_id`/`venue_id` denormalization trigger, helper functions, policies, `dashboard_stats`, `reset_demo`
- `supabase/seed.sql` (or TS seed via service role)
- Tests green

**Phase 2 - Auth and app shell (1 evening)**
- `@supabase/ssr` client helpers, middleware session refresh
- Login page (password), demo-login server action, sign out
- App layout: sidebar, role-aware nav, org/venue header

**Phase 3 - Events and check-in (2 evenings)**
- Events list + create/edit dialog (owner)
- Event detail: guest table, check-in / no-show toggle via server action, optimistic update, `checked_in_by` + `checked_in_at` written
- Venues and staff pages as read-only tables (owner)

**Phase 4 - Dashboard and export (2-3 evenings)**
- Filter bar (URL search params as state), summary cards, Recharts bar chart, paginated table
- `/app/export` CSV of the same filter, row count shown in UI equals CSV rows
- Empty and loading states

**Phase 5 - Ship (1-2 evenings)**
- Vercel env vars, Supabase cloud project, run migrations + seed, cron for reset
- README: one-paragraph pitch, schema diagram, RLS summary, "why totals are correct" note, demo credentials, local setup, **ops section** (local / staging / prod env separation, where backups live, how to rotate demo creds, how the RLS tests run)
- 60-90 s Loom: owner dashboard filters -> staff check-in -> RLS denial
- Lighthouse quick pass on `/` and `/app`

Total MVP: roughly 10-11 evenings (20-22 h). Ship this before touching v1.1.

## v1.1 (after the live URL exists; ~3 evenings)

Each item maps to a noun that showed up repeatedly in Oct 2026 Supabase posts and is missing from the MVP. Do not pull these into Phases 0-5.

| Item | Why | Scope |
|------|-----|-------|
| **Magic link login** | Two of the last three Supabase portal/marketplace posts asked for passwordless / OTP email | "Email me a link" on `/login` using Supabase built-in OTP. Demo buttons stay. No Resend. |
| **Storage + signed URL** | "Secure delivery via short-lived signed links" is the stated top concern in the Oct 4 client-portal post | Owner uploads an event poster to a private bucket; RLS on `storage.objects` scoped by `org_id` path prefix; rendered through a 60 s signed URL. One field `events.poster_path`. |
| **Activity list** | Audit trail appears in every serious comparable repo and in portal posts | Small list on `/app/events/[id]`: who checked in whom, when. Reads existing `checked_in_by` / `checked_in_at`. No new table. |

Hostile test for v1.1: staff from venue A cannot mint a signed URL for venue B's poster (server action rejects; direct Storage REST with staff JWT returns 400/403).

## Implementation mode: DeepSeek worker (mandatory)

Codegen in every implement chat goes through the `deepseek-worker` skill. Not optional for this project. Cursor orchestrates (files, terminal, Supabase CLI, browser, verify); DeepSeek generates text.

Rules per chat:

1. First reply shows the activation banner + start time (local + UTC).
2. `deepseek_ping` once per chat if not verified.
3. `deepseek_code` (`deepseek-v4-pro`, thinking false) **before** any `Write` / `StrReplace` on a codegen unit. Cursor applies the output, strips fences and token footer, runs verify.
4. After each MCP call, one line: `Worker call: deepseek_code · deepseek-v4-pro · [in/out]`.
5. Weak output (not infra error): retry once with `deepseek_chat` + `thinking: true`. MCP error: restart MCP once, then Composer fallback with the `DeepSeek worker unavailable` line.
6. Chat ends with the **Session cost report** block from `deepseek-worker-prompt.md`. Accurate rows from footers only; no invented savings.

Skip DeepSeek only for: ≤10-line edits, renames, shell commands (`pnpm create`, `shadcn add`, `supabase start`, `gh repo create`, `vercel link`), and anything that would put a secret in the context.

**Never pass to DeepSeek:** `.env.local`, `.env.example` values, Supabase anon / service-role keys, `CRON_SECRET`, demo account passwords, Vercel tokens. Pass the task + 1-3 file snippets; SQL migrations and TSX are fine.

Context hygiene: one chat per phase; new chat if context compacts (point it at this plan + "Phase N only"); subagents Fast off or Explore disabled in cost mode.

## Verification (definition of done)

- `pnpm typecheck && pnpm lint && pnpm test` green (tests hit local Supabase)
- Click path: Try as staff -> only own venue events visible, cannot open `/app/venues`; Try as owner -> filter by venue + last 7 days -> card total equals table row count equals CSV row count
- Automated: staff JWT REST call to `guests?venue_id=eq.<other venue>` returns 0 rows (Vitest, Phase 1a)
- Live Vercel URL loads without sign-up; demo buttons work after a cron reset

## After shipping (applications workspace, not this repo)

- Fill Links in [portfolio-employer-demand.md](/Users/aikengunay/Developer/Projects/freelance/applications/portfolio-employer-demand.md) Project 1; move EventPulse from "In progress" to a full entry in [profile/proof-inventory.md](/Users/aikengunay/Developer/Projects/freelance/applications/profile/proof-inventory.md); remove "Supabase in production" from gaps in [profile/candidate.md](/Users/aikengunay/Developer/Projects/freelance/applications/profile/candidate.md)
- Add project card + link on aikengunay.com, Upwork portfolio item, OLJ profile first paragraph
- Re-run the 40-post noun tally. Expect AI-in-product above the 30% gate; plan P4 as a small LLM feature inside the client portal, not a fourth repo.
- **P2 default is now Size B, trimmed (~8-10 evenings):** standalone client portal reusing this scaffold. Reason: Oct 4 agency post requires "at least 2 shipped apps using Supabase Auth with RLS (links and your role)"; EventPulse alone gives one. Invoice payment is also a natural Stripe use; a Pro plan on a check-in tool is not. Scope: admin/client roles with RLS, projects + invoices, Stripe Checkout test mode, one idempotent webhook with `webhook_events`, magic-link login, deliverables in Storage via signed URLs. Drop inbound third-party webhook and Resend from that MVP.
- Start Project 3 (Figma marketing site) after P2, or before if a design-lead post is live.

## Out of scope for MVP

Public RSVP page, Realtime, Edge Functions, Stripe, email sending (Resend/Postmark), multi-org switching UI, full venues/staff CRUD, mobile app, i18n, any AI feature, any LokalFi code or data. v1.1 items stay out until Gate 5 passes.

---

## First messages

One chat per phase. Workspace for implement chats: open `/Users/aikengunay/Developer/Projects/eventpulse` and add `/Users/aikengunay/Developer/Projects/freelance/applications` as a second folder so `@` to this plan resolves. The `post-ship-docs` chat runs in the applications workspace only.

Two parts per chat. **Model** is for you (set the picker; do not paste). **Paste** is the fenced block.

Escalation for every implement chat: `If blocked twice on RLS / Supabase SSR / cron: new chat → Grok 4.6 High, Fast Off, DeepSeek worker off for that chat.`

### Chat 0 — Scaffold

Model (you — set picker; do not paste):
- Mode: Agent
- Pool: Cursor Models
- Model: Composer 2.5
- Fast: On
- Effort: Medium (default)
- Context: Default
- DeepSeek worker: Yes (config files, `AGENTS.md`, `.env.example` keys-only; shell commands run directly)

```markdown
DeepSeek worker mode — follow the deepseek-worker skill.

Rules:
- First reply: activation banner + start time (local + UTC)
- deepseek_ping once if MCP not verified this session
- deepseek_code (deepseek-v4-pro) before any codegen; Cursor applies + verifies
- Do not implement code yourself before deepseek_code
- Shell commands (pnpm create, shadcn add, supabase init/start, gh, vercel) run directly — no DeepSeek
- Never pass .env values, Supabase keys, or CRON_SECRET to DeepSeek
- Minimal context only (@ files)
- End with session cost report (accurate block only — no invented savings)

## Goal
Phase 0 of @.cursor/plans/eventpulse_build_plan_ed2ab01b.plan.md: scaffold the eventpulse repo at /Users/aikengunay/Developer/Projects/eventpulse (Next.js 16.2 App Router, React 19, TS, Tailwind v4, shadcn/ui, @supabase/ssr, Supabase CLI, Vitest, pnpm), copy and fill AGENTS.md from ~/Documents/cursor/how-to-use-cursor/project-stub/AGENTS.md, create public repo aikengunay/eventpulse, link Vercel.

## Files
- /Users/aikengunay/Developer/Projects/eventpulse (new repo) — create
- @.cursor/plans/eventpulse_build_plan_ed2ab01b.plan.md — read only; edit frontmatter at Closeout

## Verify
- `pnpm typecheck && pnpm lint` green
- `supabase start` runs; `.env.example` lists keys without values
- `gh repo view aikengunay/eventpulse` shows public
- Vercel preview URL loads the empty app

## Closeout
Mark `status: completed` in the plan frontmatter for: `p0-scaffold`, `gate-0`. Required before you stop — do not mark Phase 1 todos.

## Out of scope
No schema, no auth, no UI beyond the default page. Do not touch aikengunay.com or any reiinnprojects repo.
```

### Chat 1 — Tests first, then schema + RLS + seed

Model (you — set picker; do not paste):
- Mode: Agent
- Pool: Cursor Models
- Model: Composer 2.5
- Fast: On
- Effort: Medium (default)
- Context: Default
- DeepSeek worker: Yes (SQL migrations, helper functions, policies, Vitest files, seed)

```markdown
DeepSeek worker mode — follow the deepseek-worker skill.

Rules:
- First reply: activation banner + start time (local + UTC)
- deepseek_ping once if MCP not verified this session
- deepseek_code (deepseek-v4-pro) before any codegen; Cursor applies + verifies
- Do not implement code yourself before deepseek_code
- Never pass .env values or Supabase keys to DeepSeek; SQL and test files are fine
- Minimal context only (@ files)
- End with session cost report (accurate block only — no invented savings)

## Goal
Phase 1 of @.cursor/plans/eventpulse_build_plan_ed2ab01b.plan.md. 1a: write failing Vitest DB tests against local Supabase (two seeded sessions): staff cannot select other-venue guests; staff cannot insert events; owner sees all three venues; dashboard_stats totals equal raw count(*) for the same filter; hostile PostgREST call with staff JWT for guests?venue_id=eq.<other venue> returns 0 rows. 1b: migrations (enums, tables per the schema section, org_id/venue_id denormalization trigger on guests, my_org_ids / is_org_owner / my_staff_venue_ids, RLS policies, dashboard_stats security-invoker RPC, reset_demo), seed (1 org, 3 venues, 12 events, ~300 guests). Tests green.

## Files
- supabase/migrations/*.sql — create
- supabase/seed.sql (or scripts/seed.ts) — create
- tests/db/*.test.ts, vitest.config.ts — create
- @.cursor/plans/eventpulse_build_plan_ed2ab01b.plan.md — read; edit frontmatter at Closeout

## Verify
- Tests fail before migrations, pass after: `pnpm test`
- `supabase db reset` applies migrations + seed cleanly
- Hostile REST test asserts 0 rows (staff JWT, other venue) and 42501 on staff event insert

## Closeout
Mark `status: completed` in the plan frontmatter for: `p1a-tests-first`, `p1b-schema`, `gate-1`. Required before you stop — do not mark Phase 2 todos.

## Out of scope
No Next.js pages, no auth UI, no Storage, no Stripe. Check-ins live on guests; do not add a checkins table.
```

### Chat 2 — Auth and app shell

Model (you — set picker; do not paste):
- Mode: Agent
- Pool: Cursor Models
- Model: Composer 2.5
- Fast: On
- Effort: Medium (default)
- Context: Default
- DeepSeek worker: Yes (Supabase SSR helpers, middleware, login page, server actions, layout)

```markdown
DeepSeek worker mode — follow the deepseek-worker skill.

Rules:
- First reply: activation banner + start time (local + UTC)
- deepseek_ping once if MCP not verified this session
- deepseek_code (deepseek-v4-pro) before any codegen; Cursor applies + verifies
- Do not implement code yourself before deepseek_code
- Never pass .env values, Supabase keys, or demo passwords to DeepSeek
- Minimal context only (@ files)
- End with session cost report (accurate block only — no invented savings)

## Goal
Phase 2 of @.cursor/plans/eventpulse_build_plan_ed2ab01b.plan.md: @supabase/ssr browser + server clients, middleware session refresh, /login (email + password), demo-login server action ("Try as owner" / "Try as staff" using env-held credentials), sign out, /app layout with sidebar, role-aware nav (owner-only items hidden for staff), org/venue header. Data access only through the user-session client.

## Files
- lib/supabase/{client,server,middleware}.ts — create
- middleware.ts — create
- app/(auth)/login/page.tsx, app/actions/auth.ts — create
- app/app/layout.tsx, components/app-shell/* — create
- app/page.tsx — edit (demo buttons)
- @.cursor/plans/eventpulse_build_plan_ed2ab01b.plan.md — read; edit frontmatter at Closeout

## Verify
- Try as owner → /app, Try as staff → /app/events?today=1
- Sign out returns to /
- Staff does not see Venues / Staff nav items; direct visit to /app/venues as staff shows empty or 403 (RLS, not UI)
- `pnpm typecheck && pnpm lint` green

## Closeout
Mark `status: completed` in the plan frontmatter for: `p2-auth-shell`, `gate-2`. Required before you stop — do not mark Phase 3 todos.

## Out of scope
No magic link yet (v1.1). No events UI, no dashboard. No service-role key anywhere in app code.
```

### Chat 3 — Events and check-in

Model (you — set picker; do not paste):
- Mode: Agent
- Pool: Cursor Models
- Model: Composer 2.5
- Fast: On
- Effort: Medium (default)
- Context: Default
- DeepSeek worker: Yes (pages, dialogs, server actions, tables)

```markdown
DeepSeek worker mode — follow the deepseek-worker skill.

Rules:
- First reply: activation banner + start time (local + UTC)
- deepseek_ping once if MCP not verified this session
- deepseek_code (deepseek-v4-pro) before any codegen; Cursor applies + verifies
- Do not implement code yourself before deepseek_code
- Never pass .env values or Supabase keys to DeepSeek
- Minimal context only (@ files)
- End with session cost report (accurate block only — no invented savings)

## Goal
Phase 3 of @.cursor/plans/eventpulse_build_plan_ed2ab01b.plan.md: /app/events list with owner create/edit dialog; /app/events/[id] guest table with check-in / no-show toggle via server action (optimistic update) that writes checked_in_by + checked_in_at; /app/venues and /app/staff as read-only tables (owner). All writes through the user-session client so RLS enforces role.

## Files
- app/app/events/page.tsx, app/app/events/[id]/page.tsx — create
- app/actions/events.ts, app/actions/guests.ts — create
- components/events/*, components/guests/* — create
- app/app/venues/page.tsx, app/app/staff/page.tsx — create (read-only)
- @.cursor/plans/eventpulse_build_plan_ed2ab01b.plan.md — read; edit frontmatter at Closeout

## Verify
- Owner creates and edits an event; staff sees no create button and server action rejects staff insert
- Staff toggles a guest to checked_in; row shows checked_in_by = staff user; toggle back to pending clears it
- Staff visiting /app/venues sees nothing from RLS
- `pnpm typecheck && pnpm lint && pnpm test` green

## Closeout
Mark `status: completed` in the plan frontmatter for: `p3-events-checkin`, `gate-3`. Required before you stop — do not mark Phase 4 todos.

## Out of scope
No venues/staff CRUD. No poster upload, no activity list (v1.1). No dashboard or CSV.
```

### Chat 4 — Dashboard and export

Model (you — set picker; do not paste):
- Mode: Agent
- Pool: Cursor Models
- Model: Composer 2.5
- Fast: On
- Effort: Medium (default)
- Context: Default
- DeepSeek worker: Yes (filter bar, cards, Recharts chart, table, CSV route)

```markdown
DeepSeek worker mode — follow the deepseek-worker skill.

Rules:
- First reply: activation banner + start time (local + UTC)
- deepseek_ping once if MCP not verified this session
- deepseek_code (deepseek-v4-pro) before any codegen; Cursor applies + verifies
- Do not implement code yourself before deepseek_code
- Never pass .env values or Supabase keys to DeepSeek
- Minimal context only (@ files)
- End with session cost report (accurate block only — no invented savings)

## Goal
Phase 4 of @.cursor/plans/eventpulse_build_plan_ed2ab01b.plan.md: /app owner dashboard. Filter bar (date range, venue, status) with URL search params as state; 3 summary cards + check-ins-per-day Recharts bar chart + paginated guests table, all fed by the dashboard_stats RPC; /app/export route handler streams CSV for the same filter; empty and loading states.

## Files
- app/app/page.tsx, app/app/export/route.ts — create / edit
- components/dashboard/* — create
- lib/filters.ts (search-param parsing) — create
- @.cursor/plans/eventpulse_build_plan_ed2ab01b.plan.md — read; edit frontmatter at Closeout

## Verify
- Filter venue + last 7 days: card total = table row count = CSV row count
- Change status filter → URL updates, back button restores previous filter
- Empty state renders for a date range with no guests; loading skeleton on navigation
- `pnpm typecheck && pnpm lint && pnpm test` green

## Closeout
Mark `status: completed` in the plan frontmatter for: `p4-dashboard-export`, `gate-4`. Required before you stop — do not mark Phase 5 todos.

## Out of scope
No client-side aggregation after joins — totals come from dashboard_stats only. No new tables. No Realtime.
```

### Chat 5 — Ship

Model (you — set picker; do not paste):
- Mode: Agent
- Pool: Cursor Models
- Model: Composer 2.5
- Fast: On
- Effort: Medium (default)
- Context: Default
- DeepSeek worker: Yes (cron route, README sections); Vercel / Supabase CLI steps run directly

```markdown
DeepSeek worker mode — follow the deepseek-worker skill.

Rules:
- First reply: activation banner + start time (local + UTC)
- deepseek_ping once if MCP not verified this session
- deepseek_code (deepseek-v4-pro) before any codegen; Cursor applies + verifies
- Do not implement code yourself before deepseek_code
- Vercel, Supabase CLI, and gh commands run directly — no DeepSeek
- Never pass .env values, Supabase keys, CRON_SECRET, or demo passwords to DeepSeek
- Minimal context only (@ files)
- End with session cost report (accurate block only — no invented savings)

## Goal
Phase 5 of @.cursor/plans/eventpulse_build_plan_ed2ab01b.plan.md: Supabase cloud project + migrations + seed; Vercel env vars and production deploy; /api/cron/reset-demo guarded by CRON_SECRET calling reset_demo() with the service role, scheduled nightly in vercel.json; README with pitch, schema diagram, RLS summary, "why totals are correct" note, demo credentials, local setup, and an ops section (local/staging/prod env separation, backups, demo-cred rotation, how RLS tests run); Lighthouse quick pass on / and /app. Loom is recorded by the human.

## Files
- app/api/cron/reset-demo/route.ts, vercel.json — create
- README.md — create / edit
- @.cursor/plans/eventpulse_build_plan_ed2ab01b.plan.md — read; edit frontmatter at Closeout

## Verify
- Live Vercel URL loads without sign-up; Try as owner / Try as staff both work
- Trigger cron route manually with CRON_SECRET → data resets; demo buttons still work
- README renders schema diagram and ops section
- Lighthouse ≥ 90 performance on / (quick pass)

## Closeout
Mark `status: completed` in the plan frontmatter for: `p5-ship`, `gate-5`. Required before you stop. Tell the human the live URL and that post-ship-docs can start in the applications workspace.

## Out of scope
No v1.1 items. No custom domain yet. Do not edit anything under freelance/applications except the plan frontmatter.
```

### Chat 6 — Post-ship docs (applications workspace, Composer only)

Model (you — set picker; do not paste):
- Mode: Agent
- Pool: Cursor Models
- Model: Composer 2.5
- Fast: On
- Effort: Medium (default)
- Context: Default
- DeepSeek worker: No (prose + tracker edits; no codegen)

```markdown
## Goal
Post-ship docs for EventPulse per the After shipping section of @.cursor/plans/eventpulse_build_plan_ed2ab01b.plan.md: fill Project 1 Links in @portfolio-employer-demand.md, add the full EventPulse entry to @profile/proof-inventory.md, remove "Supabase in production" from gaps in @profile/candidate.md, add the application line to @profile/upwork-profile.md and @profile/olj-profile.md. Live URL, repo URL, Loom URL: [paste].

## Files
- @portfolio-employer-demand.md — edit
- @profile/proof-inventory.md — edit
- @profile/candidate.md — edit
- @profile/upwork-profile.md, @profile/olj-profile.md — edit
- @.cursor/plans/eventpulse_build_plan_ed2ab01b.plan.md — edit frontmatter at Closeout

## Verify
- Every "_TBD_" under Project 1 Links is replaced
- proof-inventory entry lists the true stack only (Next 16, Supabase Auth/Postgres/RLS, Recharts, Vercel) — no Stripe, no Realtime

## Closeout
Mark `status: completed` in the plan frontmatter for: `post-ship-docs`. Required before you stop.

## Out of scope
Do not touch aikengunay.com repo in this chat (separate task). No changes to EventPulse code.
```

### Chat 7 — v1.1 (after Gate 5)

Model (you — set picker; do not paste):
- Mode: Agent
- Pool: Cursor Models
- Model: Composer 2.5
- Fast: On
- Effort: Medium (default)
- Context: Default
- DeepSeek worker: Yes (OTP login form, Storage policies migration, upload action, signed-URL helper, activity list)

```markdown
DeepSeek worker mode — follow the deepseek-worker skill.

Rules:
- First reply: activation banner + start time (local + UTC)
- deepseek_ping once if MCP not verified this session
- deepseek_code (deepseek-v4-pro) before any codegen; Cursor applies + verifies
- Do not implement code yourself before deepseek_code
- Never pass .env values or Supabase keys to DeepSeek
- Minimal context only (@ files)
- End with session cost report (accurate block only — no invented savings)

## Goal
v1.1 of @.cursor/plans/eventpulse_build_plan_ed2ab01b.plan.md: (1) "Email me a link" on /login via Supabase OTP, demo buttons unchanged; (2) events.poster_path + private Storage bucket with RLS on storage.objects scoped by org_id path prefix, owner upload action, 60 s signed URL render on event page; (3) activity list on /app/events/[id] from checked_in_by / checked_in_at. Add Vitest: staff from venue A cannot mint a signed URL for venue B's poster.

## Files
- app/(auth)/login/page.tsx, app/actions/auth.ts — edit
- supabase/migrations/*_storage_posters.sql — create
- app/actions/posters.ts, lib/storage.ts — create
- app/app/events/[id]/page.tsx, components/events/activity-list.tsx — edit / create
- tests/db/storage.test.ts — create
- README.md — edit (auth options, Storage note)
- @.cursor/plans/eventpulse_build_plan_ed2ab01b.plan.md — read; edit frontmatter at Closeout

## Verify
- Magic link signs in a real (non-demo) account on local Supabase (Inbucket)
- Owner uploads a poster; event page shows it via signed URL that expires
- Staff on venue A: server action for venue B poster rejects; direct Storage REST with staff JWT returns 400/403 (test)
- Activity list rows match guests with status checked_in
- `pnpm typecheck && pnpm lint && pnpm test` green; redeploy to Vercel

## Closeout
Mark `status: completed` in the plan frontmatter for: `v11-magic-link`, `v11-storage`, `v11-activity`, `gate-v11`. Required before you stop.

## Out of scope
No Resend/Postmark. No Realtime, no Stripe, no RSVP page. No new tables beyond storage policies.
```

## After final gate

Human-only — do not paste into implement chats.

| When | Action |
| --- | --- |
| After Gate 5 passes | Optional `simplify-ai-slop` on any slice that felt bloated (DeepSeek output tends to over-comment) |
| Before announcing the repo publicly | Optional Thermos (both tracks) — **one** review chat on `main` |
| README and landing copy | Optional `no-ai-slop` on your draft |
| Do not | Thermos, Bugbot, or Security Review between slices (mid-feature) |
| Do not | Stack Thermos + Bugbot + Security on the same diff unless you ask for a second pass |

Product `.cursor/rules` (none yet) and `AGENTS.md` apply automatically — no plan line needed.
