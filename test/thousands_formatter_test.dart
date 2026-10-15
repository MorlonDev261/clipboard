import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:influencor/core/widgets/app_inputs.dart';

TextEditingValue _type(String text, int caret) {
  return const ThousandsFormatter().formatEditUpdate(
    const TextEditingValue(),
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    ),
  );
}

void main() {
  test('groups by thousands', () {
    expect(_type('1250000', 7).text, '1 250 000');
    expect(_type('1000000000', 10).text, '1 000 000 000');
    expect(_type('12', 2).text, '12');
    expect(_type('', 0).text, '');
  });

  test('ignores non digits and caps at 15 digits', () {
    expect(_type('1a2b3', 5).text, '123');
    expect(_type('1234567890123456789', 19).text.replaceAll(' ', ''),
        '123456789012345');
  });

  test('caret stays after the typed digit, not at the end', () {
    // "1 250 000" with a digit inserted after "1" -> caret right after it.
    final v = _type('19 250 000', 2);
    expect(v.text, '19 250 000');
    expect(v.selection.baseOffset, 2);
    // Typing at the very end keeps the caret at the end.
    final end = _type('1 250 0001', 10);
    expect(end.selection.baseOffset, end.text.length);
  });

  test('parse ignores any kind of space', () {
    expect(AppAmountField.parse('1 250\u00A0000'), 1250000);
    expect(AppAmountField.parse(''), isNull);
  });
}
