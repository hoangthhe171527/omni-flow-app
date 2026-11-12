import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../data/inbox_api.dart';
import '../../domain/message.dart';

/// Nhóm "Tin nhắn" trong kết quả ô tìm Hộp thư (bug sheet 12/11/2026, đã duyệt
/// artifact mục 3): mỗi dòng là một TIN khớp nội dung — tên khách, giờ, nguồn
/// và đoạn trích tô vàng chỗ khớp. Chạm mở hội thoại tại đúng tin.
class MessageHitsSection extends StatelessWidget {
  const MessageHitsSection({
    super.key,
    required this.hits,
    required this.term,
    required this.onOpen,
  });

  final List<MessageSearchHit> hits;
  final String term;
  final void Function(MessageSearchHit hit) onOpen;

  @override
  Widget build(BuildContext context) {
    if (hits.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, OmniGroupSection.gap, 16, 0),
      child: OmniGroupSection(
        key: const Key('inbox-message-hits'),
        title: 'Tin nhắn · ${hits.length}',
        children: [
          for (final hit in hits)
            _HitRow(hit: hit, term: term, onTap: () => onOpen(hit)),
        ],
      ),
    );
  }
}

class _HitRow extends StatelessWidget {
  const _HitRow({required this.hit, required this.term, required this.onTap});

  final MessageSearchHit hit;
  final String term;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = hit.conversation;
    final m = hit.message;
    final secondary = scheme.onSurfaceVariant;
    final source = c.sourceAccount == null
        ? c.channel.sourceKind
        : '${c.channel.sourceKind} · ${c.sourceAccount}';

    return Semantics(
      button: true,
      label: '${c.title}: ${m.text}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Formatters.relative(m.sentAt),
                      style: OmniType.micro.copyWith(
                        color: secondary,
                        fontFeatures: OmniType.tabular,
                      ),
                    ),
                  ],
                ),
                Text(
                  source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.micro.copyWith(color: secondary),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      if (m.author == MessageAuthor.agent)
                        TextSpan(
                          text: 'Bạn: ',
                          style: TextStyle(color: secondary),
                        ),
                      ...highlightSpans(
                        m.text,
                        term,
                        TextStyle(
                          backgroundColor: OmniColors.sun.withValues(
                            alpha: .45,
                          ),
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.bodySm.copyWith(color: scheme.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);
final _split = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// Tô các chỗ khớp ĐẦU TỪ (không phân biệt hoa thường) — đúng luật server, nên
/// chỗ được tô là chỗ đã làm tin hiện ra. Tin dài thì cắt quanh chỗ khớp đầu.
List<TextSpan> highlightSpans(
  String text,
  String term,
  TextStyle mark, {
  int max = 160,
}) {
  final words = term.toLowerCase().split(_split).where((w) => w.isNotEmpty);
  final lower = text.toLowerCase();
  bool startsWord(int i) => i == 0 || !_wordChar.hasMatch(text[i - 1]);

  final hits = <(int, int)>[];
  for (final w in words) {
    var i = lower.indexOf(w);
    while (i >= 0) {
      if (startsWord(i)) hits.add((i, i + w.length));
      i = lower.indexOf(w, i + 1);
    }
  }
  hits.sort((a, b) => a.$1.compareTo(b.$1));

  var from = 0;
  var to = text.length;
  if (text.length > max) {
    if (hits.isNotEmpty) from = (hits.first.$1 - 30).clamp(0, text.length);
    to = (from + max).clamp(0, text.length);
  }

  final out = <TextSpan>[if (from > 0) const TextSpan(text: '…')];
  var at = from;
  for (final (s, e) in hits) {
    if (s < at || e > to) continue;
    if (s > at) out.add(TextSpan(text: text.substring(at, s)));
    out.add(TextSpan(text: text.substring(s, e), style: mark));
    at = e;
  }
  if (at < to) out.add(TextSpan(text: text.substring(at, to)));
  if (to < text.length) out.add(const TextSpan(text: '…'));
  return out;
}
