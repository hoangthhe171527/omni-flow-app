import 'dart:async';

import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Debounced search field. Debouncing lives here rather than in each screen so
/// no list ever fires a request per keystroke.
class OmniSearchField extends StatefulWidget {
  const OmniSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Tìm kiếm...',
    this.initialValue,
    this.debounce = const Duration(milliseconds: 350),
    this.trailing,
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final String? initialValue;
  final Duration debounce;
  final Widget? trailing;

  @override
  State<OmniSearchField> createState() => _OmniSearchFieldState();
}

class _OmniSearchFieldState extends State<OmniSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onChanged(value.trim()));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      style: OmniType.body.copyWith(color: scheme.onSurface),
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: Icon(
          Icons.search_rounded,
          color: scheme.onSurfaceVariant,
          size: 20,
        ),
        suffixIcon: _controller.text.isEmpty
            ? widget.trailing
            : IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: () {
                  _controller.clear();
                  _onChanged('');
                },
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        fillColor: scheme.surface,
      ),
    );
  }
}

/// Labelled form field wrapper — one place for the label, hint, error and
/// required marker so no two forms disagree.
class OmniField extends StatelessWidget {
  const OmniField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.error,
    this.hint,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? error;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: OmniType.caption.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (required)
              Text(' *', style: OmniType.caption.copyWith(color: scheme.error)),
          ],
        ),
        const SizedBox(height: OmniSpacing.sm),
        child,
        if (error != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 13, color: scheme.error),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  error!,
                  style: OmniType.micro.copyWith(color: scheme.error),
                ),
              ),
            ],
          ),
        ] else if (hint != null) ...[
          const SizedBox(height: 5),
          Text(
            hint!,
            style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Sticky bottom action bar for forms and detail screens.
class OmniActionBar extends StatelessWidget {
  const OmniActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        OmniSpacing.md,
        OmniSpacing.lg,
        OmniSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: OmniSpacing.md),
            Expanded(
              flex: i == children.length - 1 ? 2 : 1,
              child: children[i],
            ),
          ],
        ],
      ),
    );
  }
}

/// Consistent modal sheet — used for assign, labels, filters, stage change.
Future<T?> showOmniSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  bool expand = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: expand
          ? FractionallySizedBox(heightFactor: 0.9, child: builder(context))
          : builder(context),
    ),
  );
}
