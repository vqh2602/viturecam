import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'patreon_models.dart';
import 'patreon_provider.dart';
import 'patreon_service.dart';

class PatreonConfigDialog extends ConsumerStatefulWidget {
  const PatreonConfigDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const PatreonConfigDialog(),
    );
  }

  @override
  ConsumerState<PatreonConfigDialog> createState() => _PatreonConfigDialogState();
}

class _PatreonConfigDialogState extends ConsumerState<PatreonConfigDialog> {
  late TextEditingController _clientIdCtrl;
  late TextEditingController _clientSecretCtrl;
  late TextEditingController _redirectUriCtrl;
  late TextEditingController _campaignUrlCtrl;
  late TextEditingController _campaignIdCtrl;
  late TextEditingController _creatorAccessTokenCtrl;
  late TextEditingController _creatorRefreshTokenCtrl;

  @override
  void initState() {
    super.initState();
    final config = ref.read(patreonProvider).config;
    _clientIdCtrl = TextEditingController(text: config.clientId);
    _clientSecretCtrl = TextEditingController(text: config.clientSecret);
    _redirectUriCtrl = TextEditingController(text: config.redirectUri);
    _campaignUrlCtrl = TextEditingController(text: config.campaignUrl);
    _campaignIdCtrl = TextEditingController(text: config.campaignId);
    _creatorAccessTokenCtrl = TextEditingController(text: config.creatorAccessToken);
    _creatorRefreshTokenCtrl = TextEditingController(text: config.creatorRefreshToken);
  }

  @override
  void dispose() {
    _clientIdCtrl.dispose();
    _clientSecretCtrl.dispose();
    _redirectUriCtrl.dispose();
    _campaignUrlCtrl.dispose();
    _campaignIdCtrl.dispose();
    _creatorAccessTokenCtrl.dispose();
    _creatorRefreshTokenCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final current = ref.read(patreonProvider).config;
    final newConfig = current.copyWith(
      clientId: _clientIdCtrl.text.trim().isNotEmpty
          ? _clientIdCtrl.text.trim()
          : PatreonConfig.defaultClientId,
      clientSecret: _clientSecretCtrl.text.trim().isNotEmpty
          ? _clientSecretCtrl.text.trim()
          : PatreonConfig.defaultClientSecret,
      redirectUri: _redirectUriCtrl.text.trim().isNotEmpty
          ? _redirectUriCtrl.text.trim()
          : PatreonConfig.defaultRedirectUri,
      campaignUrl: _campaignUrlCtrl.text.trim().isNotEmpty
          ? _campaignUrlCtrl.text.trim()
          : PatreonConfig.defaultCampaignUrl,
      campaignId: _campaignIdCtrl.text.trim().isNotEmpty
          ? _campaignIdCtrl.text.trim()
          : PatreonConfig.defaultCampaignId,
      creatorAccessToken: _creatorAccessTokenCtrl.text.trim().isNotEmpty
          ? _creatorAccessTokenCtrl.text.trim()
          : PatreonConfig.defaultCreatorAccessToken,
      creatorRefreshToken: _creatorRefreshTokenCtrl.text.trim().isNotEmpty
          ? _creatorRefreshTokenCtrl.text.trim()
          : PatreonConfig.defaultCreatorRefreshToken,
    );
    ref.read(patreonProvider.notifier).saveConfig(newConfig);
    Navigator.of(context).pop();
  }

  void _copyRedirectUri() {
    final uri = _redirectUriCtrl.text.trim().isNotEmpty
        ? _redirectUriCtrl.text.trim()
        : 'http://localhost:8888/callback';
    Clipboard.setData(ClipboardData(text: uri));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép Redirect URI: $uri'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF2E2E38),
      ),
    );
  }

  void _openDeveloperPortal() {
    PatreonService().openUrl('https://www.patreon.com/portal/registration/register-clients');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patreonProvider);
    final notifier = ref.read(patreonProvider.notifier);

    return Dialog(
      backgroundColor: const Color(0xFF1C1C22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Colors.white12),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF424D).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.settings_suggest_rounded, color: Color(0xFFFF424D), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Cấu hình Patreon',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Colors.white10),
              const SizedBox(height: 12),

              // Quick Creator Login Banner
              if (state.config.hasCreatorToken) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7597).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF7597).withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFF7597), size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đăng nhập Tác giả (Creator VIP)',
                              style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Xác thực tài khoản Huy Vương ngay lập tức bằng Creator Token',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: state.isLoading
                            ? null
                            : () async {
                                final success = await notifier.loginWithCreatorToken();
                                if (success && context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7597),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.flash_on_rounded, size: 14),
                        label: const Text('Đăng nhập', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Quick Developer Guide Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF24242B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.help_outline_rounded, color: Color(0xFFFF7597), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Hướng dẫn kết nối Patreon OAuth (1 phút)',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '1. Mở Patreon Developer Portal và tạo Client mới.\n'
                      '2. Nhập Redirect URI là: http://localhost:8888/callback\n'
                      '3. Dán Client ID & Client Secret vào bên dưới và bấm Lưu.',
                      style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.45),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _openDeveloperPortal,
                          icon: const Icon(Icons.open_in_new_rounded, size: 13),
                          label: const Text('Mở trang Developer Portal', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF7597),
                            side: const BorderSide(color: Color(0xFFFF424D), width: 0.8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _copyRedirectUri,
                          icon: const Icon(Icons.copy_rounded, size: 13),
                          label: const Text('Sao chép Redirect URI', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24, width: 0.8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Client ID
              _buildTextField(
                controller: _clientIdCtrl,
                label: 'Client ID (từ Patreon Developer Portal)',
                hint: 'Nhập Client ID của OAuth Client',
              ),
              const SizedBox(height: 12),

              // Client Secret
              _buildTextField(
                controller: _clientSecretCtrl,
                label: 'Client Secret',
                hint: 'Nhập Client Secret',
                obscure: true,
              ),
              const SizedBox(height: 12),

              // Redirect URI
              _buildTextField(
                controller: _redirectUriCtrl,
                label: 'Redirect URI (Mặc định: http://localhost:8888/callback)',
                hint: 'http://localhost:8888/callback',
              ),
              const SizedBox(height: 12),

              // Campaign URL
              _buildTextField(
                controller: _campaignUrlCtrl,
                label: 'Patreon Campaign URL (Trang ủng hộ)',
                hint: PatreonConfig.defaultCampaignUrl,
              ),
              const SizedBox(height: 12),

              // Campaign ID
              _buildTextField(
                controller: _campaignIdCtrl,
                label: 'Campaign ID (Mặc định: 16838541)',
                hint: PatreonConfig.defaultCampaignId,
              ),
              const SizedBox(height: 12),

              // Creator Access Token
              _buildTextField(
                controller: _creatorAccessTokenCtrl,
                label: 'Creator Access Token (Dành riêng cho Tác giả)',
                hint: 'Token của Tác giả',
                obscure: true,
              ),
              const SizedBox(height: 12),

              // Creator Refresh Token
              _buildTextField(
                controller: _creatorRefreshTokenCtrl,
                label: 'Creator Refresh Token (Dành riêng cho Tác giả)',
                hint: 'Refresh token của Tác giả',
                obscure: true,
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF424D),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: const Text('Lưu cấu hình', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontSize: 12.5),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF141418),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white10)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white10)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFF424D), width: 1.2)),
          ),
        ),
      ],
    );
  }
}
