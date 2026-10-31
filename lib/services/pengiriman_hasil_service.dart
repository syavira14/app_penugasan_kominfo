import 'dart:async';

/// Batasi setiap tahap pengiriman agar UI selalu menerima hasil atau error.
Future<T> runSubmissionStep<T>(
  Future<T> Function() operation, {
  required String timeoutMessage,
  required Duration timeout,
  void Function()? onTimeout,
}) {
  return Future<T>.sync(operation).timeout(
    timeout,
    onTimeout: () {
      onTimeout?.call();
      throw TimeoutException(timeoutMessage, timeout);
    },
  );
}
