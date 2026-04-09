import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:nutri_app/models/charla_diapositiva.dart';
import 'package:nutri_app/models/charla_seminario.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/widgets/premium_feature_dialog_helper.dart';
import 'package:provider/provider.dart';

class _PresentationItem {
  _PresentationItem({
    required this.slide,
    required this.duracionSeg,
  });

  final CharlaDiapositiva slide;
  final double duracionSeg;
}

class CharlaSeminarioDetailScreen extends StatefulWidget {
  const CharlaSeminarioDetailScreen({
    super.key,
    required this.charla,
    this.previewMode = false,
  });

  final CharlaSeminario charla;
  final bool previewMode;

  @override
  State<CharlaSeminarioDetailScreen> createState() =>
      _CharlaSeminarioDetailScreenState();
}

class _CharlaSeminarioDetailScreenState
    extends State<CharlaSeminarioDetailScreen> {
  final Map<int, MemoryImage> _slideCache = <int, MemoryImage>{};
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _playerPositionSub;
  StreamSubscription<Duration>? _playerDurationSub;

  List<CharlaDiapositiva> _slides = <CharlaDiapositiva>[];
  List<_PresentationItem> _presentationItems = <_PresentationItem>[];

  bool _loading = true;
  bool _audioPlaying = false;
  bool _isUserScrubbing = false;

  int _currentPage = 0;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;

  late CharlaSeminario _charla;

  String? get _userCode => context.read<AuthService>().userCode;
  bool get _hasGlobalAudio => (_charla.audioGlobal ?? '').trim().isNotEmpty;

  Future<void> _showPreviewPremiumDialog() {
    final l10n = AppLocalizations.of(context)!;
    return PremiumFeatureDialogHelper.show(
      context,
      message: l10n.charlasPremiumContentMessage,
    );
  }

  @override
  void initState() {
    super.initState();
    _charla = widget.charla;
    _currentPage = widget.previewMode
        ? 0
        : (_charla.ultimaDiapositivaVista > 0)
            ? (_charla.ultimaDiapositivaVista - 1).clamp(0, 9999)
            : 0;
    _loadSlides();
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _playerPositionSub?.cancel();
    _playerDurationSub?.cancel();
    _audioPlayer.dispose();
    _slideCache.clear();
    super.dispose();
  }

  Future<void> _loadSlides() async {
    if (_charla.codigo == null) return;

    final api = context.read<ApiService>();
    setState(() => _loading = true);
    try {
      final charlaResponse = await api.get(
        'api/charlas_seminarios.php?codigo=${_charla.codigo}',
      );
      if (charlaResponse.statusCode == 200 && mounted) {
        _charla = CharlaSeminario.fromJson(
          Map<String, dynamic>.from(
            jsonDecode(charlaResponse.body) as Map,
          ),
        );
      }

      final response = await api.get(
        'api/charlas_seminarios.php?diapositivas=${_charla.codigo}',
      );
      if (response.statusCode != 200 || !mounted) {
        return;
      }

      final data = jsonDecode(response.body) as List<dynamic>;
      _slides = data
          .map(
            (e) => CharlaDiapositiva.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(growable: false);
      _presentationItems = _buildPresentationItems(_slides, _charla);

      _bindAudioStreams();

      final initialIndex = widget.previewMode ? 0 : _initialPresentationIndex();
      _currentPage = initialIndex;

      if (_hasGlobalAudio && !widget.previewMode) {
        await _playGlobalAudio(fromCurrentIndex: true);
      }

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Ignorar error y mostrar estado actual
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _bindAudioStreams() {
    _playerStateSub?.cancel();
    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _audioPlaying = state == PlayerState.playing;
      });
    });

    _playerPositionSub?.cancel();
    _playerPositionSub = _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      final newIndex = _presentationIndexForPosition(position);
      setState(() {
        if (!_isUserScrubbing) {
          _audioPosition = position;
        }
        if (newIndex != null && newIndex != _currentPage) {
          _currentPage = newIndex;
        }
      });
    });

    _playerDurationSub?.cancel();
    _playerDurationSub = _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() {
        _audioDuration = duration;
      });
    });
  }

  List<_PresentationItem> _buildPresentationItems(
    List<CharlaDiapositiva> slides,
    CharlaSeminario charla,
  ) {
    if (slides.isEmpty) return <_PresentationItem>[];

    final byCode = <int, CharlaDiapositiva>{
      for (final slide in slides)
        if (slide.codigo != null) slide.codigo!: slide,
    };

    final rawTimeline = (charla.timelinePresentacionJson ?? '').trim();
    if (rawTimeline.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTimeline);
        if (decoded is List) {
          final items = <_PresentationItem>[];
          for (final entry in decoded) {
            if (entry is! Map) continue;
            final map = Map<String, dynamic>.from(entry);
            final code = int.tryParse(
              (map['codigo_diapositiva'] ?? '').toString(),
            );
            final dur =
                double.tryParse((map['duracion_seg'] ?? '').toString()) ?? 8.0;
            if (code == null) continue;
            final slide = byCode[code];
            if (slide == null) continue;
            items.add(
              _PresentationItem(
                slide: slide,
                duracionSeg: dur > 0 ? dur : 8.0,
              ),
            );
          }
          if (items.isNotEmpty) return items;
        }
      } catch (_) {
        // Fallback al mapeo directo de diapositivas
      }
    }

    return slides
        .map(
          (slide) => _PresentationItem(
            slide: slide,
            duracionSeg: slide.duracionPresentacionSeg ?? 8.0,
          ),
        )
        .toList(growable: false);
  }

  int _initialPresentationIndex() {
    final ultimaVista = _charla.ultimaDiapositivaVista;
    if (ultimaVista <= 0 || _presentationItems.isEmpty) return 0;
    final idx = _presentationItems.indexWhere(
      (item) => item.slide.numeroDiapositiva == ultimaVista,
    );
    return idx < 0 ? 0 : idx;
  }

  _PresentationItem? get _currentItem {
    if (_presentationItems.isEmpty ||
        _currentPage < 0 ||
        _currentPage >= _presentationItems.length) {
      return null;
    }
    return _presentationItems[_currentPage];
  }

  CharlaDiapositiva? get _currentSlide => _currentItem?.slide;

  bool get _currentSlideHasAudio {
    final slide = _currentSlide;
    if (slide == null) return false;
    return (slide.audioDiapositiva ?? '').trim().isNotEmpty;
  }

  List<double> _effectiveDurationsSeg() {
    if (_presentationItems.isEmpty) return const <double>[];

    final configuredTotal = _presentationItems.fold<double>(
      0.0,
      (sum, item) => sum + item.duracionSeg,
    );

    final globalTotal = _audioDuration.inMilliseconds / 1000.0;
    if (!_hasGlobalAudio || configuredTotal <= 0 || globalTotal <= 0) {
      return _presentationItems
          .map((item) => item.duracionSeg)
          .toList(growable: false);
    }

    final factor = globalTotal / configuredTotal;
    return _presentationItems
        .map((item) => (item.duracionSeg * factor).clamp(0.05, 999999.0))
        .cast<double>()
        .toList(growable: false);
  }

  Duration _presentationStartForIndex(int index) {
    final durations = _effectiveDurationsSeg();
    var acc = 0.0;
    for (var i = 0; i < durations.length; i++) {
      if (i == index) {
        return Duration(milliseconds: (acc * 1000).round());
      }
      acc += durations[i];
    }
    return Duration.zero;
  }

  int? _presentationIndexForPosition(Duration position) {
    if (_presentationItems.isEmpty) return null;

    final durations = _effectiveDurationsSeg();
    final seconds = position.inMilliseconds / 1000.0;
    var acc = 0.0;

    for (var i = 0; i < durations.length; i++) {
      acc += durations[i];
      if (seconds < acc) {
        return i;
      }
    }

    return _presentationItems.length - 1;
  }

  Future<void> _playGlobalAudio({bool fromCurrentIndex = false}) async {
    if (!_hasGlobalAudio) return;

    try {
      final bytes = base64Decode((_charla.audioGlobal ?? '').trim());
      final source = BytesSource(
        Uint8List.fromList(bytes),
        mimeType: (_charla.audioGlobalMime ?? '').trim().isEmpty
            ? null
            : _charla.audioGlobalMime!.trim(),
      );

      await _audioPlayer.stop();
      await _audioPlayer.play(source);

      if (fromCurrentIndex) {
        final target = _presentationStartForIndex(_currentPage);
        if (target > Duration.zero) {
          await _audioPlayer.seek(target);
          if (mounted) {
            setState(() => _audioPosition = target);
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _audioPlaying = false);
    }
  }

  Future<void> _playCurrentSlideAudio() async {
    final item = _currentItem;
    if (item == null) return;

    if (_hasGlobalAudio) {
      await _playGlobalAudio(fromCurrentIndex: true);
      return;
    }

    final raw = (item.slide.audioDiapositiva ?? '').trim();
    if (raw.isEmpty) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _audioPlaying = false);
      return;
    }

    try {
      final bytes = base64Decode(raw);
      final mimeType = (item.slide.audioDiapositivaMime ?? '').trim().isNotEmpty
          ? item.slide.audioDiapositivaMime!.trim()
          : null;
      await _audioPlayer.stop();
      await _audioPlayer.play(
        BytesSource(Uint8List.fromList(bytes), mimeType: mimeType),
      );
    } catch (_) {
      if (mounted) setState(() => _audioPlaying = false);
    }
  }

  Future<void> _pauseOrResumeAudio() async {
    if (!_hasGlobalAudio && !_currentSlideHasAudio) return;

    if (_audioPlaying) {
      await _audioPlayer.pause();
      return;
    }

    final position = await _audioPlayer.getCurrentPosition();
    if (position == null || position.inMilliseconds <= 0) {
      await _playCurrentSlideAudio();
    } else {
      await _audioPlayer.resume();
    }
  }

  Future<void> _seekToPresentationIndex(int index) async {
    if (!_hasGlobalAudio) return;
    final target = _presentationStartForIndex(index);
    await _audioPlayer.seek(target);
    if (mounted) {
      setState(() {
        _audioPosition = target;
      });
    }
  }

  Future<void> _goToNextSlide() async {
    if (_currentPage >= _presentationItems.length - 1) return;
    final next = _currentPage + 1;
    setState(() => _currentPage = next);
    _saveProgreso(next);

    if (_hasGlobalAudio) {
      await _seekToPresentationIndex(next);
    } else {
      await _playCurrentSlideAudio();
    }
  }

  Future<void> _goToPreviousSlide() async {
    if (_currentPage <= 0) return;
    final prev = _currentPage - 1;
    setState(() => _currentPage = prev);
    _saveProgreso(prev);

    if (_hasGlobalAudio) {
      await _seekToPresentationIndex(prev);
    } else {
      await _playCurrentSlideAudio();
    }
  }

  ImageProvider? _slideProvider(CharlaDiapositiva slide) {
    final raw = (slide.imagenDiapositiva ?? '').trim();
    if (raw.isEmpty) return null;

    final cached = _slideCache[slide.numeroDiapositiva];
    if (cached != null) return cached;

    try {
      final img = MemoryImage(base64Decode(raw));
      _slideCache[slide.numeroDiapositiva] = img;
      return img;
    } catch (_) {
      return null;
    }
  }

  void _saveProgreso(int pageIndex) {
    if (widget.previewMode) return;
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty || _charla.codigo == null) return;
    if (pageIndex < 0 || pageIndex >= _presentationItems.length) return;

    final slideNum = _presentationItems[pageIndex].slide.numeroDiapositiva;
    context.read<ApiService>().post(
          'api/charlas_seminarios.php?progreso=1',
          body: jsonEncode(<String, dynamic>{
            'codigo_charla': _charla.codigo,
            'codigo_usuario': int.parse(userCode),
            'ultima_diapositiva_vista': slideNum,
          }),
        );
  }

  Future<void> _toggleLike() async {
    if (widget.previewMode) {
      await _showPreviewPremiumDialog();
      return;
    }
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty || _charla.codigo == null) return;

    final prev = _charla.meGusta ?? 'N';
    try {
      final response = await context.read<ApiService>().post(
            'api/charlas_seminarios.php?toggle_like=1',
            body: jsonEncode(<String, dynamic>{
              'codigo_charla': _charla.codigo,
              'codigo_usuario': int.parse(userCode),
            }),
          );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _charla.meGusta = (data['me_gusta'] ?? 'N').toString();
          if (prev != 'S' && _charla.meGusta == 'S') {
            _charla.totalLikes += 1;
          } else if (prev == 'S' &&
              _charla.meGusta != 'S' &&
              _charla.totalLikes > 0) {
            _charla.totalLikes -= 1;
          }
        });
      }
    } catch (_) {
      // Ignore
    }
  }

  Future<void> _toggleFavorito() async {
    if (widget.previewMode) {
      await _showPreviewPremiumDialog();
      return;
    }
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty || _charla.codigo == null) return;

    try {
      final response = await context.read<ApiService>().post(
            'api/charlas_seminarios.php?toggle_favorito=1',
            body: jsonEncode(<String, dynamic>{
              'codigo_charla': _charla.codigo,
              'codigo_usuario': int.parse(userCode),
            }),
          );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _charla.favorito = (data['favorito'] ?? 'N').toString();
        });
      }
    } catch (_) {
      // Ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final meGusta = _charla.meGusta == 'S';
    final esFavorito = _charla.favorito == 'S';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(
          _charla.titulo,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: meGusta ? 'Quitar me gusta' : 'Me gusta',
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  meGusta ? Icons.favorite : Icons.favorite_border,
                  color: meGusta ? Colors.red.shade300 : Colors.white70,
                  size: 22,
                ),
                if (_charla.totalLikes > 0) ...[
                  const SizedBox(width: 3),
                  Text(
                    '${_charla.totalLikes}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ],
            ),
            onPressed: _toggleLike,
          ),
          IconButton(
            tooltip: esFavorito ? 'Quitar de favoritos' : 'Anadir a favoritos',
            icon: Icon(
              esFavorito ? Icons.bookmark : Icons.bookmark_border,
              color: esFavorito ? Colors.amber.shade300 : Colors.white70,
            ),
            onPressed: _toggleFavorito,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _presentationItems.isEmpty
              ? _buildNoSlides()
              : _buildSingleSlide(),
      bottomNavigationBar: !_loading && _presentationItems.isNotEmpty
          ? _buildBottomControls()
          : null,
    );
  }

  Widget _buildNoSlides() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty, size: 56, color: Colors.white38),
          SizedBox(height: 16),
          Text(
            'Esta charla aun no tiene diapositivas disponibles.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleSlide() {
    final safeIndex = _currentPage.clamp(0, _presentationItems.length - 1);
    final slide = _presentationItems[safeIndex].slide;
    final provider = _slideProvider(slide);

    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4.0,
      child: Center(
        child: provider != null
            ? Image(image: provider, fit: BoxFit.contain)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.image_not_supported,
                    color: Colors.white30,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Diapositiva ${slide.numeroDiapositiva}',
                    style: const TextStyle(color: Colors.white38),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Anterior',
                onPressed: widget.previewMode
                    ? _showPreviewPremiumDialog
                    : _currentPage > 0
                        ? _goToPreviousSlide
                        : null,
                icon: const Icon(Icons.skip_previous, color: Colors.white),
              ),
              IconButton(
                tooltip: _audioPlaying ? 'Pausar audio' : 'Reproducir audio',
                onPressed: widget.previewMode
                    ? _showPreviewPremiumDialog
                    : (_hasGlobalAudio || _currentSlideHasAudio)
                        ? _pauseOrResumeAudio
                        : null,
                icon: Icon(
                  _audioPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: (_hasGlobalAudio || _currentSlideHasAudio)
                      ? Colors.white
                      : Colors.white24,
                  size: 30,
                ),
              ),
              IconButton(
                tooltip: 'Siguiente',
                onPressed: widget.previewMode
                    ? _showPreviewPremiumDialog
                    : _currentPage < _presentationItems.length - 1
                        ? _goToNextSlide
                        : null,
                icon: const Icon(Icons.skip_next, color: Colors.white),
              ),
            ],
          ),
          if (_hasGlobalAudio && !widget.previewMode)
            Slider(
              value: _audioDuration.inMilliseconds > 0
                  ? (_audioPosition.inMilliseconds /
                          _audioDuration.inMilliseconds)
                      .clamp(0.0, 1.0)
                  : 0.0,
              onChanged: (value) {
                if (_audioDuration.inMilliseconds <= 0) return;
                final target = Duration(
                  milliseconds: (_audioDuration.inMilliseconds * value).round(),
                );
                setState(() {
                  _isUserScrubbing = true;
                  _audioPosition = target;
                  final idx = _presentationIndexForPosition(target);
                  if (idx != null) {
                    _currentPage = idx;
                  }
                });
              },
              onChangeEnd: (value) async {
                if (_audioDuration.inMilliseconds <= 0) {
                  if (mounted) {
                    setState(() => _isUserScrubbing = false);
                  }
                  return;
                }

                final target = Duration(
                  milliseconds: (_audioDuration.inMilliseconds * value).round(),
                );
                await _audioPlayer.seek(target);
                if (!mounted) return;
                setState(() {
                  _audioPosition = target;
                  final idx = _presentationIndexForPosition(target);
                  if (idx != null) {
                    _currentPage = idx;
                  }
                  _isUserScrubbing = false;
                });
              },
              activeColor: Colors.deepOrange.shade300,
              inactiveColor: Colors.white24,
            ),
        ],
      ),
    );
  }
}
