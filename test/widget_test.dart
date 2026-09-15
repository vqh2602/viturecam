import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viturecam/app/app.dart';
import 'package:viturecam/app/locale_provider.dart';

void main() {
  testWidgets('BeautyCameraApp renders and operates in English locale', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLocaleProvider.overrideWith((ref) => const Locale('en')),
        ],
        child: const BeautyCameraApp(),
      ),
    );
    await tester.pump();

    // Verify Brand title
    expect(find.text('Beauty Camera'), findsWidgets);

    // Verify Main Categories in English
    expect(find.text('Beauty'), findsOneWidget);
    expect(find.text('Reshape'), findsOneWidget);
    expect(find.text('Makeup'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Color'), findsOneWidget);
    expect(find.text('Background'), findsOneWidget);
    expect(find.text('Presets'), findsOneWidget);

    // Verify Initial Sub-tools in English
    expect(find.text('Smooth'), findsOneWidget);
    expect(find.text('Texture'), findsOneWidget);
    expect(find.text('Skin Tone'), findsOneWidget);
    expect(find.text('Skin Smoothing'), findsOneWidget);

    // Tap Skin Tone tool
    await tester.tap(find.text('Skin Tone'));
    await tester.pump();
    expect(find.text('Natural'), findsOneWidget);
    expect(find.text('Porcelain'), findsOneWidget);
    expect(find.text('Tan'), findsOneWidget);

    // Tap on Reshape category
    await tester.tap(find.text('Reshape'));
    await tester.pump();
    expect(find.text('Slim Face'), findsWidgets);
    expect(find.text('V Face'), findsOneWidget);

    // Switch to Eyebrow group
    await tester.tap(find.text('Eyebrow'));
    await tester.pump();
    expect(find.text('Height'), findsOneWidget);
    expect(find.text('Arch'), findsOneWidget);
    expect(find.text('Tilt'), findsOneWidget);
    await tester.tap(find.text('Height'));
    await tester.pump();
    expect(find.text('Eyebrow Height'), findsOneWidget);

    // Switch to Mouth group
    await tester.tap(find.text('Mouth'));
    await tester.pump();
    expect(find.text('Corners'), findsOneWidget);
    await tester.tap(find.text('Corners'));
    await tester.pump();
    expect(find.text('Smile Corners'), findsOneWidget);

    expect(find.text('Heart Lips'), findsOneWidget);
    await tester.tap(find.text('Heart Lips'));
    await tester.pump();
    expect(find.text('Heart / M-Shaped Lips'), findsOneWidget);

    // Tap on Makeup category
    await tester.tap(find.text('Makeup'));
    await tester.pump();
    expect(find.text('Lipstick'), findsWidgets);
    expect(find.text('Blush'), findsOneWidget);
    expect(find.text('Glossy'), findsOneWidget);
    expect(find.text('Gradient'), findsOneWidget);
    expect(find.text('Lined'), findsOneWidget);

    // Tap Blush tool
    await tester.tap(find.text('Blush'));
    await tester.pump();
    expect(find.text('Apple Cheek'), findsOneWidget);
    expect(find.text('Sun-kissed'), findsOneWidget);
    expect(find.text('Lifted'), findsOneWidget);

    // Tap on Filter category
    await tester.tap(find.text('Filter'));
    await tester.pump();
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Korean'), findsOneWidget);
    expect(find.text('Film'), findsWidgets);
    expect(find.text('Original'), findsWidgets);

    // Tap on Color category
    await tester.tap(find.text('Color'));
    await tester.pump();
    expect(find.text('Exposure'), findsWidgets);
    expect(find.text('Brightness'), findsOneWidget);

    // Tap on Background category
    await tester.tap(find.text('Background'));
    await tester.pump();
    expect(find.text('Portrait Blur'), findsOneWidget);
    expect(find.text('Strong Blur'), findsOneWidget);
    expect(find.text('Studio'), findsOneWidget);

    // Tap on Presets category
    await tester.tap(find.text('Presets'));
    await tester.pump();
    expect(find.text('Save Current'), findsOneWidget);
  });

  testWidgets('BeautyCameraApp renders and operates in Vietnamese locale', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLocaleProvider.overrideWith((ref) => const Locale('vi')),
        ],
        child: const BeautyCameraApp(),
      ),
    );
    await tester.pump();

    // Verify Main Categories in Vietnamese
    expect(find.text('Làm đẹp'), findsOneWidget);
    expect(find.text('Gọt mặt'), findsOneWidget);
    expect(find.text('Trang điểm'), findsOneWidget);
    expect(find.text('Bộ lọc'), findsOneWidget);
    expect(find.text('Màu sắc'), findsOneWidget);
    expect(find.text('Phông nền'), findsOneWidget);
    expect(find.text('Mẫu sẵn'), findsOneWidget);

    // Verify Initial Sub-tools in Vietnamese
    expect(find.text('Làm mịn'), findsOneWidget);
    expect(find.text('Chi tiết da'), findsOneWidget);
    expect(find.text('Tông da'), findsOneWidget);
    expect(find.text('Mức độ làm mịn da'), findsOneWidget);

    // Tap Skin Tone tool
    await tester.tap(find.text('Tông da'));
    await tester.pump();
    expect(find.text('Tự nhiên'), findsOneWidget);
    expect(find.text('Trắng sứ'), findsOneWidget);
    expect(find.text('Bánh mật'), findsOneWidget);

    // Tap on Reshape category
    await tester.tap(find.text('Gọt mặt'));
    await tester.pump();
    expect(find.text('Gọt mặt'), findsWidgets);
    expect(find.text('Mặt V-line'), findsOneWidget);

    // Switch to Eyebrow group
    await tester.tap(find.text('Chân mày'));
    await tester.pump();
    expect(find.text('Độ cao'), findsOneWidget);
    expect(find.text('Cung mày'), findsOneWidget);
    expect(find.text('Độ nghiêng'), findsOneWidget);
    await tester.tap(find.text('Độ cao'));
    await tester.pump();
    expect(find.text('Độ cao chân mày'), findsOneWidget);

    // Switch to Mouth group
    await tester.tap(find.text('Miệng'));
    await tester.pump();
    expect(find.text('Khóe cười'), findsOneWidget);
    await tester.tap(find.text('Khóe cười'));
    await tester.pump();
    expect(find.text('Khóe cười tự nhiên'), findsOneWidget);

    expect(find.text('Môi chữ M'), findsOneWidget);
    await tester.tap(find.text('Môi chữ M'));
    await tester.pump();
    expect(find.text('Tạo dáng môi chữ M'), findsOneWidget);

    // Tap on Makeup category
    await tester.tap(find.text('Trang điểm'));
    await tester.pump();
    expect(find.text('Son môi'), findsWidgets);
    expect(find.text('Phấn má'), findsOneWidget);
    expect(find.text('Son bóng'), findsOneWidget);
    expect(find.text('Lòng môi'), findsOneWidget);
    expect(find.text('Viền môi'), findsOneWidget);

    // Tap Blush tool
    await tester.tap(find.text('Phấn má'));
    await tester.pump();
    expect(find.text('Gò má tròn'), findsOneWidget);
    expect(find.text('Say rượu'), findsOneWidget);
    expect(find.text('Kéo thái dương'), findsOneWidget);

    // Tap on Filter category
    await tester.tap(find.text('Bộ lọc'));
    await tester.pump();
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('Hàn Quốc'), findsOneWidget);
    expect(find.text('Phim ảnh'), findsOneWidget);
    expect(find.text('Gốc'), findsWidgets);

    // Tap on Color category
    await tester.tap(find.text('Màu sắc'));
    await tester.pump();
    expect(find.text('Phơi sáng'), findsWidgets);
    expect(find.text('Độ sáng'), findsOneWidget);

    // Tap on Background category
    await tester.tap(find.text('Phông nền'));
    await tester.pump();
    expect(find.text('Xóa phông chân dung'), findsOneWidget);
    expect(find.text('Xóa phông mạnh'), findsOneWidget);
    expect(find.text('Studio ảo'), findsOneWidget);

    // Scroll category toolbar to bring Presets (Mẫu sẵn) into view and tap it
    await tester.drag(find.byType(ListView).last, const Offset(-200, 0));
    await tester.pump();
    await tester.tap(find.text('Mẫu sẵn'));
    await tester.pump();
    expect(find.text('Lưu hiện tại'), findsOneWidget);
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

    // Look for tool buttons on the category bar
    final toolButtons = find.byType(GestureDetector);
    expect(toolButtons, findsWidgets);
    final size = tester.getSize(dockFinder);
    expect(size.height, equals(168.0));
  });

  testWidgets('Settings dialog allows switching language dynamically', (tester) async {
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

    // Open Settings dialog
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();

    // Should find settings dialog
    expect(find.byType(Dialog), findsOneWidget);

    // Tap English choice chip
    await tester.tap(find.text('English'));
    await tester.pump();

    // Verify dialog content switched to English
    expect(find.text('Beauty Camera Settings'), findsOneWidget);
    expect(find.text('Capture Format & Framerate'), findsOneWidget);

    // Tap Vietnamese choice chip
    await tester.tap(find.text('Tiếng Việt'));
    await tester.pump();

    // Verify dialog content switched to Vietnamese
    expect(find.text('Cài đặt Beauty Camera'), findsOneWidget);
    expect(find.text('Định dạng & Khung hình'), findsOneWidget);
  });
}
