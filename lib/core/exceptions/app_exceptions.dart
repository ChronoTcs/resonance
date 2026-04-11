class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, [this.code]);

  @override
  String toString() => 'AppException: [$code] $message';
}

class StorageException extends AppException {
  StorageException(super.message, [super.code]);
}

class NetworkException extends AppException {
  NetworkException(super.message, [super.code]);
}

class PlayerException extends AppException {
  PlayerException(super.message, [super.code]);
}
