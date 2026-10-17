import 'package:ve_services/ve_services.dart';

VegasHostStatus vegasHostFixture(VegasInstallationState state, {bool older = false}) {
  final root = older ? r'D:\VEGAS\VEGAS Pro 23.0' : r'C:\Program Files\BorisFX\Vegas Pro 2026';
  final plugin = '$root\\FileIO Plug-Ins\\vegas-encoder';
  return VegasHostStatus(
    name: older ? 'VEGAS Pro 23' : 'Boris FX VEGAS Pro 2026',
    version: older ? '23.0.0.278' : '2026.0.3.189',
    executable: '$root\\${older ? 'vegas230.exe' : 'vegas2026.exe'}',
    x64: true,
    exporterPath: '$plugin\\vegas-encoder.dll',
    discoveryPath: '$root\\VegasEncoder-x64.fio2007-config',
    manifestPath: '$plugin\\install-manifest.json',
    exporterVersion: state == VegasInstallationState.notInstalled ? null : '0.1.7.1',
    state: state,
    details: [
      switch (state) {
        VegasInstallationState.notInstalled => 'No exporter or discovery files were found.',
        VegasInstallationState.verified =>
          'Recorded exporter, INI and discovery bytes match the installed manifest (SHA-256).',
        VegasInstallationState.unverified => 'Unsupported installed manifest schema: future-installer/2',
        VegasInstallationState.changed => 'Missing or changed recorded file: $plugin\\vegas-encoder.ini',
        VegasInstallationState.unreadable => 'Cannot read file (Windows error 5): $plugin\\install-manifest.json',
      },
    ],
  );
}
