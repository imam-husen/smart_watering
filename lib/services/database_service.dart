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
          (value as Map).forEach((k, v) => result[k.toString()] = v);
          return result;
        }
      }
      return <String, dynamic>{};
    });
  }

  /// Set motorState (true = ON, false = OFF).
  /// Returns true if write succeeded, false otherwise.
  Future<bool> setMotorState(bool motorOn) async {
    final String isoTime = DateTime.now().toIso8601String();
    try {
      // Update status node
      await _statusRef.update({
        'motorState': motorOn,
        'updatedAt': isoTime,
      });

      // Add history entry (keyed by push())
      final historyData = {
        'motorState': motorOn,
        'timestamp': isoTime,
      };
      await _historyRef.push().set(historyData);

      return true;
    } on FirebaseException catch (e) {
      // log e.message if needed
      print('DatabaseService.setMotorState - FirebaseException: ${e.message}');
      return false;
    } catch (e) {
      print('DatabaseService.setMotorState - Unknown error: $e');
      return false;
    }
  }
}