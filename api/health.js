const { neon } = require('@neondatabase/serverless');

module.exports = async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store, max-age=0');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'no-referrer');

  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({ ok: false, code: 'METHOD_NOT_ALLOWED' });
  }

  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    return res.status(503).json({
      ok: false,
      database: 'not_configured',
      schema: 'unknown',
      code: 'DATABASE_NOT_CONFIGURED'
    });
  }

  try {
    const sql = neon(connectionString);
    const rows = await sql`
      select
        current_timestamp as checked_at,
        to_regclass('public.tenants') is not null as tenants_ready,
        to_regclass('public.hotels') is not null as hotels_ready,
        to_regclass('public.app_users') is not null as users_ready,
        to_regclass('public.audit_events') is not null as audit_ready
    `;
    const schema = rows[0];
    const ready = Boolean(
      schema.tenants_ready &&
      schema.hotels_ready &&
      schema.users_ready &&
      schema.audit_ready
    );

    return res.status(ready ? 200 : 503).json({
      ok: ready,
      database: 'connected',
      schema: ready ? 'foundation_present' : 'migration_required',
      checkedAt: schema.checked_at
    });
  } catch (_error) {
    return res.status(503).json({
      ok: false,
      database: 'unavailable',
      schema: 'unknown',
      code: 'DATABASE_CONNECTION_FAILED'
    });
  }
};
