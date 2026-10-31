import 'package:app_penugasan_kominfo/services/penugasan_workflow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Alur pengerjaan, revisi berulang, dan persetujuan diizinkan', () {
    final flow = [
      'pending',
      'berlangsung',
      'dikumpulkan',
      'revisi',
      'dikumpulkan',
      'revisi',
      'dikumpulkan',
      'disetujui',
    ];
    for (var i = 1; i < flow.length; i++) {
      expect(canTransitionAssignment(flow[i - 1], flow[i]), isTrue);
    }
  });

  test('Hasil terkunci saat dikumpulkan dan setelah disetujui', () {
    for (final next in [
      'pending',
      'berlangsung',
      'dikumpulkan',
      'terkendala',
    ]) {
      expect(canTransitionAssignment('dikumpulkan', next), isFalse);
    }
    for (final next in [
      'pending',
      'berlangsung',
      'dikumpulkan',
      'revisi',
      'disetujui',
    ]) {
      expect(canTransitionAssignment('disetujui', next), isFalse);
    }
  });

  test('Admin hanya dapat merevisi atau menyetujui hasil yang dikumpulkan', () {
    for (final current in ['pending', 'berlangsung', 'revisi', 'terkendala']) {
      expect(canTransitionAssignment(current, 'disetujui'), isFalse);
      expect(canTransitionAssignment(current, 'revisi'), isFalse);
    }
    expect(canTransitionAssignment('pending', 'dikumpulkan'), isFalse);
    expect(canTransitionAssignment('terkendala', 'berlangsung'), isTrue);
  });

  test(
    'Tugas beberapa staf tetap aktif sampai seluruh penugasan disetujui',
    () {
      expect(assignmentGroupStatus(['disetujui', 'pending']), 'pending');
      expect(
        assignmentGroupStatus(['disetujui', 'berlangsung']),
        'berlangsung',
      );
      expect(
        assignmentGroupStatus(['disetujui', 'dikumpulkan']),
        'dikumpulkan',
      );
      expect(assignmentGroupStatus(['disetujui', 'disetujui']), 'disetujui');
      expect(assignmentGroupStatus([]), 'pending');
    },
  );

  test('Status agregat menonjolkan revisi dan hasil yang perlu diperiksa', () {
    expect(
      assignmentGroupStatus(['berlangsung', 'dikumpulkan']),
      'dikumpulkan',
    );
    expect(assignmentGroupStatus(['dikumpulkan', 'revisi']), 'revisi');
    expect(assignmentGroupStatus(['terkendala', 'pending']), 'terkendala');
  });
}
