import 'package:knit/app/app_config.dart';
import 'package:knit/main.dart';

/// Dev flavor entry point — in-memory graph, distinct app id (`.dev`).
/// Run with: `flutter run --flavor dev -t lib/main_dev.dart`.
void main() => bootstrap(Flavor.dev.config);
