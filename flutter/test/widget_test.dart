import 'package:flutter_test/flutter_test.dart';

import 'package:unisyn/main.dart';

void main() {
  testWidgets('Unisyn app boots shell', (tester) async {
    await tester.pumpWidget(const EaselApp());
    await tester.pump();
    expect(find.textContaining('sidecar'), findsWidgets);
  });
}
