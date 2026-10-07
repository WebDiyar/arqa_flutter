import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/features/posts/di.dart';
import 'package:my_app/features/posts/domain/entities/post.dart';

final postsProvider = FutureProvider<List<Post>>(
  (ref) => ref.watch(getPostsProvider)(),
);
