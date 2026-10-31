
const { onCall, HttpsError } =
  require("firebase-functions/v2/https");

const { defineSecret } =
  require("firebase-functions/params");

const admin = require("firebase-admin");

const { createClient } =
  require("@supabase/supabase-js");

// Inisialisasi Firebase Admin SDK.
if (!admin.apps.length) {
  admin.initializeApp();
}

// Secret Supabase, hanya digunakan di backend.
const supabaseUrl = defineSecret("SUPABASE_URL");

const serviceRoleKey =
  defineSecret("SUPABASE_SERVICE_ROLE_KEY");

// Cloud Function untuk membuat signed URL
// file hasil pekerjaan dan lampiran revisi.
exports.getAssignmentFileUrl = onCall(
  {
    secrets: [supabaseUrl, serviceRoleKey],
  },
  async (request) => {
    // 1. Pastikan pengguna sudah login.
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Login diperlukan."
      );
    }

    const { assignmentId, kind } =
      request.data || {};

    // 2. Validasi parameter.
    if (
      typeof assignmentId !== "string" ||
      !assignmentId.trim() ||
      !["hasil", "revisi"].includes(kind)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Permintaan tidak valid."
      );
    }

    const db = admin.firestore();
    const uid = request.auth.uid;

    // 3. Ambil role pengguna dari Firestore.
    const userDoc = await db
      .collection("users")
      .doc(uid)
      .get();

    const role = String(
      userDoc.data()?.role || ""
    ).toLowerCase();

    // 4. Ambil data penugasan.
    const assignmentDoc = await db
      .collection("penugasan")
      .doc(assignmentId)
      .get();

    if (!assignmentDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Penugasan tidak ditemukan."
      );
    }

    const assignment = assignmentDoc.data();

    // 5. Ambil data tugas.
    const taskDoc = await db
      .collection("tugas")
      .doc(String(assignment.tugas_id || ""))
      .get();

    if (!taskDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Tugas tidak ditemukan."
      );
    }

    const task = taskDoc.data();

    const ownerId = String(
      task.dibuat_oleh || ""
    );

    const staffId = String(
      assignment.staff_id || ""
    );

    // 6. Periksa hak akses.
    //
    // Admin pembuat tugas:
    // boleh melihat hasil pekerjaan staff.
    //
    // Staff penerima tugas:
    // boleh melihat lampiran revisi admin.
    const authorized = kind === "hasil"
      ? role === "admin" && uid === ownerId
      : role === "staff" && uid === staffId;

    if (!authorized) {
      throw new HttpsError(
        "permission-denied",
        "Akses file ditolak."
      );
    }

    // 7. Tentukan field path file.
    const field = kind === "hasil"
      ? "file_hasil_path"
      : "file_revisi_path";

    // 8. Normalisasi path Supabase.
    let path = String(
      assignment[field] || ""
    )
      .trim()
      .replace(/^\/+/, "")
      .replace(/^file-tugas\//, "");

    // File hasil berada di folder UID staff.
    // File revisi berada di folder UID admin.
    const expectedFolder = kind === "hasil"
      ? staffId
      : ownerId;

    if (
      !expectedFolder ||
      !path.startsWith(`${expectedFolder}/`) ||
      path.includes("..")
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Path file tidak sesuai."
      );
    }

    // 9. Buat koneksi Supabase di backend.
    const supabase = createClient(
      supabaseUrl.value(),
      serviceRoleKey.value(),
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
        },
      }
    );

    // 10. Buat signed URL selama 5 menit.
    const { data, error } = await supabase.storage
      .from("file-tugas")
      .createSignedUrl(path, 300);

    if (error || !data?.signedUrl) {
      throw new HttpsError(
        "not-found",
        "File tidak dapat diakses."
      );
    }

    // 11. Kirim signed URL ke Flutter.
    return {
      url: data.signedUrl,
    };
  }
);
