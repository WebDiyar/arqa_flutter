import 'package:my_app/features/posts/domain/entities/post.dart';
import 'package:my_app/features/posts/domain/repositories/posts_repository.dart';

class GetPosts {
  const GetPosts(this._repository);

  final PostsRepository _repository;

  Future<List<Post>> call() => _repository.getPosts();
}
