import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Beauty Camera'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @resetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset All'**
  String get resetAll;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get languageSystem;

  /// No description provided for @languageVi.
  ///
  /// In en, this message translates to:
  /// **'Tiếng Việt'**
  String get languageVi;

  /// No description provided for @languageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @mirrorPreview.
  ///
  /// In en, this message translates to:
  /// **'Mirror Preview'**
  String get mirrorPreview;

  /// No description provided for @disableBeauty.
  ///
  /// In en, this message translates to:
  /// **'Disable Beauty Effects'**
  String get disableBeauty;

  /// No description provided for @enableBeauty.
  ///
  /// In en, this message translates to:
  /// **'Enable Beauty Effects'**
  String get enableBeauty;

  /// No description provided for @virtualCam.
  ///
  /// In en, this message translates to:
  /// **'Virtual Cam'**
  String get virtualCam;

  /// No description provided for @virtualCamOn.
  ///
  /// In en, this message translates to:
  /// **'Virtual Cam: ON'**
  String get virtualCamOn;

  /// No description provided for @virtualCamSetup.
  ///
  /// In en, this message translates to:
  /// **'Virtual Cam: Setup…'**
  String get virtualCamSetup;

  /// No description provided for @cameraOffline.
  ///
  /// In en, this message translates to:
  /// **'Camera Offline'**
  String get cameraOffline;

  /// No description provided for @camRawBanner.
  ///
  /// In en, this message translates to:
  /// **'RAW CAM (UNFILTERED)'**
  String get camRawBanner;

  /// No description provided for @holdOriginal.
  ///
  /// In en, this message translates to:
  /// **'Hold: Original'**
  String get holdOriginal;

  /// No description provided for @split.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get split;

  /// No description provided for @grantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant Permission'**
  String get grantPermission;

  /// No description provided for @systemSettings.
  ///
  /// In en, this message translates to:
  /// **'System Settings'**
  String get systemSettings;

  /// No description provided for @cameraAccessRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera access required. Click below to grant permission.'**
  String get cameraAccessRequired;

  /// No description provided for @categoryBeauty.
  ///
  /// In en, this message translates to:
  /// **'Beauty'**
  String get categoryBeauty;

  /// No description provided for @categoryReshape.
  ///
  /// In en, this message translates to:
  /// **'Reshape'**
  String get categoryReshape;

  /// No description provided for @categoryMakeup.
  ///
  /// In en, this message translates to:
  /// **'Makeup'**
  String get categoryMakeup;

  /// No description provided for @categoryFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get categoryFilter;

  /// No description provided for @categoryColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get categoryColor;

  /// No description provided for @categoryBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get categoryBackground;

  /// No description provided for @categoryPresets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get categoryPresets;

  /// No description provided for @resetBeautyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset Beauty'**
  String get resetBeautyTooltip;

  /// No description provided for @beautySmooth.
  ///
  /// In en, this message translates to:
  /// **'Smooth'**
  String get beautySmooth;

  /// No description provided for @beautyTexture.
  ///
  /// In en, this message translates to:
  /// **'Texture'**
  String get beautyTexture;

  /// No description provided for @beautySkinTone.
  ///
  /// In en, this message translates to:
  /// **'Skin Tone'**
  String get beautySkinTone;

  /// No description provided for @beautyBrighten.
  ///
  /// In en, this message translates to:
  /// **'Brighten'**
  String get beautyBrighten;

  /// No description provided for @beautyWhitening.
  ///
  /// In en, this message translates to:
  /// **'Whitening'**
  String get beautyWhitening;

  /// No description provided for @beautyTeethWhitening.
  ///
  /// In en, this message translates to:
  /// **'Teeth Whitening'**
  String get beautyTeethWhitening;

  /// No description provided for @beautyRedness.
  ///
  /// In en, this message translates to:
  /// **'Redness'**
  String get beautyRedness;

  /// No description provided for @beautyDarkCircle.
  ///
  /// In en, this message translates to:
  /// **'Dark Circle'**
  String get beautyDarkCircle;

  /// No description provided for @beautyEyeBag.
  ///
  /// In en, this message translates to:
  /// **'Eye Bag'**
  String get beautyEyeBag;

  /// No description provided for @beautyGlassSkin.
  ///
  /// In en, this message translates to:
  /// **'Glass Skin'**
  String get beautyGlassSkin;

  /// No description provided for @sliderSkinSmoothing.
  ///
  /// In en, this message translates to:
  /// **'Skin Smoothing'**
  String get sliderSkinSmoothing;

  /// No description provided for @sliderTexturePreservation.
  ///
  /// In en, this message translates to:
  /// **'Texture Preservation'**
  String get sliderTexturePreservation;

  /// No description provided for @sliderSkinToneIntensity.
  ///
  /// In en, this message translates to:
  /// **'Skin Tone Intensity'**
  String get sliderSkinToneIntensity;

  /// No description provided for @sliderSkinBrightness.
  ///
  /// In en, this message translates to:
  /// **'Skin Brightness'**
  String get sliderSkinBrightness;

  /// No description provided for @sliderSkinWhitening.
  ///
  /// In en, this message translates to:
  /// **'Skin Whitening'**
  String get sliderSkinWhitening;

  /// No description provided for @sliderRednessReduction.
  ///
  /// In en, this message translates to:
  /// **'Redness Reduction'**
  String get sliderRednessReduction;

  /// No description provided for @sliderDarkCircleReduction.
  ///
  /// In en, this message translates to:
  /// **'Dark Circle Reduction'**
  String get sliderDarkCircleReduction;

  /// No description provided for @sliderEyeBagReduction.
  ///
  /// In en, this message translates to:
  /// **'Eye Bag Reduction'**
  String get sliderEyeBagReduction;

  /// No description provided for @sliderGlassSkin.
  ///
  /// In en, this message translates to:
  /// **'Glass Skin Glow'**
  String get sliderGlassSkin;

  /// No description provided for @sliderTeethWhitening.
  ///
  /// In en, this message translates to:
  /// **'Teeth Whitening'**
  String get sliderTeethWhitening;

  /// No description provided for @toneNatural.
  ///
  /// In en, this message translates to:
  /// **'Natural'**
  String get toneNatural;

  /// No description provided for @tonePorcelain.
  ///
  /// In en, this message translates to:
  /// **'Porcelain'**
  String get tonePorcelain;

  /// No description provided for @toneSnow.
  ///
  /// In en, this message translates to:
  /// **'Snow'**
  String get toneSnow;

  /// No description provided for @toneRosy.
  ///
  /// In en, this message translates to:
  /// **'Rosy'**
  String get toneRosy;

  /// No description provided for @toneCherry.
  ///
  /// In en, this message translates to:
  /// **'Cherry'**
  String get toneCherry;

  /// No description provided for @tonePeach.
  ///
  /// In en, this message translates to:
  /// **'Peach'**
  String get tonePeach;

  /// No description provided for @toneCoral.
  ///
  /// In en, this message translates to:
  /// **'Coral'**
  String get toneCoral;

  /// No description provided for @toneWarm.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get toneWarm;

  /// No description provided for @toneHoney.
  ///
  /// In en, this message translates to:
  /// **'Honey'**
  String get toneHoney;

  /// No description provided for @toneWheat.
  ///
  /// In en, this message translates to:
  /// **'Wheat'**
  String get toneWheat;

  /// No description provided for @toneOlive.
  ///
  /// In en, this message translates to:
  /// **'Olive'**
  String get toneOlive;

  /// No description provided for @toneTan.
  ///
  /// In en, this message translates to:
  /// **'Tan'**
  String get toneTan;

  /// No description provided for @resetFaceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset Face'**
  String get resetFaceTooltip;

  /// No description provided for @groupFace.
  ///
  /// In en, this message translates to:
  /// **'Face'**
  String get groupFace;

  /// No description provided for @groupEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Eyebrow'**
  String get groupEyebrow;

  /// No description provided for @groupEyes.
  ///
  /// In en, this message translates to:
  /// **'Eyes'**
  String get groupEyes;

  /// No description provided for @groupNose.
  ///
  /// In en, this message translates to:
  /// **'Nose'**
  String get groupNose;

  /// No description provided for @groupMouth.
  ///
  /// In en, this message translates to:
  /// **'Mouth'**
  String get groupMouth;

  /// No description provided for @reshapeSlimFace.
  ///
  /// In en, this message translates to:
  /// **'Slim Face'**
  String get reshapeSlimFace;

  /// No description provided for @reshapeSmallFace.
  ///
  /// In en, this message translates to:
  /// **'Small Face'**
  String get reshapeSmallFace;

  /// No description provided for @reshapeVFace.
  ///
  /// In en, this message translates to:
  /// **'V Face'**
  String get reshapeVFace;

  /// No description provided for @reshapeJaw.
  ///
  /// In en, this message translates to:
  /// **'Jaw'**
  String get reshapeJaw;

  /// No description provided for @reshapeCheek.
  ///
  /// In en, this message translates to:
  /// **'Cheek'**
  String get reshapeCheek;

  /// No description provided for @reshapeChinLen.
  ///
  /// In en, this message translates to:
  /// **'Chin Len'**
  String get reshapeChinLen;

  /// No description provided for @reshapeChinWid.
  ///
  /// In en, this message translates to:
  /// **'Chin Wid'**
  String get reshapeChinWid;

  /// No description provided for @reshapeForehead.
  ///
  /// In en, this message translates to:
  /// **'Forehead'**
  String get reshapeForehead;

  /// No description provided for @reshapeHairline.
  ///
  /// In en, this message translates to:
  /// **'Hairline'**
  String get reshapeHairline;

  /// No description provided for @reshapeTemple.
  ///
  /// In en, this message translates to:
  /// **'Temple'**
  String get reshapeTemple;

  /// No description provided for @reshapeDoubleChin.
  ///
  /// In en, this message translates to:
  /// **'Double Chin'**
  String get reshapeDoubleChin;

  /// No description provided for @reshapeJawline.
  ///
  /// In en, this message translates to:
  /// **'Jawline'**
  String get reshapeJawline;

  /// No description provided for @reshapeNoseWid.
  ///
  /// In en, this message translates to:
  /// **'Nose Wid'**
  String get reshapeNoseWid;

  /// No description provided for @reshapeNoseBridge.
  ///
  /// In en, this message translates to:
  /// **'Nose Bridge'**
  String get reshapeNoseBridge;

  /// No description provided for @reshapeNoseTip.
  ///
  /// In en, this message translates to:
  /// **'Nose Tip'**
  String get reshapeNoseTip;

  /// No description provided for @reshapeNoseLen.
  ///
  /// In en, this message translates to:
  /// **'Nose Len'**
  String get reshapeNoseLen;

  /// No description provided for @reshapeNostril.
  ///
  /// In en, this message translates to:
  /// **'Nostril'**
  String get reshapeNostril;

  /// No description provided for @reshapeEyeSize.
  ///
  /// In en, this message translates to:
  /// **'Eye Size'**
  String get reshapeEyeSize;

  /// No description provided for @reshapeEyeDist.
  ///
  /// In en, this message translates to:
  /// **'Eye Dist'**
  String get reshapeEyeDist;

  /// No description provided for @reshapeEyeHeight.
  ///
  /// In en, this message translates to:
  /// **'Eye Height'**
  String get reshapeEyeHeight;

  /// No description provided for @reshapeEyeAngle.
  ///
  /// In en, this message translates to:
  /// **'Eye Angle'**
  String get reshapeEyeAngle;

  /// No description provided for @reshapeEyeBrighten.
  ///
  /// In en, this message translates to:
  /// **'Brighten'**
  String get reshapeEyeBrighten;

  /// No description provided for @reshapeEyeSparkle.
  ///
  /// In en, this message translates to:
  /// **'Sparkle'**
  String get reshapeEyeSparkle;

  /// No description provided for @reshapeAegyoSal.
  ///
  /// In en, this message translates to:
  /// **'Smile Eye Bags'**
  String get reshapeAegyoSal;

  /// No description provided for @reshapeEyebrowHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get reshapeEyebrowHeight;

  /// No description provided for @reshapeEyebrowArch.
  ///
  /// In en, this message translates to:
  /// **'Arch'**
  String get reshapeEyebrowArch;

  /// No description provided for @reshapeEyebrowTilt.
  ///
  /// In en, this message translates to:
  /// **'Tilt'**
  String get reshapeEyebrowTilt;

  /// No description provided for @reshapeSmile.
  ///
  /// In en, this message translates to:
  /// **'Smile'**
  String get reshapeSmile;

  /// No description provided for @reshapeSmileCorners.
  ///
  /// In en, this message translates to:
  /// **'Corners'**
  String get reshapeSmileCorners;

  /// No description provided for @reshapeMShapeLips.
  ///
  /// In en, this message translates to:
  /// **'Heart Lips'**
  String get reshapeMShapeLips;

  /// No description provided for @reshapeMouthWid.
  ///
  /// In en, this message translates to:
  /// **'Mouth Wid'**
  String get reshapeMouthWid;

  /// No description provided for @reshapeMouthSize.
  ///
  /// In en, this message translates to:
  /// **'Mouth Size'**
  String get reshapeMouthSize;

  /// No description provided for @reshapeLipThick.
  ///
  /// In en, this message translates to:
  /// **'Lip Thick'**
  String get reshapeLipThick;

  /// No description provided for @reshapeMouthPos.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get reshapeMouthPos;

  /// No description provided for @sliderVLineFace.
  ///
  /// In en, this message translates to:
  /// **'V-Line Face'**
  String get sliderVLineFace;

  /// No description provided for @sliderJawWidth.
  ///
  /// In en, this message translates to:
  /// **'Jaw Width'**
  String get sliderJawWidth;

  /// No description provided for @sliderCheekbones.
  ///
  /// In en, this message translates to:
  /// **'Cheekbones & Contour'**
  String get sliderCheekbones;

  /// No description provided for @sliderChinLength.
  ///
  /// In en, this message translates to:
  /// **'Chin Length'**
  String get sliderChinLength;

  /// No description provided for @sliderChinWidth.
  ///
  /// In en, this message translates to:
  /// **'Chin Width'**
  String get sliderChinWidth;

  /// No description provided for @sliderForeheadHeight.
  ///
  /// In en, this message translates to:
  /// **'Forehead Height'**
  String get sliderForeheadHeight;

  /// No description provided for @sliderHairline.
  ///
  /// In en, this message translates to:
  /// **'Hairline Position'**
  String get sliderHairline;

  /// No description provided for @sliderTemple.
  ///
  /// In en, this message translates to:
  /// **'Temple Filling'**
  String get sliderTemple;

  /// No description provided for @sliderNoseWidth.
  ///
  /// In en, this message translates to:
  /// **'Nose Width'**
  String get sliderNoseWidth;

  /// No description provided for @sliderNoseBridge.
  ///
  /// In en, this message translates to:
  /// **'Nose Bridge'**
  String get sliderNoseBridge;

  /// No description provided for @sliderNoseTip.
  ///
  /// In en, this message translates to:
  /// **'Nose Tip'**
  String get sliderNoseTip;

  /// No description provided for @sliderNoseLength.
  ///
  /// In en, this message translates to:
  /// **'Nose Length'**
  String get sliderNoseLength;

  /// No description provided for @sliderNostrilWidth.
  ///
  /// In en, this message translates to:
  /// **'Nostril Width'**
  String get sliderNostrilWidth;

  /// No description provided for @sliderBigEyes.
  ///
  /// In en, this message translates to:
  /// **'Big Eyes'**
  String get sliderBigEyes;

  /// No description provided for @sliderEyeDistance.
  ///
  /// In en, this message translates to:
  /// **'Eye Distance'**
  String get sliderEyeDistance;

  /// No description provided for @sliderEyeHeight.
  ///
  /// In en, this message translates to:
  /// **'Eye Height'**
  String get sliderEyeHeight;

  /// No description provided for @sliderEyeAngle.
  ///
  /// In en, this message translates to:
  /// **'Eye Angle'**
  String get sliderEyeAngle;

  /// No description provided for @sliderEyeBrightness.
  ///
  /// In en, this message translates to:
  /// **'Eye Brightening'**
  String get sliderEyeBrightness;

  /// No description provided for @sliderSparklingEyes.
  ///
  /// In en, this message translates to:
  /// **'Sparkling Eyes'**
  String get sliderSparklingEyes;

  /// No description provided for @sliderEyebrowHeight.
  ///
  /// In en, this message translates to:
  /// **'Eyebrow Height'**
  String get sliderEyebrowHeight;

  /// No description provided for @sliderEyebrowArch.
  ///
  /// In en, this message translates to:
  /// **'Eyebrow Arch'**
  String get sliderEyebrowArch;

  /// No description provided for @sliderEyebrowTilt.
  ///
  /// In en, this message translates to:
  /// **'Eyebrow Tilt'**
  String get sliderEyebrowTilt;

  /// No description provided for @sliderSmileLift.
  ///
  /// In en, this message translates to:
  /// **'Smile Lift'**
  String get sliderSmileLift;

  /// No description provided for @sliderSmileCorners.
  ///
  /// In en, this message translates to:
  /// **'Smile Corners'**
  String get sliderSmileCorners;

  /// No description provided for @sliderHeartLips.
  ///
  /// In en, this message translates to:
  /// **'Heart / M-Shaped Lips'**
  String get sliderHeartLips;

  /// No description provided for @sliderMouthWidth.
  ///
  /// In en, this message translates to:
  /// **'Mouth Width'**
  String get sliderMouthWidth;

  /// No description provided for @sliderMouthSize.
  ///
  /// In en, this message translates to:
  /// **'Mouth Size'**
  String get sliderMouthSize;

  /// No description provided for @sliderLipThickness.
  ///
  /// In en, this message translates to:
  /// **'Lip Thickness'**
  String get sliderLipThickness;

  /// No description provided for @sliderMouthPosition.
  ///
  /// In en, this message translates to:
  /// **'Mouth Position'**
  String get sliderMouthPosition;

  /// No description provided for @sparkleNatural.
  ///
  /// In en, this message translates to:
  /// **'Natural'**
  String get sparkleNatural;

  /// No description provided for @sparkleStarlight.
  ///
  /// In en, this message translates to:
  /// **'Starlight'**
  String get sparkleStarlight;

  /// No description provided for @sparkleRing.
  ///
  /// In en, this message translates to:
  /// **'Ring'**
  String get sparkleRing;

  /// No description provided for @sparkleCrystal.
  ///
  /// In en, this message translates to:
  /// **'Crystal'**
  String get sparkleCrystal;

  /// No description provided for @resetMakeupTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset Makeup'**
  String get resetMakeupTooltip;

  /// No description provided for @makeupLipstick.
  ///
  /// In en, this message translates to:
  /// **'Lipstick'**
  String get makeupLipstick;

  /// No description provided for @makeupBlush.
  ///
  /// In en, this message translates to:
  /// **'Blush'**
  String get makeupBlush;

  /// No description provided for @makeupEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Eyebrow'**
  String get makeupEyebrow;

  /// No description provided for @makeupEyeliner.
  ///
  /// In en, this message translates to:
  /// **'Eyeliner'**
  String get makeupEyeliner;

  /// No description provided for @makeupEyeshadow.
  ///
  /// In en, this message translates to:
  /// **'Eyeshadow'**
  String get makeupEyeshadow;

  /// No description provided for @makeupContour.
  ///
  /// In en, this message translates to:
  /// **'Contour'**
  String get makeupContour;

  /// No description provided for @makeupIntensity.
  ///
  /// In en, this message translates to:
  /// **'{name} Intensity'**
  String makeupIntensity(String name);

  /// No description provided for @selectMakeupColorBelow.
  ///
  /// In en, this message translates to:
  /// **'Select a {name} color below'**
  String selectMakeupColorBelow(String name);

  /// No description provided for @styleFull.
  ///
  /// In en, this message translates to:
  /// **'Full Lip'**
  String get styleFull;

  /// No description provided for @styleGradient.
  ///
  /// In en, this message translates to:
  /// **'Gradient'**
  String get styleGradient;

  /// No description provided for @styleLiner.
  ///
  /// In en, this message translates to:
  /// **'Lined'**
  String get styleLiner;

  /// No description provided for @styleGloss.
  ///
  /// In en, this message translates to:
  /// **'Glossy'**
  String get styleGloss;

  /// No description provided for @styleApple.
  ///
  /// In en, this message translates to:
  /// **'Apple Cheek'**
  String get styleApple;

  /// No description provided for @styleSunkissed.
  ///
  /// In en, this message translates to:
  /// **'Sun-kissed'**
  String get styleSunkissed;

  /// No description provided for @styleLifted.
  ///
  /// In en, this message translates to:
  /// **'Lifted'**
  String get styleLifted;

  /// No description provided for @styleUndereye.
  ///
  /// In en, this message translates to:
  /// **'Under Eye'**
  String get styleUndereye;

  /// No description provided for @styleContour.
  ///
  /// In en, this message translates to:
  /// **'Contour'**
  String get styleContour;

  /// No description provided for @styleKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean Straight'**
  String get styleKorean;

  /// No description provided for @styleArched.
  ///
  /// In en, this message translates to:
  /// **'Arched'**
  String get styleArched;

  /// No description provided for @styleFeathered.
  ///
  /// In en, this message translates to:
  /// **'Feathered'**
  String get styleFeathered;

  /// No description provided for @styleWillow.
  ///
  /// In en, this message translates to:
  /// **'Willow Leaf'**
  String get styleWillow;

  /// No description provided for @styleClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic Wing'**
  String get styleClassic;

  /// No description provided for @styleCat.
  ///
  /// In en, this message translates to:
  /// **'Cat Eye'**
  String get styleCat;

  /// No description provided for @stylePuppy.
  ///
  /// In en, this message translates to:
  /// **'Puppy Eye'**
  String get stylePuppy;

  /// No description provided for @styleFox.
  ///
  /// In en, this message translates to:
  /// **'Fox Eye'**
  String get styleFox;

  /// No description provided for @styleHalo.
  ///
  /// In en, this message translates to:
  /// **'Halo Eye'**
  String get styleHalo;

  /// No description provided for @styleCutCrease.
  ///
  /// In en, this message translates to:
  /// **'Cut Crease'**
  String get styleCutCrease;

  /// No description provided for @styleOuterV.
  ///
  /// In en, this message translates to:
  /// **'Outer V'**
  String get styleOuterV;

  /// No description provided for @styleDouyin.
  ///
  /// In en, this message translates to:
  /// **'Douyin'**
  String get styleDouyin;

  /// No description provided for @styleVShape.
  ///
  /// In en, this message translates to:
  /// **'V-Line'**
  String get styleVShape;

  /// No description provided for @styleSculpted.
  ///
  /// In en, this message translates to:
  /// **'3D Sculpted'**
  String get styleSculpted;

  /// No description provided for @styleNoseContour.
  ///
  /// In en, this message translates to:
  /// **'Slim Nose'**
  String get styleNoseContour;

  /// No description provided for @styleSoftContour.
  ///
  /// In en, this message translates to:
  /// **'Soft Depth'**
  String get styleSoftContour;

  /// No description provided for @resetColorTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset Color'**
  String get resetColorTooltip;

  /// No description provided for @colorExposure.
  ///
  /// In en, this message translates to:
  /// **'Exposure'**
  String get colorExposure;

  /// No description provided for @colorBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get colorBrightness;

  /// No description provided for @colorContrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get colorContrast;

  /// No description provided for @colorHighlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get colorHighlights;

  /// No description provided for @colorShadows.
  ///
  /// In en, this message translates to:
  /// **'Shadows'**
  String get colorShadows;

  /// No description provided for @colorSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get colorSaturation;

  /// No description provided for @colorTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get colorTemperature;

  /// No description provided for @colorTint.
  ///
  /// In en, this message translates to:
  /// **'Tint'**
  String get colorTint;

  /// No description provided for @colorSharpness.
  ///
  /// In en, this message translates to:
  /// **'Sharpness'**
  String get colorSharpness;

  /// No description provided for @sliderColorTemperature.
  ///
  /// In en, this message translates to:
  /// **'Color Temperature'**
  String get sliderColorTemperature;

  /// No description provided for @sliderColorTint.
  ///
  /// In en, this message translates to:
  /// **'Color Tint'**
  String get sliderColorTint;

  /// No description provided for @sliderDetailSharpness.
  ///
  /// In en, this message translates to:
  /// **'Detail Sharpness'**
  String get sliderDetailSharpness;

  /// No description provided for @filterCatAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterCatAll;

  /// No description provided for @filterCatDouyin.
  ///
  /// In en, this message translates to:
  /// **'Douyin ✨'**
  String get filterCatDouyin;

  /// No description provided for @filterCatNatural.
  ///
  /// In en, this message translates to:
  /// **'Natural'**
  String get filterCatNatural;

  /// No description provided for @filterCatKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get filterCatKorean;

  /// No description provided for @filterCatFilm.
  ///
  /// In en, this message translates to:
  /// **'Film'**
  String get filterCatFilm;

  /// No description provided for @filterCatWarm.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get filterCatWarm;

  /// No description provided for @filterCatCool.
  ///
  /// In en, this message translates to:
  /// **'Cool'**
  String get filterCatCool;

  /// No description provided for @filterCatBW.
  ///
  /// In en, this message translates to:
  /// **'B&W'**
  String get filterCatBW;

  /// No description provided for @filterIntensity.
  ///
  /// In en, this message translates to:
  /// **'{name} Intensity'**
  String filterIntensity(String name);

  /// No description provided for @filterOriginalPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Original • Select a filter preset below'**
  String get filterOriginalPlaceholder;

  /// No description provided for @resetBackgroundTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset Background'**
  String get resetBackgroundTooltip;

  /// No description provided for @bgBlurIntensity.
  ///
  /// In en, this message translates to:
  /// **'Blur Intensity'**
  String get bgBlurIntensity;

  /// No description provided for @bgNonePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'None • Select a background mode below'**
  String get bgNonePlaceholder;

  /// No description provided for @bgModeNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get bgModeNone;

  /// No description provided for @bgModePortraitBlur.
  ///
  /// In en, this message translates to:
  /// **'Portrait Blur'**
  String get bgModePortraitBlur;

  /// No description provided for @bgModeStrongBlur.
  ///
  /// In en, this message translates to:
  /// **'Strong Blur'**
  String get bgModeStrongBlur;

  /// No description provided for @bgModeStudio.
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get bgModeStudio;

  /// No description provided for @bgModeZoomBlur.
  ///
  /// In en, this message translates to:
  /// **'Zoom Blur'**
  String get bgModeZoomBlur;

  /// No description provided for @bgModeSwirlyBokeh.
  ///
  /// In en, this message translates to:
  /// **'Swirly Bokeh'**
  String get bgModeSwirlyBokeh;

  /// No description provided for @bgModeDreamyGlow.
  ///
  /// In en, this message translates to:
  /// **'Dreamy Glow'**
  String get bgModeDreamyGlow;

  /// No description provided for @bgModeMotionBlur.
  ///
  /// In en, this message translates to:
  /// **'Motion Blur'**
  String get bgModeMotionBlur;

  /// No description provided for @activePreset.
  ///
  /// In en, this message translates to:
  /// **'Active Preset: {name}'**
  String activePreset(String name);

  /// No description provided for @customSettingsActive.
  ///
  /// In en, this message translates to:
  /// **'Custom Settings Active'**
  String get customSettingsActive;

  /// No description provided for @saveCurrent.
  ///
  /// In en, this message translates to:
  /// **'Save Current'**
  String get saveCurrent;

  /// No description provided for @saveCustomPreset.
  ///
  /// In en, this message translates to:
  /// **'Save Custom Preset'**
  String get saveCustomPreset;

  /// No description provided for @presetNameHint.
  ///
  /// In en, this message translates to:
  /// **'Preset Name (e.g. My Glow)'**
  String get presetNameHint;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Beauty Camera Settings'**
  String get settingsTitle;

  /// No description provided for @captureFormatFramerate.
  ///
  /// In en, this message translates to:
  /// **'Capture Format & Framerate'**
  String get captureFormatFramerate;

  /// No description provided for @virtualCameraHeader.
  ///
  /// In en, this message translates to:
  /// **'Virtual Camera (CoreMediaIO)'**
  String get virtualCameraHeader;

  /// No description provided for @virtualDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Virtual Device Name: '**
  String get virtualDeviceName;

  /// No description provided for @virtualCamActive.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get virtualCamActive;

  /// No description provided for @virtualCamStandby.
  ///
  /// In en, this message translates to:
  /// **'STANDBY'**
  String get virtualCamStandby;

  /// No description provided for @virtualCamDescription.
  ///
  /// In en, this message translates to:
  /// **'When enabled, select \"Beauty Camera\" in Zoom, Google Meet, OBS, Discord, Telegram, or Microsoft Teams to use your beautified video stream directly.'**
  String get virtualCamDescription;

  /// No description provided for @hardwarePipelineStats.
  ///
  /// In en, this message translates to:
  /// **'Hardware & Pipeline Stats'**
  String get hardwarePipelineStats;

  /// No description provided for @statFps.
  ///
  /// In en, this message translates to:
  /// **'FPS'**
  String get statFps;

  /// No description provided for @statProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get statProcessing;

  /// No description provided for @statTracking.
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get statTracking;

  /// No description provided for @statDropped.
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get statDropped;

  /// No description provided for @statResolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get statResolution;

  /// No description provided for @softwareUpdate.
  ///
  /// In en, this message translates to:
  /// **'Software Update'**
  String get softwareUpdate;

  /// No description provided for @updateCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get updateCheck;

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get updateChecking;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'New Version Available'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is ready to install.'**
  String updateAvailableSubtitle(String version);

  /// No description provided for @updateCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version: {version}'**
  String updateCurrentVersion(String version);

  /// No description provided for @updateLatest.
  ///
  /// In en, this message translates to:
  /// **'You are on the latest version ({version})'**
  String updateLatest(String version);

  /// No description provided for @updateReleaseNotes.
  ///
  /// In en, this message translates to:
  /// **'Release Notes'**
  String get updateReleaseNotes;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update...'**
  String get updateDownloading;

  /// No description provided for @updateInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing and restarting...'**
  String get updateInstalling;

  /// No description provided for @updateError.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String updateError(String error);

  /// No description provided for @updateCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get updateCancel;

  /// No description provided for @patreonTitle.
  ///
  /// In en, this message translates to:
  /// **'Patreon Membership'**
  String get patreonTitle;

  /// No description provided for @patreonLogin.
  ///
  /// In en, this message translates to:
  /// **'Login with Patreon'**
  String get patreonLogin;

  /// No description provided for @patreonLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get patreonLogout;

  /// No description provided for @patreonCheck.
  ///
  /// In en, this message translates to:
  /// **'Check Membership'**
  String get patreonCheck;

  /// No description provided for @patreonChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking status...'**
  String get patreonChecking;

  /// No description provided for @patreonActive.
  ///
  /// In en, this message translates to:
  /// **'Active Patron'**
  String get patreonActive;

  /// No description provided for @patreonInactive.
  ///
  /// In en, this message translates to:
  /// **'No Active Membership'**
  String get patreonInactive;

  /// No description provided for @patreonNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not Connected'**
  String get patreonNotConnected;

  /// No description provided for @patreonSupportProject.
  ///
  /// In en, this message translates to:
  /// **'Support on Patreon'**
  String get patreonSupportProject;

  /// No description provided for @patreonConfig.
  ///
  /// In en, this message translates to:
  /// **'OAuth Settings'**
  String get patreonConfig;

  /// No description provided for @patreonTestMode.
  ///
  /// In en, this message translates to:
  /// **'Test Mode (VIP)'**
  String get patreonTestMode;

  /// No description provided for @patreonTestModeActive.
  ///
  /// In en, this message translates to:
  /// **'VIP Test Mode Active'**
  String get patreonTestModeActive;

  /// No description provided for @patreonLoggedAs.
  ///
  /// In en, this message translates to:
  /// **'Logged in as: {name}'**
  String patreonLoggedAs(String name);

  /// No description provided for @patreonPledgedAmount.
  ///
  /// In en, this message translates to:
  /// **'Pledge: {amount}/mo'**
  String patreonPledgedAmount(String amount);

  /// No description provided for @patreonRecheckSuccess.
  ///
  /// In en, this message translates to:
  /// **'Status updated: {status}'**
  String patreonRecheckSuccess(String status);

  /// No description provided for @makeupLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Makeup — Patreon Supporter Exclusive'**
  String get makeupLockedTitle;

  /// No description provided for @makeupLockedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Support us on Patreon to unlock full Lipstick, Blush, Eyebrows, Eyeliner, Eyeshadow, and Contour features!'**
  String get makeupLockedSubtitle;

  /// No description provided for @makeupVipBadge.
  ///
  /// In en, this message translates to:
  /// **'Patreon VIP'**
  String get makeupVipBadge;

  /// No description provided for @patreonOpenBrowserPrompt.
  ///
  /// In en, this message translates to:
  /// **'Opening browser to authorize with Patreon. Please grant access and return to Beauty Camera.'**
  String get patreonOpenBrowserPrompt;

  /// No description provided for @patreonLoginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Patreon login successful!'**
  String get patreonLoginSuccess;

  /// No description provided for @patreonLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Patreon login failed: {error}'**
  String patreonLoginFailed(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
