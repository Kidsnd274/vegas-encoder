import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    if (input.config.code.targetOS != OS.windows ||
        input.config.code.targetArchitecture != Architecture.x64) {
      throw UnsupportedError('Vegas Encoder services require Windows x64.');
    }
    await CBuilder.library(
      name: 've_windows_services',
      assetName: 'src/windows_gpu.dart',
      sources: [
        input.packageRoot
            .resolve('../../src/services/windows_gpu.cpp')
            .toFilePath(),
      ],
      libraries: ['dxgi'],
      language: Language.cpp,
      std: 'c++17',
      flags: ['/EHsc', '/W4', '/WX', '/utf-8'],
    ).run(input: input, output: output);
  });
}
