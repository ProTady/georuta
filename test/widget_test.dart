import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:geo_ruta/app.dart';

void main() {
  testWidgets('GeoRutaApp renders without crashing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GeoRutaApp()));
    expect(find.byType(GeoRutaApp), findsOneWidget);
  });
}
