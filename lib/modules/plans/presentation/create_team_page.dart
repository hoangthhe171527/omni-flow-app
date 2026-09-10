import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/tokens/tokens.dart';
import '../application/plans_providers.dart';
import '../data/plans_api.dart';
import 'create_plan_page.dart';
import 'widgets/member_picker_sheet.dart';

class CreateTeamPage extends ConsumerStatefulWidget {
  const CreateTeamPage({super.key});

  @override
  ConsumerState<CreateTeamPage> createState() => _CreateTeamPageState();
}

class _CreateTeamPageState extends ConsumerState<CreateTeamPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  Set<String> _memberIds = {};
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
          const SizedBox(height: OmniSpacing.lg),
          // Chọn người NGAY TRONG form, không phải một màn thứ ba: ba màn nối
          // tiếp cho một việc hai trường là bắt người dùng bấm "Tiếp" hai lần
          // để làm cái họ đã nhìn thấy hết ngay từ đầu.
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Thành viên'),
            subtitle: Text(
              _memberIds.isEmpty
                  // Nói rõ bỏ qua là HỢP LỆ. Một ô trống không chú thích đọc
                  // như một chỗ mình đang bỏ sót.
                  ? 'Chưa chọn ai — thêm sau cũng được'
                  : '${_memberIds.length} người',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final picked = await showMemberPicker(
                context,
                selected: _memberIds,
              );
              if (picked != null) setState(() => _memberIds = picked);
            },
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
      final team = await ref
          .read(plansApiProvider)
          .createTeam(
            name: _name.text.trim(),
            description: _description.text,
            memberIds: _memberIds,
          );

      ref.invalidate(teamsWithPlansProvider);
      if (!mounted) return;

      // Đi THẲNG sang tạo dự án. Team không có dự án thì không có bảng việc,
      // không có nhóm việc, không có gì để giao — nó chỉ là một cái tên, và
      // người vừa tạo phải tự đoán ra hai bước tiếp theo.
      //
      // `pushReplacement`, KHÔNG `push`: bấm Back từ màn dự án phải về danh
      // sách team, không quay lại một form tạo team đã dùng xong. Quay lại đó
      // rồi bấm "Tạo team" lần nữa là tạo một team trùng tên mà người dùng
      // không định tạo.
      //
      // Thoát ra được từ màn kia: team chưa có dự án vẫn là trạng thái hợp lệ.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CreatePlanPage(teamId: team.id),
        ),
      );
    } on AppException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }
}
