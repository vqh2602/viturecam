import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'patreon_models.dart';

class PatreonService {
  static const String _authorizeBaseUrl = 'https://www.patreon.com/oauth2/authorize';
  static const String _tokenBaseUrl = 'https://www.patreon.com/api/oauth2/token';
  static const String _identityBaseUrl =
      'https://www.patreon.com/api/oauth2/v2/identity?include=memberships.campaign,memberships.currently_entitled_tiers&fields[user]=email,first_name,last_name,full_name,image_url,url&fields[member]=patron_status,currently_entitled_amount_cents,is_follower,last_charge_status,lifetime_support_cents';

  /// Mở link trình duyệt trên macOS
  Future<void> openUrl(String url) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
      }
    } catch (e) {
      debugPrint('[PatreonService] Error opening url: $e');
    }
  }

  /// Khởi động luồng OAuth2 qua trình duyệt và đón callback tại localhost
  Future<PatreonAccount> loginWithOAuth(PatreonConfig config) async {
    if (!config.isConfigured) {
      throw Exception('Chưa cấu hình Client ID và Client Secret cho Patreon OAuth');
    }

    final redirectUri = Uri.parse(config.redirectUri);
    final port = redirectUri.port > 0 ? redirectUri.port : 8888;
    final state = 'state_${DateTime.now().millisecondsSinceEpoch}';

    HttpServer? server;
    try {
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      } catch (_) {
        // Thử lại nếu port mặc định đang bận
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      }

      final actualPort = server.port;
      final actualRedirectUri = '${redirectUri.scheme}://${redirectUri.host}:$actualPort${redirectUri.path}';

      final authUri = Uri.parse(_authorizeBaseUrl).replace(queryParameters: {
        'response_type': 'code',
        'client_id': config.clientId.trim(),
        'redirect_uri': actualRedirectUri,
        'scope': 'identity identity.memberships',
        'state': state,
      });

      debugPrint('[PatreonService] Opening OAuth URL: $authUri');
      await openUrl(authUri.toString());

      // Chờ request callback từ browser trong tối đa 3 phút
      final completer = Completer<String>();
      final sub = server.listen((HttpRequest request) async {
        final uri = request.uri;
        if (uri.path == redirectUri.path || uri.path == '/callback') {
          final code = uri.queryParameters['code'];
          final returnedState = uri.queryParameters['state'];
          final error = uri.queryParameters['error'];

          // Gửi phản hồi HTML cho browser
          request.response.headers.contentType = ContentType.html;
          if (error != null) {
            request.response.write('''
              <!DOCTYPE html>
              <html>
              <head><meta charset="utf-8"><title>Xác thực thất bại</title></head>
              <body style="font-family: sans-serif; background: #141419; color: #fff; text-align: center; padding: 50px;">
                <h2 style="color: #FF5252;">Đăng nhập Patreon không thành công</h2>
                <p>Lỗi: $error</p>
                <p>Bạn có thể đóng tab này và thử lại trong ứng dụng Beauty Camera.</p>
              </body>
              </html>
            ''');
            await request.response.close();
            if (!completer.isCompleted) {
              completer.completeError(Exception('Patreon error: $error'));
            }
          } else if (code != null) {
            request.response.write('''
              <!DOCTYPE html>
              <html>
              <head>
                <meta charset="utf-8">
                <title>Đăng nhập thành công</title>
                <style>
                  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #141419; color: #ffffff; text-align: center; padding: 60px 20px; }
                  .card { max-width: 460px; margin: 0 auto; background: #1E1E26; border-radius: 20px; padding: 40px; border: 1px solid rgba(255, 117, 151, 0.4); box-shadow: 0 10px 40px rgba(0,0,0,0.6); }
                  h1 { color: #FF7597; font-size: 22px; margin-bottom: 12px; }
                  p { color: rgba(255,255,255,0.75); font-size: 14.5px; line-height: 1.6; }
                </style>
              </head>
              <body>
                <div class="card">
                  <h1>Đăng nhập Patreon thành công!</h1>
                  <p>Tài khoản của bạn đã được xác thực.<br>Bạn có thể đóng trang này và quay lại ứng dụng <b>Beauty Camera</b>.</p>
                </div>
              </body>
              </html>
            ''');
            await request.response.close();
            if (!completer.isCompleted) {
              completer.complete(code);
            }
          } else {
            request.response.statusCode = HttpStatus.badRequest;
            request.response.write('Thiếu mã xác thực (code)');
            await request.response.close();
          }
        }
      });

      final code = await completer.future.timeout(const Duration(minutes: 3), onTimeout: () {
        throw TimeoutException('Quá thời gian chờ đăng nhập Patreon (3 phút)');
      });

      await sub.cancel();
      await server.close(force: true);

      // Trao đổi code lấy access_token
      return await _exchangeCodeForToken(
        code: code,
        clientId: config.clientId.trim(),
        clientSecret: config.clientSecret.trim(),
        redirectUri: actualRedirectUri,
      );
    } finally {
      try {
        await server?.close(force: true);
      } catch (_) {}
    }
  }

  Future<PatreonAccount> _exchangeCodeForToken({
    required String code,
    required String clientId,
    required String clientSecret,
    required String redirectUri,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(_tokenBaseUrl));
      request.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');

      final body = {
        'code': code,
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': redirectUri,
      };

      final bodyString = body.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
      request.write(bodyString);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        debugPrint('[PatreonService] Token exchange failed: $responseBody');
        throw Exception('Không thể lấy access token từ Patreon (${response.statusCode})');
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final accessToken = json['access_token'] as String;
      final refreshToken = json['refresh_token'] as String?;

      return await fetchIdentity(accessToken: accessToken, refreshToken: refreshToken);
    } finally {
      client.close();
    }
  }

  /// Làm mới token khi hết hạn
  Future<String> refreshAccessToken({
    required PatreonConfig config,
    required String refreshToken,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(_tokenBaseUrl));
      request.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');

      final body = {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': config.clientId.trim(),
        'client_secret': config.clientSecret.trim(),
      };

      final bodyString = body.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
      request.write(bodyString);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('Không thể làm mới token Patreon (${response.statusCode})');
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      return json['access_token'] as String;
    } finally {
      client.close();
    }
  }

  /// Lấy thông tin tài khoản và kiểm tra trạng thái donate
  Future<PatreonAccount> fetchIdentity({
    required String accessToken,
    String? refreshToken,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(_identityBaseUrl));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        debugPrint('[PatreonService] Fetch identity failed: $responseBody');
        throw Exception('Không thể lấy thông tin thành viên từ Patreon (${response.statusCode})');
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      return parseIdentityResponse(json: json, accessToken: accessToken, refreshToken: refreshToken);
    } finally {
      client.close();
    }
  }

  /// Phân tích JSON phản hồi từ Patreon v2 identity endpoint
  static PatreonAccount parseIdentityResponse({
    required Map<String, dynamic> json,
    required String accessToken,
    String? refreshToken,
    bool isTestMode = false,
  }) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final userId = data['id'] as String? ?? '';
    final userAttrs = data['attributes'] as Map<String, dynamic>? ?? {};

    final fullName = (userAttrs['full_name'] as String? ?? '').trim().isNotEmpty
        ? userAttrs['full_name'] as String
        : '${userAttrs['first_name'] ?? ''} ${userAttrs['last_name'] ?? ''}'.trim();
    final email = userAttrs['email'] as String? ?? '';
    final imageUrl = userAttrs['image_url'] as String?;
    final url = userAttrs['url'] as String?;

    // Phân tích danh sách memberships
    final included = json['included'] as List<dynamic>? ?? [];
    bool isPatron = false;
    String? patronStatus;
    int totalEntitledCents = 0;

    for (final item in included) {
      if (item is Map<String, dynamic> && item['type'] == 'member') {
        final attrs = item['attributes'] as Map<String, dynamic>? ?? {};
        final status = attrs['patron_status'] as String?;
        final amount = attrs['currently_entitled_amount_cents'] as int? ?? 0;
        final chargeStatus = attrs['last_charge_status'] as String?;

        if (amount > totalEntitledCents) {
          totalEntitledCents = amount;
        }

        if (status == 'active_patron' || amount > 0 || chargeStatus == 'Paid') {
          isPatron = true;
          patronStatus = status ?? 'active_patron';
        } else if (patronStatus == null) {
          patronStatus = status;
        }
      }
    }

    return PatreonAccount(
      id: userId,
      fullName: fullName.isNotEmpty ? fullName : 'Patreon User',
      email: email,
      imageUrl: imageUrl,
      url: url,
      isPatron: isPatron,
      patronStatus: patronStatus,
      entitledAmountCents: totalEntitledCents,
      accessToken: accessToken,
      refreshToken: refreshToken,
      lastChecked: DateTime.now(),
      isTestMode: isTestMode,
    );
  }

  /// Tạo tài khoản mẫu cho chế độ dùng thử (Test Mode)
  static PatreonAccount createTestAccount({bool isPatron = true}) {
    return PatreonAccount(
      id: 'test_patron_id',
      fullName: 'VIP Supporter (Test Mode)',
      email: 'supporter@beautycamera.test',
      imageUrl: null,
      url: 'https://www.patreon.com',
      isPatron: isPatron,
      patronStatus: isPatron ? 'active_patron' : 'former_patron',
      entitledAmountCents: isPatron ? 500 : 0,
      accessToken: 'test_access_token',
      refreshToken: 'test_refresh_token',
      lastChecked: DateTime.now(),
      isTestMode: true,
    );
  }
}
