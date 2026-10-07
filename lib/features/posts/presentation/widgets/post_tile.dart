import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_app/features/posts/domain/entities/post.dart';

class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(post.title),
      subtitle: Text(post.body, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () => context.go('/posts/${post.id}'),
    );
  }
}
