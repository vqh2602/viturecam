class PatreonAccount {
  final String id;
  final String fullName;
  final String email;
  final String? imageUrl;
  final String? url;
  final bool isPatron;
  final String? patronStatus;
  final int entitledAmountCents;
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
    this.patronStatus,
    this.entitledAmountCents = 0,
    required this.accessToken,
    this.refreshToken,
    this.lastChecked,
    this.isTestMode = false,
  });

  String? get avatarUrl => imageUrl;

  String get displayAmount {
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
      'patronStatus': patronStatus,
      'entitledAmountCents': entitledAmountCents,
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
      patronStatus: json['patronStatus'] as String?,
      entitledAmountCents: json['entitledAmountCents'] as int? ?? 0,
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
    String? patronStatus,
    int? entitledAmountCents,
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
      patronStatus: patronStatus ?? this.patronStatus,
      entitledAmountCents: entitledAmountCents ?? this.entitledAmountCents,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      lastChecked: lastChecked ?? this.lastChecked,
      isTestMode: isTestMode ?? this.isTestMode,
    );
  }
}

class PatreonConfig {
  final String clientId;
  final String clientSecret;
  final String redirectUri;
  final String campaignUrl;

  const PatreonConfig({
    this.clientId = '',
    this.clientSecret = '',
    this.redirectUri = 'http://localhost:8888/callback',
    this.campaignUrl = 'https://www.patreon.com',
  });

  bool get isConfigured => clientId.trim().isNotEmpty && clientSecret.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'clientSecret': clientSecret,
      'redirectUri': redirectUri,
      'campaignUrl': campaignUrl,
    };
  }

  factory PatreonConfig.fromJson(Map<String, dynamic> json) {
    return PatreonConfig(
      clientId: json['clientId'] as String? ?? '',
      clientSecret: json['clientSecret'] as String? ?? '',
      redirectUri: json['redirectUri'] as String? ?? 'http://localhost:8888/callback',
      campaignUrl: json['campaignUrl'] as String? ?? 'https://www.patreon.com',
    );
  }

  PatreonConfig copyWith({
    String? clientId,
    String? clientSecret,
    String? redirectUri,
    String? campaignUrl,
  }) {
    return PatreonConfig(
      clientId: clientId ?? this.clientId,
      clientSecret: clientSecret ?? this.clientSecret,
      redirectUri: redirectUri ?? this.redirectUri,
      campaignUrl: campaignUrl ?? this.campaignUrl,
    );
  }
}
