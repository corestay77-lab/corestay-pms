# Hasil bedah FO.EXE (deep analysis)

## 1. Temuan teknis
| Pemeriksaan | Hasil |
|---|---|
| Ukuran / tipe | 3.964.608 byte, PE 32-bit (bagian program hanya 67.584 byte) |
| Identitas (resource) | InternalName `hotel`, OriginalFilename `hotel.exe`, versi 4.0.9606; stub peluncur Visual FoxPro 9 (`VFP9R.DLL`, `VFP9T.DLL`, MSVCR71, lokasi runtime dibaca dari registry) |
| Isi aplikasi | 3.897.024 byte di belakang stub (overlay) |
| Entropi | Seksi `.text` stub 7,99 dan overlay 8,00 per byte: acak sempurna. Tidak ada blok 16-byte berulang, dan tidak terbaca sebagai zlib, raw deflate, bzip2 maupun LZMA |
| Teks terbaca | Nol kata menu, form, tabel atau nama berkas (`check`, `reserv`, `room`, `folio`, `.scx`, `.prg`, `.dbf`, `g_house`, `mst_bill` semuanya 0) |
| Library pendukung | `foxtools.fll`, `vfpcompression.fll` (kompresi/enkripsi), `xfrxlib.fll` (laporan ke PDF/gambar) |
| Berkas desain layar | Tidak ada: tidak ada SCX/FRX/MNX/PRG/VCX/PJX di kedua arsip. Dua FXP dan lima TBK hanya aset pendukung |
| Gambar | `hotelindo.jpg` hanya foto latar bertema laptop (stok), `FO.ICO`/`cashier.ico` ikon. Tidak ada tangkapan layar form |

**Kesimpulan:** kode program, daftar menu dan tata letak form di FO.EXE tersimpan terenkripsi/terproteksi. Isinya hanya bisa muncul saat aplikasi dijalankan di Windows dengan runtime VFP9 dan kunci yang sah. Dari arsip ini tidak ada cara membaca desain layarnya, dan saya tidak mencoba membongkar proteksinya.

## 2. Petunjuk tambahan yang berhasil dibaca
- `FOXUSER.DBF/FPT` (resource lingkungan pengembang) menyimpan jendela browse terakhir untuk `Mst_bill` dan `Dept`. Dari sana terlihat field folio yang belum saya pakai penuh: `Urutan` (urutan baris), `Last_line`, `Printed` (sudah dicetak), `Closed`, `T_bal`, `Old_trans`, `Hide_item`, `Rate_type`, `Post_mtd`, `Paydesc`; dan di `Dept`: `Hotel`, `Transfer`, `Location`, `Kd_supl`, `Hide`.
- Catatan nyata di data: reservasi "satu room pake extra bad", barang tertinggal, kwitansi "Biaya Akomodasi Di ...", artinya field memo (REMARKS) dipakai operator.
- Dari 184 tabel unik terlihat modul yang belum sepenuhnya ada di CoreStay: jurnal per jenis transaksi (`JURBL` pembelian, `JURJL` penjualan, `JURKK` kas keluar, `JURKM` kas masuk, `JURRBL` retur beli, `JURRT`, `JURSS`, `JURTRG` transfer gudang, `JURTT`), stok dan harga terpisah per departemen (`*_FB`, `*_HK`), retur pembelian (`RETB`), transfer gudang (`TRANGD`, `GDTRANS`), giro/cek (`NO_GIRO`, `D_BANK`), daftar waiter per outlet (`WAITERS_BH/KO/LL/SVC`), kartu RA (`RA_CARD`, registrasi tambahan) dan `CSDEPT` (charge departemen per tamu).

## 3. Peta relasi antar tabel (dihitung otomatis dari nama field bersama)
| Kunci | Jumlah tabel | Tabel yang memakai |
|---|---|---|
| REG_NO | 25 | ADVDEPO2, BQRESV, B_BQRESV, B_LNDRY, B_MNBAR, B_OTHERS, B_RSERV, B_SLONA, B_SLONA2, B_SLONA3, B_SLONA4, CLGT, CSDEPT, G_HOUSE, G_HOUSED, LNDRY, MNBAR, MST_BILL, OTHERS, RA_CARD, RSERV, SLONA, SLONA2, SLONA3, SLONA4 |
| REG_NO2 | 11 | G_HOUSED, LNDRY, MNBAR, MST_BILL, OTHERS, RA_CARD, RSERV, SLONA, SLONA2, SLONA3, SLONA4 |
| REG_NO3 | 8 | LNDRY, MNBAR, OTHERS, RSERV, SLONA, SLONA2, SLONA3, SLONA4 |
| REG_DUMMY | 3 | G_HOUSE, MST_BILL, RA_CARD |
| RESV_NO | 6 | AD*, ADVDEPO, G_HOUSE, RESDBAK, R_RESV, R_RESVD |
| ROOM_NO | 29 | BQRESV, B_LNDRY, B_MNBAR, B_OTHERS, B_RSERV, B_SLONA, B_SLONA2, B_SLONA3, B_SLONA4, CLGT, CSDEPT, EDTROOM, GUEST_D, G_HOUSE, LNDRY, MNBAR, MST_BILL, OTHERS, RA_CARD, RESDBAK, ROOM, ROOMBAK, RSERV, R_RESV, R_RESVD, SLONA, SLONA2, SLONA3, SLONA4 |
| NO_BILL | 2 | MST_BILL, RA_CARD |
| KD_CUST | 5 | ADJ_DP, AR, CLGT, CUSTOMER, KWITANSI |
| KD_CSHOP | 18 | B_LNDRY, B_MNBAR, B_OTHERS, B_RSERV, B_SLONA, B_SLONA2, B_SLONA3, B_SLONA4, CSHOP, CSHOP2, CSHOP3, CSHOP4, JNSDRUG, JNSLNDRY, JNSMNBAR, MST_BILL, RA_CARD, SERVICE |
| KD_WAITER | 23 | B_LNDRY, B_MNBAR, B_OTHERS, B_RSERV, B_SLONA, B_SLONA2, B_SLONA3, B_SLONA4, DRUGMAN, LNDRY, MNBAR, OTHERS, ROOMBOY, RSERV, SLONA, SLONA2, SLONA3, SLONA4, WAITERS, WAITERS_BH, WAITERS_KO, WAITERS_LL, WAITERS_SVC |
| KD_SUPL | 14 | ADJ_DH, AP, BELI, BELI_D, BELI_D_FB, BELI_D_HK, BELI_FB, BELI_HK, BLGD, BLGD_D, DEPT, RETB, RETB_D, SUPPLIER |
| KD_STOK | 33 | ADJ_DS, BELI_D, BELI_D_FB, BELI_D_HK, BLGD_D, FIFO, FIFO_FB, FIFO_HK, GDTRAN_D, GDTRAN_D_FB, GDTRAN_D_HK, HRG_DEPT, HRG_DEPT_FB, HRG_DEPT_HK, KRT_STDP, KRT_STDP_FB, KRT_STDP_HK, KRT_STOK, KRT_STOK_FB, KRT_STOK_HK, OPNAME, OPNAME_FB, OPNAME_HK, RETB_D, STOK, STOK2, STOK3, STOKDEPT, STOKDEPT_FB, STOKDEPT_HK, STOK_FB, STOK_HK, TRANS |
| KD_DEPT | 26 | BLGD, BLGD_D, DEPT1, DEPT1_FB, DEPT1_HK, GDTRANS, GDTRANS_FB, GDTRANS_HK, GDTRAN_D, GDTRAN_D_FB, GDTRAN_D_HK, HRG_DEPT, HRG_DEPT_FB, HRG_DEPT_HK, KRT_STDP, KRT_STDP_FB, KRT_STDP_HK, KRT_STOK, KRT_STOK_FB, KRT_STOK_HK, OPNAME, OPNAME_FB, OPNAME_HK, STOKDEPT, STOKDEPT_FB, STOKDEPT_HK |
| CODE_DEPT | 3 | DEPT, MST_BILL, RA_CARD |
| NO_BUKTI | 22 | ADJ_DH, ADJ_DP, ADJ_HUT, ADJ_PIUT, AP, AR, BAYAR, BAYARD2, BAYAR_D, BK_HUT, BK_PIUT, BUKTI, BUKTI_D, BYRHUT, BYRHUTD, BYRPIUT, BYRPIUTD, D_BANK, RETB, TERIMA, TERIMAD2, TERIMA_D |
| NO_TRANS | 43 | ACC_D, ADJ_DH, ADJ_DP, ADJ_DS, ADJ_STOK, AP, AR, BAYARD2, BAYAR_D, BELI, BELI_D, BELI_D_FB, BELI_D_HK, BELI_FB, BELI_HK, BLGD, BLGD_D, BUKTI_D, BYRHUTD, BYRPIUTD, CASH_D, CLGT, GDTRANS, GDTRANS_FB, GDTRANS_HK, GDTRAN_D, GDTRAN_D_FB, GDTRAN_D_HK, HRG_DEPT, HRG_DEPT_FB, HRG_DEPT_HK, KRT_STDP, KRT_STDP_FB, KRT_STDP_HK, KRT_STOK, KRT_STOK_FB, KRT_STOK_HK, KWITANSI, RETB, RETB_D, TERIMAD2, TERIMA_D, TRANS |
| NO_PERK | 34 | ACCOUNT, ACC_D, BAYAR, BELI, BELI_FB, BELI_HK, BLGD, BYRHUT, BYRPIUT, CASH, CASHBLDD, CASHBL_D, CASHJL_D, CASHKK_D, CASHKM_D, CASHRBLD, CASHRT_D, CASHSS_D, CASHTRGD, CASHTT_D, CASHUM_D, CASH_D, JURBLD_D, JURBL_D, JURJL_D, JURKK_D, JURKM_D, JURNAL_D, JURRBL_D, JURRT_D, JURSS_D, JURTRG_D, JURTT_D, TERIMA |
| JN_BUKTI | 13 | ACC_D, BAYAR, BAYAR_D, BK_HUT, BK_PIUT, BUKTI, BUKTI_D, BYRHUT, BYRPIUT, CASH_D, D_BANK, TERIMA, TERIMA_D |
| KD_BANK | 6 | BANK, BAYAR, BYRHUT, BYRPIUT, D_BANK, TERIMA |
| NO_GIRO | 4 | BAYAR_D, BUKTI_D, D_BANK, TERIMA_D |
| NO_REFF | 4 | BELI, BELI_FB, BELI_HK, BLGD |
| RATE_CODE | 3 | G_HOUSE, R_RATE2, R_RESVD |
| ROOM_TYPE | 4 | ROOM, ROOMBAK, R_RATE, R_RATE2 |
| COMPANY | 5 | CSDEPT, GUEST, G_HOUSE, R_RATE2, R_RESVD |

Pola kunci yang terbaca:
- Registrasi tamu memakai tiga nomor: `REG_NO` (tamu), `REG_NO2` (nomor bill) dan `REG_NO3` (dummy/pindah folio), lalu POS menautkan keduanya ke folio kamar (`ROOM_NO`).
- `REG_DUMMY` dipakai G_HOUSE, MST_BILL dan RA_CARD untuk memisahkan folio (split bill).
- Seluruh transaksi keuangan back office berkumpul pada `NO_BUKTI` / `NO_TRANS` / `JN_BUKTI` dan akun `NO_PERK`, lalu dijurnal oleh keluarga tabel JUR* dan CASH*.

## 4. Cara mendapatkan tampilan yang persis sama
1. Tangkapan layar form Registrasi/Check-in, Reservasi, Folio/Bill, Night Audit dan menu utama dari FO.EXE yang berjalan (urutan field, label, tombol).
2. Contoh cetakan registration card, bill, kwitansi dan laporan harian (PDF atau foto).
3. Kalau ada, berkas sumber aplikasi (folder berisi `.pjx`, `.scx`, `.frx`) dari pengembangnya.
