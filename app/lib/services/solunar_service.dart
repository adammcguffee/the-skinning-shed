import 'dart:math' as math;

/// Solunar feeding times calculator for hunting activity predictions.
///
/// Based on the Solunar Theory developed by John Alden Knight, which correlates
/// fish and game activity with the position of the moon.
///
/// Major periods (~2 hours): When moon is directly overhead or underfoot
/// Minor periods (~1 hour): At moonrise and moonset
///
/// This implementation uses astronomical calculations without external APIs.
class SolunarService {
  /// Calculate Solunar times for a given date and location.
  ///
  /// Returns [SolunarTimes] containing major and minor feeding periods.
  SolunarTimes getSolunarTimes({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) {
    // Normalize date to local midnight
    final localDate = DateTime(date.year, date.month, date.day);

    // Calculate Julian Day Number
    final jd = _toJulianDay(localDate);

    // Calculate moon transit times
    final moonTimes = _calculateMoonTimes(jd, latitude, longitude);

    // Major periods: Moon overhead (transit) and underfoot (anti-transit)
    // Minor periods: Moonrise and moonset
    final major1 = _createPeriod(moonTimes.transit, const Duration(hours: 2), 'Major');
    final major2 = _createPeriod(moonTimes.antiTransit, const Duration(hours: 2), 'Major');
    final minor1 = _createPeriod(moonTimes.rise, const Duration(hours: 1), 'Minor');
    final minor2 = _createPeriod(moonTimes.set, const Duration(hours: 1), 'Minor');

    // Sort periods by start time
    final allPeriods = [
      if (major1 != null) major1,
      if (major2 != null) major2,
      if (minor1 != null) minor1,
      if (minor2 != null) minor2,
    ]..sort((a, b) => a.start.compareTo(b.start));

    // Separate majors and minors for cleaner access
    final majors = allPeriods.where((p) => p.type == 'Major').toList();
    final minors = allPeriods.where((p) => p.type == 'Minor').toList();

    return SolunarTimes(
      date: localDate,
      latitude: latitude,
      longitude: longitude,
      major1: majors.isNotEmpty ? majors[0] : null,
      major2: majors.length > 1 ? majors[1] : null,
      minor1: minors.isNotEmpty ? minors[0] : null,
      minor2: minors.length > 1 ? minors[1] : null,
      moonrise: moonTimes.rise,
      moonset: moonTimes.set,
      moonTransit: moonTimes.transit,
    );
  }

  SolunarPeriod? _createPeriod(DateTime? centerTime, Duration halfDuration, String type) {
    if (centerTime == null) return null;
    final halfMinutes = halfDuration.inMinutes ~/ 2;
    return SolunarPeriod(
      start: centerTime.subtract(Duration(minutes: halfMinutes)),
      end: centerTime.add(Duration(minutes: halfMinutes)),
      peak: centerTime,
      type: type,
    );
  }

  /// Convert DateTime to Julian Day Number
  double _toJulianDay(DateTime dt) {
    final y = dt.year;
    final m = dt.month;
    final d = dt.day + (dt.hour + dt.minute / 60.0) / 24.0;

    final a = ((14 - m) / 12).floor();
    final y1 = y + 4800 - a;
    final m1 = m + 12 * a - 3;

    return d + ((153 * m1 + 2) / 5).floor() + 365 * y1 + (y1 / 4).floor() - (y1 / 100).floor() + (y1 / 400).floor() - 32045;
  }

  /// Calculate approximate moon transit times
  _MoonTimes _calculateMoonTimes(double jd, double lat, double lon) {
    // Calculate moon position for noon local time
    final jdNoon = jd;

    // Moon's mean longitude
    final daysSinceJ2000 = jdNoon - 2451545.0;
    final T = daysSinceJ2000 / 36525.0;

    // Moon's mean orbital elements (simplified)
    final L0 = _normalize(218.32 + 481267.883 * T); // Mean longitude
    final M = _normalize(134.9 + 477198.85 * T); // Mean anomaly
    final F = _normalize(93.3 + 483202.02 * T); // Argument of latitude

    // Approximate moon longitude
    final moonLon = L0 + 6.29 * _sin(M) + 1.27 * _sin(2 * F - M) + 0.66 * _sin(2 * F);

    // Local sidereal time at midnight
    final lst = _normalize(100.46 + 0.985647 * daysSinceJ2000 + lon);

    // Hour angle at transit (moon overhead)
    final hourAngleTransit = _normalize(moonLon - lst);
    final transitHours = hourAngleTransit / 15.0;

    // Moon transit time (when moon is highest)
    final transitTime = DateTime(
      (jd - 0.5).floor() + 2000 - 2451545,
      1,
      1,
    ).add(Duration(
      days: ((jd - 2451545) % 365.25).floor(),
      hours: transitHours.floor(),
      minutes: ((transitHours % 1) * 60).floor(),
    ));

    // For simplified calculation, estimate moonrise/moonset as ~6h before/after transit
    // This is approximate; real calculation requires iterative solving
    final riseHours = (transitHours - 6.5 + 24) % 24;
    final setHours = (transitHours + 6.5) % 24;
    final antiTransitHours = (transitHours + 12) % 24;

    // Create DateTime objects for today
    final baseDate = DateTime.fromMillisecondsSinceEpoch(
      ((jd - 2440587.5) * 86400000).round(),
    );
    final today = DateTime(baseDate.year, baseDate.month, baseDate.day);

    DateTime? makeTime(double hours) {
      if (hours.isNaN || hours.isInfinite) return null;
      final h = hours.floor();
      final m = ((hours - h) * 60).floor();
      return today.add(Duration(hours: h, minutes: m));
    }

    return _MoonTimes(
      rise: makeTime(riseHours),
      set: makeTime(setHours),
      transit: makeTime(transitHours),
      antiTransit: makeTime(antiTransitHours),
    );
  }

  double _normalize(double degrees) => degrees % 360;
  double _sin(double degrees) => math.sin(degrees * math.pi / 180);
}

class _MoonTimes {
  const _MoonTimes({
    this.rise,
    this.set,
    this.transit,
    this.antiTransit,
  });

  final DateTime? rise;
  final DateTime? set;
  final DateTime? transit;
  final DateTime? antiTransit;
}

/// A Solunar feeding period (major or minor).
class SolunarPeriod {
  const SolunarPeriod({
    required this.start,
    required this.end,
    required this.peak,
    required this.type,
  });

  final DateTime start;
  final DateTime end;
  final DateTime peak;
  final String type; // 'Major' or 'Minor'

  Duration get duration => end.difference(start);

  bool isActive(DateTime time) => time.isAfter(start) && time.isBefore(end);

  String get timeRange {
    String fmt(DateTime t) {
      final h = t.hour;
      final m = t.minute;
      final suffix = h >= 12 ? 'PM' : 'AM';
      final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$displayH:${m.toString().padLeft(2, '0')} $suffix';
    }
    return '${fmt(start)} – ${fmt(end)}';
  }
}

/// Complete Solunar times for a given day and location.
class SolunarTimes {
  const SolunarTimes({
    required this.date,
    required this.latitude,
    required this.longitude,
    this.major1,
    this.major2,
    this.minor1,
    this.minor2,
    this.moonrise,
    this.moonset,
    this.moonTransit,
  });

  final DateTime date;
  final double latitude;
  final double longitude;
  final SolunarPeriod? major1;
  final SolunarPeriod? major2;
  final SolunarPeriod? minor1;
  final SolunarPeriod? minor2;
  final DateTime? moonrise;
  final DateTime? moonset;
  final DateTime? moonTransit;

  List<SolunarPeriod> get allPeriods => [
        if (major1 != null) major1!,
        if (major2 != null) major2!,
        if (minor1 != null) minor1!,
        if (minor2 != null) minor2!,
      ];

  /// Get the next upcoming period from a given time.
  SolunarPeriod? getNextPeriod(DateTime from) {
    final sorted = allPeriods..sort((a, b) => a.start.compareTo(b.start));
    for (final p in sorted) {
      if (p.start.isAfter(from) || p.isActive(from)) {
        return p;
      }
    }
    // Wrap to next day's first period
    return sorted.isNotEmpty ? sorted.first : null;
  }

  /// Get currently active period, if any.
  SolunarPeriod? getActivePeriod(DateTime time) {
    for (final p in allPeriods) {
      if (p.isActive(time)) return p;
    }
    return null;
  }
}
