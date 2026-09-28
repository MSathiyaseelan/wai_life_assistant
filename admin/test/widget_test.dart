import 'package:flutter_test/flutter_test.dart';
import 'package:wai_admin/widgets/common.dart';

void main() {
  test('fmtNum formats Indian grouping', () {
    expect(fmtNum(1234567), '12,34,567');
    expect(fmtNum(null), '—');
  });

  test('fmtAgo', () {
    expect(fmtAgo(null), '—');
    expect(fmtAgo(DateTime.now().subtract(const Duration(hours: 3)).toIso8601String()), '3h ago');
    expect(fmtAgo(DateTime.now().subtract(const Duration(days: 2)).toIso8601String()), '2d ago');
  });
}
