import 'package:caremate_app/models/emergency_contact.dart';
import 'package:caremate_app/models/medication.dart';
import 'package:caremate_app/screens/settings_screen.dart';
import 'package:caremate_app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeApi extends ApiService {
  final meds = <Medication>[
    const Medication(
      id: '1',
      name: 'Blood pressure tablets',
      times: ['08:00', '20:00'],
      instructions: 'After meals',
    ),
  ];
  List<EmergencyContact> contacts = [
    const EmergencyContact(
      name: 'Chan Tai Man',
      phone: '+852 9123 4567',
      relation: 'Son',
    ),
  ];
  Medication? saved;

  @override
  Future<List<Medication>> listMedications() async => meds;
  @override
  Future<List<EmergencyContact>> listContacts() async => contacts;
  @override
  Future<Medication> saveMedication(Medication med) async {
    saved = med;
    meds.add(med);
    return med;
  }

  @override
  Future<void> saveContacts(List<EmergencyContact> c) async => contacts = c;
}

Widget wrap(Widget child) => MaterialApp(
  builder: (context, w) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(1.35)),
    child: w!,
  ),
  home: child,
);

void main() {
  testWidgets(
    'Settings shows medications and contacts without overflow (small phone, 1.35x text)',
    (tester) async {
      tester.view.physicalSize = const Size(375 * 3, 667 * 3); // iPhone SE 大小
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(SettingsScreen(api: FakeApi())));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Medications'), findsOneWidget);
      expect(find.text('Blood pressure tablets'), findsOneWidget);
      expect(find.textContaining('08:00'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Chan Tai Man'), 200);
      expect(find.text('Chan Tai Man'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Add Contact'), 200);
      expect(find.text('Add Contact'), findsOneWidget);
    },
  );

  testWidgets('Add medication requires name and time', (tester) async {
    tester.view.physicalSize = const Size(375 * 3, 667 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final api = FakeApi();

    await tester.pumpWidget(wrap(SettingsScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Medication'));
    await tester.pumpAndSettle();
    expect(find.text('Add Medication'), findsOneWidget); // 新頁標題

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Please enter the medicine name'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Vitamin D');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Please add at least one time'), findsOneWidget);
    expect(api.saved, isNull);
  });
}
