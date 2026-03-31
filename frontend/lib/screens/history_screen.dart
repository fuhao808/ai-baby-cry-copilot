import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/recording_flow_controller.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider(userId));
    final formatter = DateFormat('MMM d, h:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('Cry History')),
      body: historyAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(
              child: Text('No cry logs yet. Record your first sample.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final log = logs[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    '${log.predictedLabel} • ${(log.confidenceScore * 100).toStringAsFixed(0)}%',
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${formatter.format(log.timestamp)}\n'
                      'User feedback: ${log.actualLabelFromUser ?? 'Pending'}',
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('History failed: $error')),
      ),
    );
  }
}
