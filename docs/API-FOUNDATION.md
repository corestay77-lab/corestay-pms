# CoreStay API foundation

## Current scope

The first server-side endpoint is `GET /api/health`. It is a readiness check, not an application data API. It verifies that Vercel has a server-only `DATABASE_URL`, can connect to PostgreSQL, and can see the minimum foundation tables.

Response states:
- `DATABASE_NOT_CONFIGURED`: the Vercel environment variable is absent.
- `DATABASE_CONNECTION_FAILED`: connection failed; internal error details are intentionally not returned.
- `migration_required`: PostgreSQL is reachable but the expected foundation tables are not present.
- `foundation_present`: the expected tables exist.

The endpoint does not expose database host, credentials, SQL errors, tenant names, user information, or operational records.

## Vercel setup (owner action required)

1. In Vercel, open the `corestay-pms` project and connect a new Neon PostgreSQL database through the Marketplace.
2. Use a dedicated database for CoreStay staging first. Do not connect a database containing unrelated or production data.
3. Set `DATABASE_URL` as a server-only environment variable for Preview. Use the pooled connection string. Never use a `NEXT_PUBLIC_` prefix.
4. Do not add the admin/owner database credential as the runtime `DATABASE_URL`. Create a restricted runtime role after reviewing the migration and grant it only required access.
5. Apply the reviewed migration to the empty staging database using a separate migration/admin connection.
6. Deploy the branch preview and open `/api/health`. It should report `foundation_present` only after the migration is applied.

Do not send credentials in chat or commit them to GitHub.

## Important security gate before business APIs

The schema currently protects tenant-scoped tables with forced PostgreSQL RLS. Business API routes must not be added until all of these are implemented and tested:

- Authentication/session verification on the server.
- Membership resolution from trusted identity, not browser-supplied tenant/hotel IDs.
- A restricted runtime database role that is not superuser, table owner, or `BYPASSRLS`.
- Every tenant-scoped query runs in one database transaction with transaction-local `app.tenant_id` and `app.hotel_id` set by trusted server code.
- Cross-tenant and cross-property isolation tests.
- Idempotency and atomic transaction boundaries for payments, check-in/out, inventory posting, and General Ledger.

The health endpoint deliberately does not bypass RLS or create initial tenant/user records.

## Existing browser data

The existing application remains on its current localStorage storage key. This endpoint does not read or modify browser storage. Export, checksum, snapshot, dry-run import, and reconciliation are required before any production cutover.
