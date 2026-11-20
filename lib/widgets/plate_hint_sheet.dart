import 'dart:io';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import '../screens/manual_add_screen.dart';

/// Shown after a photo is picked: the user can (optionally) type what is on
/// the plate so the AI / offline model gives a better result.
/// Returns the typed text ('' when skipped) or null when cancelled.
Future<String?> showPlateHintSheet(BuildContext context, File file) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _PlateHintSheet(file: file),
  );
}

const _t = <String, Map<String, String>>{
  'tr': {
    'plate_hint_title': 'Tabakta neler var?',
    'plate_hint_sub':
        'İsteğe bağlı. Yazarsan yapay zekâ çok daha doğru hesaplar.',
    'plate_hint_example':
        'ör. pilav 150 g, 2 köfte, çoban salata, 1 bardak ayran',
    'plate_hint_from_list': 'Listeden ekle',
    'plate_hint_tip':
        'Virgülle ayır. Miktarı biliyorsan yaz (gram, adet, kaşık, bardak).',
    'plate_hint_skip': 'Atla',
    'plate_hint_analyze': 'Analiz Et',
  },
  'en': {
    'plate_hint_title': "What's on the plate?",
    'plate_hint_sub':
        'Optional. Typing it helps the AI calculate much more accurately.',
    'plate_hint_example':
        'e.g. rice 150 g, 2 meatballs, salad, 1 glass of milk',
    'plate_hint_from_list': 'Add from list',
    'plate_hint_tip':
        'Separate with commas. Add amounts if you know them (grams, pieces, spoons, cups).',
    'plate_hint_skip': 'Skip',
    'plate_hint_analyze': 'Analyze',
  },
  'ar': {
    'plate_hint_title': 'ماذا يوجد في الطبق؟',
    'plate_hint_sub':
        'اختياري. كتابة المكونات تساعد الذكاء الاصطناعي على حساب أدق بكثير.',
    'plate_hint_example': 'مثال: أرز 150 غ، 2 كفتة، سلطة، كوب لبن',
    'plate_hint_from_list': 'أضف من القائمة',
    'plate_hint_tip':
        'افصل بفاصلة. أضف الكمية إن عرفتها (غرام، حبة، ملعقة، كوب).',
    'plate_hint_skip': 'تخطي',
    'plate_hint_analyze': 'تحليل',
  },
};

class _PlateHintSheet extends StatefulWidget {
  final File file;
  const _PlateHintSheet({required this.file});

  @override
  State<_PlateHintSheet> createState() => _PlateHintSheetState();
}

class _PlateHintSheetState extends State<_PlateHintSheet> {
  final _ctrl = TextEditingController();
  final _chips = <String>[];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _text {
    final parts = [
      ..._chips,
      if (_ctrl.text.trim().isNotEmpty) _ctrl.text.trim(),
    ];
    return parts.join(', ');
  }

  Future<void> _fromList() async {
    final item = await Navigator.push<FoodItem>(
      context,
      MaterialPageRoute(builder: (_) => const ManualAddScreen(pickOnly: true)),
    );
    if (item == null || !mounted) return;
    setState(() => _chips.add('${item.name} ${item.grams.round()} g'));
  }

  @override
  Widget build(BuildContext context) {
    final code = S.of(context).code;
    String s(String k) => _t[code]?[k] ?? _t['en']![k]!;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(widget.file,
                      width: 72, height: 72, fit: BoxFit.cover),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s('plate_hint_title'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(s('plate_hint_sub'),
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.65))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_chips.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < _chips.length; i++)
                    InputChip(
                      label: Text(_chips[i]),
                      onDeleted: () => setState(() => _chips.removeAt(i)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _ctrl,
              autofocus: false,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: s('plate_hint_example'),
                prefixIcon: const Icon(Icons.restaurant_menu_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _fromList,
                icon: const Icon(Icons.playlist_add_rounded),
                label: Text(s('plate_hint_from_list')),
              ),
            ),
            Text(s('plate_hint_tip'),
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, ''),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(s('plate_hint_skip')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, _text),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rose,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text(s('plate_hint_analyze')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
