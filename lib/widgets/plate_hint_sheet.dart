import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../data/settings.dart';
import '../l10n/strings.dart';
import '../screens/manual_add_screen.dart';

/// Shown after a photo is picked: the user can (optionally) type what is on
/// the plate so the AI / offline model gives a better result.
/// v1.0.11: also a size reference (plate / card / fork / spoon) and an
/// optional side photo. Returns null when cancelled.
Future<PlateInput?> showPlateHintSheet(BuildContext context, File file) {
  return showModalBottomSheet<PlateInput>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
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
    'ref_title': 'Boyut referansı (daha doğru gram)',
    'ref_none': 'Yok',
    'ref_plate': 'Tabağım',
    'ref_card': 'Kart',
    'ref_fork': 'Çatal',
    'ref_spoon': 'Kaşık',
    'ref_tip': 'Tabağın yanına banka kartı, çatal ya da kaşık koyup çekersen porsiyon çok daha doğru hesaplanır.',
    'plate_cm_title': 'Tabağının çapı (cm)',
    'plate_cm_hint': 'Bir kez ölçmen yeterli. Ör. 26',
    'side_add': 'Yandan fotoğraf ekle',
    'side_tip': 'Yandan çekilen ikinci fotoğraf, yüksekliği (hacmi) gösterir.',
    'side_camera': 'Kamera',
    'side_gallery': 'Galeri',
    'cancel': 'Vazgeç',
    'ok': 'Tamam',
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
    'ref_title': 'Size reference (more accurate grams)',
    'ref_none': 'None',
    'ref_plate': 'My plate',
    'ref_card': 'Card',
    'ref_fork': 'Fork',
    'ref_spoon': 'Spoon',
    'ref_tip': 'Put a bank card, a fork or a spoon next to the plate before taking the photo: portions become much more accurate.',
    'plate_cm_title': 'Your plate diameter (cm)',
    'plate_cm_hint': 'Measure once. e.g. 26',
    'side_add': 'Add a side photo',
    'side_tip': 'A second photo from the side shows the height (volume).',
    'side_camera': 'Camera',
    'side_gallery': 'Gallery',
    'cancel': 'Cancel',
    'ok': 'OK',
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
    'ref_title': 'مرجع الحجم (غرامات أدق)',
    'ref_none': 'لا يوجد',
    'ref_plate': 'طبقي',
    'ref_card': 'بطاقة',
    'ref_fork': 'شوكة',
    'ref_spoon': 'ملعقة',
    'ref_tip': 'ضعي بطاقة بنكية أو شوكة أو ملعقة بجانب الطبق قبل التصوير لتصبح الحصص أدق بكثير.',
    'plate_cm_title': 'قطر طبقك (سم)',
    'plate_cm_hint': 'يكفي القياس مرة واحدة. مثال: 26',
    'side_add': 'أضيفي صورة جانبية',
    'side_tip': 'الصورة الثانية من الجانب تُظهر الارتفاع (الحجم).',
    'side_camera': 'الكاميرا',
    'side_gallery': 'المعرض',
    'cancel': 'إلغاء',
    'ok': 'حسناً',
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
  String _ref = Settings.instance.lastRef;
  File? _side;

  PlateInput _result(String hint) {
    Settings.instance.lastRef = _ref;
    return PlateInput(hint: hint, ref: _ref, side: _side);
  }

  Future<void> _pickSide(String Function(String) s) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: Icon(Icons.photo_camera_rounded),
              title: Text(s('side_camera')),
              onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(
              leading: Icon(Icons.photo_library_rounded),
              title: Text(s('side_gallery')),
              onTap: () => Navigator.pop(c, ImageSource.gallery)),
        ]),
      ),
    );
    if (src == null) return;
    final x = await ImagePicker().pickImage(
        source: src, imageQuality: 90, maxWidth: 1600, maxHeight: 1600);
    if (x != null && mounted) setState(() => _side = File(x.path));
  }

  Future<void> _choosePlate(String Function(String) s) async {
    final st = Settings.instance;
    final ctrl =
        TextEditingController(text: st.plateCm > 0 ? '${st.plateCm}' : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s('plate_cm_title')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: s('plate_cm_hint')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(s('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(s('ok'))),
        ],
      ),
    );
    if (ok != true) return;
    final v = int.tryParse(ctrl.text.trim()) ?? 0;
    if (v >= 10 && v <= 50) {
      st.plateCm = v;
      setState(() => _ref = 'plate');
    }
  }

  Widget _refChips(String Function(String) s) {
    final cm = Settings.instance.plateCm;
    Widget chip(String key, IconData icon, {String? label}) => ChoiceChip(
          avatar: Icon(icon, size: 18),
          label: Text(label ?? s('ref_$key')),
          selected: _ref == key,
          selectedColor: AppColors.roseSoft,
          onSelected: (_) {
            if (key == 'plate' && cm == 0) {
              _choosePlate(s);
            } else {
              setState(() => _ref = key);
            }
          },
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s('ref_title'),
            style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: [
          chip('none', Icons.block_rounded),
          GestureDetector(
            onLongPress: () => _choosePlate(s),
            child: chip('plate', Icons.circle_outlined,
                label: cm > 0 ? '${s('ref_plate')} $cm cm' : s('ref_plate')),
          ),
          chip('card', Icons.credit_card_rounded),
          chip('fork', Icons.restaurant_rounded),
          chip('spoon', Icons.soup_kitchen_rounded),
        ]),
        SizedBox(height: 4),
        Text(s('ref_tip'),
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55))),
        SizedBox(height: 10),
        Row(children: [
          if (_side != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(_side!, width: 52, height: 52, fit: BoxFit.cover),
            ),
            IconButton(
                onPressed: () => setState(() => _side = null),
                icon: Icon(Icons.close_rounded)),
          ] else
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickSide(s),
                icon: Icon(Icons.add_a_photo_rounded),
                label: Text(s('side_add')),
              ),
            ),
          if (_side != null)
            Expanded(
                child: Text(s('side_tip'),
                    style: TextStyle(fontSize: 12))),
        ]),
      ],
    );
  }

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
      MaterialPageRoute(builder: (_) => ManualAddScreen(pickOnly: true)),
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
            SizedBox(height: 14),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(widget.file,
                      width: 72, height: 72, fit: BoxFit.cover),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s('plate_hint_title'),
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
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
            SizedBox(height: 16),
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
              SizedBox(height: 10),
            ],
            TextField(
              controller: _ctrl,
              autofocus: false,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: s('plate_hint_example'),
                prefixIcon: Icon(Icons.restaurant_menu_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _fromList,
                icon: Icon(Icons.playlist_add_rounded),
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
            SizedBox(height: 14),
            _refChips(s),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, _result('')),
                    style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14)),
                    child: Text(s('plate_hint_skip')),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, _result(_text)),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rose,
                        padding: EdgeInsets.symmetric(vertical: 14)),
                    icon: Icon(Icons.auto_awesome_rounded),
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
