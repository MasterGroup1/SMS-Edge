-- Shared storage for Tableau warehouse uploads (Daily Report tab): daily and monthly summaries.
-- Without this table the dashboard keeps uploaded Tableau data in the
-- uploader's browser only. Run once in Supabase → SQL Editor.
create table if not exists public.warehouse_daily (
  day         date primary key,
  data        jsonb not null,
  source      text,
  uploaded_at timestamptz not null default now()
);
alter table public.warehouse_daily enable row level security;
create policy "warehouse_daily read"   on public.warehouse_daily for select using (true);
create policy "warehouse_daily insert" on public.warehouse_daily for insert with check (true);
create policy "warehouse_daily update" on public.warehouse_daily for update using (true) with check (true);

-- Tableau Monthly Summary uploads (one row per month, e.g. '2026-11').
create table if not exists public.warehouse_monthly (
  month       text primary key,
  data        jsonb not null,
  source      text,
  uploaded_at timestamptz not null default now()
);
alter table public.warehouse_monthly enable row level security;
create policy "warehouse_monthly read"   on public.warehouse_monthly for select using (true);
create policy "warehouse_monthly insert" on public.warehouse_monthly for insert with check (true);
create policy "warehouse_monthly update" on public.warehouse_monthly for update using (true) with check (true);
