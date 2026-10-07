import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/core/network/dio_provider.dart';
import 'package:my_app/features/posts/data/datasources/posts_remote_data_source.dart';
import 'package:my_app/features/posts/data/repositories/posts_repository_impl.dart';
import 'package:my_app/features/posts/domain/repositories/posts_repository.dart';
import 'package:my_app/features/posts/domain/usecases/get_posts.dart';

// Composition root фичи: единственное место, где data встречается с domain.
// В тестах подменяется postsRepositoryProvider.

final postsRemoteDataSourceProvider = Provider(
  (ref) => PostsRemoteDataSource(ref.watch(dioProvider)),
);

final postsRepositoryProvider = Provider<PostsRepository>(
  (ref) => PostsRepositoryImpl(ref.watch(postsRemoteDataSourceProvider)),
);

final getPostsProvider = Provider(
  (ref) => GetPosts(ref.watch(postsRepositoryProvider)),
);
