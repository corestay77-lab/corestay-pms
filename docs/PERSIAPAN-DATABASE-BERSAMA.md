# Persiapan database bersama CoreStay di Vercel

CoreStay memakai Vercel untuk hosting aplikasi dan API, dengan Neon Postgres yang dipasang melalui Vercel Marketplace sebagai database pusat. Tidak menggunakan Supabase.

## Langkah pemilik project

1. Buka Vercel Dashboard → project `corestay-pms` → Storage/Marketplace.
2. Pilih integrasi **Neon Postgres** dan buat database baru khusus CoreStay PMS. Jangan hubungkan database lain yang sudah berisi data.
3. Pilih region terdekat yang tersedia dan hubungkan database ke project CoreStay.
4. Pastikan `DATABASE_URL` tersedia sebagai Environment Variable server-side di Vercel. Jangan gunakan prefix `NEXT_PUBLIC_` dan jangan kirim nilainya melalui chat.
5. Setelah API dan migration direview, jalankan `db/migrations/202611160001_shared_pms_core.sql` pada database baru yang kosong.
6. Buat akun owner melalui proses bootstrap satu kali yang disediakan API; jangan membuka pendaftaran admin publik.
7. Deploy ulang project setelah environment variable tersedia.

## Data yang tetap aman

Aplikasi saat ini memakai browser localStorage key `corestay-pms-v2`. Nilai ini tidak boleh dihapus atau ditimpa selama pembangunan. Sebelum cutover, aplikasi harus mengekspor snapshot JSON asli, menyimpan checksum, lalu memetakan data ke tabel baru dan merekonsiliasi jumlah record serta saldo kontrol.

Database pusat tidak mengambil alih transaksi sampai backup, import, dan pengujian multi-perangkat disetujui pemilik.

## Keamanan

- `DATABASE_URL` dan session secret hanya digunakan di Vercel Functions.
- Password di-hash di server; tidak disimpan sebagai teks biasa.
- Browser tidak berkomunikasi langsung dengan database.
- Setiap endpoint memeriksa session, hotel, role, dan izin modul.
- Jangan pernah mengirim password, database URL, atau secret melalui chat.

## Status

Belum ada database yang dibuat, belum ada SQL yang dijalankan, dan belum ada data lama yang dipindahkan. Ini adalah rencana persiapan; produksi tetap memakai sistem yang ada sampai cutover disetujui.
