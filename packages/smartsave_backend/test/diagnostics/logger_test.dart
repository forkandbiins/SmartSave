import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/src/diagnostics/logger.dart';

void main() {
  test('redacts privileged protocol PINs', () {
    expect(redactPin('AUTH:1234'), 'AUTH:****');
    expect(redactPin('UNLOCK:1234,500'), 'UNLOCK:****,500');
    expect(redactPin('ADJ:1234,90'), 'ADJ:****,90');
    expect(redactPin('SETPIN:1234'), 'SETPIN:****');
    expect(redactPin('SETPIN:1234,5678'), 'SETPIN:****,****');
    expect(redactPin('TOTAL:500'), 'TOTAL:500');
  });
}
