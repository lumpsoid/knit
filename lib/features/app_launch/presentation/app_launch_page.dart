import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/features/app_launch/domain/app_destination.dart';
import 'package:knit/features/app_launch/presentation/app_launch_action.dart';
import 'package:knit/features/app_launch/presentation/app_launch_controller.dart';
import 'package:knit/features/app_launch/presentation/app_launch_scope.dart';
import 'package:knit/features/app_launch/presentation/app_launch_state.dart';
import 'package:knit/features/app_launch/presentation/app_launch_ui_effect.dart';
import 'package:knit/features/onboard/presentation/onboard_page.dart';
import 'package:knit/features/timeline/presentation/timeline_page.dart';

/// The splash / entry point (composition.md §3). Drives initialization, then
/// `pushReplacement`s the resolved destination.
class AppLaunchPage extends StatefulWidget {
  const AppLaunchPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const AppLaunchPage());

  @override
  State<AppLaunchPage> createState() => _AppLaunchPageState();
}

class _AppLaunchPageState extends State<AppLaunchPage> {
  AppLaunchController get _controller => AppLaunchScope.controller;

  @override
  void initState() {
    super.initState();
    _controller
      ..onAttach(_onUiEffect)
      ..dispatch(const ViewAttached());
  }

  @override
  void dispose() {
    _controller
      ..dispatch(const DeactivateFeature())
      ..onDetach();
    super.dispose();
  }

  void _onUiEffect(AppLaunchUiEffect effect) {
    if (!mounted) return;
    switch (effect) {
      case AppLaunchNavigateUiEffect(:final destination):
        final route = switch (destination) {
          AppLaunchDestination.onboarding => OnboardPage.route(),
          AppLaunchDestination.timeline => TimelinePage.route(),
        };
        Navigator.of(context).pushReplacement(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: ValueListenableBuilder<AppLaunchState>(
          valueListenable: _controller.stateHolder,
          builder: (context, state, _) {
            if (state.isFailed) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    Text(l10n.appLaunchError,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      state.errorMessage ?? l10n.appLaunchUnknownError,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () =>
                          _controller.dispatch(const RetryRequested()),
                      child: Text(l10n.actionRetry),
                    ),
                  ],
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.appTitle,
                    style: theme.textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
