import 'package:flutter_test/flutter_test.dart';
import 'package:accounting_system/core/fixed.dart';

void main(){
  test('exact money and quantities including Arabic digits',(){
    expect(parseFixed('12.34',2),1234);
    expect(parseFixed('١٢٫٣٤',2),1234);
    expect(parseFixed('0.001',3),1);
    expect(formatFixed(-1234),'-12.34');
    expect(()=>parseFixed('0.001',2),throwsFormatException);
    expect(()=>parseFixed('-1',2),throwsFormatException);
  });
}
