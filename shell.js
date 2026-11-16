/* CoreStay PMS — Dark Professional horizontal mega menu shell.
   Presentation layer only: existing app.js, seed.js and localStorage schema remain untouched. */
(() => {
  const groups = [
    {label:'OVERVIEW', items:[['dash','Dashboard']]},
    {label:'FRONT OFFICE', items:[['rs','Reservations'],['ih','Check-in & In-House'],['pos','POS Outlet'],['na','Night Audit & Advance Deposit'],['gs','Guest & Rate Master']]},
    {label:'ROOMS & EVENTS', items:[['hk','Housekeeping'],['bq','Banquet & Meeting']]},
    {label:'BACK OFFICE', items:[['ar','Account Receivable / City Ledger'],['kas','Cash & Bank'],['stok','Purchasing & Inventory']]},
    {label:'FINANCE & CONTROL', items:[['gl','General Ledger'],['rp','Reports'],['mst','Master & Parameters']]}
  ];
  const $ = (s, root=document) => root.querySelector(s);
  const $$ = (s, root=document) => [...root.querySelectorAll(s)];
  const esc = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function install(){
    const oldNav=$('#nav'), app=$('#app');
    if(!oldNav || !app || !window.go) return;
    oldNav.setAttribute('aria-hidden','true');
    oldNav.style.display='none';
    let shell=$('#cs-shell');
    if(!shell){
      shell=document.createElement('header'); shell.id='cs-shell';
      shell.innerHTML='<div class="cs-brand"><div class="cs-mark">C</div><div><strong>CORESTAY</strong><small>PROPERTY MANAGEMENT SYSTEM</small></div></div><div class="cs-hotel"><span class="cs-live"></span><span id="cs-hotel-name">HOTEL OPERATIONS</span><small> | BUSINESS DATE <b id="cs-date"></b></small></div><div class="cs-user"><span class="cs-bell">♧</span><span class="cs-avatar">HM</span><span>Hotel Manager</span></div><nav class="cs-nav" aria-label="Main navigation"></nav><div class="cs-menu-panel" hidden></div>';
      document.body.insertBefore(shell, app);
      const nav=$('.cs-nav',shell), panel=$('.cs-menu-panel',shell);
      nav.innerHTML=groups.map((g,i)=>'<button class="cs-nav-btn" data-group="'+i+'">'+esc(g.label)+' <span>⌄</span></button>').join('');
      function openGroup(i,anchor){
        const g=groups[i]; panel.innerHTML='<div class="cs-menu-head"><div><small>CORESTAY MODULES</small><h3>'+esc(g.label)+'</h3></div><span>Choose a workspace</span></div><div class="cs-menu-grid">'+g.items.map(([key,label])=>'<button class="cs-menu-item" data-page="'+key+'"><span class="cs-menu-dot"></span><span>'+esc(label)+'</span><b>→</b></button>').join('')+'</div>';
        panel.hidden=false; $$('.cs-nav-btn',nav).forEach(b=>b.classList.toggle('active',+b.dataset.group===i));
      }
      nav.addEventListener('click',e=>{const b=e.target.closest('[data-group]');if(b)openGroup(+b.dataset.group,b)});
      panel.addEventListener('click',e=>{const b=e.target.closest('[data-page]');if(b){panel.hidden=true;window.go(b.dataset.page)}});
      document.addEventListener('click',e=>{if(!shell.contains(e.target)){panel.hidden=true;$$('.cs-nav-btn',nav).forEach(b=>b.classList.remove('active'))}});
      document.addEventListener('keydown',e=>{if(e.key==='Escape'){panel.hidden=true;$$('.cs-nav-btn',nav).forEach(b=>b.classList.remove('active'))}});
    }
    const date=$('#cs-date'); if(date) date.textContent=(window.D?.bd || new Date().toISOString().slice(0,10));
    // Remove the destructive reset control from the visible UI; no data operation is performed.
    $$('button',app).filter(b=>/reset data/i.test(b.textContent||'')).forEach(b=>b.remove());
    const title=app.querySelector('h2');
    if(title) document.title='CoreStay PMS | '+title.textContent.trim();
  }
  const originalGo=window.go;
  if(typeof originalGo==='function'){
    window.go=function(page){originalGo(page);install();};
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});else install();
  window.addEventListener('pageshow',install);
})();
