/* ============================================================
   DIGIY GUARD LITE — PIN Center SSO (no loop)
   - If no valid session -> redirect to PIN Center
   - Preserves return_to
   - Works on GitHub Pages
   ============================================================ */

(function () {
  const CFG = {
    // ✅ PIN Center URL (ton nouveau repo/page)
    PIN_CENTER_URL: "https://beauville.github.io/digiy-pin/pin.html",

    // ✅ Session globale (commune à tous les modules)
    SESSION_KEY: "DIGIY_SESSION_V1",

    // ✅ TTL session (8h)
    TTL_MS: 8 * 60 * 60 * 1000,

    // ✅ Pages à ne JAMAIS rediriger (anti-loop)
    // (utile si tu copies guard-lite dans le PIN repo aussi)
    NO_GUARD_PAGES: new Set(["pin.html", "offline.html"]),

    // ✅ Debug
    DEBUG: false
  };

  const log = (...a) => CFG.DEBUG && console.log("[DIGIY:GUARD]", ...a);

  function safeParse(x) { try { return JSON.parse(x); } catch { return null; } }

  function pageName() {
    const p = (location.pathname || "").split("/").pop() || "";
    return p || "index.html";
  }

  function isValidSession(s) {
    if (!s || typeof s !== "object") return false;
    const created = Number(s.created_at || 0);
    if (!created) return false;
    if ((Date.now() - created) > CFG.TTL_MS) return false;
    if (!s.ok) return false;
    return true;
  }

  const page = pageName();
  if (CFG.NO_GUARD_PAGES.has(page)) return;

  const sess = safeParse(localStorage.getItem(CFG.SESSION_KEY));
  if (isValidSession(sess)) return;

  // Redirect → PIN Center avec return_to + infos utiles
  const u = new URL(CFG.PIN_CENTER_URL);
  u.searchParams.set("return_to", location.href);

  // Optionnel: si l’URL a slug/module, on les passe au PIN Center
  const here = new URL(location.href);
  const slug = here.searchParams.get("slug");
  const mod = here.searchParams.get("module");
  if (slug) u.searchParams.set("slug", slug);
  if (mod) u.searchParams.set("module", mod);

  log("redirect -> pin center", u.toString());
  location.replace(u.toString());
})();
