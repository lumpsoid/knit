import 'package:knit/app/app_config.dart';
import 'package:knit/main.dart';

/// Staging flavor entry point — persistent sqflite graph, distinct app id
/// (`.staging`). Run with: `flutter run --flavor staging -t lib/main_staging.dart`.
void main() => bootstrap(Flavor.staging.config);
