import 'package:flutter/material.dart';

import '../core/fc_tokens.dart';
import '../core/look.dart';
import '../core/theme.dart';
import '../data/settings.dart';
import '../l10n/strings.dart';

/// Ayarlar → Görünüm (ve ilk açılış rehberi): renk şeması, koyu / açık / otomatik, yazı boyutu.
class LookPicker extends StatelessWidget {
  final bool compact;
  const LookPicker({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final look = FcLook.instance;
    final lang = Settings.instance.lang;
    return ListenableBuilder(
      listenable: look,
      builder: (context, _) {
        final p = look.palette;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s['scheme'], style: TextStyle(fontWeight: FontWeight.w600, color: p.text)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in kFcSchemeIds)
                  _SchemeChip(
                    id: id,
                    label: FcLook.schemeLabel(id, lang),
                    selected: look.scheme == id,
                    dark: look.dark,
                    onTap: () => look.setScheme(id),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(s['mode'], style: TextStyle(fontWeight: FontWeight.w600, color: p.text)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'dark', label: Text(s['mode_dark']), icon: const Icon(Icons.dark_mode_rounded, size: 18)),
                ButtonSegment(value: 'light', label: Text(s['mode_light']), icon: const Icon(Icons.light_mode_rounded, size: 18)),
                ButtonSegment(value: 'auto', label: Text(s['mode_auto']), icon: const Icon(Icons.brightness_auto_rounded, size: 18)),
              ],
              selected: {look.theme},
              onSelectionChanged: (v) => look.setTheme(v.first),
            ),
            if (!compact) ...[
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Text('${s['font_size']}: ${(look.scale * 100).round()}%',
                      style: TextStyle(fontWeight: FontWeight.w600, color: p.text)),
                ),
                IconButton.outlined(
                  tooltip: s['font_smaller'],
                  onPressed: look.scale <= FcLook.minScale ? null : () => look.bump(-1),
                  icon: const Text('A−', textDirection: TextDirection.ltr),
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  tooltip: s['font_larger'],
                  onPressed: look.scale >= FcLook.maxScale ? null : () => look.bump(1),
                  icon: const Text('A+', textDirection: TextDirection.ltr, style: TextStyle(fontSize: 17)),
                ),
                const SizedBox(width: 6),
                TextButton(onPressed: () => look.setScale(1), child: Text(s['font_reset'])),
              ]),
              const SizedBox(height: 4),
              Text(s['look_desc'], style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
            ],
          ],
        );
      },
    );
  }
}

class _SchemeChip extends StatelessWidget {
  final String id;
  final String label;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;
  const _SchemeChip(
      {required this.id, required this.label, required this.selected, required this.dark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cur = FcLook.instance.palette;
    final t = FcPalette(id, dark);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? cur['active-1'] : cur.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? cur.accent : cur.border, width: selected ? 2 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [t.bg, t.bg, t.accent, t.accent2], stops: const [0, .45, .55, 1]),
                border: Border.all(color: cur.border),
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: cur.text, fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}
