# Persiapan database bersama CoreStay

Dokumen ini menjelaskan langkah pemilik project sebelum aplikasi dihubungkan ke database pusat.

1. Buat project Supabase baru khusus CoreStay PMS (jangan gunakan database lain yang sudah berisi data).
2. Simpan Project URL dan anon/public key. Jangan kirim service-role key melalui chat dan jangan memasukkannya ke file frontend.
3. Pastikan akun pemilik sudah dibuat di Supabase Auth.
4. Setelah migration schema disetujui, jalankan file SQL melalui Supabase SQL Editor.
5. Buat satu hotel dan membership untuk akun owner. Proses bootstrap owner harus dilakukan secara aman oleh pemilik project; jangan membuka pendaftaran admin publik.
6. Masukkan Project URL dan anon key ke Vercel Environment Variables.
7. Jangan aktifkan sinkronisasi tulis-menulis sebelum snapshot localStorage lama diekspor dan direkonsiliasi.

## Data yang tetap aman

Aplikasi yang sekarang memakai browser localStorage key `corestay-pms-v2`. Nilai ini tidak boleh dihapus. Migration cloud menyediakan tabel `legacy_data_snapshots` untuk menyimpan salinan JSON asli sebelum pemetaan ke tabel transaksi.

## Yang perlu disiapkan untuk tahap integrasi berikutnya

- Project URL Supabase.
- Anon/public key (boleh ditaruh di konfigurasi frontend; bukan service-role key).
- Email akun owner yang akan dipakai login.
- Persetujuan untuk menjalankan migration schema pada project Supabase baru yang kosong.

Jangan pernah mengirim password atau service-role key.
