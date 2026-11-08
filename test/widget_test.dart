// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_penugasan_kominfo/tugas/location_picker_page.dart';

void main() {
  testWidgets('Location picker shows the map and marker at initial coordinates',
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

    expect(find.byType(FlutterMap), findsOneWidget);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCenter.latitude, -0.494823);
    expect(map.options.initialCenter.longitude, 117.143615);
    final markers = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(markers.markers.single.point.latitude, -0.494823);
    expect(markers.markers.single.point.longitude, 117.143615);
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
