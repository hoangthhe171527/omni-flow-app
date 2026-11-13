import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../core/utils/formatters.dart';
import '../../../../../design/components/components.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../domain/task.dart';
import '../../../domain/task_reminder.dart';
import 'comment_bar.dart';
import 'task_attachments.dart';

/// Ghi chú tối đa (`TaskIssueController` `max:2000`) và số ảnh (`max:10`).
const kIssueMaxNote = 2000;
const kIssueMaxPhotos = 10;

typedef IssueDraft = ({String note, List<CommentUpload> photos});

/// Tấm "Báo vấn đề" (bản mẫu 7LZPEX "App · Báo vấn đề"): ghi chú + ảnh + Gửi.
/// [pick] thay bộ chọn ảnh thật trong test.
Future<IssueDraft?> showReportIssueSheet(
  BuildContext context, {
  CommentFilePicker pick = pickCommentFiles,
}) => showOmniSheet<IssueDraft>(
  context: context,
  builder: (_) => _ReportIssueSheet(pick: pick),
);

class _ReportIssueSheet extends StatefulWidget {
  const _ReportIssueSheet({required this.pick});
  final CommentFilePicker pick;

  @override
  State<_ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<_ReportIssueSheet> {
  final _note = TextEditingController();
  final _photos = <CommentUpload>[];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final remaining = kIssueMaxPhotos - _photos.length;
    if (remaining <= 0) return;
    final source = await showOmniSheet<CommentFileSource>(
      context: context,
      builder: (sheet) => OmniSheetBody(
        header: OmniSheetHeader(
          title: 'Đính kèm ảnh',
          trailing: OmniGlassCircle(
            child: IconButton(
              tooltip: 'Đóng',
              onPressed: () => Navigator.of(sheet).maybePop(),
              icon: const Icon(Icons.close_rounded, size: OmniIconSize.lg),
            ),
          ),
        ),
        children: [
          OmniGroupSection(
            children: [
              OmniGroupRow(
                title: 'Chụp ảnh',
                icon: Icons.photo_camera_outlined,
                chevron: false,
                onTap: () => Navigator.of(sheet).pop(CommentFileSource.camera),
              ),
              OmniGroupRow(
                title: 'Chọn từ thư viện',
                icon: Icons.photo_library_outlined,
                chevron: false,
                onTap: () => Navigator.of(sheet).pop(CommentFileSource.gallery),
              ),
            ],
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;
    try {
      final picked = await widget.pick(source, remaining);
      if (!mounted) return;
      setState(() => _photos.addAll(picked.take(remaining)));
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = _note.text.trim();
    final scheme = Theme.of(context).colorScheme;

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: 'Báo vấn đề',
        trailing: OmniGlassCircle(
          child: IconButton(
            tooltip: 'Đóng',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded, size: OmniIconSize.lg),
          ),
        ),
      ),
      footer: FilledButton(
        key: const Key('issue-send'),
        onPressed: note.isEmpty
            ? null
            : () => Navigator.of(
                context,
              ).pop((note: note, photos: List.of(_photos))),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: const Text('Gửi'),
      ),
      children: [
        OmniGroupSection(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: TextField(
                key: const Key('issue-note'),
                controller: _note,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                maxLength: kIssueMaxNote,
                textCapitalization: TextCapitalization.sentences,
                style: OmniType.body.copyWith(color: scheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Thấy gì, cần ai xem',
                  hintStyle: OmniType.body.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  counterText: '',
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _photos.length; i++)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.square(
                      dimension: 64,
                      child: kIsWeb
                          ? ColoredBox(color: scheme.surfaceContainerHighest)
                          : Image.file(
                              File(_photos[i].path),
                              fit: BoxFit.cover,
                              cacheWidth: 192,
                            ),
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Semantics(
                      button: true,
                      label: 'Bỏ ảnh',
                      child: GestureDetector(
                        onTap: () => setState(() => _photos.removeAt(i)),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: OmniColors.ink.withValues(alpha: 0.74),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            if (_photos.length < kIssueMaxPhotos)
              Semantics(
                button: true,
                label: 'Thêm ảnh',
                child: InkWell(
                  key: const Key('issue-add-photo'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: _add,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Khối cờ vấn đề trong màn việc: người báo · giờ, lời báo đỏ, ảnh.
class IssueCard extends StatelessWidget {
  const IssueCard({super.key, required this.issue});
  final TaskIssue issue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final red = OmniColors.dangerTextOf(context);
    final who = [
      ?issue.byName,
      if (issue.at case final at?)
        '${Formatters.dayMonth(at)} ${Formatters.time(at)}',
    ].join(' · ');

    return Container(
      key: const Key('task-issue-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.report_outlined, size: 15, color: red),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        who.isEmpty ? 'Vấn đề' : who,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.micro.copyWith(
                          fontWeight: FontWeight.w600,
                          color: red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            issue.note,
            style: OmniType.body.copyWith(color: scheme.onSurface),
          ),
          if (issue.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < issue.photoUrls.length; i++)
                  AttachmentThumb(
                    attachment: TaskAttachment(
                      id: 'issue-$i',
                      url: issue.photoUrls[i],
                      name: 'Ảnh vấn đề ${i + 1}',
                      type: 'image',
                    ),
                    size: 56,
                    radius: 12,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
