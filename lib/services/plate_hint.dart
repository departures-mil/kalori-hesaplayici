/// One food the user typed in the "what's on the plate" box.
class HintItem {
  final String name;
  final double? grams; // exact grams if given
  final double? count; // pieces/slices if given (multiplied by portion)
  HintItem(this.name, {this.grams, this.count});
}

/// Parses free text like "pilav 150 g, 2 köfte, çoban salata ve ayran"
/// (tr / en / ar) into separate items with optional amounts.
class PlateHint {
  static final _split = RegExp(
      r'[,;\n،+]|\s+ve\s+|\s+and\s+|\s+with\s+|\s+ile\s+|\s+و\s+|\s+و(?=ال)',
      caseSensitive: false);

  static final _num = RegExp(r'(\d+(?:[.,]\d+)?)');

  static const _gramUnits = ['gram', 'grams', 'gr', 'g', 'غرام', 'جرام', 'غ'];
  static const _mlUnits = ['ml', 'مل'];
  static const _spoonUnits = ['yemek kaşığı', 'kaşık', 'kasik', 'tbsp', 'spoon', 'spoons', 'ملعقة', 'ملاعق'];
  static const _cupUnits = ['su bardağı', 'bardak', 'kase', 'kâse', 'cup', 'cups', 'glass', 'glasses', 'bowl', 'كوب', 'أكواب', 'كاس', 'كأس', 'صحن'];
  static const _pieceUnits = ['adet', 'tane', 'dilim', 'parça', 'porsiyon', 'piece', 'pieces', 'pcs', 'slice', 'slices', 'portion', 'حبة', 'حبات', 'قطعة', 'قطع', 'شريحة', 'حصة'];

  static List<HintItem> parse(String? text) {
    final t = text?.trim() ?? '';
    if (t.isEmpty) return [];
    final out = <HintItem>[];
    for (var part in t.split(_split)) {
      part = part.trim();
      if (part.isEmpty) continue;
      final m = _num.firstMatch(part);
      double? grams;
      double? count;
      var name = part;
      if (m != null) {
        final n = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
        name = part.replaceRange(m.start, m.end, ' ');
        final lower = name.toLowerCase();
        String? unit;
        double factor = 0; // grams per unit, 0 = pieces
        bool isPiece = false;
        bool find(List<String> units, double f, {bool piece = false}) {
          for (final u in units) {
            final r = RegExp('(^|\\s)${RegExp.escape(u)}(\\s|\$|\\.)',
                caseSensitive: false);
            if (r.hasMatch(lower)) {
              unit = u;
              factor = f;
              isPiece = piece;
              return true;
            }
          }
          return false;
        }

        find(_spoonUnits, 15) ||
            find(_cupUnits, 200) ||
            find(_pieceUnits, 0, piece: true) ||
            find(_mlUnits, 1) ||
            find(_gramUnits, 1);
        if (unit != null) {
          name = name.replaceFirst(
              RegExp('(^|\\s)${RegExp.escape(unit!)}(?=\\s|\$|\\.)',
                  caseSensitive: false),
              ' ');
          if (isPiece) {
            count = n;
          } else {
            grams = n * factor;
          }
        } else {
          // bare number: small = pieces, large = grams
          if (n <= 12) {
            count = n;
          } else {
            grams = n;
          }
        }
      }
      name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (name.length < 2) continue;
      out.add(HintItem(name, grams: grams, count: count));
    }
    return out;
  }
}
