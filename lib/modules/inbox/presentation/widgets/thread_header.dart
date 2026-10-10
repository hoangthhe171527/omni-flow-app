import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/conversation.dart';

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

  static const rowHeight = 52.0;
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
    final glass = OmniColors.byBrightness(
      context,
      OmniColors.background.withValues(alpha: 0.82),
      OmniColors.darkBackground.withValues(alpha: 0.82),
    );

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: glass,
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(height: rowHeight, child: _buildRow(context)),
                if (searchMode)
                  SizedBox(
                    height: searchBarHeight,
                    child: _buildSearchBar(context),
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
    final canPop = Navigator.of(context).canPop();
    final muted = OmniColors.byBrightness(
      context,
      OmniColors.mutedForeground,
      scheme.onSurfaceVariant,
    );
    final c = conversation;

    return Row(
      children: [
        if (canPop)
          IconButton(
            tooltip: 'Quay lại',
            onPressed: () => Navigator.of(context).maybePop(),
            style: IconButton.styleFrom(
              minimumSize: const Size(36, 36),
              maximumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              foregroundColor: scheme.onSurface,
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
          )
        else
          const SizedBox(width: 12),
        if (c != null)
          Expanded(
            child: InkWell(
              onTap: onInfo,
              child: SizedBox(
                height: rowHeight,
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    c.isGroup
                        ? OmniGroupAvatar(
                            names: c.groupMembers
                                .map((m) => m.name ?? '?')
                                .toList(),
                            size: 30,
                          )
                        : OmniAvatar(
                            name: c.title,
                            imageUrl: c.customerAvatar,
                            size: 30,
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
                  ],
                ),
              ),
            ),
          )
        else
          const Spacer(),
        IconButton(
          tooltip: 'Thông tin khách',
          onPressed: onInfo,
          style: IconButton.styleFrom(
            minimumSize: const Size(40, 40),
            maximumSize: const Size(40, 40),
            padding: EdgeInsets.zero,
            foregroundColor: scheme.primary,
          ),
          icon: const Icon(Icons.info_outline_rounded, size: 22),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
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
              decoration: InputDecoration(
                hintText: 'Tìm trong hội thoại',
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
            onPressed: searchResultCount == 0 ? null : onSearchPrevious,
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 22),
          ),
          IconButton(
            tooltip: 'Kết quả sau',
            onPressed: searchResultCount == 0 ? null : onSearchNext,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
          ),
          IconButton(
            tooltip: 'Đóng tìm kiếm',
            onPressed: onCloseSearch,
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
