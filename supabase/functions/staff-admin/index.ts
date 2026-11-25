// Supabase Edge Function: staff-admin
// Pengganti Cloud Functions Firebase (yang butuh paket berbayar).
// Memakai Firebase service account lewat REST API Google, jadi Firebase
// cukup di paket gratis (Spark).
//
// Secret yang dibutuhkan (lihat PETUNJUK_SETUP.md):
//   FIREBASE_SERVICE_ACCOUNT_B64 = isi file service account JSON, di-base64
//
// Deploy:  supabase functions deploy staff-admin --no-verify-jwt

import {
  SignJWT,
  importPKCS8,
  jwtVerify,
  createRemoteJWKSet,
} from "npm:jose@5.9.6";

const DOMAIN = "@simtas.internal";

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-firebase-token",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

class HttpError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

function reply(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

// ---------- Service account ----------
function loadServiceAccount(): { project_id: string; client_email: string; private_key: string } {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_B64") ??
    Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "";
  if (!raw) {
    throw new HttpError(500, "Server belum dikonfigurasi (FIREBASE_SERVICE_ACCOUNT_B64 kosong).");
  }
  try {
    const text = raw.trim().startsWith("{") ? raw : atob(raw.trim());
    const sa = JSON.parse(text);
    if (!sa.project_id || !sa.client_email || !sa.private_key) throw new Error("incomplete");
    return sa;
  } catch (_) {
    throw new HttpError(500, "FIREBASE_SERVICE_ACCOUNT_B64 tidak valid.");
  }
}

let cachedToken: { value: string; exp: number } | null = null;

async function accessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.exp - 60 > now) return cachedToken.value;

  const sa = loadServiceAccount();
  const key = await importPKCS8(sa.private_key, "RS256");
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/cloud-platform",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(sa.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3300)
    .sign(key);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const json = await res.json();
  if (!res.ok || !json.access_token) {
    console.error("oauth gagal", json);
    throw new HttpError(500, "Gagal mendapat izin server ke Firebase.");
  }
  cachedToken = { value: json.access_token, exp: now + (json.expires_in ?? 3300) };
  return cachedToken.value;
}

async function google(url: string, method: string, body?: unknown) {
  const token = await accessToken();
  const res = await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json: any = {};
  try { json = text ? JSON.parse(text) : {}; } catch (_) { json = { raw: text }; }
  return { ok: res.ok, status: res.status, json };
}

// ---------- Identity Toolkit (akun login) ----------
function authBase(): string {
  return `https://identitytoolkit.googleapis.com/v1/projects/${loadServiceAccount().project_id}`;
}

async function authLookupByEmail(email: string) {
  const r = await google(`${authBase()}/accounts:lookup`, "POST", { email: [email] });
  if (!r.ok) return null;
  return (r.json.users ?? [])[0] ?? null;
}

async function authLookup(uid: string) {
  const r = await google(`${authBase()}/accounts:lookup`, "POST", { localId: [uid] });
  if (!r.ok) {
    console.error("accounts:lookup", r.status, r.json);
    throw new HttpError(500, `Gagal membaca akun login (${r.json?.error?.message ?? r.status}).`);
  }
  return (r.json.users ?? [])[0] ?? null;
}

async function authUpdate(uid: string, fields: Record<string, unknown>) {
  const r = await google(`${authBase()}/accounts:update`, "POST", { localId: uid, ...fields });
  if (!r.ok) {
    const code = String(r.json?.error?.message ?? r.status);
    console.error("accounts:update", r.status, r.json);
    if (code.includes("EMAIL_EXISTS")) throw new HttpError(409, "NIP ini sudah dipakai akun login lain.");
    if (code.includes("USER_NOT_FOUND")) {
      throw new HttpError(404, "Akun login tidak ditemukan di Authentication (UID tidak cocok dengan data profil).");
    }
    if (code.includes("WEAK_PASSWORD")) throw new HttpError(400, "Password minimal 6 karakter.");
    throw new HttpError(500, `Gagal mengubah akun login (${code}).`);
  }
}

// ---------- Firestore REST ----------
function fsBase(): string {
  return `https://firestore.googleapis.com/v1/projects/${loadServiceAccount().project_id}/databases/(default)/documents`;
}

function str(f: any, k: string): string {
  const v = f?.[k];
  if (!v) return "";
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.integerValue !== undefined) return String(v.integerValue);
  return "";
}

async function fsGet(path: string) {
  const r = await google(`${fsBase()}/${path}`, "GET");
  if (r.status === 404) return null;
  if (!r.ok) {
    console.error("firestore get", path, r.status, r.json);
    throw new HttpError(500, "Gagal membaca data dari Firestore.");
  }
  return r.json.fields ?? {};
}

async function fsPatch(path: string, fields: Record<string, unknown>, mask?: string[]) {
  const q = mask ? "?" + mask.map((m) => `updateMask.fieldPaths=${encodeURIComponent(m)}`).join("&") : "";
  const r = await google(`${fsBase()}/${path}${q}`, "PATCH", { fields });
  if (!r.ok) {
    console.error("firestore patch", path, r.status, r.json);
    throw new HttpError(500, "Gagal menyimpan data ke Firestore.");
  }
}

async function findUserByEmail(email: string): Promise<{ id: string; fields: any } | null> {
  const target = email.trim().toLowerCase();
  let pageToken = "";
  for (let page = 0; page < 10; page++) {
    const q = pageToken ? `?pageSize=200&pageToken=${encodeURIComponent(pageToken)}` : "?pageSize=200";
    const r = await google(`${fsBase()}/users${q}`, "GET");
    if (!r.ok) {
      console.error("firestore list users", r.status, r.json);
      throw new HttpError(500, "Gagal mencari data akun berdasarkan email.");
    }
    const docs = (r.json.documents ?? []) as any[];
    for (const d of docs) {
      const fields = d.fields ?? {};
      const kontak = emailPemulihan(fields).toLowerCase();
      const emailUtama = str(fields, "email").toLowerCase();
      if ((kontak && kontak === target) || (emailUtama && emailUtama === target)) {
        const id = String(d.name).split("/").pop()!;
        return { id, fields };
      }
    }
    pageToken = String(r.json.nextPageToken ?? "");
    if (!pageToken) break;
  }
  return null;
}

async function findUserByNip(nip: string): Promise<{ id: string; fields: any } | null> {
  const variants = [{ stringValue: nip }, { integerValue: String(Number(nip)) }];
  for (const value of variants) {
    const r = await google(`${fsBase()}:runQuery`, "POST", {
      structuredQuery: {
        from: [{ collectionId: "users" }],
        where: { fieldFilter: { field: { fieldPath: "nip" }, op: "EQUAL", value } },
        limit: 1,
      },
    });
    if (!r.ok) {
      console.error("firestore query", r.status, r.json);
      throw new HttpError(500, "Gagal mencari data staf.");
    }
    const hit = (r.json as any[]).find((x) => x.document);
    if (hit) {
      const id = String(hit.document.name).split("/").pop()!;
      return { id, fields: hit.document.fields ?? {} };
    }
  }
  return null;
}

// ---------- Verifikasi pemanggil ----------
const JWKS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"),
);

async function verifyToken(req: Request): Promise<{ uid: string; authTime: number }> {
  const token = req.headers.get("x-firebase-token");
  if (!token) throw new HttpError(401, "Silakan login terlebih dahulu.");
  const projectId = loadServiceAccount().project_id;
  try {
    const { payload } = await jwtVerify(token, JWKS, {
      issuer: `https://securetoken.google.com/${projectId}`,
      audience: projectId,
    });
    const uid = String(payload.sub ?? "");
    if (!uid) throw new Error("no sub");
    return { uid, authTime: Number(payload.auth_time ?? 0) };
  } catch (_) {
    throw new HttpError(401, "Sesi login tidak valid atau sudah habis. Silakan login ulang.");
  }
}

async function requireAdmin(req: Request): Promise<string> {
  const { uid } = await verifyToken(req);
  const me = await fsGet(`users/${uid}`);
  if (!me || str(me, "role").toLowerCase() !== "admin") {
    throw new HttpError(403, "Hanya admin yang boleh melakukan ini.");
  }
  return uid;
}

// Untuk perubahan sensitif pada akun sendiri: pengguna harus baru saja
// memasukkan kata sandi (maksimal 5 menit yang lalu).
async function requireFreshAdmin(req: Request): Promise<string> {
  const { uid, authTime } = await verifyToken(req);
  const me = await fsGet(`users/${uid}`);
  if (!me || str(me, "role").toLowerCase() !== "admin") {
    throw new HttpError(403, "Hanya admin yang boleh melakukan ini.");
  }
  const now = Math.floor(Date.now() / 1000);
  if (!authTime || now - authTime > 300) {
    throw new HttpError(401, "Konfirmasi kata sandi sudah kedaluwarsa. Silakan coba lagi.");
  }
  return uid;
}

function validNip(nip: unknown): nip is string {
  return typeof nip === "string" && /^[0-9]{6,30}$/.test(nip);
}

function normNama(v: unknown): string {
  return String(v ?? "").trim().toLowerCase().replace(/\s+/g, " ");
}

async function requireStaffTarget(uid: unknown) {
  if (typeof uid !== "string" || !uid.trim()) throw new HttpError(400, "UID staf tidak valid.");
  const doc = await fsGet(`users/${uid}`);
  if (doc && str(doc, "role").toLowerCase() === "admin") {
    throw new HttpError(403, "Akun admin tidak boleh diubah lewat fitur ini.");
  }
  return doc; // bisa null (data profil sudah dihapus)
}

// Ubah password. Sekaligus merapikan email login menjadi NIP@simtas.internal
// (untuk akun lama yang dulu mendaftar dengan email asli).
async function setPassword(uid: string, password: string, doc: any) {
  if (typeof password !== "string" || password.length < 6) {
    throw new HttpError(400, "Password minimal 6 karakter.");
  }
  const fields: Record<string, unknown> = {
    password,
    validSince: String(Math.floor(Date.now() / 1000)), // cabut sesi lama
  };
  const nip = str(doc, "nip");
  let emailBaru = "";
  if (validNip(nip)) {
    const wanted = `${nip}${DOMAIN}`;
    const acc = await authLookup(uid);
    if (!acc) throw new HttpError(404, "Akun login tidak ditemukan di Authentication (UID tidak cocok dengan data profil).");
    if (String(acc.email ?? "").toLowerCase() !== wanted) {
      fields.email = wanted;
      emailBaru = wanted;
    }
  }
  await authUpdate(uid, fields);
  if (emailBaru) {
    await fsPatch(`users/${uid}`, {
      email: { stringValue: emailBaru },
      updated_at: { timestampValue: new Date().toISOString() },
    }, ["email", "updated_at"]);
  }
}

// ---------- Lupa password via email ----------
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const LUPA_MAKS_PERCOBAAN = 5;          // per NIP per jendela
const LUPA_JENDELA_MS = 60 * 60 * 1000; // 1 jam
const LUPA_JEDA_MS = 60 * 1000;         // minimal 1 menit antar percobaan

// Email pemulihan = bagian sebelum "||" pada field email_kontak
// (format yang sama dengan StaffAdminApi.cleanEmailKontak di aplikasi).
function emailPemulihan(fields: any): string {
  const kontak = str(fields, "email_kontak").split("||")[0].split("\t")[0].trim();
  if (kontak) return kontak;
  const lama = str(fields, "email").split("||")[0].split("\t")[0].trim();
  return lama && !lama.toLowerCase().endsWith(DOMAIN) ? lama : "";
}

// Password lama yang tersimpan di email_kontak ("bersih||password||alias||...").
function passwordTersimpan(fields: any): string | null {
  const raw = str(fields, "email_kontak");
  const parts = raw.includes("||") ? raw.split("||") : raw.split("\t");
  if (parts.length >= 2 && parts[1].trim().length >= 6) return parts[1].trim();
  return null;
}

function maskEmail(email: string): string {
  const [user, domain] = email.split("@");
  if (!domain) return email;
  const awal = user.slice(0, Math.min(2, user.length));
  return `${awal}${"*".repeat(Math.max(user.length - awal.length, 3))}@${domain}`;
}

function escapeHtml(v: string): string {
  return v.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}

// Password acak 10 karakter (tanpa karakter yang mirip: 0/O, 1/l/I),
// dijamin mengandung huruf besar, huruf kecil, dan angka.
function buatPasswordAcak(panjang = 10): string {
  const besar = "ABCDEFGHJKLMNPQRSTUVWXYZ";
  const kecil = "abcdefghijkmnopqrstuvwxyz";
  const angka = "23456789";
  const semua = besar + kecil + angka;
  const pick = (set: string) => {
    const b = new Uint32Array(1);
    const batas = Math.floor(0x100000000 / set.length) * set.length;
    do crypto.getRandomValues(b); while (b[0] >= batas);
    return set[b[0] % set.length];
  };
  for (;;) {
    let out = "";
    for (let i = 0; i < panjang; i++) out += pick(semua);
    if (/[A-Z]/.test(out) && /[a-z]/.test(out) && /[0-9]/.test(out)) return out;
  }
}

// Pembatasan percobaan per NIP (disimpan di koleksi lupa_password_log; koleksi ini
// tidak punya aturan Firestore sehingga hanya bisa diakses server).
async function batasiPercobaan(nip: string) {
  const path = `lupa_password_log/${nip}`;
  const doc = await fsGet(path);
  const now = Date.now();
  let mulai = now;
  let jumlah = 0;
  let terakhir = 0;
  if (doc) {
    const m = Date.parse(doc.jendela_mulai?.timestampValue ?? "");
    const t = Date.parse(doc.terakhir?.timestampValue ?? "");
    const j = Number(doc.jumlah?.integerValue ?? 0);
    if (!Number.isNaN(m) && now - m < LUPA_JENDELA_MS) {
      mulai = m;
      jumlah = j;
    }
    if (!Number.isNaN(t)) terakhir = t;
  }
  if (terakhir && now - terakhir < LUPA_JEDA_MS) {
    const detik = Math.ceil((LUPA_JEDA_MS - (now - terakhir)) / 1000);
    throw new HttpError(429, `Terlalu cepat. Coba lagi dalam ${detik} detik.`);
  }
  if (jumlah >= LUPA_MAKS_PERCOBAAN) {
    const menit = Math.ceil((LUPA_JENDELA_MS - (now - mulai)) / 60000);
    throw new HttpError(429, `Terlalu banyak percobaan. Coba lagi dalam ${menit} menit.`);
  }
  await fsPatch(path, {
    jendela_mulai: { timestampValue: new Date(mulai).toISOString() },
    jumlah: { integerValue: String(jumlah + 1) },
    terakhir: { timestampValue: new Date(now).toISOString() },
  });
}

// Konfigurasi email: mendukung Brevo (gratis tanpa perlu domain sendiri)
// maupun Resend (jika sudah verifikasi domain).
function konfigurasiEmail() {
  const brevoKey = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
  const brevoFrom = (Deno.env.get("BREVO_FROM") ?? "").trim();
  if (brevoKey) {
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(brevoFrom)) {
      throw new HttpError(500, "BREVO_FROM belum diisi dengan alamat email pengirim.");
    }
    return { provider: "brevo" as const, apiKey: brevoKey, from: brevoFrom };
  }

  const apiKey = (Deno.env.get("RESEND_API_KEY") ?? "").trim();
  const from = (Deno.env.get("RESEND_FROM") ?? "SIMTAS Kominfo <noreply@domain-anda.id>").trim();
  if (!apiKey) {
    throw new HttpError(500, "Layanan email belum dikonfigurasi (BREVO_API_KEY / RESEND_API_KEY).");
  }
  if (!/^[^<>]+<[^<>@\s]+@[^<>@\s]+>$/.test(from)) {
    throw new HttpError(500, "RESEND_FROM belum diatur dengan alamat domain terverifikasi.");
  }
  return { provider: "resend" as const, apiKey, from };
}

async function kirimEmail(args: {
  provider: "brevo" | "resend";
  apiKey: string; from: string; to: string; subject: string; text: string; html: string;
}) {
  if (args.provider === "brevo") {
    const response = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: {
        "api-key": args.apiKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        sender: { name: "SIMTAS Kominfo", email: args.from },
        to: [{ email: args.to }],
        subject: args.subject,
        textContent: args.text,
        htmlContent: args.html,
      }),
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok) {
      console.error("Brevo gagal mengirim email", response.status, result);
      const detail = String(result?.message ?? result?.code ?? `HTTP ${response.status}`);
      throw new Error(detail);
    }
    return result;
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${args.apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: args.from, to: [args.to], subject: args.subject,
      text: args.text, html: args.html,
    }),
  });
  const result = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error("Resend gagal mengirim email", response.status, result);
    const detail = String(result?.message ?? result?.error ?? `HTTP ${response.status}`);
    throw new Error(detail);
  }
  return result;
}

async function rateLimitKey(raw: string): Promise<string> {
  const bytes = new TextEncoder().encode(raw.trim().toLowerCase());
  const hash = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(hash)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function isiEmailResetLink(nama: string, nip: string, resetLink: string) {
  const n = escapeHtml(nama || "Pengguna");
  const linkAman = escapeHtml(resetLink);
  const text =
    `Halo ${nama || "Pengguna"},\n\n` +
    `Anda menerima email ini karena ada permintaan untuk mengatur ulang password akun SIMTAS Anda` +
    (nip ? ` (NIP ${nip})` : "") +
    `.\n\n` +
    `Klik tautan berikut untuk mengatur ulang password Anda:\n${resetLink}\n\n` +
    `Jika Anda tidak meminta pengaturan ulang password, abaikan email ini.\n\n` +
    `SIMTAS - Dinas Komunikasi dan Informatika`;
  const html = `<!doctype html><html><body style="margin:0;background:#F8FAFC;font-family:Arial,Helvetica,sans-serif;color:#0D1B2A">
<div style="max-width:480px;margin:24px auto;background:#fff;border:1px solid #E2E8F0;border-radius:16px;overflow:hidden">
  <div style="background:#1E3A8A;color:#fff;padding:20px 24px">
    <div style="font-size:20px;font-weight:700;letter-spacing:1px">SIMTAS</div>
    <div style="font-size:12px;opacity:.85">Sistem Informasi Manajemen Tugas dan Staff</div>
  </div>
  <div style="padding:24px">
    <p style="margin:0 0 12px">Halo <b>${n}</b>,</p>
    <p style="margin:0 0 18px;font-size:14px;line-height:1.5">Anda menerima email ini karena ada permintaan untuk mengatur ulang password akun SIMTAS Anda${nip ? ` (NIP <b>${escapeHtml(nip)}</b>)` : ""}.</p>
    <div style="text-align:center;margin:24px 0">
      <a href="${linkAman}" style="display:inline-block;background:#2563EB;color:#fff;text-decoration:none;font-size:15px;font-weight:700;padding:13px 28px;border-radius:10px">Reset Password</a>
    </div>
    <p style="margin:0 0 10px;font-size:12.5px;color:#64748B;line-height:1.5">Jika tombol di atas tidak berfungsi, salin dan buka tautan berikut di browser Anda:</p>
    <p style="margin:0 0 16px;font-size:12px;word-break:break-all;color:#2563EB">${linkAman}</p>
    <p style="margin:0;font-size:12.5px;color:#64748B;line-height:1.5">Jika Anda tidak meminta pengaturan ulang password, abaikan email ini.</p>
  </div>
  <div style="padding:12px 24px;background:#F8FAFC;font-size:11.5px;color:#64748B;text-align:center">Dinas Komunikasi dan Informatika</div>
</div></body></html>`;
  return { text, html };
}

function isiEmailPasswordBaru(nama: string, nip: string, passwordBaru: string) {
  const n = escapeHtml(nama || "Pengguna");
  const text =
    `Halo ${nama || "Pengguna"},\n\n` +
    `Permintaan lupa kata sandi untuk akun SIMTAS (NIP ${nip}) telah diproses.\n\n` +
    `Kata sandi baru Anda: ${passwordBaru}\n\n` +
    `Silakan masuk memakai NIP dan kata sandi di atas, lalu segera ganti kata sandi ` +
    `melalui menu Profil > Ubah Kata Sandi.\n\n` +
    `Jika Anda tidak merasa meminta ini, segera hubungi Atasan/Admin.\n\n` +
    `SIMTAS - Dinas Komunikasi dan Informatika`;
  const html = `<!doctype html><html><body style="margin:0;background:#F8FAFC;font-family:Arial,Helvetica,sans-serif;color:#0D1B2A">
<div style="max-width:480px;margin:24px auto;background:#fff;border:1px solid #E2E8F0;border-radius:16px;overflow:hidden">
  <div style="background:#1E3A8A;color:#fff;padding:20px 24px">
    <div style="font-size:20px;font-weight:700;letter-spacing:1px">SIMTAS</div>
    <div style="font-size:12px;opacity:.85">Sistem Informasi Manajemen Tugas dan Staff</div>
  </div>
  <div style="padding:24px">
    <p style="margin:0 0 12px">Halo <b>${n}</b>,</p>
    <p style="margin:0 0 16px;font-size:14px;line-height:1.5">Permintaan lupa kata sandi untuk akun dengan NIP <b>${escapeHtml(nip)}</b> telah diproses. Berikut kata sandi baru Anda:</p>
    <div style="text-align:center;margin:20px 0">
      <span style="display:inline-block;background:#EFF6FF;border:1px dashed #2563EB;border-radius:10px;padding:14px 24px;font-size:24px;font-weight:700;letter-spacing:3px;font-family:Consolas,Menlo,monospace">${escapeHtml(passwordBaru)}</span>
    </div>
    <p style="margin:0 0 12px;font-size:14px;line-height:1.5">Masuk memakai <b>NIP</b> dan kata sandi di atas, lalu segera ganti kata sandi melalui menu <b>Profil &rarr; Ubah Kata Sandi</b>.</p>
    <p style="margin:0;font-size:12.5px;color:#64748B;line-height:1.5">Jika Anda tidak merasa meminta ini, segera hubungi Atasan/Admin.</p>
  </div>
  <div style="padding:12px 24px;background:#F8FAFC;font-size:11.5px;color:#64748B;text-align:center">Dinas Komunikasi dan Informatika</div>
</div></body></html>`;
  return { text, html };
}

// ---------- Aksi ----------
async function handle(action: string, data: any, req: Request) {
  switch (action) {
    // ===== Publik (belum login) =====
    case "check-nip": {
      if (!validNip(data.nip)) return { exists: false };
      const u = await findUserByNip(data.nip);
      if (!u) return { exists: false };
      const acc = await authLookup(u.id);
      const accEmail = String(acc?.email ?? "").toLowerCase();
      const nipPattern = new RegExp(`^${data.nip}(\\.[a-z0-9]+)?@simtas\\.internal$`);
      const legacy = !!acc && !nipPattern.test(accEmail);
      return { exists: true, legacy };
    }

    case "request-reset": {
      const nama = normNama(data.nama);
      if (!validNip(data.nip) || nama.length < 2) {
        throw new HttpError(400, "Isi NIP dan nama lengkap dengan benar.");
      }
      const tidakCocok = new HttpError(404, "NIP atau nama tidak cocok dengan data staf.");
      const u = await findUserByNip(data.nip);
      if (!u) throw tidakCocok;
      if (str(u.fields, "role").toLowerCase() !== "staff") {
        throw new HttpError(400, "Akun ini tidak dapat direset lewat fitur ini.");
      }
      if (normNama(str(u.fields, "nama")) !== nama) throw tidakCocok;

      const lama = await fsGet(`permintaan_reset/${u.id}`);
      if (lama && str(lama, "status") === "menunggu") return { ok: true, sudahAda: true };

      await fsPatch(`permintaan_reset/${u.id}`, {
        uid: { stringValue: u.id },
        nip: { stringValue: str(u.fields, "nip") },
        nama: { stringValue: str(u.fields, "nama") },
        status: { stringValue: "menunggu" },
        created_at: { timestampValue: new Date().toISOString() },
      });
      return { ok: true };
    }

    // Lupa password: input email terdaftar -> generate link reset password Firebase Auth -> kirim ke email.
    case "forgot-password": {
      const email = String(data.email ?? "").trim().toLowerCase();
      if (!EMAIL_RE.test(email) || email.length > 200) {
        throw new HttpError(400, "Format email tidak valid.");
      }

      const u = await findUserByEmail(email);
      if (!u) {
        throw new HttpError(404, "Email tidak terdaftar pada akun SIMTAS.");
      }

      const acc = await authLookup(u.id);
      if (!acc || !acc.email) {
        throw new HttpError(404, "Akun login tidak ditemukan. Hubungi Atasan/Admin.");
      }

      const emailConfig = konfigurasiEmail();
      const nipPengguna = str(u.fields, "nip");
      let authEmail = String(acc.email);
      // Akun login HARUS bernama "<NIP>@simtas.internal" (atau "<NIP>.<alias>@simtas.internal").
      // Sebelumnya hanya dicek endsWith(DOMAIN), sehingga akun Atasan yang NIP-nya pernah
      // diganti (email login lama masih "<NIPLAMA>@simtas.internal") TIDAK diperbaiki.
      // Akibatnya link reset mengubah sandi akun lama, sedangkan halaman login masuk lewat
      // akun "jembatan" <NIP>@simtas.internal yang sandinya tidak ikut berubah.
      const nipPattern = new RegExp(`^${nipPengguna}(\\.[a-z0-9]+)?@simtas\\.internal$`);
      if (validNip(nipPengguna) && !nipPattern.test(authEmail.toLowerCase())) {
        const emailBaru = `${nipPengguna}${DOMAIN}`;
        const holder = await authLookupByEmail(emailBaru);
        if (holder && holder.localId && holder.localId !== u.id) {
          const holderDoc = await fsGet(`users/${holder.localId}`);
          if (!holderDoc || str(holderDoc, "nip") === nipPengguna) {
            await google(`${authBase()}/accounts:delete`, "POST", { localId: holder.localId });
            if (holderDoc) {
              await google(`${fsBase()}/users/${holder.localId}`, "DELETE");
            }
          }
        }
        await authUpdate(u.id, { email: emailBaru });
        await fsPatch(`users/${u.id}`, {
          email: { stringValue: emailBaru },
          updated_at: { timestampValue: new Date().toISOString() },
        }, ["email", "updated_at"]);
        authEmail = emailBaru;
      }

      const oobRes = await google(`${authBase()}/accounts:sendOobCode`, "POST", {
        requestType: "PASSWORD_RESET",
        email: authEmail,
        returnOobLink: true,
      });
      if (!oobRes.ok || !oobRes.json?.oobLink) {
        console.error("accounts:sendOobCode gagal", oobRes.status, oobRes.json);
        throw new HttpError(502, "Gagal membuat link reset password Firebase.");
      }

      const resetLink = String(oobRes.json.oobLink);
      const namaPengguna = str(u.fields, "nama");
      const kontak = emailPemulihan(u.fields) || email;

      const isi = isiEmailResetLink(namaPengguna, nipPengguna, resetLink);
      try {
        await kirimEmail({
          provider: emailConfig.provider,
          apiKey: emailConfig.apiKey,
          from: emailConfig.from,
          to: kontak,
          subject: "Reset your password for SIMTAS",
          text: isi.text,
          html: isi.html,
        });
      } catch (e) {
        console.error("kirim email gagal", e);
        const detail = e instanceof Error ? e.message : "Terjadi kesalahan pengiriman email.";
        throw new HttpError(
          502,
          `Gagal mengirim email: ${detail}`,
        );
      }
      return { ok: true, email_masked: maskEmail(kontak) };
    }

    // ===== Khusus admin =====
    case "set-password": {
      await requireAdmin(req);
      const doc = await requireStaffTarget(data.uid);
      if (!doc) throw new HttpError(404, "Data staf tidak ditemukan.");
      await setPassword(data.uid, data.password, doc);
      return { ok: true };
    }

    case "set-nip": {
      await requireAdmin(req);
      await requireStaffTarget(data.uid);
      if (!validNip(data.nip)) throw new HttpError(400, "NIP harus angka, 6 sampai 30 digit.");
      const email = `${data.nip}${DOMAIN}`;
      await authUpdate(data.uid, { email, validSince: String(Math.floor(Date.now() / 1000)) });
      return { ok: true, email };
    }

    case "delete-auth": {
      const adminUid = await requireAdmin(req);
      if (data.uid === adminUid) throw new HttpError(400, "Tidak bisa menghapus akun sendiri.");
      await requireStaffTarget(data.uid);
      const acc = await authLookup(data.uid);
      if (!acc) return { ok: true };
      if (!String(acc.email ?? "").toLowerCase().endsWith(DOMAIN)) {
        throw new HttpError(400, "Bukan akun staf NIP, tidak dihapus.");
      }
      const r = await google(`${authBase()}/accounts:delete`, "POST", { localId: data.uid });
      if (!r.ok) {
        console.error("accounts:delete", r.status, r.json);
        throw new HttpError(500, `Gagal menghapus akun login (${r.json?.error?.message ?? r.status}).`);
      }
      return { ok: true };
    }

    // Admin mengubah akunnya sendiri: NIP (username login), kata sandi, dan profil.
    // Dipakai saat pergantian atasan. UID tetap sama, jadi tugas, riwayat, dan
    // laporan kendala tidak hilang.
    case "update-own-account": {
      const uid = await requireFreshAdmin(req);
      const nama = String(data.nama ?? "").trim();
      const jabatan = String(data.jabatan ?? "").trim();
      const noHp = String(data.no_hp ?? "").trim();
      const emailKontak = String(data.email_kontak ?? "").trim();
      if (nama.length < 1 || nama.length > 200) throw new HttpError(400, "Nama wajib diisi (maksimal 200 karakter).");
      if (jabatan.length < 1 || jabatan.length > 200) throw new HttpError(400, "Jabatan wajib diisi (maksimal 200 karakter).");
      if (noHp.length > 30) throw new HttpError(400, "No. HP maksimal 30 karakter.");
      if (emailKontak.length > 200) throw new HttpError(400, "Email terlalu panjang.");
      if (!validNip(data.nip)) throw new HttpError(400, "NIP harus angka, 6 sampai 30 digit.");
      const password = data.password == null || data.password === "" ? null : String(data.password);
      if (password !== null && password.length < 6) throw new HttpError(400, "Kata sandi baru minimal 6 karakter.");

      const lama = await fsGet(`users/${uid}`);
      const nipLama = str(lama, "nip");
      const nipBerubah = data.nip !== nipLama;

      if (nipBerubah) {
        const dipakai = await findUserByNip(data.nip);
        if (dipakai && dipakai.id !== uid) {
          throw new HttpError(409, "NIP baru ini sudah dipakai akun lain.");
        }
      }

      // 1. Akun login (Firebase Authentication)
      const email = `${data.nip}${DOMAIN}`;
      const akun: Record<string, unknown> = {};
      if (nipBerubah) akun.email = email;
      if (password !== null) akun.password = password;
      if (Object.keys(akun).length > 0) await authUpdate(uid, akun);

      // 2. Data profil (Firestore)
      const sekarang = new Date().toISOString();
      await fsPatch(`users/${uid}`, {
        nama: { stringValue: nama },
        nip: { stringValue: data.nip },
        email: { stringValue: email },
        jabatan: { stringValue: jabatan },
        no_hp: { stringValue: noHp },
        email_kontak: { stringValue: emailKontak },
        updated_at: { timestampValue: sekarang },
      }, ["nama", "nip", "email", "jabatan", "no_hp", "email_kontak", "updated_at"]);

      // 3. Catatan siapa pemegang jabatan sebelumnya (hanya jika NIP berganti)
      if (nipBerubah) {
        await fsPatch(`riwayat_jabatan/${uid}_${Date.now()}`, {
          uid: { stringValue: uid },
          nama_lama: { stringValue: str(lama, "nama") },
          nip_lama: { stringValue: nipLama },
          jabatan_lama: { stringValue: str(lama, "jabatan") },
          nama_baru: { stringValue: nama },
          nip_baru: { stringValue: data.nip },
          jabatan_baru: { stringValue: jabatan },
          tanggal: { timestampValue: sekarang },
        });
      }
      return { ok: true, email };
    }

    case "resolve-reset": {
      const adminUid = await requireAdmin(req);
      if (typeof data.uid !== "string" || !["reset", "tolak"].includes(data.action)) {
        throw new HttpError(400, "Permintaan tidak valid.");
      }
      const reqDoc = await fsGet(`permintaan_reset/${data.uid}`);
      if (!reqDoc || str(reqDoc, "status") !== "menunggu") {
        throw new HttpError(404, "Permintaan sudah diproses atau tidak ada.");
      }
      if (data.action === "reset") {
        const doc = await requireStaffTarget(data.uid);
        if (!doc || str(doc, "role").toLowerCase() !== "staff") {
          throw new HttpError(404, "Akun staf tidak ditemukan.");
        }
        const nip = str(doc, "nip");
        if (!validNip(nip)) throw new HttpError(400, "NIP staf tidak valid.");
        await setPassword(data.uid, nip, doc);
      }
      await fsPatch(`permintaan_reset/${data.uid}`, {
        status: { stringValue: data.action === "reset" ? "selesai" : "ditolak" },
        diproses_oleh: { stringValue: adminUid },
        diproses_at: { timestampValue: new Date().toISOString() },
      }, ["status", "diproses_oleh", "diproses_at"]);
      return { ok: true };
    }

    default:
      throw new HttpError(400, "Aksi tidak dikenal.");
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return reply({ error: "Metode tidak didukung." }, 405);
  try {
    const body = await req.json().catch(() => ({}));
    const { action, ...data } = body ?? {};
    const result = await handle(String(action ?? ""), data, req);
    return reply(result);
  } catch (e) {
    if (e instanceof HttpError) return reply({ error: e.message }, e.status);
    console.error("staff-admin error", e);
    return reply({ error: "Terjadi kesalahan di server." }, 500);
  }
});