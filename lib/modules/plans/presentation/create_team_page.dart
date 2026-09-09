import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/tokens/tokens.dart';
import '../application/plans_providers.dart';
import '../data/plans_api.dart';

class CreateTeamPage extends ConsumerStatefulWidget {
  const CreateTeamPage({super.key});

  @override
  ConsumerState<CreateTeamPage> createState() => _CreateTeamPageState();
}

class _CreateTeamPageState extends ConsumerState<CreateTeamPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty && !_saving;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Team mới')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.lg,
          OmniSpacing.lg,
          OmniSpacing.lg,
          OmniSpacing.bottomSafe,
        ),
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Tên team',
              hintText: 'Tổ sản xuất, Nhóm kinh doanh…',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: OmniSpacing.lg),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Mô tả',
              hintText: 'Tổ phục chế đàn cơ và đàn điện',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: OmniSpacing.lg),
            Text(
              _error!,
              style: text.bodyMedium?.copyWith(
                color: OmniColors.dangerTextOf(context),
              ),
            ),
          ],
          const SizedBox(height: OmniSpacing.xxl),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Tạo team'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(plansApiProvider)
          .createTeam(name: _name.text.trim(), description: _description.text);

      ref.invalidate(teamsWithPlansProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }
}
