import 'package:flutter/material.dart';

/// Glass / prism palettes -- the same three as passvault-client's
/// lib/palette.js + glass-theme.scss, with matching colour values so both
/// apps look like one product.
enum PvPalette { amethyst, rose, frost }

extension PvPaletteInfo on PvPalette {
  String get label => switch (this) {
        PvPalette.amethyst => 'Amethyst',
        PvPalette.rose => 'Rose Quartz',
        PvPalette.frost => 'Frost',
      };

  String get description => switch (this) {
        PvPalette.amethyst => 'Deep violet glass',
        PvPalette.rose => 'Rose pink with emerald',
        PvPalette.frost => 'Monochrome frosted glass',
      };

  PvTokens get tokens => switch (this) {
        PvPalette.amethyst => PvTokens.amethyst,
        PvPalette.rose => PvTokens.rose,
        PvPalette.frost => PvTokens.frost,
      };
}

/// Every colour the glass widgets need, exposed as a ThemeExtension so any
/// widget can read `PvTokens.of(context)`.
@immutable
class PvTokens extends ThemeExtension<PvTokens> {
  const PvTokens({
    required this.brightness,
    required this.bg1,
    required this.bg2,
    required this.bg3,
    required this.orb1,
    required this.orb2,
    required this.orb3,
    required this.shard,
    required this.shardOpacity,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accentStrong,
    required this.accent2,
    required this.glassHi,
    required this.glassLo,
    required this.glassSolid,
    required this.glassBorder,
    required this.innerHi,
    required this.shadow,
    required this.inputFill,
    required this.holo1,
    required this.holo2,
    required this.holo3,
    required this.crystalMid,
    required this.crystalDeep,
  });

  final Brightness brightness;
  final Color bg1, bg2, bg3;
  final Color orb1, orb2, orb3;
  final Color shard;
  final double shardOpacity;
  final Color text, muted;
  final Color accent, accentStrong, accent2;
  final Color glassHi, glassLo, glassSolid, glassBorder, innerHi, shadow, inputFill;
  final Color holo1, holo2, holo3, crystalMid, crystalDeep;

  static PvTokens of(BuildContext context) => Theme.of(context).extension<PvTokens>()!;

  LinearGradient get holoGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accentStrong, accent2],
      );

  static const amethyst = PvTokens(
    brightness: Brightness.dark,
    bg1: Color(0xFF12071F),
    bg2: Color(0xFF24123F),
    bg3: Color(0xFF3A1D5E),
    orb1: Color(0xFF7C3AED),
    orb2: Color(0xFFC026D3),
    orb3: Color(0xFF4F46E5),
    shard: Color(0xFFE9D5FF),
    shardOpacity: 0.07,
    text: Color(0xFFF4EEFF),
    muted: Color(0xA8ECE2FF),
    accent: Color(0xFF8B5CF6),
    accentStrong: Color(0xFF6D28D9),
    accent2: Color(0xFFC026D3),
    glassHi: Color(0x1FFFFFFF),
    glassLo: Color(0x0AFFFFFF),
    glassSolid: Color(0xF0281545),
    glassBorder: Color(0x29FFFFFF),
    innerHi: Color(0x38FFFFFF),
    shadow: Color(0x99080214),
    inputFill: Color(0x12FFFFFF),
    holo1: Color(0xFFC4B5FD),
    holo2: Color(0xFFF0ABFC),
    holo3: Color(0xFF93C5FD),
    crystalMid: Color(0xFFA855F7),
    crystalDeep: Color(0xFF6D28D9),
  );

  static const rose = PvTokens(
    brightness: Brightness.light,
    bg1: Color(0xFFFFF5F8),
    bg2: Color(0xFFFDE4EE),
    bg3: Color(0xFFF5E1EC),
    orb1: Color(0xFFF9A8D4),
    orb2: Color(0xFF6EE7B7),
    orb3: Color(0xFFFBCFE8),
    shard: Color(0xFFBE185D),
    shardOpacity: 0.06,
    text: Color(0xFF3B1D2E),
    muted: Color(0xFF85606F),
    accent: Color(0xFFDB2777),
    accentStrong: Color(0xFF047857),
    accent2: Color(0xFFBE185D),
    glassHi: Color(0xB8FFFFFF),
    glassLo: Color(0x6BFFFFFF),
    glassSolid: Color(0xF2FFF7FA),
    glassBorder: Color(0xD9FFFFFF),
    innerHi: Color(0xF2FFFFFF),
    shadow: Color(0x299D174D),
    inputFill: Color(0x99FFFFFF),
    holo1: Color(0xFFF9A8D4),
    holo2: Color(0xFF6EE7B7),
    holo3: Color(0xFFFDE68A),
    crystalMid: Color(0xFF34D399),
    crystalDeep: Color(0xFFF472B6),
  );

  static const frost = PvTokens(
    brightness: Brightness.light,
    bg1: Color(0xFFF6F8FB),
    bg2: Color(0xFFE6EBF2),
    bg3: Color(0xFFDBE2EC),
    orb1: Color(0xFFCBD5E1),
    orb2: Color(0xFFE2E8F0),
    orb3: Color(0xFF94A3B8),
    shard: Color(0xFF334155),
    shardOpacity: 0.05,
    text: Color(0xFF1E293B),
    muted: Color(0xFF526074),
    accent: Color(0xFF475569),
    accentStrong: Color(0xFF1E293B),
    accent2: Color(0xFF64748B),
    glassHi: Color(0xB3FFFFFF),
    glassLo: Color(0x61FFFFFF),
    glassSolid: Color(0xF2F8FAFC),
    glassBorder: Color(0xE6FFFFFF),
    innerHi: Color(0xFFFFFFFF),
    shadow: Color(0x240F172A),
    inputFill: Color(0x9EFFFFFF),
    holo1: Color(0xFFFFFFFF),
    holo2: Color(0xFFCBD5E1),
    holo3: Color(0xFFDBEAFE),
    crystalMid: Color(0xFF94A3B8),
    crystalDeep: Color(0xFF475569),
  );

  @override
  PvTokens copyWith() => this;

  @override
  PvTokens lerp(ThemeExtension<PvTokens>? other, double t) => t < 0.5 ? this : (other as PvTokens? ?? this);
}

ThemeData buildAppTheme(PvPalette palette) {
  final t = palette.tokens;
  final base = ColorScheme.fromSeed(seedColor: t.accentStrong, brightness: t.brightness);
  final colors = base.copyWith(
    primary: t.accentStrong,
    onPrimary: Colors.white,
    secondary: t.accent2,
    onSurface: t.text,
    onSurfaceVariant: t.muted,
    outline: t.glassBorder,
    surface: t.bg2,
  );
  final radius = BorderRadius.circular(18);
  final fieldRadius = BorderRadius.circular(14);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    extensions: [t],
    // Every Scaffold is see-through: PrismBackground (MaterialApp.builder)
    // paints the gradient, orbs and shards behind all screens.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    textTheme: ThemeData(brightness: t.brightness).textTheme.apply(bodyColor: t.text, displayColor: t.text),
    iconTheme: IconThemeData(color: t.text),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: t.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    // List cards: translucent glass without a live blur (cheap to scroll).
    // GlassCard adds the real backdrop blur where a few large panels appear.
    cardTheme: CardThemeData(
      color: t.glassHi,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: t.glassBorder)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.glassSolid,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: t.glassBorder)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.glassSolid,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: t.glassBorder),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: t.glassSolid,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: t.glassBorder)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.glassSolid,
      contentTextStyle: TextStyle(color: t.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: t.glassBorder)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.inputFill,
      labelStyle: TextStyle(color: t.muted),
      hintStyle: TextStyle(color: t.muted),
      helperStyle: TextStyle(color: t.muted),
      border: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide(color: t.glassBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide(color: t.glassBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide(color: t.accent, width: 1.6)),
      disabledBorder: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide(color: t.glassBorder.withValues(alpha: 0.4))),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.accentStrong,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: fieldRadius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.text,
        backgroundColor: t.inputFill,
        minimumSize: const Size(64, 50),
        side: BorderSide(color: t.glassBorder),
        shape: RoundedRectangleBorder(borderRadius: fieldRadius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: t.brightness == Brightness.dark ? t.holo1 : t.accentStrong),
    ),
    listTileTheme: ListTileThemeData(iconColor: t.text, textColor: t.text),
    dividerTheme: DividerThemeData(color: t.glassBorder),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.accentStrong : t.inputFill),
    ),
    chipTheme: ChipThemeData(backgroundColor: t.inputFill, side: BorderSide(color: t.glassBorder)),
    tabBarTheme: TabBarThemeData(
      labelColor: t.text,
      unselectedLabelColor: t.muted,
      indicatorColor: t.accent,
      dividerColor: t.glassBorder,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: t.accentStrong,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: t.accent),
  );
}
