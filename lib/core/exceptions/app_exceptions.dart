class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, [this.code]);

  @override
  String toString() => 'AppException: [$code] $message';
}

class StorageException extends AppException {
  StorageException(String message, [String? code]) : super(message, code);
}

class NetworkException extends AppException {
  NetworkException(String message, [String? code]) : super(message, code);
}

class PlayerException extends AppException {
  PlayerException(String message, [String? code]) : super(message, code);
}
