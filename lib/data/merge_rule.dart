/// Ortak çekirdek eşitleme kuralı (lan-sync-merge): hiçbir kayıt kalıcı olarak silinmez
/// ya da iz bırakmadan üstüne yazılmaz.
///  - yerelde yoksa → eklenir
///  - karşıdaki daha yeniyse → yerel eski hâl `cakisma` tablosuna yedeklenir, sonra güncellenir
///    (karşıda silinmişse kayıt yerelde "arşivlendi" olur: deleted=1, Arşiv'den geri getirilebilir)
///  - aksi hâlde → yerel kalır
enum MergeAction { insert, backupAndReplace, keep }

MergeAction mergeDecision({required bool exists, required int mineUpdated, required int theirsUpdated}) {
  if (!exists) return MergeAction.insert;
  if (theirsUpdated > mineUpdated) return MergeAction.backupAndReplace;
  return MergeAction.keep;
}
