import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/themes/colors.dart';
import '../validators.dart';

/// The 6-digit code, drawn as six boxes as in Claude Design.
///
/// One invisible [TextField] takes the input (so paste and the SMS/e-mail
/// autofill work); the boxes only show its digits.
class CodeField extends StatelessWidget {
  const CodeField({
    super.key,
    required this.controller,
    this.errorText,
    this.enabled = true,
    this.onCompleted,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool enabled;

  /// Called when the sixth digit is typed.
  final ValueChanged<String>? onCompleted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, value, _) =>
                  _Boxes(digits: value.text, hasError: errorText != null),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(codeLength),
                  ],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  onChanged: (code) {
                    if (code.length == codeLength) onCompleted?.call(code);
                  },
                ),
              ),
            ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: const TextStyle(fontSize: 13, color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}

class _Boxes extends StatelessWidget {
  const _Boxes({required this.digits, required this.hasError});

  final String digits;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Código de 6 dígitos',
      value: digits,
      excludeSemantics: true,
      child: Row(
        children: [
          for (var index = 0; index < codeLength; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    width: 1.5,
                    color: hasError
                        ? AppColors.danger
                        : index == digits.length
                        ? AppColors.forest
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  index < digits.length ? digits[index] : '',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
