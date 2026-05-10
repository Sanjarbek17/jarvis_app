import 'package:flutter/material.dart';
import '../services/wake_word_service.dart';

class TranscriptionArea extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final WakeState wakeState;
  final String lastWords;
  final String aiStatus;
  final VoidCallback onToggleMic;

  const TranscriptionArea({
    super.key,
    required this.pulseAnimation,
    required this.wakeState,
    required this.lastWords,
    required this.aiStatus,
    required this.onToggleMic,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: pulseAnimation,
          builder: (context, child) {
            return Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  if (wakeState != WakeState.idle)
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 20 * pulseAnimation.value,
                      spreadRadius: 10 * pulseAnimation.value,
                    ),
                ],
              ),
              child: ElevatedButton(
                onPressed: onToggleMic,
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                  backgroundColor: wakeState != WakeState.idle ? Colors.blue.shade600 : Colors.white10,
                  foregroundColor: Colors.white,
                ),
                child: Icon(
                  wakeState != WakeState.idle ? Icons.mic : Icons.mic_none,
                  size: 30,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 15),
        Text(
          lastWords,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Status: $aiStatus',
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue.shade300,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
