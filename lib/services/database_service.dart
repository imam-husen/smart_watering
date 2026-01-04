import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class DatabaseService {
  final DatabaseReference _statusRef =
      FirebaseDatabase.instance.ref().child('smart_watering/status');
  final DatabaseReference _historyRef =
      FirebaseDatabase.instance.ref().child('smart_watering/history');

  /// Stream untuk status (existing)
  Stream<Map<String, dynamic>> getStatusStream() {
    return _statusRef.onValue.map((event) {
      final dynamic value = event.snapshot.value;
      if (value == null) return <String, dynamic>{};
      if (value is Map) {
        try {
          return Map<String, dynamic>.from(value.map((k, v) => MapEntry(k.toString(), v)));
        } catch (_) {
          final result = <String, dynamic>{};
          (value).forEach((k, v) => result[k.toString()] = v);
          return result;
        }
      }
      return <String, dynamic>{};
    });
  }

  /// Set motorState (true = ON, false = OFF).
  /// When called from the app (manual), we also disable autoMode in the same update
  /// to reflect manual override.
  /// Returns true if write succeeded, false otherwise.
  Future<bool> setMotorState(bool motorOn) async {
    final String isoTime = DateTime.now().toIso8601String();
    try {
      // Update status node with motorState and autoMode=false (manual override)
      await _statusRef.update({
        'motorState': motorOn,
        'autoMode': false, // disable auto when manual control from app
        'updatedAt': isoTime,
        'controlSource': 'app_manual'
      });

      // Add history entry
      final historyData = {
        'motorState': motorOn,
        'timestamp': isoTime,
        'source': 'app_manual',
        'type': 'manual_control'
      };
      await _historyRef.push().set(historyData);

      return true;
    } on FirebaseException catch (e) {
      print('DatabaseService.setMotorState - FirebaseException: ${e.message}');
      return false;
    } catch (e) {
      print('DatabaseService.setMotorState - Unknown error: $e');
      return false;
    }
  }

  /// Set autoMode (true = otomatis aktif, false = non-aktif)
  Future<bool> setAutoMode(bool enabled) async {
    final String isoTime = DateTime.now().toIso8601String();
    try {
      await _statusRef.update({
        'autoMode': enabled,
        'updatedAt': isoTime,
      });
      
      // Log auto mode change
      final historyData = {
        'autoMode': enabled,
        'timestamp': isoTime,
        'source': 'app',
        'type': 'auto_mode_change'
      };
      await _historyRef.push().set(historyData);
      
      return true;
    } on FirebaseException catch (e) {
      print('DatabaseService.setAutoMode - FirebaseException: ${e.message}');
      return false;
    } catch (e) {
      print('DatabaseService.setAutoMode - Unknown error: $e');
      return false;
    }
  }

  /// Set autoThreshold (0..100)
  Future<bool> setAutoThreshold(int threshold) async {
    final String isoTime = DateTime.now().toIso8601String();
    try {
      await _statusRef.update({
        'autoThreshold': threshold,
        'updatedAt': isoTime,
      });
      return true;
    } on FirebaseException catch (e) {
      print('DatabaseService.setAutoThreshold - FirebaseException: ${e.message}');
      return false;
    } catch (e) {
      print('DatabaseService.setAutoThreshold - Unknown error: $e');
      return false;
    }
  }

  /// Set autoCooldownSeconds (seconds between auto cycles)
  Future<bool> setAutoCooldown(int seconds) async {
    final String isoTime = DateTime.now().toIso8601String();
    try {
      await _statusRef.update({
        'autoCooldownSeconds': seconds,
        'updatedAt': isoTime,
      });
      return true;
    } on FirebaseException catch (e) {
      print('DatabaseService.setAutoCooldown - FirebaseException: ${e.message}');
      return false;
    } catch (e) {
      print('DatabaseService.setAutoCooldown - Unknown error: $e');
      return false;
    }
  }

  /// Get last auto watering info.
  /// First tries /smart_watering/status.lastAutoWateredAt & lastAutoDuration.
  /// If not present, fallback to scanning recent history entries to find the last entry
  /// that looks like an automatic watering (type/source containing 'auto').
  Future<Map<String, dynamic>> getLastAutoWatering() async {
    try {
      // 1) Try status node first
      final statusSnap = await _statusRef.get();
      if (statusSnap.exists) {
        final statusMap = Map<String, dynamic>.from(statusSnap.value as Map);
        final lastAt = statusMap['lastAutoWateredAt'];
        final lastDur = statusMap['lastAutoDuration'];
        if (lastAt != null || lastDur != null) {
          return {
            'lastAutoWateredAt': lastAt ?? '-',
            'lastAutoDuration': lastDur?.toString() ?? '-',
          };
        }
      }

      // 2) Fallback: read recent history and find an entry marked as auto
      final histSnap = await _historyRef.limitToLast(200).get();
      if (histSnap.exists && histSnap.value != null) {
        final raw = Map<String, dynamic>.from(histSnap.value as Map);
        // Collect entries and sort by timestamp (if present) descending
        final entries = <Map<String, dynamic>>[];
        raw.forEach((k, v) {
          if (v is Map) entries.add(Map<String, dynamic>.from(v));
        });

        entries.sort((a, b) {
          final ta = DateTime.tryParse(a['timestamp']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final tb = DateTime.tryParse(b['timestamp']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return tb.compareTo(ta);
        });

        for (final e in entries) {
          final type = e['type']?.toString().toLowerCase() ?? '';
          final source = e['source']?.toString().toLowerCase() ?? '';
          // Consider it an auto watering entry if type/source mentions 'auto'
          if (type.contains('auto') || source.contains('auto')) {
            return {
              'lastAutoWateredAt': e['timestamp']?.toString() ?? '-',
              'lastAutoDuration': e['duration']?.toString() ?? '-',
            };
          }
        }

        // If no explicit auto-tagged entry found, try to find last entry where motorState was true
        for (final e in entries) {
          if (e['motorState'] == true || e['motorState']?.toString() == 'true') {
            return {
              'lastAutoWateredAt': e['timestamp']?.toString() ?? '-',
              'lastAutoDuration': e['duration']?.toString() ?? '-',
            };
          }
        }
      }

      return {'lastAutoWateredAt': '-', 'lastAutoDuration': '-'};
    } catch (e) {
      print('DatabaseService.getLastAutoWatering - Error: $e');
      return {'lastAutoWateredAt': '-', 'lastAutoDuration': '-'};
    }
  }
}