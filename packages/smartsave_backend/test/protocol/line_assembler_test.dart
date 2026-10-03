import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave_backend/src/protocol/line_assembler.dart';

void main() {
  test('assembles split and multiple lines', () {
    final assembler = LineAssembler();
    expect(assembler.addString('COIN:5,'), isEmpty);
    expect(assembler.addString('1\nTOTAL:5\n'), ['COIN:5,1', 'TOTAL:5']);
    expect(assembler.addString('PONG\nSYNC:END\n'), ['PONG', 'SYNC:END']);
  });

  test('ignores carriage returns and empty lines', () {
    final assembler = LineAssembler();
    expect(assembler.addString('\r\nTOTAL:5\r\n\r\n'), ['TOTAL:5']);
  });

  test('drops an overlong line and continues', () {
    final assembler = LineAssembler(maxLineLength: 64);
    final lines = assembler.addString('${'x' * 200}\nTOTAL:5\n');
    expect(lines, ['TOTAL:5']);
    expect(assembler.droppedLines, 1);
  });

  test('decodes byte chunks', () {
    final assembler = LineAssembler();
    expect(assembler.addBytes('PONG\n'.codeUnits), ['PONG']);
  });

  test('reset discards a partial line', () {
    final assembler = LineAssembler();
    assembler.addString('TOTAL:');
    assembler.reset();
    expect(assembler.addString('5\n'), ['5']);
  });
}
