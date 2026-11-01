enum RiskLevel {
  rendah('Rendah'),
  sedang('Sedang'),
  tinggi('Tinggi');

  const RiskLevel(this.label);

  final String label;

  /// Backend mengirim "Rendah" / "Sedang" / "Tinggi".
  static RiskLevel fromLabel(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'tinggi':
        return RiskLevel.tinggi;
      case 'sedang':
        return RiskLevel.sedang;
      default:
        return RiskLevel.rendah;
    }
  }
}

class Elder {
  const Elder({
    required this.id,
    required this.nama,
    required this.umur,
    required this.alamat,
    required this.catatanKesehatan,
  });

  /// id dikirim backend sebagai string.
  final String id;
  final String nama;
  final int umur;
  final String alamat;
  final String catatanKesehatan;

  factory Elder.fromJson(Map<String, dynamic> json) {
    return Elder(
      id: json['id'].toString(),
      nama: (json['nama'] as String?) ?? '',
      umur: (json['umur'] as num?)?.toInt() ?? 0,
      alamat: (json['alamat'] as String?) ?? '',
      catatanKesehatan: (json['catatanKesehatan'] as String?) ?? '',
    );
  }
}

/// Alert aktif (belum "selesai") terbaru milik seorang lansia.
class ActiveAlert {
  const ActiveAlert({
    required this.id,
    required this.fallId,
    required this.status,
    required this.type,
    required this.description,
    required this.detected,
    required this.level,
  });

  static const statusBaru = 'baru';
  static const statusDitindaklanjuti = 'ditindaklanjuti';
  static const statusSelesai = 'selesai';

  final String id;

  /// Terisi bila alert berasal dari deteksi jatuh; dipakai untuk konfirmasi jatuh.
  final String? fallId;
  final String status;
  final String type;
  final String description;

  /// Sudah diformat backend, mis. "27 Okt 2026 16:45 WIB".
  final String detected;
  final RiskLevel level;

  bool get isFall => fallId != null || type.startsWith('Jatuh');

  String get statusLabel {
    switch (status) {
      case statusDitindaklanjuti:
        return 'Ditindaklanjuti';
      case statusSelesai:
        return 'Selesai';
      default:
        return 'Baru';
    }
  }

  factory ActiveAlert.fromJson(Map<String, dynamic> json) {
    return ActiveAlert(
      id: json['id'].toString(),
      fallId: json['fallId']?.toString(),
      status: (json['status'] as String?) ?? statusBaru,
      type: (json['type'] as String?) ?? 'Peringatan',
      description: (json['description'] as String?) ?? '',
      detected: (json['detected'] as String?) ?? '',
      level: RiskLevel.fromLabel(json['level'] as String?),
    );
  }
}

class ActivityDay {
  const ActivityDay({required this.day, required this.value});

  final String day;

  /// 0-100, hari tersibuk = 100.
  final int value;

  factory ActivityDay.fromJson(Map<String, dynamic> json) {
    return ActivityDay(
      day: (json['day'] as String?) ?? '',
      value: (json['value'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Respons `GET /elders/:id/summary`.
class ElderSummary {
  const ElderSummary({
    required this.heartRate,
    this.oxygen,
    this.temperature,
    this.hrv,
    required this.activity,
    required this.sleepHours,
    required this.risk,
    required this.activityHistory,
    required this.alert,
  });

  /// 0 berarti belum ada data.
  final int heartRate;

  /// Nilai terbaru 24 jam terakhir dari jam; null bila belum ada.
  final double? oxygen;
  final double? temperature;
  final double? hrv;
  final int activity;
  final double sleepHours;
  final RiskLevel risk;
  final List<ActivityDay> activityHistory;
  final ActiveAlert? alert;

  bool get hasHeartRate => heartRate > 0;
  bool get hasSleep => sleepHours > 0;

  factory ElderSummary.fromJson(Map<String, dynamic> json) {
    final alertJson = json['alert'];
    final hasAlert = json['hasAlert'] == true &&
        alertJson is Map<String, dynamic> &&
        alertJson['id'] != null;

    final history = json['activityHistory'];

    return ElderSummary(
      heartRate: (json['heartRate'] as num?)?.toInt() ?? 0,
      oxygen: (json['oxygen'] as num?)?.toDouble(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      hrv: (json['hrv'] as num?)?.toDouble(),
      activity: (json['activity'] as num?)?.toInt() ?? 0,
      sleepHours: (json['sleep'] as num?)?.toDouble() ?? 0,
      risk: RiskLevel.fromLabel(json['risk'] as String?),
      activityHistory: history is List
          ? history
              .whereType<Map<String, dynamic>>()
              .map(ActivityDay.fromJson)
              .toList()
          : const [],
      alert: hasAlert ? ActiveAlert.fromJson(alertJson) : null,
    );
  }
}

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.date,
    required this.time,
    required this.type,
    required this.description,
    required this.level,
  });

  final String id;
  final String date;
  final String time;
  final String type;
  final String description;
  final RiskLevel level;

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'].toString(),
      date: (json['date'] as String?) ?? '',
      time: (json['time'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      level: RiskLevel.fromLabel(json['level'] as String?),
    );
  }
}

class VitalPoint {
  const VitalPoint({required this.time, required this.heartRate});

  final DateTime time;
  final int? heartRate;

  /// Mengembalikan null bila timestamp tidak bisa dibaca.
  static VitalPoint? tryParse(Map<String, dynamic> json) {
    final raw = json['timestamp'];
    final time = raw is String ? DateTime.tryParse(raw) : null;
    if (time == null) return null;
    return VitalPoint(
      time: time.toLocal(),
      heartRate: (json['heartRate'] as num?)?.toInt(),
    );
  }
}
