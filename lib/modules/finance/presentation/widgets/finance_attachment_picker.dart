import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../design/tokens/tokens.dart';
import '../../data/finance_api.dart';
import '../../domain/finance_models.dart';
import 'finance_palette.dart';

/// Mở menu chọn ngày nhanh trong tháng kèm tuỳ chọn mở lịch đầy đủ (`showDatePicker`).
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
  final chosenDate = await showDatePicker(
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
                    color: p.primaryInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (expenseAmount != null && expenseAmount > 0)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                FinanceMonthUtils.formatNumber(expenseAmount),
                style: OmniType.micro.copyWith(
                  color: p.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Text(
            att.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniType.micro.copyWith(
              color: p.ink2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.selLine, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
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
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    key: ValueKey('finance-att-remove-${attachment.id}'),
                    onTap: onRemove,
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.68),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.close_rounded,
                        size: 11,
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

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      return Dialog(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: p.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      att.isPdf
                          ? Icons.picture_as_pdf_outlined
                          : Icons.image_outlined,
                      size: 18,
                      color: p.primaryInk,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          att.name.isNotEmpty ? att.name : 'Ảnh chứng từ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OmniType.bodyStrong.copyWith(
                            color: p.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (metaParts.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            metaParts.join(' · '),
                            style: OmniType.caption.copyWith(color: p.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    icon: Icon(Icons.close_rounded, color: p.muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
                SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(resolvedUrl);
                      if (uri != null) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 15),
                    label: const Text('Mở tệp'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.primary,
                      side: BorderSide(color: p.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
