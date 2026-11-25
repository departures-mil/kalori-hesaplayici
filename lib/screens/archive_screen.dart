import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import '../widgets/common.dart';

/// Ayarlar → Arşiv: silinen kayıtlar kalıcı olarak silinmez; buradan geri getirilir.
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<DiaryEntry>? _items;
  List<SavedMeal> _saved = [];
  int _conflicts = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await AppDb.instance.archivedEntries();
    final c = await AppDb.instance.conflictCount();
    final sv = await AppDb.instance.archivedSaved();
    if (mounted) {
      setState(() {
        _items = a;
        _saved = sv;
        _conflicts = c;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final items = _items;
    final fmt = DateFormat.yMMMd(s.code).add_Hm();
    return Scaffold(
      appBar: AppBar(title: Text(s['arch_title'])),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Text(s['arch_desc'], style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Text(s.f('arch_conflicts', {'n': _conflicts}),
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 14),
                Text(s['arch_deleted'], style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (items.isEmpty) Text(s['arch_empty']),
                for (final e in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SoftCard(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${fmt.format(e.time)} · ${e.kcal.round()} ${s['kcal']}',
                                  style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await AppDb.instance.restoreEntry(e.id!);
                            if (!context.mounted) return;
                            showSnack(context, s['arch_restored']);
                            _load();
                          },
                          icon: const Icon(Icons.restore_rounded, size: 18),
                          label: Text(s['arch_restore']),
                        ),
                      ]),
                    ),
                  ),
                if (_saved.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(s['arch_saved'], style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final m in _saved)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SoftCard(
                        padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 10),
                        child: Row(children: [
                          Icon(m.isRecipe ? Icons.soup_kitchen_rounded : Icons.star_rounded,
                              color: AppColors.inkSoft, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(m.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await AppDb.instance.restoreSaved(m.uid!);
                              if (!context.mounted) return;
                              showSnack(context, s['arch_restored']);
                              _load();
                            },
                            icon: const Icon(Icons.restore_rounded, size: 18),
                            label: Text(s['arch_restore']),
                          ),
                        ]),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
