/* DIGIY MEDIA UPLOADER (Universal) v1
   - Injecte un mini-uploader dans #digiyMediaSlot
   - Upload vers https://media.digiylyfe.com/upload/<module>/<slug>/<kind>
   - Récupère module/slug depuis URL (?module=driver&slug=bb-cheir) OU depuis le module sélectionné
   - Stocke la dernière URL dans localStorage pour réutilisation.
*/

(function(){
  const API_BASE = "https://media.digiylyfe.com/upload";
  const MEDIA_BASE = "https://media.digiylyfe.com/media";
  const SLOT_ID = "digiyMediaSlot";

  // IMPORTANT: Clé côté client = "clé publique" (obfuscation légère seulement)
  // => si tu veux plus sécu, on passera sur token court via orchestrator/queue plus tard.
  const PUBLIC_MEDIA_KEY = "CHANGE_ME_MEDIA_KEY_NOW";

  const $ = (s, r=document) => r.querySelector(s);

  function escapeHtml(s){
    return String(s||"").replace(/[&<>"']/g, m => ({
      "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"
    }[m]));
  }

  function qsGet(name){
    try { return new URLSearchParams(location.search).get(name); } catch { return null; }
  }

  function getSelectedModuleFromUI(){
    // Sur ta page inscription: .module-option.selected contient data-module
    const sel = document.querySelector(".module-option.selected");
    if(!sel) return null;
    return (sel.getAttribute("data-module") || "").trim().toLowerCase() || null;
  }

  function slugify(s){
    s = String(s||"").trim().toLowerCase();
    s = s.normalize("NFD").replace(/[\u0300-\u036f]/g,""); // accents
    s = s.replace(/[^a-z0-9]+/g,"-").replace(/^-+|-+$/g,"");
    return s || "";
  }

  function guessSlug(){
    // priorité querystring
    const qsSlug = qsGet("slug");
    if(qsSlug) return slugify(qsSlug);

    // sinon tente depuis businessName (quand rempli)
    const bn = $("#businessName");
    if(bn && bn.value.trim()) return slugify(bn.value);

    // sinon vide (on demandera)
    return "";
  }

  function ensureSlot(){
    const slot = document.getElementById(SLOT_ID);
    if(!slot) return null;
    slot.style.display = "block";
    return slot;
  }

  function buildUI(slot){
    slot.innerHTML = `
      <div style="
        margin:16px 0 0;
        padding:14px 14px;
        border-radius:16px;
        border:1px solid rgba(250,204,21,.28);
        background:rgba(15,23,42,.55);
      ">
        <div style="display:flex;align-items:center;justify-content:space-between;gap:10px;flex-wrap:wrap">
          <div style="font-weight:950;color:rgba(250,204,21,.95);letter-spacing:.02em">
            📸 Photo PRO (avatar / vitrine)
          </div>
          <div style="font-size:12px;color:rgba(229,231,235,.75);font-weight:800">
            Stockage DIGIY • URL stable
          </div>
        </div>

        <div style="margin-top:10px;font-size:12px;color:rgba(229,231,235,.8);font-weight:650;line-height:1.45">
          Choisis une image (PNG/JPG/WebP). On l’upload et on te donne l’URL DIGIY.
        </div>

        <div style="margin-top:12px;display:flex;gap:10px;flex-wrap:wrap;align-items:center">
          <select id="digiyMediaKind" style="
            padding:10px 12px;border-radius:12px;border:1px solid rgba(148,163,184,0.45);
            background:rgba(15,23,42,0.75);color:#e5e7eb;font-weight:800
          ">
            <option value="avatar">Avatar</option>
            <option value="cover">Couverture</option>
            <option value="gallery">Galerie</option>
          </select>

          <input id="digiyMediaSlug" placeholder="slug (ex: bb-cheir)" style="
            flex:1;min-width:180px;
            padding:10px 12px;border-radius:12px;border:1px solid rgba(148,163,184,0.45);
            background:rgba(15,23,42,0.75);color:#e5e7eb;font-weight:800
          " />

          <input id="digiyMediaFile" type="file" accept="image/*" style="
            flex:1;min-width:220px;
            padding:10px 12px;border-radius:12px;border:1px solid rgba(148,163,184,0.45);
            background:rgba(15,23,42,0.75);color:#e5e7eb;font-weight:800
          "/>

          <button id="digiyMediaBtn" type="button" style="
            padding:12px 14px;border-radius:999px;border:none;cursor:pointer;
            font-weight:950;letter-spacing:.05em;text-transform:uppercase;
            background:linear-gradient(135deg,#facc15,#eab308);
            color:#022c22;box-shadow:0 12px 28px rgba(250,204,21,0.35)
          ">Uploader</button>
        </div>

        <div id="digiyMediaMsg" style="margin-top:10px;font-size:12px;font-weight:800;color:rgba(229,231,235,.85)"></div>

        <div id="digiyMediaPreview" style="display:none;margin-top:12px;gap:12px;align-items:center">
          <img id="digiyMediaImg" alt="preview" style="
            width:72px;height:72px;border-radius:14px;object-fit:cover;
            border:1px solid rgba(250,204,21,.35)
          "/>
          <div style="flex:1;min-width:240px">
            <div style="font-size:12px;color:rgba(250,204,21,.95);font-weight:950">URL</div>
            <input id="digiyMediaUrl" readonly style="
              width:100%;
              padding:10px 12px;border-radius:12px;border:1px solid rgba(148,163,184,0.45);
              background:rgba(15,23,42,0.75);color:#e5e7eb;font-weight:800
            "/>
            <div style="margin-top:8px;display:flex;gap:10px;flex-wrap:wrap">
              <button id="digiyMediaCopy" type="button" style="
                padding:10px 12px;border-radius:12px;border:1px solid rgba(250,204,21,.35);
                background:rgba(250,204,21,.10);color:rgba(250,204,21,.95);
                font-weight:950;cursor:pointer
              ">Copier</button>
              <a id="digiyMediaOpen" target="_blank" rel="noreferrer" style="
                padding:10px 12px;border-radius:12px;border:1px solid rgba(148,163,184,0.35);
                background:rgba(15,23,42,.55);color:#e5e7eb;font-weight:900;
                text-decoration:none
              ">Ouvrir</a>
            </div>
          </div>
        </div>
      </div>
    `;

    // Prefill slug
    const slugInput = $("#digiyMediaSlug");
    slugInput.value = guessSlug();

    // Restore last url if any
    const last = localStorage.getItem("DIGIY_MEDIA_LAST_URL");
    if(last) showResult(last);
  }

  function setMsg(txt, ok=true){
    const el = $("#digiyMediaMsg");
    if(!el) return;
    el.textContent = txt || "";
    el.style.color = ok ? "rgba(229,231,235,.85)" : "rgba(249,115,115,.95)";
  }

  function showResult(url){
    const prev = $("#digiyMediaPreview");
    const img  = $("#digiyMediaImg");
    const inp  = $("#digiyMediaUrl");
    const open = $("#digiyMediaOpen");

    if(!prev || !img || !inp || !open) return;

    prev.style.display = "flex";
    img.src = url;
    inp.value = url;
    open.href = url;

    try { localStorage.setItem("DIGIY_MEDIA_LAST_URL", url); } catch {}
  }

  async function upload(){
    const file = $("#digiyMediaFile")?.files?.[0];
    const kind = ($("#digiyMediaKind")?.value || "avatar").trim();
    let slug = ($("#digiyMediaSlug")?.value || "").trim();

    if(!slug){
      slug = guessSlug();
      if($("#digiyMediaSlug")) $("#digiyMediaSlug").value = slug;
    }

    if(!file){
      setMsg("⚠️ Choisis une image d'abord.", false);
      return;
    }
    if(!slug){
      setMsg("⚠️ Mets un slug (ex: bb-cheir) ou remplis le nom.", false);
      return;
    }

    // module: priorité querystring -> sinon module sélectionné -> fallback driver
    let module = (qsGet("module") || "").trim().toLowerCase();
    if(!module) module = getSelectedModuleFromUI() || "driver";

    const url = `${API_BASE}/${encodeURIComponent(module)}/${encodeURIComponent(slug)}/${encodeURIComponent(kind)}`;

    const btn = $("#digiyMediaBtn");
    if(btn){ btn.disabled = true; btn.textContent = "⏳ Upload..."; }

    try{
      setMsg("📤 Upload en cours…");
      const fd = new FormData();
      fd.append("file", file);

      const res = await fetch(url, {
        method: "POST",
        headers: { "X-DIGIY-KEY": PUBLIC_MEDIA_KEY },
        body: fd
      });

      const text = await res.text();
      let json = null;
      try { json = JSON.parse(text); } catch {}

      if(!res.ok){
        setMsg(`❌ Upload KO (${res.status}) : ${text.slice(0,200)}`, false);
        return;
      }

      const outUrl = json?.url || "";
      if(!outUrl){
        setMsg("❌ Upload OK mais URL manquante.", false);
        return;
      }

      setMsg("✅ Upload OK. URL prête.");
      showResult(outUrl);

    } catch(err){
      setMsg("❌ Erreur réseau : " + (err?.message || "inconnue"), false);
    } finally{
      if(btn){ btn.disabled = false; btn.textContent = "Uploader"; }
    }
  }

  function hook(){
    const btn = $("#digiyMediaBtn");
    const copy = $("#digiyMediaCopy");
    if(btn) btn.addEventListener("click", upload);
    if(copy) copy.addEventListener("click", async () => {
      const v = $("#digiyMediaUrl")?.value || "";
      if(!v) return;
      try { await navigator.clipboard.writeText(v); setMsg("✅ URL copiée."); }
      catch { setMsg("⚠️ Copie impossible (navigateur).", false); }
    });

    // Auto update slug quand businessName change
    const bn = $("#businessName");
    if(bn){
      bn.addEventListener("blur", () => {
        const s = slugify(bn.value);
        const slugInput = $("#digiyMediaSlug");
        if(slugInput && !slugInput.value.trim() && s) slugInput.value = s;
      });
    }
  }

  function init(){
    const slot = ensureSlot();
    if(!slot) return;
    buildUI(slot);
    hook();
  }

  // Lance après load
  if(document.readyState === "complete" || document.readyState === "interactive"){
    setTimeout(init, 60);
  } else {
    window.addEventListener("DOMContentLoaded", () => setTimeout(init, 60));
  }
})();
