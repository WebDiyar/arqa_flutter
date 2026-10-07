import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/core/widgets/error_view.dart';
import 'package:my_app/features/posts/presentation/providers/posts_provider.dart';

class PostDetailsPage extends ConsumerWidget {
  const PostDetailsPage({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Берём из уже загруженного списка — отдельный запрос не нужен,
    // а при deep link на /posts/5 список просто загрузится.
    final post = ref
        .watch(postsProvider)
        .whenData((posts) => posts.where((p) => p.id == id).firstOrNull);

    return Scaffold(
      appBar: AppBar(title: Text('Post #$id')),
      body: post.when(
        data: (p) => p == null
            ? const Center(child: Text('Пост не найден'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(p.title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(p.body),
                ],
              ),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(postsProvider),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
