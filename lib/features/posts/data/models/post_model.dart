import 'package:my_app/features/posts/domain/entities/post.dart';

/// DTO: форма ответа API. Меняется вместе с бэком, entity — нет.
class PostModel {
  const PostModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) => PostModel(
    id: json['id'] as int,
    userId: json['userId'] as int,
    title: json['title'] as String,
    body: json['body'] as String,
  );

  final int id;
  final int userId;
  final String title;
  final String body;

  Post toEntity() => Post(id: id, userId: userId, title: title, body: body);
}
