import 'package:flutter_test/flutter_test.dart';

import 'package:easel_app/main.dart';

void main() {
  testWidgets('Easel app boots shell', (tester) async {
    await tester.pumpWidget(const EaselApp());
    await tester.pump();
    expect(find.textContaining('sidecar'), findsWidgets);
  });
}
