import 'package:flutter/material.dart';

import '../../../../design/tokens/tokens.dart';

enum ComposeMode { reply, note }

/// Reply box with an explicit reply / internal-note switch.
///
/// The mode is a visible, sticky toggle rather than a hidden gesture: sending an
/// internal note to a customer by accident is the one mistake in this screen
/// that cannot be undone.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.onSend,
    required this.onAttach,
    this.suggestions = const [],
    this.canNote = true,
    this.enabled = true,
  });

  final Future<void> Function(String text, ComposeMode mode) onSend;
  final VoidCallback onAttach;
  final List<String> suggestions;
  final bool canNote;
  final bool enabled;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  ComposeMode _mode = ComposeMode.reply;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();
    await widget.onSend(text, _mode);
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isNote = _mode == ComposeMode.note;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.suggestions.isNotEmpty && !isNote)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: OmniSpacing.md,
                    vertical: OmniSpacing.xs,
                  ),
                  itemCount: widget.suggestions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.sm),
                  itemBuilder: (context, index) {
                    final suggestion = widget.suggestions[index];
                    return ActionChip(
                      label: Text(suggestion, style: OmniType.micro),
                      onPressed: () {
                        _controller.text = suggestion;
                        _focus.requestFocus();
                      },
                    );
                  },
                ),
              ),
            if (widget.canNote)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  OmniSpacing.md,
                  OmniSpacing.sm,
                  OmniSpacing.md,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeButton(
                        label: 'Trả lời khách',
                        icon: Icons.chat_bubble_outline_rounded,
                        selected: !isNote,
                        onTap: () => setState(() => _mode = ComposeMode.reply),
                      ),
                    ),
                    const SizedBox(width: OmniSpacing.sm),
                    Expanded(
                      child: _ModeButton(
                        label: 'Ghi chú nội bộ',
                        icon: Icons.sticky_note_2_outlined,
                        selected: isNote,
                        color: OmniColors.warning,
                        onTap: () => setState(() => _mode = ComposeMode.note),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(OmniSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: isNote || !widget.enabled ? null : widget.onAttach,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    color: scheme.onSurfaceVariant,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: isNote
                            ? 'Ghi chú cho đồng nghiệp...'
                            : 'Nhập nội dung...',
                        isDense: true,
                        fillColor: isNote
                            ? OmniColors.warning.withValues(alpha: 0.07)
                            : scheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: OmniSpacing.lg,
                          vertical: OmniSpacing.md,
                        ),
                        border: const OutlineInputBorder(
                          borderRadius: OmniRadius.pillAll,
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: OmniRadius.pillAll,
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: OmniRadius.pillAll,
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: OmniSpacing.sm),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: FilledButton(
                      onPressed: widget.enabled ? _send : null,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        backgroundColor:
                            isNote ? OmniColors.warning : scheme.primary,
                        shape: const CircleBorder(),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;

    return Material(
      color: selected ? tint.withValues(alpha: 0.1) : Colors.transparent,
      borderRadius: OmniRadius.smAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: OmniRadius.smAll,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: OmniRadius.smAll,
            border: Border.all(color: selected ? tint : scheme.outline),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? tint : scheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                label,
                style: OmniType.micro.copyWith(
                  color: selected ? tint : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
