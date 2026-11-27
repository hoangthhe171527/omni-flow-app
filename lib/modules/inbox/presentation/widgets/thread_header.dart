import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_platform.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/conversation.dart';
import '../../inbox_routes.dart';

/// Đầu màn hội thoại kiểu iMessage (duyệt 26/11/2026): phẳng, nền đặc, vạch
/// mảnh dưới. Trái ‹ (màu chính), giữa avatar 32 + tên 14/600 + dòng nguồn
/// 11.5 xám (chạm mở Thông tin khách), phải ⓘ. Không còn viên kính bọc tên.
///
/// Khi [searchMode] bật, một thanh tìm kiếm 48px hiện dưới hàng tên.
class ThreadHeader extends StatelessWidget implements PreferredSizeWidget {
  const ThreadHeader({
    super.key,
    required this.conversation,
    required this.onInfo,
    required this.searchMode,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchResultCount,
    required this.searchResultIndex,
    required this.onSearchChanged,
    required this.onSearchPrevious,
    required this.onSearchNext,
    required this.onCloseSearch,
  });

  /// Đệm trên 4 + khối giữa 72 (avatar 32 + tên + nguồn) + đệm dưới 4.
  static const rowHeight = 80.0;
  static const searchBarHeight = 48.0;

  final Conversation? conversation;
  final VoidCallback onInfo;
  final bool searchMode;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final int searchResultCount;
  final int searchResultIndex;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchPrevious;
  final VoidCallback onSearchNext;
  final VoidCallback onCloseSearch;

  @override
  Size get preferredSize =>
      Size.fromHeight(rowHeight + (searchMode ? searchBarHeight : 0));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Chiều cao đầu màn cố định (PreferredSize): chữ phóng to quá 1.15 sẽ
    // tràn khối giữa, nên kẹp ở đây — tên đầy đủ vẫn ở trang Thông tin.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      // Material đặc (không kính) để gợn chạm của khối tên vẽ được lên nền.
      child: Material(
        color: scheme.surface,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: scheme.outlineVariant, width: 0.5),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: SizedBox(
                    height: rowHeight - 8,
                    child: _buildRow(context),
                  ),
                ),
                if (searchMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: SizedBox(
                      height: searchBarHeight - 8,
                      // Ô tìm nền xám đặc như ô tìm iOS — kính chỉ ở thanh tab.
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _buildSearchBar(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = conversation;

    return Row(
      children: [
        SizedBox(
          width: 44,
          child: OmniTopBarAction(
            icon: isApple(context)
                ? LucideIcons.chevronLeft
                : LucideIcons.arrowLeft,
            tooltip: 'Quay lại',
            // ‹ màu chính như iOS (duyệt 26/11/2026).
            color: scheme.primary,
            onPressed: () {
              final nav = Navigator.of(context);
              if (nav.canPop()) {
                nav.maybePop();
              } else {
                GoRouter.maybeOf(context)?.go(InboxRoutes.listPath);
              }
            },
          ),
        ),
        Expanded(
          child: c == null
              ? const SizedBox.shrink()
              : Semantics(
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onInfo();
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        c.isGroup
                            ? OmniGroupAvatar(
                                names: c.groupMembers
                                    .map((m) => m.name ?? '?')
                                    .toList(),
                                size: 32,
                              )
                            : OmniAvatar(
                                name: c.title,
                                imageUrl: c.customerAvatar,
                                size: 32,
                              ),
                        const SizedBox(height: 2),
                        Text(
                          c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          // Tên 14/600 (bodySm 14 + w600).
                          style: OmniType.bodySm.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _sourceLine(c),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          // Dòng nguồn 11.5 xám (OmniChatType.meta).
                          style: OmniChatType.meta.copyWith(
                            height: 1.2,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        SizedBox(
          width: 44,
          child: OmniTopBarAction(
            icon: LucideIcons.info,
            tooltip: 'Thông tin khách',
            color: scheme.primary,
            onPressed: onInfo,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              autofocus: true,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              style: OmniType.search.copyWith(
                color: scheme.onSurface,
                fontStyle: FontStyle.normal,
              ),
              decoration: InputDecoration(
                hintText: 'Tìm trong hội thoại',
                hintStyle: OmniType.searchHint.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                suffixText: searchResultCount == 0
                    ? null
                    : '${searchResultIndex + 1}/$searchResultCount',
              ),
            ),
          ),
          IconButton(
            tooltip: 'Kết quả trước',
            onPressed: searchResultCount == 0
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onSearchPrevious();
                  },
            icon: const Icon(LucideIcons.chevronUp, size: 22),
          ),
          IconButton(
            tooltip: 'Kết quả sau',
            onPressed: searchResultCount == 0
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onSearchNext();
                  },
            icon: const Icon(LucideIcons.chevronDown, size: 22),
          ),
          IconButton(
            tooltip: 'Đóng tìm kiếm',
            onPressed: () {
              HapticFeedback.selectionClick();
              onCloseSearch();
            },
            icon: const Icon(LucideIcons.x, size: 21),
          ),
        ],
      ),
    );
  }

  /// "OA Trung Nguyên": loại nguồn rồi tên tài khoản.
  static String _sourceLine(Conversation c) {
    final account = c.sourceAccount;
    final kind = c.channel.sourceKind;
    return account == null ? kind : '$kind $account';
  }
}
