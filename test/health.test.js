'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const Module = require('node:module');

let queryResult = [{
  checked_at: '2026-11-18T00:00:00.000Z',
  tenants_ready: true,
  hotels_ready: true,
  users_ready: true,
  audit_ready: true,
    tenant_integrity_ready: true
}];
let queryError = null;

const originalLoad = Module._load;
Module._load = function (request, parent, isMain) {
  if (request === '@neondatabase/serverless') {
    return {
      neon: () => async () => {
        if (queryError) throw queryError;
        return queryResult;
      }
    };
  }
  return originalLoad.call(this, request, parent, isMain);
};

const handler = require('../api/health');
Module._load = originalLoad;

function responseRecorder() {
  return {
    headers: {},
    statusCode: 200,
    body: undefined,
    setHeader(name, value) { this.headers[name] = value; },
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; }
  };
}

test('rejects non-GET requests without touching the database', async () => {
  delete process.env.DATABASE_URL;
  const res = responseRecorder();
  await handler({ method: 'POST' }, res);

  assert.equal(res.statusCode, 405);
  assert.equal(res.headers.Allow, 'GET');
  assert.equal(res.body.code, 'METHOD_NOT_ALLOWED');
});

test('reports missing DATABASE_URL without exposing configuration', async () => {
  delete process.env.DATABASE_URL;
  const res = responseRecorder();
  await handler({ method: 'GET' }, res);

  assert.equal(res.statusCode, 503);
  assert.equal(res.body.code, 'DATABASE_NOT_CONFIGURED');
  assert.equal(res.body.database, 'not_configured');
});

test('reports readiness only when every foundation table exists', async () => {
  process.env.DATABASE_URL = 'postgres://test.invalid/corestay';
  queryError = null;
  queryResult = [{
    checked_at: '2026-11-18T00:00:00.000Z',
    tenants_ready: true,
    hotels_ready: true,
    users_ready: true,
    audit_ready: true,
    tenant_integrity_ready: true
  }];
  const res = responseRecorder();
  await handler({ method: 'GET' }, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.equal(res.body.schema, 'foundation_present');
  assert.equal(res.body.database, 'connected');
  assert.equal(res.headers['Cache-Control'], 'no-store, max-age=0');
});

test('reports migration_required when a foundation table is missing', async () => {
  queryResult = [{
    checked_at: '2026-11-18T00:00:00.000Z',
    tenants_ready: true,
    hotels_ready: true,
    users_ready: true,
    audit_ready: false,
    tenant_integrity_ready: true
  }];
  const res = responseRecorder();
  await handler({ method: 'GET' }, res);

  assert.equal(res.statusCode, 503);
  assert.equal(res.body.ok, false);
  assert.equal(res.body.schema, 'migration_required');
});

test('does not expose database errors', async () => {
  queryError = new Error('sensitive connection detail');
  const res = responseRecorder();
  await handler({ method: 'GET' }, res);

  assert.equal(res.statusCode, 503);
  assert.equal(res.body.code, 'DATABASE_CONNECTION_FAILED');
  assert.equal(JSON.stringify(res.body).includes('sensitive'), false);
  queryError = null;
});
