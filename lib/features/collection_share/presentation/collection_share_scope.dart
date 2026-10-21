import 'package:knit/features/collection_share/presentation/collection_share_import_controller.dart';

/// Composition seam for collection share by file: `main` wires the factory
/// of import controllers that Settings → Data and the incoming-share gate
/// build one per import from. The export lives on the Collection screen
/// (`CollectionScope.createShareExport`).
abstract final class CollectionShareScope {
  static CollectionShareImportController Function()? _importFactory;

  static void setImportFactory(
    CollectionShareImportController Function() factory,
  ) => _importFactory = factory;

  /// Whether imports are wired (tests that pump a page on their own leave
  /// them out).
  static bool get canImport => _importFactory != null;

  /// A fresh controller for one import; its preview sheet disposes it.
  static CollectionShareImportController createImport() {
    final factory = _importFactory;
    if (factory == null) {
      throw StateError(
        'CollectionShareScope is not initialized.\n'
        'Call CollectionShareScope.setImportFactory() before createImport().',
      );
    }
    return factory();
  }
}
