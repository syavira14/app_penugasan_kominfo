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

// ---------- Aksi ----------
async function handle(action: string, data: any, req: Request) {
  switch (action) {
    // ===== Publik (belum login) =====
    case "check-nip": {
      if (!validNip(data.nip)) return { exists: false };
      const u = await findUserByNip(data.nip);
      if (!u) return { exists: false };
      const acc = await authLookup(u.id);
      const legacy = !!acc && String(acc.email ?? "").toLowerCase() !== `${data.nip}${DOMAIN}`;
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
