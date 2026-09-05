import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/tokens/tokens.dart';
import '../../application/task_controller.dart';
import '../../domain/task.dart';

/// One stage, and the tap target for finishing it.
///
/// The person using this is standing at a workbench with dirty or gloved hands
/// and a noisy room. Three consequences, and none of them are cosmetic:
///
///  * The whole row is the target, 56dp tall — well past the 48dp platform
///    minimum. Nobody should have to aim at a checkbox.
///  * Rows are spaced further apart than the usual 8dp, because a mis-tap here
///    marks the wrong stage of a piano complete.
///  * Ticking fires haptic feedback. In a workshop you cannot hear a sound and
///    may not be looking at the screen as you tap.
class SubtaskRow extends StatelessWidget {
  const SubtaskRow({
    super.key,
    required this.subtask,
    required this.pending,
    required this.enabled,
    required this.onToggle,
    required this.onRetry,
    required this.onDiscard,
  });

  /// Comfortably above the 48dp Android minimum: this is a gloved thumb.
  static const double minHeight = 56;

  final Subtask subtask;
  final PendingTick? pending;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  bool get _failed => pending?.failed ?? false;

  bool get _inFlight => pending != null && !_failed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Semantics(
      checked: subtask.done,
      label: subtask.title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  // Haptic first so the confirmation is felt at the moment of
                  // the tap, not after the network decides anything.
                  HapticFeedback.selectionClick();
                  onToggle(!subtask.done);
                }
              : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OmniSpacing.lg,
                vertical: OmniSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Box(
                    done: subtask.done,
                    inFlight: _inFlight,
                    failed: _failed,
                  ),
                  const SizedBox(width: OmniSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subtask.title,
                          style: text.bodyLarge?.copyWith(
                            decoration: subtask.done
                                ? TextDecoration.lineThrough
                                : null,
                            color: subtask.done
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                          ),
                        ),
                        if (subtask.assigneeName != null) ...[
                          const SizedBox(height: OmniSpacing.xs),
                          // A chip rather than "(Hằng Ni)" inside the title, so
                          // the name is a filterable fact and the title stays
                          // the name of the work.
                          _AssigneeChip(name: subtask.assigneeName!),
                        ],
                        if (_failed) ...[
                          const SizedBox(height: OmniSpacing.sm),
                          _FailureNotice(
                            reason: pending!.error!,
                            onRetry: onRetry,
                            onDiscard: onDiscard,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.done,
    required this.inFlight,
    required this.failed,
  });

  final bool done;
  final bool inFlight;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (inFlight) {
      // The box already shows the new state; this only says it is still on its
      // way, so the worker does not tap twice.
      return const SizedBox(
        width: 24,
        height: 24,
        child: Padding(
          padding: EdgeInsets.all(3),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final colour = failed
        ? OmniColors.destructive
        : (done ? OmniColors.success : scheme.outline);

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: done && !failed ? OmniColors.success : Colors.transparent,
        border: Border.all(color: colour, width: 2),
        borderRadius: BorderRadius.circular(OmniRadius.xs),
      ),
      child: done
          ? Icon(
              Icons.check_rounded,
              size: OmniIconSize.md,
              color: failed ? OmniColors.destructive : Colors.white,
            )
          : null,
    );
  }
}

class _AssigneeChip extends StatelessWidget {
  const _AssigneeChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.sm,
        vertical: OmniSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(OmniRadius.xs),
      ),
      child: Text(
        name,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// A tick that did not save, and what to do about it.
///
/// Stated in words with two explicit choices. A stage silently un-ticking is
/// how a piano gets skipped, so this stays on screen until the worker decides.
class _FailureNotice extends StatelessWidget {
  const _FailureNotice({
    required this.reason,
    required this.onRetry,
    required this.onDiscard,
  });

  final String reason;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: OmniIconSize.xs,
              color: OmniColors.dangerText,
            ),
            const SizedBox(width: OmniSpacing.xs),
            Expanded(
              child: Text(
                'Chưa lưu được: $reason',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: OmniColors.dangerText),
              ),
            ),
          ],
        ),
        Row(
          children: [
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
            const SizedBox(width: OmniSpacing.sm),
            TextButton(onPressed: onDiscard, child: const Text('Bỏ')),
          ],
        ),
      ],
    );
  }
}
