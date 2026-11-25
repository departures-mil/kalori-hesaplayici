import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/settings.dart';
import '../l10n/strings.dart';
import '../services/native_bridge.dart';
import '../services/text_entry.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

/// 1.1.1 — "Yazarak / sesle ekle": bir cümleden öğün (tr / en / ar).
class QuickTextScreen extends StatefulWidget {
  final bool startVoice;
  const QuickTextScreen({super.key, this.startVoice = false});

  @override
  State<QuickTextScreen> createState() => _QuickTextScreenState();
}

class _QuickTextScreenState extends State<QuickTextScreen> {
  final _c = TextEditingController();
  bool _busy = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    if (widget.startVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _voice());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _voice() async {
    final s = S.of(context);
    setState(() => _listening = true);
    final t = await NativeBridge.speech(Settings.instance.lang);
    if (!mounted) return;
    setState(() => _listening = false);
    if (t == null || t.trim().isEmpty) {
      showSnack(context, s['qt_voice_none']);
      return;
    }
    final cur = _c.text.trim();
    _c.text = cur.isEmpty ? t.trim() : '$cur, ${t.trim()}';
    _c.selection = TextSelection.collapsed(offset: _c.text.length);
    setState(() {});
  }

  Future<void> _go() async {
    final s = S.of(context);
    final text = _c.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final r = await TextEntry.parse(text, Settings.instance.lang);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.items.isEmpty) {
      showSnack(context, s['qt_nothing']);
      return;
    }
    final added = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => ResultScreen(result: r)));
    if (added == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final examples = [s['qt_ex1'], s['qt_ex2'], s['qt_ex3']];
    return Scaffold(
      appBar: AppBar(title: Text(s['qt_title'])),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(s['qt_desc'], style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _c,
                    minLines: 3,
                    maxLines: 6,
                    autofocus: !widget.startVoice,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: s['qt_hint'],
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: _MicButton(listening: _listening, onTap: _listening ? null : _voice, tip: s['qt_voice']),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(s['qt_examples'], style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in examples)
              ActionChip(
                avatar: Icon(Icons.north_west_rounded, size: 16, color: AppColors.rose),
                label: Text(e),
                onPressed: () {
                  _c.text = e;
                  setState(() {});
                },
              ),
          ]),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy || _c.text.trim().isEmpty ? null : _go,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: _busy
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(_busy ? s['qt_working'] : s['qt_go']),
          ),
          const SizedBox(height: 10),
          Text(s['qt_note'], textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool listening;
  final VoidCallback? onTap;
  final String tip;
  const _MicButton({required this.listening, required this.onTap, required this.tip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: Semantics(
        button: true,
        label: tip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: kGradient,
              boxShadow: [
                if (listening)
                  BoxShadow(color: AppColors.rose.withValues(alpha: 0.5), blurRadius: 18, spreadRadius: 4),
              ],
            ),
            child: Icon(listening ? Icons.graphic_eq_rounded : Icons.mic_rounded, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
