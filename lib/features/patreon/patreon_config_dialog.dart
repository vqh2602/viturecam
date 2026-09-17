import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'patreon_models.dart';
import 'patreon_provider.dart';

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

  @override
  void initState() {
    super.initState();
    final config = ref.read(patreonProvider).config;
    _clientIdCtrl = TextEditingController(text: config.clientId);
    _clientSecretCtrl = TextEditingController(text: config.clientSecret);
    _redirectUriCtrl = TextEditingController(text: config.redirectUri);
    _campaignUrlCtrl = TextEditingController(text: config.campaignUrl);
  }

  @override
  void dispose() {
    _clientIdCtrl.dispose();
    _clientSecretCtrl.dispose();
    _redirectUriCtrl.dispose();
    _campaignUrlCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final newConfig = PatreonConfig(
      clientId: _clientIdCtrl.text.trim(),
      clientSecret: _clientSecretCtrl.text.trim(),
      redirectUri: _redirectUriCtrl.text.trim().isNotEmpty
          ? _redirectUriCtrl.text.trim()
          : 'http://localhost:8888/callback',
      campaignUrl: _campaignUrlCtrl.text.trim().isNotEmpty
          ? _campaignUrlCtrl.text.trim()
          : 'https://www.patreon.com',
    );
    ref.read(patreonProvider.notifier).saveConfig(newConfig);
    Navigator.of(context).pop();
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
        width: 480,
        padding: const EdgeInsets.all(24),
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
                    'Cấu hình Patreon OAuth & Dùng thử',
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

            // Test Mode Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: state.isTestMode
                    ? const Color(0xFFFF424D).withValues(alpha: 0.12)
                    : const Color(0xFF24242B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: state.isTestMode ? const Color(0xFFFF424D).withValues(alpha: 0.4) : Colors.white10,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chế độ dùng thử VIP (Test Mode)',
                          style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Bật để mở khóa Makeup ngay mà không cần kết nối OAuth',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: state.isTestMode,
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFFFF424D),
                    onChanged: (val) {
                      notifier.enableTestMode(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

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
              hint: 'https://www.patreon.com/your_page',
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
