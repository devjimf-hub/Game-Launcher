import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

class PinVerificationDialog extends StatelessWidget {
  final String correctPin;
  final VoidCallback? onCancelled;
  final ValueChanged<bool>? onResult;

  const PinVerificationDialog({
    super.key,
    required this.correctPin,
    this.onCancelled,
    this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    // Avoid creating controller inside build if possible, but for simplicity here it's fine as long as stateless
    final controller = TextEditingController();

    return AlertDialog(
      backgroundColor: const Color(0xFF0D0D0D),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFF00D4FF), width: 1),
        borderRadius: BorderRadius.circular(0),
      ),
      title: const Text('AUTHENTICATION REQUIRED',
          style: TextStyle(
              color: Color(0xFF00D4FF),
              fontWeight: FontWeight.bold,
              letterSpacing: 2)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter access key to continue',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 24),
          Pinput(
            controller: controller,
            length: correctPin.length,
            obscureText: true,
            autofocus: true,
            defaultPinTheme: PinTheme(
              width: 56,
              height: 56,
              textStyle: const TextStyle(
                fontSize: 20,
                color: Color(0xFF9D4EDD),
                fontWeight: FontWeight.w600,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF333333)),
                borderRadius: BorderRadius.circular(0),
                color: const Color(0xFF1A1A1A),
              ),
            ),
            focusedPinTheme: PinTheme(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00D4FF)),
                borderRadius: BorderRadius.circular(0),
                color: const Color(0xFF1A1A1A),
              ),
            ),
            onCompleted: (pin) {
              if (pin == correctPin) {
                Navigator.pop(context, true);
                onResult?.call(true);
              } else {
                controller.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('INVALID ACCESS KEY'),
                      backgroundColor: Colors.red),
                );
                onResult?.call(false);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context, false);
            onCancelled?.call();
            onResult?.call(false);
          },
          child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
