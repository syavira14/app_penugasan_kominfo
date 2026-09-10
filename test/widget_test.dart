// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_penugasan_kominfo/tugas/detail_tugas_admin_page.dart';
import 'package:app_penugasan_kominfo/tugas/location_picker_page.dart';
import 'package:app_penugasan_kominfo/tugas/tugas_model.dart';

void main() {
  testWidgets('Map preview and route action are shown for task with coordinates',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DetailTugasAdminPage(
          tugas: TugasModel(
            id: 'task-1',
            judul: 'Test tugas',
            deskripsi: 'Deskripsi tugas',
            tempat: 'Kantor Dinas Kominfo',
            latitude: -0.494823,
            longitude: 117.143615,
            tanggal: DateTime(2026, 8, 22),
            jam: const TimeOfDay(hour: 9, minute: 0),
            staff: const ['Ahmad Fauzi'],
            prioritas: 'Tinggi',
          ),
        ),
      ),
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is OutlinedButton && widget.onPressed != null,
      ),
      findsWidgets,
    );
  });

  testWidgets('Location picker shows a search field for places',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LocationPickerPage(
          initialTempat: 'Kantor Dinas Kominfo',
          initialLatitude: -0.494823,
          initialLongitude: 117.143615,
        ),
      ),
    );

    expect(find.text('Cari lokasi...'), findsOneWidget);
  });
}
