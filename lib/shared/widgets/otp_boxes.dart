import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// Deret kotak digit OTP dengan satu [TextField] tersembunyi sebagai input.
/// Dipakai bersama oleh layar verifikasi OTP (register) dan reset password.
class OtpBoxes extends StatelessWidget {
  const OtpBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onCompleted,
    required this.onChanged,
    this.length = 6,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final code = controller.text;
    return Stack(
      children: [
        // Input tak terlihat namun menangkap ketikan & keyboard.
        Opacity(
          opacity: 0,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: length,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(length),
            ],
            onChanged: (v) {
              onChanged(v);
              if (v.length == length) onCompleted(v);
            },
          ),
        ),
        GestureDetector(
          onTap: () => focusNode.requestFocus(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(length, (i) {
              final filled = i < code.length;
              final isActive = i == code.length;
              return Container(
                width: 48,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? AppColors.amber
                        : filled
                            ? AppColors.espresso
                            : AppColors.border,
                    width: isActive ? 1.8 : 1,
                  ),
                ),
                child: Text(filled ? code[i] : '',
                    style: AppTextStyles.displaySmall),
              );
            }),
          ),
        ),
      ],
    );
  }
}
