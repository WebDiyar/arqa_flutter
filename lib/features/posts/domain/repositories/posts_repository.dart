import 'package:my_app/features/posts/domain/entities/post.dart';

/// Контракт. Реализация — в data/, domain о ней не знает.
/// Бросает только AppException.
abstract interface class PostsRepository {
  Future<List<Post>> getPosts();
}
