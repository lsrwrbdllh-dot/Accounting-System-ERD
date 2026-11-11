// Exact decimal input/output. No double is used for money or quantities.
int parseFixed(String input, int places) {
  var value = input.trim();
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < 10; i++) {
    value = value.replaceAll(arabic[i], '$i');
  }
  value = value.replaceAll('٫', '.');
  if (!RegExp('^\\d+(?:\\.\\d{1,$places})?\$').hasMatch(value)) {
    throw FormatException('أدخل عددًا موجبًا بدقة $places منازل كحد أقصى');
  }
  final parts = value.split('.');
  var scale = 1;
  for (var i = 0; i < places; i++) { scale *= 10; }
  final result = int.parse(parts[0]) * scale +
      int.parse(parts.length == 2 ? parts[1].padRight(places, '0') : '0');
  if (result > 1000000000) { throw const FormatException('القيمة تتجاوز الحد المسموح'); }
  return result;
}

String formatFixed(int value, [int places = 2]) {
  var scale = 1;
  for (var i = 0; i < places; i++) { scale *= 10; }
  final absolute = value.abs();
  return '${value < 0 ? '-' : ''}${absolute ~/ scale}.${(absolute % scale).toString().padLeft(places, '0')}';
}

String today() => DateTime.now().toIso8601String().substring(0, 10);
