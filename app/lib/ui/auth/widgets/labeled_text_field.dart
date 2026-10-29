import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';

/// A field of the entry screens: the bold [label] over a rounded box, and
/// under it the [errorText] (in red) or the [helperText].
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    this.helperText,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? helperText;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool enabled;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: 1.5),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          obscureText: obscureText,
          enabled: enabled,
          autocorrect:
              !obscureText && keyboardType != TextInputType.emailAddress,
          enableSuggestions: !obscureText,
          textCapitalization: textCapitalization,
          onSubmitted: onSubmitted,
          style: const TextStyle(fontSize: 16, color: AppColors.ink),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: _border(AppColors.border),
            enabledBorder: _border(AppColors.border),
            disabledBorder: _border(AppColors.divider),
            focusedBorder: _border(AppColors.forest),
            errorBorder: _border(AppColors.danger),
            focusedErrorBorder: _border(AppColors.danger),
            errorText: errorText,
            helperText: helperText,
            helperMaxLines: 2,
            errorMaxLines: 2,
            helperStyle: const TextStyle(
              fontSize: 12,
              color: AppColors.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}
