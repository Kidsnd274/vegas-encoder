import 'dart:convert';

import 'api.dart';
import 'windows_gpu.dart';

enum VegasInstallationState {
  notInstalled,
  verified,
  unverified,
  changed,
  unreadable,
}

class VegasHostStatus {
  const VegasHostStatus({
    required this.name,
    required this.version,
    required this.executable,
    required this.x64,
    required this.exporterPath,
    required this.discoveryPath,
    required this.manifestPath,
    required this.state,
    this.exporterVersion,
    this.details = const [],
  });
  final String name,
      version,
      executable,
      exporterPath,
      discoveryPath,
      manifestPath;
  final bool x64;
  final String? exporterVersion;
  final VegasInstallationState state;
  final List<String> details;

  // This identifies the recorded target version, never a support guarantee.
  bool get selectedHostVersion => x64 && version == '2026.0.3.189';

  factory VegasHostStatus.fromJson(Map<String, dynamic> json) =>
      VegasHostStatus(
        name: json['name'] as String,
        version: json['version'] as String,
        executable: json['executable'] as String,
        x64: json['x64'] as bool,
        exporterPath: json['exporterPath'] as String,
        discoveryPath: json['discoveryPath'] as String,
        manifestPath: json['manifestPath'] as String,
        exporterVersion: json['exporterVersion'] as String?,
        state: VegasInstallationState.values.byName(json['state'] as String),
        details: List<String>.unmodifiable(
          (json['details'] as List).cast<String>(),
        ),
      );
}

class VegasInstallationSnapshot {
  const VegasInstallationSnapshot({
    this.hosts = const [],
    this.errors = const [],
  });
  final List<VegasHostStatus> hosts;
  final List<String> errors;
}

abstract interface class VegasInstallations {
  Future<VegasInstallationSnapshot> inspect();
}

/// Read-only Windows API inspection on a worker isolate. No host/exporter is
/// loaded, no process is started, and no installation or user data is written.
class WindowsVegasInstallations implements VegasInstallations {
  WindowsVegasInstallations({
    this.candidateDirectories = const [],
    this.readRegistry = true,
  });
  final List<String> candidateDirectories;
  final bool readRegistry;

  @override
  Future<VegasInstallationSnapshot> inspect() async {
    final response = await readVegasInstallationJson(
      jsonEncode({
        'directories': candidateDirectories,
        'registry': readRegistry,
      }),
    );
    try {
      final json = jsonDecode(response) as Map<String, dynamic>;
      if (json['schema'] != 'vegas-installation-status/1') {
        throw const FormatException('Unknown inspection response');
      }
      return VegasInstallationSnapshot(
        hosts: List.unmodifiable(
          (json['hosts'] as List).map(
            (row) => VegasHostStatus.fromJson(row as Map<String, dynamic>),
          ),
        ),
        errors: List<String>.unmodifiable(
          (json['errors'] as List).cast<String>(),
        ),
      );
    } catch (e) {
      throw ServiceException(
        'VEGAS-STATUS',
        'Could not read VEGAS inspection results: $e',
      );
    }
  }
}

class FakeVegasInstallations implements VegasInstallations {
  FakeVegasInstallations({this.snapshot = const VegasInstallationSnapshot()});
  VegasInstallationSnapshot snapshot;
  ServiceException? error;
  int inspections = 0;
  @override
  Future<VegasInstallationSnapshot> inspect() async {
    inspections++;
    if (error case final error?) throw error;
    return snapshot;
  }
}
