import 'package:ve_services/ve_services.dart';

/// `older` describes an older VEGAS: 23.0.0.278 (an owner-tested legacy host) by
/// default, or a host that is detected only, such as VEGAS 22.
VegasHostStatus vegasHostFixture(
  VegasInstallationState state, {
  bool older = false,
  String olderVersion = '23.0.0.278',
}) {
  final major = olderVersion.split('.').first;
  final root = older ? 'D:\\VEGAS\\VEGAS Pro $major.0' : r'C:\Program Files\BorisFX\Vegas Pro 2026';
  final plugin = '$root\\FileIO Plug-Ins\\vegas-encoder';
  return VegasHostStatus(
    name: older ? 'VEGAS Pro $major' : 'Boris FX VEGAS Pro 2026',
    version: older ? olderVersion : '2026.0.3.189',
    executable: '$root\\${older ? 'vegas${major}0.exe' : 'vegas2026.exe'}',
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
