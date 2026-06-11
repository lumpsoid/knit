import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:knit/features/onboard/domain/identity_card.dart';
import 'package:knit/features/onboard/presentation/onboard_action.dart';
import 'package:knit/features/onboard/presentation/onboard_controller.dart';
import 'package:knit/features/onboard/presentation/onboard_scope.dart';
import 'package:knit/features/onboard/presentation/onboard_state.dart';
import 'package:knit/features/onboard/presentation/onboard_ui_effect.dart';
import 'package:knit/features/timeline/presentation/timeline_page.dart';

/// The first-run identity ceremony (spec §5): welcome → nickname → explain →
/// generate (with a visible "minting" moment) → reveal → into the timeline.
class OnboardPage extends StatefulWidget {
  const OnboardPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const OnboardPage());

  @override
  State<OnboardPage> createState() => _OnboardPageState();
}

class _OnboardPageState extends State<OnboardPage> {
  OnboardController get _controller => OnboardScope.controller;
  final TextEditingController _nicknameField = TextEditingController();

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
    _nicknameField.dispose();
    super.dispose();
  }

  void _onUiEffect(OnboardUiEffect effect) {
    if (!mounted) return;
    switch (effect) {
      case OnboardEnterAppUiEffect():
        Navigator.of(context).pushReplacement(TimelinePage.route());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<OnboardState>(
          valueListenable: _controller.stateHolder,
          builder: (context, state, _) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: KeyedSubtree(
                key: ValueKey(state.step),
                child: _stepView(state),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _stepView(OnboardState state) {
    switch (state.step) {
      case OnboardStep.welcome:
        return _WelcomeView(
          onGetStarted: () => _controller.dispatch(const GetStartedTapped()),
        );
      case OnboardStep.nickname:
        return _NicknameView(
          field: _nicknameField,
          canContinue: state.canContinueFromNickname,
          onChanged: (v) => _controller.dispatch(NicknameChanged(v)),
          onContinue: () => _controller.dispatch(const NicknameSubmitted()),
          onBack: () => _controller.dispatch(const BackTapped()),
        );
      case OnboardStep.explainIdentity:
        return _ExplainView(
          nickname: state.nickname.trim(),
          errorMessage: state.errorMessage,
          onGenerate: () =>
              _controller.dispatch(const GenerateIdentityTapped()),
          onBack: () => _controller.dispatch(const BackTapped()),
        );
      case OnboardStep.generating:
        return const _GeneratingView();
      case OnboardStep.reveal:
        return _RevealView(
          identity: state.identity!,
          onEnter: () => _controller.dispatch(const EnterAppTapped()),
        );
    }
  }
}

// --- Steps -----------------------------------------------------------------

class _WelcomeView extends StatelessWidget {
  const _WelcomeView({required this.onGetStarted});
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Frame(
      children: [
        const Spacer(),
        Icon(Icons.hub_outlined, size: 96, color: theme.colorScheme.primary),
        const SizedBox(height: 32),
        Text('Welcome to Knit',
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          'Capture anything as cards, woven together in your own\n'
          'collections. Local-first — your data lives on your device.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        FilledButton(
          onPressed: onGetStarted,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('Get started'),
        ),
      ],
    );
  }
}

class _NicknameView extends StatelessWidget {
  const _NicknameView({
    required this.field,
    required this.canContinue,
    required this.onChanged,
    required this.onContinue,
    required this.onBack,
  });

  final TextEditingController field;
  final bool canContinue;
  final ValueChanged<String> onChanged;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Frame(
      onBack: onBack,
      children: [
        const SizedBox(height: 24),
        Text('What should people call you?',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text(
          'A nickname is just a label — your identity is your key, not this '
          'name. You can change it anytime.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: field,
          autofocus: true,
          textInputAction: TextInputAction.done,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Nickname',
            hintText: 'e.g. mira',
            border: OutlineInputBorder(),
          ),
          onChanged: onChanged,
          onSubmitted: (_) {
            if (canContinue) onContinue();
          },
        ),
        const Spacer(),
        FilledButton(
          onPressed: canContinue ? onContinue : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _ExplainView extends StatelessWidget {
  const _ExplainView({
    required this.nickname,
    required this.errorMessage,
    required this.onGenerate,
    required this.onBack,
  });

  final String nickname;
  final String? errorMessage;
  final VoidCallback onGenerate;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Frame(
      onBack: onBack,
      children: [
        const SizedBox(height: 24),
        Icon(Icons.vpn_key_outlined,
            size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        Text('Your identity is a key',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        _bullet(theme, Icons.fingerprint,
            'We\'ll generate a cryptographic key pair on this device. The '
            'public key IS your identity — not a username on someone\'s server.'),
        _bullet(theme, Icons.lock_outline,
            'The private half never leaves your device. Keep it safe — backing '
            'it up later (in Settings) is how you back up "you".'),
        _bullet(theme, Icons.badge_outlined,
            'Hi, $nickname — your key is who you are, your nickname is what '
            'you\'re called.'),
        if (errorMessage != null) ...[
          const SizedBox(height: 16),
          _ErrorBanner(message: errorMessage!),
        ],
        const Spacer(),
        FilledButton.icon(
          onPressed: onGenerate,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Generate my identity'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
      ],
    );
  }

  Widget _bullet(ThemeData theme, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(text, style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      );
}

class _GeneratingView extends StatefulWidget {
  const _GeneratingView();

  @override
  State<_GeneratingView> createState() => _GeneratingViewState();
}

class _GeneratingViewState extends State<_GeneratingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Frame(
      children: [
        const Spacer(),
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
              ),
              ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.1).animate(
                  CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
                ),
                child: Icon(Icons.vpn_key,
                    size: 44, color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text('Minting your keypair…',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Generating Ed25519 keys and signing your profile.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center),
        const Spacer(),
      ],
    );
  }
}

class _RevealView extends StatelessWidget {
  const _RevealView({required this.identity, required this.onEnter});
  final IdentityCard identity;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarColor = _avatarColor(identity.fingerprint);
    return _Frame(
      children: [
        const SizedBox(height: 16),
        Text('Meet yourself',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 24),
        CircleAvatar(
          radius: 44,
          backgroundColor: avatarColor,
          child: Text(
            identity.nickname.isEmpty
                ? '?'
                : identity.nickname.substring(0, 1).toUpperCase(),
            style: theme.textTheme.headlineMedium
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 16),
        Text(identity.handle,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('key = who you are · nickname = what you\'re called',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 24),
        _PubkeyBox(publicKeyHex: identity.publicKeyHex),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.shield_outlined,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Your private key is stored only on this device. Back it up '
                'later from Settings.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const Spacer(),
        FilledButton(
          onPressed: onEnter,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('Enter Knit'),
        ),
      ],
    );
  }

  /// Deterministic avatar hue from the fingerprint (§5) — same key, same color.
  Color _avatarColor(String fingerprint) {
    final v = int.tryParse(fingerprint, radix: 16) ?? 0;
    return HSLColor.fromAHSL(1, (v % 360).toDouble(), 0.55, 0.5).toColor();
  }
}

// --- Shared bits -----------------------------------------------------------

/// A consistent padded column frame with an optional back button.
class _Frame extends StatelessWidget {
  const _Frame({required this.children, this.onBack});
  final List<Widget> children;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: onBack == null
                ? null
                : Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _PubkeyBox extends StatelessWidget {
  const _PubkeyBox({required this.publicKeyHex});
  final String publicKeyHex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              publicKeyHex,
              maxLines: 2,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy public key',
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: publicKeyHex));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Public key copied')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              size: 20, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
