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
  bool get isCreator => account?.isCreator ?? false;
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
    var account = await PatreonStorage.loadAccount();
    if (account != null && account.isTestMode) {
      await PatreonStorage.saveAccount(null);
      account = null;
    }
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
      final msg = account.isCreator
          ? 'Chào mừng tác giả Huy Vương! Đã mở khóa toàn bộ tính năng VIP.'
          : (account.isPatron
              ? 'Đăng nhập Patreon thành công! Gói ủng hộ đang hoạt động (${account.displayAmount}/tháng).'
              : 'Đăng nhập thành công, nhưng tài khoản chưa đăng ký gói ủng hộ.');
      state = state.copyWith(
        account: account,
        isLoading: false,
        successMessage: msg,
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

  Future<bool> loginWithCreatorToken() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final account = await _service.loginWithCreatorToken(config: state.config);
      await PatreonStorage.saveAccount(account);
      if (!mounted) return false;
      state = state.copyWith(
        account: account,
        isLoading: false,
        successMessage: 'Đăng nhập thành công với tư cách Tác giả (Creator VIP)!',
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

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      var token = state.account!.accessToken;
      PatreonAccount updatedAccount;

      try {
        updatedAccount = await _service.fetchIdentity(
          accessToken: token,
          refreshToken: state.account!.refreshToken,
          targetCampaignId: state.config.campaignId,
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
            targetCampaignId: state.config.campaignId,
          );
        } else {
          rethrow;
        }
      }

      await PatreonStorage.saveAccount(updatedAccount);
      if (!mounted) return updatedAccount.isPatron;
      final successMsg = updatedAccount.isCreator
          ? 'Đã xác nhận: Bạn là Tác giả của dự án (Creator VIP)!'
          : (updatedAccount.isPatron
              ? 'Đã xác nhận: Bạn đang là Patron hoạt động (${updatedAccount.displayAmount}/tháng)'
              : 'Tài khoản chưa có gói ủng hộ nào đang hoạt động cho chiến dịch này');
      state = state.copyWith(
        account: updatedAccount,
        isLoading: false,
        successMessage: successMsg,
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

  Future<void> openCampaign() async {
    final url = state.config.campaignUrl.isNotEmpty
        ? state.config.campaignUrl
        : PatreonConfig.defaultCampaignUrl;
    await _service.openUrl(url);
  }
}

final patreonProvider = StateNotifierProvider<PatreonNotifier, PatreonState>((ref) {
  return PatreonNotifier();
});
