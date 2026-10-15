import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/plans_providers.dart';
import '../data/plan_cover_upload.dart';
import '../data/plans_api.dart';
import '../domain/plan.dart';
import 'widgets/cover_picker.dart';

/// Nút "Lưu" trên thanh trên của các màn sửa kế hoạch (cùng kiểu
/// `EditSectionsPage`).
class PlanSaveAction extends StatelessWidget {
  const PlanSaveAction({
    super.key,
    required this.saving,
    required this.onPressed,
  });

  final bool saving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: FilledButton(
      onPressed: saving ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: const RoundedRectangleBorder(borderRadius: OmniRadius.smAll),
        textStyle: OmniType.body.copyWith(fontWeight: FontWeight.w600),
      ),
      child: saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Lưu'),
    ),
  );
}

/// Gửi một [PlanPatch], làm mới kế hoạch và tab Việc, rồi đóng màn. Lỗi thì
/// hiện câu của server và ở lại.
Future<bool> savePlanPatch(
  BuildContext context,
  String planId,
  PlanPatch patch,
) async {
  final container = ProviderScope.containerOf(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    await container.read(plansApiProvider).updatePlan(planId, patch);
    container.invalidate(planProvider(planId));
    container.invalidate(teamsWithPlansProvider);
    if (navigator.canPop()) navigator.pop(true);
    return true;
  } on AppException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    return false;
  }
}

/// Sửa tên, mô tả, nền của kế hoạch. Chỉ gửi khoá đã đổi.
class EditPlanPage extends ConsumerStatefulWidget {
  const EditPlanPage({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<EditPlanPage> createState() => _EditPlanPageState();
}

class _EditPlanPageState extends ConsumerState<EditPlanPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  Plan? _plan;
  String? _coverPath;
  bool _removeCover = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  PlanPatch? _patch() {
    final plan = _plan;
    if (plan == null) return null;
    final name = _name.text.trim();
    if (name.isEmpty) return null;
    final description = _description.text.trim();
    final patch = PlanPatch(
      name: name == plan.name ? null : name,
      description: description == (plan.description ?? '').trim()
          ? null
          : description,
    );

    return patch.isEmpty ? null : patch;
  }

  bool get _coverChanged {
    final plan = _plan;
    if (plan == null) return false;
    return _coverPath != null ||
        (_removeCover && resolveProjectCoverUrl(plan.cover) != null);
  }

  Future<void> _save() async {
    final patch = _patch();
    if (patch == null && !_coverChanged) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      if (patch != null) {
        _plan = await ref
            .read(plansApiProvider)
            .updatePlan(widget.planId, patch);
      }
      if (_coverPath case final path?) {
        await ref.read(planCoverApiProvider).upload(widget.planId, path);
      } else if (_removeCover) {
        await ref.read(planCoverApiProvider).remove(widget.planId);
      }
      ref.invalidate(planProvider(widget.planId));
      ref.invalidate(teamsWithPlansProvider);
      if (!mounted) return;
      if (navigator.canPop()) {
        navigator.pop(true);
      } else {
        setState(() => _saving = false);
      }
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (!mounted) return;
      const message = 'Chưa lưu được ảnh nền. Vui lòng thử lại.';
      setState(() {
        _saving = false;
        _error = message;
      });
      messenger.showSnackBar(const SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(planProvider(widget.planId));
    final loaded = async.valueOrNull;
    if (loaded != null && _plan == null) {
      _plan = loaded;
      _name.text = loaded.name;
      _description.text = loaded.description ?? '';
    }
    final scheme = Theme.of(context).colorScheme;
    final patch = _patch();
    final canSave = !_saving && (patch != null || _coverChanged);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: const Text('Sửa kế hoạch'),
        actions: [
          PlanSaveAction(saving: _saving, onPressed: canSave ? _save : null),
        ],
      ),
      body: _plan == null
          ? OmniAsyncView(
              value: async,
              onRetry: () => ref.invalidate(planProvider(widget.planId)),
              data: (_) => const SizedBox.shrink(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, OmniSpacing.lg, 20, 24),
              children: [
                OmniField(
                  label: 'Tên kế hoạch',
                  child: TextField(
                    controller: _name,
                    maxLength: 255,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: OmniSpacing.lg),
                OmniField(
                  label: 'Mô tả',
                  child: TextField(
                    controller: _description,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Kế hoạch này dùng để làm gì',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: OmniSpacing.lg),
                Text(
                  'Ảnh nền',
                  style: OmniType.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: OmniSpacing.sm),
                CoverPicker(
                  localPath: _coverPath,
                  remoteUrl: _removeCover
                      ? null
                      : resolveProjectCoverUrl(_plan?.cover),
                  title: _name.text.trim(),
                  busy: _saving && _coverChanged,
                  onPicked: (path) => setState(() {
                    _coverPath = path;
                    _removeCover = false;
                    _error = null;
                  }),
                  onRemove: _coverPath != null
                      ? () => setState(() => _coverPath = null)
                      : resolveProjectCoverUrl(_plan?.cover) != null &&
                            !_removeCover
                      ? () => setState(() => _removeCover = true)
                      : null,
                  onError: (message) => setState(() => _error = message),
                ),
                if (_error != null) ...[
                  const SizedBox(height: OmniSpacing.sm),
                  Text(
                    _error!,
                    style: OmniType.caption.copyWith(
                      color: OmniColors.dangerTextOf(context),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
