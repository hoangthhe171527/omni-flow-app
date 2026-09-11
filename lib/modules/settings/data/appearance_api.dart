import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Ghi lựa chọn nền lên tài khoản.
///
/// `null` vẫn phải GỬI (`{"background": null}`): server đòi khoá `present`,
/// bỏ khoá đi là 422 — và "về mặc định" là một lựa chọn thật.
class AppearanceApi {
  AppearanceApi(this._client);

  final ApiClient _client;

  Future<void> setBackground(String? name) =>
      _client.put('/auth/appearance', body: {'background': name});
}

final appearanceApiProvider = Provider<AppearanceApi>(
  (ref) => AppearanceApi(ref.watch(apiClientProvider)),
);
