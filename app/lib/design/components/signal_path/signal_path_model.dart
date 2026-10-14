import 'package:flutter/foundation.dart';

import '../status.dart';

/// The diagram's nodes, in keyboard order.
enum SignalNode { source, video, audio, container, file }

/// What VEGAS delivers (the "From VEGAS" node).
@immutable
class SignalSource {
  const SignalSource({
    required this.frameSize,
    required this.frameRate,
    required this.pixelFormat,
    required this.audio,
    required this.stripVideo,
    required this.stripAudio,
    required this.depth,
    required this.spokenSummary,
  });

  /// "1920×1080"
  final String frameSize;

  /// "29.97 fps"
  final String frameRate;

  /// "P010, 10-bit 4:2:0"
  final String pixelFormat;

  /// "48 kHz float stereo"
  final String audio;

  /// Strip lines: "29.97 fps, 10-bit" and "48 kHz float".
  final String stripVideo;
  final String stripAudio;

  /// Bit depth of the delivered frames; sets the input wire's thickness.
  final int depth;

  /// "1920 by 1080, 29.97 fps"
  final String spokenSummary;
}

/// A format change on a wire, marked by a pip.
@immutable
class SignalConversion {
  const SignalConversion({required this.label, required this.shortLabel, this.note});

  /// Full diagram: "p010le to yuv420p", "f32le to s16".
  final String label;

  /// Strip: "10 to 8-bit", "Float to 16-bit".
  final String shortLabel;

  /// Under the pip: "4:2:0, precision lost"; for audio the output format,
  /// "16-bit integer".
  final String? note;
}

/// One encoder stage. Video uses bit depth (8, 10, 12) for wire thickness;
/// audio uses sample bits (16, 24, 32 float).
@immutable
class SignalStream {
  const SignalStream({
    required this.encoder,
    required this.detail,
    required this.codec,
    required this.inputBits,
    required this.outputBits,
    required this.availability,
    this.runsOn,
    this.conversion,
    this.formatLabel,
    this.inputLabel,
    this.outputLabel,
    this.muxProblem = false,
    this.conversionKnown = true,
  });

  /// "x264", "AAC".
  final String encoder;

  /// "CRF 18, slow", "320 kb/s".
  final String detail;

  /// Wire label after the encoder: "H.264", "AAC".
  final String codec;
  final int inputBits;
  final int outputBits;

  /// Null when it isn't known which encoder runs (Advanced mode): no state is
  /// shown.
  final VeAvailability? availability;

  /// "CPU", "NVIDIA GPU": shown with a check when the encoder is ready.
  final String? runsOn;
  final SignalConversion? conversion;

  /// The wire label when nothing converts: "10-bit 4:2:0", "32-bit float".
  final String? formatLabel;

  /// Labels either side of a video pip: "10-bit", "8-bit".
  final String? inputLabel;
  final String? outputLabel;

  /// The container can't hold this codec: the wire into it turns red and
  /// dashed and says "Can't mux".
  final bool muxProblem;

  /// False when the core hasn't said whether a conversion happens (no
  /// compile result): the wire then claims neither a pip nor "No conversion".
  final bool conversionKnown;
}

@immutable
class SignalContainer {
  const SignalContainer({required this.label, required this.detail, this.spokenLabel});

  /// "MP4"
  final String label;

  /// "Fast start", ".mkv"
  final String detail;

  /// "MP4 (H.264, HEVC, AV1…)"; defaults to [label].
  final String? spokenLabel;
}

/// Local and library differences shown on a node (popup).
@immutable
class SignalMarks {
  const SignalMarks({this.changed = false, this.libraryRevision});

  /// "Changed": edited in this template.
  final bool changed;

  /// "Revision 6": the library has a newer revision that changes this node.
  final int? libraryRevision;
}

/// Everything the diagram draws. Built from the core's signal-path facts
/// (platform C2); this class only carries display text and numbers.
@immutable
class SignalPathModel {
  const SignalPathModel({
    required this.source,
    required this.container,
    required this.fileName,
    this.video,
    this.audio,
    this.contextLabel = '',
    this.fromCommand = false,
    this.marks = const {},
  });

  final SignalSource source;

  /// Null when video is off.
  final SignalStream? video;

  /// Null when audio is off.
  final SignalStream? audio;
  final SignalContainer container;

  /// "Sample project.mp4".
  final String fileName;

  /// "Preview with: 1920×1080, 29.97 fps, 48 kHz stereo, 10 minutes".
  final String contextLabel;

  /// Advanced mode: nodes are read back from the command and drawn dashed.
  final bool fromCommand;
  final Map<SignalNode, SignalMarks> marks;

  bool get containerProblem => (video?.muxProblem ?? false) || (audio?.muxProblem ?? false);

  /// Nodes that can be selected, in arrow-key order. Audio stays selectable
  /// when it is off, so its settings can turn it back on.
  List<SignalNode> get selectable => [
    SignalNode.source,
    if (video != null) SignalNode.video,
    SignalNode.audio,
    SignalNode.container,
    SignalNode.file,
  ];
}
