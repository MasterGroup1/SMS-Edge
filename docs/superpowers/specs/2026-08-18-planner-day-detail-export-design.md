# Planner Day Detail View + CSV Export

## Problem

The Planner Calendar (`renderPlannerCalendar`, index.html ~line 2286) shows a chip per planned send on each day, with an estimated-cost breakdown available only as a hover tooltip. There's no way to see a day's full list of sends at a glance, get a per-day summary (total estimated cost, total estimated send volume), or take that data out of the dashboard (e.g. to hand off or archive).

## Goals

- Click a calendar day with planned sends to open a detail view listing everything sending that day, with a summary (total lists, total estimated send volume, total estimated cost).
- From that same view, export the day's data as a CSV.

## Non-goals

- No `.xlsx` export (CSV only — opens fine in Excel/Sheets, needs no new dependency).
- No standalone export icon directly on calendar cells — export lives inside the detail modal only.
- No changes to how estimated cost or estimated send volume are computed — reuses the existing `cost_per_camp` metric and the `estimatedSize()` helper already used for Clicker eligibility (manual List Size if set, else average sent per campaign).

## Design

### Trigger

Calendar day cells that have at least one planned send become clickable (`cursor:pointer`, `onclick`). Days with zero planned sends are not clickable — nothing happens on click.

### Detail view

A modal opens over the calendar showing:

- **Header:** the date, plus a one-line summary — total lists, total estimated send volume, total estimated cost.
- **Table**, one row per list planned that day:
  - List Name
  - Country
  - Type (Main / Clicker)
  - Estimated Send Volume — `estimatedSize(list)`
  - Estimated Cost — `cost_per_camp` from that list's existing metrics group
  - Rows sorted by Estimated Cost, descending (biggest sends surfaced first)
- **Export CSV** button in the modal header.

### CSV export

Triggered from the button inside the modal. Contains the same columns/rows as the table, plus a totals row at the bottom (total send volume, total cost). Filename: `planner-YYYY-MM-DD.csv`. Built with a plain CSV-string function and a browser download trigger (`Blob` + temporary `<a>` link) — no new library.

### Implementation shape

- One function to gather a day's data (list rows + summary totals), shared by both the modal render and the CSV export so they can never drift apart from each other.
- A small modal render/open/close function set, following the existing modal/popover patterns already in index.html (e.g. the Clicker-align country picker).
- A CSV-string builder + download-trigger function.
- Wiring: add `onclick` to calendar day cells inside `renderPlannerCalendar`, conditional on that day having planned sends.

## Open questions

None outstanding — design approved as presented.
