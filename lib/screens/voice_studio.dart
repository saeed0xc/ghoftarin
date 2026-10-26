import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../audio/mic.dart';
import '../data/coach_lines.dart';
import '../data/partner_scenes.dart';
import '../fa.dart';
import '../theme.dart';
import '../widgets/visuals.dart';

/// Voice studio: a person reads every line the app speaks (coach and
/// conversation partner) and exports the takes as one zip, which replaces
/// the synthetic voice in the next build. Takes stay in memory only, so
/// export before closing; a partial export is fine.
class VoiceStudioScreen extends StatefulWidget {
  const VoiceStudioScreen({super.key});

  @override
  State<VoiceStudioScreen> createState() => _VoiceStudioScreenState();
}

class _Line {
  final String id; // file name without extension
  final String group;
  final String text;
  const _Line(this.id, this.group, this.text);
}

final List<_Line> _lines = [
  for (final e in coachLines.entries)
    _Line('coach/${e.key}', 'راهنمای صوتی', e.value),
  for (final s in partnerScenes)
    for (var i = 0; i < s.turns.length; i++)
      _Line('partner/${s.id}-$i', '${s.title} · ${s.role}', s.turns[i].partner),
];

const _rate = 24000;

class _VoiceStudioScreenState extends State<VoiceStudioScreen> {
  final _mic = Mic()..cleanVoice = true;
  AudioPlayer? _player;
  final Map<String, Float32List> _takes = {};
  int _i = 0;
  bool _recording = false;
  final List<double> _buf = [];
  double _level = 0;

  _Line get _line => _lines[_i];

  @override
  void dispose() {
    _mic.dispose();
    _player?.dispose();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_recording) {
      await _mic.stop();
      final take = _trim(_buf);
      setState(() {
        _recording = false;
        if (take.isNotEmpty) _takes[_line.id] = take;
      });
      if (take.isNotEmpty) await _play();
      return;
    }
    await _player?.stop();
    if (!await _mic.ensurePermission()) {
      _snack('برای ضبط، اجازه‌ی میکروفون لازم است.');
      return;
    }
    _buf.clear();
    setState(() => _recording = true);
    WakelockPlus.enable().catchError((_) {});
    await _mic.start((x) {
      _buf.addAll(x);
      var peak = 0.0;
      for (final v in x) {
        final a = v.abs();
        if (a > peak) peak = a;
      }
      if (mounted) setState(() => _level = peak);
    }, sampleRate: _rate);
  }

  /// Cuts silence at both ends (keeping 120 ms of room tone) and evens the
  /// loudness, so every take sounds alike.
  static Float32List _trim(List<double> x) {
    if (x.length < _rate ~/ 4) return Float32List(0);
    final win = _rate ~/ 50;
    var noise = 0.0;
    for (var i = 0; i < win * 10 && i < x.length; i++) {
      noise = noise > x[i].abs() ? noise : x[i].abs();
    }
    final th = (noise * 3).clamp(0.01, 0.2);
    var a = 0, b = x.length - 1;
    while (a < x.length && x[a].abs() < th) {
      a++;
    }
    while (b > a && x[b].abs() < th) {
      b--;
    }
    if (b - a < _rate ~/ 5) return Float32List(0);
    a = (a - _rate * 12 ~/ 100).clamp(0, x.length);
    b = (b + _rate * 12 ~/ 100).clamp(0, x.length - 1);
    var peak = 0.0;
    for (var i = a; i <= b; i++) {
      if (x[i].abs() > peak) peak = x[i].abs();
    }
    final g = peak > 0 ? (0.8 / peak).clamp(0.5, 8.0) : 1.0;
    return Float32List.fromList([
      for (var i = a; i <= b; i++) (x[i] * g).clamp(-1.0, 1.0),
    ]);
  }

  static Uint8List _wav(Float32List s) {
    final n = s.length;
    final b = ByteData(44 + n * 2);
    void str(int o, String t) {
      for (var i = 0; i < t.length; i++) {
        b.setUint8(o + i, t.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    b.setUint32(4, 36 + n * 2, Endian.little);
    str(8, 'WAVEfmt ');
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little);
    b.setUint16(22, 1, Endian.little);
    b.setUint32(24, _rate, Endian.little);
    b.setUint32(28, _rate * 2, Endian.little);
    b.setUint16(32, 2, Endian.little);
    b.setUint16(34, 16, Endian.little);
    str(36, 'data');
    b.setUint32(40, n * 2, Endian.little);
    for (var i = 0; i < n; i++) {
      b.setInt16(44 + i * 2, (s[i] * 32767).round(), Endian.little);
    }
    return b.buffer.asUint8List();
  }

  Future<void> _play() async {
    final t = _takes[_line.id];
    if (t == null) return;
    try {
      final p = _player ??= AudioPlayer();
      await p.stop();
      await p.play(BytesSource(_wav(t), mimeType: 'audio/wav'));
    } catch (_) {}
  }

  void _go(int d) {
    if (_recording) return;
    setState(() => _i = (_i + d).clamp(0, _lines.length - 1));
  }

  Future<void> _export() async {
    if (_takes.isEmpty) return;
    final arc = Archive();
    for (final e in _takes.entries) {
      final w = _wav(e.value);
      arc.addFile(ArchiveFile('${e.key}.wav', w.length, w));
    }
    final manifest = utf8.encode(
      jsonEncode({
        'app': 'goftarin-voice',
        'rate': _rate,
        'lines': {
          for (final l in _lines)
            if (_takes.containsKey(l.id)) l.id: l.text,
        },
      }),
    );
    arc.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    final zip = Uint8List.fromList(ZipEncoder().encode(arc));
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            zip,
            name: 'goftarin-voice.zip',
            mimeType: 'application/zip',
          ),
        ],
        fileNameOverrides: ['goftarin-voice.zip'],
        subject: 'صدای ضبط‌شده‌ی گفتارین',
      ),
    );
  }

  void _snack(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  @override
  Widget build(BuildContext context) {
    final has = _takes.containsKey(_line.id);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'استودیوی صدا',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton.icon(
            onPressed: _takes.isEmpty ? null : _export,
            icon: const Icon(Icons.ios_share),
            label: const Text('خروجی'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LessonProgress(value: _takes.length / _lines.length),
              const SizedBox(height: 6),
              Text(
                '${faNum(_takes.length)} از ${faNum(_lines.length)} جمله ضبط شده · جمله‌ی ${faNum(_i + 1)}',
                style: const TextStyle(fontSize: 13, color: C.muted),
              ),
              const SizedBox(height: 12),
              const AppCard(
                color: C.blueBg,
                border: false,
                child: Text(
                  'آرام، گرم و کمی آهسته‌تر از معمول بخوان، با شروع نرم؛ مثل کسی که حوصله دارد. '
                  'جای ساکت، گوشی حدود ۲۰ سانتی‌متر جلوی دهان. بعد از هر ضبط، خودش پخش می‌شود.',
                  style: TextStyle(fontSize: 13, height: 1.8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _line.group,
                style: const TextStyle(
                  fontSize: 13,
                  color: C.blueDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    border: Border.all(color: has ? C.brand : C.line, width: 2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Text(
                        _line.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          height: 1.9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_recording)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _level.clamp(0.0, 1.0),
                    minHeight: 8,
                    color: _level > 0.95 ? C.warn : C.brand,
                    backgroundColor: C.line,
                  ),
                ),
              const SizedBox(height: 12),
              ChunkyButton(
                label: _recording ? 'پایان ضبط' : (has ? 'ضبط دوباره' : 'ضبط'),
                icon: _recording ? Icons.stop : Icons.mic,
                color: _recording ? C.warn : C.brand,
                shadow: _recording ? const Color(0xFFB71C1C) : C.brandDark,
                onPressed: _toggle,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _i > 0 && !_recording ? () => _go(-1) : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('قبلی'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: has && !_recording ? _play : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('پخش'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _i < _lines.length - 1 && !_recording
                          ? () => _go(1)
                          : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('بعدی'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
