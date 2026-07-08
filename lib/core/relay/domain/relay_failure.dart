/// Per-area failure family for relay publishing (result.md §9.3 — never a global
/// `AppFailure`). Every fallible relay call returns a `Result` carrying one of
/// these, so the shell logs the real cause (an HTTP status, a transport error, a
/// local read failure) rather than a re-typed summary.
sealed class RelayFailure {
  const RelayFailure(this.error, [this.stackTrace]);

  /// The underlying error — a caught exception, or a domain-condition message.
  final Object error;

  /// The stack trace from the caught exception, when there was one.
  final StackTrace? stackTrace;
}

/// The transport failed before an HTTP status came back (offline, DNS, TLS,
/// timeout). Retriable.
class RelayNetworkFailure extends RelayFailure {
  const RelayNetworkFailure(super.error, [super.stackTrace]);
}

/// The relay answered with a non-2xx status. [statusCode] is the HTTP status and
/// [code] the relay's wire error string when present (e.g. `"no_topic"`,
/// `"bad_visibility"`, `"hash_mismatch"`, `"no_push_scope"`).
class RelayResponseFailure extends RelayFailure {
  const RelayResponseFailure({
    required this.statusCode,
    this.code,
    required Object error,
    StackTrace? stackTrace,
  }) : super(error, stackTrace);

  final int statusCode;
  final String? code;
}

/// No local identity is provisioned, so there is no owner pubkey to bind a new
/// topic to. The onboarding ceremony must run first (§6.5).
class RelayIdentityMissing extends RelayFailure {
  const RelayIdentityMissing() : super('no local identity provisioned');
}

/// Assembling the snapshot failed — reading the collection or an attachment's
/// bytes errored. Wraps the underlying `CollectionFailure`/`AttachmentFailure`.
class RelayBuildFailure extends RelayFailure {
  const RelayBuildFailure(super.error, [super.stackTrace]);
}

/// A device-local persistence read/write (the relay publication table) failed.
class RelayStoreFailure extends RelayFailure {
  const RelayStoreFailure(super.error, [super.stackTrace]);
}

/// Anything not otherwise classified — an unexpected exception at the seam.
class RelayUnexpected extends RelayFailure {
  const RelayUnexpected(super.error, [super.stackTrace]);
}
