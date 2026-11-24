import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../data/models.dart';
import '../data/settings.dart';
import 'ai_error.dart';
import 'food_db.dart';
import 'nutrition_db.dart';
import 'usage.dart';

/// Online photo analysis. Tries Gemini first, then OpenAI, then Claude,
/// depending on which API keys are available.
class OnlineAnalyzer {
  static const geminiModels = [
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-flash-latest',
    'gemini-flash-lite-latest',
  ];

  static const _timeout = Duration(seconds: 45);

  static String _langName(String lang) => switch (lang) {
        'tr' => 'Turkish',
        'ar' => 'Arabic',
        _ => 'English',
      };

  /// Size reference sentence for the prompt.
  static String _refText(String ref) {
    final cm = Settings.instance.plateCm;
    return switch (ref) {
      'card' =>
        'A standard bank card (8.56 x 5.4 cm) is placed next to the food: use it as the scale.',
      'fork' =>
        'A standard dinner fork (about 19 cm long) is placed next to the food: use it as the scale.',
      'spoon' =>
        'A standard tablespoon (about 17 cm long) is placed next to the food: use it as the scale.',
      'plate' when cm > 0 =>
        'The plate in the photo is exactly $cm cm in diameter: use it as the scale.',
      _ => cm > 0
          ? 'If a dinner plate is visible, it is $cm cm in diameter.'
          : 'No reference object: judge the scale from the plate (a dinner plate is usually 26 cm), bowls, glasses (a Turkish tea glass holds 100 ml, a water glass 200 ml) and cutlery.',
    };
  }

  static String _prompt(String lang, PlateInput input) {
    final l = _langName(lang);
    final side = input.side != null;
    return '''
You are a professional dietitian. Estimate the portion size of every edible item in the photo${side ? 's' : ''} as precisely as possible.
${side ? 'Image 1 shows the meal from above or the front, image 2 shows the SAME meal from the side: use image 2 to judge height / depth, so the volume is right.' : 'Judge height from shadows, perspective and the rim of the plate or bowl.'}
${_refText(input.ref)}
For each distinct food or drink:
1. identify it (dish name, cooking method, visible oil, sauce, dressing, sugar);
2. estimate the area it covers relative to the reference, and its height;
3. convert volume to edible grams with a typical density (exclude bones, shells, peels, packaging);
4. give the most likely weight and a realistic low / high range (not too wide).
Packaged products: if the package size is readable, use it.
Write "name" in $l. "name_en" is a short English food name, "usda" the closest USDA SR food description in English (e.g. "Rice, white, long-grain, regular, cooked").
Nutrition per 100 g is only a fallback for foods missing from our tables: use standard food composition values.
"cooking": raw, boiled, grilled, baked, stewed or fried. "oil": none, normal or high (visible oil / butter / dressing compared with a usual home recipe).
"question": when something you cannot see changes the calories by more than about 15 % (fried or baked, sugar in tea, hidden sauce, full-fat or light), ask the user ONE short question in $l; otherwise "".
Respond ONLY with JSON in exactly this shape:
{"is_food": true, "items": [{"name": "...", "name_en": "...", "usda": "...", "grams": 180, "grams_min": 150, "grams_max": 210, "cooking": "boiled", "oil": "normal", "kcal_per_100g": 130, "protein_per_100g": 2.7, "carbs_per_100g": 28, "fat_per_100g": 0.3, "confidence": 0.8, "question": ""}], "note": "short optional remark in $l"}
If there is no food, respond {"is_food": false, "items": [], "note": "..."}.${_hintBlock(input.hint, l)}''';
  }

  /// Extra instructions when the user typed what is on the plate.
  static String _hintBlock(String? hint, String langName) {
    final h = hint?.trim() ?? '';
    if (h.isEmpty) return '';
    return '''

IMPORTANT: the user told you what is on the plate (it may be written in Turkish, English or Arabic):
<user_list>
$h
</user_list>
Treat this list as ground truth: include every food the user listed, using the user's names (translated to $langName if needed).
If the user gave an amount (grams, pieces, spoons, slices, cups, glasses), use it to compute the grams and keep the range narrow; otherwise estimate the portion from the photo.
Use the photo for portion sizes, cooking style and any extra visible items the user did not mention.
Because the user confirmed the food, always set "is_food": true and use confidence 0.9 or higher for the items the user listed.''';
  }

  /// What the user gave for an image (used on re-analysis).
  static final Map<String, PlateInput> inputs = {};

  /// Downscale + JPEG encode to keep uploads small.
  static Future<List<int>> prepareImage(File file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final oriented = img.bakeOrientation(decoded);
    final resized = oriented.width > 1024 || oriented.height > 1024
        ? img.copyResize(oriented,
            width: oriented.width >= oriented.height ? 1024 : null,
            height: oriented.height > oriented.width ? 1024 : null)
        : oriented;
    return img.encodeJpg(resized, quality: 85);
  }

  static const _cooks = {'raw', 'boiled', 'grilled', 'baked', 'stewed', 'fried'};

  static AnalysisResult _parse(String text, String model, String lang) {
    var t = text.trim();
    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start >= 0 && end > start) t = t.substring(start, end + 1);
    final j = jsonDecode(t) as Map<String, dynamic>;
    final isFood = j['is_food'] != false;
    final items = <FoodItem>[];
    for (final raw in (j['items'] as List? ?? [])) {
      final m = raw as Map<String, dynamic>;
      double n(String k, [double d = 0]) => (m[k] as num?)?.toDouble() ?? d;
      String? str(String k) {
        final v = (m[k] as String?)?.trim();
        return v == null || v.isEmpty ? null : v;
      }

      final grams = n('grams', 100).roundToDouble();
      if (grams <= 0) continue;
      var gMin = (m['grams_min'] as num?)?.toDouble();
      var gMax = (m['grams_max'] as num?)?.toDouble();
      if (gMin != null && (gMin <= 0 || gMin > grams)) gMin = null;
      if (gMax != null && gMax < grams) gMax = null;
      final cook = _cooks.contains(str('cooking')) ? str('cooking') : null;
      final oil = str('oil');
      final it = FoodItem(
        name: str('name') ?? '?',
        grams: grams,
        kcalPer100: n('kcal_per_100g'),
        proteinPer100: n('protein_per_100g'),
        carbsPer100: n('carbs_per_100g'),
        fatPer100: n('fat_per_100g'),
        confidence: n('confidence', 0.7).clamp(0, 1),
        nameEn: str('usda') ?? str('name_en'),
        gramsMin: gMin,
        gramsMax: gMax,
        question: str('question'),
      );
      // 1) calories from the tables, 2) AI only as a fallback
      final enShort = str('name_en');
      NutritionDb.instance.resolve(it,
          names: [it.name, enShort], usdaNames: [str('usda'), enShort]);
      if (it.dataSource == 'db') {
        // table values have their own cooking style; the photo's style
        // and visible oil adjust them
        final f = it.foodId == null ? null : FoodDb.instance.byId(it.foodId!);
        it.cookBase = f == null ? cook : FoodItem.guessCook('${f.en} ${f.tr}');
        it.cook = cook ?? it.cookBase;
        if (oil == 'high' || oil == 'none') it.oil = oil!;
      } else {
        // USDA descriptions / AI values already describe this cooking
        it.cookBase = cook ?? FoodItem.guessCook(it.nameEn ?? it.name);
        it.cook = it.cookBase;
      }
      items.add(it);
    }
    return AnalysisResult(
      items: isFood ? items : [],
      source: AnalysisSource.ai,
      note: j['note'] as String?,
      modelUsed: model,
    );
  }

  static Future<AnalysisResult?> analyze(File file, String lang,
      {PlateInput? input}) async {
    if (input != null) {
      inputs[file.path] = input;
    } else {
      input = inputs[file.path] ?? const PlateInput(); // re-analysis
    }
    await NutritionDb.instance.load();
    final s = Settings.instance;
    final b64 = <String>[base64Encode(await prepareImage(file))];
    final side = input.side;
    if (side != null && await side.exists()) {
      b64.add(base64Encode(await prepareImage(side)));
    }
    final prompt = _prompt(lang, input);
    AiError? best;
    void keep(Object e, String provider) {
      final err = toAiError(e, provider);
      if (best == null || err.priority > best!.priority) best = err;
    }

    // The key typed in Settings first, then the one bundled with the app.
    for (final key in s.geminiKeys) {
      for (final model in geminiModels) {
        try {
          final r = await _gemini(key, model, prompt, b64, lang);
          if (r != null) return r;
        } catch (e) {
          final err = toAiError(e, 'Gemini');
          keep(err, 'Gemini');
          // no point trying other models with this key
          if (err.kind == AiErrorKind.invalidKey ||
              err.kind == AiErrorKind.denied ||
              err.kind == AiErrorKind.region) {
            break;
          }
        }
      }
    }
    if (s.openAiKey.isNotEmpty) {
      try {
        final r = await _openAi(s.openAiKey, prompt, b64, lang);
        if (r != null) return r;
      } catch (e) {
        keep(e, 'OpenAI');
      }
    }
    if (s.claudeKey.isNotEmpty) {
      try {
        final r = await _claude(s.claudeKey, prompt, b64, lang);
        if (r != null) return r;
      } catch (e) {
        keep(e, 'Claude');
      }
    }
    if (s.geminiKey.isEmpty && s.openAiKey.isEmpty && s.claudeKey.isEmpty) {
      throw AiError(AiErrorKind.noKey, '-', 'no API key');
    }
    throw best ?? AiError(AiErrorKind.other, '-', 'empty response');
  }

  static AiError toAiError(Object e, String provider) {
    if (e is AiError) return e;
    if (e is TimeoutException) {
      return AiError(AiErrorKind.timeout, provider, e.toString());
    }
    if (e is SocketException || e is http.ClientException) {
      return AiError(AiErrorKind.network, provider, e.toString());
    }
    return AiError(AiErrorKind.other, provider, e.toString());
  }

  /// Sends a tiny text-only request to every provider that has a key.
  /// Returns provider -> null (works) or the error.
  static Future<Map<String, AiError?>> testAll() async {
    final s = Settings.instance;
    const p = 'Reply with JSON: {"ok": true}';
    final out = <String, AiError?>{};
    Future<void> run(String name, Future<Object?> Function() f) async {
      try {
        await f();
        out[name] = null;
      } catch (e) {
        out[name] = toAiError(e, name);
      }
    }

    if (s.geminiKeys.isEmpty) {
      out['Gemini'] = AiError(AiErrorKind.noKey, 'Gemini', '');
    } else {
      final manual = s.manualGeminiKey;
      if (manual.isNotEmpty) {
        await run('Gemini (elle)',
            () => _geminiRaw(manual, geminiModels.first, p, null));
      }
      if (kBundledGeminiKey.isNotEmpty && kBundledGeminiKey != manual) {
        await run('Gemini (app)',
            () => _geminiRaw(kBundledGeminiKey, geminiModels.first, p, null));
      }
    }
    if (s.openAiKey.isEmpty) {
      out['OpenAI'] = AiError(AiErrorKind.noKey, 'OpenAI', '');
    } else {
      await run('OpenAI', () => _openAiRaw(s.openAiKey, p, null));
    }
    if (s.claudeKey.isEmpty) {
      out['Claude'] = AiError(AiErrorKind.noKey, 'Claude', '');
    } else {
      await run('Claude', () => _claudeRaw(s.claudeKey, p, null));
    }
    return out;
  }

  static Future<AnalysisResult?> _gemini(String key, String model,
      String prompt, List<String> b64, String lang) async {
    final text = await _geminiRaw(key, model, prompt, b64);
    if (text == null) return null;
    return _parse(text, model, lang);
  }

  static Future<String?> _geminiRaw(
      String key, String model, String prompt, List<String>? b64) async {
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key');
    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
            for (final im in b64 ?? const <String>[])
              {
                'inline_data': {'mime_type': 'image/jpeg', 'data': im}
              }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0, // same photo -> same answer
        'response_mime_type': 'application/json',
        // Gemini 3.x "thinks" for ~30 s by default; low is ~3x faster.
        if (model.startsWith('gemini-3'))
          'thinkingConfig': {'thinkingLevel': 'low'},
      }
    };
    final res = await http
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body))
        .timeout(_timeout);
    await Usage.record(res.statusCode, res.body); // Ayarlar > Kullanım Limitleri
    if (res.statusCode != 200) {
      throw AiError.fromHttp('Gemini', res.statusCode, res.body);
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    // Newer models may return "thought" parts first: join only answer text.
    final parts = ((((j['candidates'] as List?)?.firstOrNull as Map?)?['content']
            as Map?)?['parts'] as List?) ??
        const [];
    final text = parts
        .whereType<Map>()
        .where((p) => p['thought'] != true && p['text'] is String)
        .map((p) => p['text'] as String)
        .join();
    return text.isEmpty ? null : text;
  }

  static Future<AnalysisResult?> _openAi(
      String key, String prompt, List<String> b64, String lang) async {
    final text = await _openAiRaw(key, prompt, b64);
    if (text == null) return null;
    return _parse(text, 'gpt-4o-mini', lang);
  }

  static Future<String?> _openAiRaw(
      String key, String prompt, List<String>? b64) async {
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final body = {
      'model': 'gpt-4o-mini',
      'temperature': 0,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            for (final im in b64 ?? const <String>[])
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$im'}
              }
          ]
        }
      ]
    };
    final res = await http
        .post(uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key'
            },
            body: jsonEncode(body))
        .timeout(_timeout);
    await Usage.record(res.statusCode, res.body); // Ayarlar > Kullanım Limitleri
    if (res.statusCode != 200) {
      throw AiError.fromHttp('OpenAI', res.statusCode, res.body);
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return j['choices'][0]['message']['content'] as String?;
  }

  static Future<AnalysisResult?> _claude(
      String key, String prompt, List<String> b64, String lang) async {
    final text = await _claudeRaw(key, prompt, b64);
    if (text == null) return null;
    return _parse(text, 'claude', lang);
  }

  static Future<String?> _claudeRaw(
      String key, String prompt, List<String>? b64) async {
    final uri = Uri.parse('https://api.anthropic.com/v1/messages');
    final body = {
      'model': 'claude-sonnet-4-5',
      'max_tokens': 2048,
      'temperature': 0,
      'messages': [
        {
          'role': 'user',
          'content': [
            for (final im in b64 ?? const <String>[])
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': 'image/jpeg',
                  'data': im
                }
              },
            {'type': 'text', 'text': prompt}
          ]
        }
      ]
    };
    final res = await http
        .post(uri,
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': key,
              'anthropic-version': '2023-06-01'
            },
            body: jsonEncode(body))
        .timeout(_timeout);
    await Usage.record(res.statusCode, res.body); // Ayarlar > Kullanım Limitleri
    if (res.statusCode != 200) {
      throw AiError.fromHttp('Claude', res.statusCode, res.body);
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return (j['content'] as List).first['text'] as String?;
  }
}
