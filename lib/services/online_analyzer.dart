import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../data/models.dart';
import '../data/settings.dart';
import 'ai_error.dart';

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

  static String _prompt(String lang, [String? hint]) {
    final langName = switch (lang) {
      'tr' => 'Turkish',
      'ar' => 'Arabic',
      _ => 'English',
    };
    _langNameCache = langName;
    return '''
You are a professional nutritionist. Analyze the photo and estimate the calories of everything edible in it.
It may be a plate of food, fruit, a snack, chocolate, biscuits, a drink or a packaged product.
Identify each distinct food item, estimate its weight in grams from visual cues (plate size, typical portions),
and give nutrition values per 100 g. Be realistic; use standard nutrition tables.
Write the item names in $langName.
Respond ONLY with JSON in exactly this shape:
{"is_food": true, "items": [{"name": "...", "grams": 150, "kcal_per_100g": 120, "protein_per_100g": 5, "carbs_per_100g": 20, "fat_per_100g": 3, "confidence": 0.8}], "note": "short optional remark in $langName"}
If there is no food in the photo, respond {"is_food": false, "items": [], "note": "..."}.${_hintBlock(hint)}''';
  }

  /// Extra instructions when the user typed what is on the plate.
  static String _hintBlock(String? hint) {
    final h = hint?.trim() ?? '';
    if (h.isEmpty) return '';
    return '''

IMPORTANT: the user told you what is on the plate (it may be written in Turkish, English or Arabic):
<user_list>
$h
</user_list>
Treat this list as ground truth: include every food the user listed, using the user's names (translated to $_langNameCache if needed).
If the user gave an amount (grams, pieces, spoons, slices, cups, glasses), use it to compute the grams; otherwise estimate the portion from the photo.
Use the photo for portion sizes, cooking style (fried, oily, sauce, dressing) and any extra visible items the user did not mention.
Because the user confirmed the food, always set "is_food": true and use confidence 0.9 or higher for the items the user listed.''';
  }

  static String _langNameCache = 'English';

  /// Plate lists typed by the user, by image path (used on re-analysis).
  static final Map<String, String> hints = {};

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

  static AnalysisResult _parse(String text, String model) {
    var t = text.trim();
    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start >= 0 && end > start) t = t.substring(start, end + 1);
    final j = jsonDecode(t) as Map<String, dynamic>;
    final isFood = j['is_food'] != false;
    final items = <FoodItem>[];
    for (final it in (j['items'] as List? ?? [])) {
      final m = it as Map<String, dynamic>;
      double n(String k, [double d = 0]) => (m[k] as num?)?.toDouble() ?? d;
      final grams = n('grams', 100);
      if (grams <= 0) continue;
      items.add(FoodItem(
        name: (m['name'] as String? ?? '?').trim(),
        grams: grams,
        kcalPer100: n('kcal_per_100g'),
        proteinPer100: n('protein_per_100g'),
        carbsPer100: n('carbs_per_100g'),
        fatPer100: n('fat_per_100g'),
        confidence: n('confidence', 0.7).clamp(0, 1),
      ));
    }
    return AnalysisResult(
      items: isFood ? items : [],
      source: AnalysisSource.ai,
      note: j['note'] as String?,
      modelUsed: model,
    );
  }

  static Future<AnalysisResult?> analyze(File file, String lang,
      {String? hint}) async {
    if (hint != null && hint.trim().isNotEmpty) {
      hints[file.path] = hint;
    } else {
      hint = hints[file.path]; // re-analysis keeps the user's list
    }
    final s = Settings.instance;
    final image = await prepareImage(file);
    final b64 = base64Encode(image);
    final prompt = _prompt(lang, hint);
    AiError? best;
    void keep(Object e, String provider) {
      final err = toAiError(e, provider);
      if (best == null || err.priority > best!.priority) best = err;
    }

    // The key typed in Settings first, then the one bundled with the app.
    for (final key in s.geminiKeys) {
      for (final model in geminiModels) {
        try {
          final r = await _gemini(key, model, prompt, b64);
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
        final r = await _openAi(s.openAiKey, prompt, b64);
        if (r != null) return r;
      } catch (e) {
        keep(e, 'OpenAI');
      }
    }
    if (s.claudeKey.isNotEmpty) {
      try {
        final r = await _claude(s.claudeKey, prompt, b64);
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

  static Future<AnalysisResult?> _gemini(
      String key, String model, String prompt, String b64) async {
    final text = await _geminiRaw(key, model, prompt, b64);
    if (text == null) return null;
    return _parse(text, model);
  }

  static Future<String?> _geminiRaw(
      String key, String model, String prompt, String? b64) async {
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key');
    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
            if (b64 != null)
              {
                'inline_data': {'mime_type': 'image/jpeg', 'data': b64}
              }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
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
      String key, String prompt, String b64) async {
    final text = await _openAiRaw(key, prompt, b64);
    if (text == null) return null;
    return _parse(text, 'gpt-4o-mini');
  }

  static Future<String?> _openAiRaw(
      String key, String prompt, String? b64) async {
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final body = {
      'model': 'gpt-4o-mini',
      'temperature': 0.2,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            if (b64 != null)
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$b64'}
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
    if (res.statusCode != 200) {
      throw AiError.fromHttp('OpenAI', res.statusCode, res.body);
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return j['choices'][0]['message']['content'] as String?;
  }

  static Future<AnalysisResult?> _claude(
      String key, String prompt, String b64) async {
    final text = await _claudeRaw(key, prompt, b64);
    if (text == null) return null;
    return _parse(text, 'claude');
  }

  static Future<String?> _claudeRaw(
      String key, String prompt, String? b64) async {
    final uri = Uri.parse('https://api.anthropic.com/v1/messages');
    final body = {
      'model': 'claude-sonnet-4-5',
      'max_tokens': 1024,
      'messages': [
        {
          'role': 'user',
          'content': [
            if (b64 != null)
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': 'image/jpeg',
                  'data': b64
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
    if (res.statusCode != 200) {
      throw AiError.fromHttp('Claude', res.statusCode, res.body);
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return (j['content'] as List).first['text'] as String?;
  }
}
