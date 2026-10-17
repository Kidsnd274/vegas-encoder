import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import '../../../scripts/version_hook.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    await checkVersionInputs(input.packageRoot, output.dependencies.add);
    output.dependencies.add(
      input.packageRoot.resolve('../../src/core/profiles/data.h'),
    );
    if (input.config.code.targetOS != OS.windows ||
        input.config.code.targetArchitecture != Architecture.x64) {
      throw UnsupportedError('Vegas Encoder supports Windows x64 only.');
    }
    // Both the DLL and the future exporter static consumer use these sources.
    final core = input.packageRoot.resolve('../../src/core/');
    final builder = CBuilder.library(
      name: 've_core',
      assetName: 'src/native_bindings.dart',
      sources: [
        for (final file in [
          'json.cpp',
          'text.cpp',
          'recipe.cpp',
          'signal.cpp',
          'compile.cpp',
          'lint.cpp',
          'payload.cpp',
          'capi/ve_core.cpp',
        ])
          core.resolve(file).toFilePath(),
      ],
      includes: [core.toFilePath()],
      defines: {'VE_CORE_BUILD_DLL': null},
      language: Language.cpp,
      std: 'c++17',
      flags: ['/EHsc', '/W4', '/WX', '/utf-8'],
    );
    await builder.run(input: input, output: output);
  });
}
