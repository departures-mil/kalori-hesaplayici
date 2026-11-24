#!/usr/bin/env node
/* Falcon renk şemalarını Dart'a çevirir: lib/core/fc_tokens.dart
 *   node tool/gen_fc_tokens.js           → dosyayı yazar
 *   node tool/gen_fc_tokens.js --check   → dosya güncel değilse çıkış kodu 1 (CI)
 * Kaynak: cekirdek/schemes.js (ortak-cekirdek web/tools/schemes.js kopyası, commit cekirdek/VERSION)
 *         + uygulamanın eski görünümü "klasik" (aşağıda; v1.0.x pembe/lavanta renkleri).
 * Çekirdek güncellenince: cp ../ortak-cekirdek/web/tools/schemes.js cekirdek/ && node tool/gen_fc_tokens.js */
'use strict';
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const { TOKENS, SCHEMES, derive } = require(path.join(root, 'cekirdek', 'schemes.js'));

const DARK_STATUS = { danger: '#f43f5e', warn: '#f59e0b', ok: '#34d399', okText: '#6ee7b7', dangerText: '#fda4af', warnText: '#fcd34d', errBg: '#2a0f17', errText: '#fecdd3' };
const LIGHT_STATUS = { danger: '#be123c', warn: '#b45309', ok: '#047857', okText: '#047857', dangerText: '#9f1239', warnText: '#92400e', errBg: '#fff1f2', errText: '#9f1239' };

/* klasik = Kalori Hesaplayıcı 1.0.x görünümü (lib/core/theme.dart AppColors): açık mod birebir eski renkler */
const KLASIK = {
  light: derive({
    bg: '#fff7fa', panelSolid: '#ffffff', panelHover: '#fdeff4', text: '#3b2a3f', muted: '#7a6a80', label: '#5a4a60',
    navText: '#3b2a3f', navTitle: '#7a6a80', accent: '#e75480', accent2: '#9b7ede', primary1: '#e75480', primary2: '#9b7ede',
    line: '#9b7ede', sidebar: '#fff7fa', topbar: '#fff7fa', modal: '#ffffff', toastBg: '#3b2a3f', toastText: '#ffffff',
    badgeText: '#3b2a3f', onBadge: '#ffffff', ...LIGHT_STATUS, over: { 'toast-line': '#3b2a3f' }
  }, false),
  dark: derive({
    bg: '#1b1220', panelSolid: '#271a2d', panelHover: '#312236', text: '#f6eaf1', muted: '#bba8c1', label: '#d8c6de',
    navText: '#e6d6ea', navTitle: '#9c88a3', accent: '#f27aa0', accent2: '#b49cf0', primary1: '#e75480', primary2: '#9b7ede',
    line: '#d9ccf5', sidebar: '#1d1322', topbar: '#1b1220', modal: '#241829', toastBg: '#2f1f35', toastText: '#f6eaf1',
    badgeText: '#ecdfff', onBadge: '#1b1220', ...DARK_STATUS
  }, true),
  label: { tr: 'Klasik (eski görünüm)', en: 'Classic (old look)', ar: 'كلاسيكي (المظهر القديم)' }
};

const ORDER = ['falcon', 'klasik', 'zumrut', 'gunbatimi', 'mor', 'okyanus', 'grafit', 'yuksek-kontrast'];
const LABELS = {
  falcon: { tr: 'Falcon (varsayılan)', en: 'Falcon (default)', ar: 'فالكون (الافتراضي)' },
  klasik: KLASIK.label,
  zumrut: { tr: 'Zümrüt', en: 'Emerald', ar: 'زمردي' },
  gunbatimi: { tr: 'Gün batımı', en: 'Sunset', ar: 'الغروب' },
  mor: { tr: 'Mor', en: 'Violet', ar: 'بنفسجي' },
  okyanus: { tr: 'Okyanus', en: 'Ocean', ar: 'المحيط' },
  grafit: { tr: 'Grafit', en: 'Graphite', ar: 'رمادي غرافيتي' },
  'yuksek-kontrast': { tr: 'Yüksek kontrast', en: 'High contrast', ar: 'تباين عالٍ' }
};

function hexToDart(v) {
  let h = String(v).trim();
  if (!/^#[0-9a-fA-F]+$/.test(h)) return null;
  h = h.slice(1);
  if (h.length === 3 || h.length === 4) h = h.split('').map((c) => c + c).join('');
  if (h.length === 6) h += 'ff';
  if (h.length !== 8) return null;
  const rgb = h.slice(0, 6), a = h.slice(6, 8);
  return '0x' + (a + rgb).toUpperCase();
}

const all = Object.assign({}, SCHEMES, { klasik: KLASIK });
for (const id of ORDER) if (!all[id]) throw new Error('şema yok: ' + id);

const colorTokens = TOKENS.filter((t) => hexToDart(SCHEMES.falcon.dark[t]) !== null);

let out = '';
out += '// ÜRETİLDİ — elle düzenlemeyin: node tool/gen_fc_tokens.js\n';
out += '// Kaynak: cekirdek/schemes.js (ortak-cekirdek ' + fs.readFileSync(path.join(root, 'cekirdek', 'VERSION'), 'utf8').trim().slice(0, 7) + ') + tool/gen_fc_tokens.js (klasik)\n';
out += '// ignore_for_file: constant_identifier_names\n\n';
out += "import 'dart:ui' show Color;\n\n";
out += '/// Şema sırası (Ayarlar → Görünüm). Varsayılan: falcon.\n';
out += 'const List<String> kFcSchemeIds = [' + ORDER.map((x) => `'${x}'`).join(', ') + '];\n\n';
out += '/// Renk tokenları (CSS değişken adlarıyla aynı, başında -- olmadan).\n';
out += 'const List<String> kFcColorTokens = [' + colorTokens.map((x) => `'${x}'`).join(', ') + '];\n\n';
out += 'const Map<String, Map<String, String>> kFcSchemeLabels = {\n';
for (const id of ORDER) {
  const l = LABELS[id];
  out += `  '${id}': {'tr': ${JSON.stringify(l.tr)}, 'en': ${JSON.stringify(l.en)}, 'ar': ${JSON.stringify(l.ar)}},\n`;
}
out += '};\n\n';
out += '/// kFcTokens[şema][\'dark\'|\'light\'][token]\n';
out += 'const Map<String, Map<String, Map<String, Color>>> kFcTokens = {\n';
for (const id of ORDER) {
  out += `  '${id}': {\n`;
  for (const mode of ['dark', 'light']) {
    const t = all[id][mode];
    out += `    '${mode}': {\n`;
    for (const k of colorTokens) {
      const d = hexToDart(t[k]);
      if (d === null) throw new Error(`${id}.${mode}.${k} renk değil: ${t[k]}`);
      out += `      '${k}': Color(${d}),\n`;
    }
    out += '    },\n';
  }
  out += '  },\n';
}
out += '};\n';

const dest = path.join(root, 'lib', 'core', 'fc_tokens.dart');
if (process.argv.includes('--check')) {
  const cur = fs.existsSync(dest) ? fs.readFileSync(dest, 'utf8') : '';
  if (cur !== out) {
    console.error('lib/core/fc_tokens.dart güncel değil: node tool/gen_fc_tokens.js');
    process.exit(1);
  }
  console.log('fc_tokens.dart güncel (' + ORDER.length + ' şema, ' + colorTokens.length + ' renk tokenı)');
} else {
  fs.writeFileSync(dest, out);
  console.log('yazıldı: lib/core/fc_tokens.dart (' + ORDER.length + ' şema, ' + colorTokens.length + ' renk tokenı)');
}
