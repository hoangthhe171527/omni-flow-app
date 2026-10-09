import 'package:flutter/material.dart';

/// Kết quả trang Thông tin trả về cho hội thoại.
enum ThreadInfoResult { search }

/// Trang Thông tin khách — khung tạm, nội dung dựng ở Task 9.
class ThreadInfoPage extends StatelessWidget {
  const ThreadInfoPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text('Thông tin')));
}
