/* CoreStay safe browser-data export.
   Read-only: never clears, rewrites, imports, or migrates localStorage. */
(() => {
  'use strict';

  const STORAGE_KEY = 'corestay-pms-v3';
  const BUTTON_ID = 'cs-backup-export';
  const STATUS_ID = 'cs-backup-status';

  function install() {
    const userArea = document.querySelector('#cs-shell .cs-user');
    if (!userArea || document.getElementById(BUTTON_ID)) return;

    const button = document.createElement('button');
    button.id = BUTTON_ID;
    button.type = 'button';
    button.className = 's';
    button.textContent = 'Backup data';
    button.setAttribute('aria-describedby', STATUS_ID);
    button.style.cssText = 'font-size:10px;padding:7px 9px;white-space:nowrap;';

    const status = document.createElement('span');
    status.id = STATUS_ID;
    status.setAttribute('role', 'status');
    status.setAttribute('aria-live', 'polite');
    status.style.cssText = 'position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0;';

    button.addEventListener('click', async () => {
      if (!window.confirm('Ekspor salinan data CoreStay dari browser ini? Data asli tidak akan diubah atau dihapus. Simpan file backup di tempat yang aman karena dapat berisi data tamu dan transaksi.')) return;

      button.disabled = true;
      status.textContent = 'Mempersiapkan backup…';
      try {
        const raw = window.localStorage.getItem(STORAGE_KEY);
        if (!raw) throw new Error('Data CoreStay tidak ditemukan pada browser ini.');

        const payload = JSON.parse(raw);
        if (!payload || typeof payload !== 'object' || Array.isArray(payload) ||
            typeof payload.bd !== 'string' || !Array.isArray(payload.rooms)) {
          throw new Error('Struktur data tidak sesuai. Backup dibatalkan agar file tidak menyesatkan.');
        }
        if (!window.crypto || !window.crypto.subtle || typeof TextEncoder === 'undefined') {
          throw new Error('Browser ini tidak mendukung checksum SHA-256. Gunakan browser modern melalui HTTPS.');
        }

        const payloadJson = JSON.stringify(payload);
        const bytes = new TextEncoder().encode(payloadJson);
        const digest = await window.crypto.subtle.digest('SHA-256', bytes);
        const checksum = Array.from(new Uint8Array(digest))
          .map(byte => byte.toString(16).padStart(2, '0')).join('');

        const backup = {
          format: 'corestay-localstorage-backup',
          formatVersion: 1,
          storageKey: STORAGE_KEY,
          exportedAt: new Date().toISOString(),
          checksum: { algorithm: 'SHA-256', scope: 'UTF-8 bytes of JSON.stringify(payload)', value: checksum },
          payload
        };

        const blob = new Blob([JSON.stringify(backup, null, 2)], { type: 'application/json;charset=utf-8' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        const stamp = new Date().toISOString().replace(/[:.]/g, '-');
        link.href = url;
        link.download = 'corestay-backup-' + stamp + '.json';
        link.style.display = 'none';
        document.body.appendChild(link);
        link.click();
        link.remove();
        window.setTimeout(() => URL.revokeObjectURL(url), 1000);

        status.textContent = 'Backup berhasil dibuat. SHA-256: ' + checksum;
        button.textContent = 'Backup siap';
      } catch (error) {
        status.textContent = error && error.message ? error.message : 'Backup gagal.';
        window.alert(status.textContent);
      } finally {
        button.disabled = false;
      }
    });

    userArea.appendChild(button);
    userArea.appendChild(status);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', install, { once: true });
  } else {
    install();
  }
  window.addEventListener('pageshow', install);
})();
