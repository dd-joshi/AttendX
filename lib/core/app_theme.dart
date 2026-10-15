import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF5F5F7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSecondary = Color(0xFFF2F2F7);

  static const primary = Color(0xFF0066CC);
  static const primaryPressed = Color(0xFF0052A3);
  static const primarySoft = Color(0xFFEAF0F5);

  static const textPrimary = Color(0xFF1D1D1F);
  static const textSecondary = Color(0xFF62666D);
  static const textDisabled = Color(0xFF8E8E93);
  static const divider = Color(0xFFE1E5E9);
  static const inputOutline = Color(0xFF7A8490);

  // Attendance meanings only: calm green register, solid red absences.
  static const presentBackground = Color(0xFFC9E3D2);
  static const presentPressedBackground = Color(0xFFB0D4BE);
  static const present = Color(0xFF216844);
  static const absent = Color(0xFFC43B35);
  static const absentPressed = Color(0xFFA92A22);
  static const errorSoft = Color(0xFFFCECEB);

  static const lab = Color(0xFFB45309);
  static const labSoft = Color(0xFFFFF4E5);
}

abstract final class AppTheme {
  static ThemeData light() {
    final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.primarySoft,
          onPrimaryContainer: AppColors.primaryPressed,
          secondary: AppColors.primary,
          onSecondary: Colors.white,
          secondaryContainer: AppColors.primarySoft,
          onSecondaryContainer: AppColors.primaryPressed,
          error: AppColors.absent,
          onError: Colors.white,
          errorContainer: AppColors.errorSoft,
          onErrorContainer: AppColors.absentPressed,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          surfaceDim: AppColors.surfaceSecondary,
          surfaceBright: AppColors.surface,
          surfaceContainerLowest: AppColors.surface,
          surfaceContainerLow: AppColors.background,
          surfaceContainer: AppColors.surfaceSecondary,
          surfaceContainerHigh: AppColors.surfaceSecondary,
          surfaceContainerHighest: AppColors.surfaceSecondary,
          onSurfaceVariant: AppColors.textSecondary,
          outline: AppColors.inputOutline,
          outlineVariant: AppColors.divider,
          shadow: Colors.black,
          scrim: Colors.black,
          surfaceTint: Colors.transparent,
        );

    final textTheme = base.textTheme
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        )
        .copyWith(
          headlineSmall: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          titleLarge: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            height: 1.25,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          titleMedium: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          titleSmall: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w400,
          ),
          bodySmall: const TextStyle(
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
          labelLarge: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            height: 1.2,
            fontWeight: FontWeight.w500,
          ),
        );

    const fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.inputOutline),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: AppColors.divider),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        disabledBorder: fieldBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.absent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.absent, width: 1.5),
        ),
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        helperStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        floatingLabelStyle: TextStyle(color: AppColors.primary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.divider;
            }
            if (states.contains(WidgetState.pressed)) {
              return AppColors.primaryPressed;
            }
            return AppColors.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? AppColors.textDisabled
                : Colors.white;
          }),
        ),
      ),
      outlinedButtonTheme: const OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(64, 48)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: AppColors.inputOutline),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
          foregroundColor: WidgetStatePropertyAll(AppColors.primary),
          textStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      textButtonTheme: const TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          foregroundColor: WidgetStatePropertyAll(AppColors.primary),
          textStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          foregroundColor: WidgetStatePropertyAll(AppColors.textPrimary),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 1,
        shape: StadiumBorder(),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 10,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        modalBarrierColor: Color(0x52000000),
        showDragHandle: true,
        dragHandleColor: AppColors.inputOutline,
        dragHandleSize: Size(36, 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }
}
