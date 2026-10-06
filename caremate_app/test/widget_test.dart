import 'package:caremate_app/models/emergency_contact.dart';
import 'package:caremate_app/models/medication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Medication JSON round trip', () {
    final med = Medication.fromJson({
      'id': 'abc',
      'name': 'Blood pressure',
      'times': ['08:00', '20:00'],
      'instructions': 'After meals',
    });
    expect(med.id, 'abc');
    expect(med.times, ['08:00', '20:00']);
    expect(med.toJson(), {
      'name': 'Blood pressure',
      'times': ['08:00', '20:00'],
      'instructions': 'After meals',
    });
  });

  test('EmergencyContact JSON round trip', () {
    final c = EmergencyContact.fromJson({
      'name': 'Ming',
      'phone': '+852 9123 4567',
    });
    expect(c.relation, '');
    expect(c.toJson()['phone'], '+852 9123 4567');
  });
}
