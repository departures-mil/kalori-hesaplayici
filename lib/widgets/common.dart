import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

class GradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
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
  final EdgeInsetsGeometry padding;
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

/// 1.1.1: boş ekranlar için ortak görünüm (yumuşak daire içinde simge, başlık,
/// açıklama, isteğe bağlı düğme). Hafif bir belirme animasyonuyla gelir.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? text;
  final String? action;
  final VoidCallback? onAction;
  const EmptyState(
      {super.key, required this.icon, required this.title, this.text, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [
                  AppColors.roseSoft.withValues(alpha: 0.55),
                  AppColors.lavenderSoft.withValues(alpha: 0.55),
                ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Icon(icon, size: 46, color: AppColors.rose),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            if (text != null) ...[
              const SizedBox(height: 6),
              Text(text!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (action != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton.tonal(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 1.1.1: makro halkası (alınan / hedef gram). Açılışta dolarak gelir.
class MacroRing extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color color;
  final double size;
  const MacroRing(
      {super.key,
      required this.label,
      required this.value,
      required this.target,
      required this.color,
      this.size = 86});

  @override
  Widget build(BuildContext context) {
    final frac = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    return Semantics(
      label: '$label ${value.round()} / ${target.round()} g',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: frac),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, f, _) => SizedBox(
            width: size,
            height: size,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(size: Size.square(size), painter: _MacroPainter(f, color)),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${value.round()}',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
                Text('/ ${target.round()} g',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(fontSize: 10, color: AppColors.inkSoft)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
    );
  }
}

class _MacroPainter extends CustomPainter {
  final double frac;
  final Color color;
  _MacroPainter(this.frac, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9);
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * frac,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_MacroPainter o) => o.frac != frac || o.color != color;
}
