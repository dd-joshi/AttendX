import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';

/// Shared date label used across screens, e.g. "Mon 12 Oct 2026".
/// The year is dropped for the current year to keep labels short: "Mon 12 Oct".
String formatAppDate(DateTime date, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  return date.year == reference.year
      ? DateFormat('EEE d MMM').format(date)
      : DateFormat('EEE d MMM yyyy').format(date);
}

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding,
    this.color = AppColors.surface,
    this.radius = 14,
    this.showBorder = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color color;
  final double radius;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: showBorder
            ? const BorderSide(color: AppColors.divider)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.onPressed,
    required this.child,
  });

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: AppColors.surface,
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(onPressed: onPressed, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class WeekdaySelector extends StatelessWidget {
  const WeekdaySelector({
    super.key,
    required this.selectedDays,
    required this.onChanged,
    this.enabled = true,
  });

  static const _shortLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
  static const _fullLabels = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final List<int> selectedDays;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(7, (index) {
        final selected = selectedDays.contains(index);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 6 ? 0 : 4),
            child: Semantics(
              button: true,
              selected: selected,
              enabled: enabled,
              label: _fullLabels[index],
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: enabled ? () => onChanged(index) : null,
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _shortLabels[index],
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : (enabled
                                  ? AppColors.textPrimary
                                  : AppColors.textDisabled),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class InlineMessage extends StatelessWidget {
  const InlineMessage({super.key, required this.child, this.isError = false});

  final Widget child;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? AppColors.errorSoft : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: isError ? AppColors.absentPressed : AppColors.primaryPressed,
          fontSize: 13,
          height: 1.35,
        ),
        child: child,
      ),
    );
  }
}
