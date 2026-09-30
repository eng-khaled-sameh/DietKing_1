import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_colors.dart';
import 'core/cubits/held_orders_cubit.dart';
import 'features/auth/presentation/screens/login_screen.dart';

void main() {
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => HeldOrdersCubit()),
      ],
      child: const DietKingApp(),
    ),
  );
}

class DietKingApp extends StatelessWidget {
  const DietKingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دايت كنج POS — تسجيل دخول الكاشير',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.surface,
          primary: AppColors.primary,
          primaryContainer: AppColors.primaryContainer,
          tertiary: AppColors.tertiary,
          onSurface: AppColors.onSurface,
          outline: AppColors.outlineVariant,
        ),
        textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
