import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/beauty_slider.dart';
import '../camera/camera_controller.dart';
import '../patreon/patreon_paywall_view.dart';
import '../patreon/patreon_provider.dart';
import 'makeup_settings.dart';

class MakeupPanel extends ConsumerWidget {
  const MakeupPanel({super.key});

  static String getStyleName(AppLocalizations l10n, String id, String fallback, {String? category}) {
    final isVi = l10n.localeName.startsWith('vi');
    if (category == 'eyeshadow') {
      switch (id) {
        case 'gradient':
          return isVi ? 'Tán loang' : 'Gradient';
        case 'korean':
          return isVi ? 'Trong trẻo' : 'K-Dewy';
        case 'sheer':
          return isVi ? 'Phủ sương' : 'Soft Sheer';
        case 'shimmer':
          return isVi ? 'Ánh nhũ' : 'Shimmer';
        case 'halo':
          return isVi ? 'Tâm sáng' : 'Halo Glow';
        case 'puppy':
          return isVi ? 'Mắt cún' : 'Puppy Eyes';
        case 'douyin':
          return 'Douyin';
        case 'outerV':
          return isVi ? 'Đuôi V' : 'Outer V';
        case 'cutCrease':
          return isVi ? 'Cắt mí' : 'Cut Crease';
        default:
          return fallback;
      }
    }

    switch (id) {
      case 'full':
        return l10n.styleFull;
      case 'gradient':
        return l10n.styleGradient;
      case 'liner':
        return l10n.styleLiner;
      case 'gloss':
        return l10n.styleGloss;
      case 'apple':
        return l10n.styleApple;
      case 'sunkissed':
        return l10n.styleSunkissed;
      case 'lifted':
        return l10n.styleLifted;
      case 'undereye':
        return l10n.styleUndereye;
      case 'nose_chin':
        return l10n.localeName.startsWith('vi') ? 'Mũi & cằm' : 'Nose & Chin';
      case 'temple_c':
        return l10n.localeName.startsWith('vi') ? 'Thái dương C' : 'C-Temple';
      case 'eyecorner':
        return l10n.localeName.startsWith('vi') ? 'Đuôi mắt' : 'Eye Corner';
      case 'contour':
        return l10n.styleContour;
      case 'natural':
        return l10n.localeName.startsWith('vi') ? 'Tự nhiên' : 'Natural';
      case 'korean':
        return l10n.styleKorean;
      case 'arched':
        return l10n.styleArched;
      case 'feathered':
        return l10n.styleFeathered;
      case 'willow':
        return l10n.styleWillow;
      case 'classic':
        return l10n.styleClassic;
      case 'cat':
        return l10n.styleCat;
      case 'puppy':
        return l10n.stylePuppy;
      case 'fox':
        return l10n.styleFox;
      case 'halo':
        return l10n.styleHalo;
      case 'cutCrease':
        return l10n.styleCutCrease;
      case 'outerV':
        return l10n.styleOuterV;
      case 'douyin':
        return l10n.styleDouyin;
      case 'vShape':
        return l10n.styleVShape;
      case 'sculpted':
        return l10n.styleSculpted;
      case 'nose':
        return l10n.styleNoseContour;
      case 'soft':
        return l10n.styleSoftContour;
      case 'male_natural':
        return l10n.localeName.startsWith('vi') ? 'Tự nhiên' : 'Natural';
      case 'male_sword':
        return l10n.localeName.startsWith('vi') ? 'Dáng kiếm' : 'Sword';
      case 'male_bold':
        return l10n.localeName.startsWith('vi') ? 'Ngang rậm' : 'Bold';
      case 'male_feathered':
        return l10n.localeName.startsWith('vi') ? 'Phẩy sợi' : 'Feathered';
      case 'limbalRing':
        return l10n.lensLimbalRing;
      case 'starburst':
        return l10n.sparkleStarburst;
      case 'galaxy':
        return l10n.sparkleGalaxy;
      case 'starlight':
        return l10n.sparkleStarlight;
      case 'crystal':
        return l10n.sparkleCrystal;
      case 'ring':
        return l10n.sparkleRing;
      case 'heart':
        return l10n.sparkleHeart;
      case 'crescent':
        return l10n.sparkleCrescent;
      case 'pearl':
        return l10n.sparklePearl;
      case 'butterfly':
        return l10n.sparkleButterfly;
      default:
        return fallback;
    }
  }

  static IconData getSparkleIcon(String id) {
    switch (id) {
      case 'natural':
        return Icons.wb_sunny_outlined;
      case 'ring':
        return Icons.panorama_fish_eye;
      case 'crystal':
        return Icons.diamond_outlined;
      case 'heart':
        return Icons.favorite_border;
      case 'crescent':
        return Icons.nightlight_round;
      case 'starburst':
        return Icons.flare;
      case 'galaxy':
        return Icons.grain;
      case 'pearl':
        return Icons.blur_circular;
      case 'butterfly':
        return Icons.filter_vintage_outlined;
      case 'starlight':
      default:
        return Icons.star_border;
    }
  }

  static String getOptionName(AppLocalizations l10n, MakeupOption opt) {
    if (opt.id == 'none') return l10n.none;
    if (l10n.localeName.startsWith('en')) {
      if (opt.name == 'Hồng anh đào') return 'Sakura Pink';
      if (opt.name == 'Đen búp bê') return 'Doll Black';
      const enColorNames = {
        'red': 'Pure Red',
        'ruby': 'Ruby Red',
        'chili': 'Brick Red',
        'cherry': 'Cherry Red',
        'wine': 'Wine',
        'coral': 'Coral',
        'orange': 'Warm Orange',
        'peach': 'Peach Pink',
        'rose': 'Dusty Rose',
        'pink': 'Baby Pink',
        'nude': 'Nude Orange',
        'nudePink': 'Nude Pink',
        'berry': 'Berry',
        'plum': 'Plum',
        'brown': 'Cinnamon',
        'caramel': 'Caramel',
        'rosy': 'Natural Rosy',
        'apricot': 'Apricot',
        'strawberry': 'Strawberry',
        'mauve': 'Mauve',
        'terracotta': 'Terracotta',
        'black': 'Natural Black',
        'darkBrown': 'Dark Brown',
        'natural': 'Natural Brown',
        'chestnut': 'Chestnut',
        'ashBrown': 'Ash Brown',
        'soft': 'Soft Gray',
        'blonde': 'Light Blonde',
        'redBrown': 'Red Brown',
        'classic': 'Soft Black',
        'deepBrown': 'Deep Brown',
        'burgundy': 'Burgundy',
        'navy': 'Navy Blue',
        'white': 'White',
        'earth': 'Earth Brown',
        'sunset': 'Sunset',
        'champagne': 'Champagne',
        'smoky': 'Smoky',
        'dewyPeach': 'Dewy Peach',
        'milkyPink': 'Milky Pink',
        'apricotMilk': 'Apricot Milk',
        'glassCoral': 'Glass Coral',
        'pearlGlow': 'Pearl Glow',
        'berryDew': 'Berry Dew',
        'softMocha': 'Soft Mocha',
        'grapefruit': 'Grapefruit Glow',
        'warm': 'Warm Brown',
        'cool': 'Cool Ash',
        'bronze': 'Bronze',
        'deep': 'Deep Contour',
        'softTaupe': 'Soft Taupe',
        // Contact lenses
        'hazel': 'Hazel Honey',
        'honey': 'Bright Honey',
        'choc': 'Choco Brown',
        'gray': 'Crystal Gray',
        'blue': 'Ocean Blue',
        'aqua': 'Aqua Turquoise',
        'green': 'Emerald Green',
        'violet': 'Amethyst Violet',
        'amber': 'Golden Amber',
        'cosmic_galaxy': 'Cosmic Galaxy',
        'supernova_star': 'Supernova Star',
        'barbie_brown': 'Barbie Brown',
        'cat_eye_gold': 'Cat Eye Gold',
        'midnight_navy': 'Midnight Navy',
        'platinum_silver': 'Platinum Silver',
        // Sparkle options
        'starlight': 'Starlight',
        'crystal': 'Crystal',
        'ring': 'Ring',
        'heart': 'Heart',
        'crescent': 'Crescent',
        'starburst': 'Starburst',
        'galaxy': 'Galaxy',
        'pearl': 'Pearl',
        'butterfly': 'Butterfly',
      };
      return enColorNames[opt.id] ?? opt.name;
    }
    return opt.name;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patreon = ref.watch(patreonProvider);
    if (!patreon.isPatron) {
      return const PatreonPaywallView();
    }

    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);
    final m = state.makeup;
    final subTool = state.activeSubTool;

    final categories = [
      {'id': 'lip', 'label': l10n.makeupLipstick, 'icon': Icons.brush},
      {'id': 'blush', 'label': l10n.makeupBlush, 'icon': Icons.bubble_chart},
      {'id': 'contour', 'label': l10n.makeupContour, 'icon': Icons.tonality},
      {'id': 'eyebrow', 'label': l10n.makeupEyebrow, 'icon': Icons.gesture},
      {'id': 'eyeliner', 'label': l10n.makeupEyeliner, 'icon': Icons.edit},
      {'id': 'eyeshadow', 'label': l10n.makeupEyeshadow, 'icon': Icons.palette},
      {'id': 'lens', 'label': l10n.makeupContactLens, 'icon': Icons.remove_red_eye},
      {'id': 'sparkle', 'label': l10n.makeupEyeSparkle, 'icon': Icons.auto_awesome},
    ];

    List<MakeupOption> activeOptions;
    String activePreset;
    double activeOpacity;
    ValueChanged<String> onSelectPreset;
    ValueChanged<double> onOpacityChanged;

    switch (subTool) {
      case 'blush':
        activeOptions = MakeupPresets.blushOptions;
        activePreset = m.blushPreset;
        activeOpacity = m.blushOpacity;
        onSelectPreset = (id) => controller.updateMakeup(m.copyWith(blushPreset: id));
        onOpacityChanged = (op) => controller.updateMakeup(m.copyWith(blushOpacity: op));
        break;
      case 'contour':
        activeOptions = MakeupPresets.contourOptions;
        activePreset = m.contourPreset;
        activeOpacity = m.contourOpacity;
        onSelectPreset = (id) => controller.updateMakeup(m.copyWith(contourPreset: id));
        onOpacityChanged = (op) => controller.updateMakeup(m.copyWith(contourOpacity: op));
        break;
      case 'eyebrow':
        activeOptions = MakeupPresets.eyebrowOptions;
        activePreset = m.eyebrowPreset;
        activeOpacity = m.eyebrowOpacity;
        onSelectPreset = (id) => controller.updateMakeup(m.copyWith(eyebrowPreset: id));
        onOpacityChanged = (op) => controller.updateMakeup(m.copyWith(eyebrowOpacity: op));
        break;
      case 'eyeliner':
        activeOptions = MakeupPresets.eyelinerOptions;
        activePreset = m.eyelinerPreset;
        activeOpacity = m.eyelinerOpacity;
        onSelectPreset = (id) => controller.updateMakeup(m.copyWith(eyelinerPreset: id));
        onOpacityChanged = (op) => controller.updateMakeup(m.copyWith(eyelinerOpacity: op));
        break;
      case 'eyeshadow':
        activeOptions = MakeupPresets.eyeshadowOptions;
        activePreset = m.eyeshadowPreset;
        activeOpacity = m.eyeshadowOpacity;
        onSelectPreset = (id) => controller.updateMakeup(m.copyWith(eyeshadowPreset: id));
        onOpacityChanged = (op) => controller.updateMakeup(m.copyWith(eyeshadowOpacity: op));
        break;
      case 'lens':
        activeOptions = MakeupPresets.lensOptions;
        activePreset = m.contactLensPreset;
        activeOpacity = m.contactLensOpacity;
        onSelectPreset = (id) => controller.updateMakeup(m.copyWith(contactLensPreset: id));
        onOpacityChanged = (op) => controller.updateMakeup(m.copyWith(contactLensOpacity: op));
        break;
      case 'sparkle':
        activeOptions = MakeupPresets.sparkleOptions;
        activePreset = m.sparklePreset;
        activeOpacity = m.sparkleOpacity;
        onSelectPreset = (id) => controller.updateMakeup(m.copyWith(
          sparklePreset: id,
          sparkleStyle: id == 'none' ? m.sparkleStyle : id,
          sparkleOpacity: (id != 'none' && m.sparkleOpacity == 0) ? 60 : m.sparkleOpacity,
        ));
        onOpacityChanged = (op) => controller.updateMakeup(m.copyWith(sparkleOpacity: op));
        break;
      case 'lip':
      default:
        activeOptions = MakeupPresets.lipOptions;
        activePreset = m.lipPreset;
        activeOpacity = m.lipOpacity;
        onSelectPreset = (id) => controller.updateMakeup(m.copyWith(lipPreset: id));
        onOpacityChanged = (op) => controller.updateMakeup(m.copyWith(lipOpacity: op));
        break;
    }

    String activeCategoryName;
    switch (subTool) {
      case 'blush':
        activeCategoryName = l10n.makeupBlush;
        break;
      case 'contour':
        activeCategoryName = l10n.makeupContour;
        break;
      case 'eyebrow':
        activeCategoryName = l10n.makeupEyebrow;
        break;
      case 'eyeliner':
        activeCategoryName = l10n.makeupEyeliner;
        break;
      case 'eyeshadow':
        activeCategoryName = l10n.makeupEyeshadow;
        break;
      case 'lens':
        activeCategoryName = l10n.makeupContactLens;
        break;
      case 'sparkle':
        activeCategoryName = l10n.makeupEyeSparkle;
        break;
      case 'lip':
      default:
        activeCategoryName = l10n.makeupLipstick;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Category Selector + Opacity Slider
        SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 14),
              // Category Pills
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFF222227),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final cat in categories)
                        GestureDetector(
                          onTap: () => controller.selectSubTool(cat['id'] as String),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: subTool == cat['id']
                                  ? const Color(0xFFFF7597)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              cat['label'] as String,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: subTool == cat['id']
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: subTool == cat['id']
                                    ? Colors.white
                                    : Colors.white60,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Opacity Slider
              Expanded(
                child: activePreset != 'none'
                    ? BeautySlider(
                        label: l10n.makeupIntensity(activeCategoryName),
                        value: activeOpacity,
                        defaultValue: 60,
                        onChanged: onOpacityChanged,
                      )
                    : Center(
                        child: Text(
                          l10n.selectMakeupColorBelow(activeCategoryName),
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Colors.white10),

        // Row 2: Reset Button + Style Chips (if Lip or Blush) + Swatches Bar
        SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: Colors.white54),
                tooltip: l10n.resetMakeupTooltip,
                onPressed: m.isModified ? () => controller.resetMakeup() : null,
              ),

              // Style Chips for Lipstick, Blush, Eyebrow, Eyeliner, Eyeshadow
              if (subTool == 'lip') ...[
                const VerticalDivider(width: 12, indent: 12, endIndent: 12, color: Colors.white12),
                _buildStyleSelector(
                  l10n: l10n,
                  options: MakeupPresets.lipStyles,
                  selectedId: m.lipStyle,
                  onSelect: (id) => controller.updateMakeup(m.copyWith(lipStyle: id)),
                ),
              ] else if (subTool == 'blush') ...[
                const VerticalDivider(width: 12, indent: 12, endIndent: 12, color: Colors.white12),
                _buildStyleSelector(
                  l10n: l10n,
                  options: MakeupPresets.blushStyles,
                  selectedId: m.blushStyle,
                  onSelect: (id) => controller.updateMakeup(m.copyWith(blushStyle: id)),
                ),
              ] else if (subTool == 'contour') ...[
                const VerticalDivider(width: 12, indent: 12, endIndent: 12, color: Colors.white12),
                _buildStyleSelector(
                  l10n: l10n,
                  options: MakeupPresets.contourStyles,
                  selectedId: m.contourStyle,
                  onSelect: (id) => controller.updateMakeup(m.copyWith(contourStyle: id)),
                ),
              ] else if (subTool == 'eyebrow') ...[
                const VerticalDivider(width: 12, indent: 12, endIndent: 12, color: Colors.white12),
                _buildEyebrowGenderAndStyleSelector(
                  l10n: l10n,
                  selectedId: m.eyebrowStyle,
                  onSelect: (id) => controller.updateMakeup(m.copyWith(eyebrowStyle: id)),
                ),
              ] else if (subTool == 'eyeliner') ...[
                const VerticalDivider(width: 12, indent: 12, endIndent: 12, color: Colors.white12),
                _buildStyleSelector(
                  l10n: l10n,
                  options: MakeupPresets.eyelinerStyles,
                  selectedId: m.eyelinerStyle,
                  onSelect: (id) => controller.updateMakeup(m.copyWith(eyelinerStyle: id)),
                ),
              ] else if (subTool == 'eyeshadow') ...[
                const VerticalDivider(width: 12, indent: 12, endIndent: 12, color: Colors.white12),
                _buildStyleSelector(
                  l10n: l10n,
                  options: MakeupPresets.eyeshadowStyles,
                  selectedId: m.eyeshadowStyle,
                  category: 'eyeshadow',
                  onSelect: (id) => controller.updateMakeup(m.copyWith(eyeshadowStyle: id)),
                ),
              ] else if (subTool == 'lens') ...[
                const VerticalDivider(width: 12, indent: 12, endIndent: 12, color: Colors.white12),
                _buildStyleSelector(
                  l10n: l10n,
                  options: MakeupPresets.lensStyles,
                  selectedId: m.contactLensStyle,
                  onSelect: (id) => controller.updateMakeup(m.copyWith(contactLensStyle: id)),
                ),
              ],

              const VerticalDivider(width: 12, indent: 12, endIndent: 12, color: Colors.white12),

              // Preset Color Swatches List
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  itemCount: activeOptions.length,
                  itemBuilder: (context, idx) {
                    final opt = activeOptions[idx];
                    final isSel = opt.id == activePreset;
                    final displayName = getOptionName(l10n, opt);

                    return GestureDetector(
                      onTap: () => onSelectPreset(opt.id),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: opt.id == 'none'
                                    ? const Color(0xFF26262B)
                                    : (subTool == 'sparkle'
                                        ? (isSel ? const Color(0xFFFF7597) : const Color(0xFF26262B))
                                        : opt.color),
                                border: Border.all(
                                  color: isSel ? Colors.white : Colors.white24,
                                  width: isSel ? 2 : 1,
                                ),
                                boxShadow: isSel
                                    ? [
                                        BoxShadow(
                                          color: (opt.id == 'none'
                                                  ? Colors.white
                                                  : (subTool == 'sparkle' ? const Color(0xFFFF7597) : opt.color))
                                              .withValues(alpha: 0.5),
                                          blurRadius: 6,
                                        )
                                      ]
                                    : null,
                              ),
                              child: opt.id == 'none'
                                  ? const Icon(Icons.block, size: 12, color: Colors.white54)
                                  : (subTool == 'lens'
                                      ? ClipOval(
                                          child: Image.asset(
                                            'assets/lenses/lens_${opt.id}.png',
                                            width: 24,
                                            height: 24,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const SizedBox(),
                                          ),
                                        )
                                      : (subTool == 'sparkle'
                                          ? Icon(
                                              getSparkleIcon(opt.id),
                                              size: 13,
                                              color: isSel ? Colors.white : Colors.white70,
                                            )
                                          : null)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 10,
                                color: isSel ? Colors.white : Colors.white60,
                                fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStyleSelector({
    required AppLocalizations l10n,
    required List<MakeupStyleOption> options,
    required String selectedId,
    required ValueChanged<String> onSelect,
    String? category,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF222227),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in options)
              GestureDetector(
                onTap: () => onSelect(opt.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: selectedId == opt.id ? const Color(0xFFFF7597) : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        opt.icon,
                        size: 13,
                        color: selectedId == opt.id ? Colors.white : Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        getStyleName(l10n, opt.id, opt.name, category: category),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: selectedId == opt.id ? FontWeight.w600 : FontWeight.w400,
                          color: selectedId == opt.id ? Colors.white : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEyebrowGenderAndStyleSelector({
    required AppLocalizations l10n,
    required String selectedId,
    required ValueChanged<String> onSelect,
  }) {
    final isMale = MakeupPresets.isMaleEyebrow(selectedId);
    final activeStyles = isMale ? MakeupPresets.maleEyebrowStyles : MakeupPresets.femaleEyebrowStyles;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Gender Switcher: [ ♀ Nữ | ♂ Nam ]
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  if (isMale) onSelect('natural');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: !isMale ? const Color(0xFFFF7597) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.female, size: 13, color: !isMale ? Colors.white : Colors.white60),
                      const SizedBox(width: 2),
                      Text(
                        l10n.localeName.startsWith('vi') ? 'Nữ' : 'Women',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: !isMale ? FontWeight.w600 : FontWeight.w400,
                          color: !isMale ? Colors.white : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (!isMale) onSelect('male_natural');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMale ? const Color(0xFF4A90E2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.male, size: 13, color: isMale ? Colors.white : Colors.white60),
                      const SizedBox(width: 2),
                      Text(
                        l10n.localeName.startsWith('vi') ? 'Nam' : 'Men',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isMale ? FontWeight.w600 : FontWeight.w400,
                          color: isMale ? Colors.white : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _buildStyleSelector(
          l10n: l10n,
          options: activeStyles,
          selectedId: selectedId,
          onSelect: onSelect,
        ),
      ],
    );
  }
}
