import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'status_indicator.dart';

class AppHeader extends StatelessWidget {
  final bool isAccessibilityEnabled;
  final bool isRemoteConnected;
  final VoidCallback onRequestAccessibility;
  final VoidCallback onRequestRemote;

  const AppHeader({
    super.key,
    required this.isAccessibilityEnabled,
    required this.isRemoteConnected,
    required this.onRequestAccessibility,
    required this.onRequestRemote,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PHONE CONTROLLER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.5,
                    color: Colors.blue.shade400,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Remote Control',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusIndicator(
                isEnabled: isAccessibilityEnabled,
                onRequest: onRequestAccessibility,
              ),
              const SizedBox(width: 8),
              StatusIndicator(
                isEnabled: isRemoteConnected,
                onRequest: onRequestRemote,
                label: 'Remote',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- FLUTTER WIDGET PREVIEW ---
@Preview(name: 'App Header - Connected State')
Widget previewAppHeaderConnected() {
  return Scaffold(
    backgroundColor: const Color(0xFF0F172A),
    body: SafeArea(
      child: AppHeader(
        isAccessibilityEnabled: true,
        isRemoteConnected: true,
        onRequestAccessibility: () {},
        onRequestRemote: () {},
      ),
    ),
  );
}

@Preview(name: 'App Header - Disconnected State')
Widget previewAppHeaderDisconnected() {
  return Scaffold(
    backgroundColor: const Color(0xFF0F172A),
    body: SafeArea(
      child: AppHeader(
        isAccessibilityEnabled: false,
        isRemoteConnected: false,
        onRequestAccessibility: () {},
        onRequestRemote: () {},
      ),
    ),
  );
}
