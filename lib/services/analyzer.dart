import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../data/models.dart';
import 'ai_error.dart';
import 'offline_analyzer.dart';
import 'online_analyzer.dart';
import 'portion_learner.dart';

enum AnalysisStage { online, offline }

/// Orchestrates: online first, offline fallback.
class Analyzer {
  static Future<bool> isOnline() async {
    final c = await Connectivity().checkConnectivity();
    return !(c.contains(ConnectivityResult.none) || c.isEmpty);
  }

  static Future<AnalysisResult> analyze(
    File file,
    String lang, {
    PlateInput input = const PlateInput(),
    void Function(AnalysisStage)? onStage,
  }) async {
    final h = input.hint.trim().isEmpty ? null : input.hint.trim();
    String? note;
    AiError? err;
    if (await isOnline()) {
      onStage?.call(AnalysisStage.online);
      try {
        final r = await OnlineAnalyzer.analyze(file, lang, input: input);
        if (r != null) {
          PortionLearner.instance.apply(r.items, userListed: h != null);
          return AnalysisResult(
            items: r.items,
            source: r.source,
            note: r.note,
            imagePath: file.path,
            modelUsed: r.modelUsed,
            hint: h,
          );
        }
      } catch (e) {
        err = OnlineAnalyzer.toAiError(e, '-');
        note = err.kind == AiErrorKind.noKey ? 'no_key' : 'online_failed';
      }
    } else {
      note = 'no_internet';
    }
    onStage?.call(AnalysisStage.offline);
    final r = await OfflineAnalyzer.analyze(file, lang, hint: h);
    PortionLearner.instance.apply(r.items, userListed: h != null);
    return AnalysisResult(
      items: r.items,
      source: r.source,
      note: note,
      imagePath: file.path,
      modelUsed: r.modelUsed,
      hint: h,
      errorKey: err?.key,
      errorDetail: err?.toString(),
    );
  }
}
