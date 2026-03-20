sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;
  @override
  String toString() => message;
}

final class AuthException extends AppException {
  const AuthException(super.message);
}

final class NetworkException extends AppException {
  const NetworkException(super.message);
}

final class StorageException extends AppException {
  const StorageException(super.message);
}

final class ParseException extends AppException {
  const ParseException(super.message);
}

final class NotFoundException extends AppException {
  const NotFoundException(super.message);
}
