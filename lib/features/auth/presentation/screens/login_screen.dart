import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/supabase_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../cubits/branches/branches_cubit.dart';
import '../../../../cubits/catalog/catalog_cubit.dart';
import '../../../../cubits/session/session_cubit.dart';
import '../../../../models/login_branch.dart';
import '../../../../services/auth_service.dart';
import '../../../meal_sales/presentation/screens/meal_sales_screen.dart';
import '../widgets/login_card.dart';
import '../widgets/login_footer.dart';
import '../widgets/login_status_strip.dart';
import '../widgets/login_title_bar.dart';

// ── أسماء الورديات (بدون أوقات) ───────────────────────────────────────────────
abstract final class AppShifts {
  static const String morning = 'الوردية الصباحية';
  static const String evening = 'الوردية المسائية';
  static const String night = 'الوردية الليلية';

  static const List<String> all = [morning, evening, night];
}

/// شاشة تسجيل دخول الكاشير الرئيسية — دايت كنج POS
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── Controllers ──────────────────────────────────────────────────────────────
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // ── Focus Nodes ──────────────────────────────────────────────────────────────
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // ── State ────────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  String? _authError;

  // اختيارات الفرع والوردية
  LoginBranch? _selectedBranch;
  String? _selectedShift;

  // أخطاء التحقق
  String? _branchError;
  String? _shiftError;
  String? _usernameError;
  String? _passwordError;

  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // تحميل الفروع مرة واحدة عند فتح الشاشة (الكاش يمنع الطلب مجدداً)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BranchesCubit>().load();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Validation ───────────────────────────────────────────────────────────────
  bool _validate() {
    String? branchErr;
    String? shiftErr;
    String? usernameErr;
    String? passwordErr;

    if (_selectedBranch == null) {
      branchErr = 'اختر الفرع';
    }
    if (_selectedShift == null) {
      shiftErr = 'اختر الوردية';
    }
    if (_usernameController.text.trim().isEmpty) {
      usernameErr = 'اسم المستخدم مطلوب';
    }
    if (_passwordController.text.isEmpty) {
      passwordErr = 'كلمة المرور مطلوبة';
    }

    setState(() {
      _branchError = branchErr;
      _shiftError = shiftErr;
      _usernameError = usernameErr;
      _passwordError = passwordErr;
      _authError = null;
    });

    return branchErr == null &&
        shiftErr == null &&
        usernameErr == null &&
        passwordErr == null;
  }

  // ── Submit ───────────────────────────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    if (!_validate()) return;

    setState(() {
      _isLoading = true;
      _authError = null;
    });

    try {
      await _authService.signIn(
        _usernameController.text,
        _passwordController.text,
      );

      if (!mounted) return;

      // قراءة بيانات المستخدم من Supabase بعد تسجيل الدخول
      final user = supabase.auth.currentUser;
      final userId = user?.id ?? '';
      final email = user?.email ?? _usernameController.text.trim().toLowerCase();

      // بدء الجلسة — مرة واحدة فقط، ثابتة طوال الجلسة
      if (!mounted) return;
      context.read<SessionCubit>().start(
            branch: _selectedBranch!,
            shift: _selectedShift!,
            userId: userId,
            email: email,
          );

      // بدء تحميل الكاتالوج مرة واحدة عند بدء الجلسة
      if (!mounted) return;
      context.read<CatalogCubit>().load();

      // الانتقال لشاشة البيع — استبدال شاشة الدخول (ممنوع الرجوع بزر الرجوع)
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MealSalesScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _authError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // ── 1. خلفية متدرجة مع توهجات دائرية ──────────────────────────
            const _BackgroundGradient(),
            // ── 2. ترتيب الويدجتس الرئيسي ────────────────────────────────────
            Column(
              children: [
                // شريط العنوان العلوي
                const LoginTitleBar(),

                // شريط حالة النظام
                const LoginStatusStrip(),

                // بطاقة تسجيل الدخول
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                        vertical: AppDimens.spaceLg,
                      ),
                      child: LoginCard(
                        // ── اختيار الفرع ──
                        selectedBranch: _selectedBranch,
                        branchError: _branchError,
                        onBranchChanged: (branch) {
                          setState(() {
                            _selectedBranch = branch;
                            _branchError = null;
                          });
                        },
                        onBranchRetry: () =>
                            context.read<BranchesCubit>().load(force: true),
                        // ── اختيار الوردية ──
                        selectedShift: _selectedShift,
                        shiftError: _shiftError,
                        onShiftChanged: (shift) {
                          setState(() {
                            _selectedShift = shift;
                            _shiftError = null;
                          });
                        },
                        // ── حقول المستخدم ──
                        cashierController: _usernameController,
                        passwordController: _passwordController,
                        cashierFocusNode: _usernameFocus,
                        passwordFocusNode: _passwordFocus,
                        onSubmit: _handleSubmit,
                        isLoading: _isLoading,
                        errorMessage: _authError,
                        usernameError: _usernameError,
                        passwordError: _passwordError,
                      ),
                    ),
                  ),
                ),
                // فوتر الصفحة السفلي
                const LoginFooter(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// خلفية متدرجة شفافة
class _BackgroundGradient extends StatelessWidget {
  const _BackgroundGradient();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryContainer.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.tertiary.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
