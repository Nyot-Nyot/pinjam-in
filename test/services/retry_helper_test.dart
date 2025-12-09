import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/services/retry_helper.dart';

void main() {
  test('retry returns result on first attempt', () async {
    final result = await retry(() async => 'ok', attempts: 3);
    expect(result, 'ok');
  });

  test('retry retries on failure and succeeds', () async {
    var calls = 0;
    final result = await retry(
      () async {
        calls++;
        if (calls < 3) throw Exception('fail');
        return 'done';
      },
      attempts: 4,
      initialDelay: const Duration(milliseconds: 1),
    );

    expect(result, 'done');
    expect(calls, 3);
  });

  test('retry rethrows after attempts exhausted', () async {
    var calls = 0;
    final future = retry(
      () async {
        calls++;
        throw Exception('always');
      },
      attempts: 2,
      initialDelay: const Duration(milliseconds: 1),
    );
    await expectLater(future, throwsException);
    expect(calls, 2);
  });
}
