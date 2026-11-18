-- CoreStay: enforce same-hotel references in addition to row-level security.
-- Apply after 202611160001_shared_pms_core.sql on a new, empty staging database.
-- Existing single-column foreign keys are retained; these composite constraints
-- additionally prevent a record in hotel A from referencing a record in hotel B.

-- Candidate keys required by composite foreign keys.
alter table public.rooms add constraint uq_rooms_hotel_id_id unique (hotel_id, id);
alter table public.guests add constraint uq_guests_hotel_id_id unique (hotel_id, id);
alter table public.customers add constraint uq_customers_hotel_id_id unique (hotel_id, id);
alter table public.reservations add constraint uq_reservations_hotel_id_id unique (hotel_id, id);
alter table public.reservation_rooms add constraint uq_reservation_rooms_hotel_id_id unique (hotel_id, id);
alter table public.stays add constraint uq_stays_hotel_id_id unique (hotel_id, id);
alter table public.folios add constraint uq_folios_hotel_id_id unique (hotel_id, id);
alter table public.pos_checks add constraint uq_pos_checks_hotel_id_id unique (hotel_id, id);
alter table public.inventory_items add constraint uq_inventory_items_hotel_id_id unique (hotel_id, id);
alter table public.suppliers add constraint uq_suppliers_hotel_id_id unique (hotel_id, id);
alter table public.purchase_orders add constraint uq_purchase_orders_hotel_id_id unique (hotel_id, id);
alter table public.ap_invoices add constraint uq_ap_invoices_hotel_id_id unique (hotel_id, id);
alter table public.ar_invoices add constraint uq_ar_invoices_hotel_id_id unique (hotel_id, id);
alter table public.cash_accounts add constraint uq_cash_accounts_hotel_id_id unique (hotel_id, id);
alter table public.gl_accounts add constraint uq_gl_accounts_hotel_id_id unique (hotel_id, id);
alter table public.gl_journals add constraint uq_gl_journals_hotel_id_id unique (hotel_id, id);

-- Front Office: reservation, room assignment, stay and guest/folio links.
alter table public.reservations
  add constraint fk_reservations_guest_same_hotel
    foreign key (hotel_id, guest_id) references public.guests(hotel_id, id),
  add constraint fk_reservations_customer_same_hotel
    foreign key (hotel_id, customer_id) references public.customers(hotel_id, id);

alter table public.reservation_rooms
  add constraint fk_reservation_rooms_reservation_same_hotel
    foreign key (hotel_id, reservation_id) references public.reservations(hotel_id, id),
  add constraint fk_reservation_rooms_room_same_hotel
    foreign key (hotel_id, room_id) references public.rooms(hotel_id, id);

alter table public.stays
  add constraint fk_stays_reservation_same_hotel
    foreign key (hotel_id, reservation_id) references public.reservations(hotel_id, id),
  add constraint fk_stays_reservation_room_same_hotel
    foreign key (hotel_id, reservation_room_id) references public.reservation_rooms(hotel_id, id),
  add constraint fk_stays_guest_same_hotel
    foreign key (hotel_id, guest_id) references public.guests(hotel_id, id),
  add constraint fk_stays_room_same_hotel
    foreign key (hotel_id, room_id) references public.rooms(hotel_id, id);

alter table public.folios
  add constraint fk_folios_stay_same_hotel
    foreign key (hotel_id, stay_id) references public.stays(hotel_id, id),
  add constraint fk_folios_customer_same_hotel
    foreign key (hotel_id, customer_id) references public.customers(hotel_id, id);

alter table public.folio_lines
  add constraint fk_folio_lines_folio_same_hotel
    foreign key (hotel_id, folio_id) references public.folios(hotel_id, id);

alter table public.deposits
  add constraint fk_deposits_folio_same_hotel
    foreign key (hotel_id, folio_id) references public.folios(hotel_id, id);

-- POS and banquet: room-charge targets and linked checks stay within one property.
alter table public.pos_checks
  add constraint fk_pos_checks_stay_same_hotel
    foreign key (hotel_id, stay_id) references public.stays(hotel_id, id),
  add constraint fk_pos_checks_folio_same_hotel
    foreign key (hotel_id, folio_id) references public.folios(hotel_id, id);

alter table public.pos_check_lines
  add constraint fk_pos_check_lines_check_same_hotel
    foreign key (hotel_id, pos_check_id) references public.pos_checks(hotel_id, id);

alter table public.banquet_bookings
  add constraint fk_banquet_customer_same_hotel
    foreign key (hotel_id, customer_id) references public.customers(hotel_id, id);

-- Back Office: stock, supplier, purchasing, AP and AR relationships.
alter table public.stock_movements
  add constraint fk_stock_movements_item_same_hotel
    foreign key (hotel_id, item_id) references public.inventory_items(hotel_id, id);

alter table public.purchase_orders
  add constraint fk_purchase_orders_supplier_same_hotel
    foreign key (hotel_id, supplier_id) references public.suppliers(hotel_id, id);

alter table public.purchase_order_lines
  add constraint fk_po_lines_order_same_hotel
    foreign key (hotel_id, purchase_order_id) references public.purchase_orders(hotel_id, id),
  add constraint fk_po_lines_item_same_hotel
    foreign key (hotel_id, item_id) references public.inventory_items(hotel_id, id);

alter table public.ap_invoices
  add constraint fk_ap_invoices_supplier_same_hotel
    foreign key (hotel_id, supplier_id) references public.suppliers(hotel_id, id),
  add constraint fk_ap_invoices_po_same_hotel
    foreign key (hotel_id, purchase_order_id) references public.purchase_orders(hotel_id, id);

alter table public.ap_payments
  add constraint fk_ap_payments_invoice_same_hotel
    foreign key (hotel_id, ap_invoice_id) references public.ap_invoices(hotel_id, id);

alter table public.ar_invoices
  add constraint fk_ar_invoices_customer_same_hotel
    foreign key (hotel_id, customer_id) references public.customers(hotel_id, id),
  add constraint fk_ar_invoices_folio_same_hotel
    foreign key (hotel_id, source_folio_id) references public.folios(hotel_id, id);

alter table public.ar_receipts
  add constraint fk_ar_receipts_invoice_same_hotel
    foreign key (hotel_id, ar_invoice_id) references public.ar_invoices(hotel_id, id);

-- Cash and General Ledger: prevent cross-property account/journal references.
alter table public.cash_transactions
  add constraint fk_cash_transactions_account_same_hotel
    foreign key (hotel_id, cash_account_id) references public.cash_accounts(hotel_id, id);

alter table public.gl_accounts
  add constraint fk_gl_accounts_parent_same_hotel
    foreign key (hotel_id, parent_account_id) references public.gl_accounts(hotel_id, id);

alter table public.gl_journal_lines
  add constraint fk_gl_lines_journal_same_hotel
    foreign key (hotel_id, journal_id) references public.gl_journals(hotel_id, id),
  add constraint fk_gl_lines_account_same_hotel
    foreign key (hotel_id, account_id) references public.gl_accounts(hotel_id, id);
