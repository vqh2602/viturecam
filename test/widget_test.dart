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
    expect(find.text('Skin Tone'), findsOneWidget);
    expect(find.text('Skin Smoothing'), findsOneWidget);

    // Tap Skin Tone tool
    await tester.tap(find.text('Skin Tone'));
    await tester.pump();
    expect(find.text('Tự nhiên'), findsOneWidget);
    expect(find.text('Trắng sứ'), findsOneWidget);
    expect(find.text('Bánh mật'), findsOneWidget);

    // Tap on Reshape category
    await tester.tap(find.text('Reshape'));
    await tester.pump();
    expect(find.text('Slim Face'), findsWidgets);
    expect(find.text('V Face'), findsOneWidget);

    // Switch to Mouth group
    await tester.tap(find.text('Miệng'));
    await tester.pump();
    expect(find.text('Khóe cười'), findsOneWidget);
    await tester.tap(find.text('Khóe cười'));
    await tester.pump();
    expect(find.text('Khóe cười (Smile Corners)'), findsOneWidget);

    expect(find.text('Môi chữ M'), findsOneWidget);
    await tester.tap(find.text('Môi chữ M'));
    await tester.pump();
    expect(find.text('Môi chữ M / Trái tim (Heart Lips)'), findsOneWidget);

    // Tap on Makeup category
    await tester.tap(find.text('Makeup'));
    await tester.pump();
    expect(find.text('Lipstick'), findsWidgets);
    expect(find.text('Blush'), findsOneWidget);
    expect(find.text('Son bóng'), findsOneWidget);
    expect(find.text('Lòng môi'), findsOneWidget);
    expect(find.text('Viền môi'), findsOneWidget);

    // Tap Blush tool
    await tester.tap(find.text('Blush'));
    await tester.pump();
    expect(find.text('Gò má tròn'), findsOneWidget);
    expect(find.text('Say rượu'), findsOneWidget);
    expect(find.text('Kéo thái dương'), findsOneWidget);

    // Tap on Filter category
    await tester.tap(find.text('Filter'));
    await tester.pump();
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('Hàn Quốc'), findsOneWidget);
    expect(find.text('Film'), findsWidgets);
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);

    // Tap on Color category
    await tester.tap(find.text('Color'));
    await tester.pump();
    expect(find.text('Exposure'), findsWidgets);
    expect(find.text('Brightness'), findsOneWidget);

    // Tap on Background category
    await tester.tap(find.text('Background'));
    await tester.pump();
    expect(find.text('Portrait Blur'), findsOneWidget);

    // Tap on Presets category
    await tester.tap(find.text('Presets'));
    await tester.pump();
    expect(find.text('Save Current'), findsOneWidget);
  });

  testWidgets('Bottom dock maintains strictly fixed height across all tab switches', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: BeautyCameraApp(),
      ),
    );
    await tester.pump();

    final dockFinder = find.byWidgetPredicate(
      (w) => w is Container && w.constraints?.maxHeight == 168.0,
    );
    expect(dockFinder, findsOneWidget);

    final tabs = ['Beauty', 'Reshape', 'Makeup', 'Filter', 'Color', 'Background', 'Presets'];
    for (final tab in tabs) {
      await tester.tap(find.text(tab));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'Tab $tab caused layout exception');
      final size = tester.getSize(dockFinder);
      expect(size.height, equals(168.0), reason: 'Dock height must be 168.0 for tab $tab');
    }
  });
}
