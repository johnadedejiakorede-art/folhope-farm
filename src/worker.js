const json = (data, status = 200, extra = {}) => new Response(JSON.stringify(data), {
  status, headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", ...extra }
});
const cookie = (request, name) => (request.headers.get("Cookie") || "").split(";").map(x => x.trim()).find(x => x.startsWith(`${name}=`))?.slice(name.length + 1) || "";
const noStore = { "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff", "Referrer-Policy": "strict-origin-when-cross-origin", "X-Frame-Options": "DENY", "Permissions-Policy": "camera=(), microphone=(), geolocation=()", "Content-Security-Policy": "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'self'" };

const APP_HTML = __APP_HTML__;
export default {
 async fetch(request, env) {
  const url = new URL(request.url);
  if (url.pathname === "/api/health") return json({ status: "ok", app: "fol-hope-farm", backend: "supabase-postgres" }, 200, noStore);
  if (url.pathname === "/api/action" && request.method === "POST") {
   if (request.headers.get("Origin") && request.headers.get("Origin") !== url.origin) return json({ error: "Cross-origin request blocked." }, 403, noStore);
   if (request.headers.get("Sec-Fetch-Site") === "cross-site") return json({ error: "Cross-site request blocked." }, 403, noStore);
   const size = Number(request.headers.get("Content-Length") || 0);
   if (size > 30000) return json({ error: "Request too large." }, 413, noStore);
   let body;
   try { const raw = await request.text(); if (raw.length>30000) return json({error:'Request too large.'},413,noStore); body = JSON.parse(raw); if (!body || typeof body !== 'object') throw new Error('Invalid'); } catch { return json({ error: "Enter a valid request." }, 400, noStore); }
   const action = typeof body.action === "string" ? body.action : "";
   const publicAction = action === "login";
   const token = publicAction ? "" : cookie(request, "fh_session");
   if (!publicAction && !token) return json({ error: "Session expired. Sign in again." }, 401, noStore);
   try {
    const response = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/farm_api`, {
     method: "POST", headers: { "Content-Type": "application/json", apikey: env.SUPABASE_KEY, Authorization: `Bearer ${env.SUPABASE_KEY}` },
     body: JSON.stringify({ action, payload: body.payload && typeof body.payload === "object" ? body.payload : {}, token })
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok || result.error) {
     const message = String(result.message || result.msg || result.error || "Request failed.");
     const status = /session expired|invalid session/i.test(message) ? 401 : /forbidden|permission denied/i.test(message) ? 403 : /invalid email or password/i.test(message) ? 401 : /too many attempts/i.test(message) ? 429 : /already exists|duplicate key/i.test(message) ? 409 : 400;
     return json({ error: message.replace(/^.*?ERROR:\s*/i, "").replace(/\s+CONTEXT:[\s\S]*$/i, "").slice(0, 220) }, status, noStore);
    }
    if (publicAction && result.token) {
     return json({ data: result.user }, 200, { ...noStore, "Set-Cookie": `fh_session=${result.token}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=28800` });
    }
    if (action === "logout") return json({ data: result }, 200, { ...noStore, "Set-Cookie": "fh_session=; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=0" });
    return json({ data: result }, 200, noStore);
   } catch (error) {
    console.error(JSON.stringify({ event: "farm_api_error", action, message: String(error).slice(0, 180) }));
    return json({ error: "The farm database could not be reached. Try again." }, 502, noStore);
   }
  }
  if (url.pathname.startsWith("/api/")) return json({ error: "Not found." }, 404, noStore);
  if (request.method !== "GET" && request.method !== "HEAD") return json({ error: "Method not allowed." }, 405, noStore);
  if (url.pathname === '/app.js' || url.pathname === '/style.css') return new Response(request.method==='HEAD'?null:(url.pathname==='/app.js'?APP_JS:APP_CSS), {headers:{...noStore,'Content-Type':url.pathname==='/app.js'?'application/javascript; charset=utf-8':'text/css; charset=utf-8'}});
  return new Response(request.method === "HEAD" ? null : APP_HTML, { status: 200, headers: { ...noStore, "Content-Type": "text/html; charset=utf-8" } });
 }
};
