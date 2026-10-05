import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/core/utils/person_name.dart';

void main() {
  test('rejects names with no letters', () {
    expect(isValidPersonName('878320'), isFalse);
    expect(isValidPersonName('  '), isFalse);
    expect(isValidPersonName('123-456'), isFalse);
  });

  test('accepts names in any script', () {
    expect(isValidPersonName('Sathiya'), isTrue);
    expect(isValidPersonName('சத்யா'), isTrue);
    expect(isValidPersonName('Ravi 2'), isTrue);
  });
}
