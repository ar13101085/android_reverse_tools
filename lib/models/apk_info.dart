class ApkInfo {
  final String packageName;
  final String versionName;
  final String versionCode;
  final String targetSdk;
  final String minSdk;
  final List<String> permissions;
  final List<String> activities;
  final List<String> services;
  final List<String> receivers;
  final List<String> providers;
  final List<String> libraries;
  final String manifestContent;

  ApkInfo({
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.targetSdk,
    required this.minSdk,
    required this.permissions,
    required this.activities,
    required this.services,
    required this.receivers,
    required this.providers,
    required this.libraries,
    required this.manifestContent,
  });

  factory ApkInfo.empty() {
    return ApkInfo(
      packageName: '',
      versionName: '',
      versionCode: '',
      targetSdk: '',
      minSdk: '',
      permissions: [],
      activities: [],
      services: [],
      receivers: [],
      providers: [],
      libraries: [],
      manifestContent: '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'packageName': packageName,
      'versionName': versionName,
      'versionCode': versionCode,
      'targetSdk': targetSdk,
      'minSdk': minSdk,
      'permissions': permissions,
      'activities': activities,
      'services': services,
      'receivers': receivers,
      'providers': providers,
      'libraries': libraries,
      'manifestContent': manifestContent,
    };
  }

  factory ApkInfo.fromJson(Map<String, dynamic> json) {
    return ApkInfo(
      packageName: json['packageName'] ?? '',
      versionName: json['versionName'] ?? '',
      versionCode: json['versionCode'] ?? '',
      targetSdk: json['targetSdk'] ?? '',
      minSdk: json['minSdk'] ?? '',
      permissions: List<String>.from(json['permissions'] ?? []),
      activities: List<String>.from(json['activities'] ?? []),
      services: List<String>.from(json['services'] ?? []),
      receivers: List<String>.from(json['receivers'] ?? []),
      providers: List<String>.from(json['providers'] ?? []),
      libraries: List<String>.from(json['libraries'] ?? []),
      manifestContent: json['manifestContent'] ?? '',
    );
  }
}