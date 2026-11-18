'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const migration = fs.readFileSync(
  path.join(__dirname, '../db/migrations/202611180001_tenant_safe_foreign_keys.sql'),
  'utf8'
);
const health = fs.readFileSync(path.join(__dirname, '../api/health.js'), 'utf8');

const readinessConstraints = [
  'fk_reservations_guest_same_hotel',
  'fk_pos_checks_folio_same_hotel',
  'fk_stock_movements_item_same_hotel',
  'fk_ap_invoices_supplier_same_hotel',
  'fk_gl_lines_journal_same_hotel',
  'fk_gl_lines_account_same_hotel'
];

test('every critical same-hotel constraint checked by health exists in migration', () => {
  for (const name of readinessConstraints) {
    assert.match(migration, new RegExp(name));
    assert.match(health, new RegExp(name));
  }
});

test('migration adds composite hotel-scoped foreign keys for FO, POS, BO and GL', () => {
  for (const name of [
    'fk_reservation_rooms_reservation_same_hotel',
    'fk_stays_room_same_hotel',
    'fk_folio_lines_folio_same_hotel',
    'fk_pos_check_lines_check_same_hotel',
    'fk_stock_movements_item_same_hotel',
    'fk_purchase_orders_supplier_same_hotel',
    'fk_ap_payments_invoice_same_hotel',
    'fk_ar_receipts_invoice_same_hotel',
    'fk_cash_transactions_account_same_hotel',
    'fk_gl_lines_account_same_hotel'
  ]) {
    assert.ok(migration.includes(name), `missing constraint: ${name}`);
  }
});
