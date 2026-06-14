import 'package:knit/app/app_config.dart';
import 'package:knit/main.dart';

/// Prod flavor entry point — persistent sqflite graph, release app id.
/// Run with: `flutter run --flavor prod -t lib/main_prod.dart`.
void main() => bootstrap(Flavor.prod.config);
