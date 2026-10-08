# EventPulse roadmap

Phase order and gates live in `.cursor/plans/eventpulse_build_plan_ed2ab01b.plan.md`. One Agent chat per phase.

| Phase | Scope | Gate |
| --- | --- | --- |
| 0 | Scaffold (Next, Tailwind, shadcn, Supabase CLI, Vitest) | typecheck + lint green; supabase start; Vercel preview |
| 1 | Schema, RLS, seed + Vitest DB tests | `pnpm test` green against local Supabase |
| 2 | Auth + app shell | Demo login lands on `/app` |
| 3 | Events CRUD + check-in | Staff scoped by RLS |
| 4 | Dashboard + CSV export | Counts match across UI and export |
| 5 | Ship (cloud Supabase, Vercel, cron, README, Loom) | Live demo URL works after cron reset |

v1.1 (after Gate 5): magic link, Storage posters, activity trail.
