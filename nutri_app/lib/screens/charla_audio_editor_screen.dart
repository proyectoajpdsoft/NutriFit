import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nutri_app/models/charla_diapositiva.dart';
import 'package:nutri_app/models/charla_seminario.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

class _TimelineItem {
  _TimelineItem({
    required this.uid,
    required this.slide,
    required this.duracionSeg,
  });

  final int uid;
  final CharlaDiapositiva slide;
  double duracionSeg;
}

class _DragPayload {
  const _DragPayload.source(this.slide)
      : timelineUid = null,
        fromTimeline = false;

  const _DragPayload.timeline(this.timelineUid)
      : slide = null,
        fromTimeline = true;

  final CharlaDiapositiva? slide;
  final int? timelineUid;
  final bool fromTimeline;
}

class _CharlaAudioEditorState extends ChangeNotifier {
  _CharlaAudioEditorState({
    required this.charla,
    required this.apiService,
  });

  final CharlaSeminario charla;
  final ApiService apiService;

  final List<CharlaDiapositiva> sourceSlides = <CharlaDiapositiva>[];
  final List<_TimelineItem> timelineItems = <_TimelineItem>[];
  int? selectedTimelineUid;
  int _nextUid = 1;

  String? audioGlobalBase64;
  String? audioGlobalNombre;
  String? audioGlobalMime;

  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();

  PlayerState playerState = PlayerState.stopped;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool loading = false;
  bool saving = false;
  bool isRecording = false;

  String? _recordingPath;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;

  int get selectedTimelineIndex {
    if (selectedTimelineUid == null) return -1;
    return timelineItems.indexWhere((e) => e.uid == selectedTimelineUid);
  }

  _TimelineItem? get selectedTimelineItem {
    final idx = selectedTimelineIndex;
    if (idx < 0 || idx >= timelineItems.length) return null;
    return timelineItems[idx];
  }

  bool get hasAudioConfigured =>
      audioGlobalBase64 != null && audioGlobalBase64!.isNotEmpty;

  double get fixedTimelineDurationSeg {
    if (hasAudioConfigured && duration.inMilliseconds > 0) {
      return duration.inMilliseconds / 1000.0;
    }
    if (!hasAudioConfigured) {
      return timelineItems.isEmpty ? 0.0 : timelineItems.length * 8.0;
    }
    return totalDuracionSeg > 0 ? totalDuracionSeg : timelineItems.length * 8.0;
  }

  double get totalDuracionSeg =>
      timelineItems.fold(0.0, (a, b) => a + b.duracionSeg);

  void initPlayer() {
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      playerState = state;
      if (state == PlayerState.completed) {
        // Mantener el cursor al final para poder decidir reinicio o seek.
        position = duration;
      }
      notifyListeners();
    });

    _posSub = _player.onPositionChanged.listen((p) {
      position = p;
      _syncSelectedFromAudioPosition();
      notifyListeners();
    });

    _durSub = _player.onDurationChanged.listen((d) {
      duration = d;
      if (hasAudioConfigured &&
          d.inMilliseconds > 0 &&
          timelineItems.isNotEmpty) {
        _rescaleTimelineTo(d.inMilliseconds / 1000.0);
      }
      notifyListeners();
    });
  }

  void _rescaleTimelineTo(double targetTotalSeg) {
    if (timelineItems.isEmpty || targetTotalSeg <= 0) return;
    final currentTotal = totalDuracionSeg;
    if (currentTotal <= 0) {
      final even = targetTotalSeg / timelineItems.length;
      for (final item in timelineItems) {
        item.duracionSeg = even;
      }
      return;
    }
    final factor = targetTotalSeg / currentTotal;
    for (final item in timelineItems) {
      item.duracionSeg = math.max(0.5, item.duracionSeg * factor);
    }
  }

  Future<void> loadData() async {
    loading = true;
    notifyListeners();

    try {
      final respSlides = await apiService.get(
        'api/charlas_seminarios.php?diapositivas=${charla.codigo}',
      );

      if (respSlides.statusCode == 200) {
        final list = jsonDecode(respSlides.body) as List<dynamic>;
        sourceSlides
          ..clear()
          ..addAll(
            list
                .map((e) => CharlaDiapositiva.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList(growable: false),
          );
      }

      final respCharla = await apiService.get(
        'api/charlas_seminarios.php?codigo=${charla.codigo}',
      );

      dynamic timelineRaw;
      if (respCharla.statusCode == 200) {
        final data =
            Map<String, dynamic>.from(jsonDecode(respCharla.body) as Map);
        audioGlobalBase64 = data['audio_global']?.toString();
        audioGlobalNombre = data['audio_global_nombre']?.toString();
        audioGlobalMime = data['audio_global_mime']?.toString();
        timelineRaw = data['timeline_presentacion_json'];
      }

      _buildTimelineFromData(timelineRaw);
    } catch (_) {
      // Mantener estado recuperable.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _buildTimelineFromData(dynamic timelineRaw) {
    timelineItems.clear();

    final byCode = <int, CharlaDiapositiva>{
      for (final slide in sourceSlides)
        if (slide.codigo != null) slide.codigo!: slide,
    };

    List<dynamic> parsed = <dynamic>[];
    if (timelineRaw is String && timelineRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(timelineRaw);
        if (decoded is List) parsed = decoded;
      } catch (_) {}
    } else if (timelineRaw is List) {
      parsed = timelineRaw;
    }

    if (parsed.isNotEmpty) {
      for (final item in parsed) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final codigo =
            int.tryParse((map['codigo_diapositiva'] ?? '').toString());
        if (codigo == null || !byCode.containsKey(codigo)) continue;

        final dur =
            double.tryParse((map['duracion_seg'] ?? '').toString()) ?? 5.0;
        timelineItems.add(
          _TimelineItem(
            uid: _nextUid++,
            slide: byCode[codigo]!,
            duracionSeg: dur <= 0 ? 5.0 : dur,
          ),
        );
      }
    }

    if (timelineItems.isEmpty) {
      for (final slide in sourceSlides) {
        timelineItems.add(
          _TimelineItem(
            uid: _nextUid++,
            slide: slide,
            duracionSeg: 8.0,
          ),
        );
      }
    }

    selectedTimelineUid =
        timelineItems.isEmpty ? null : timelineItems.first.uid;

    if (!hasAudioConfigured && timelineItems.isNotEmpty) {
      _rescaleTimelineTo(timelineItems.length * 8.0);
    }
  }

  void addSourceSlideToTimeline(CharlaDiapositiva slide, {int? insertAt}) {
    final idx = insertAt == null
        ? timelineItems.length
        : insertAt.clamp(0, timelineItems.length);

    timelineItems.insert(
      idx,
      _TimelineItem(uid: _nextUid++, slide: slide, duracionSeg: 8.0),
    );
    selectedTimelineUid = timelineItems[idx].uid;
    if (fixedTimelineDurationSeg > 0) {
      _rescaleTimelineTo(fixedTimelineDurationSeg);
    }
    notifyListeners();
  }

  void moveTimelineItem(int uid, int targetIndex) {
    final currentIndex = timelineItems.indexWhere((e) => e.uid == uid);
    if (currentIndex < 0) return;

    final safeTarget = targetIndex.clamp(0, timelineItems.length);
    final item = timelineItems.removeAt(currentIndex);
    final adjustedTarget =
        currentIndex < safeTarget ? safeTarget - 1 : safeTarget;
    timelineItems.insert(adjustedTarget, item);

    selectedTimelineUid = item.uid;
    notifyListeners();
  }

  void removeTimelineItem(int uid) {
    final idx = timelineItems.indexWhere((e) => e.uid == uid);
    if (idx < 0) return;

    timelineItems.removeAt(idx);
    if (selectedTimelineUid == uid) {
      selectedTimelineUid = timelineItems.isEmpty
          ? null
          : timelineItems[math.max(0, math.min(idx, timelineItems.length - 1))]
              .uid;
    }
    notifyListeners();
  }

  void selectTimelineItem(int uid) {
    selectedTimelineUid = uid;
    notifyListeners();
  }

  int insertionIndexForDx(double dx, double trackWidth) {
    if (timelineItems.isEmpty || trackWidth <= 0) return 0;
    final total = fixedTimelineDurationSeg <= 0
        ? totalDuracionSeg
        : fixedTimelineDurationSeg;
    if (total <= 0) return timelineItems.length;

    var accPx = 0.0;
    for (var i = 0; i < timelineItems.length; i++) {
      final itemWidth = (timelineItems[i].duracionSeg / total) * trackWidth;
      if (dx < accPx + (itemWidth / 2)) {
        return i;
      }
      accPx += itemWidth;
    }
    return timelineItems.length;
  }

  void adjustBoundaryByIndex(int index, double deltaPx, double trackWidth) {
    if (index < 0 || index >= timelineItems.length - 1 || trackWidth <= 0) {
      return;
    }

    final total = fixedTimelineDurationSeg;
    if (total <= 0) return;

    final current = timelineItems[index];
    final next = timelineItems[index + 1];
    final desiredDelta = (deltaPx / trackWidth) * total;
    final maxGrow = next.duracionSeg - 0.5;
    final maxShrink = current.duracionSeg - 0.5;
    final appliedDelta = desiredDelta.clamp(-maxShrink, maxGrow);

    current.duracionSeg += appliedDelta;
    next.duracionSeg -= appliedDelta;
    notifyListeners();
  }

  int timelineIndexAtPosition(Duration pos) {
    if (timelineItems.isEmpty) return -1;
    final secs = pos.inMilliseconds / 1000.0;
    var acc = 0.0;
    for (var i = 0; i < timelineItems.length; i++) {
      acc += timelineItems[i].duracionSeg;
      if (secs < acc) return i;
    }
    return timelineItems.length - 1;
  }

  void _syncSelectedFromAudioPosition() {
    final idx = timelineIndexAtPosition(position);
    if (idx < 0 || idx >= timelineItems.length) return;
    final uid = timelineItems[idx].uid;
    if (uid != selectedTimelineUid) {
      selectedTimelineUid = uid;
    }
  }

  Uint8List? _audioBytes() {
    if (audioGlobalBase64 == null || audioGlobalBase64!.isEmpty) {
      return null;
    }
    try {
      return base64Decode(audioGlobalBase64!);
    } catch (_) {
      return null;
    }
  }

  Duration _normalizeTarget(Duration target) {
    if (target.isNegative) return Duration.zero;
    if (duration.inMilliseconds <= 0) return target;

    final maxMs = math.max(0, duration.inMilliseconds - 120);
    final next = target.inMilliseconds.clamp(0, maxMs);
    return Duration(milliseconds: next);
  }

  Future<void> playPause() async {
    final bytes = _audioBytes();
    if (bytes == null) return;

    if (playerState == PlayerState.playing) {
      await _player.pause();
      return;
    }

    // Si quedó al final, reiniciar a 0 o al seek actual válido.
    final atEnd = duration.inMilliseconds > 0 &&
        position.inMilliseconds >= duration.inMilliseconds - 50;
    final target = atEnd ? Duration.zero : _normalizeTarget(position);

    await _player.play(BytesSource(bytes));
    if (target > Duration.zero) {
      await _player.seek(target);
      position = target;
      _syncSelectedFromAudioPosition();
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    position = Duration.zero;
    _syncSelectedFromAudioPosition();
    notifyListeners();
  }

  Future<void> seekTo(Duration target) async {
    final safe = _normalizeTarget(target);
    await _player.seek(safe);
    position = safe;
    _syncSelectedFromAudioPosition();
    notifyListeners();
  }

  Future<void> pickAudioGlobal() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['m4a', 'aac', 'mp3', 'wav'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;

    final ext = (file.extension ?? '').toLowerCase();
    final mime = switch (ext) {
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'aac' => 'audio/aac',
      _ => 'audio/mp4',
    };

    await _player.stop();
    audioGlobalBase64 = base64Encode(bytes);
    audioGlobalNombre = file.name;
    audioGlobalMime = mime;
    position = Duration.zero;
    duration = Duration.zero;
    notifyListeners();
  }

  Future<void> clearAudioGlobal() async {
    await _player.stop();
    audioGlobalBase64 = null;
    audioGlobalNombre = null;
    audioGlobalMime = null;
    position = Duration.zero;
    duration = Duration.zero;
    if (timelineItems.isNotEmpty) {
      _rescaleTimelineTo(timelineItems.length * 8.0);
    }
    notifyListeners();
  }

  Future<void> startRecordingGlobal() async {
    if (Platform.isWindows) {
      await _launchWindowsVoiceRecorder();
      return;
    }

    final permission = await Permission.microphone.request();
    if (!permission.isGranted) return;

    final tmp = await getTemporaryDirectory();
    _recordingPath =
        '${tmp.path}/charla_global_${charla.codigo}_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _recordingPath!,
    );

    isRecording = true;
    notifyListeners();
  }

  Future<void> _launchWindowsVoiceRecorder() async {
    final uri = Uri.parse('ms-voicerecorder:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> stopRecordingGlobal() async {
    final filePath = await _recorder.stop();
    isRecording = false;

    final effectivePath = filePath ?? _recordingPath;
    _recordingPath = null;

    if (effectivePath == null) {
      notifyListeners();
      return;
    }

    final file = File(effectivePath);
    if (!await file.exists()) {
      notifyListeners();
      return;
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      notifyListeners();
      return;
    }

    await _player.stop();
    audioGlobalBase64 = base64Encode(bytes);
    audioGlobalNombre = 'charla_global_${charla.codigo}.m4a';
    audioGlobalMime = 'audio/mp4';
    position = Duration.zero;
    duration = Duration.zero;
    notifyListeners();
  }

  Future<bool> saveConfig() async {
    saving = true;
    notifyListeners();

    try {
      final timelineData = <Map<String, dynamic>>[];
      for (final item in timelineItems) {
        final codigo = item.slide.codigo;
        if (codigo == null) continue;
        timelineData.add({
          'codigo_diapositiva': codigo,
          'duracion_seg': item.duracionSeg,
        });
      }

      // Compatibilidad con backend anterior: versión deduplicada por diapositiva.
      final uniqueBySlide = <int, Map<String, dynamic>>{};
      var numero = 1;
      for (final item in timelineItems) {
        final codigo = item.slide.codigo;
        if (codigo == null) continue;
        if (uniqueBySlide.containsKey(codigo)) continue;
        uniqueBySlide[codigo] = {
          'codigo': codigo,
          'numero_diapositiva': numero++,
          'duracion_presentacion_seg': item.duracionSeg,
        };
      }

      final response = await apiService.put(
        'api/charlas_seminarios.php?audio_config=${charla.codigo}',
        body: jsonEncode(<String, dynamic>{
          'timeline_items': timelineData,
          'diapositivas': uniqueBySlide.values.toList(growable: false),
          if (audioGlobalBase64 != null && audioGlobalBase64!.isNotEmpty)
            'audio_global': audioGlobalBase64,
          if (audioGlobalNombre != null)
            'audio_global_nombre': audioGlobalNombre,
          if (audioGlobalMime != null) 'audio_global_mime': audioGlobalMime,
          if (audioGlobalBase64 == null || audioGlobalBase64!.isEmpty)
            'clear_audio_global': 1,
        }),
      );

      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }
}

class CharlaAudioEditorScreen extends StatefulWidget {
  const CharlaAudioEditorScreen({super.key, required this.charla});

  final CharlaSeminario charla;

  @override
  State<CharlaAudioEditorScreen> createState() =>
      _CharlaAudioEditorScreenState();
}

class _CharlaAudioEditorScreenState extends State<CharlaAudioEditorScreen> {
  late final _CharlaAudioEditorState _state;

  @override
  void initState() {
    super.initState();
    _state = _CharlaAudioEditorState(
      charla: widget.charla,
      apiService: context.read<ApiService>(),
    );
    _state.initPlayer();
    _state.loadData();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<_CharlaAudioEditorState>.value(
      value: _state,
      child: const _EditorBody(),
    );
  }
}

class _EditorBody extends StatelessWidget {
  const _EditorBody();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<_CharlaAudioEditorState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Presentación: ${state.charla.titulo}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (state.saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: () async {
                final ok = await state.saveConfig();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Configuración guardada.'
                        : 'Error al guardar la configuración.'),
                    backgroundColor: ok ? Colors.green : Colors.red,
                  ),
                );
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  const _SourceCarousel(),
                  const SizedBox(height: 6),
                  const Expanded(child: _TimelineEditor()),
                  Container(
                    color: Colors.grey.shade50,
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.audioGlobalBase64 != null &&
                            state.audioGlobalBase64!.isNotEmpty)
                          Slider(
                            value: state.duration.inMilliseconds > 0
                                ? (state.position.inMilliseconds /
                                        state.duration.inMilliseconds)
                                    .clamp(0.0, 1.0)
                                : 0.0,
                            onChanged: (v) {
                              final target = Duration(
                                milliseconds:
                                    (v * state.duration.inMilliseconds).round(),
                              );
                              state.seekTo(target);
                            },
                          ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            IconButton(
                              onPressed: state.audioGlobalBase64 == null
                                  ? null
                                  : state.stop,
                              icon: const Icon(Icons.stop_rounded),
                              tooltip: 'Parar',
                            ),
                            IconButton(
                              onPressed: state.audioGlobalBase64 == null
                                  ? null
                                  : state.playPause,
                              icon: Icon(
                                state.playerState == PlayerState.playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              tooltip: state.playerState == PlayerState.playing
                                  ? 'Pausar'
                                  : 'Reproducir',
                            ),
                            IconButton(
                              onPressed: state.pickAudioGlobal,
                              icon: const Icon(Icons.audio_file_outlined),
                              tooltip: 'Importar audio',
                            ),
                            if (state.isRecording)
                              IconButton(
                                onPressed: state.stopRecordingGlobal,
                                icon: const Icon(Icons.stop_circle_outlined),
                                tooltip: 'Parar grabacion',
                                color: Colors.red,
                              )
                            else
                              IconButton(
                                onPressed: state.startRecordingGlobal,
                                icon: const Icon(Icons.mic_outlined),
                                tooltip: Platform.isWindows
                                    ? 'Abrir Grabadora de Voz de Windows (usa "Importar audio" al terminar)'
                                    : 'Grabar audio',
                              ),
                            if (state.audioGlobalBase64 != null)
                              IconButton(
                                onPressed: state.clearAudioGlobal,
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Quitar audio',
                              ),
                          ],
                        ),
                        if (state.audioGlobalNombre != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Audio: ${state.audioGlobalNombre}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black54),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SourceCarousel extends StatelessWidget {
  const _SourceCarousel();

  Uint8List? _bytes(CharlaDiapositiva s) {
    final raw = (s.imagenMiniatura ?? s.imagenDiapositiva ?? '').trim();
    if (raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<_CharlaAudioEditorState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
          child: Row(
            children: [
              const Icon(Icons.view_carousel_outlined, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Diapositivas disponibles (arrastra a la línea de tiempo)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text('${state.sourceSlides.length}'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DragTarget<_DragPayload>(
            onWillAcceptWithDetails: (d) => d.data.fromTimeline,
            onAcceptWithDetails: (d) {
              final uid = d.data.timelineUid;
              if (uid != null) {
                state.removeTimelineItem(uid);
              }
            },
            builder: (context, candidateData, rejectedData) {
              final active = candidateData.isNotEmpty;
              return Container(
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? Colors.red.shade400 : Colors.grey.shade300,
                    width: active ? 2 : 1,
                  ),
                  color: active ? Colors.red.shade50 : Colors.grey.shade100,
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  itemCount: state.sourceSlides.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final slide = state.sourceSlides[index];
                    final bytes = _bytes(slide);

                    return LongPressDraggable<_DragPayload>(
                      data: _DragPayload.source(slide),
                      feedback: _ThumbTile(
                          bytes: bytes,
                          label: '${index + 1}',
                          isFeedback: true),
                      childWhenDragging: Opacity(
                        opacity: 0.45,
                        child: _ThumbTile(bytes: bytes, label: '${index + 1}'),
                      ),
                      child: _ThumbTile(bytes: bytes, label: '${index + 1}'),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ThumbTile extends StatelessWidget {
  const _ThumbTile({
    required this.bytes,
    required this.label,
    this.isFeedback = false,
  });

  final Uint8List? bytes;
  final String label;
  final bool isFeedback;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: isFeedback ? 6 : 0,
      borderRadius: BorderRadius.circular(8),
      color: Colors.transparent,
      child: Container(
        width: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
          color: Colors.white,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes!, fit: BoxFit.cover)
            else
              const Icon(Icons.image_not_supported_outlined),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineEditor extends StatelessWidget {
  const _TimelineEditor();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<_CharlaAudioEditorState>();

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Row(
              children: [
                const Icon(Icons.timeline, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Línea de tiempo fija (${state.timelineItems.length} bloques · ${state.fixedTimelineDurationSeg.toStringAsFixed(1)} s)',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 130,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: _FixedTimelineTrack(items: state.timelineItems),
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedTimelineTrack extends StatelessWidget {
  const _FixedTimelineTrack({required this.items});

  final List<_TimelineItem> items;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<_CharlaAudioEditorState>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final totalDuration = state.fixedTimelineDurationSeg;
        final desiredWidth = math.max(viewportWidth, totalDuration * 44);

        return DragTarget<_DragPayload>(
          onWillAcceptWithDetails: (details) => !details.data.fromTimeline,
          onAcceptWithDetails: (details) {
            final slide = details.data.slide;
            if (slide == null) return;
            final renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox == null) {
              state.addSourceSlideToTimeline(slide);
              return;
            }
            final local = renderBox.globalToLocal(details.offset);
            final insertIndex =
                state.insertionIndexForDx(local.dx, desiredWidth);
            state.addSourceSlideToTimeline(slide, insertAt: insertIndex);
          },
          builder: (context, candidateData, rejectedData) {
            final active = candidateData.isNotEmpty;
            if (items.isEmpty) {
              return Container(
                decoration: BoxDecoration(
                  color: active ? Colors.orange.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        active ? Colors.orange.shade400 : Colors.grey.shade300,
                    width: active ? 2 : 1,
                  ),
                ),
                child: const Center(
                  child: Text(
                      'Arrastra aquí diapositivas desde el carrusel superior'),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: active ? Colors.orange.shade50 : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: desiredWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        SizedBox(
                          width: math.max(
                            92,
                            totalDuration <= 0
                                ? desiredWidth / items.length
                                : (items[i].duracionSeg / totalDuration) *
                                    desiredWidth,
                          ),
                          child: _TimelineBlock(
                            item: items[i],
                            index: i,
                          ),
                        ),
                        if (i < items.length - 1)
                          _BoundaryHandle(
                            index: i,
                            trackWidth: desiredWidth,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TimelineBlock extends StatelessWidget {
  const _TimelineBlock({
    required this.item,
    required this.index,
  });

  final _TimelineItem item;
  final int index;

  Uint8List? _bytes(CharlaDiapositiva s) {
    final raw = (s.imagenMiniatura ?? s.imagenDiapositiva ?? '').trim();
    if (raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<_CharlaAudioEditorState>();
    final selected = state.selectedTimelineUid == item.uid;
    return LongPressDraggable<_DragPayload>(
      data: _DragPayload.timeline(item.uid),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 120,
          height: 64,
          child: _buildTile(context, selected: selected),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.45,
        child: _buildTile(context, selected: selected),
      ),
      child: _buildTile(context, selected: selected),
    );
  }

  Widget _buildTile(BuildContext context, {required bool selected}) {
    final state = context.read<_CharlaAudioEditorState>();
    final bytes = _bytes(item.slide);

    return GestureDetector(
      onTap: () => state.selectTimelineItem(item.uid),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? Colors.blue.shade500 : Colors.grey.shade400,
            width: selected ? 2 : 1,
          ),
          color: Colors.white,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes, fit: BoxFit.cover)
            else
              Container(
                color: Colors.grey.shade100,
                child: const Icon(Icons.image_not_supported_outlined),
              ),
            Positioned(
              left: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => Text(
                    constraints.maxWidth < 54
                        ? item.duracionSeg.toStringAsFixed(1)
                        : '${item.duracionSeg.toStringAsFixed(1)} s',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                    overflow: TextOverflow.fade,
                    softWrap: false,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: GestureDetector(
                onTap: () => state.removeTimelineItem(item.uid),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
            if (selected)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 3,
                  color: Colors.blue.shade500,
                ),
              ),
            if (state.playerState == PlayerState.playing ||
                state.position > Duration.zero)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: state.selectedTimelineUid == item.uid
                              ? Colors.deepOrange
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BoundaryHandle extends StatelessWidget {
  const _BoundaryHandle({
    required this.index,
    required this.trackWidth,
  });

  final int index;
  final double trackWidth;

  @override
  Widget build(BuildContext context) {
    final state = context.read<_CharlaAudioEditorState>();
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        state.adjustBoundaryByIndex(index, d.delta.dx, trackWidth);
      },
      child: Container(
        width: 14,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        color: Colors.black12,
        child: const Center(
          child: Icon(Icons.drag_indicator, size: 12),
        ),
      ),
    );
  }
}
