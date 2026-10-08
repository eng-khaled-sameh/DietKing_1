class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

String mapError(Object error) {
  if (error is AppException) return error.message;
  final original = error.toString();
  const branchMessages = [
    'حسابك غير مفعّل',
    'حسابك غير مرتبط بفرع',
    'هذا الحساب غير مصرح له بالعمل على هذا الفرع',
    'الفرع المرتبط بحسابك غير نشط، تواصل مع الإدارة',
  ];
  for (final message in branchMessages) {
    if (original.contains(message)) return message;
  }
  final text = original.toLowerCase();
  if (text.contains('socket') || text.contains('network') ||
      text.contains('connection') || text.contains('host')) {
    return 'تعذر الاتصال بالإنترنت';
  }
  return 'حدث خطأ غير متوقع، حاول مرة أخرى';
}
