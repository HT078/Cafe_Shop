import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('app shows home screen content', (tester) async {
    await tester.pumpWidget(const HaiTinApp());

    expect(find.text('Cà Phê Hải Tín'), findsOneWidget);
    expect(find.text('Phượng Hoàng Lửa'), findsOneWidget);
    expect(find.text('Danh Mục Nhanh'), findsOneWidget);
  });
}
