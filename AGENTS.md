# EventPulse

## What this is

EventPulse is a public portfolio proof app — multi-venue event check-in and analytics admin with Supabase Auth + RLS. Demo login, deployed on Vercel.

## How to run

```bash
pnpm install
cp .env.example .env.local   # fill from `supabase status` after `supabase start`
supabase start
pnpm dev
```

## How to verify done

- `pnpm typecheck && pnpm lint && pnpm test`
- `supabase start` runs for local DB
- Default page loads at `http://localhost:3000`

## Stack facts

- Language / framework: TypeScript, Next.js 16.2 App Router, React 19
- Package manager: pnpm
- Where config lives: `next.config.ts`, `app/globals.css` + `postcss.config.mjs`, `components.json`, `supabase/config.toml`
- Where the main entry is: `app/layout.tsx`, `app/page.tsx`; Supabase helpers in `lib/supabase/`
- Anything the agent always gets wrong in this repo: RLS is the auth layer — use the user-session Supabase client in app code, not the service role; middleware only refreshes sessions in Phase 0; never commit `.env.local`

## Current status

Phase 0 scaffold: empty Next app, shadcn/ui components installed, Supabase CLI init, Vitest smoke test. No schema or auth yet.

## Cursor in this repo

Layer 1 (User Rules, personal skills, Thermos plugin) is already on the machine. Do not install plugins or copy skills into this repo.

Product rules in `.cursor/rules` when added. Thermos only when asked for merge-ready or a branch review.

Phase order: `docs/roadmap.md`. Phased implement procedure lives in the `plan-then-implement` skill — do not copy Closeout rules here. Model names belong in task plans, not in this file.

## External worker

- DeepSeek MCP worker: yes
- Bulk codegen via `deepseek-worker`; no secrets in worker context

## Wrapper

Runbooks, deploy docs, and client-facing verify live in `README.md` and `docs/` — not in the OS kit.
