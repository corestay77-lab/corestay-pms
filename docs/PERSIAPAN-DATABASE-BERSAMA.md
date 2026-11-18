# Persiapan database bersama CoreStay di Vercel

CoreStay memakai Vercel untuk hosting aplikasi dan API, dengan Neon Postgres yang dipasang melalui Vercel Marketplace sebagai database pusat. Tidak menggunakan Supabase. Skema mendukung tenant organisasi dan beberapa hotel di bawah tenant yang sama, dengan RLS untuk isolasi tenant/properti.

## Langkah pemilik project

1. Buka Vercel Dashboard → project `corestay-pms` → Storage/Marketplace.
2. Pilih integrasi **Neon Postgres** dan buat database baru khusus CoreStay PMS. Jangan hubungkan database lain yang sudah berisi data.
3. Pilih region terdekat yang tersedia dan hubungkan database ke project CoreStay.
4. Pastikan `DATABASE_URL` tersedia sebagai Environment Variable server-side di Vercel. Jangan gunakan prefix `NEXT_PUBLIC_` dan jangan kirim nilainya melalui chat.
5. Setelah API dan migration direview, jalankan `db/migrations/202611160001_shared_pms_core.sql` pada database baru yang kosong.
6. Buat akun owner melalui proses bootstrap satu kali yang disediakan API; jangan membuka pendaftaran admin publik.
7. Deploy ulang project setelah environment variable tersedia.

## Data yang tetap aman

Aplikasi saat ini memakai browser localStorage key `corestay-pms-v3` (sesuai deklarasi saat ini di `app.js`). Nilai ini tidak boleh dihapus atau ditimpa selama pembangunan. Sebelum cutover, aplikasi harus mengekspor snapshot JSON asli, menyimpan checksum, lalu memetakan data ke tabel baru dan merekonsiliasi jumlah record serta saldo kontrol.

Database pusat tidak mengambil alih transaksi sampai backup, import, dan pengujian multi-perangkat disetujui pemilik.

## Keamanan

Setelah migration diterapkan, buat runtime role terpisah (contoh nama `corestay_app`) yang bukan superuser, bukan pemilik tabel, dan tidak memiliki atribut `BYPASSRLS`. Berikan hak minimum dari koneksi admin/migration:

```sql
CREATE ROLE corestay_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
GRANT USAGE ON SCHEMA public TO corestay_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO corestay_app;
REVOKE UPDATE, DELETE ON public.audit_events FROM corestay_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO corestay_app;
```

Simpan password role dan pooled `DATABASE_URL` hanya di Environment Variables Vercel. Jangan menggunakan migration/owner role sebagai runtime role.

Setiap request terautentikasi harus membuka transaksi dan mengatur konteks server-side sebelum query tenant-scoped:

```sql
SELECT set_config('app.tenant_id', $1, true);
SELECT set_config('app.hotel_id', $2, true);
```

Nilai tenant dan hotel harus berasal dari membership yang telah diverifikasi di backend, bukan dipercaya dari payload browser.

- `DATABASE_URL` dan session secret hanya digunakan di Vercel Functions.
- Password di-hash di server; tidak disimpan sebagai teks biasa.
- Browser tidak berkomunikasi langsung dengan database.
- Setiap endpoint memeriksa session, hotel, role, dan izin modul.
- Jangan pernah mengirim password, database URL, atau secret melalui chat.

## Status

Belum ada database yang dibuat, belum ada SQL yang dijalankan, dan belum ada data lama yang dipindahkan. Draft migration menyiapkan tabel FO–BO–GL, identitas, tenant, properti, dan RLS; ini belum berarti database aktif atau aplikasi sudah tersambung. Produksi tetap memakai sistem yang ada sampai cutover disetujui.
