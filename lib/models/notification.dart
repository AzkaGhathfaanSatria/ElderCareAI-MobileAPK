import 'elder.dart';

/// Satu baris dari `GET /notifications`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.description,
    required this.level,
    required this.createdAt,
    required this.read,
    required this.elderId,
    required this.elderName,
  });

  final String id;
  final String title;
  final String description;
  final RiskLevel level;
  final DateTime? createdAt;
  final bool read;
  final String elderId;
  final String elderName;

  AppNotification markedRead() => AppNotification(
        id: id,
        title: title,
        description: description,
        level: level,
        createdAt: createdAt,
        read: true,
        elderId: elderId,
        elderName: elderName,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
    return AppNotification(
      id: json['id'].toString(),
      title: (json['title'] as String?) ?? 'Peringatan',
      description: (json['description'] as String?) ?? '',
      level: RiskLevel.fromLabel(json['level'] as String?),
      createdAt: created is String ? DateTime.tryParse(created)?.toLocal() : null,
      read: json['readAt'] != null,
      elderId: (json['elderId'] ?? '').toString(),
      elderName: (json['elderName'] as String?) ?? '',
    );
  }
}

/// Respons `GET /me/notification-preferences` (objek langsung, tidak dibungkus `data`).
class NotificationPrefs {
  const NotificationPrefs({
    required this.push,
    required this.dashboard,
    required this.minimumLevel,
  });

  final bool push;
  final bool dashboard;
  final RiskLevel minimumLevel;

  NotificationPrefs copyWith({bool? push, bool? dashboard, RiskLevel? minimumLevel}) {
    return NotificationPrefs(
      push: push ?? this.push,
      dashboard: dashboard ?? this.dashboard,
      minimumLevel: minimumLevel ?? this.minimumLevel,
    );
  }

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) {
    return NotificationPrefs(
      push: json['push'] != false,
      dashboard: json['dashboard'] != false,
      minimumLevel: RiskLevel.fromLabel(json['minimumLevel'] as String?),
    );
  }
}

/// Respons `POST /me/push-test`.
class PushTestResult {
  const PushTestResult({
    required this.enabled,
    required this.tokens,
    required this.sent,
    required this.failed,
  });

  /// False bila server belum diberi kunci Firebase.
  final bool enabled;

  /// Jumlah perangkat terdaftar untuk akun ini.
  final int tokens;
  final int sent;
  final int failed;

  factory PushTestResult.fromJson(Map<String, dynamic> json) {
    return PushTestResult(
      enabled: json['enabled'] == true,
      tokens: (json['tokens'] as num?)?.toInt() ?? 0,
      sent: (json['sent'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
    );
  }
}
