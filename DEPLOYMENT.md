# Launch Bridge deployment

Select `johnadedejiakorede-art/folhope-farm`, branch `main`.
Root: repository root. Build command: `npm run build`. Output directory: `dist`.
The output is already committed for upload workflows without a build step.
`launchbridge.json` lists the database scripts in execution order.

This application requires Cloudflare Pages Functions advanced mode. Deploy
`dist/_worker.js` as the Pages worker, not as an ordinary downloadable asset.
A static-only uploader will show the sign-in page but will not run its API.

Set these Cloudflare **server-side runtime** bindings for the target database:
- `SUPABASE_URL`: the target Supabase project URL.
- `SUPABASE_KEY`: the target project's legacy anon key, stored as a secret.
The existing RPC expects a bearer-compatible legacy anon JWT. Do not substitute
a new publishable key without changing the authorization header handling.
Never put a service role key in the frontend or repository.

Apply all three scripts to a fresh database in the manifest order. They create the
private schema, custom staff accounts, RPC and fictional operational records.
This application uses its own staff sessions rather than Supabase Auth; it does
not implement Launch Bridge's first-registrant owner adapter. Use the seeded
administrator described in README.md for this academic demonstration.

After deployment verify `/api/health`, administrator sign-in, an authenticated
inventory read, logout, and access denial after logout. Source packaging and local
API checks do not prove Launch Bridge provisions the worker and runtime secrets.
The original standalone Worker configuration remains in `wrangler.jsonc`; Pages
runtime variables must be configured separately from that file.
