class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

String mapError(Object error) {
  if (error is AppException) return error.message;
  final text = error.toString().toLowerCase();
  if (text.contains('socket') || text.contains('network') ||
      text.contains('connection') || text.contains('host')) {
    return 'تعذر الاتصال بالإنترنت';
  }
  return 'حدث خطأ غير متوقع، حاول مرة أخرى';
}
