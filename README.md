# CoreStay PMS v3 (FO → Back Office terhubung penuh)

PMS hotel berbasis web statis (tanpa build, tanpa dependensi). Mengadopsi alur & format data aplikasi HOTELINDO (Visual FoxPro: FO.EXE + BO.EXE) dari arsip `HOTELINDO.rar` dan `FO-DBFS.rar`.
Data tersimpan di browser (localStorage). Master (kamar, tarif, kode tarif, item POS, customer, kota, negara) diambil dari data asli di `seed.js`.

## Deploy
- **GitHub**: `git init && git add . && git commit -m "CoreStay PMS" && git push`
- **Vercel**: Import repo → Framework *Other* → tanpa build command → Deploy.
- Berkas: `index.html`, `app.js`, `seed.js`, `vercel.json`, `docs/KAMUS-DATA.md` (kamus 244+91 tabel, dibuat otomatis dari header DBF).
- Catatan privasi: `seed.js` memuat nama customer/perusahaan dari master asli. Data tamu (GUEST, 2.114 baris) sengaja TIDAK disertakan.

## Hasil analisa

### Isi arsip
| Arsip | Isi |
|---|---|
| HOTELINDO.rar | FO.EXE, BO.EXE, UTIL.EXE, CONFIG.EXE (VFP9 terkompilasi; teks menu tidak terbaca), DLL kunci kartu/PABX, `BO-DBFS` (49 tabel), `GL-DBFS` (42), `AR2019/2021/2022/2023` (11 tabel/tahun), `DBFHIST` (log A/D bulanan), file MEM (parameter) |
| FO-DBFS.rar | 91 tabel Front Office (periode 2019-05 s.d. 2024-12): 56 kamar, 2.114 tamu, 1.565 hari statistik, 511 baris bill, 47 reservasi/88 kamar |

Struktur menu EXE tidak bisa dibaca (terkompilasi), sehingga menu disusun dari tabel, field, nama berkas outlet (kolom `LOCATION` di DEPT), parameter MEM, dan pola data.

### Rumus tarif (terverifikasi dari data)
`Gross = Net x 1,21`; Service = 10% x Net; Pajak = 10% x (Net + Service). Contoh: 450.000 → net 371.901, service 37.190, pajak 40.909 (cocok dengan R_RATE). Spa memakai pajak lebih tinggi (x1,30). `RATE = KAMAR + BREAKFAST` (mis. 550.000 = 500.000 + 50.000). Night audit memposting dua baris: `RM` (kamar) dan `BF` (breakfast).

### Peta modul dan tabel
| Modul | Tabel asli | Fungsi |
|---|---|---|
| Reservasi | R_RESV (header, 45 fld), R_RESVD (per kamar, 71 fld), RESV_BY, RESDBAK | Kode `NNN-MMYYYY`; METODE, STATUS, CHECK_IN, CANCEL, NOSHOW, DEPOSIT; rate code, sebaran tarif (kamar, breakfast, meeting, coffee break, lunch, dinner, minibar, laundry, transport) |
| In-House | G_HOUSE (108 fld), G_HOUSED, GUEST (26), GUEST_D | Reg `NNNNN-MMYYYY`; RATE_TYPE, CHARGE_TO, ID_TYPE, PURPOSE, TIME_CO 12:00; split folio; riwayat menginap |
| Folio | MST_BILL (34), RA_CARD, CSDEPT | Baris bill: `RM` kamar, `BF` breakfast, `D` charge outlet, `E` Advance Deposit (kamar "A/D"), `R` deposit saat registrasi, `K` pembayaran (PAYM), `KH` refund; ROOM_NO khusus `DC` (bayar langsung) dan `CLGT` (city ledger); POST_MTD AUTO_NA / MANUAL |
| Advance Deposit | ADVDEPO (+DBFHIST AD*) | Log per RESV_NO: tanggal, jam, debet/kredit, "A/D dd/mm CASH", user, SHIFT |
| POS Outlet | SLONA(restoran) RSERV LNDRY MNBAR OTHERS SLONA2(cafe) SLONA3(banquet) SLONA4(spa) + B_* (detail baris) | Reg `NNNN-RT/RS/LD/MB/OT/LL/RB/SP+MMYY`; FOOD/BEV/MISC, SERV, TAX, POKOK, DISC, pembayaran (CASH, CC, DC, TRF_BANK, QRIS, EWALLET), void |
| Katalog harga | CSHOP, CSHOP2-4, JNSLNDRY(45), JNSMNBAR, JNSDRUG, SERVICE | KD_CSHOP, JNS_JUAL (1 food, 2 bev, 3-4 misc), BDOWN/SERV/TAX/HARGA, konsinyasi (I_HOTEL/I_SELLER) |
| Tarif | R_RATE (5 tipe, tarif 1-4), R_RATE2 (58 kode tarif kontrak, VALID1/2, credit limit) | Rack rate dan harga kontrak |
| Kamar | ROOM (56), ROOMBAK, EDTROOM (log OOO harian 3.570 baris) | Tipe 1 Superior, 2 Deluxe, 3 Executive, 4 Suite, 5 President Suite; bed SGL/DBL/TWN; lantai 1-5 |
| Housekeeping | ROOMBOY, LINEN, LOST, FOUND, STOK*_HK | Status kamar, barang tertinggal/ditemukan |
| Banquet | BQRESV, B_BQRESV, VENUE, LAYOUT, RESV/RESV_D | Grup, ruang (Ballroom, Meeting Room), layout, jadwal, REM_* per departemen |
| Statistik | DAYSAL1/2 (231+225 fld, 1.565 hari), STISTIK (218 fld), DAY_RS1/2 | Snapshot harian night audit: pendapatan per outlet/service/tax, pembayaran (CASH/CC/DC/TB/CL/RF/QRIS/EWALLET), okupansi per segmen |
| Master | DEPT (29), CUSTOMER (343), CITY (375), NATIONAL (188), WAITERS | Departemen dan lokasi file POS, customer OTA/perusahaan/instansi |
| Piutang | AR20xx: CUSTOMER, CLGT, KWITANSI, BYRPIUT/D, BK_PIUT, AR | CLGT → Kwitansi `NNNN/Lmmyy` → Bayar `NNNN/Hmmyy` → Terima Kas `NNNN/Mmmyy` → Buku Piutang |
| Back Office | BELI, TERIMA, STOK, FIFO, OPNAME, SUPPLIER, AP, BAYAR, BYRHUT, BANK, ADJ_* | Pembelian, hutang, stok per departemen (FB/HK), opname |
| GL | ACCOUNT, JURNAL*, CASH*, TBLREPT, `no_kira.MEM` | Laporan 001 Laba Rugi Hotel; peta akun |

### Peta akun (no_kira.MEM)
Kas 110.01 · Piutang usaha 130.01 · Advance/Titipan 400 · Hutang 320 · Persediaan 750 · Kamar 701 · F&B 702.01, Room Service 702.02, Banquet 702.03, Lounge 702.04, Minibar 702.05 · Laundry 707.01 · Lain 705.05 · Service 500.01 · Pajak 500.02. Akun `130.02 Guest Ledger` adalah tambahan CoreStay.

### Alur data FO → Back Office (terimplementasi)
```
Reservasi → Check-in (G_HOUSE+GUEST) → Folio (MST_BILL)
   Deposit/A-D ─────────────► Jurnal: Dr Kas/Bank, Cr 400 Advance ─┐
   POS Outlet ─ ke kamar ───► baris D di folio                    │
              ─ bayar langsung► Jurnal: Dr Kas/Bank, Cr Guest Ledger
              ─ item bertaut stok ► FIFO keluar → Jurnal HPP: Dr 600.01, Cr 750 Persediaan
Night Audit: post RM+BF → Jurnal pendapatan (Dr Guest Ledger; Cr 701/702.x/707/705, Service 500.01, Pajak 500.02)
             → potong amenities HK otomatis (stok per kamar/malam) → statistik harian → tanggal bisnis +1
Check-out:  alokasi A/D (Dr 400, Cr Guest Ledger) → sisa: Tunai/Kartu/QRIS/Transfer (Dr Kas/Bank)
            atau City Ledger (Dr 130.01) → CLGT → Kwitansi → Pembayaran → Bukti terima → Buku Piutang
Back Office: Pembelian kredit (Dr 750, Cr 320 Hutang) / tunai (Cr Kas/Bank) → lapis FIFO + kartu stok
             Bayar hutang (Dr 320, Cr Kas/Bank) · Opname (selisih ke 600.04) · Pengeluaran (Biaya Ops 600.03 / Lain 600.09 / Aktiva 180)
             Penerimaan lain (Cr 705.05) · Setor kas ke bank
Semua jurnal yang menyentuh Kas/Bank otomatis masuk Buku Kas/Bank → Laba Rugi Hotel & Neraca Saldo
Rekonsiliasi FO⇄BO: GL vs sub-ledger (Guest Ledger, A/D, Piutang, Persediaan, Hutang, 4 akun kas/bank)
```

### Kode yang disimpulkan (bukan dari teks program)
PAYM: 1 Cash, 2 C.Card, 3 City Ledger, 4 Transfer, 5 D.Card (6 QRIS, 7 E-Wallet menurut kolom DAYSAL). ST_ROOM: 1 VC, 4 hunian, 5 OOO, 3 VD (inferensi). Tarif 1-4 pada R_RATE belum bisa dipastikan maknanya (rack, weekend, korporat, dst).

## Pengujian (54 skenario lulus)
Rumus pajak (cocok R_RATE), double-booking, kamar OOO/terisi/VD, A/D dan refund, POS ke kamar dan bayar langsung, stok bertaut POS (HPP FIFO dua lapis harga), jual melebihi stok ditolak, amenities otomatis, pembelian tunai/kredit, bayar hutang (ganda ditolak), pengeluaran melebihi saldo ditolak, setor ke bank, opname, dua kali night audit, check-out City Ledger, kwitansi, pelunasan, walk-in, no-show, banquet bentrok, semua jurnal balance, 9 pos rekonsiliasi selisih nol, 15 menu tampil.
Pengujian lewat simulasi Node, belum di browser sungguhan.

## Belum tercakup
Integrasi key-card/PABX, cetak registrasi/bill/kwitansi, split folio, void/reprint POS, laporan per segmen (STISTIK 218 kolom), import langsung DBF, multi-user/database server, resep (satu item POS = banyak bahan), nomor akun bank selain 140.09 (140.10 dan 140.11 adalah asumsi), neraca format lengkap.


## Backup data browser

Gunakan tombol **Backup data** pada header untuk mengekspor salinan data browser dari storage key `corestay-pms-v3`. Ekspor meminta konfirmasi, memvalidasi struktur data, dan menyertakan checksum SHA-256 untuk pemeriksaan integritas. File JSON diunduh ke perangkat; data browser tidak diubah, dihapus, dikirim ke server, atau diimpor otomatis. Simpan file backup di tempat aman karena dapat berisi data tamu dan transaksi. Fitur ini hanya ekspor—belum ada fungsi restore/import.
