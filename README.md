# Fol-Hope Farm Management System

Deployed 13 October 2026.

Live application: https://fol-hope-farm-management.johnadedejiakorede.workers.dev/
Supabase project: enwlfhfkbrqrkpfotpgy

Administrator demo login: admin@folhope.demo
Password: FarmDemo2026!
Other seeded accounts use the same demonstration password: manager@folhope.demo, store@folhope.demo, sales@folhope.demo and each division slug @folhope.demo.

All farm records are fictional demonstration data. Do not use these shared demo accounts for real farm or personal data.

## Included
Seven division screens, production batches and movements, egg collection, hatchery records, cattle weights, feed production, shared inventory, sales and payments, expenses, reports/CSV, staff administration and audit history. Database is persistent Supabase Postgres; Cloudflare Worker proxies authenticated RPC using opaque HttpOnly session cookies. Private tables deny direct client access.

## Deployment
The deployed bundle is src/deployed.mjs. public/ contains editable UI sources; changes need rebuilding the bundled HTML/CSS/JS before upload. The original src/worker.js is a template containing __APP_HTML__.
Apply database/migration.sql to a new Supabase project, update SUPABASE_URL in wrangler.jsonc, configure SUPABASE_KEY as a Worker secret using the project anon key, and deploy src/deployed.mjs with Wrangler. API keys are not included in this archive.

## Verified
Cloudflare upload and workers.dev activation; homepage HTTP 200; live API login and authenticated state (7 divisions, 20 stock items); SQL-backed reports/CSV, batch creation and mortality stock balance, division data scoping and denial of unauthorized admin action; JavaScript syntax checks.
The checks that insert temporary records run in a transaction and roll back.

## Limits
This is a student demonstration, not a full commercial implementation. All screens have not received a complete visual or end-to-end browser acceptance test. The hosted reset action is disabled. The Supabase public RPC is an invoker wrapper around a private, fixed-search-path function that deliberately validates custom session tokens; private table RLS has no permissive policies. Update/edit support varies by record type. Use fictional records for demonstrations.

## Operations dashboard refresh
The interface was redesigned with larger type, financial summaries, seven-day sales/expense charts, payment collection progress and division cards. Simulated customer and production activity is installed by database/simulated_operations.sql after migration.sql. These records are synthetic and are not verified Fol-Hope business results. The interface omits demonstration badges for presentation.

## Before-and-after audit upgrade
Apply database/audit_upgrade.sql after migration.sql to capture edits with actor, timestamp, record reference and changed-field values. Password hashes are excluded; password changes show a redacted marker. Historical entries are retained and are not backfilled. Audit history displays the most recent 120 entries with search and expandable details. Tests verified expense amount diffs, actor attribution and password redaction using rolled-back transactions.
