import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/web_url.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../data/finance_api.dart';
import '../../domain/finance_models.dart';
import 'finance_palette.dart';

/// Mở menu chọn ngày nhanh trong tháng kèm tuỳ chọn mở lịch đầy đủ (`pickOmniDate`).
Future<String?> showFinanceDateSelector({
  required BuildContext context,
  required BuildContext? anchorContext,
  required String currentIsoDate,
  required String monthYm,
  String header = 'Ngày ghi nhận',
  DateTime? clock,
}) async {
  const calendarSentinel = '__open_calendar__';
  final quickDates = FinanceMonthUtils.quickDatesForMonth(monthYm, clock);
  final normalizedCurrent = FinanceMonthUtils.toIsoDate(
    currentIsoDate,
    monthYm,
  );
  final hasCurrentInQuick = quickDates.any(
    (d) => d.isoDate == normalizedCurrent,
  );

  final picked = await showFinancePopoverMenu<String>(
    context: context,
    anchorContext: anchorContext,
    header: header,
    width: 244,
    items: [
      if (!hasCurrentInQuick)
        FinancePopoverItem<String>(
          value: normalizedCurrent,
          label: FinanceMonthUtils.fullDayMonthYear(
            normalizedCurrent,
            fallbackMonth: monthYm,
          ),
          selected: true,
        ),
      for (final d in quickDates)
        FinancePopoverItem<String>(
          value: d.isoDate,
          label: d.label,
          selected: d.isoDate == normalizedCurrent,
        ),
      const FinancePopoverItem<String>(
        value: calendarSentinel,
        label: 'Chọn ngày khác…',
        icon: Icons.edit_calendar_outlined,
      ),
    ],
  );

  if (picked == null || !context.mounted) return null;
  if (picked != calendarSentinel) return picked;

  final initialDt = FinanceMonthUtils.parseIsoDate(
    normalizedCurrent,
    fallbackMonth: monthYm,
  );
  final chosenDate = await pickOmniDate(
    context: context,
    initialDate: initialDt,
    firstDate: DateTime(2000, 1, 1),
    lastDate: DateTime(2100, 12, 31),
    helpText: header,
  );
  if (chosenDate == null) return null;
  return FinanceMonthUtils.formatIsoDate(chosenDate);
}

/// Mở menu chọn chứng từ (máy ảnh, thư viện ảnh, PDF/tệp) và tải thực lên `POST /finance/attachments`.
Future<ExpenseAttachment?> pickAndUploadFinanceAttachment({
  required BuildContext context,
  required BuildContext? anchorContext,
  required FinanceApi api,
  required void Function(String message) onError,
}) async {
  final sourceKind = await showFinancePopoverMenu<String>(
    context: context,
    anchorContext: anchorContext,
    header: 'Đính kèm chứng từ đã chi',
    width: 248,
    items: const [
      FinancePopoverItem<String>(
        value: 'photo',
        label: 'Chụp ảnh phiếu chi',
        icon: Icons.camera_alt_outlined,
      ),
      FinancePopoverItem<String>(
        value: 'gallery',
        label: 'Chọn ảnh hoá đơn',
        icon: Icons.image_outlined,
      ),
      FinancePopoverItem<String>(
        value: 'pdf',
        label: 'Chọn tệp PDF / chứng từ',
        icon: Icons.picture_as_pdf_outlined,
      ),
    ],
  );
  if (sourceKind == null || !context.mounted) return null;

  String? filePath;
  String? fileName;

  try {
    if (sourceKind == 'photo' || sourceKind == 'gallery') {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: sourceKind == 'photo'
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2400,
        maxHeight: 2400,
      );
      if (xfile == null) return null;
      filePath = xfile.path;
      fileName = xfile.name;
    } else {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );
      if (res == null || res.files.isEmpty) return null;
      final first = res.files.first;
      if (first.path == null || first.path!.trim().isEmpty) {
        onError(
          'Không đọc được đường dẫn tệp đã chọn. Vui lòng chọn tệp khác.',
        );
        return null;
      }
      filePath = first.path!;
      fileName = first.name;
    }
  } on PlatformException {
    onError(
      'Không mở được trình chọn tệp/ảnh — vui lòng kiểm tra quyền truy cập trong Cài đặt.',
    );
    return null;
  }

  try {
    final uploaded = await api.uploadAttachment(
      filePath: filePath,
      filename: fileName,
    );
    return uploaded.copyWith(localPath: filePath);
  } on AppException catch (e) {
    onError(e.message);
    return null;
  } catch (_) {
    onError('Tải chứng từ lên máy chủ thất bại. Vui lòng thử lại.');
    return null;
  }
}

Uint8List? _tryDecodeDataImageUrl(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (!trimmed.startsWith('data:image/')) return null;
  final comma = trimmed.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(trimmed.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

/// Dựng Widget hiển thị hình ảnh chứng từ trực tiếp (ưu tiên `localPath` -> `data:image` -> `CachedNetworkImage`).
Widget buildFinanceAttachmentImageContent({
  required BuildContext context,
  required ExpenseAttachment att,
  required FinancePalette palette,
  BoxFit fit = BoxFit.cover,
  String? expenseTitle,
  int? expenseAmount,
  String? accountName,
  bool compact = false,
}) {
  final localPath = att.localPath;
  final decodeWidth =
      ((compact ? 120 : 720) * MediaQuery.devicePixelRatioOf(context))
          .round()
          .clamp(120, 1600);
  if (localPath != null && localPath.isNotEmpty) {
    final file = File(localPath);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: fit,
        cacheWidth: decodeWidth,
        errorBuilder: (_, _, _) => _buildReceiptVisualFallback(
          palette,
          att: att,
          expenseTitle: expenseTitle,
          expenseAmount: expenseAmount,
          accountName: accountName,
          compact: compact,
        ),
      );
    }
  }

  final memoryBytes = _tryDecodeDataImageUrl(att.url);
  if (memoryBytes != null) {
    return Image.memory(
      memoryBytes,
      fit: fit,
      cacheWidth: decodeWidth,
      errorBuilder: (_, _, _) => _buildReceiptVisualFallback(
        palette,
        att: att,
        expenseTitle: expenseTitle,
        expenseAmount: expenseAmount,
        accountName: accountName,
        compact: compact,
      ),
    );
  }

  final resolvedUrl = att.resolvedUrl;
  if (att.isImage &&
      resolvedUrl.isNotEmpty &&
      (resolvedUrl.startsWith('http://') ||
          resolvedUrl.startsWith('https://'))) {
    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      fit: fit,
      memCacheWidth: decodeWidth,
      memCacheHeight: decodeWidth,
      placeholder: (_, _) => _buildReceiptVisualFallback(
        palette,
        att: att,
        expenseTitle: expenseTitle,
        expenseAmount: expenseAmount,
        accountName: accountName,
        compact: compact,
      ),
      errorWidget: (_, _, _) => _buildReceiptVisualFallback(
        palette,
        att: att,
        expenseTitle: expenseTitle,
        expenseAmount: expenseAmount,
        accountName: accountName,
        compact: compact,
      ),
    );
  }

  return _buildReceiptVisualFallback(
    palette,
    att: att,
    expenseTitle: expenseTitle,
    expenseAmount: expenseAmount,
    accountName: accountName,
    compact: compact,
  );
}

Widget _buildReceiptVisualFallback(
  FinancePalette p, {
  required ExpenseAttachment att,
  String? expenseTitle,
  int? expenseAmount,
  String? accountName,
  required bool compact,
}) {
  if (compact) {
    return LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final showAmount =
            expenseAmount != null &&
            expenseAmount > 0 &&
            box.maxHeight >= 50 * scale;
        return Container(
          color: p.card,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    att.isPdf
                        ? Icons.picture_as_pdf_rounded
                        : Icons.receipt_long_rounded,
                    size: 11,
                    color: p.primary,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      att.isPdf ? 'PDF' : 'UNC',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.micro.copyWith(
                        height: 1.15,
                        color: p.primaryInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (showAmount)
                Text(
                  FinanceMonthUtils.formatNumber(expenseAmount),
                  maxLines: 1,
                  softWrap: false,
                  style: OmniType.micro.copyWith(
                    height: 1.15,
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                    fontFeatures: OmniType.tabular,
                  ),
                ),
              Text(
                att.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OmniType.micro.copyWith(
                  height: 1.15,
                  color: p.ink2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: p.bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: p.line, width: 0.5),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          att.isPdf ? Icons.description_outlined : Icons.image_outlined,
          size: 40,
          color: p.primary,
        ),
        const SizedBox(height: 8),
        Text(
          expenseTitle != null && expenseTitle.trim().isNotEmpty
              ? 'Chứng từ khoản chi: $expenseTitle'
              : att.name,
          textAlign: TextAlign.center,
          style: OmniType.bodySm.copyWith(
            color: p.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        if ((expenseAmount != null && expenseAmount != 0) ||
            (accountName != null && accountName.isNotEmpty)) ...[
          const SizedBox(height: 4),
          Text(
            [
              if (expenseAmount != null && expenseAmount != 0)
                FinanceMonthUtils.formatVndSpace(expenseAmount),
              if (accountName != null && accountName.isNotEmpty) accountName,
            ].join(' · '),
            style: OmniType.caption.copyWith(color: p.muted),
          ),
        ],
      ],
    ),
  );
}

/// Thumbnail chứng từ hiển thị ảnh trực tiếp ngay trong dòng (không để dạng link chữ).
class FinanceAttachmentInlineThumb extends StatelessWidget {
  const FinanceAttachmentInlineThumb({
    super.key,
    required this.attachment,
    required this.onTap,
    this.onRemove,
    this.expenseTitle,
    this.expenseAmount,
    this.accountName,
    this.width = 68,
    this.height = 46,
  });

  final ExpenseAttachment attachment;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final String? expenseTitle;
  final int? expenseAmount;
  final String? accountName;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = FinancePalette.of(context);
    return GestureDetector(
      key: ValueKey('finance-att-thumb-${attachment.id}'),
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.line, width: 1),
          boxShadow: [
            BoxShadow(
              color: OmniColors.ink.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              buildFinanceAttachmentImageContent(
                context: context,
                att: attachment,
                palette: p,
                fit: BoxFit.cover,
                expenseTitle: expenseTitle,
                expenseAmount: expenseAmount,
                accountName: accountName,
                compact: true,
              ),
              if (onRemove != null)
                Positioned(
                  top: 3,
                  right: 3,
                  child: GestureDetector(
                    key: ValueKey('finance-att-remove-${attachment.id}'),
                    onTap: onRemove,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: OmniColors.ink.withValues(alpha: 0.72),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.close_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hiển thị hộp thoại xem ảnh chứng từ lớn (hỗ trợ phóng to `InteractiveViewer`).
Future<void> showFinanceAttachmentPreviewDialog({
  required BuildContext context,
  required ExpenseAttachment att,
  String? expenseTitle,
  int? expenseAmount,
  String? accountName,
}) async {
  final p = FinancePalette.of(context);
  final resolvedUrl = att.resolvedUrl;
  final metaParts = <String>[
    if (att.sizeLabel.isNotEmpty) att.sizeLabel,
    if (att.uploadedAt.isNotEmpty) 'Tải lên ${att.uploadedAt}',
  ];

  await showOmniGlassDialog<void>(
    context: context,
    builder: (dialogCtx) {
      return OmniGlassAlert(
        title: att.name.isNotEmpty ? att.name : 'Ảnh chứng từ',
        message: metaParts.isEmpty ? null : metaParts.join(' · '),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: buildFinanceAttachmentImageContent(
                    context: dialogCtx,
                    att: att,
                    palette: p,
                    fit: BoxFit.contain,
                    expenseTitle: expenseTitle,
                    expenseAmount: expenseAmount,
                    accountName: accountName,
                    compact: false,
                  ),
                ),
              ),
            ),
            if (resolvedUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  // Chỉ http/https — không trao `file:`/`intent:` cho máy.
                  final uri = webUriOrNull(resolvedUrl);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Mở tệp'),
              ),
            ],
          ],
        ),
        actions: [
          OmniAlertAction(
            label: 'Đóng',
            strong: true,
            onPressed: () => Navigator.of(dialogCtx).pop(),
          ),
        ],
      );
    },
  );
}
