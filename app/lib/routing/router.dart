import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../ui/home/view_models/home_view_model.dart';
import '../ui/home/widgets/home_screen.dart';

abstract final class Routes {
  static const home = '/';
}

GoRouter router() => GoRouter(
  initialLocation: Routes.home,
  routes: [
    GoRoute(
      path: Routes.home,
      // The provider creates the view model once per visit and disposes it
      // when the route leaves.
      builder: (context, state) => ChangeNotifierProvider(
        create: (context) => HomeViewModel(healthRepository: context.read()),
        child: Consumer<HomeViewModel>(
          builder: (context, viewModel, _) => HomeScreen(viewModel: viewModel),
        ),
      ),
    ),
  ],
);
