import 'package:cloud_firestore/cloud_firestore.dart';

Stream<List<Map<String, dynamic>>> streamRiwayatPenugasan({String? staffId}) {
  final firestore = FirebaseFirestore.instance;
  Query<Map<String, dynamic>> query = firestore.collection('penugasan');
  if (staffId != null) query = query.where('staff_id', isEqualTo: staffId);
  return query.snapshots().asyncMap((snapshot) async {
    final tasks = <String, Map<String, dynamic>>{};
    final users = <String, Map<String, dynamic>>{};
    Future<Map<String, dynamic>> user(String id) async {
      if (id.isEmpty) return {};
      return users[id] ??=
          (await firestore.collection('users').doc(id).get()).data() ?? {};
    }

    final result = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final assignment = doc.data();
      if (assignment['status'] != 'disetujui') continue;
      final taskId = (assignment['tugas_id'] ?? '').toString();
      if (taskId.isEmpty) continue;
      final task = tasks[taskId] ??=
          (await firestore.collection('tugas').doc(taskId).get()).data() ?? {};
      final staff = await user((assignment['staff_id'] ?? '').toString());
      final admin = await user((task['dibuat_oleh'] ?? '').toString());
      result.add({
        ...task,
        ...assignment,
        'id': doc.id,
        'nama_staff':
            staff['nama'] ?? assignment['staff_nama'] ?? 'Staf tidak ditemukan',
        'nama_atasan': admin['nama'] ?? 'Atasan',
      });
    }
    result.sort((a, b) {
      final left = a['tanggal_disetujui'] ?? a['updated_at'];
      final right = b['tanggal_disetujui'] ?? b['updated_at'];
      return (right is Timestamp ? right.millisecondsSinceEpoch : 0).compareTo(
        left is Timestamp ? left.millisecondsSinceEpoch : 0,
      );
    });
    return result;
  });
}
