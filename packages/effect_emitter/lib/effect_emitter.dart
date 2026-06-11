/// The UI side-effect seam: a controller/shell pushes one-shot, fire-and-forget
/// effects (navigation, snackbars, dialogs, sheets, loading toggles) to the View
/// without depending on the UI. See `docs/architecture/cross_feature.md` §4.
library;

export 'src/effect_emitter.dart';
