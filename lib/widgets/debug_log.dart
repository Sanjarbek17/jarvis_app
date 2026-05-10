import 'package:flutter/material.dart';
import '../services/log_service.dart';

class DebugLog extends StatelessWidget {
  final ScrollController scrollController;

  const DebugLog({
    super.key,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DEBUG LOG',
                style: TextStyle(fontSize: 12, letterSpacing: 2, color: Colors.blue, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white38),
                onPressed: () => logger.clear(),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: logger.logs,
              builder: (context, logs, child) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (scrollController.hasClients) {
                    scrollController.animateTo(
                      scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: scrollController,
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        logs[index],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
