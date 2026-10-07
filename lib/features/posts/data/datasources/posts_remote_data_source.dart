import 'package:dio/dio.dart';
import 'package:my_app/features/posts/data/models/post_model.dart';

class PostsRemoteDataSource {
  const PostsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<PostModel>> getPosts() async {
    final res = await _dio.get<List<dynamic>>('/posts');
    return res.data!
        .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
