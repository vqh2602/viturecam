import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/camera/camera_screen.dart';
import '../l10n/app_localizations.dart';
import 'locale_provider.dart';
import 'theme.dart';

class BeautyCameraApp extends ConsumerWidget {
  const BeautyCameraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(appLocaleProvider);

    return MaterialApp(
      title: 'Beauty Camera',
      debugShowCheckedModeBanner: false,
      theme: BeautyAppTheme.darkTheme,
      locale: currentLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CameraScreen(),
    );
  }
}
