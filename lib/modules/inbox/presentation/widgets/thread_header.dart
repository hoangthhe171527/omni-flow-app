import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_platform.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/conversation.dart';
import '../../inbox_routes.dart';

/// Header gọn của hội thoại: ‹, avatar 30, tên + dòng nguồn, nút Thông tin.
///
/// Nền kính (`rgba(245,247,250,.82)` blur 20). Khi [searchMode] bật, một thanh
/// tìm kiếm 48px hiện dưới hàng tên.
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

  /// Đệm trên 4 + hàng kính 44 + đệm 8.
  static const rowHeight = 56.0;
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
    // Kiểu nút kính rời (viomni-apple-uiux.html "Hội thoại"): không dải nền;
    // quay lại và ⓘ là viên kính tròn, danh tính khách là một viên kính dạng
    // viên thuốc ở giữa. Nội dung dưới thanh nhoè dần (OmniScrollEdge).
    return SafeArea(
      bottom: false,
      child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Column(
              children: [
                SizedBox(height: 44, child: _buildRow(context)),
                const SizedBox(height: 8),
                if (searchMode)
                  SizedBox(
                    height: searchBarHeight - 8,
                    child: OmniGlass(
                      radius: 20,
                      child: _buildSearchBar(context),
                    ),
                  ),
                if (searchMode) const SizedBox(height: 8),
              ],
            ),
          ),
        );
  }

  Widget _buildRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = OmniColors.byBrightness(
      context,
      OmniColors.mutedForeground,
      scheme.onSurfaceVariant,
    );
    final c = conversation;

    return Row(
      children: [
        OmniTopBarAction(
          icon: isApple(context)
              ? Icons.arrow_back_ios_new_rounded
              : Icons.arrow_back_rounded,
          tooltip: 'Quay lại',
          onPressed: () {
            final nav = Navigator.of(context);
            if (nav.canPop()) {
              nav.maybePop();
            } else {
              GoRouter.maybeOf(context)?.go(InboxRoutes.listPath);
            }
          },
        ),
        const SizedBox(width: 8),
        if (c != null)
          Expanded(
            child: OmniGlass(
              radius: 22,
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onInfo();
                },
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      const SizedBox(width: 6),
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: OmniType.bodyStrong.copyWith(
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                                color: scheme.onSurface,
                              ),
                            ),
                            Text(
                              _sourceLine(c),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: OmniType.micro.copyWith(
                                height: 1.2,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: 8),
        OmniTopBarAction(
          icon: Icons.info_outline_rounded,
          tooltip: 'Thông tin khách',
          onPressed: onInfo,
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
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 22),
          ),
          IconButton(
            tooltip: 'Kết quả sau',
            onPressed: searchResultCount == 0
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onSearchNext();
                  },
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
          ),
          IconButton(
            tooltip: 'Đóng tìm kiếm',
            onPressed: () {
              HapticFeedback.selectionClick();
              onCloseSearch();
            },
            icon: const Icon(Icons.close_rounded, size: 21),
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
