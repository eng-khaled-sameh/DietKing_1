import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../core/supabase_config.dart';

/// خدمة المصادقة — تتعامل مع Supabase Auth
class AuthService {
  /// تسجيل الدخول باسم المستخدم وكلمة المرور.
  ///
  /// إذا كان [username] يحتوي على @ يُستخدم كإيميل مباشرة،
  /// وإلا يُضاف إليه نطاق [SupabaseConfig.emailDomain].
  Future<void> signIn(String username, String password) async {
    final trimmed = username.trim().toLowerCase();
    final email = trimmed.contains('@')
        ? trimmed
        : '$trimmed@${SupabaseConfig.emailDomain}';

    try {
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid credentials') ||
          e.statusCode == '400') {
        throw Exception('اسم المستخدم أو كلمة المرور غير صحيحة');
      }
      throw Exception('حدث خطأ غير متوقع، حاول مرة أخرى');
    } on SocketException {
      throw Exception('تعذر الاتصال بالإنترنت، حاول مرة أخرى');
    } on HttpException {
      throw Exception('تعذر الاتصال بالإنترنت، حاول مرة أخرى');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') ||
          msg.contains('network') ||
          msg.contains('connection') ||
          msg.contains('host')) {
        throw Exception('تعذر الاتصال بالإنترنت، حاول مرة أخرى');
      }
      throw Exception('حدث خطأ غير متوقع، حاول مرة أخرى');
    }
  }
}
