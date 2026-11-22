import 'dart:convert';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      p.join(dir.path, 'kalori.db'),
      version: 2,
      onUpgrade: (d, from, to) async {
        if (from < 2) await _v2(d);
      },
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            time INTEGER NOT NULL,
            day TEXT NOT NULL,
            meal INTEGER NOT NULL,
            source INTEGER NOT NULL,
            items TEXT NOT NULL,
            kcal REAL NOT NULL,
            image TEXT,
            note TEXT,
            uid TEXT,
            updated INTEGER NOT NULL DEFAULT 0,
            deleted INTEGER NOT NULL DEFAULT 0
          )''');
        await d.execute('CREATE UNIQUE INDEX idx_uid ON entries(uid)');
        await d.execute('CREATE INDEX idx_day ON entries(day)');
        await d.execute('''
          CREATE TABLE water(day TEXT PRIMARY KEY, glasses INTEGER NOT NULL, updated INTEGER NOT NULL DEFAULT 0)''');
        await d.execute('''
          CREATE TABLE weight(day TEXT PRIMARY KEY, kg REAL NOT NULL, updated INTEGER NOT NULL DEFAULT 0)''');
        await d.execute('''
          CREATE TABLE products(barcode TEXT PRIMARY KEY, json TEXT NOT NULL)''');
      },
    );
    return _db!;
  }

  /// v1 → v2: eşitleme için her kayda kalıcı kimlik, değişim zamanı ve
  /// silindi işareti (silinen kayıt öbür cihazda geri dirilmesin).
  static Future<void> _v2(Database d) async {
    await d.execute('ALTER TABLE entries ADD COLUMN uid TEXT');
    await d.execute('ALTER TABLE entries ADD COLUMN updated INTEGER NOT NULL DEFAULT 0');
    await d.execute('ALTER TABLE entries ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0');
    await d.execute('ALTER TABLE water ADD COLUMN updated INTEGER NOT NULL DEFAULT 0');
    await d.execute('ALTER TABLE weight ADD COLUMN updated INTEGER NOT NULL DEFAULT 0');
    final rows = await d.query('entries', columns: ['id', 'time']);
    for (final r in rows) {
      await d.update('entries', {'uid': newUid(), 'updated': r['time']},
          where: 'id = ?', whereArgs: [r['id']]);
    }
    await d.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_uid ON entries(uid)');
  }

  static final _rnd = Random.secure();
  static String newUid() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
      '${List.generate(8, (_) => _rnd.nextInt(36).toRadixString(36)).join()}';

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  static String dayKey(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  Future<int> insertEntry(DiaryEntry e) async {
    final d = await db;
    return d.insert('entries', {
      'time': e.time.millisecondsSinceEpoch,
      'day': dayKey(e.time),
      'meal': e.meal.index,
      'source': e.source.index,
      'items': jsonEncode(e.items.map((i) => i.toJson()).toList()),
      'kcal': e.kcal,
      'image': e.imagePath,
      'note': e.note,
      'uid': newUid(),
      'updated': _now(),
      'deleted': 0,
    });
  }

  Future<void> updateEntry(DiaryEntry e) async {
    final d = await db;
    await d.update(
      'entries',
      {
        'time': e.time.millisecondsSinceEpoch,
        'day': dayKey(e.time),
        'meal': e.meal.index,
        'source': e.source.index,
        'items': jsonEncode(e.items.map((i) => i.toJson()).toList()),
        'kcal': e.kcal,
        'image': e.imagePath,
        'note': e.note,
        'updated': _now(),
      },
      where: 'id = ?',
      whereArgs: [e.id],
    );
  }

  Future<void> deleteEntry(int id) async {
    final d = await db;
    // yumuşak silme: eşitlemede öbür cihaza da "silindi" olarak gider
    await d.update('entries', {'deleted': 1, 'updated': _now()},
        where: 'id = ?', whereArgs: [id]);
  }

  DiaryEntry _row(Map<String, Object?> r) => DiaryEntry(
        id: r['id'] as int,
        time: DateTime.fromMillisecondsSinceEpoch(r['time'] as int),
        meal: MealType.values[r['meal'] as int],
        source: AnalysisSource.values[r['source'] as int],
        items: (jsonDecode(r['items'] as String) as List)
            .map((j) => FoodItem.fromJson(j as Map<String, dynamic>))
            .toList(),
        imagePath: r['image'] as String?,
        note: r['note'] as String?,
      );

  Future<List<DiaryEntry>> entriesForDay(DateTime day) async {
    final d = await db;
    final rows = await d.query('entries',
        where: 'day = ? AND deleted = 0',
        whereArgs: [dayKey(day)],
        orderBy: 'time ASC');
    return rows.map(_row).toList();
  }

  Future<List<DaySummary>> dailyTotals({required int days}) async {
    final d = await db;
    final from = DateTime.now().subtract(Duration(days: days - 1));
    final rows = await d.rawQuery(
      'SELECT day, SUM(kcal) AS k, COUNT(*) AS n FROM entries WHERE day >= ? AND deleted = 0 GROUP BY day ORDER BY day',
      [dayKey(from)],
    );
    return rows
        .map((r) => DaySummary(DateTime.parse(r['day'] as String),
            (r['k'] as num).toDouble(), r['n'] as int))
        .toList();
  }

  Future<Map<String, num>> lifetimeStats() async {
    final d = await db;
    final r = (await d.rawQuery(
            'SELECT COUNT(*) AS n, COUNT(DISTINCT day) AS days, COALESCE(SUM(kcal),0) AS k FROM entries WHERE deleted = 0'))
        .first;
    return {'n': r['n'] as int, 'days': r['days'] as int, 'k': r['k'] as num};
  }

  Future<int> water(DateTime day) async {
    final d = await db;
    final rows =
        await d.query('water', where: 'day = ?', whereArgs: [dayKey(day)]);
    return rows.isEmpty ? 0 : rows.first['glasses'] as int;
  }

  Future<void> setWater(DateTime day, int glasses) async {
    final d = await db;
    await d.insert('water', {'day': dayKey(day), 'glasses': glasses, 'updated': _now()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setWeight(DateTime day, double kg) async {
    final d = await db;
    await d.insert('weight', {'day': dayKey(day), 'kg': kg, 'updated': _now()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MapEntry<DateTime, double>>> weights({int limit = 60}) async {
    final d = await db;
    final rows = await d.query('weight', orderBy: 'day DESC', limit: limit);
    return rows
        .map((r) => MapEntry(
            DateTime.parse(r['day'] as String), (r['kg'] as num).toDouble()))
        .toList()
        .reversed
        .toList();
  }

  Future<Map<String, dynamic>?> cachedProduct(String barcode) async {
    final d = await db;
    final rows =
        await d.query('products', where: 'barcode = ?', whereArgs: [barcode]);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['json'] as String) as Map<String, dynamic>;
  }

  Future<void> cacheProduct(String barcode, Map<String, dynamic> j) async {
    final d = await db;
    await d.insert('products', {'barcode': barcode, 'json': jsonEncode(j)},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------------- Wi-Fi eşitleme ----------------

  /// Bütün günlük (silinenler dahil), su ve kilo kayıtları.
  /// Fotoğraf dosya yolu cihaza özel olduğundan gönderilmez.
  Future<Map<String, dynamic>> exportAll() async {
    final d = await db;
    final e = await d.query('entries');
    return {
      'app': 'kalori',
      'schema': 2,
      'entries': [
        for (final r in e)
          {
            'uid': r['uid'],
            'time': r['time'],
            'meal': r['meal'],
            'source': r['source'],
            'items': r['items'],
            'kcal': r['kcal'],
            'note': r['note'],
            'updated': r['updated'],
            'deleted': r['deleted'],
          }
      ],
      'water': await d.query('water'),
      'weight': await d.query('weight'),
    };
  }

  /// Karşı cihazdan gelenleri birleştirir. Kural: kimliği olmayan kayıt eklenir,
  /// aynı kimlikte yalnızca daha yeni olan kazanır. Hiçbir kayıt kendiliğinden
  /// silinmez; silme yalnızca karşıda gerçekten silinmiş (ve daha yeni) ise.
  Future<Map<String, int>> mergeAll(Map<String, dynamic> j) async {
    if (j['app'] != 'kalori') throw const FormatException('not kalori data');
    final d = await db;
    var added = 0, updated = 0;
    await d.transaction((tx) async {
      for (final raw in (j['entries'] as List? ?? const [])) {
        final r = Map<String, dynamic>.from(raw as Map);
        final uid = r['uid'] as String?;
        if (uid == null || uid.isEmpty) continue;
        final t = (r['time'] as num).toInt();
        final row = {
          'time': t,
          'day': dayKey(DateTime.fromMillisecondsSinceEpoch(t)),
          'meal': r['meal'],
          'source': r['source'],
          'items': r['items'],
          'kcal': r['kcal'],
          'note': r['note'],
          'updated': (r['updated'] as num?)?.toInt() ?? t,
          'deleted': (r['deleted'] as num?)?.toInt() ?? 0,
        };
        final mine = await tx.query('entries',
            columns: ['updated'], where: 'uid = ?', whereArgs: [uid]);
        if (mine.isEmpty) {
          await tx.insert('entries', {...row, 'uid': uid});
          if (row['deleted'] == 0) added++;
        } else if ((row['updated'] as int) > ((mine.first['updated'] as num?)?.toInt() ?? 0)) {
          await tx.update('entries', row, where: 'uid = ?', whereArgs: [uid]);
          updated++;
        }
      }
      for (final table in const ['water', 'weight']) {
        for (final raw in (j[table] as List? ?? const [])) {
          final r = Map<String, dynamic>.from(raw as Map);
          final day = r['day'] as String?;
          if (day == null) continue;
          final mine = await tx.query(table, where: 'day = ?', whereArgs: [day]);
          final ru = (r['updated'] as num?)?.toInt() ?? 0;
          if (mine.isEmpty) {
            await tx.insert(table, r);
            added++;
          } else if (ru > ((mine.first['updated'] as num?)?.toInt() ?? 0)) {
            await tx.update(table, r, where: 'day = ?', whereArgs: [day]);
            updated++;
          }
        }
      }
    });
    return {'added': added, 'updated': updated};
  }
}
