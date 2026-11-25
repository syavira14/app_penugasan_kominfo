const { onCall, HttpsError } = require("firebase-functions/v2/https");

const { defineSecret } = require("firebase-functions/params");

const admin = require("firebase-admin");

const { createClient } = require("@supabase/supabase-js");

const crypto = require("crypto");

const nodemailer = require("nodemailer");

// Inisialisasi Firebase Admin SDK.
if (!admin.apps.length) {
  admin.initializeApp();
}

// Secret Supabase, hanya digunakan di backend.
const supabaseUrl = defineSecret("SUPABASE_URL");

const serviceRoleKey = defineSecret("SUPABASE_SERVICE_ROLE_KEY");

// Secret SMTP untuk mengirim email lupa password (mis. Gmail + App Password).
const smtpUser = defineSecret("SMTP_USER");

const smtpPass = defineSecret("SMTP_PASS");

// Cloud Function untuk membuat signed URL
// file hasil pekerjaan dan lampiran revisi.
exports.getAssignmentFileUrl = onCall(
  {
    secrets: [supabaseUrl, serviceRoleKey],
  },
  async (request) => {
    // 1. Pastikan pengguna sudah login.
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login diperlukan.");
    }

    const { assignmentId, kind } = request.data || {};

    // 2. Validasi parameter.
    if (
      typeof assignmentId !== "string" ||
      !assignmentId.trim() ||
      !["hasil", "revisi"].includes(kind)
    ) {
      throw new HttpsError("invalid-argument", "Permintaan tidak valid.");
    }

    const db = admin.firestore();
    const uid = request.auth.uid;

    // 3. Ambil role pengguna dari Firestore.
    const userDoc = await db.collection("users").doc(uid).get();

    const role = String(userDoc.data()?.role || "").toLowerCase();

    // 4. Ambil data penugasan.
    const assignmentDoc = await db
      .collection("penugasan")
      .doc(assignmentId)
      .get();

    if (!assignmentDoc.exists) {
      throw new HttpsError("not-found", "Penugasan tidak ditemukan.");
    }

    const assignment = assignmentDoc.data();

    // 5. Ambil data tugas.
    const taskDoc = await db
      .collection("tugas")
      .doc(String(assignment.tugas_id || ""))
      .get();

    if (!taskDoc.exists) {
      throw new HttpsError("not-found", "Tugas tidak ditemukan.");
    }

    const task = taskDoc.data();

    const ownerId = String(task.dibuat_oleh || "");

    const staffId = String(assignment.staff_id || "");

    // 6. Periksa hak akses.
    //
    // Admin pembuat tugas:
    // boleh melihat hasil pekerjaan staff.
    //
    // Staff penerima tugas:
    // boleh melihat lampiran revisi admin.
    const authorized =
      kind === "hasil"
        ? role === "admin" && uid === ownerId
        : role === "staff" && uid === staffId;

    if (!authorized) {
      throw new HttpsError("permission-denied", "Akses file ditolak.");
    }

    // 7. Tentukan field path file.
    const field = kind === "hasil" ? "file_hasil_path" : "file_revisi_path";

    // 8. Normalisasi path Supabase.
    let path = String(assignment[field] || "")
      .trim()
      .replace(/^\/+/, "")
      .replace(/^file-tugas\//, "");

    // File hasil berada di folder UID staff.
    // File revisi berada di folder UID admin.
    const expectedFolder = kind === "hasil" ? staffId : ownerId;

    if (
      !expectedFolder ||
      !path.startsWith(`${expectedFolder}/`) ||
      path.includes("..")
    ) {
      throw new HttpsError("failed-precondition", "Path file tidak sesuai.");
    }

    // 9. Buat koneksi Supabase di backend.
    const supabase = createClient(supabaseUrl.value(), serviceRoleKey.value(), {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    // 10. Buat signed URL selama 5 menit.
    const { data, error } = await supabase.storage
      .from("file-tugas")
      .createSignedUrl(path, 300);

    if (error || !data?.signedUrl) {
      throw new HttpsError("not-found", "File tidak dapat diakses.");
    }

    // 11. Kirim signed URL ke Flutter.
    return {
      url: data.signedUrl,
    };
  },
);

// Cloud Function untuk admin mengubah / mereset password akun staff.
// Hanya pengguna dengan role admin yang boleh memanggil.
exports.adminSetPassword = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Login diperlukan.");
  }

  const callerDoc = await admin
    .firestore()
    .collection("users")
    .doc(request.auth.uid)
    .get();

  const callerRole = String(callerDoc.data()?.role || "").toLowerCase();
  if (!callerDoc.exists || callerRole !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Hanya admin yang boleh mengubah password.",
    );
  }

  const { uid, password } = request.data || {};

  if (typeof uid !== "string" || !uid.trim()) {
    throw new HttpsError("invalid-argument", "UID staff tidak valid.");
  }
  if (typeof password !== "string" || password.length < 6) {
    throw new HttpsError("invalid-argument", "Password minimal 6 karakter.");
  }

  // Hanya akun staff yang boleh diubah lewat fungsi ini.
  const targetDoc = await admin.firestore().collection("users").doc(uid).get();
  const targetRole = String(targetDoc.data()?.role || "").toLowerCase();
  if (!targetDoc.exists || targetRole !== "staff") {
    throw new HttpsError("not-found", "Akun staff tidak ditemukan.");
  }

  try {
    await admin.auth().updateUser(uid, { password });
  } catch (e) {
    console.error("adminSetPassword gagal", uid, e);
    if (e.code === "auth/user-not-found") {
      throw new HttpsError(
        "not-found",
        "Akun login staf tidak ditemukan di Authentication (UID tidak cocok dengan data profil).",
      );
    }
    throw new HttpsError(
      "internal",
      `Gagal mengubah password (${e.code || e.message}).`,
    );
  }
  return { ok: true };
});

// Admin mengganti NIP miliknya sendiri.
// NIP = username login, jadi email Firebase Auth ikut diganti menjadi
// NIP@simtas.internal. UID tidak berubah, jadi data tugas tetap aman.
exports.changeOwnNip = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Login diperlukan.");
  }

  const uid = request.auth.uid;
  const db = admin.firestore();

  const callerDoc = await db.collection("users").doc(uid).get();
  const callerRole = String(callerDoc.data()?.role || "").toLowerCase();
  if (!callerDoc.exists || callerRole !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Hanya admin yang boleh mengubah NIP lewat fungsi ini.",
    );
  }

  const nip = String((request.data || {}).nip || "").trim();
  if (!/^[0-9]{6,30}$/.test(nip)) {
    throw new HttpsError(
      "invalid-argument",
      "NIP harus angka, 6 sampai 30 digit.",
    );
  }

  // NIP tidak boleh dipakai pengguna lain.
  const dup = await db.collection("users").where("nip", "==", nip).get();
  if (dup.docs.some((d) => d.id !== uid)) {
    throw new HttpsError("already-exists", "NIP sudah dipakai pengguna lain.");
  }

  const email = `${nip}@simtas.internal`;

  try {
    await admin.auth().updateUser(uid, { email });
  } catch (e) {
    if (e.code === "auth/email-already-exists") {
      throw new HttpsError(
        "already-exists",
        "NIP sudah punya akun login lain.",
      );
    }
    console.error("updateUser(email) gagal", e);
    throw new HttpsError(
      "internal",
      `Gagal mengubah akun login (${e.code || e.message}).`,
    );
  }

  await db.collection("users").doc(uid).update({
    nip,
    email,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true };
});

// Admin mengganti NIP akun staff.
// NIP = username login, jadi email Firebase Auth ikut diganti menjadi
// NIP@simtas.internal. UID tidak berubah, jadi data tugas tetap aman.
// Hanya pengguna dengan role admin yang boleh memanggil.
exports.adminSetNip = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Login diperlukan.");
  }

  const db = admin.firestore();

  const callerDoc = await db.collection("users").doc(request.auth.uid).get();
  const callerRole = String(callerDoc.data()?.role || "").toLowerCase();
  if (!callerDoc.exists || callerRole !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Hanya admin yang boleh mengubah NIP staff.",
    );
  }

  const { uid } = request.data || {};
  const nip = String((request.data || {}).nip || "").trim();

  if (typeof uid !== "string" || !uid.trim()) {
    throw new HttpsError("invalid-argument", "UID staff tidak valid.");
  }
  if (!/^[0-9]{6,30}$/.test(nip)) {
    throw new HttpsError(
      "invalid-argument",
      "NIP harus angka, 6 sampai 30 digit.",
    );
  }

  // Hanya akun staff yang boleh diubah lewat fungsi ini.
  const targetDoc = await db.collection("users").doc(uid).get();
  const targetRole = String(targetDoc.data()?.role || "").toLowerCase();
  if (!targetDoc.exists || targetRole !== "staff") {
    throw new HttpsError("not-found", "Akun staff tidak ditemukan.");
  }

  // NIP tidak boleh dipakai pengguna lain.
  // Dicek untuk NIP bertipe teks maupun angka (data lama bisa tersimpan angka).
  const dupText = await db.collection("users").where("nip", "==", nip).get();
  const dupNum = await db
    .collection("users")
    .where("nip", "==", Number(nip))
    .get();
  if ([...dupText.docs, ...dupNum.docs].some((d) => d.id !== uid)) {
    throw new HttpsError("already-exists", "NIP sudah dipakai pengguna lain.");
  }

  const email = `${nip}@simtas.internal`;

  try {
    await admin.auth().updateUser(uid, { email });
  } catch (e) {
    if (e.code === "auth/email-already-exists") {
      throw new HttpsError(
        "already-exists",
        "NIP sudah punya akun login lain.",
      );
    }
    console.error("updateUser(email) gagal", e);
    throw new HttpsError(
      "internal",
      `Gagal mengubah akun login (${e.code || e.message}).`,
    );
  }

  // NIP disimpan sebagai teks supaya konsisten.
  await db.collection("users").doc(uid).update({
    nip,
    email,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true, email };
});

// Admin menghapus akun login (Firebase Authentication) staff.
// Dipanggil aplikasi SETELAH dokumen users/{uid} dihapus, supaya NIP yang
// sama bisa didaftarkan lagi. Hanya admin yang boleh memanggil.
exports.adminDeleteStaff = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Login diperlukan.");
  }

  const db = admin.firestore();

  const callerDoc = await db.collection("users").doc(request.auth.uid).get();
  const callerRole = String(callerDoc.data()?.role || "").toLowerCase();
  if (!callerDoc.exists || callerRole !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Hanya admin yang boleh menghapus akun staff.",
    );
  }

  const { uid } = request.data || {};
  if (typeof uid !== "string" || !uid.trim()) {
    throw new HttpsError("invalid-argument", "UID staff tidak valid.");
  }
  if (uid === request.auth.uid) {
    throw new HttpsError(
      "failed-precondition",
      "Tidak bisa menghapus akun sendiri.",
    );
  }

  // Pengaman: kalau dokumennya masih ada, harus berperan staff.
  const targetDoc = await db.collection("users").doc(uid).get();
  if (targetDoc.exists) {
    const targetRole = String(targetDoc.data()?.role || "").toLowerCase();
    if (targetRole !== "staff") {
      throw new HttpsError(
        "permission-denied",
        "Hanya akun staff yang boleh dihapus.",
      );
    }
  }

  let user;
  try {
    user = await admin.auth().getUser(uid);
  } catch (e) {
    if (e.code === "auth/user-not-found") return { ok: true };
    throw new HttpsError("internal", "Gagal membaca akun login.");
  }

  // Pengaman: hanya akun NIP internal yang boleh dihapus lewat fungsi ini.
  if (!String(user.email || "").endsWith("@simtas.internal")) {
    throw new HttpsError("failed-precondition", "Bukan akun staff NIP.");
  }

  await admin.auth().deleteUser(uid);
  return { ok: true };
});

// Dipakai halaman login (belum login, jadi tanpa cek auth): mencari email
// login yang sebenarnya dari NIP. Perlu karena akun lama bisa saja terdaftar
// dengan email asli, bukan NIP@simtas.internal.
exports.resolveLoginEmail = onCall(async (request) => {
  const nip = String((request.data || {}).nip || "").trim();
  if (!/^[0-9]{6,30}$/.test(nip)) {
    return { found: false };
  }

  const db = admin.firestore();
  const byText = await db
    .collection("users")
    .where("nip", "==", nip)
    .limit(1)
    .get();
  let doc = byText.docs[0];
  if (!doc) {
    // Data lama bisa menyimpan NIP sebagai angka.
    const byNum = await db
      .collection("users")
      .where("nip", "==", Number(nip))
      .limit(1)
      .get();
    doc = byNum.docs[0];
  }
  if (!doc) return { found: false };

  try {
    const user = await admin.auth().getUser(doc.id);
    if (!user.email) return { found: false };
    return { found: true, email: user.email };
  } catch (e) {
    return { found: false };
  }
});

// ===========================================================
// LUPA KATA SANDI (tanpa email / WhatsApp)
// 1) Staf mengisi NIP + nama di halaman login -> permintaan masuk ke admin.
// 2) Admin melihat permintaan di Kelola Staff -> tekan "Reset ke NIP".
// ===========================================================

function normNama(v) {
  return String(v || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

// Dipanggil dari halaman login (belum login).
exports.requestPasswordReset = onCall(async (request) => {
  const nip = String((request.data || {}).nip || "").trim();
  const nama = normNama((request.data || {}).nama);
  if (!/^[0-9]{6,30}$/.test(nip) || nama.length < 2) {
    throw new HttpsError(
      "invalid-argument",
      "Isi NIP dan nama lengkap dengan benar.",
    );
  }

  const db = admin.firestore();
  let snap = await db
    .collection("users")
    .where("nip", "==", nip)
    .limit(1)
    .get();
  if (snap.empty) {
    snap = await db
      .collection("users")
      .where("nip", "==", Number(nip))
      .limit(1)
      .get();
  }
  // Pesan sengaja sama agar tidak membocorkan mana yang salah.
  const tidakCocok = new HttpsError(
    "not-found",
    "NIP atau nama tidak cocok dengan data staf.",
  );
  if (snap.empty) throw tidakCocok;

  const doc = snap.docs[0];
  const data = doc.data();
  if (String(data.role || "").toLowerCase() !== "staff") {
    throw new HttpsError(
      "failed-precondition",
      "Akun ini tidak dapat direset lewat fitur ini.",
    );
  }
  if (normNama(data.nama) !== nama) throw tidakCocok;

  const ref = db.collection("permintaan_reset").doc(doc.id);
  const lama = await ref.get();
  if (lama.exists && lama.data().status === "menunggu") {
    return { ok: true, sudahAda: true };
  }
  await ref.set({
    uid: doc.id,
    nip: String(data.nip),
    nama: String(data.nama || ""),
    status: "menunggu",
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { ok: true };
});

// Admin memproses permintaan: action = "reset" (password jadi NIP) atau "tolak".
exports.adminResolveResetRequest = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Login diperlukan.");
  }
  const db = admin.firestore();
  const callerDoc = await db.collection("users").doc(request.auth.uid).get();
  const callerRole = String(callerDoc.data()?.role || "").toLowerCase();
  if (!callerDoc.exists || callerRole !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Hanya admin yang boleh memproses.",
    );
  }

  const { uid, action } = request.data || {};
  if (
    typeof uid !== "string" ||
    !uid.trim() ||
    !["reset", "tolak"].includes(action)
  ) {
    throw new HttpsError("invalid-argument", "Permintaan tidak valid.");
  }

  const ref = db.collection("permintaan_reset").doc(uid);
  const req = await ref.get();
  if (!req.exists || req.data().status !== "menunggu") {
    throw new HttpsError(
      "not-found",
      "Permintaan sudah diproses atau tidak ada.",
    );
  }

  if (action === "reset") {
    const userDoc = await db.collection("users").doc(uid).get();
    const u = userDoc.data() || {};
    if (!userDoc.exists || String(u.role || "").toLowerCase() !== "staff") {
      throw new HttpsError("not-found", "Akun staff tidak ditemukan.");
    }
    const nip = String(u.nip || "").trim();
    if (nip.length < 6) {
      throw new HttpsError("failed-precondition", "NIP staf tidak valid.");
    }
    try {
      await admin.auth().updateUser(uid, { password: nip });
      await admin.auth().revokeRefreshTokens(uid);
    } catch (e) {
      console.error("adminResolveResetRequest gagal", uid, e);
      throw new HttpsError(
        "internal",
        `Gagal mereset password (${e.code || e.message}).`,
      );
    }
  }

  await ref.update({
    status: action === "reset" ? "selesai" : "ditolak",
    diproses_oleh: request.auth.uid,
    diproses_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { ok: true };
});

// ===========================================================
// LUPA KATA SANDI VIA EMAIL
// Staf mengisi NIP + email (yang diisi sendiri di profil) di halaman login.
// Jika cocok, sandi baru acak dibuat dan DIKIRIM ke email tersebut.
// ===========================================================

const SEP = "||";

// Email kontak bersih (bagian sebelum "||" / tab) dari field email_kontak.
function cleanKontak(raw) {
  return String(raw || "")
    .split(SEP)[0]
    .split("\t")[0]
    .trim()
    .toLowerCase();
}

// NIP efektif: nip_override (bagian ke-4 di email_kontak) lebih diutamakan.
function effectiveNip(data) {
  const raw = String(data.email_kontak || "");
  if (raw.includes(SEP)) {
    const parts = raw.split(SEP);
    if (parts.length >= 4 && parts[3].trim()) return parts[3].trim();
  }
  return String(data.nip || "").trim();
}

async function findUserByNip(nip) {
  const db = admin.firestore();
  let snap = await db.collection("users").where("nip", "==", nip).limit(1).get();
  if (snap.empty) {
    snap = await db
      .collection("users")
      .where("nip", "==", Number(nip))
      .limit(1)
      .get();
  }
  if (!snap.empty) return snap.docs[0];
  // Cadangan: NIP bisa tersimpan sebagai override di email_kontak.
  const all = await db.collection("users").get();
  return all.docs.find((d) => effectiveNip(d.data()) === nip) || null;
}

// Sandi acak 10 karakter (huruf + angka, tanpa karakter yang mirip).
function generatePassword() {
  const letters = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
  const digits = "23456789";
  const all = letters + digits;
  const chars = [
    letters[crypto.randomInt(letters.length)],
    digits[crypto.randomInt(digits.length)],
  ];
  while (chars.length < 10) chars.push(all[crypto.randomInt(all.length)]);
  for (let i = chars.length - 1; i > 0; i--) {
    const j = crypto.randomInt(i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }
  return chars.join("");
}

// Menjaga metadata password aktif di email_kontak tetap sinkron dengan sandi baru.
function repackKontak(raw, newPass) {
  const s = String(raw || "");
  if (!s.includes(SEP)) return s; // belum ada metadata -> biarkan, app sinkron saat login
  const parts = s.split(SEP);
  parts[1] = newPass;
  const packed = parts.join(SEP);
  return packed.length <= 200 ? packed : parts[0];
}

function escapeHtml(v) {
  return String(v).replace(/[&<>"']/g, (c) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  })[c]);
}

const PESAN_UMUM =
  "Jika NIP dan email cocok dengan data terdaftar, kata sandi baru sudah dikirim ke email tersebut. " +
  "Periksa juga folder Spam.";

async function prosesLupaPassword(request) {
    const nip = String((request.data || {}).nip || "").trim();
    const email = String((request.data || {}).email || "")
      .trim()
      .toLowerCase();

    if (!/^[0-9]{6,30}$/.test(nip)) {
      throw new HttpsError("invalid-argument", "NIP tidak valid.");
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 200) {
      throw new HttpsError("invalid-argument", "Format email tidak valid.");
    }

    console.log("forgotPasswordByEmail: cari NIP", nip);
    const doc = await findUserByNip(nip);
    if (!doc) {
      console.log("forgotPasswordByEmail: NIP tidak ditemukan");
      return { ok: true, message: PESAN_UMUM };
    }

    const data = doc.data();
    const role = String(data.role || "").toLowerCase();
    if (!["staff", "admin", "atasan"].includes(role)) {
      return { ok: true, message: PESAN_UMUM };
    }

    // Email harus sama persis dengan email yang diisi pemilik akun di profil.
    const emailTerdaftar = cleanKontak(data.email_kontak);
    if (!emailTerdaftar || emailTerdaftar !== email) {
      console.log("forgotPasswordByEmail: email tidak cocok / belum diisi di profil");
      return { ok: true, message: PESAN_UMUM };
    }

    // Batasi permintaan: 1x per 2 menit & 5x per jam per akun.
    const db = admin.firestore();
    const logRef = db.collection("log_lupa_password").doc(doc.id);
    const now = Date.now();
    const log = (await logRef.get()).data() || {};
    const recent = (log.waktu || []).filter((t) => now - t < 3600 * 1000);
    if (recent.length && now - Math.max(...recent) < 2 * 60 * 1000) {
      throw new HttpsError(
        "resource-exhausted",
        "Permintaan terlalu sering. Coba lagi dalam 2 menit.",
      );
    }
    if (recent.length >= 5) {
      throw new HttpsError(
        "resource-exhausted",
        "Terlalu banyak permintaan. Coba lagi dalam 1 jam.",
      );
    }
    await logRef.set({ waktu: [...recent, now] });

    const newPass = generatePassword();
    const nama = String(data.nama || "Pengguna");

    console.log("forgotPasswordByEmail: data cocok, mengirim email");
    // 1) Kirim email lebih dulu: jika gagal, sandi lama tetap berlaku.
    try {
      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: { user: smtpUser.value(), pass: smtpPass.value() },
      });
      await transporter.sendMail({
        from: `"SIMTAS Kominfo" <${smtpUser.value()}>`,
        to: emailTerdaftar,
        subject: "Kata Sandi Baru Akun SIMTAS",
        text:
          `Halo ${nama},\n\n` +
          `Permintaan lupa kata sandi untuk NIP ${nip} telah diproses.\n\n` +
          `Kata sandi baru Anda: ${newPass}\n\n` +
          `Silakan masuk memakai NIP dan kata sandi di atas, lalu segera ganti kata sandi Anda.\n` +
          `Jika Anda tidak merasa meminta ini, hubungi Admin.\n\n` +
          `SIMTAS - Dinas Komunikasi dan Informatika`,
        html:
          `<p>Halo <b>${escapeHtml(nama)}</b>,</p>` +
          `<p>Permintaan lupa kata sandi untuk NIP <b>${escapeHtml(nip)}</b> telah diproses.</p>` +
          `<p>Kata sandi baru Anda:</p>` +
          `<p style="font-size:20px;font-family:monospace;letter-spacing:2px;background:#f1f5f9;padding:12px 16px;display:inline-block;border-radius:8px"><b>${escapeHtml(newPass)}</b></p>` +
          `<p>Silakan masuk memakai NIP dan kata sandi di atas, lalu segera ganti kata sandi Anda.<br>` +
          `Jika Anda tidak merasa meminta ini, hubungi Admin.</p>` +
          `<p style="color:#64748b">SIMTAS - Dinas Komunikasi dan Informatika</p>`,
      });
    } catch (e) {
      console.error("forgotPasswordByEmail: gagal kirim email", e);
      throw new HttpsError(
        "internal",
        "Gagal mengirim email. Coba lagi nanti atau hubungi Admin.",
      );
    }

    // 2) Baru ganti sandi di Firebase Auth + sinkronkan metadata.
    try {
      await admin.auth().updateUser(doc.id, { password: newPass });
      await admin.auth().revokeRefreshTokens(doc.id);
      await doc.ref.update({
        email_kontak: repackKontak(data.email_kontak, newPass),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      console.error("forgotPasswordByEmail: gagal set sandi", doc.id, e);
      throw new HttpsError(
        "internal",
        "Gagal memperbarui kata sandi. Hubungi Admin.",
      );
    }

    return { ok: true, message: PESAN_UMUM };
}

exports.forgotPasswordByEmail = onCall(
  { secrets: [smtpUser, smtpPass] },
  async (request) => {
    try {
      return await prosesLupaPassword(request);
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      console.error("forgotPasswordByEmail: error tak terduga", e);
      throw new HttpsError(
        "internal",
        `Kesalahan server (${e.code || e.message || "tidak diketahui"}). Hubungi Admin.`,
      );
    }
  },
);
