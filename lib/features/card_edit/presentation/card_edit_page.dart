import 'package:flutter/material.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_controller.dart';
import 'package:knit/features/card_edit/presentation/card_edit_scope.dart';
import 'package:knit/features/card_edit/presentation/card_edit_state.dart';
import 'package:knit/features/card_edit/presentation/card_edit_ui_effect.dart';

/// The Card Edit page (§4.3) — a dedicated page for editing a card's content.
/// The MVP edits text; links (subtask 3) and image (subtask 4) hang off it. The
/// edit target arrives via the route-args carrier (cross_feature.md §2); on save
/// the page pops and the Collection screen resyncs from the projection.
class CardEditPage extends StatefulWidget {
  const CardEditPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const CardEditPage());

  @override
  State<CardEditPage> createState() => _CardEditPageState();
}

class _CardEditPageState extends State<CardEditPage> {
  CardEditController get _controller => CardEditScope.controller;
  late final TextEditingController _field;

  @override
  void initState() {
    super.initState();
    final args = CardEditScope.routeArgs;
    _field = TextEditingController(text: args.initialText);
    _controller
      ..onAttach(_onUiEffect)
      ..dispatch(
        ViewAttached(cardId: args.cardId, initialText: args.initialText),
      );
  }

  @override
  void dispose() {
    _controller
      ..dispatch(const DeactivateFeature())
      ..onDetach();
    _field.dispose();
    super.dispose();
  }

  void _onUiEffect(CardEditUiEffect effect) {
    if (!mounted) return;
    switch (effect) {
      case CardEditSavedUiEffect():
        Navigator.of(context).pop();
      case CardEditShowMessageUiEffect(:final message):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _save() => _controller.dispatch(SaveRequested(_field.text));

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CardEditState>(
      valueListenable: _controller.stateHolder,
      builder: (context, state, _) {
        final saving = state.status == CardEditStatus.saving;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit card'),
            actions: [
              saving
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _field,
              autofocus: true,
              enabled: !saving,
              minLines: 3,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Edit this card…',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        );
      },
    );
  }
}
