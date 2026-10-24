import 'package:ace_mail_web/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders AceMail web sign-in screen', (tester) async {
    await tester.pumpWidget(const AceMailWebApp());
    await tester.pumpAndSettle();
    expect(find.text('AceMail'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
