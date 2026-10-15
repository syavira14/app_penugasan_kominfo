import 'package:app_penugasan_kominfo/tugas/tugas_staff_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Staf dengan skema Firebase saat ini dapat dipilih', () {
    final staff = staffFromDocument('staff-uid', {
      'nama': 'gizza',
      'role': 'Staff',
      'uid': 'staff-uid',
      'status_pekerjaan': 'tersedia',
    });
    expect(isSelectableStaff(staff), isTrue);
    expect(staffDisplayName(staff), 'gizza');
    expect(staff['id'], 'staff-uid');
  });

  test(
    'Role dan status dinormalisasi, admin dan staf nonaktif dikecualikan',
    () {
      expect(
        isSelectableStaff({'role': ' staff ', 'status_akun': 'Aktif'}),
        isTrue,
      );
      expect(isSelectableStaff({'role': 'Admin'}), isFalse);
      expect(
        isSelectableStaff({'role': 'Staff', 'status_akun': 'nonaktif'}),
        isFalse,
      );
    },
  );

  test('Relasi memakai UID pengguna dan mendukung dokumen tanpa field UID', () {
    expect(staffFromDocument('doc-id', {'uid': 'auth-uid'})['id'], 'auth-uid');
    expect(staffFromDocument('doc-id', {})['id'], 'doc-id');
    expect(staffFromDocument('doc-id', {'uid': ' '})['id'], 'doc-id');
  });

  test(
    'Pencarian mendukung nama, NIP, email, dan jabatan tanpa beda kapital',
    () {
      final staff = {
        'nama': 'Gizza Putri',
        'nip': '199203152020121001',
        'email': 'staff@gmail.com',
        'jabatan': 'Staff Kominfo',
      };
      for (final query in [
        ' GIZZA ',
        'putri',
        '19920315',
        'GMAIL',
        'kominfo',
        '',
      ]) {
        expect(matchesStaffSearch(staff, query), isTrue, reason: query);
      }
      expect(matchesStaffSearch(staff, 'nama lain'), isFalse);
      expect(matchesStaffSearch({}, 'gizza'), isFalse);
    },
  );

  test('Nama kosong tidak menampilkan UID', () {
    expect(staffDisplayName({'uid': 'auth-uid'}), 'Nama staf belum diisi');
  });
}
