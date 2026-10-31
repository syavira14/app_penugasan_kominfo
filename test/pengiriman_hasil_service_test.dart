import 'dart:async';

import 'package:app_penugasan_kominfo/services/pengiriman_hasil_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Tahap yang macet berhenti menunggu dan membatalkan unggahan', () async {
    final pendingUpload = Completer<String>();
    var cancelled = false;
    var saved = false;
    final result =
        runSubmissionStep(
          () => pendingUpload.future,
          timeoutMessage: 'Unggahan terlalu lama.',
          timeout: const Duration(milliseconds: 10),
          onTimeout: () => cancelled = true,
        ).then((url) {
          saved = true;
          return url;
        });
    await expectLater(result, throwsA(isA<TimeoutException>()));
    expect(cancelled, isTrue);
    expect(saved, isFalse);
    // Penyelesaian operasi lama tidak boleh meneruskan penyimpanan status.
    pendingUpload.complete('late-file-url');
    await Future<void>.delayed(Duration.zero);
    expect(saved, isFalse);
  });

  test('Error Firebase diteruskan tanpa menunggu batas waktu', () async {
    final failure = StateError('storage/unauthorized');
    await expectLater(
      runSubmissionStep<String>(
        () => Future.error(failure),
        timeoutMessage: 'Timeout',
        timeout: const Duration(seconds: 1),
      ),
      throwsA(same(failure)),
    );
  });

  test('Unggahan berhasil diteruskan untuk penyimpanan status', () async {
    var cancelled = false;
    final url = await runSubmissionStep(
      () async => 'file-url',
      timeoutMessage: 'Timeout',
      timeout: const Duration(seconds: 1),
      onTimeout: () => cancelled = true,
    );
    expect(url, 'file-url');
    expect(cancelled, isFalse);
  });
}
