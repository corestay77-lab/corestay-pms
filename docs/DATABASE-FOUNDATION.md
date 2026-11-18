# CoreStay Database Foundation

Status: schema foundation prepared on branch `feature/corestay-database-foundation`.
This is a staged foundation, not a live database connection. No production data is migrated by this change.

## Architecture

- PostgreSQL is the system of record for shared, multi-device and multi-hotel operation.
- Vercel remains the application/deployment host.
- The application server must authenticate users and resolve tenant/property membership before querying tenant data.
- Every tenant-scoped request must run in a database transaction and set trusted context with `SET LOCAL app.tenant_id = '<uuid>'`. Set `app.hotel_id` as well when the request is scoped to one property.
- Never trust a tenant or hotel identifier supplied by the browser without checking the authenticated user's membership.
- Use a pooled PostgreSQL connection string for serverless request traffic. Keep credentials in Vercel environment variables; never commit secrets.

## Initial schema

Migration `db/migrations/0001_corestay_foundation.sql` creates:

- `tenants`: customer organizations.
- `hotels`: properties belonging to a tenant, with timezone, currency, country and business date.
- `users`: global user identities; passwords and provider secrets do not belong in this table.
- `tenant_memberships` and `hotel_memberships`: explicit organization/property access.
- `permissions`, `roles`, `role_permissions`, `hotel_membership_roles`: RBAC foundation.
- `hotel_settings`: property-level JSON settings.
- `audit_logs`: append-only audit history.
- `schema_migrations`: applied migration registry.

Tenant-scoped tables have PostgreSQL Row-Level Security policies. The database context must be set by trusted backend code within a transaction. The application must use a restricted runtime database role, not the schema owner/superuser, because owners and roles with BYPASSRLS can bypass RLS unless FORCE ROW LEVEL SECURITY is applied and ownership is handled appropriately.

## Apply to a new PostgreSQL database

1. Create a PostgreSQL database (Neon is the planned managed provider).
2. Create a dedicated migration/owner role and a separate restricted runtime role. Do not use the owner role in Vercel.
3. Back up and verify the target database is empty/new before applying this first migration.
4. Apply the SQL from `db/migrations/0001_corestay_foundation.sql` using a trusted migration runner or `psql`.
5. Verify `schema_migrations` contains `0001_corestay_foundation`, and verify RLS is enabled on all tenant-scoped tables.
6. Add the pooled connection string to Vercel as `DATABASE_URL` only after the database and restricted role are ready.
7. Test tenant A and tenant B using separate authenticated contexts and verify cross-tenant SELECT/INSERT/UPDATE are denied.

Example command (run locally in a trusted terminal; never put credentials in Git):
```sh
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/migrations/0001_corestay_foundation.sql
```

## Backend transaction contract

For every request:

1. Verify session/token.
2. Resolve the user's active tenant membership and property membership on the server.
3. Acquire a pooled connection.
4. Begin a transaction.
5. Set context with parameterized values:
   ```sql
   SELECT set_config('app.tenant_id', $1, true);
   SELECT set_config('app.hotel_id', $2, true); -- when property scoped
   ```
6. Execute all tenant-scoped queries on that same connection.
7. Commit or rollback, then release the connection.

Do not set tenant context with a session-level SET on a pooled connection. Use transaction-local settings so context cannot leak to another request.

## Existing CoreStay data: preservation rules

The current application is a static browser app and stores operational state in browser `localStorage`; `app.js` currently declares the storage key `corestay-pms-v3`. This migration does not read, clear, rename, or overwrite that key.

Before any live cutover:

- Export the current browser data from each device/browser profile that contains business records.
- Keep immutable, timestamped copies and verify their hashes/record counts.
- Map the existing structures (reservations, in-house guests, folios, payments, POS, inventory, journals, room status and sequence counters) to normalized PostgreSQL tables.
- Run a dry-run import into a staging database; report rejected rows and duplicates.
- Reconcile counts and financial totals, including balanced journals and sub-ledger balances.
- Test concurrent users and tenant isolation.
- Keep the old application and local data read-only/available until the owner approves cutover and restore has been tested.

Do not assume localStorage data is shared across devices: each browser profile may have a different copy. Do not delete the old storage key after import.

## Next migrations

1. Core operational masters: room types, rooms, rate plans, guests, companies, outlets, departments, tax/service configuration.
2. Front Office: reservations, reservation rooms, in-house stays, folios, folio entries, deposits, payments and night audit.
3. Back Office: suppliers, purchasing, receiving, inventory lots, stock movements, AP/AR.
4. Accounting: chart of accounts, journal headers/lines, posting periods and reconciliation.
5. Migration/import tooling and read-only comparison reports.

Financial records should be append-oriented with explicit reversal/void records, unique idempotency keys, and database transactions. Do not silently overwrite posted transactions.

## Operational readiness checklist

- [ ] Managed PostgreSQL project and region selected.
- [ ] Separate migration and restricted runtime roles created.
- [ ] Migration applied successfully to a new staging database.
- [ ] RLS cross-tenant tests pass.
- [ ] Backup/PITR configured and restore drill completed.
- [ ] Vercel environment variables configured without exposing secrets.
- [ ] Backend authentication and tenant context implemented.
- [ ] Existing browser data exported and reconciled before import.
- [ ] FO-to-BO-to-GL end-to-end tests pass before production cutover.
