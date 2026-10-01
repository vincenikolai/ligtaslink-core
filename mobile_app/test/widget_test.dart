import 'package:flutter_test/flutter_test.dart';
import 'package:ligtaslink_mobile/main.dart';

void main() {
  testWidgets('LigtasLink home renders emergency services', (tester) async {
    await tester.pumpWidget(const LigtasLinkApp());
    expect(find.text('Quick relief service'), findsOneWidget);
    expect(find.text('Household verification'), findsOneWidget);
  });
}
