import 'dart:convert';
import 'dart:typed_data';
import 'api.dart';
import 'fixture_data.dart';
import 'json_model.dart';
import 'models.dart';

/// Shared read-only seed data for all B0 fakes. These are design facts only.
class _FixtureSeed extends JsonModel {
  _FixtureSeed() : super(jsonMap(jsonDecode(b0FixtureJson)));
}

final _seed = _FixtureSeed();
JsonMap b0Fixtures() => _seed.data;

String _key(Object? value) {
  Object? sorted(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {
        for (final key in keys)
          if (!(key == 'extensions' &&
              value[key] is Map &&
              (value[key] as Map).isEmpty))
            key: sorted(value[key]),
      };
    }
    if (value is List) return value.map(sorted).toList();
    return value;
  }

  return jsonEncode(sorted(value));
}

class CoreFixture {
  CoreFixture({
    required this.recipe,
    required this.media,
    required this.paths,
    required this.normalized,
    required this.compiled,
    required this.estimate,
    required Map<String, List<Issue>> validations,
    Map<String, List<Issue>>? compileIssues,
  }) : validations = Map.unmodifiable(
         validations.map((k, v) => MapEntry(k, List<Issue>.unmodifiable(v))),
       ),
       compileIssues = Map.unmodifiable(
         (compileIssues ?? validations).map(
           (k, v) => MapEntry(k, List<Issue>.unmodifiable(v)),
         ),
       );
  factory CoreFixture.fromJson(JsonMap json) => CoreFixture(
    recipe: Recipe.fromJson(jsonMap(json['recipe'])),
    media: MediaDescription.fromJson(jsonMap(json['media'])),
    paths: CompilePaths.fromJson(jsonMap(json['paths'])),
    normalized: NormalizeResult.fromJson(jsonMap(json['normalize'])),
    compiled: CompileResult.fromJson(jsonMap(json['compile'])),
    estimate: SizeEstimate.fromJson(jsonMap(json['estimate'])),
    validations: jsonMap(
      json['validations'],
    ).map((k, v) => MapEntry(k, jsonMaps(v).map(Issue.fromJson).toList())),
    compileIssues: jsonMap(
      json['compileIssues'] ?? json['validations'],
    ).map((k, v) => MapEntry(k, jsonMaps(v).map(Issue.fromJson).toList())),
  );
  final Recipe recipe;
  final MediaDescription media;
  final CompilePaths paths;
  final NormalizeResult normalized;
  final CompileResult compiled;
  final SizeEstimate estimate;
  final Map<String, List<Issue>> validations;
  final Map<String, List<Issue>> compileIssues;
}

/// A fixture lookup, never a second implementation of the product rules.
/// Modified recipes/contexts require injected fixtures; unmatched calls throw.
class FakeVeCore implements VeCore {
  FakeVeCore({
    List<CoreFixture>? fixtures,
    ProfileCatalog? catalog,
    Map<String, List<Diagnostic>>? lintFixtures,
    Map<String, CompletionResult>? completionFixtures,
    Map<String, List<FieldDiff>>? diffFixtures,
    Map<String, SizeEstimate>? estimateFixtures,
    Map<String, Uint8List>? encodedPayloadFixtures,
    Map<String, PayloadResult>? decodedPayloadFixtures,
  }) : fixtures = List.unmodifiable(
         fixtures ??
             [
               ...jsonMaps(b0Fixtures()['fixtures']),
               ...jsonMaps(b0Fixtures()['additionalFixtures']),
             ].map(CoreFixture.fromJson),
       ),
       _catalog =
           catalog ??
           ProfileCatalog.fromJson(jsonMap(b0Fixtures()['profiles'])),
       _lint = Map.unmodifiable(
         (lintFixtures ??
                 jsonMap(b0Fixtures()['lint']).map(
                   (k, v) => MapEntry(
                     k,
                     jsonMaps(v).map(Diagnostic.fromJson).toList(),
                   ),
                 ))
             .map((k, v) => MapEntry(k, List<Diagnostic>.unmodifiable(v))),
       ),
       _complete = Map.unmodifiable(
         completionFixtures ??
             jsonMap(b0Fixtures()['complete']).map(
               (k, v) => MapEntry(k, CompletionResult.fromJson(jsonMap(v))),
             ),
       ),
       _diff = Map.unmodifiable(
         (diffFixtures ??
                 jsonMap(b0Fixtures()['diffs']).map(
                   (k, v) => MapEntry(
                     k
                         .split('\n')
                         .map((part) => _key(jsonDecode(part)))
                         .join('\n'),
                     jsonMaps(v).map(FieldDiff.fromJson).toList(),
                   ),
                 ))
             .map((k, v) => MapEntry(k, List<FieldDiff>.unmodifiable(v))),
       ),
       _estimate = Map.unmodifiable(estimateFixtures ?? {}),
       _encode = Map.unmodifiable(
         (encodedPayloadFixtures ??
                 jsonMap(b0Fixtures()['payloads']).map(
                   (k, v) =>
                       MapEntry(_key(jsonDecode(k)), base64Decode(v as String)),
                 ))
             .map((k, v) => MapEntry(k, Uint8List.fromList(v))),
       ),
       _decode = Map.unmodifiable(
         decodedPayloadFixtures ??
             jsonMap(
               b0Fixtures()['decodedPayloads'],
             ).map((k, v) => MapEntry(k, PayloadResult.fromJson(jsonMap(v)))),
       );

  final List<CoreFixture> fixtures;
  final ProfileCatalog _catalog;
  final Map<String, List<Diagnostic>> _lint;
  final Map<String, CompletionResult> _complete;
  final Map<String, List<FieldDiff>> _diff;
  final Map<String, SizeEstimate> _estimate;
  final Map<String, Uint8List> _encode;
  final Map<String, PayloadResult> _decode;
  @override
  CoreVersion get version => CoreVersion();
  @override
  ProfileCatalog profiles() => _catalog;
  static String recipeKey(Recipe recipe) => _key(recipe.toJson());
  static String completionKey(String text, int caret) => '$caret:$text';
  static String diffKey(Recipe before, Recipe after) =>
      '${recipeKey(before)}\n${recipeKey(after)}';
  static String estimateKey(
    Recipe recipe,
    MediaDescription media,
    double? durationSec,
  ) => _key({
    'recipe': recipe.toJson(),
    'media': media.toJson(),
    'durationSec': durationSec,
  });
  static String snapshotKey(TemplateSnapshot snapshot) =>
      _key(snapshot.toJson());

  Never _missing(String operation) => throw CoreException(
    'B0-FIXTURE-MISSING',
    'No $operation fixture. Inject a fixture for this request; real rules arrive in B2.',
  );
  CoreFixture _fixture(Recipe recipe) {
    for (final fixture in fixtures) {
      if (recipeKey(recipe) == recipeKey(fixture.recipe)) return fixture;
    }
    return _missing('recipe');
  }

  bool _sameMedia(MediaDescription a, MediaDescription b) =>
      _key(a.toJson()) == _key(b.toJson());

  @override
  NormalizeResult normalize(JsonMap json) =>
      _fixture(Recipe.fromJson(json)).normalized;
  @override
  List<Issue> validate(
    Recipe recipe, {
    MediaDescription? media,
    CoreCapabilities? capabilities,
  }) {
    final f = _fixture(recipe);
    if (media != null && !_sameMedia(media, f.media))
      return _missing('validation media');
    return f.validations[capabilities?.installationId ?? 'gyan-8.1'] ??
        _missing('validation capabilities');
  }

  @override
  CompileResult compile(
    Recipe recipe, {
    required MediaDescription media,
    required CompilePaths paths,
    CoreCapabilities? capabilities,
  }) {
    final f = _fixture(recipe);
    if (!_sameMedia(media, f.media) ||
        _key(paths.toJson()) != _key(f.paths.toJson()))
      return _missing('compile context');
    if (capabilities != null) {
      final issues =
          f.compileIssues[capabilities.installationId] ??
          _missing('compile capabilities');
      return f.compiled.copyWith(issues: issues);
    }
    return f.compiled;
  }

  @override
  List<Diagnostic> lint(String text, {CoreCapabilities? capabilities}) {
    if (capabilities != null) return _missing('capability-specific lint');
    return _lint[text] ?? _missing('lint');
  }

  @override
  CompletionResult complete(
    String text,
    int caret, {
    CoreCapabilities? capabilities,
  }) {
    if (caret < 0 || caret > text.length)
      throw RangeError.range(caret, 0, text.length, 'caret');
    if (capabilities != null) return _missing('capability-specific completion');
    return _complete[completionKey(text, caret)] ?? _missing('completion');
  }

  @override
  SizeEstimate estimate(
    Recipe recipe, {
    required MediaDescription media,
    double? durationSec,
  }) {
    final override = _estimate[estimateKey(recipe, media, durationSec)];
    if (override != null) return override;
    final f = _fixture(recipe);
    if (durationSec != null || !_sameMedia(media, f.media))
      return _missing('estimate context');
    return f.estimate;
  }

  @override
  List<FieldDiff> diff(Recipe before, Recipe after) =>
      _diff[diffKey(before, after)] ?? _missing('diff');
  @override
  Uint8List encodePayload(TemplateSnapshot snapshot) {
    final bytes = _encode[snapshotKey(snapshot)] ?? _missing('payload encode');
    return Uint8List.fromList(bytes);
  }

  @override
  PayloadResult decodePayload(Uint8List bytes) =>
      _decode[base64Encode(bytes)] ?? _missing('payload decode');
}
