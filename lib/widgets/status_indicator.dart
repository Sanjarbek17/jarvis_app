import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onRequest;

  const StatusIndicator({
    super.key,
    required this.isEnabled,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isEnabled ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEnabled ? Colors.green.shade400 : Colors.red.shade400,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEnabled ? Icons.check_circle : Icons.warning,
                size: 14,
                color: isEnabled ? Colors.green.shade400 : Colors.red.shade400,
              ),
              const SizedBox(width: 6),
              const Text(
                'Access',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!isEnabled)
          GestureDetector(
            onTap: onRequest,
            child: const Padding(
              padding: EdgeInsets.only(top: 4.0),
              child: Text(
                'ENABLE NOW',
                style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
