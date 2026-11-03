import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/app_exception.dart';
import '../../data/finance_api.dart';
import '../../domain/finance_models.dart';
import 'finance_palette.dart';

/// Mở menu chọn ngày nhanh trong tháng kèm tuỳ chọn mở lịch đầy đủ (`showDatePicker`).
Future<String?> showFinanceDateSelector({
  required BuildContext context,
  required BuildContext? anchorContext,
  required String currentIsoDate,
  required String monthYm,
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
    header: 'Ngày ghi nhận',
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
    helpText: 'Chọn ngày ghi nhận',
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
    return await api.uploadAttachment(filePath: filePath, filename: fileName);
  } on AppException catch (e) {
    onError(e.message);
    return null;
  } catch (_) {
    onError('Tải chứng từ lên máy chủ thất bại. Vui lòng thử lại.');
    return null;
  }
}
