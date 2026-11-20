-- Shared storage for the Daily Report: Tableau uploads (daily + monthly) and your own findings/action items.
-- Without this table the dashboard keeps uploaded Tableau data in the
-- uploader's browser only. Run once in Supabase → SQL Editor.
create table if not exists public.tableau_daily (
  day         date primary key,
  data        jsonb not null,
  source      text,
  uploaded_at timestamptz not null default now()
);
alter table public.tableau_daily enable row level security;
create policy "tableau_daily read"   on public.tableau_daily for select using (true);
create policy "tableau_daily insert" on public.tableau_daily for insert with check (true);
create policy "tableau_daily update" on public.tableau_daily for update using (true) with check (true);

-- Tableau Monthly Summary uploads (one row per month, e.g. '2026-11').
create table if not exists public.tableau_monthly (
  month       text primary key,
  data        jsonb not null,
  source      text,
  uploaded_at timestamptz not null default now()
);
alter table public.tableau_monthly enable row level security;
create policy "tableau_monthly read"   on public.tableau_monthly for select using (true);
create policy "tableau_monthly insert" on public.tableau_monthly for insert with check (true);
create policy "tableau_monthly update" on public.tableau_monthly for update using (true) with check (true);

-- Your own Key findings / Action items on the Daily Report.
create table if not exists public.report_notes (
  id          text primary key,
  kind        text not null check (kind in ('finding', 'action')),
  text        text not null,
  color       text,
  done        boolean not null default false,
  created_at  timestamptz not null default now()
);
alter table public.report_notes enable row level security;
create policy "report_notes read"   on public.report_notes for select using (true);
create policy "report_notes insert" on public.report_notes for insert with check (true);
create policy "report_notes update" on public.report_notes for update using (true) with check (true);
create policy "report_notes delete" on public.report_notes for delete using (true);
