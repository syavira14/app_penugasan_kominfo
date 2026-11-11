// Supabase Edge Function: get-assignment-file-url
//
// Mengembalikan signed URL (1 jam) untuk file di bucket "file-tugas".
// Jenis (kind): hasil | riwayat | revisi | solusi | kendala | penghentian
//
// Cara kerja keamanan:
//  1. Token Firebase diverifikasi (tanda tangan, penerbit, audience).
//  2. Data Firestore dibaca DENGAN TOKEN PENGGUNA lewat REST API, sehingga
//     Firestore Security Rules yang menentukan boleh/tidaknya pengguna melihat
//     penugasan/laporan tersebut (Staff hanya miliknya, Admin semuanya).
//  3. Untuk path yang bisa ditulis Staff (hasil, riwayat, bukti kendala),
//     folder file harus sama dengan uid PENGUNGGAH yang tercatat saat itu
//     (staff_id / pelapor_id yang tidak dapat diubah). Dengan begitu file lama
//     di folder uid lama tetap bisa dibuka, tetapi Staff tidak bisa mengarahkan
//     path ke file milik orang lain.
//  4. Path yang hanya bisa ditulis Admin (revisi, solusi, penghentian)
//     dipercaya sebagaimana tercatat di Firestore.
//
// Secret yang diperlukan (Edge Functions -> Secrets):
//   FIREBASE_PROJECT_ID  = project id Firebase (lihat firebase_options.dart)
// SUPABASE_URL dan SUPABASE_SERVICE_ROLE_KEY sudah tersedia otomatis.
// Pastikan "Verify JWT" pada function ini DIMATIKAN (token Firebase, bukan Supabase).

import { createClient } from "npm:@supabase/supabase-js@2";
import { createRemoteJWKSet, jwtVerify } from "npm:jose@5";

const BUCKET = "file-tugas";
const PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const JWKS = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);
const FS =
  `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

class HttpError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

const str = (v: unknown) => (v == null ? "" : String(v)).trim();

// ---------- Firestore REST ----------
// deno-lint-ignore no-explicit-any
function fv(v: any): any {
  if (!v) return null;
  if ("stringValue" in v) return v.stringValue;
  if ("integerValue" in v) return Number(v.integerValue);
  if ("doubleValue" in v) return v.doubleValue;
  if ("booleanValue" in v) return v.booleanValue;
  if ("timestampValue" in v) return v.timestampValue;
  if ("mapValue" in v) return fields(v.mapValue.fields ?? {});
  if ("arrayValue" in v) return (v.arrayValue.values ?? []).map(fv);
  return null;
}
// deno-lint-ignore no-explicit-any
function fields(f: Record<string, any>) {
  // deno-lint-ignore no-explicit-any
  const out: Record<string, any> = {};
  for (const k of Object.keys(f)) out[k] = fv(f[k]);
  return out;
}

// deno-lint-ignore no-explicit-any
type Doc = Record<string, any>;

async function fsFetch(token: string, url: string) {
  const r = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (r.status === 404) return null;
  if (r.status === 401 || r.status === 403) {
    throw new HttpError(
      403,
      "Akses ke data ditolak oleh aturan Firestore untuk akun ini.",
    );
  }
  if (!r.ok) throw new HttpError(502, `Firestore HTTP ${r.status}`);
  return await r.json();
}

async function getDoc(token: string, path: string): Promise<Doc | null> {
  const d = await fsFetch(token, `${FS}/${path}`);
  if (!d) return null;
  return { ...fields(d.fields ?? {}), __id: String(d.name).split("/").pop() };
}

async function listDocs(token: string, path: string): Promise<Doc[]> {
  const d = await fsFetch(token, `${FS}/${path}?pageSize=200`);
  if (!d || !d.documents) return [];
  // deno-lint-ignore no-explicit-any
  return d.documents.map((x: any) => ({
    ...fields(x.fields ?? {}),
    __id: String(x.name).split("/").pop(),
  }));
}

// ---------- Path ----------
function cleanPath(p: string) {
  let x = str(p).replace(/^\/+/, "");
  if (x.startsWith(`${BUCKET}/`)) x = x.slice(BUCKET.length + 1);
  if (!x || x.includes("..") || x.includes("\\") || x.includes("//")) {
    throw new HttpError(400, "Path file tidak valid.");
  }
  return x;
}
const folderOf = (p: string) => p.split("/")[0];

// ---------- Tentukan path + folder yang diizinkan ----------
type Target = { path: string; allowed: string[] | null };

async function resolveTarget(
  token: string,
  kind: string,
  b: Doc,
): Promise<Target> {
  const assignmentId = str(b.assignmentId);
  const laporanId = str(b.laporanId);
  const submissionId = str(b.submissionId);

  const needAssignment = async () => {
    if (!assignmentId) throw new HttpError(400, "assignmentId wajib diisi.");
    const a = await getDoc(token, `penugasan/${assignmentId}`);
    if (!a) throw new HttpError(404, "Penugasan tidak ditemukan.");
    return a;
  };
  const needLaporan = async () => {
    if (!laporanId) throw new HttpError(400, "laporanId wajib diisi.");
    const l = await getDoc(token, `laporan_kendala/${laporanId}`);
    if (!l) throw new HttpError(404, "Laporan kendala tidak ditemukan.");
    return l;
  };

  switch (kind) {
    case "hasil": {
      const a = await needAssignment();
      const riwayat = await listDocs(
        token,
        `penugasan/${assignmentId}/riwayat_pengumpulan`,
      );
      let path = str(a.file_hasil_path);
      if (!path && riwayat.length) {
        // pakai pengumpulan terbaru bila field penugasan kosong
        riwayat.sort((x, y) =>
          str(y.created_at).localeCompare(str(x.created_at))
        );
        path = str(riwayat[0].file_path);
      }
      if (!path) throw new HttpError(404, "Belum ada file hasil.");
      const allowed = [str(a.staff_id), ...riwayat.map((r) => str(r.staff_id))]
        .filter(Boolean);
      return { path, allowed };
    }
    case "riwayat": {
      if (!assignmentId || !submissionId) {
        throw new HttpError(400, "assignmentId dan submissionId wajib diisi.");
      }
      const s = await getDoc(
        token,
        `penugasan/${assignmentId}/riwayat_pengumpulan/${submissionId}`,
      );
      if (!s) throw new HttpError(404, "Riwayat pengumpulan tidak ditemukan.");
      const path = str(s.file_path);
      if (!path) throw new HttpError(404, "Riwayat ini tidak punya file.");
      return { path, allowed: [str(s.staff_id)].filter(Boolean) };
    }
    case "revisi": {
      const a = await needAssignment();
      let path = str(a.file_revisi_path);
      if (!path) {
        const rid = str(b.revisiId) || str(a.revisi_aktif_id);
        if (rid) {
          const r = await getDoc(
            token,
            `penugasan/${assignmentId}/riwayat_revisi/${rid}`,
          );
          path = str(r?.file_revisi_path);
        }
      }
      if (!path) throw new HttpError(404, "Belum ada lampiran revisi.");
      return { path, allowed: null }; // hanya Admin yang dapat menulis
    }
    case "solusi": {
      const l = await needLaporan();
      const path = str(l.solusi_file_path);
      if (!path) throw new HttpError(404, "Belum ada lampiran solusi.");
      return { path, allowed: null }; // hanya Admin yang dapat menulis
    }
    case "kendala": {
      const l = await needLaporan();
      const path = str(l.bukti_path);
      if (!path) throw new HttpError(404, "Laporan tidak punya bukti.");
      return { path, allowed: [str(l.pelapor_id)].filter(Boolean) };
    }
    case "penghentian": {
      const a = await needAssignment();
      const path = str(a.bukti_penghentian_path);
      if (!path) throw new HttpError(404, "Belum ada bukti penghentian.");
      return { path, allowed: null }; // hanya Admin yang dapat menulis
    }
    default:
      throw new HttpError(400, `kind tidak dikenal: ${kind}`);
  }
}

// ---------- Handler ----------
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    if (req.method !== "POST") throw new HttpError(405, "Gunakan metode POST.");
    if (!PROJECT_ID) {
      throw new HttpError(500, "Secret FIREBASE_PROJECT_ID belum diatur.");
    }

    const token = (req.headers.get("Authorization") ?? "").replace(
      /^Bearer\s+/i,
      "",
    );
    if (!token) throw new HttpError(401, "Token tidak ditemukan.");

    let uid = "";
    try {
      const { payload } = await jwtVerify(token, JWKS, {
        issuer: `https://securetoken.google.com/${PROJECT_ID}`,
        audience: PROJECT_ID,
      });
      uid = str(payload.sub);
    } catch {
      throw new HttpError(401, "Token Firebase tidak valid atau kedaluwarsa.");
    }
    if (!uid) throw new HttpError(401, "Token tidak berisi uid.");

    // deno-lint-ignore no-explicit-any
    const body: Doc = await req.json().catch(() => ({} as any));
    const kind = str(body.kind);

    const me = await getDoc(token, `users/${uid}`);
    const isAdmin = str(me?.role).toLowerCase() === "admin";

    const target = await resolveTarget(token, kind, body);
    const path = cleanPath(target.path);

    if (!isAdmin && target.allowed) {
      const ok = target.allowed.includes(folderOf(path));
      if (!ok) {
        throw new HttpError(
          403,
          "File bukan milik pengunggah yang tercatat pada data ini.",
        );
      }
    }

    const sb = createClient(SUPABASE_URL, SERVICE_KEY, {
      auth: { persistSession: false },
    });
    const { data, error } = await sb.storage
      .from(BUCKET)
      .createSignedUrl(path, 3600);
    if (error || !data?.signedUrl) {
      throw new HttpError(
        404,
        `File tidak ditemukan di Storage (path: ${path}). ${error?.message ?? ""}`
          .trim(),
      );
    }
    return json({ url: data.signedUrl });
  } catch (e) {
    if (e instanceof HttpError) return json({ error: e.message }, e.status);
    console.error(e);
    return json({ error: `Kesalahan server: ${(e as Error).message}` }, 500);
  }
});