part of 'router.dart';

/// Login and the entry screens under it.
GoRoute _entryRoute(AuthRepository authRepository) => GoRoute(
  path: Routes.login,
  builder: (context, state) => ViewModelScope(
    create: () => LoginViewModel(authRepository: authRepository),
    builder: (viewModel) => LoginScreen(
      viewModel: viewModel,
      onEmail: () => context.push(Routes.emailLogin),
    ),
  ),
  routes: [
    GoRoute(
      path: _child(Routes.emailLogin),
      builder: (context, state) => ViewModelScope(
        create: () => EmailLoginViewModel(authRepository: authRepository),
        builder: (viewModel) => EmailLoginScreen(
          viewModel: viewModel,
          onVerifyEmail: () => context.push(Routes.verifyEmail),
          onSignup: () => context.push(Routes.signup),
          onForgotPassword: () => context.push(Routes.passwordReset),
        ),
      ),
    ),
    GoRoute(
      path: _child(Routes.signup),
      builder: (context, state) => ViewModelScope(
        create: () => SignupViewModel(authRepository: authRepository),
        builder: (viewModel) => SignupScreen(
          viewModel: viewModel,
          onCodeSent: () => context.push(Routes.verifyEmail),
        ),
      ),
    ),
    GoRoute(
      path: _child(Routes.verifyEmail),
      builder: (context, state) => ViewModelScope(
        create: () => VerifyEmailViewModel(authRepository: authRepository),
        builder: (viewModel) => VerifyEmailScreen(viewModel: viewModel),
      ),
    ),
    GoRoute(
      path: _child(Routes.passwordReset),
      builder: (context, state) => ViewModelScope(
        create: () => PasswordResetViewModel(authRepository: authRepository),
        builder: (viewModel) => PasswordResetScreen(viewModel: viewModel),
      ),
    ),
  ],
);

/// The path of an entry screen relative to [Routes.login], as a child route.
String _child(String location) => location.substring(Routes.login.length + 1);
