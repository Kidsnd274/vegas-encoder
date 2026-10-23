import 'dart:typed_data';
import 'models.dart';

/// Synchronous, deterministic calls. NativeVeCore uses the bundled B2 native asset.
/// Implementations never inspect the filesystem, run FFmpeg, or access VEGAS.
abstract interface class VeCore {
  CoreVersion get version;
  ProfileCatalog profiles();
  NormalizeResult normalize(Map<String, Object?> json);
  List<Issue> validate(
    Recipe recipe, {
    MediaDescription? media,
    CoreCapabilities? capabilities,
  });
  CompileResult compile(
    Recipe recipe, {
    required MediaDescription media,
    required CompilePaths paths,
    CoreCapabilities? capabilities,
  });
  List<Diagnostic> lint(String text, {CoreCapabilities? capabilities});
  CompletionResult complete(
    String text,
    int caret, {
    CoreCapabilities? capabilities,
  });
  SizeEstimate estimate(
    Recipe recipe, {
    required MediaDescription media,
    double? durationSec,
  });
  List<FieldDiff> diff(Recipe before, Recipe after);
  Uint8List encodePayload(TemplateSnapshot snapshot);
  PayloadResult decodePayload(Uint8List bytes);
}

/// Optional additive interface, keeping injected older core fakes valid.
abstract interface class VeCoreSnapshotSummaries {
  SnapshotSummary summarizeSnapshot(
    TemplateSnapshot snapshot, {
    MediaDescription? media,
  });
}

extension VeCoreSummary on VeCore {
  SnapshotSummary summarizeSnapshot(
    TemplateSnapshot snapshot, {
    MediaDescription? media,
  }) {
    final core = this;
    if (core is VeCoreSnapshotSummaries) {
      return (core as VeCoreSnapshotSummaries).summarizeSnapshot(
        snapshot,
        media: media,
      );
    }
    throw const CoreException(
      'SUMMARY-UNAVAILABLE',
      'This core does not supply snapshot summaries.',
    );
  }
}

class CoreException implements Exception {
  const CoreException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'CoreException($code): $message';
}

/// Additive optional interface: existing VeCore implementations remain valid.
abstract interface class VeCoreMacroCatalog {
  List<MacroDefinition> macros({
    required MediaDescription media,
    required CompilePaths paths,
    Recipe? recipe,
  });
}

extension VeCoreMacros on VeCore {
  List<MacroDefinition> macros({
    required MediaDescription media,
    required CompilePaths paths,
    Recipe? recipe,
  }) {
    final core = this;
    if (core is VeCoreMacroCatalog)
      return (core as VeCoreMacroCatalog).macros(
        media: media,
        paths: paths,
        recipe: recipe,
      );
    throw const CoreException(
      'MACROS-UNAVAILABLE',
      'This core does not supply a macro catalogue.',
    );
  }
}
