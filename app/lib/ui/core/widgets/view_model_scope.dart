import 'package:flutter/widgets.dart';

/// Creates a screen's ViewModel once, when the route is built, and disposes it
/// when the route goes away. The router uses it so screens can take their
/// ViewModel as a plain parameter (and tests can pass one in).
///
/// @example ViewModelScope(create: () => SignupViewModel(...),
///     builder: (viewModel) => SignupScreen(viewModel: viewModel))
class ViewModelScope<T extends ChangeNotifier> extends StatefulWidget {
  const ViewModelScope({
    super.key,
    required this.create,
    required this.builder,
  });

  final T Function() create;
  final Widget Function(T viewModel) builder;

  @override
  State<ViewModelScope<T>> createState() => _ViewModelScopeState<T>();
}

class _ViewModelScopeState<T extends ChangeNotifier>
    extends State<ViewModelScope<T>> {
  late final T _viewModel = widget.create();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_viewModel);
}
