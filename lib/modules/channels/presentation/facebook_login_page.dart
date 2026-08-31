import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens/tokens.dart';
import '../data/channels_api.dart';

class FacebookLoginPage extends ConsumerStatefulWidget {
  const FacebookLoginPage({
    super.key,
    required this.connectionId,
    this.freshSession = false,
  });

  final String connectionId;
  final bool freshSession;

  @override
  ConsumerState<FacebookLoginPage> createState() => _FacebookLoginPageState();
}

class _FacebookLoginPageState extends ConsumerState<FacebookLoginPage> {
  static final _loginUrl = WebUri('https://www.facebook.com/login');
  static final _facebookUrl = WebUri('https://www.facebook.com/');

  final _cookies = CookieManager.instance();
  Timer? _cookiePoll;
  bool _preparing = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    if (widget.freshSession) {
      await _cookies.deleteAllCookies();
    }
    if (!mounted) return;
    setState(() => _preparing = false);
    _cookiePoll = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_captureWhenLoggedIn()),
    );
  }

  @override
  void dispose() {
    _cookiePoll?.cancel();
    super.dispose();
  }

  Future<void> _captureWhenLoggedIn() async {
    if (_submitting) return;
    final rows = await _cookies.getCookies(url: _facebookUrl);
    final names = {for (final cookie in rows) cookie.name};
    if (!names.contains('c_user') || !names.contains('xs')) return;

    _submitting = true;
    _cookiePoll?.cancel();
    if (mounted) setState(() => _error = null);

    final now = DateTime.now().toUtc().toIso8601String();
    final appState = rows
        .where((cookie) => cookie.name.isNotEmpty && cookie.value.isNotEmpty)
        .map(
          (cookie) => <String, dynamic>{
            'key': cookie.name,
            'name': cookie.name,
            'value': cookie.value,
            'domain': cookie.domain ?? '.facebook.com',
            'path': cookie.path ?? '/',
            'hostOnly': !(cookie.domain ?? '').startsWith('.'),
            'creation': now,
            'lastAccessed': now,
          },
        )
        .toList(growable: false);

    try {
      await ref
          .read(channelsApiProvider)
          .submitFacebookSession(widget.connectionId, appState);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      _submitting = false;
      if (!mounted) return;
      setState(() => _error = '$error');
      _cookiePoll = Timer.periodic(
        const Duration(seconds: 3),
        (_) => unawaited(_captureWhenLoggedIn()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng nhập Facebook'),
        actions: [
          if (_submitting)
            const Padding(
              padding: EdgeInsets.only(right: OmniSpacing.lg),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_error != null)
              MaterialBanner(
                content: Text('Chưa chuyển được phiên đăng nhập: $_error'),
                actions: [
                  TextButton(
                    onPressed: _captureWhenLoggedIn,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            Expanded(
              child: _preparing
                  ? const Center(child: CircularProgressIndicator())
                  : InAppWebView(
                      initialUrlRequest: URLRequest(url: _loginUrl),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        thirdPartyCookiesEnabled: true,
                        sharedCookiesEnabled: true,
                        useShouldOverrideUrlLoading: true,
                      ),
                      shouldOverrideUrlLoading: (controller, action) async {
                        final uri = action.request.url;
                        if (uri == null) return NavigationActionPolicy.CANCEL;
                        final host = uri.host.toLowerCase();
                        final allowed =
                            host == 'facebook.com' ||
                            host.endsWith('.facebook.com') ||
                            host == 'messenger.com' ||
                            host.endsWith('.messenger.com');
                        return allowed
                            ? NavigationActionPolicy.ALLOW
                            : NavigationActionPolicy.CANCEL;
                      },
                      onLoadStop: (_, url) => _captureWhenLoggedIn(),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(OmniSpacing.md),
              child: Text(
                _submitting
                    ? 'Đã đăng nhập. Đang chuyển phiên an toàn sang agent…'
                    : 'Đăng nhập và hoàn tất xác minh Facebook ngay tại đây. Viomni không nhận mật khẩu của bạn.',
                textAlign: TextAlign.center,
                style: OmniType.micro.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
