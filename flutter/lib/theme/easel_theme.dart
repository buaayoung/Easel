import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tokens mirrored from web `theme.css` `:root[data-theme='dark']`
/// （Web 用户当前界面是暗色；Flutter 默认对齐这套，而不是浅色 index.css）。
class EaselColors {
  // ---- Dark palette ----
  static const primaryBg = Color(0xFFEDF0F5);
  static const primaryHoverBg = Color(0xFFCDD6E3);
  static const primaryText = Color(0xFF14171E);

  static const bg = Color(0xFF14171E);
  static const bgElev = Color(0xFF1B2029);
  static const surface = Color(0xFF1E242E);
  static const surface2 = Color(0xFF252C37);
  static const surfaceHover = Color(0xFF2D3643);
  static const border = Color(0xFF333D4B);
  static const borderStrong = Color(0xFF4A586A);

  static const text = Color(0xFFEDF0F5);
  static const textSecondary = Color(0xFFB1BBC9);
  static const textTertiary = Color(0xFF95A1B3);

  static const accentStart = Color(0xFF63C9CF);
  static const accentEnd = Color(0xFFA1B4FA);
  /// rgba(115, 151, 222, 0.17)
  static const accentSoft = Color(0x2B7397DE);

  static const green = Color(0xFF6BD499);
  static const greenSoft = Color(0x2646BE80);
  static const amber = Color(0xFFF1BD69);
  static const amberSoft = Color(0x26E4A341);
  static const red = Color(0xFFF58F98);
  static const redSoft = Color(0x26E96673);
  static const codeBg = Color(0xFF171C24);

  static const trendUp = Color(0xFF83CAA3);
  static const trendDown = Color(0xFFDF969C);

  static const layerDiscover = Color(0xFF64C6F2);
  static const layerPlan = Color(0xFFB69AFA);
  static const layerProduce = Color(0xFFF38DBD);
  static const layerPublish = Color(0xFF64D3B0);
  static const layerAttribute = Color(0xFFF1BD69);
  static const layerGeneral = Color(0xFFA2B3C9);

  /// Sidebar dark gradient stops
  static const sidebarTop = Color(0xFF191E27);
  static const sidebarMid = Color(0xFF1C222C);
  static const sidebarBottom = Color(0xFF1C222C);

  static const accentGradA = Color(0xFF167D89);
  static const accentGradB = Color(0xFF485EB4);
  static const softGradA = Color(0xFF25364B);
  static const softGradB = Color(0xFF37303A);

  static const sidebarWidth = 264.0;
  static const radiusSm = 6.0;
  static const radius = 9.0;
  static const radiusLg = 14.0;
  static const radiusXl = 20.0;

  static const accentGradient = LinearGradient(
    begin: Alignment(-0.8, -0.8),
    end: Alignment(0.9, 0.9),
    colors: [accentGradA, accentGradB],
  );

  static const accentGradientSoft = LinearGradient(
    begin: Alignment(-0.8, -0.8),
    end: Alignment(0.9, 0.9),
    colors: [softGradA, softGradB],
  );

  static List<BoxShadow> get shadowSm => const [
        BoxShadow(color: Color(0x29000000), blurRadius: 4, offset: Offset(0, 1)),
      ];

  static List<BoxShadow> get shadowMd => const [
        BoxShadow(color: Color(0x3D000000), blurRadius: 30, offset: Offset(0, 10)),
      ];

  static List<BoxShadow> get shadowLg => const [
        BoxShadow(color: Color(0x5C000000), blurRadius: 50, offset: Offset(0, 20)),
      ];
}

ThemeData buildEaselTheme() {
  final scheme = ColorScheme.dark(
    primary: EaselColors.primaryBg,
    onPrimary: EaselColors.primaryText,
    primaryContainer: EaselColors.accentSoft,
    onPrimaryContainer: EaselColors.text,
    secondary: EaselColors.accentEnd,
    onSecondary: EaselColors.bg,
    secondaryContainer: EaselColors.surface2,
    onSecondaryContainer: EaselColors.accentEnd,
    tertiary: EaselColors.accentStart,
    onTertiary: EaselColors.bg,
    surface: EaselColors.surface,
    onSurface: EaselColors.text,
    onSurfaceVariant: EaselColors.textSecondary,
    error: EaselColors.red,
    onError: EaselColors.bg,
    errorContainer: EaselColors.redSoft,
    onErrorContainer: EaselColors.red,
    outline: EaselColors.border,
    outlineVariant: EaselColors.borderStrong,
    surfaceContainerHighest: EaselColors.surfaceHover,
    surfaceContainerHigh: EaselColors.surface2,
    surfaceContainer: EaselColors.surface2,
    surfaceContainerLow: EaselColors.bgElev,
    surfaceContainerLowest: EaselColors.bg,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: '.AppleSystemUIFont',
    scaffoldBackgroundColor: EaselColors.bg,
    colorScheme: scheme,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: EaselColors.text,
      displayColor: EaselColors.text,
    ),
    dividerColor: EaselColors.border,
    dividerTheme: const DividerThemeData(color: EaselColors.border, thickness: 1, space: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: EaselColors.bg,
      foregroundColor: EaselColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    cardTheme: CardThemeData(
      color: EaselColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EaselColors.radiusLg),
        side: const BorderSide(color: EaselColors.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: EaselColors.bgElev,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EaselColors.radiusXl),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: EaselColors.bgElev,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EaselColors.radius),
        borderSide: const BorderSide(color: EaselColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EaselColors.radius),
        borderSide: const BorderSide(color: EaselColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EaselColors.radius),
        borderSide: const BorderSide(color: EaselColors.accentStart),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EaselColors.radius),
        borderSide: const BorderSide(color: EaselColors.red),
      ),
      hintStyle: const TextStyle(color: EaselColors.textTertiary, fontSize: 14),
      labelStyle: const TextStyle(color: EaselColors.textSecondary, fontSize: 13),
    ),
    // Dark-theme primary CTA = light fill / dark text（截图里「新建画像」白钮）
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: EaselColors.primaryBg,
        foregroundColor: EaselColors.primaryText,
        disabledBackgroundColor: EaselColors.primaryBg.withValues(alpha: 0.45),
        disabledForegroundColor: EaselColors.primaryText.withValues(alpha: 0.7),
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
        backgroundColor: EaselColors.primaryBg,
        foregroundColor: EaselColors.primaryText,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EaselColors.radius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: EaselColors.text,
        backgroundColor: EaselColors.surface2,
        side: const BorderSide(color: EaselColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EaselColors.radius),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: EaselColors.textSecondary,
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: EaselColors.textSecondary),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: EaselColors.primaryBg,
      foregroundColor: EaselColors.primaryText,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: EaselColors.surface,
      selectedColor: EaselColors.accentSoft,
      disabledColor: EaselColors.surfaceHover,
      labelStyle: const TextStyle(color: EaselColors.textSecondary, fontSize: 13),
      secondaryLabelStyle: const TextStyle(color: EaselColors.text, fontSize: 13),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: EaselColors.border),
      ),
      side: const BorderSide(color: EaselColors.border),
      checkmarkColor: EaselColors.accentEnd,
      deleteIconColor: EaselColors.textSecondary,
      showCheckmark: false,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: EaselColors.accentStart,
      linearTrackColor: EaselColors.surfaceHover,
      circularTrackColor: EaselColors.surfaceHover,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: EaselColors.surface2,
      contentTextStyle: const TextStyle(color: EaselColors.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EaselColors.radius)),
      behavior: SnackBarBehavior.floating,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: EaselColors.textSecondary,
      textColor: EaselColors.text,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return EaselColors.accentStart;
        return EaselColors.borderStrong;
      }),
      trackColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return EaselColors.accentSoft;
        return EaselColors.surfaceHover;
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return EaselColors.accentStart;
        return Colors.transparent;
      }),
      checkColor: const WidgetStatePropertyAll(EaselColors.bg),
      side: const BorderSide(color: EaselColors.borderStrong),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: const TextStyle(color: EaselColors.text),
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(EaselColors.bgElev),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: EaselColors.bgElev,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: EaselColors.text),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(8),
      radius: const Radius.circular(4),
      thumbColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.hovered)) return EaselColors.borderStrong;
        return EaselColors.border;
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

Decoration mainContentDecoration() => const BoxDecoration(color: EaselColors.bg);

/// Dark paper wash — web dark `.main-content`:
/// radial blue + warm brown over `--bg #14171e`.
Widget mainContentBackground({required Widget child}) {
  return ColoredBox(
    color: EaselColors.bg,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.54, -0.84),
                  radius: 1.35,
                  colors: const [Color(0x2B375785), Color(0x00375785)],
                  stops: const [0.0, 0.36],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.56, -0.76),
                  radius: 1.4,
                  colors: const [Color(0x1F754C43), Color(0x00754C43)],
                  stops: const [0.0, 0.38],
                ),
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
