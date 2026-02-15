// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:alfoods_adminapp/app.dart';
import 'package:alfoods_adminapp/core/api_client.dart';
import 'package:alfoods_adminapp/core/storage.dart';
import 'package:alfoods_adminapp/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    final storage = await Storage.init();
    final apiClient = ApiClient(storage);
    final apiService = ApiService(storage, apiClient);

    await tester.pumpWidget(App(
      storage: storage,
      apiService: apiService,
    ));

    // Initial route is /login — verify login screen is shown
    expect(find.text('Alfoods Касса'), findsOneWidget);
  });
}
