# CoreStay PMS — Rancangan integrasi FO → BO → GL

## Sasaran penggunaan

Satu komputer utama dan beberapa perangkat lain dapat membuka hotel yang sama. Semua perangkat membaca dan menulis ke satu PostgreSQL terpusat. Browser tidak lagi menjadi sumber data utama; browser hanya menjadi antarmuka dan cache sementara.

## Pilihan arsitektur

Vercel menyediakan hosting dan Functions; database SQL pusat disediakan melalui integrasi Marketplace. Vercel Postgres dan Vercel KV versi lama sudah sunset. Untuk CoreStay dipilih Neon Postgres melalui Vercel Marketplace agar instalasi, koneksi environment, dan pengelolaan dilakukan dari Vercel Dashboard. Tidak menggunakan Supabase.


- **Database pusat:** Neon Postgres dari Vercel Marketplace, dibuat dan dihubungkan dari Vercel Dashboard. Tidak menggunakan Supabase.
- **Login dan hak akses:** CoreStay API pada Vercel Functions menggunakan tabel `app_users`, `user_sessions`, dan `hotel_memberships`; password wajib di-hash dan session cookie HttpOnly, Secure, SameSite.
- **Sinkronisasi:** semua perangkat membaca/menulis melalui API Vercel ke PostgreSQL pusat; layar memperbarui data setelah server mengonfirmasi dan melakukan refresh berkala.
- **Keamanan:** `DATABASE_URL` hanya tersedia pada Vercel Functions. API memeriksa session, `hotel_id`, role, dan izin; browser tidak pernah mengakses database langsung.
- **Hosting/backend:** Vercel menyajikan aplikasi dan menjalankan API melalui Vercel Functions.
- **Transaksi penting:** gunakan PostgreSQL RPC/transaction untuk posting, pembayaran, check-out, penerimaan barang, pembayaran supplier/customer, dan Night Audit.

## Menu dan keterkaitan modul

### Front Office
Reservation (R_RESV/R_RESVD) → Check-in/In-House (G_HOUSE/G_HOUSED/GUEST) → Guest Folio (MST_BILL) → Deposit (ADVDEPO/ADVDEPO2) → Payment/Checkout.

POS outlet meliputi SLONA, Room Service, Cafe, Minibar, Laundry, Others. Posting ke kamar membuat baris folio dengan referensi ke nomor check POS; pembayaran langsung masuk Cash & Bank. Banquet memakai BQRESV/B_BQRESV dan dapat ditagihkan ke customer atau folio sesuai aturan transaksi.

Housekeeping mengelola ROOM, EDTROOM, LOST, FOUND. Night Audit mem-posting room/breakfast, pendapatan outlet, deposit, pembayaran, statistik DAYSAL/STISTIK dan menghasilkan jurnal yang bisa ditelusuri.

### Back Office
Purchasing (BELI/BELI_D/RETB/RETB_D) → penerimaan barang → stock movement (STOK/STOK2/STOK3, FIFO, GDTRANS, OPNAME) → Account Payable (AP/BK_HUT/BYRHUT) → pembayaran (BAYAR) → Cash/Bank (TERIMA/BANK).

Account Receivable (CLGT/AR/BK_PIUT/BYRPIUT/KWITANSI) menerima tagihan City Ledger dari FO, membuat kuitansi, menerima pelunasan, lalu meneruskan jurnal ke GL.

### General Ledger
ACCOUNT/ACC_D menjadi Chart of Accounts. JURNAL/JURNAL_D menjadi jurnal header/detail. Kas masuk/keluar, piutang, hutang, persediaan, pendapatan FO, service dan pajak harus diposting melalui pemetaan akun yang dapat diatur, bukan akun yang ditanam permanen di kode.

## Aturan integrasi wajib

Semua query database dilakukan di server melalui Vercel Functions dengan parameterized SQL. Database credential tidak pernah dikirim ke browser. Gunakan transaksi SQL atomik untuk pembayaran, check-out, penerimaan barang, posting stok, dan Night Audit.

1. Setiap dokumen memiliki ID internal UUID dan nomor dokumen yang terlihat pengguna.
2. Setiap posting membawa `hotel_id`, tanggal bisnis, modul sumber, ID sumber, pengguna, dan waktu.
3. Posting harus idempotent: klik ulang atau retry jaringan tidak boleh menggandakan folio, stok, kas, atau jurnal.
4. Dokumen yang sudah posted tidak dihapus; koreksi dilakukan dengan void/reversal dan audit trail.
5. Jurnal harus balance (total debit = total kredit) sebelum status POSTED.
6. Stok hanya berubah melalui stock movements; saldo stok merupakan hasil pergerakan, bukan angka yang diedit bebas.
7. City Ledger FO membuat AR invoice yang terhubung ke folio sumber. Pelunasan AR mengurangi saldo invoice dan menambah kas/bank.
8. Pembelian/receiving membuat stock movements dan AP invoice; pembayaran AP mengurangi hutang dan kas/bank.
9. Night Audit hanya dapat diposting satu kali per hotel dan tanggal bisnis; pembatalan memerlukan reversal yang tercatat.
10. Perangkat yang kehilangan koneksi harus menampilkan status offline dan tidak boleh menyatakan transaksi tersimpan di server sebelum server mengonfirmasi.

## Menjaga data lama

- Tidak ada penghapusan atau reset pada `localStorage` key `corestay-pms-v2`.
- Migration SQL ini hanya menambah struktur di database cloud baru; tidak menyentuh data browser atau DBF sumber.
- Sebelum migrasi transaksi, aplikasi harus mengekspor snapshot JSON dari browser yang selama ini menyimpan data utama.
- Snapshot disimpan apa adanya ke `legacy_data_snapshots` dengan checksum; snapshot yang sama tidak dapat diimpor dua kali.
- Sesudah snapshot diverifikasi, data dipetakan per modul dengan laporan jumlah record dan saldo kontrol. Data lama tetap disimpan sampai pemilik menyetujui hasil rekonsiliasi.
- Jangan mengimpor data historis DBF ke tabel aktif tanpa pemilihan periode, deduplikasi, dan rekonsiliasi.

## Tahapan implementasi

### Tahap 1 — Infrastruktur Vercel
- Dari Vercel Dashboard project CoreStay, pasang integrasi Neon Postgres melalui Marketplace dan buat database baru khusus CoreStay.
- Hubungkan database ke project dan pastikan `DATABASE_URL` tersedia sebagai server-only Environment Variable.
- Jalankan migration `db/migrations/202611160001_shared_pms_core.sql` hanya pada database baru yang kosong setelah review.
- Bootstrap akun owner secara aman melalui API satu kali.

### Tahap 2 — Migrasi aman
- Tambahkan halaman export/backup dari localStorage.
- Arsipkan snapshot di cloud tanpa mengubah data lokal.
- Buat pemetaan bertahap: master → reservasi/stay/folio → POS/deposit/payment → inventory/purchasing/AP/AR → GL.
- Rekonsiliasi total folio, saldo deposit, stok, AP, AR, dan trial balance.

### Tahap 3 — Multi-device
- Login per pengguna dan role melalui Vercel Functions.
- Semua operasi membaca/menulis database pusat melalui API Vercel.
- Perangkat lain memperbarui tampilan melalui refresh berkala setelah transaksi terkonfirmasi.
- Uji dua perangkat bersamaan, konflik nomor dokumen, retry jaringan, dan audit trail.

### Tahap 4 — Cutover
- Jalankan paralel dengan mode baca/perbandingan.
- Setelah hasil sama dan pemilik menyetujui, jadikan database pusat sebagai sumber data utama.
- LocalStorage lama tetap dipertahankan sebagai backup sampai cutover dinyatakan selesai.

## Hal yang belum boleh dilakukan

- Jangan menghapus key localStorage, menjalankan reset data, atau mengganti seed master lama.
- Jangan menjalankan migration ini pada database produksi yang sudah berisi data tanpa backup dan review.
- Jangan menaruh `DATABASE_URL`, password database, session secret, atau kredensial admin di `app.js`, HTML, atau browser.
- Jangan menganggap deployment Vercel saja membuat data tersinkron antar-perangkat; database pusat harus dikonfigurasi.
