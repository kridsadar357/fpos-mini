bool isAsciiDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

/// First run of ASCII digits, e.g. "Gasohol 95" → "95".
String? firstDigitSequence(String input) {
  final buffer = StringBuffer();
  var started = false;
  for (final code in input.codeUnits) {
    if (isAsciiDigit(code)) {
      buffer.writeCharCode(code);
      started = true;
    } else if (started) {
      break;
    }
  }
  final value = buffer.toString();
  return value.isEmpty ? null : value;
}

/// Matches legacy RegExp(r'(\d{2,3}|B\d+|E\d+)') for fuel short labels.
String? fuelShortToken(String name) {
  for (var i = 0; i < name.length; i++) {
    if (isAsciiDigit(name.codeUnitAt(i))) {
      var end = i;
      while (end < name.length && isAsciiDigit(name.codeUnitAt(end))) {
        end++;
      }
      final available = end - i;
      if (available >= 2) {
        final take = available >= 3 ? 3 : 2;
        return name.substring(i, i + take);
      }
      continue;
    }
    if (name[i] == 'B' || name[i] == 'E') {
      final buffer = StringBuffer(name[i]);
      var j = i + 1;
      while (j < name.length && isAsciiDigit(name.codeUnitAt(j))) {
        buffer.writeCharCode(name.codeUnitAt(j));
        j++;
      }
      if (buffer.length > 1) return buffer.toString();
    }
  }
  return null;
}
