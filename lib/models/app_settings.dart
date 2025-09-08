class AppSettings {
  final int callDelaySeconds;
  final bool darkMode;

  const AppSettings({
    this.callDelaySeconds = 30,
    this.darkMode = false,
  });

  AppSettings copyWith({int? callDelaySeconds, bool? darkMode}) {
    return AppSettings(
      callDelaySeconds: callDelaySeconds ?? this.callDelaySeconds,
      darkMode: darkMode ?? this.darkMode,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'call_delay_seconds': callDelaySeconds,
      'dark_mode': darkMode ? 1 : 0,
    };
  }

  static AppSettings fromMap(Map<String, Object?> map) {
    return AppSettings(
      callDelaySeconds: (map['call_delay_seconds'] as int?) ?? 30,
      darkMode: ((map['dark_mode'] as int?) ?? 0) == 1,
    );
  }
}
