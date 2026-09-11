import 'package:flutter/services.dart';

String normalizeKazakhstanPhone(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');

  // Accept pasted international (+7...) and national (8...) forms while the
  // visible field itself always keeps +7 outside the editable text.
  if (digits.length == 11 &&
      (digits.startsWith('7') || digits.startsWith('8'))) {
    digits = digits.substring(1);
  }

  if (digits.length != 10 || !digits.startsWith('7')) return '';
  return '+7$digits';
}

class KazakhstanPhoneInputFormatter extends TextInputFormatter {
  const KazakhstanPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.length > 10 &&
        (digits.startsWith('7') || digits.startsWith('8'))) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
