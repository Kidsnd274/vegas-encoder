import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../icons.dart';
import '../../tokens.dart';
import '../interactive.dart';
import '../status.dart';
import 'signal_path_model.dart';

export 'signal_path_model.dart';

enum SignalPathLayout {
  /// Desktop: about 216 px tall, with title, legend and wire labels.
  full,

  /// Popup: one row, about 100 px tall; small nodes, short pip labels.
  strip,
}

/// The signal path (UI_SPEC §2): VEGAS, the two encoders, the container and
/// the file. Wire thickness is bit depth; an amber pip marks each format
/// conversion. Selecting a node opens its settings; arrow keys move between
/// nodes.
class SignalPath extends StatefulWidget {
  const SignalPath({
    super.key,
    required this.model,
    this.layout = SignalPathLayout.full,
    this.selected,
    this.onSelect,
    this.height,
  });

  final SignalPathModel model;
  final SignalPathLayout layout;
  final SignalNode? selected;
  final ValueChanged<SignalNode>? onSelect;

  /// Defaults to 216 (full) or 100 (strip).
  final double? height;

  static const double fullHeight = 216;
  static const double stripHeight = 100;

  @override
  State<SignalPath> createState() => _SignalPathState();
}

class _SignalPathState extends State<SignalPath> {
  final Map<SignalNode, FocusNode> _focus = {
    for (final n in SignalNode.values) n: FocusNode(debugLabel: 'signal ${n.name}'),
  };

  @override
  void dispose() {
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  bool get _strip => widget.layout == SignalPathLayout.strip;

  KeyEventResult _onKey(SignalNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final dir = (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.arrowDown)
        ? 1
        : (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowUp)
        ? -1
        : 0;
    if (dir == 0) return KeyEventResult.ignored;
    final order = widget.model.selectable;
    final i = order.indexOf(node);
    final next = order[(i + dir + order.length) % order.length];
    _focus[next]!.requestFocus();
    widget.onSelect?.call(next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final height = widget.height ?? (_strip ? SignalPath.stripHeight : SignalPath.fullHeight);
    return Semantics(
      container: true,
      label: 'Signal path',
      explicitChildNodes: true,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, box) {
            final g = _Geometry(box.maxWidth, height, _strip);
            final target = _WireValues.of(widget.model, _strip);
            return CustomPaint(
              painter: _DotGridPainter(t.colors),
              child: TweenAnimationBuilder<_WireValues>(
                tween: _WireTween(end: target),
                duration: VeTokens.motion(context, VeDurations.wire),
                curve: VeDurations.wireCurve,
                builder: (context, wires, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _WirePainter(g, wires, widget.model, t.colors, _strip)),
                    ),
                    if (!_strip) ..._header(t),
                    ..._labels(g, t),
                    ..._nodes(g, t),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------ title and legend

  List<Widget> _header(VeTokens t) {
    final c = t.colors;
    final m = widget.model;
    final style = t.text.small.copyWith(color: c.text2);
    return [
      Positioned(
        left: 22,
        top: 12,
        child: Row(
          children: [
            Text(
              m.fromCommand ? 'Read from your command' : 'Signal path',
              style: style.copyWith(color: c.ink, fontWeight: const FontWeight(600)),
            ),
            const SizedBox(width: 10),
            Text(m.fromCommand ? 'Dashed nodes show what the command sets.' : m.contextLabel, style: style),
          ],
        ),
      ),
      Positioned(
        right: 14,
        top: 8,
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: c.legendBackground, borderRadius: BorderRadius.circular(6)),
            child: DefaultTextStyle(
              style: t.text.caption.copyWith(color: c.text2),
              child: Row(
                children: [
                  _LegendWire(width: 10, color: c.videoWire),
                  const SizedBox(width: 6),
                  const Text('10-bit'),
                  const SizedBox(width: 16),
                  _LegendWire(width: 4, color: c.videoWire),
                  const SizedBox(width: 6),
                  const Text('8-bit'),
                  const SizedBox(width: 16),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: c.pip, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  const Text('Pixel format conversion'),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  // ------------------------------------------------------------ wire labels

  List<Widget> _labels(_Geometry g, VeTokens t) {
    final c = t.colors;
    final m = widget.model;
    final out = <Widget>[];
    TextStyle wl(Color color) => t.text.caption.copyWith(color: color, fontWeight: const FontWeight(550), height: 1.25);
    final sub = t.text.caption.copyWith(color: c.subText, fontWeight: const FontWeight(450), height: 1.25);

    Widget at(double x, double y, Widget child, {double dy = 0}) => Positioned(
      left: x,
      top: y,
      child: FractionalTranslation(
        translation: Offset(-0.5, dy),
        child: ExcludeSemantics(child: child),
      ),
    );

    final v = m.video;
    if (v != null) {
      final conv = v.conversion;
      if (_strip) {
        if (conv != null) out.add(at(g.pipX, g.vy - 9, _PipLabel(conv.shortLabel, small: true), dy: -1));
      } else if (conv != null) {
        out.add(at(g.pipX, g.vy - 16, _PipLabel(conv.label), dy: -1));
        if (v.inputLabel != null) {
          out.add(at((g.sx + g.pipX) / 2, g.vy + 9, Text(v.inputLabel!, style: wl(c.videoText))));
        }
        if (v.outputLabel != null) {
          out.add(at((g.pipX + g.venc.left) / 2, g.vy + 9, Text(v.outputLabel!, style: wl(c.videoText))));
        }
        if (conv.note != null) out.add(at(g.pipX, g.vy + 25, Text(conv.note!, style: sub)));
      } else {
        final mid = (g.sx + g.venc.left) / 2;
        if (v.formatLabel != null) out.add(at(mid, g.vy + 9, Text(v.formatLabel!, style: wl(c.videoText))));
        if (v.conversionKnown) out.add(at(mid, g.vy - 24, Text('No conversion', style: sub)));
      }
      if (!_strip) {
        final mx = (g.venc.right + g.cont.left) / 2;
        out.add(
          at(
            mx,
            (g.vy + g.cvy) / 2 - 24,
            Text(v.muxProblem ? 'Can’t mux' : v.codec, style: wl(v.muxProblem ? c.error : c.videoText)),
          ),
        );
      }
    }

    final a = m.audio;
    if (a != null) {
      final conv = a.conversion;
      if (_strip) {
        if (conv != null) out.add(at(g.apX, g.ay + 9, _PipLabel(conv.shortLabel, small: true)));
      } else {
        if (conv != null) {
          out.add(at(g.apX, g.ay - 13, _PipLabel(conv.label), dy: -1));
          if (conv.note != null) out.add(at(g.apX, g.ay + 8, Text(conv.note!, style: wl(c.audioText))));
        } else if (a.formatLabel != null) {
          out.add(at((g.sx + g.aenc.left) / 2, g.ay + 7, Text(a.formatLabel!, style: wl(c.audioText))));
        }
        out.add(
          at(
            (g.aenc.right + g.cont.left) / 2,
            (g.ay + g.cay) / 2 + 10,
            Text(a.muxProblem ? 'Can’t mux' : a.codec, style: wl(a.muxProblem ? c.error : c.audioText)),
          ),
        );
      }
    }
    return out;
  }

  // ------------------------------------------------------------ nodes

  List<Widget> _nodes(_Geometry g, VeTokens t) {
    final m = widget.model;
    final c = t.colors;
    final out = <Widget>[];

    Widget node(
      SignalNode id,
      Rect r,
      Widget child, {
      required String spoken,
      Color? stripe,
      bool bad = false,
      bool source = false,
      bool placeholder = false,
      String? tooltip,
    }) {
      return Positioned.fromRect(
        rect: r,
        child: _NodeBox(
          focusNode: _focus[id]!,
          selected: widget.selected == id,
          onTap: widget.onSelect == null ? null : () => widget.onSelect!(id),
          onKey: (e) => _onKey(id, e),
          spoken: spoken,
          stripe: stripe,
          bad: bad,
          dashed: placeholder || (m.fromCommand && !source),
          placeholder: placeholder,
          source: source,
          strip: _strip,
          tooltip: tooltip,
          child: child,
        ),
      );
    }

    final src = m.source;
    out.add(
      node(
        SignalNode.source,
        g.src,
        _strip
            ? _Lines(
                strip: true,
                children: [_nk(t, 'From VEGAS'), _nt(t, src.frameSize), _nd(t, src.stripVideo), _nd(t, src.stripAudio)],
              )
            : _Lines(
                strip: false,
                children: [
                  _nk(t, 'From VEGAS'),
                  _nt(t, src.frameSize),
                  _nd(t, src.frameRate),
                  _nd(t, src.pixelFormat),
                  Container(height: 1, color: c.line, margin: const EdgeInsets.symmetric(vertical: 6)),
                  _nd(t, src.audio),
                ],
              ),
        spoken: 'From VEGAS. ${src.spokenSummary}. Show details',
        source: true,
      ),
    );

    final v = m.video;
    if (v != null) {
      out.add(
        node(
          SignalNode.video,
          g.venc,
          _strip
              ? _oneRow(t, v, m.marks[SignalNode.video])
              : _encoderBody(t, 'Video encoder', v, m.marks[SignalNode.video], showRunsOn: true),
          spoken: 'Video encoder ${v.encoder}, ${v.detail}. ${v.availability.label}',
          stripe: c.videoWire,
          bad: v.availability.isProblem,
          tooltip: _strip ? '${v.encoder}, ${v.detail}' : null,
        ),
      );
    }

    final a = m.audio;
    if (a != null) {
      out.add(
        node(
          SignalNode.audio,
          g.aenc,
          _strip
              ? _oneRow(t, a, m.marks[SignalNode.audio])
              : _encoderBody(t, 'Audio encoder', a, m.marks[SignalNode.audio], showRunsOn: false),
          spoken: 'Audio encoder ${a.encoder}, ${a.detail}. ${a.availability.label}',
          stripe: c.audioWire,
          bad: a.availability.isProblem,
          tooltip: _strip ? '${a.encoder}, ${a.detail}' : null,
        ),
      );
    } else {
      // Still a node: selecting it opens the audio settings, where audio can
      // be turned back on.
      out.add(
        node(
          SignalNode.audio,
          g.aenc,
          Center(
            child: Text(
              _strip ? 'Audio off' : 'Audio is off. The file has video only.',
              style: t.text.small.copyWith(color: c.muted),
            ),
          ),
          spoken: 'Audio encoder. Audio is off; the file has video only. Show audio settings',
          placeholder: true,
        ),
      );
    }

    final cm = m.marks[SignalNode.container];
    out.add(
      node(
        SignalNode.container,
        g.cont,
        _Lines(
          strip: _strip,
          children: [
            _nk(t, 'Container', trailing: _marks(t, cm)),
            _nt(t, m.container.label),
            if (!_strip) _nd(t, m.container.detail),
          ],
        ),
        spoken: 'Container ${m.container.spokenLabel ?? m.container.label}',
        stripe: c.containerWire,
        bad: m.containerProblem,
      ),
    );

    out.add(
      node(
        SignalNode.file,
        g.file,
        _Lines(
          strip: _strip,
          children: [
            _nk(t, 'File'),
            if (!_strip)
              Text(
                m.fileName,
                style: t.text.body.copyWith(fontSize: 14, fontWeight: const FontWeight(650), height: 1.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (m.fromCommand) _nd(t, 'Name from Render As') else _SizeLink(strip: _strip),
          ],
        ),
        spoken: m.fromCommand ? 'File ${m.fileName}' : 'File ${m.fileName}. Show size and quality',
      ),
    );
    return out;
  }

  Widget _encoderBody(VeTokens t, String kind, SignalStream s, SignalMarks? marks, {required bool showRunsOn}) {
    Widget? state;
    if (s.availability != VeAvailability.ready) {
      state = VeStatusTag(s.availability);
    } else if (showRunsOn && s.runsOn != null) {
      state = VeStatusTag(VeAvailability.ready, label: s.runsOn);
    }
    final marksRow = _marks(t, marks);
    return _Lines(
      strip: false,
      children: [
        _nk(
          t,
          kind,
          trailing: (marksRow == null && state == null)
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [?marksRow, if (marksRow != null && state != null) const SizedBox(width: 8), ?state],
                ),
        ),
        _nt(t, s.encoder),
        _nd(t, s.detail),
      ],
    );
  }

  Widget _oneRow(VeTokens t, SignalStream s, SignalMarks? marks) {
    final c = t.colors;
    return Row(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 96),
          child: Text(
            s.encoder,
            style: t.text.nodeTitle.copyWith(fontSize: 14, height: 1.3),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            s.detail,
            style: t.text.caption.copyWith(color: c.nodeText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (marks != null && marks.changed) ...[
          const SizedBox(width: 8),
          Semantics(
            label: 'Changed in this template',
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
            ),
          ),
        ],
        if (marks?.libraryRevision != null) ...[
          const SizedBox(width: 8),
          _RevisionPill(marks!.libraryRevision!, short: true),
        ],
        if (s.availability != VeAvailability.ready) ...[
          const SizedBox(width: 8),
          VeStatusTag(s.availability, iconOnly: true),
        ],
      ],
    );
  }

  Widget? _marks(VeTokens t, SignalMarks? marks) {
    if (marks == null || (!marks.changed && marks.libraryRevision == null)) return null;
    final c = t.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (marks.changed)
          _strip
              ? Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Changed',
                      style: t.text.micro.copyWith(color: c.ink, fontWeight: const FontWeight(600)),
                    ),
                  ],
                ),
        if (marks.changed && marks.libraryRevision != null) const SizedBox(width: 8),
        if (marks.libraryRevision != null) _RevisionPill(marks.libraryRevision!, short: _strip),
      ],
    );
  }

  Widget _nk(VeTokens t, String text, {Widget? trailing}) {
    final style = t.text.caption.copyWith(
      color: t.colors.muted,
      fontWeight: const FontWeight(500),
      fontSize: _strip ? 11.5 : 12,
      height: 15 / (_strip ? 11.5 : 12),
    );
    return Row(
      children: [
        Expanded(
          child: Text(text, style: style, maxLines: 1, overflow: TextOverflow.clip, softWrap: false),
        ),
        ?trailing,
      ],
    );
  }

  Widget _nt(VeTokens t, String text) => Text(
    text,
    style: _strip ? t.text.nodeTitle.copyWith(fontSize: 14, height: 1.3) : t.text.nodeTitle,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );

  Widget _nd(VeTokens t, String text) => Text(
    text,
    style: (_strip ? t.text.caption : t.text.small).copyWith(color: t.colors.nodeText, height: _strip ? 1.35 : 1.4),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}

class _Lines extends StatelessWidget {
  const _Lines({required this.children, required this.strip});
  final List<Widget> children;
  final bool strip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 1), children[i]],
      ],
    );
  }
}

class _SizeLink extends StatelessWidget {
  const _SizeLink({required this.strip});
  final bool strip;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Size and quality',
          style: (strip ? t.text.caption : t.text.small).copyWith(
            color: c.ink,
            fontWeight: const FontWeight(600),
            decoration: TextDecoration.underline,
            decorationColor: c.faint,
          ),
        ),
        const SizedBox(width: 2),
        VeIcon(VeIcons.chevronRight, color: c.ink),
      ],
    );
  }
}

class _RevisionPill extends StatelessWidget {
  const _RevisionPill(this.revision, {required this.short});
  final int revision;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: short ? 6 : 7),
      decoration: BoxDecoration(color: t.colors.pip, borderRadius: BorderRadius.circular(9)),
      child: Text(
        short ? 'Rev. $revision' : 'Revision $revision',
        style: t.text.micro.copyWith(
          color: t.colors.onPip,
          fontWeight: const FontWeight(600),
          fontSize: short ? 11 : 11.5,
          height: short ? 16 / 11 : 17 / 11.5,
        ),
      ),
    );
  }
}

class _PipLabel extends StatelessWidget {
  const _PipLabel(this.text, {this.small = false});
  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 5 : 6, vertical: small ? 0 : 1),
      decoration: BoxDecoration(
        color: c.pipLabelBackground,
        border: Border.all(color: c.amberLine),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: t.text.caption.copyWith(
          color: c.pipLabelText,
          fontWeight: const FontWeight(600),
          fontSize: small ? 11.5 : 12,
          height: small ? 15 / 11.5 : 1.3,
        ),
      ),
    );
  }
}

class _LegendWire extends StatelessWidget {
  const _LegendWire({required this.width, required this.color});
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 26,
    height: 10,
    child: Center(
      child: Container(height: width, color: color),
    ),
  );
}

class _NodeBox extends StatelessWidget {
  const _NodeBox({
    required this.focusNode,
    required this.selected,
    required this.onTap,
    required this.onKey,
    required this.spoken,
    required this.child,
    required this.strip,
    this.stripe,
    this.bad = false,
    this.dashed = false,
    this.placeholder = false,
    this.source = false,
    this.tooltip,
  });

  final FocusNode focusNode;
  final bool selected;
  final VoidCallback? onTap;
  final KeyEventResult Function(KeyEvent) onKey;
  final String spoken;
  final Widget child;
  final bool strip;
  final Color? stripe;
  final bool bad;
  final bool dashed;

  /// A stage that is off: no fill or shadow until selected.
  final bool placeholder;
  final bool source;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final radius = strip ? 8.0 : 10.0;
    final pad = strip
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    return Semantics(
      button: true,
      selected: selected,
      label: spoken,
      tooltip: tooltip,
      child: VeInteractive(
        focusNode: focusNode,
        onTap: onTap,
        onKeyEvent: (_, e) => onKey(e),
        builder: (context, s) {
          final borderColor = bad ? c.error : (selected ? c.ink : (s.hovered ? c.lineHover : c.line2));
          final background = bad
              ? c.errorBackground
              : placeholder
              ? const Color(0x00000000)
              : (source ? c.surface2 : c.surface);
          final width = selected ? 2.0 : 1.0;
          // Node sizes are fixed by the layout; at large text scales the
          // content is clipped rather than overflowing the box.
          final align = strip && !source ? Alignment.centerLeft : Alignment.topLeft;
          final inner = Padding(
            padding: pad - EdgeInsets.all(width - 1),
            child: ClipRect(
              child: OverflowBox(alignment: align, minHeight: 0, maxHeight: double.infinity, child: child),
            ),
          );
          Widget box;
          if (dashed && !selected) {
            box = CustomPaint(
              painter: DashedRRectPainter(color: borderColor, radius: radius, fill: background, dash: 5, gap: 4),
              child: inner,
            );
          } else {
            box = DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                border: Border.all(color: borderColor, width: width),
                borderRadius: BorderRadius.circular(radius),
                boxShadow: selected ? t.raisedShadow : t.restingShadow,
              ),
              child: inner,
            );
          }
          return VeFocusRing(
            visible: s.focused,
            radius: radius,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: box),
                if (stripe != null)
                  Positioned(
                    left: 0,
                    top: strip ? 8 : 12,
                    bottom: strip ? 8 : 12,
                    width: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: stripe,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Node rectangles and wire anchors (`layoutFor` in the mockup).
class _Geometry {
  _Geometry(double w, double h, bool strip) {
    if (strip) {
      const pad = 14.0, top = 10.0, eh = 36.0;
      src = Rect.fromLTWH(pad, top, 132, h - 2 * top);
      final vx = (w * 0.3).roundToDouble();
      venc = Rect.fromLTWH(vx, top, 164, eh);
      aenc = Rect.fromLTWH(vx, h - top - eh, 164, eh);
      final fy = (h / 2 - 25).roundToDouble();
      file = Rect.fromLTWH(w - pad - 158, fy, 158, 50);
      cont = Rect.fromLTWH(((venc.right + file.left) / 2 - 46).roundToDouble(), fy, 92, 50);
    } else {
      const pad = 22.0, top = 38.0, nh = 72.0;
      src = Rect.fromLTWH(pad, top, 188, h - top - 14);
      final vx = (w * 0.33).roundToDouble();
      venc = Rect.fromLTWH(vx, top, 236, nh);
      aenc = Rect.fromLTWH(vx, h - 14 - nh, 236, nh);
      final fileX = w - pad - 184;
      final cx = ((venc.right + fileX) / 2 - 75).roundToDouble();
      final cy = ((venc.center.dy + aenc.center.dy) / 2 - 42).roundToDouble();
      cont = Rect.fromLTWH(cx, cy, 150, 84);
      file = Rect.fromLTWH(fileX, (cont.center.dy - 36).roundToDouble(), 184, 72);
    }
    sx = src.right;
    vy = venc.center.dy;
    ay = aenc.center.dy;
    cvy = cont.top + cont.height * 0.36;
    cay = cont.top + cont.height * 0.72;
    pipX = (sx + (venc.left - sx) * 0.5).roundToDouble();
    apX = (sx + (aenc.left - sx) * 0.5).roundToDouble();
  }

  late final Rect src, venc, aenc, cont, file;
  late final double sx, vy, ay, cvy, cay, pipX, apX;
}

/// Animated wire values: thickness by bit depth, pip size, stream visibility.
@immutable
class _WireValues {
  const _WireValues(this.vIn, this.vOut, this.aIn, this.aOut, this.pip, this.aPip, this.vShow, this.aShow);

  factory _WireValues.of(SignalPathModel m, bool strip) {
    final k = strip ? 0.6 : 1.0;
    double vw(int d) => (d >= 10 ? 10 : 4) * k;
    double aw(int b) =>
        (b >= 32
            ? 6
            : b >= 24
            ? 5
            : 2.5) *
        k;
    final v = m.video, a = m.audio;
    return _WireValues(
      vw(m.source.depth),
      v == null ? 4 * k : vw(v.outputBits),
      aw(a?.inputBits ?? 32),
      a == null ? 3 * k : aw(a.outputBits),
      v?.conversion != null ? (strip ? 7 : 10) : 0,
      a?.conversion != null ? (strip ? 6 : 8) : 0,
      v == null ? 0 : 1,
      a == null ? 0 : 1,
    );
  }

  final double vIn, vOut, aIn, aOut, pip, aPip, vShow, aShow;

  static _WireValues lerp(_WireValues a, _WireValues b, double t) => _WireValues(
    lerpDouble(a.vIn, b.vIn, t)!,
    lerpDouble(a.vOut, b.vOut, t)!,
    lerpDouble(a.aIn, b.aIn, t)!,
    lerpDouble(a.aOut, b.aOut, t)!,
    lerpDouble(a.pip, b.pip, t)!,
    lerpDouble(a.aPip, b.aPip, t)!,
    lerpDouble(a.vShow, b.vShow, t)!,
    lerpDouble(a.aShow, b.aShow, t)!,
  );

  @override
  bool operator ==(Object o) =>
      o is _WireValues &&
      o.vIn == vIn &&
      o.vOut == vOut &&
      o.aIn == aIn &&
      o.aOut == aOut &&
      o.pip == pip &&
      o.aPip == aPip &&
      o.vShow == vShow &&
      o.aShow == aShow;

  @override
  int get hashCode => Object.hash(vIn, vOut, aIn, aOut, pip, aPip, vShow, aShow);
}

class _WireTween extends Tween<_WireValues> {
  _WireTween({required super.end});
  @override
  _WireValues lerp(double t) => _WireValues.lerp(begin ?? end!, end!, t);
}

class _WirePainter extends CustomPainter {
  _WirePainter(this.g, this.w, this.m, this.c, this.strip);
  final _Geometry g;
  final _WireValues w;
  final SignalPathModel m;
  final VePalette c;
  final bool strip;

  Path _curve(double x1, double y1, double x2, double y2) {
    final dx = math.max(24.0, (x2 - x1) * 0.5);
    return Path()
      ..moveTo(x1, y1)
      ..cubicTo(x1 + dx, y1, x2 - dx, y2, x2, y2);
  }

  void _stroke(Canvas canvas, Path p, Color color, double width, {bool dashed = false}) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    if (!dashed) {
      canvas.drawPath(p, paint);
      return;
    }
    for (final metric in p.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 11) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = g.cont.left;
    final pr = strip ? 4.0 : 5.0;

    void port(double x, double y, Color color, double opacity) {
      if (opacity <= 0) return;
      canvas.drawCircle(Offset(x, y), pr, Paint()..color = color.withValues(alpha: opacity));
      canvas.drawCircle(
        Offset(x, y),
        pr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = c.surface.withValues(alpha: opacity),
      );
    }

    // Video.
    if (w.vShow > 0) {
      final vc = c.videoWire.withValues(alpha: w.vShow);
      _stroke(
        canvas,
        Path()
          ..moveTo(g.sx, g.vy)
          ..lineTo(g.pipX, g.vy),
        vc,
        w.vIn,
      );
      _stroke(
        canvas,
        Path()
          ..moveTo(g.pipX, g.vy)
          ..lineTo(g.venc.left, g.vy),
        vc,
        w.vOut,
      );
      final bad = m.video?.muxProblem ?? false;
      _stroke(
        canvas,
        _curve(g.venc.right, g.vy, cx, g.cvy),
        bad ? c.error.withValues(alpha: w.vShow) : vc,
        w.vOut,
        dashed: bad,
      );
      if (w.pip > 0.1) {
        canvas.drawCircle(Offset(g.pipX, g.vy), w.pip, Paint()..color = c.pip.withValues(alpha: w.vShow));
        canvas.drawCircle(
          Offset(g.pipX, g.vy),
          w.pip,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = c.paper.withValues(alpha: w.vShow),
        );
      }
    }

    // Audio.
    if (w.aShow > 0) {
      final ac = c.audioWire.withValues(alpha: w.aShow);
      _stroke(
        canvas,
        Path()
          ..moveTo(g.sx, g.ay)
          ..lineTo(g.apX, g.ay),
        ac,
        w.aIn,
      );
      _stroke(
        canvas,
        Path()
          ..moveTo(g.apX, g.ay)
          ..lineTo(g.aenc.left, g.ay),
        ac,
        w.aOut,
      );
      final bad = m.audio?.muxProblem ?? false;
      _stroke(
        canvas,
        _curve(g.aenc.right, g.ay, cx, g.cay),
        bad ? c.error.withValues(alpha: w.aShow) : ac,
        w.aOut,
        dashed: bad,
      );
      if (w.aPip > 0.1) {
        canvas.drawCircle(Offset(g.apX, g.ay), w.aPip, Paint()..color = c.pip.withValues(alpha: w.aShow));
        canvas.drawCircle(
          Offset(g.apX, g.ay),
          w.aPip,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = c.paper.withValues(alpha: w.aShow),
        );
      }
    }

    // Container to file.
    final cmid = g.cont.center.dy;
    _stroke(
      canvas,
      Path()
        ..moveTo(g.cont.right, cmid)
        ..lineTo(g.file.left, g.file.center.dy),
      c.containerWire,
      5 * (strip ? 0.6 : 1),
    );

    port(g.sx, g.vy, c.videoWire, w.vShow);
    port(g.sx, g.ay, c.audioWire, w.aShow);
    port(g.venc.left, g.vy, c.videoWire, w.vShow);
    port(g.venc.right, g.vy, c.videoWire, w.vShow);
    port(g.aenc.left, g.ay, c.audioWire, w.aShow);
    port(g.aenc.right, g.ay, c.audioWire, w.aShow);
    port(cx, g.cvy, c.videoWire, w.vShow);
    port(cx, g.cay, c.audioWire, w.aShow);
    port(g.cont.right, cmid, c.containerWire, 1);
    port(g.file.left, g.file.center.dy, c.containerWire, 1);
  }

  @override
  bool shouldRepaint(_WirePainter old) =>
      old.w != w ||
      old.c != c ||
      old.m != m ||
      old.strip != strip ||
      old.g.src != g.src ||
      old.g.venc != g.venc ||
      old.g.cont != g.cont ||
      old.g.file != g.file;
}

/// Paper with grid dots every 16 px (`.dgw`).
class _DotGridPainter extends CustomPainter {
  _DotGridPainter(this.c);
  final VePalette c;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = c.paper);
    final dot = Paint()..color = c.dots;
    for (var y = 8.0; y < size.height; y += 16) {
      for (var x = 8.0; x < size.width; x += 16) {
        canvas.drawCircle(Offset(x, y), 1.25, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.c != c;
}
