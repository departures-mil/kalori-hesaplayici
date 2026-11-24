import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

class GradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const GradientCard(
      {super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: kGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: AppColors.rose.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: Offset(0, 8))
          ],
        ),
        child: child,
      );
}

class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  const SoftCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? AppColors.card,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: AppColors.lavender.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: Offset(0, 6))
          ],
        ),
        child: child,
      );
}

/// Circular progress ring for daily calories.
class CalorieRing extends StatelessWidget {
  final double consumed;
  final double goal;
  final double size;
  final Widget? center;
  const CalorieRing(
      {super.key,
      required this.consumed,
      required this.goal,
      this.size = 150,
      this.center});

  @override
  Widget build(BuildContext context) {
    final frac = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    final over = goal > 0 && consumed > goal;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(frac, over),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double frac;
  final bool over;
  _RingPainter(this.frac, this.over);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    final bg = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, bg);
    final fg = Paint()
      ..color = over ? AppColors.peach : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2,
        2 * math.pi * frac, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.frac != frac || o.over != over;
}

class MacroChip extends StatelessWidget {
  final String label;
  final double grams;
  final Color color;
  const MacroChip(
      {super.key,
      required this.label,
      required this.grams,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${grams.round()} g',
                style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            Text(label,
                style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
          ],
        ),
      );
}

class ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const ActionTile(
      {super.key,
      required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SoftCard(
          padding: EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 26),
              ),
              SizedBox(height: 10),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      );
}

void showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}
