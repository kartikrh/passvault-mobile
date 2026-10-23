import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'app_theme.dart';

/// Fixed backdrop behind every screen (installed via MaterialApp.builder):
/// palette gradient, three slowly drifting light orbs and a field of faint
/// geometric shards. The glass surfaces blur this, which is what gives them
/// depth -- the mobile twin of passvault-client's PrismBackground.
class PrismBackground extends StatefulWidget {
  const PrismBackground({super.key, required this.child});
  final Widget child;

  @override
  State<PrismBackground> createState() => _PrismBackgroundState();
}

class _PrismBackgroundState extends State<PrismBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 30));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the OS "reduce motion" setting.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = PvTokens.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [t.bg1, t.bg2, t.bg3],
              stops: const [0, 0.55, 1],
            ),
          ),
        ),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _drift,
            builder: (context, _) {
              final v = Curves.easeInOut.transform(_drift.value);
              return Stack(
                fit: StackFit.expand,
                children: [
                  _Orb(color: t.orb1, size: 380, alignment: Alignment(-1.2 + v * 0.3, -1.1 + v * 0.2)),
                  _Orb(color: t.orb2, size: 320, alignment: Alignment(1.2 - v * 0.25, 1.1 - v * 0.3)),
                  _Orb(color: t.orb3, size: 240, alignment: Alignment(0.2 + v * 0.2, 0.0 - v * 0.15), opacity: 0.45),
                ],
              );
            },
          ),
        ),
        RepaintBoundary(child: CustomPaint(painter: _ShardPainter(t.shard, t.shardOpacity))),
        widget.child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size, required this.alignment, this.opacity = 0.7});
  final Color color;
  final double size;
  final Alignment alignment;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _ShardPainter extends CustomPainter {
  _ShardPainter(this.color, this.opacity);
  final Color color;
  final double opacity;

  // Triangles in a 0..1 unit space, scaled to the screen.
  static const _shards = [
    [0.03, 0.02, 0.28, 0.10, 0.12, 0.17],
    [0.70, 0.04, 0.95, 0.12, 0.78, 0.19],
    [0.40, 0.22, 0.62, 0.30, 0.45, 0.36],
    [0.05, 0.40, 0.22, 0.34, 0.18, 0.52],
    [0.80, 0.38, 0.98, 0.46, 0.84, 0.55],
    [0.30, 0.58, 0.52, 0.64, 0.36, 0.72],
    [0.62, 0.70, 0.88, 0.66, 0.80, 0.80],
    [0.08, 0.78, 0.26, 0.86, 0.10, 0.94],
    [0.45, 0.86, 0.66, 0.92, 0.50, 0.99],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _shards.length; i++) {
      final s = _shards[i];
      final path = Path()
        ..moveTo(s[0] * size.width, s[1] * size.height)
        ..lineTo(s[2] * size.width, s[3] * size.height)
        ..lineTo(s[4] * size.width, s[5] * size.height)
        ..close();
      if (i % 3 != 2) {
        canvas.drawPath(path, Paint()..color = color.withValues(alpha: opacity * (i % 3 == 0 ? 1 : 0.5)));
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: math.min(1, opacity * 2.5)),
      );
    }
  }

  @override
  bool shouldRepaint(_ShardPainter old) => old.color != color || old.opacity != opacity;
}

/// Frosted glass panel: live backdrop blur, translucent gradient fill, a
/// 1px border, a brighter inner top edge and a soft outer shadow.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.radius = 22,
    this.blur = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final t = PvTokens.of(context);
    final shape = BorderRadius.circular(radius);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: [BoxShadow(color: t.shadow, blurRadius: 40, spreadRadius: -16, offset: const Offset(0, 18))],
        ),
        child: ClipRRect(
          borderRadius: shape,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: shape,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [t.glassHi, t.glassLo],
                ),
                border: Border.all(color: t.glassBorder),
              ),
              child: Stack(
                children: [
                  // inner highlight along the top edge
                  Positioned(
                    left: radius / 2,
                    right: radius / 2,
                    top: 0,
                    height: 1,
                    child: ColoredBox(color: t.innerHi),
                  ),
                  Padding(padding: padding, child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Faceted crystal emblem (hexagonal gem, light/shade facets, holographic
/// fill) with an optional icon on top -- matches the web CrystalIcon.
class CrystalIcon extends StatelessWidget {
  const CrystalIcon({super.key, this.icon, this.size = 56});
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = PvTokens.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Diffuse coloured glow under the gem (not a visible disc).
          boxShadow: [
            BoxShadow(
              color: t.accent.withValues(alpha: 0.22),
              blurRadius: size * 0.9,
              spreadRadius: -size * 0.25,
              offset: Offset(0, size * 0.2),
            ),
          ],
          shape: BoxShape.circle,
        ),
        child: CustomPaint(
          painter: _CrystalPainter(t),
          child: icon == null
              ? null
              : Center(
                  child: Icon(
                    icon,
                    size: size * 0.38,
                    color: Colors.white,
                    shadows: const [Shadow(color: Color(0x59000000), blurRadius: 6)],
                  ),
                ),
        ),
      ),
    );
  }
}

class _CrystalPainter extends CustomPainter {
  _CrystalPainter(this.t);
  final PvTokens t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Offset p(double x, double y) => Offset(x / 64 * w, y / 64 * h);
    Path poly(List<Offset> pts) => Path()..addPolygon(pts, true);

    final top = p(32, 2), tr = p(58, 17), br = p(58, 47), bottom = p(32, 62), bl = p(6, 47), tl = p(6, 17), center = p(32, 24);
    final gem = poly([top, tr, br, bottom, bl, tl]);

    canvas.drawPath(
      gem,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.holo1, t.crystalMid, t.crystalDeep, t.holo3],
          stops: const [0, 0.35, 0.7, 1],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(poly([top, tr, center, tl]), Paint()..color = Colors.white.withValues(alpha: 0.38));
    canvas.drawPath(poly([tl, center, bottom, bl]), Paint()..color = Colors.white.withValues(alpha: 0.12));
    canvas.drawPath(poly([tr, br, bottom, center]), Paint()..color = Colors.black.withValues(alpha: 0.14));
    canvas.drawPath(
      poly([p(18, 10), top, p(40, 7), p(24, 14)]),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(1, w / 50)
      ..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawPath(gem, edge);
    canvas.drawPath(Path()..addPolygon([tl, center, tr], false), edge..color = Colors.white.withValues(alpha: 0.45));
    canvas.drawLine(center, bottom, edge..color = Colors.white.withValues(alpha: 0.3));
  }

  @override
  bool shouldRepaint(_CrystalPainter old) => old.t != t;
}

/// Primary call-to-action with the palette's holographic gradient and a
/// soft glow -- used for the main action on a screen.
class HoloButton extends StatelessWidget {
  const HoloButton({super.key, required this.onPressed, required this.child, this.icon});
  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = PvTokens.of(context);
    final enabled = onPressed != null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: t.holoGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          boxShadow: enabled
              ? [BoxShadow(color: t.accent.withValues(alpha: 0.45), blurRadius: 22, spreadRadius: -8, offset: const Offset(0, 10))]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  child: IconTheme.merge(
                    data: const IconThemeData(color: Colors.white, size: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
                        Flexible(child: child),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text painted with the holographic gradient (headlines).
class HoloText extends StatelessWidget {
  const HoloText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final t = PvTokens.of(context);
    final colors = t.brightness == Brightness.dark ? [t.holo1, t.holo2, t.holo3] : [t.accent2, t.accentStrong, t.accent];
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => LinearGradient(colors: colors).createShader(rect),
      child: Text(text, style: style),
    );
  }
}

/// The three palettes as faceted swatches; selecting one re-themes the app.
class PalettePicker extends ConsumerWidget {
  const PalettePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(paletteProvider);
    final t = PvTokens.of(context);
    return Column(
      children: [
        for (final palette in PvPalette.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: t.inputFill,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: current == palette ? t.accent : t.glassBorder, width: current == palette ? 2 : 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => ref.read(paletteProvider.notifier).select(palette),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Theme(
                        data: Theme.of(context).copyWith(extensions: [palette.tokens]),
                        child: const CrystalIcon(size: 40),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(palette.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(palette.description, style: TextStyle(color: t.muted, fontSize: 13)),
                          ],
                        ),
                      ),
                      if (current == palette) Icon(Icons.check_circle, color: t.accent),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
