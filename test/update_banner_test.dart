import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:prodfos/core/services/update_service.dart';
import 'package:prodfos/core/widgets/update_banner.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('a newer version shows Update now / Later on a phone, and Later hides it', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final updates = UpdateService()..available = '1.0.42';
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: updates,
      child: const MaterialApp(home: UpdateBanner(child: Scaffold())),
    ));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('ProDFOS 1.0.42 is ready'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pump();
    expect(find.text('Update now'), findsNothing);
  });

  test('local builds (no build number) never look for updates', () {
    expect(UpdateService.supported, isFalse);
  });
}
