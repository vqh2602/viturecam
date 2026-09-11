import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viturecam/app/app.dart';

void main() {
  testWidgets('BeautyCameraApp renders top bar and beauty toolbar', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: BeautyCameraApp(),
      ),
    );

    // Initial frame
    await tester.pump();

    // Verify Brand title
    expect(find.text('Beauty Camera'), findsWidgets);

    // Verify Main Categories
    expect(find.text('Beauty'), findsOneWidget);
    expect(find.text('Reshape'), findsOneWidget);
    expect(find.text('Makeup'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Color'), findsOneWidget);
    expect(find.text('Background'), findsOneWidget);
    expect(find.text('Presets'), findsOneWidget);

    // Verify Initial Sub-tools
    expect(find.text('Smooth'), findsOneWidget);
    expect(find.text('Texture'), findsOneWidget);
    expect(find.text('Skin Smoothing'), findsOneWidget);

    // Tap on Reshape category
    await tester.tap(find.text('Reshape'));
    await tester.pump();

    // Verify Reshape subtools appear
    expect(find.text('Slim Face'), findsWidgets);
    expect(find.text('V Face'), findsOneWidget);

    // Tap on Filter category
    await tester.tap(find.text('Filter'));
    await tester.pump();

    // Verify Filters appear
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
  });
}
