import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Exact tokens from Web `styles/index.css` (light) and `theme.css` `[data-theme=dark]`.
@immutable
class EaselPalette extends ThemeExtension<EaselPalette> {
  const EaselPalette({
    required this.isDark,
    required this.primaryBg,
    required this.primaryHoverBg,
    required this.primaryText,
    required this.bg,
    required this.bgElev,
    required this.surface,
    required this.surface2,
    required this.surfaceHover,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.accentStart,
    required this.accentEnd,
    required this.accentSoft,
    required this.green,
    required this.greenSoft,
    required this.amber,
    required this.amberSoft,
    required this.red,
    required this.redSoft,
    required this.codeBg,
    required this.trendUp,
    required this.trendDown,
    required this.layerDiscover,
    required this.layerPlan,
    required this.layerProduce,
    required this.layerPublish,
    required this.layerAttribute,
    required this.layerGeneral,
    required this.sidebarTop,
    required this.sidebarMid,
    required this.sidebarBottom,
    required this.accentGradA,
    required this.accentGradB,
    required this.softGradA,
    required this.softGradB,
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
    required this.washA,
    required this.washB,
    required this.washC,
  });

  final bool isDark;

  final Color primaryBg;
  final Color primaryHoverBg;
  final Color primaryText;
  final Color bg;
  final Color bgElev;
  final Color surface;
  final Color surface2;
  final Color surfaceHover;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color accentStart;
  final Color accentEnd;
  final Color accentSoft;
  final Color green;
  final Color greenSoft;
  final Color amber;
  final Color amberSoft;
  final Color red;
  final Color redSoft;
  final Color codeBg;
  final Color trendUp;
  final Color trendDown;
  final Color layerDiscover;
  final Color layerPlan;
  final Color layerProduce;
  final Color layerPublish;
  final Color layerAttribute;
  final Color layerGeneral;
  final Color sidebarTop;
  final Color sidebarMid;
  final Color sidebarBottom;
  final Color accentGradA;
  final Color accentGradB;
  final Color softGradA;
  final Color softGradB;
  final List<BoxShadow> shadowSm;
  final List<BoxShadow> shadowMd;
  final List<BoxShadow> shadowLg;
  /// Main-content radial washes (center→transparent). Null washC = dark (only 2 washes).
  final Color washA;
  final Color washB;
  final Color? washC;

  /// `:root` in `index.css`
  static const light = EaselPalette(
    isDark: false,
    primaryBg: Color(0xFF17191C),
    primaryHoverBg: Color(0xFF30343B),
    primaryText: Color(0xFFFFFFFF),
    bg: Color(0xFFFFFFFF),
    bgElev: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFFAFAFB),
    surfaceHover: Color(0xFFF2F2F3),
    border: Color(0xFFE7E7E8),
    borderStrong: Color(0xFFD6D7D9),
    text: Color(0xFF17191C),
    textSecondary: Color(0xFF777B86),
    textTertiary: Color(0xFF979799),
    accentStart: Color(0xFF158F9A),
    accentEnd: Color(0xFF3F56A8),
    // rgba(220, 234, 251, 0.72)
    accentSoft: Color(0xB8DCEAFB),
    green: Color(0xFF16A34A),
    // rgba(22, 163, 74, 0.12)
    greenSoft: Color(0x1F16A34A),
    amber: Color(0xFFD97706),
    // rgba(217, 119, 6, 0.14)
    amberSoft: Color(0x24D97706),
    red: Color(0xFFDC2626),
    // rgba(220, 38, 38, 0.10)
    redSoft: Color(0x1ADC2626),
    codeBg: Color(0xFFF4F4F5),
    trendUp: Color(0xFF70A98A),
    trendDown: Color(0xFFC98585),
    layerDiscover: Color(0xFF0EA5E9),
    layerPlan: Color(0xFF7C3AED),
    layerProduce: Color(0xFFDB2777),
    layerPublish: Color(0xFF059669),
    layerAttribute: Color(0xFFD97706),
    layerGeneral: Color(0xFF64748B),
    sidebarTop: Color(0xFFF1F1F3),
    sidebarMid: Color(0xFFF7F7F8),
    sidebarBottom: Color(0xFFFAFAFB),
    accentGradA: Color(0xFF158F9A),
    accentGradB: Color(0xFF3F56A8),
    softGradA: Color(0xFFEAF3FD),
    softGradB: Color(0xFFFBEDE4),
    shadowSm: [BoxShadow(color: Color(0x0D17191C), blurRadius: 3, offset: Offset(0, 1))],
    shadowMd: [BoxShadow(color: Color(0x1417191C), blurRadius: 30, offset: Offset(0, 10))],
    shadowLg: [BoxShadow(color: Color(0x2417191C), blurRadius: 50, offset: Offset(0, 20))],
    // rgba(220,234,251,0.56) / rgba(251,225,209,0.5) / rgba(244,238,224,0.38)
    washA: Color(0x8FDCEAFB),
    washB: Color(0x80FBE1D1),
    washC: Color(0x61F4EEE0),
  );

  /// `:root[data-theme='dark']` in `theme.css`
  static const dark = EaselPalette(
    isDark: true,
    primaryBg: Color(0xFFEDF0F5),
    primaryHoverBg: Color(0xFFCDD6E3),
    primaryText: Color(0xFF14171E),
    bg: Color(0xFF14171E),
    bgElev: Color(0xFF1B2029),
    surface: Color(0xFF1E242E),
    surface2: Color(0xFF252C37),
    surfaceHover: Color(0xFF2D3643),
    border: Color(0xFF333D4B),
    borderStrong: Color(0xFF4A586A),
    text: Color(0xFFEDF0F5),
    textSecondary: Color(0xFFB1BBC9),
    textTertiary: Color(0xFF95A1B3),
    accentStart: Color(0xFF63C9CF),
    accentEnd: Color(0xFFA1B4FA),
    // rgba(115, 151, 222, 0.17)
    accentSoft: Color(0x2B7397DE),
    green: Color(0xFF6BD499),
    // rgba(70, 190, 128, 0.15)
    greenSoft: Color(0x2646BE80),
    amber: Color(0xFFF1BD69),
    // rgba(228, 163, 65, 0.15)
    amberSoft: Color(0x26E4A341),
    red: Color(0xFFF58F98),
    // rgba(233, 102, 115, 0.15)
    redSoft: Color(0x26E96673),
    codeBg: Color(0xFF171C24),
    trendUp: Color(0xFF83CAA3),
    trendDown: Color(0xFFDF969C),
    layerDiscover: Color(0xFF64C6F2),
    layerPlan: Color(0xFFB69AFA),
    layerProduce: Color(0xFFF38DBD),
    layerPublish: Color(0xFF64D3B0),
    layerAttribute: Color(0xFFF1BD69),
    layerGeneral: Color(0xFFA2B3C9),
    // dark sidebar: linear-gradient(180deg, #191e27, #1c222c)
    sidebarTop: Color(0xFF191E27),
    sidebarMid: Color(0xFF1C222C),
    sidebarBottom: Color(0xFF1C222C),
    accentGradA: Color(0xFF167D89),
    accentGradB: Color(0xFF485EB4),
    softGradA: Color(0xFF25364B),
    softGradB: Color(0xFF37303A),
    shadowSm: [BoxShadow(color: Color(0x29000000), blurRadius: 4, offset: Offset(0, 1))],
    shadowMd: [BoxShadow(color: Color(0x3D000000), blurRadius: 30, offset: Offset(0, 10))],
    shadowLg: [BoxShadow(color: Color(0x5C000000), blurRadius: 50, offset: Offset(0, 20))],
    // rgba(55, 87, 133, 0.17) / rgba(117, 76, 67, 0.12)
    washA: Color(0x2B375785),
    washB: Color(0x1F754C43),
    washC: null,
  );

  static EaselPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static EaselPalette of(BuildContext context) {
    final ext = Theme.of(context).extension<EaselPalette>();
    if (ext != null) return ext;
    return forBrightness(Theme.of(context).brightness);
  }

  LinearGradient get accentGradient => LinearGradient(
        begin: const Alignment(-0.707, -0.707),
        end: const Alignment(0.707, 0.707),
        colors: [accentGradA, accentGradB],
      );

  LinearGradient get accentGradientSoft => LinearGradient(
        begin: const Alignment(-0.707, -0.707),
        end: const Alignment(0.707, 0.707),
        colors: [softGradA, softGradB],
      );

  @override
  EaselPalette copyWith({bool? isDark}) => this;

  @override
  EaselPalette lerp(ThemeExtension<EaselPalette>? other, double t) {
    // Snap — never blend light/dark tokens mid-animation.
    if (other is! EaselPalette) return this;
    return t < 0.5 ? this : other;
  }
}

/// Static accessors kept for existing call sites. Always sync via [EaselColors.bind]
/// before building UI (see MaterialApp.builder). Prefer [EaselPalette.of] for new code.
class EaselColors {
  EaselColors._();

  static EaselPalette _p = EaselPalette.dark;

  static void bind(EaselPalette palette) => _p = palette;

  static void applyBrightness(Brightness brightness) =>
      bind(EaselPalette.forBrightness(brightness));

  static bool get isDark => _p.isDark;

  static Color get primaryBg => _p.primaryBg;
  static Color get primaryHoverBg => _p.primaryHoverBg;
  static Color get primaryText => _p.primaryText;
  static Color get bg => _p.bg;
  static Color get bgElev => _p.bgElev;
  static Color get surface => _p.surface;
  static Color get surface2 => _p.surface2;
  static Color get surfaceHover => _p.surfaceHover;
  static Color get border => _p.border;
  static Color get borderStrong => _p.borderStrong;
  static Color get text => _p.text;
  static Color get textSecondary => _p.textSecondary;
  static Color get textTertiary => _p.textTertiary;
  static Color get accentStart => _p.accentStart;
  static Color get accentEnd => _p.accentEnd;
  static Color get accentSoft => _p.accentSoft;
  static Color get green => _p.green;
  static Color get greenSoft => _p.greenSoft;
  static Color get amber => _p.amber;
  static Color get amberSoft => _p.amberSoft;
  static Color get red => _p.red;
  static Color get redSoft => _p.redSoft;
  static Color get codeBg => _p.codeBg;
  static Color get trendUp => _p.trendUp;
  static Color get trendDown => _p.trendDown;
  static Color get layerDiscover => _p.layerDiscover;
  static Color get layerPlan => _p.layerPlan;
  static Color get layerProduce => _p.layerProduce;
  static Color get layerPublish => _p.layerPublish;
  static Color get layerAttribute => _p.layerAttribute;
  static Color get layerGeneral => _p.layerGeneral;
  static Color get sidebarTop => _p.sidebarTop;
  static Color get sidebarMid => _p.sidebarMid;
  static Color get sidebarBottom => _p.sidebarBottom;
  static Color get accentGradA => _p.accentGradA;
  static Color get accentGradB => _p.accentGradB;
  static Color get softGradA => _p.softGradA;
  static Color get softGradB => _p.softGradB;

  static const sidebarWidth = 264.0;
  static const radiusSm = 6.0;
  static const radius = 9.0;
  static const radiusLg = 14.0;
  static const radiusXl = 20.0;

  static LinearGradient get accentGradient => _p.accentGradient;
  static LinearGradient get accentGradientSoft => _p.accentGradientSoft;
  static List<BoxShadow> get shadowSm => _p.shadowSm;
  static List<BoxShadow> get shadowMd => _p.shadowMd;
  static List<BoxShadow> get shadowLg => _p.shadowLg;
}

ThemeData buildEaselTheme(Brightness brightness) {
  final p = EaselPalette.forBrightness(brightness);
  final dark = p.isDark;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.primaryBg,
    onPrimary: p.primaryText,
    primaryContainer: p.accentSoft,
    onPrimaryContainer: p.text,
    secondary: p.accentEnd,
    onSecondary: dark ? p.bg : const Color(0xFFFFFFFF),
    secondaryContainer: dark ? p.surface2 : const Color(0xFFEAF3FD),
    onSecondaryContainer: p.accentEnd,
    tertiary: p.accentStart,
    onTertiary: dark ? p.bg : const Color(0xFFFFFFFF),
    error: p.red,
    onError: dark ? p.bg : const Color(0xFFFFFFFF),
    errorContainer: p.redSoft,
    onErrorContainer: p.red,
    surface: p.surface,
    onSurface: p.text,
    onSurfaceVariant: p.textSecondary,
    outline: p.border,
    outlineVariant: p.borderStrong,
    surfaceContainerHighest: p.surfaceHover,
    surfaceContainerHigh: p.surface2,
    surfaceContainer: p.surface2,
    surfaceContainerLow: p.bgElev,
    surfaceContainerLowest: p.bg,
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: '.AppleSystemUIFont',
    scaffoldBackgroundColor: p.bg,
    colorScheme: scheme,
    applyElevationOverlayColor: false,
    extensions: [p],
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    dividerColor: p.border,
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EaselColors.radiusLg),
        side: BorderSide(color: p.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.bgElev,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EaselColors.radiusXl),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.bgElev,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EaselColors.radius),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EaselColors.radius),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EaselColors.radius),
        borderSide: BorderSide(color: p.accentStart),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EaselColors.radius),
        borderSide: BorderSide(color: p.red),
      ),
      hintStyle: TextStyle(color: p.textTertiary, fontSize: 14),
      labelStyle: TextStyle(color: p.textSecondary, fontSize: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primaryBg,
        foregroundColor: p.primaryText,
        disabledBackgroundColor: p.primaryBg.withValues(alpha: 0.45),
        disabledForegroundColor: p.primaryText.withValues(alpha: 0.7),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EaselColors.radius),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.primaryBg,
        foregroundColor: p.primaryText,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EaselColors.radius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        backgroundColor: p.surface2,
        side: BorderSide(color: p.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EaselColors.radius),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.textSecondary,
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: p.textSecondary),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.primaryBg,
      foregroundColor: p.primaryText,
      elevation: 0,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? p.surface : p.bgElev,
      selectedColor: p.accentSoft,
      disabledColor: p.surfaceHover,
      labelStyle: TextStyle(color: p.textSecondary, fontSize: 13),
      secondaryLabelStyle: TextStyle(color: p.text, fontSize: 13),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: p.border),
      ),
      side: BorderSide(color: p.border),
      checkmarkColor: p.accentEnd,
      deleteIconColor: p.textSecondary,
      showCheckmark: false,
      surfaceTintColor: Colors.transparent,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accentStart,
      linearTrackColor: p.surfaceHover,
      circularTrackColor: p.surfaceHover,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? p.surface2 : p.primaryBg,
      contentTextStyle: TextStyle(color: dark ? p.text : p.primaryText),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EaselColors.radius)),
      behavior: SnackBarBehavior.floating,
    ),
    listTileTheme: ListTileThemeData(iconColor: p.textSecondary, textColor: p.text),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return p.accentStart;
        return p.borderStrong;
      }),
      trackColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return p.accentSoft;
        return p.surfaceHover;
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return p.accentStart;
        return Colors.transparent;
      }),
      checkColor: WidgetStatePropertyAll(dark ? p.bg : Colors.white),
      side: BorderSide(color: p.borderStrong),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: TextStyle(color: p.text),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(p.bgElev),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.bgElev,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: p.text),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(8),
      radius: const Radius.circular(4),
      thumbColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.hovered)) return p.borderStrong;
        return p.border;
      }),
    ),
  );
}

ButtonStyle easelTonalButtonStyle() => FilledButton.styleFrom(
      backgroundColor: EaselColors.accentSoft,
      foregroundColor: EaselColors.accentEnd,
      disabledBackgroundColor: EaselColors.surfaceHover,
      disabledForegroundColor: EaselColors.textTertiary,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EaselColors.radius),
      ),
    );

Decoration mainContentDecoration() => BoxDecoration(color: EaselColors.bg);

/// Paper wash — light: 3 radials + #fff；dark: 2 radials + `--bg` (matches Web CSS).
Widget mainContentBackground({required Widget child}) {
  final p = EaselColors.isDark ? EaselPalette.dark : EaselPalette.light;
  return ColoredBox(
    color: p.bg,
    child: Stack(
      fit: StackFit.expand,
      children: [
        // Isolate expensive gradient paints from content rebuilds.
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.54, -0.84),
                        radius: 1.15,
                        colors: [p.washA, p.washA.withValues(alpha: 0)],
                        stops: p.isDark ? const [0.0, 0.36] : const [0.0, 0.32],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.56, -0.76),
                        radius: 1.2,
                        colors: [p.washB, p.washB.withValues(alpha: 0)],
                        stops: p.isDark ? const [0.0, 0.38] : const [0.0, 0.34],
                      ),
                    ),
                  ),
                  if (p.washC != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.04, 0.84),
                          radius: 1.25,
                          colors: [p.washC!, p.washC!.withValues(alpha: 0)],
                          stops: const [0.0, 0.38],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

Widget navActiveStripe({double width = 3, double height = 18}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      gradient: EaselColors.accentGradient,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}
