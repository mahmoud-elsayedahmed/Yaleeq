/// Sealed hierarchy of domain-level failures.
///
/// Every repository method returns [Result] which wraps either success data
/// or one of these typed failures — raw exceptions never reach the UI.
sealed class Failure {
  const Failure(this.message);
  final String message;
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});
  final int? statusCode;
}

final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'Could not connect to server. Check your connection.',
  ]);
}

final class CancelledFailure extends Failure {
  const CancelledFailure([super.message = 'Request was cancelled']);
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'An unexpected error occurred']);
}
