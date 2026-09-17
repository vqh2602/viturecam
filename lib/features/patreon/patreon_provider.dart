import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'patreon_models.dart';
import 'patreon_service.dart';
import 'patreon_storage.dart';

class PatreonState {
  final PatreonAccount? account;
  final PatreonConfig config;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const PatreonState({
    this.account,
    this.config = const PatreonConfig(),
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  bool get isLoggedIn => account != null;
  bool get isPatron => account?.isPatron ?? false;
  bool get isTestMode => account?.isTestMode ?? false;
  String get fullName => account?.fullName ?? '';
  String get email => account?.email ?? '';
  String get displayAmount => account?.displayAmount ?? '';
  String get patronStatus => account?.patronStatus ?? '';

  PatreonState copyWith({
    PatreonAccount? account,
    bool clearAccount = false,
    PatreonConfig? config,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return PatreonState(
      account: clearAccount ? null : (account ?? this.account),
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class PatreonNotifier extends StateNotifier<PatreonState> {
  final PatreonService _service;

  PatreonNotifier([PatreonService? service])
      : _service = service ?? PatreonService(),
        super(const PatreonState()) {
    loadSavedState();
  }

  Future<void> loadSavedState() async {
    state = state.copyWith(isLoading: true);
    final account = await PatreonStorage.loadAccount();
    final config = await PatreonStorage.loadConfig();
    if (!mounted) return;
    state = state.copyWith(
      account: account,
      config: config,
      isLoading: false,
    );
  }

  Future<void> saveConfig(PatreonConfig config) async {
    await PatreonStorage.saveConfig(config);
    if (!mounted) return;
    state = state.copyWith(config: config);
  }

  Future<bool> loginWithOAuth() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final account = await _service.loginWithOAuth(state.config);
      await PatreonStorage.saveAccount(account);
      if (!mounted) return false;
      state = state.copyWith(
        account: account,
        isLoading: false,
        successMessage: 'Đăng nhập Patreon thành công!',
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> checkMembershipStatus() async {
    if (state.account == null) return false;

    if (state.account!.isTestMode) {
      // Trong test mode, làm mới trạng thái test
      final updated = PatreonService.createTestAccount(isPatron: true);
      await PatreonStorage.saveAccount(updated);
      if (!mounted) return true;
      state = state.copyWith(
        account: updated,
        successMessage: 'Đã xác nhận tư cách thành viên VIP (Test Mode)',
      );
      return true;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      var token = state.account!.accessToken;
      PatreonAccount updatedAccount;

      try {
        updatedAccount = await _service.fetchIdentity(
          accessToken: token,
          refreshToken: state.account!.refreshToken,
        );
      } catch (e) {
        // Nếu token hết hạn và có refresh token
        if (state.account!.refreshToken != null && state.config.isConfigured) {
          token = await _service.refreshAccessToken(
            config: state.config,
            refreshToken: state.account!.refreshToken!,
          );
          updatedAccount = await _service.fetchIdentity(
            accessToken: token,
            refreshToken: state.account!.refreshToken,
          );
        } else {
          rethrow;
        }
      }

      await PatreonStorage.saveAccount(updatedAccount);
      if (!mounted) return updatedAccount.isPatron;
      state = state.copyWith(
        account: updatedAccount,
        isLoading: false,
        successMessage: updatedAccount.isPatron
            ? 'Đã xác nhận: Bạn đang là Patron hoạt động (${updatedAccount.displayAmount}/tháng)'
            : 'Tài khoản chưa có gói ủng hộ nào đang hoạt động',
      );
      return updatedAccount.isPatron;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Lỗi kiểm tra tư cách thành viên: ${e.toString().replaceAll('Exception: ', '')}',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await PatreonStorage.saveAccount(null);
    if (!mounted) return;
    state = state.copyWith(clearAccount: true, clearError: true, clearSuccess: true);
  }

  Future<void> enableTestMode(bool enable) async {
    if (enable) {
      final testAccount = PatreonService.createTestAccount(isPatron: true);
      await PatreonStorage.saveAccount(testAccount);
      if (!mounted) return;
      state = state.copyWith(account: testAccount, clearError: true, clearSuccess: true);
    } else {
      if (state.account?.isTestMode == true) {
        await logout();
      }
    }
  }

  Future<void> openCampaign() async {
    final url = state.config.campaignUrl.isNotEmpty ? state.config.campaignUrl : 'https://www.patreon.com';
    await _service.openUrl(url);
  }
}

final patreonProvider = StateNotifierProvider<PatreonNotifier, PatreonState>((ref) {
  return PatreonNotifier();
});
