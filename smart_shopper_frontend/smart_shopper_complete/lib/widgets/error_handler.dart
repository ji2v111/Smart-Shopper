import 'package:flutter/material.dart';
import '../theme.dart';

class Err {
  static void show(BuildContext context, dynamic msg, {bool isSuccess = false}) {
    if (!context.mounted) return;
    final text = msg is String ? msg : msg.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
            color: Colors.white, size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ]),
        backgroundColor: isSuccess ? AppTheme.primary : const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
