import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../services/action_executor_service.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'NAVIGATION HUB',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _CapsuleButton(
                  icon: Icons.arrow_back,
                  label: 'Back',
                  onTap: () => actionExecutorService.execute({'action': 'back'}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CapsuleButton(
                  icon: Icons.home_outlined,
                  label: 'Home',
                  onTap: () => actionExecutorService.execute({'action': 'home'}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CapsuleButton(
                  icon: Icons.layers_outlined,
                  label: 'Recents',
                  onTap: () => actionExecutorService.execute({'action': 'recents'}),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapsuleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CapsuleButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          splashColor: Colors.white.withValues(alpha: 0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- FLUTTER WIDGET PREVIEW ---
@Preview(name: 'Control Panel Preview')
Widget previewControlPanel() {
  return const Scaffold(
    backgroundColor: Color(0xFF0F172A),
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: ControlPanel(),
      ),
    ),
  );
}
