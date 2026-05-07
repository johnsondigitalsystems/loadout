import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/database.dart';
import '../../repositories/recipe_repository.dart';
import 'recipe_form_screen.dart';

class RecipesListScreen extends StatelessWidget {
  const RecipesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<RecipeRepository>();
    return Scaffold(
      body: StreamBuilder<List<UserLoadRow>>(
        stream: repo.watchAll(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final recipes = snap.data ?? const <UserLoadRow>[];
          if (recipes.isEmpty) {
            return const Center(
              child: Text('No recipes yet. Tap + to create your first.'),
            );
          }
          return ListView.separated(
            itemCount: recipes.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = recipes[i];
              final subtitle = [
                if (r.caliber != null) r.caliber,
                if (r.powderChargeGr != null) '${r.powderChargeGr}gr',
                if (r.bullet != null) r.bullet,
                if (r.coalIn != null) 'COAL ${r.coalIn}"',
              ].whereType<String>().join(' · ');
              return Dismissible(
                key: ValueKey('recipe_${r.id}'),
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
                          title: const Text('Delete This Recipe?'),
                          content: Text('"${r.name}" will be removed.'),
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
                onDismissed: (_) => repo.delete(r.id),
                child: ListTile(
                  title: Text(r.name),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecipeFormScreen(existing: r),
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
          MaterialPageRoute(builder: (_) => const RecipeFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
