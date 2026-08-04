-- SMS Edge — missing tables for the "Use Again" decision audit trail.
--
-- WHY THIS EXISTS
-- The manual Use Again override, its audit trail, and manual list sizes all
-- shipped in the UI, but these three tables were never created in the Supabase
-- project. The dashboard's write calls did not check the error the Supabase
-- client returns, so every decision appeared to save, updated on screen, and
-- then vanished on reload. Verified missing (HTTP 404 on /rest/v1/<table>):
--   list_decisions, list_decision_history, list_sizes
-- Existing and working: campaigns, content_rows, planned_sends.
--
-- HOW TO APPLY
-- Supabase dashboard → SQL Editor → paste this file → Run.
-- Safe to re-run: everything is IF NOT EXISTS / idempotent.

-- ── Current decision per list (one row per list, upserted on `list`) ─────────
create table if not exists public.list_decisions (
  list          text primary key,
  use_again     text,                    -- 'Yes' | 'Maybe' | 'No' | null (= revert to AI)
  reason        text        not null default '',
  decision_date date,
  updated_at    timestamptz not null default now()
);

-- ── Append-only audit trail: who decided what, when ─────────────────────────
-- Never upserted — every change, including clearing back to the AI suggestion,
-- appends a row. This is the "audit trail of which lists were retired and when"
-- from the Aug 3 requirements.
create table if not exists public.list_decision_history (
  id            bigserial primary key,
  list          text        not null,
  use_again     text,                    -- null row = reverted to the AI suggestion
  reason        text        not null default '',
  decision_date date,
  changed_at    timestamptz not null default now()
);

create index if not exists list_decision_history_list_idx
  on public.list_decision_history (list, changed_at desc);

-- ── Manual full list size (contacts) ────────────────────────────────────────
-- Kept separate from list_decisions so clearing a Send-or-Not decision (which
-- deletes its list_decisions row) never wipes the size. Cannot be derived from
-- Sent, because sends are often partial.
create table if not exists public.list_sizes (
  list       text primary key,
  size       integer     not null default 0,
  updated_at timestamptz not null default now()
);

-- ── Access ──────────────────────────────────────────────────────────────────
-- The dashboard is a static page that talks to Supabase with the public `anon`
-- key and has no login, so anon must be able to read and write these tables.
-- The policies below match how campaigns / content_rows / planned_sends already
-- behave in this project.
--
-- SECURITY NOTE: this means anyone with the dashboard URL can read and modify
-- this data. That is inherent to the current no-auth design, not something these
-- policies introduce. If that is not acceptable, the fix is to put the dashboard
-- behind auth and scope these policies to authenticated users instead.
alter table public.list_decisions        enable row level security;
alter table public.list_decision_history enable row level security;
alter table public.list_sizes            enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies
                 where schemaname = 'public' and tablename = 'list_decisions'
                   and policyname = 'anon_all_list_decisions') then
    create policy anon_all_list_decisions on public.list_decisions
      for all to anon using (true) with check (true);
  end if;

  if not exists (select 1 from pg_policies
                 where schemaname = 'public' and tablename = 'list_decision_history'
                   and policyname = 'anon_all_list_decision_history') then
    create policy anon_all_list_decision_history on public.list_decision_history
      for all to anon using (true) with check (true);
  end if;

  if not exists (select 1 from pg_policies
                 where schemaname = 'public' and tablename = 'list_sizes'
                   and policyname = 'anon_all_list_sizes') then
    create policy anon_all_list_sizes on public.list_sizes
      for all to anon using (true) with check (true);
  end if;
end $$;

-- ── Verify ──────────────────────────────────────────────────────────────────
-- Should return three rows.
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('list_decisions', 'list_decision_history', 'list_sizes')
order by table_name;
