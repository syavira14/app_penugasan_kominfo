
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  createRemoteJWKSet,
  jwtVerify,
} from "npm:jose@6";

const firebaseProjectId = "simtas-kominfo";

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

function jsonResponse(
  data: Record<string, unknown>,
  status = 200
) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

// Membaca dokumen Firestore menggunakan token Firebase.
// Operasi ini tetap mengikuti Firestore Security Rules.
async function getFirestoreDocument(
  collection: string,
  documentId: string,
  firebaseToken: string
) {
  const url =
    `https://firestore.googleapis.com/v1/projects/` +
    `${firebaseProjectId}/databases/(default)/documents/` +
    `${encodeURIComponent(collection)}/` +
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

  // Konversi field Firestore REST menjadi nilai sederhana.
  const result: Record<string, unknown> = {};

  for (const [key, field] of Object.entries(
    document.fields ?? {}
  )) {
    const value = field as Record<string, unknown>;

    result[key] =
      value.stringValue ??
      value.integerValue ??
      value.booleanValue ??
      null;
  }

  return result;
}

Deno.serve(async (request) => {
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
    // 1. Ambil Firebase ID token dari Flutter.
    const authorization =
      request.headers.get("Authorization") ?? "";

    if (!authorization.startsWith("Bearer ")) {
      return jsonResponse(
        { error: "Token tidak ditemukan." },
        401
      );
    }

    const firebaseToken = authorization.slice(7);

    // 2. Verifikasi token Firebase.
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

    const uid = String(payload.sub ?? "");

    if (!uid) {
      return jsonResponse(
        { error: "Identitas pengguna tidak valid." },
        401
      );
    }

    // 3. Ambil parameter.
    const body = await request.json();

    const assignmentId = body.assignmentId;
    const kind = body.kind;

    if (
      typeof assignmentId !== "string" ||
      !assignmentId.trim() ||
      !["hasil", "revisi"].includes(kind)
    ) {
      return jsonResponse(
        { error: "Parameter tidak valid." },
        400
      );
    }

    // 4. Ambil role dan data penugasan dari Firestore.
    const user = await getFirestoreDocument(
      "users",
      uid,
      firebaseToken
    );

    const assignment = await getFirestoreDocument(
      "penugasan",
      assignmentId,
      firebaseToken
    );

    const taskId = String(
      assignment.tugas_id ?? ""
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

    // 5. Periksa hak akses.
    const role = String(
      user.role ?? ""
    ).toLowerCase();

    const staffId = String(
      assignment.staff_id ?? ""
    );

    const adminId = String(
      task.dibuat_oleh ?? ""
    );

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

    // 6. Ambil path file sesuai jenisnya.
    const pathField =
      kind === "hasil"
        ? "file_hasil_path"
        : "file_revisi_path";

    let path = String(
      assignment[pathField] ?? ""
    ).trim();

    path = path
      .replace(/^\/+/, "")
      .replace(/^file-tugas\//, "");

    // Validasi path file hasil pekerjaan dan lampiran revisi.
    if (!path || path.includes("..") || path.includes("\\")) {
      return jsonResponse(
        { error: "Path file tidak valid." },
        400
      );
    }
    
    if (kind === "hasil") {
      // File hasil harus berada dalam folder staff yang ditugaskan.
      if (!staffId || !path.startsWith(`${staffId}/`)) {
        return jsonResponse(
          { error: "Path file hasil tidak sesuai dengan staff." },
          400
        );
      }
    } else {
      // Ambil UID admin yang mengunggah lampiran revisi.
      const uploadedBy = String(
        assignment.file_revisi_uploaded_by ?? ""
      ).trim();
    
      if (!uploadedBy) {
        return jsonResponse(
          { error: "Identitas pengunggah revisi belum tersedia." },
          400
        );
      }
    
      // Pastikan file berada dalam folder admin pengunggah.
      if (!path.startsWith(`${uploadedBy}/`)) {
        return jsonResponse(
          { error: "Path revisi tidak sesuai dengan pengunggah." },
          400
        );
      }
    }

    // 7. Buat koneksi server-side Supabase.
    const supabaseUrl =
      Deno.env.get("SUPABASE_URL");

    const serviceRoleKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error(
        "Konfigurasi Supabase belum tersedia."
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

    // 8. Buat signed URL selama 5 menit.
    const { data, error } = await supabase.storage
      .from("file-tugas")
      .createSignedUrl(path, 300);

    if (error || !data?.signedUrl) {
      return jsonResponse(
        { error: "Gagal membuat link file." },
        404
      );
    }

    return jsonResponse({
      url: data.signedUrl,
    });
  } catch (error) {
    console.error("Edge Function error:", error);

    return jsonResponse(
      { error: "Autentikasi atau akses data gagal." },
      403
    );
  }
});
