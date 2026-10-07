import 'package:dio/dio.dart';
import 'package:my_app/core/error/app_exception.dart';
import 'package:my_app/features/posts/data/datasources/posts_remote_data_source.dart';
import 'package:my_app/features/posts/domain/entities/post.dart';
import 'package:my_app/features/posts/domain/repositories/posts_repository.dart';

class PostsRepositoryImpl implements PostsRepository {
  const PostsRepositoryImpl(this._remote);

  final PostsRemoteDataSource _remote;

  @override
  Future<List<Post>> getPosts() async {
    try {
      final models = await _remote.getPosts();
      return models.map((m) => m.toEntity()).toList();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }
}
