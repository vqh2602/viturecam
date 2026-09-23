class PatreonAccount {
  final String id;
  final String fullName;
  final String email;
  final String? imageUrl;
  final String? url;
  final bool isPatron;
  final bool isCreator;
  final String? patronStatus;
  final int entitledAmountCents;
  final String? campaignId;
  final String accessToken;
  final String? refreshToken;
  final DateTime? lastChecked;
  final bool isTestMode;

  const PatreonAccount({
    required this.id,
    required this.fullName,
    required this.email,
    this.imageUrl,
    this.url,
    required this.isPatron,
    this.isCreator = false,
    this.patronStatus,
    this.entitledAmountCents = 0,
    this.campaignId,
    required this.accessToken,
    this.refreshToken,
    this.lastChecked,
    this.isTestMode = false,
  });

  String? get avatarUrl => imageUrl;

  String get displayAmount {
    if (isCreator) return 'Creator VIP';
    if (entitledAmountCents <= 0) return '\$0.00';
    final dollars = (entitledAmountCents / 100).toStringAsFixed(2);
    return '\$$dollars';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'imageUrl': imageUrl,
      'url': url,
      'isPatron': isPatron,
      'isCreator': isCreator,
      'patronStatus': patronStatus,
      'entitledAmountCents': entitledAmountCents,
      'campaignId': campaignId,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'lastChecked': lastChecked?.toIso8601String(),
      'isTestMode': isTestMode,
    };
  }

  factory PatreonAccount.fromJson(Map<String, dynamic> json) {
    return PatreonAccount(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? 'Patreon User',
      email: json['email'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      url: json['url'] as String?,
      isPatron: json['isPatron'] as bool? ?? false,
      isCreator: json['isCreator'] as bool? ?? false,
      patronStatus: json['patronStatus'] as String?,
      entitledAmountCents: json['entitledAmountCents'] as int? ?? 0,
      campaignId: json['campaignId'] as String?,
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String?,
      lastChecked: json['lastChecked'] is String ? DateTime.tryParse(json['lastChecked'] as String) : null,
      isTestMode: json['isTestMode'] as bool? ?? false,
    );
  }

  PatreonAccount copyWith({
    String? id,
    String? fullName,
    String? email,
    String? imageUrl,
    String? url,
    bool? isPatron,
    bool? isCreator,
    String? patronStatus,
    int? entitledAmountCents,
    String? campaignId,
    String? accessToken,
    String? refreshToken,
    DateTime? lastChecked,
    bool? isTestMode,
  }) {
    return PatreonAccount(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      imageUrl: imageUrl ?? this.imageUrl,
      url: url ?? this.url,
      isPatron: isPatron ?? this.isPatron,
      isCreator: isCreator ?? this.isCreator,
      patronStatus: patronStatus ?? this.patronStatus,
      entitledAmountCents: entitledAmountCents ?? this.entitledAmountCents,
      campaignId: campaignId ?? this.campaignId,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      lastChecked: lastChecked ?? this.lastChecked,
      isTestMode: isTestMode ?? this.isTestMode,
    );
  }
}

class PatreonConfig {
  static const String defaultAppName = 'beauty camera';
  static const String defaultCampaignUrl = 'https://www.patreon.com/16838541/join';
  static const String defaultCampaignId = '16838541';
  static const String defaultCreatorName = 'Huy Vương';
  static const String defaultCreatorEmail = 'vqh2602@gmail.com';
  static const String defaultCreatorId = '224342455';
  static const String defaultClientId = 'DxI6_RpCdG1zUcaTTHc6iPfd61N0UyoAtlT2OHbDhYl78Dcqz1iwqkN22fvhRHEP';
  static const String defaultClientSecret = 'fpRdG6O8jAlwRbulkZFykWS_iMyq3YD8n75vYUJ8Ks7ybFHHwMg2BlnZZYx-4K5R';
  static const String defaultCreatorAccessToken = '4JSS8ZgZND7KLYNFxugbB2z-kq7FAcBActNzz7nq3lg';
  static const String defaultCreatorRefreshToken = 'WBDtvUyzpaUz8dJb4725GDHsB813QeypZj5hVgJY3-s';
  static const String defaultRedirectUri = 'http://localhost:8888/callback';

  final String clientId;
  final String clientSecret;
  final String redirectUri;
  final String campaignUrl;
  final String campaignId;
  final String creatorName;
  final String creatorAccessToken;
  final String creatorRefreshToken;

  const PatreonConfig({
    this.clientId = defaultClientId,
    this.clientSecret = defaultClientSecret,
    this.redirectUri = defaultRedirectUri,
    this.campaignUrl = defaultCampaignUrl,
    this.campaignId = defaultCampaignId,
    this.creatorName = defaultCreatorName,
    this.creatorAccessToken = defaultCreatorAccessToken,
    this.creatorRefreshToken = defaultCreatorRefreshToken,
  });

  bool get isConfigured => clientId.trim().isNotEmpty && clientSecret.trim().isNotEmpty;
  bool get hasCreatorToken => creatorAccessToken.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'clientSecret': clientSecret,
      'redirectUri': redirectUri,
      'campaignUrl': campaignUrl,
      'campaignId': campaignId,
      'creatorName': creatorName,
      'creatorAccessToken': creatorAccessToken,
      'creatorRefreshToken': creatorRefreshToken,
    };
  }

  factory PatreonConfig.fromJson(Map<String, dynamic> json) {
    var rawCampaignUrl = json['campaignUrl'] as String? ?? defaultCampaignUrl;
    if (rawCampaignUrl == 'https://www.patreon.com' || rawCampaignUrl.trim().isEmpty) {
      rawCampaignUrl = defaultCampaignUrl;
    }

    final rawClientId = json['clientId'] as String? ?? '';
    final rawClientSecret = json['clientSecret'] as String? ?? '';
    final rawCreatorAccessToken = json['creatorAccessToken'] as String? ?? '';
    final rawCreatorRefreshToken = json['creatorRefreshToken'] as String? ?? '';

    return PatreonConfig(
      clientId: rawClientId.trim().isEmpty ? defaultClientId : rawClientId,
      clientSecret: rawClientSecret.trim().isEmpty ? defaultClientSecret : rawClientSecret,
      redirectUri: json['redirectUri'] as String? ?? defaultRedirectUri,
      campaignUrl: rawCampaignUrl,
      campaignId: json['campaignId'] as String? ?? defaultCampaignId,
      creatorName: json['creatorName'] as String? ?? defaultCreatorName,
      creatorAccessToken: rawCreatorAccessToken.trim().isEmpty ? defaultCreatorAccessToken : rawCreatorAccessToken,
      creatorRefreshToken: rawCreatorRefreshToken.trim().isEmpty ? defaultCreatorRefreshToken : rawCreatorRefreshToken,
    );
  }

  PatreonConfig copyWith({
    String? clientId,
    String? clientSecret,
    String? redirectUri,
    String? campaignUrl,
    String? campaignId,
    String? creatorName,
    String? creatorAccessToken,
    String? creatorRefreshToken,
  }) {
    return PatreonConfig(
      clientId: clientId ?? this.clientId,
      clientSecret: clientSecret ?? this.clientSecret,
      redirectUri: redirectUri ?? this.redirectUri,
      campaignUrl: campaignUrl ?? this.campaignUrl,
      campaignId: campaignId ?? this.campaignId,
      creatorName: creatorName ?? this.creatorName,
      creatorAccessToken: creatorAccessToken ?? this.creatorAccessToken,
      creatorRefreshToken: creatorRefreshToken ?? this.creatorRefreshToken,
    );
  }
}
