import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/database.dart';
import '../../repositories/firearm_repository.dart';
import 'firearm_form_screen.dart';

class FirearmsListScreen extends StatelessWidget {
  const FirearmsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<FirearmRepository>();
    return Scaffold(
      body: StreamBuilder<List<UserFirearmRow>>(
        stream: repo.watchAll(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final firearms = snap.data ?? const <UserFirearmRow>[];
          if (firearms.isEmpty) {
            return const Center(
              child: Text('No firearms yet. Tap + to add your first.'),
            );
          }
          return ListView.separated(
            itemCount: firearms.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final f = firearms[i];
              final subtitle = [
                if (f.model != null) f.model,
                if (f.caliber != null) f.caliber,
              ].whereType<String>().join(' · ');
              return Dismissible(
                key: ValueKey('firearm_${f.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(Icons.delete),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete This Firearm?'),
                          content: Text('"${f.name}" will be removed.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton.tonal(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                },
                onDismissed: (_) => repo.delete(f.id),
                child: ListTile(
                  title: Text(f.name),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${f.shotsFired} shots',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FirearmFormScreen(existing: f),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FirearmFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
