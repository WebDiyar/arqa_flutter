import 'package:go_router/go_router.dart';
import 'package:my_app/features/posts/presentation/pages/post_details_page.dart';
import 'package:my_app/features/posts/presentation/pages/posts_page.dart';

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const PostsPage(),
      routes: [
        GoRoute(
          path: 'posts/:id',
          builder: (_, state) => PostDetailsPage(
            id: int.tryParse(state.pathParameters['id']!) ?? -1,
          ),
        ),
      ],
    ),
  ],
);
