import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum ControllerBrandingMode { xinput, dinput }

enum ControllerFaceSymbol { cross, circle, square, triangle }

class ControllerButtonPresentation {
  const ControllerButtonPresentation({
    required this.canonicalId,
    required this.shortLabel,
    required this.semanticLabel,
    required this.accentColor,
    this.symbol,
  });

  final String canonicalId;
  final String shortLabel;
  final String semanticLabel;
  final Color accentColor;
  final ControllerFaceSymbol? symbol;

  bool get hasSymbol => symbol != null;
}

class ControllerBranding {
  const ControllerBranding._();

  static const List<String> canonicalOrder = <String>[
    'Y',
    'B',
    'X',
    'A',
    'RB',
    'RT',
    'LB',
    'LT',
    'RSB',
    'LSB',
  ];

  static const Set<String> faceButtons = <String>{'A', 'B', 'X', 'Y'};

  static ControllerBrandingMode modeFromWire(String? value) {
    return value?.toLowerCase() == 'ds4'
        ? ControllerBrandingMode.dinput
        : ControllerBrandingMode.xinput;
  }

  static String normalizeCanonicalId(String id) {
    final upper = id.toUpperCase();
    switch (upper) {
      case 'BTNA':
        return 'A';
      case 'BTNB':
        return 'B';
      case 'BTNX':
        return 'X';
      case 'BTNY':
        return 'Y';
      case 'BTNLB':
        return 'LB';
      case 'BTNRB':
        return 'RB';
      case 'BTNLT':
        return 'LT';
      case 'BTNRT':
        return 'RT';
      case 'BTNLSB':
        return 'LSB';
      case 'BTNRSB':
        return 'RSB';
      default:
        return upper;
    }
  }

  static bool isSupportedCanonicalId(String id) {
    return canonicalOrder.contains(normalizeCanonicalId(id));
  }

  static List<String> normalizeCanonicalOrder(Iterable<dynamic> rawOrder) {
    final seen = <String>{};
    final normalized = <String>[];

    for (final item in rawOrder) {
      final canonical = normalizeCanonicalId('$item');
      if (isSupportedCanonicalId(canonical) && seen.add(canonical)) {
        normalized.add(canonical);
      }
    }

    for (final canonical in canonicalOrder) {
      if (seen.add(canonical)) {
        normalized.add(canonical);
      }
    }

    return normalized;
  }

  static Map<String, bool> normalizeVisibility(Map<String, dynamic> raw) {
    final normalized = <String, bool>{
      for (final canonical in canonicalOrder) canonical: false,
    };

    raw.forEach((key, value) {
      final canonical = normalizeCanonicalId(key);
      if (normalized.containsKey(canonical)) {
        normalized[canonical] = value == true;
      }
    });

    return normalized;
  }

  static ControllerButtonPresentation presentationFor(
    String canonicalId,
    ControllerBrandingMode mode,
  ) {
    final id = normalizeCanonicalId(canonicalId);

    if (mode == ControllerBrandingMode.dinput) {
      switch (id) {
        case 'A':
          return const ControllerButtonPresentation(
            canonicalId: 'A',
            shortLabel: 'Cross',
            semanticLabel: 'Cross',
            accentColor: Color(0xFF3B82F6),
            symbol: ControllerFaceSymbol.cross,
          );
        case 'B':
          return const ControllerButtonPresentation(
            canonicalId: 'B',
            shortLabel: 'Circle',
            semanticLabel: 'Circle',
            accentColor: Color(0xFFFF6B6B),
            symbol: ControllerFaceSymbol.circle,
          );
        case 'X':
          return const ControllerButtonPresentation(
            canonicalId: 'X',
            shortLabel: 'Square',
            semanticLabel: 'Square',
            accentColor: Color(0xFFFF6FD8),
            symbol: ControllerFaceSymbol.square,
          );
        case 'Y':
          return const ControllerButtonPresentation(
            canonicalId: 'Y',
            shortLabel: 'Triangle',
            semanticLabel: 'Triangle',
            accentColor: Color(0xFF22C55E),
            symbol: ControllerFaceSymbol.triangle,
          );
        case 'LB':
          return const ControllerButtonPresentation(
            canonicalId: 'LB',
            shortLabel: 'L1',
            semanticLabel: 'L1',
            accentColor: AppColors.textPrimary,
          );
        case 'RB':
          return const ControllerButtonPresentation(
            canonicalId: 'RB',
            shortLabel: 'R1',
            semanticLabel: 'R1',
            accentColor: AppColors.textPrimary,
          );
        case 'LT':
          return const ControllerButtonPresentation(
            canonicalId: 'LT',
            shortLabel: 'L2',
            semanticLabel: 'L2',
            accentColor: AppColors.textPrimary,
          );
        case 'RT':
          return const ControllerButtonPresentation(
            canonicalId: 'RT',
            shortLabel: 'R2',
            semanticLabel: 'R2',
            accentColor: AppColors.textPrimary,
          );
        case 'LSB':
          return const ControllerButtonPresentation(
            canonicalId: 'LSB',
            shortLabel: 'L3',
            semanticLabel: 'L3',
            accentColor: AppColors.textPrimary,
          );
        case 'RSB':
          return const ControllerButtonPresentation(
            canonicalId: 'RSB',
            shortLabel: 'R3',
            semanticLabel: 'R3',
            accentColor: AppColors.textPrimary,
          );
      }
    }

    switch (id) {
      case 'A':
        return const ControllerButtonPresentation(
          canonicalId: 'A',
          shortLabel: 'A',
          semanticLabel: 'A',
          accentColor: Color(0xFF22C55E),
        );
      case 'B':
        return const ControllerButtonPresentation(
          canonicalId: 'B',
          shortLabel: 'B',
          semanticLabel: 'B',
          accentColor: Color(0xFFFF6B6B),
        );
      case 'X':
        return const ControllerButtonPresentation(
          canonicalId: 'X',
          shortLabel: 'X',
          semanticLabel: 'X',
          accentColor: Color(0xFF3B82F6),
        );
      case 'Y':
        return const ControllerButtonPresentation(
          canonicalId: 'Y',
          shortLabel: 'Y',
          semanticLabel: 'Y',
          accentColor: Color(0xFFFACC15),
        );
      default:
        return ControllerButtonPresentation(
          canonicalId: id,
          shortLabel: id,
          semanticLabel: id,
          accentColor: AppColors.textPrimary,
        );
    }
  }
}

class ControllerButtonBrand extends StatelessWidget {
  const ControllerButtonBrand({
    super.key,
    required this.presentation,
    this.size = 22,
    this.fontSize,
    this.textColor,
    this.align = Alignment.center,
  });

  final ControllerButtonPresentation presentation;
  final double size;
  final double? fontSize;
  final Color? textColor;
  final AlignmentGeometry align;

  @override
  Widget build(BuildContext context) {
    final foreground = textColor ?? AppColors.textPrimary;
    final effectiveFontSize =
        fontSize ?? (presentation.hasSymbol ? size : size * 0.72);

    final makeXInputButtonsColorful = true;

    return Semantics(
      label: presentation.semanticLabel,
      child: Align(
        alignment: align,
        child: presentation.symbol == null
            ? Text(
                presentation.shortLabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: effectiveFontSize,
                  fontWeight: FontWeight.w800,
                  color: makeXInputButtonsColorful ? presentation.accentColor : foreground,
                  fontFamily: 'momo',
                ),
              )
            : SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _ControllerFaceSymbolPainter(
                    symbol: presentation.symbol!,
                    color: presentation.accentColor,
                    strokeWidth: math.max(1.8, size * 0.11),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ControllerFaceSymbolPainter extends CustomPainter {
  const _ControllerFaceSymbolPainter({
    required this.symbol,
    required this.color,
    required this.strokeWidth,
  });

  final ControllerFaceSymbol symbol;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.34;

    switch (symbol) {
      case ControllerFaceSymbol.cross:
        canvas.drawLine(
          Offset(center.dx - radius, center.dy - radius),
          Offset(center.dx + radius, center.dy + radius),
          paint,
        );
        canvas.drawLine(
          Offset(center.dx + radius, center.dy - radius),
          Offset(center.dx - radius, center.dy + radius),
          paint,
        );
        break;
      case ControllerFaceSymbol.circle:
        canvas.drawCircle(center, radius, paint);
        break;
      case ControllerFaceSymbol.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: radius * 2.2,
              height: radius * 2.2,
            ),
            Radius.circular(radius * 0.18),
          ),
          paint,
        );
        break;
      case ControllerFaceSymbol.triangle:
        final path = Path()
          ..moveTo(center.dx, center.dy - radius * 1.2)
          ..lineTo(center.dx + radius * 1.08, center.dy + radius * 0.9)
          ..lineTo(center.dx - radius * 1.08, center.dy + radius * 0.9)
          ..close();
        canvas.drawPath(path, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ControllerFaceSymbolPainter oldDelegate) {
    return oldDelegate.symbol != symbol ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
