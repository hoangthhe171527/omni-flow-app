// Rà từng dòng mọi file .dart trong lib/ theo luật spec phong cách iOS (§3).
// node audit-lines.mjs <lib> <out.csv>
// Cột: module,file,line,code,hit,text. Mã:
//  K kính/mờ tự vẽ · N nút kính tự vẽ · C chọn trắng mờ · T chữ tô màu trạng thái/màu chính
//  S chip Material / SegmentedButton · L logo ngoài đăng nhập · M widget Material lạ iOS
//  R bo góc ngoài thang 6/10/16/32/tròn · G gradient · H bóng đổ trên thẻ · P viên thuốc 999 không phải nút
import fs from 'node:fs';
import path from 'node:path';

const [lib, out] = process.argv.slice(2);
const rules = [
  ['K', /\bOmniGlass\(|BackdropFilter|ImageFilter\.blur|\b_Glass\w+\b|OmniGlassAlert/],
  ['N', /OmniGlass\.buttonDecoration/],
  ['C', /OmniGlass\.selectionOf/],
  ['T', /color:\s*(scheme\.primary|cs\.primary|colorScheme\.primary|OmniColors\.(warning|success|danger|destructive|info)\w*)/],
  ['S', /\b(ChoiceChip|FilterChip|SegmentedButton|InputChip|ActionChip)\b/],
  ['L', /\b(OmniBrandMark|BrandAnchor|OmniWordmark)\b/],
  ['M', /\b(ListTile|AlertDialog|showDatePicker|DropdownButton\w*|PopupMenuButton|SimpleDialog|showDialog|ExpansionTile|Stepper|BottomNavigationBar|NavigationBar|TabBar)\b/],
  ['R', /(BorderRadius\.circular|Radius\.circular)\(\s*(\d+(?:\.\d+)?)\s*\)/g],
  ['G', /\b(LinearGradient|RadialGradient|SweepGradient)\b/],
  ['H', /\bboxShadow\b/],
];
const okRadius = new Set(['6', '8', '10', '16', '32', '999', '99', '100', '0', '2', '3', '1', '4']);
const rows = [];
function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p);
    else if (e.name.endsWith('.dart') && !e.name.endsWith('.g.dart') && !e.name.endsWith('.freezed.dart')) scan(p);
  }
}
function scan(p) {
  const rel = path.relative(lib, p).replaceAll('\\', '/');
  const mod = rel.match(/^modules\/([^/]+)\//)?.[1] ?? (rel.startsWith('app/') ? 'app/' + rel.split('/')[1] : rel.split('/')[0]);
  const lines = fs.readFileSync(p, 'utf8').split('\n');
  lines.forEach((ln, i) => {
    const t = ln.trim();
    if (t.startsWith('//') || t.startsWith('///') || t.startsWith('*') || t.startsWith('import ')) return;
    for (const [code, re] of rules) {
      if (code === 'R') {
        for (const m of ln.matchAll(re)) if (!okRadius.has(m[2])) rows.push([mod, rel, i + 1, 'R', m[2], t]);
      } else {
        const m = ln.match(re);
        if (m) rows.push([mod, rel, i + 1, code, m[0], t]);
      }
    }
  });
}
walk(lib);
const esc = (v) => `"${String(v).replaceAll('"', '""')}"`;
fs.writeFileSync(out, '﻿module,file,line,code,hit,text\n' + rows.map((r) => r.map(esc).join(',')).join('\n'));
const by = {};
for (const r of rows) by[r[3]] = (by[r[3]] ?? 0) + 1;
console.log('hits', rows.length, JSON.stringify(by), 'files', new Set(rows.map((r) => r[1])).size);
