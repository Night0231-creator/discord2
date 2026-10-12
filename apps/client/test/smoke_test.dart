import 'package:flutter_test/flutter_test.dart';
import 'package:veylor/main.dart';
void main(){
  testWidgets('renders login screen',(tester) async {
    await tester.pumpWidget(const VeylorApp());
    expect(find.text('Bem-vindo ao Veylor'),findsOneWidget);
  });
}
