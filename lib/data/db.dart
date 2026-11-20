import 'dart:convert';

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
      version: 1,
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
            note TEXT
          )''');
        await d.execute('CREATE INDEX idx_day ON entries(day)');
        await d.execute('''
          CREATE TABLE water(day TEXT PRIMARY KEY, glasses INTEGER NOT NULL)''');
        await d.execute('''
          CREATE TABLE weight(day TEXT PRIMARY KEY, kg REAL NOT NULL)''');
        await d.execute('''
          CREATE TABLE products(barcode TEXT PRIMARY KEY, json TEXT NOT NULL)''');
      },
    );
    return _db!;
  }

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
      },
      where: 'id = ?',
      whereArgs: [e.id],
    );
  }

  Future<void> deleteEntry(int id) async {
    final d = await db;
    await d.delete('entries', where: 'id = ?', whereArgs: [id]);
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
        where: 'day = ?', whereArgs: [dayKey(day)], orderBy: 'time ASC');
    return rows.map(_row).toList();
  }

  Future<List<DaySummary>> dailyTotals({required int days}) async {
    final d = await db;
    final from = DateTime.now().subtract(Duration(days: days - 1));
    final rows = await d.rawQuery(
      'SELECT day, SUM(kcal) AS k, COUNT(*) AS n FROM entries WHERE day >= ? GROUP BY day ORDER BY day',
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
            'SELECT COUNT(*) AS n, COUNT(DISTINCT day) AS days, COALESCE(SUM(kcal),0) AS k FROM entries'))
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
    await d.insert('water', {'day': dayKey(day), 'glasses': glasses},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setWeight(DateTime day, double kg) async {
    final d = await db;
    await d.insert('weight', {'day': dayKey(day), 'kg': kg},
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
}
