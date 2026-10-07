import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/app.dart';
import 'package:my_app/features/posts/data/models/post_model.dart';
import 'package:my_app/features/posts/di.dart';
import 'package:my_app/features/posts/domain/entities/post.dart';
import 'package:my_app/features/posts/domain/repositories/posts_repository.dart';

class _FakePostsRepository implements PostsRepository {
  @override
  Future<List<Post>> getPosts() async => const [
    Post(id: 1, userId: 1, title: 'Hello', body: 'World'),
  ];
}

void main() {
  test('PostModel парсит JSON и превращается в entity', () {
    final post = PostModel.fromJson(const {
      'id': 1,
      'userId': 2,
      'title': 't',
      'body': 'b',
    }).toEntity();

    expect((post.id, post.userId, post.title, post.body), (1, 2, 't', 'b'));
  });

  testWidgets('список → детали, без сети', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          postsRepositoryProvider.overrideWithValue(_FakePostsRepository()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);

    await tester.tap(find.text('Hello'));
    await tester.pumpAndSettle();
    expect(find.text('Post #1'), findsOneWidget);
  });
}
