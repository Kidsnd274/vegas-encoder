import 'package:flutter_test/flutter_test.dart';
import 'package:vegas_encoder/design/format.dart';

void main() {
  test('bytes use decimal units and three significant figures, like the prototype', () {
    expect(VeFormat.bytes(0), '0 B');
    expect(VeFormat.bytes(537000000), '537 MB');
    expect(VeFormat.bytes(53700000), '53.7 MB');
    expect(VeFormat.bytes(2930000000), '2.93 GB');
    expect(VeFormat.bytes(999), '999 B');
    expect(VeFormat.bytes(1000), '1.00 KB');
  });

  test('rates switch to Mb/s at 1000 kb/s', () {
    expect(VeFormat.rate(320), '320 kb/s');
    expect(VeFormat.rate(8000), '8 Mb/s');
    expect(VeFormat.rate(6840), '6.8 Mb/s');
    expect(VeFormat.rate(30700), '30.7 Mb/s');
  });

  test('durations are m:ss or h:mm:ss', () {
    expect(VeFormat.duration(600), '10:00');
    expect(VeFormat.duration(763), '12:43');
    expect(VeFormat.duration(3723), '1:02:03');
    expect(VeFormat.duration(5), '0:05');
  });

  test('frame rates drop trailing zeros', () {
    expect(VeFormat.fps(30000, 1001), '29.97 fps');
    expect(VeFormat.fps(25, 1), '25 fps');
    expect(VeFormat.fps(24000, 1001), '23.976 fps');
  });

  test('counts group thousands', () {
    expect(VeFormat.count(9607), '9,607');
    expect(VeFormat.count(22873), '22,873');
    expect(VeFormat.count(1000000), '1,000,000');
    expect(VeFormat.count(12), '12');
  });

  test('typed lengths accept m:ss, h:mm:ss and plain minutes', () {
    expect(VeFormat.parseLength('10:00'), 600);
    expect(VeFormat.parseLength(' 1:02:03 '), 3723);
    expect(VeFormat.parseLength('12.5'), 750);
    expect(VeFormat.parseLength('7'), 420);
    expect(VeFormat.parseLength('10:75'), isNull);
    expect(VeFormat.parseLength('ten'), isNull);
    expect(VeFormat.parseLength(''), isNull);
  });
}
