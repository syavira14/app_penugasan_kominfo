
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  createRemoteJWKSet,
  jwtVerify,
} from "npm:jose@6";

const firebaseProjectId = "simtas-kominfo";
const bucket = "file-tugas";

const firebaseKeys = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"
  )
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type FirestoreData = Record<string, unknown>;

function jsonResponse(
  data: Record<string, unknown>,
  status = 200
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

function getString(
  data: FirestoreData,
  field: string
): string {
  return String(data[field] ?? "").trim();
}

function normalizePath(path: string): string {
  let clean = path.trim();

  clean = clean.replace(/^\/+/, "");

  if (clean.startsWith(`${bucket}/`)) {
    clean = clean.substring(bucket.length + 1);
  }

  return clean;
}

function validPath(path: string): boolean {
  if (!path || path.startsWith("/")) {
    return false;
  }

  if (
    path.includes("\\") ||
    path.includes("?") ||
    path.includes("#") ||
    path.includes("%") ||
    path.includes("//")
  ) {
    return false;
  }

  const segments = path.split("/");

  return segments.every(
    (segment) =>
      segment.length > 0 &&
      segment !== "." &&
      segment !== ".."
  );
}

function isInsideFolder(
  path: string,
  folder: string
): boolean {
  return path.startsWith(`${folder}/`);
}

// Membaca dokumen Firestore menggunakan Firebase ID Token.
// Akses dokumen mengikuti Firestore Security Rules.
async function getFirestoreDocument(
  collection: string,
  documentId: string,
  firebaseToken: string
): Promise<FirestoreData> {
  if (!documentId.trim()) {
    throw new Error("ID dokumen kosong.");
  }

  const url =
    `https://firestore.googleapis.com/v1/projects/` +
    `${firebaseProjectId}/databases/(default)/documents/` +
    `${collection.split("/").map(encodeURIComponent).join("/")}/` +
    `${encodeURIComponent(documentId)}`;

  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${firebaseToken}`,
    },
  });

  if (!response.ok) {
    throw new Error(
      `Firestore ${collection}: HTTP ${response.status}`
    );
  }

  const document = await response.json();

  const result: FirestoreData = {};

  for (const [key, rawField] of Object.entries(
    document.fields ?? {}
  )) {
    const field = rawField as Record<string, unknown>;

    result[key] =
      field.stringValue ??
      field.integerValue ??
      field.booleanValue ??
      null;
  }

  return result;
}

Deno.serve(async (request: Request): Promise<Response> => {
  // 1. CORS preflight.
  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  if (request.method !== "POST") {
    return jsonResponse(
      { error: "Method tidak diizinkan." },
      405
    );
  }

  try {
    // 2. Ambil Firebase ID Token.
    const authorization =
      request.headers.get("Authorization") ?? "";

    if (!authorization.startsWith("Bearer ")) {
      return jsonResponse(
        { error: "Token tidak ditemukan." },
        401
      );
    }

    const firebaseToken =
      authorization.substring("Bearer ".length).trim();

    // 3. Verifikasi Firebase ID Token.
    const { payload } = await jwtVerify(
      firebaseToken,
      firebaseKeys,
      {
        issuer:
          `https://securetoken.google.com/${firebaseProjectId}`,
        audience: firebaseProjectId,
        algorithms: ["RS256"],
      }
    );

    const uid = String(payload.sub ?? "").trim();

    if (!uid) {
      return jsonResponse(
        { error: "Identitas pengguna tidak valid." },
        401
      );
    }

    // 4. Baca parameter permintaan.
    let body: Record<string, unknown>;

    try {
      const parsed = await request.json();

      if (
        !parsed ||
        typeof parsed !== "object" ||
        Array.isArray(parsed)
      ) {
        return jsonResponse(
          { error: "Format permintaan tidak valid." },
          400
        );
      }

      body = parsed as Record<string, unknown>;
    } catch {
      return jsonResponse(
        { error: "Body JSON tidak valid." },
        400
      );
    }

    const kind = body.kind;

    if (
      typeof kind !== "string" ||
      !["hasil", "revisi", "kendala", "solusi", "riwayat", "penghentian"].includes(kind)
    ) {
      return jsonResponse(
        { error: "Jenis file tidak valid." },
        400
      );
    }

    // 5. Ambil role pengguna dari Firestore.
    const user = await getFirestoreDocument(
      "users",
      uid,
      firebaseToken
    );

    const role = getString(user, "role").toLowerCase();

    if (role !== "admin" && role !== "staff") {
      return jsonResponse(
        { error: "Role pengguna tidak diizinkan." },
        403
      );
    }

    let filePath = "";

    // =====================================================
    // JENIS 1: HASIL PEKERJAAN / REVISI
    // =====================================================
    if (kind === "hasil" || kind === "revisi") {
      const assignmentId = body.assignmentId;

      if (
        typeof assignmentId !== "string" ||
        !assignmentId.trim()
      ) {
        return jsonResponse(
          { error: "ID penugasan tidak valid." },
          400
        );
      }

      const assignment = await getFirestoreDocument(
        "penugasan",
        assignmentId,
        firebaseToken
      );

      const taskId = getString(
        assignment,
        "tugas_id"
      );

      if (!taskId) {
        return jsonResponse(
          { error: "ID tugas tidak ditemukan." },
          404
        );
      }

      const task = await getFirestoreDocument(
        "tugas",
        taskId,
        firebaseToken
      );

      const staffId = getString(
        assignment,
        "staff_id"
      );

      // Tetap mempertahankan kebijakan akses lama:
      // hasil untuk admin, revisi untuk staff terkait.
      const authorized =
        kind === "hasil"
          ? role === "admin"
          : role === "staff" && uid === staffId;

      if (!authorized) {
        return jsonResponse(
          { error: "Tidak memiliki izin akses." },
          403
        );
      }

      // Memastikan dokumen tugas memang tersedia.
      // Admin seluruh divisi boleh melihat hasil staff.
      if (!getString(task, "dibuat_oleh")) {
        // Tidak memblokir dokumen tugas lama
        // yang belum menyimpan pembuat tugas.
        console.log(
          "Dokumen tugas tidak memiliki dibuat_oleh."
        );
      }

      const pathField =
        kind === "hasil"
          ? "file_hasil_path"
          : "file_revisi_path";

      filePath = normalizePath(
        getString(assignment, pathField)
      );

      if (!validPath(filePath)) {
        return jsonResponse(
          { error: "Path file tidak valid." },
          400
        );
      }

      if (kind === "hasil") {
        if (
          !staffId ||
          !isInsideFolder(filePath, staffId)
        ) {
          return jsonResponse(
            {
              error:
                "Path hasil tidak sesuai dengan staff.",
            },
            400
          );
        }
      } else {
        const uploadedBy = getString(
          assignment,
          "file_revisi_uploaded_by"
        );

        if (
          !uploadedBy ||
          !isInsideFolder(filePath, uploadedBy)
        ) {
          return jsonResponse(
            {
              error:
                "Path revisi tidak sesuai dengan pengunggah.",
            },
            400
          );
        }
      }
    }

    // =====================================================
    // JENIS 2: BUKTI LAPORAN KENDALA
    // =====================================================
    if (kind === "kendala" || kind === "solusi") {
      const laporanId = body.laporanId;

      if (
        typeof laporanId !== "string" ||
        !laporanId.trim()
      ) {
        return jsonResponse(
          { error: "ID laporan kendala tidak valid." },
          400
        );
      }

      // Ambil laporan langsung dari Firestore.
      const laporan = await getFirestoreDocument(
        "laporan_kendala",
        laporanId,
        firebaseToken
      );

      const pelaporId = getString(
        laporan,
        "pelapor_id"
      );

      const penugasanId = getString(
        laporan,
        "penugasan_id"
      );

      if (!pelaporId || !penugasanId) {
        return jsonResponse(
          {
            error:
              "Data pelapor atau penugasan tidak lengkap.",
          },
          400
        );
      }

      // Admin dapat melihat seluruh laporan.
      // Staff hanya dapat melihat laporan miliknya.
      const authorized =
        role === "admin" ||
        (role === "staff" && uid === pelaporId);

      if (!authorized) {
        return jsonResponse(
          {
            error:
              "Tidak memiliki izin melihat bukti kendala.",
          },
          403
        );
      }

      // Pastikan laporan terhubung dengan penugasan
      // yang benar dan pelapornya sesuai.
      const assignment = await getFirestoreDocument(
        "penugasan",
        penugasanId,
        firebaseToken
      );

      const assignmentStaffId = getString(
        assignment,
        "staff_id"
      );

      const assignmentTaskId = getString(
        assignment,
        "tugas_id"
      );

      const reportTaskId = getString(
        laporan,
        "tugas_id"
      );

      if (
        assignmentStaffId !== pelaporId ||
        !assignmentTaskId ||
        assignmentTaskId !== reportTaskId
      ) {
        return jsonResponse(
          {
            error:
              "Laporan tidak sesuai dengan data penugasan.",
          },
          403
        );
      }

      // File bukti wajib berasal dari path
      // yang tersimpan pada dokumen laporan.
      filePath = normalizePath(
        getString(laporan, kind === "solusi" ? "solusi_file_path" : "bukti_path")
      );

      if (!validPath(filePath)) {
        return jsonResponse(
          {
            error:
              "Path bukti laporan tidak valid atau kosong.",
          },
          400
        );
      }

      // File bukti berada dalam:
      // UID_PELAPOR/kendala_ID_PENUGASAN/NAMA_FILE
      const expectedFolder = kind === "solusi"
        ? `${getString(laporan, "ditangani_oleh")}/solusi_${laporanId}`
        : `${pelaporId}/kendala_${penugasanId}`;

      if (!isInsideFolder(filePath, expectedFolder)) {
        return jsonResponse(
          {
            error:
              "Path bukti tidak sesuai dengan laporan.",
          },
          403
        );
      }

      const provider = kind === "solusi" ? "supabase" : getString(
        laporan,
        "bukti_provider"
      ).toLowerCase();

      if (
        provider &&
        provider !== "supabase"
      ) {
        return jsonResponse(
          {
            error:
              "Provider lampiran tidak didukung.",
          },
          400
        );
      }
    }

    if (kind === "riwayat" || kind === "penghentian") {
      const assignmentId = body.assignmentId;
      if (typeof assignmentId !== "string" || !assignmentId.trim()) {
        return jsonResponse({error: "ID penugasan tidak valid."}, 400);
      }
      const assignment = await getFirestoreDocument("penugasan", assignmentId, firebaseToken);
      const staffId = getString(assignment, "staff_id");
      if (role !== "admin" && uid !== staffId) {
        return jsonResponse({error: "Akses ditolak."}, 403);
      }
      if (kind === "penghentian") {
        filePath = normalizePath(getString(assignment, "bukti_penghentian_path"));
      } else {
        const submissionId = body.submissionId;
        if (typeof submissionId !== "string" || !submissionId.trim()) {
          return jsonResponse({error: "ID pengumpulan tidak valid."}, 400);
        }
        const submission = await getFirestoreDocument(
          `penugasan/${assignmentId}/riwayat_pengumpulan`,
          submissionId, firebaseToken);
        if (getString(submission, "penugasan_id") !== assignmentId ||
            getString(submission, "staff_id") !== staffId) {
          return jsonResponse({error: "Pengumpulan tidak sesuai."}, 403);
        }
        filePath = normalizePath(getString(submission, "file_path"));
      }
      if (!validPath(filePath)) return jsonResponse({error: "Path tidak valid."}, 400);
      // File pengumpulan berasal dari folder pemilik; bukti penghentian dari admin.
      if (kind === "riwayat" && !isInsideFolder(filePath, staffId)) {
        return jsonResponse({error: "File bukan milik staff."}, 403);
      }
      if (kind === "penghentian" && !filePath.includes(`/penghentian_${assignmentId}/`)) {
        return jsonResponse({error: "Path bukti tidak sesuai."}, 403);
      }
    }

    // =====================================================
    // MEMBUAT SIGNED URL SUPABASE
    // =====================================================

    const supabaseUrl =
      Deno.env.get("SUPABASE_URL");

    const serviceRoleKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      console.error(
        "Konfigurasi Supabase tidak tersedia."
      );

      return jsonResponse(
        { error: "Konfigurasi server belum lengkap." },
        500
      );
    }

    const supabase = createClient(
      supabaseUrl,
      serviceRoleKey,
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
        },
      }
    );

    // Signed URL berlaku selama 5 menit.
    const { data, error } = await supabase.storage
      .from(bucket)
      .createSignedUrl(filePath, 300);

    if (error || !data?.signedUrl) {
      console.error(
        "Gagal membuat signed URL:",
        error
      );

      return jsonResponse(
        { error: "Gagal mengambil akses file." },
        404
      );
    }

    return jsonResponse({
      url: data.signedUrl,
    });
  } catch (error) {
    console.error(
      "Edge Function error:",
      error
    );

    return jsonResponse(
      {
        error:
          "Autentikasi atau akses data gagal.",
      },
      403
    );
  }
});
