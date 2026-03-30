import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:nutri_app/models/charla_diapositiva.dart';
import 'package:nutri_app/models/charla_seminario.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:provider/provider.dart';

class CharlaSeminarioDetailScreen extends StatefulWidget {
  const CharlaSeminarioDetailScreen({super.key, required this.charla});

  final CharlaSeminario charla;

  @override
  State<CharlaSeminarioDetailScreen> createState() =>
      _CharlaSeminarioDetailScreenState();
}

class _CharlaSeminarioDetailScreenState
    extends State<CharlaSeminarioDetailScreen> {
  final PageController _pageController = PageController();
  final Map<int, MemoryImage> _slideCache = <int, MemoryImage>{};
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<void>? _playerCompleteSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  List<CharlaDiapositiva> _slides = <CharlaDiapositiva>[];
  bool _loading = true;
  bool _audioPlaying = false;
  int _currentPage = 0;

  late CharlaSeminario _charla;

  String? get _userCode => context.read<AuthService>().userCode;

  @override
  void initState() {
    super.initState();
    _charla = widget.charla;
    _currentPage = (_charla.ultimaDiapositivaVista > 0)
        ? (_charla.ultimaDiapositivaVista - 1).clamp(0, 9999)
        : 0;
    _loadSlides();
  }

  @override
  void dispose() {
    _playerCompleteSub?.cancel();
    _playerStateSub?.cancel();
    _audioPlayer.dispose();
    _pageController.dispose();
    _slideCache.clear();
    super.dispose();
  }

  Future<void> _loadSlides() async {
    if (_charla.codigo == null) return;
    setState(() => _loading = true);
    try {
      final response = await context.read<ApiService>().get(
            'api/charlas_seminarios.php?diapositivas=${_charla.codigo}',
          );
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _slides = data
              .map(
                (e) => CharlaDiapositiva.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList(growable: false);
        });

        _playerCompleteSub?.cancel();
        _playerStateSub?.cancel();
        _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
          _goToNextSlide();
        });
        _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
          if (!mounted) return;
          setState(() {
            _audioPlaying = state == PlayerState.playing;
          });
        });

        // Saltar a la última diapositiva vista
        if (_currentPage > 0 && _currentPage < _slides.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(_currentPage);
            }
          });
        }

        await _playCurrentSlideAudio();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  CharlaDiapositiva? get _currentSlide {
    if (_slides.isEmpty || _currentPage < 0 || _currentPage >= _slides.length) {
      return null;
    }
    return _slides[_currentPage];
  }

  bool get _currentSlideHasAudio {
    final slide = _currentSlide;
    if (slide == null) return false;
    return (slide.audioDiapositiva ?? '').trim().isNotEmpty;
  }

  Future<void> _playCurrentSlideAudio() async {
    final slide = _currentSlide;
    if (slide == null) return;

    final raw = (slide.audioDiapositiva ?? '').trim();
    if (raw.isEmpty) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _audioPlaying = false);
      return;
    }

    try {
      final bytes = base64Decode(raw);
      final mimeType = (slide.audioDiapositivaMime ?? '').trim().isNotEmpty
          ? slide.audioDiapositivaMime!.trim()
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
    if (!_currentSlideHasAudio) return;
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

  Future<void> _goToNextSlide() async {
    if (_currentPage >= _slides.length - 1) return;
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _goToPreviousSlide() async {
    if (_currentPage <= 0) return;
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
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
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty || _charla.codigo == null) return;
    final slideNum = pageIndex + 1;
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
    } catch (_) {}
  }

  Future<void> _toggleFavorito() async {
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
    } catch (_) {}
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
          // Like
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
          // Favorito
          IconButton(
            tooltip: esFavorito ? 'Quitar de favoritos' : 'Añadir a favoritos',
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
          : _slides.isEmpty
              ? _buildNoSlides()
              : _buildCarousel(),
      bottomNavigationBar:
          !_loading && _slides.isNotEmpty ? _buildSlideIndicator() : null,
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
            'Esta charla aún no tiene diapositivas disponibles.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCarousel() {
    return GestureDetector(
      // Tap en los lados izq/der para avanzar o retroceder
      onTapUp: (details) {
        final width = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < width / 3) {
          if (_currentPage > 0) {
            _goToPreviousSlide();
          }
        } else if (details.globalPosition.dx > width * 2 / 3) {
          if (_currentPage < _slides.length - 1) {
            _goToNextSlide();
          }
        }
      },
      child: PageView.builder(
        controller: _pageController,
        itemCount: _slides.length,
        onPageChanged: (index) {
          setState(() => _currentPage = index);
          _saveProgreso(index);
          _playCurrentSlideAudio();
        },
        itemBuilder: (context, index) {
          final slide = _slides[index];
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
        },
      ),
    );
  }

  Widget _buildSlideIndicator() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Anterior',
                  onPressed: _currentPage > 0 ? _goToPreviousSlide : null,
                  icon: const Icon(Icons.skip_previous, color: Colors.white),
                ),
                IconButton(
                  tooltip: _audioPlaying ? 'Pausar audio' : 'Reproducir audio',
                  onPressed: _currentSlideHasAudio ? _pauseOrResumeAudio : null,
                  icon: Icon(
                    _audioPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color:
                        _currentSlideHasAudio ? Colors.white : Colors.white24,
                    size: 30,
                  ),
                ),
                IconButton(
                  tooltip: 'Siguiente',
                  onPressed:
                      _currentPage < _slides.length - 1 ? _goToNextSlide : null,
                  icon: const Icon(Icons.skip_next, color: Colors.white),
                ),
              ],
            ),
          ),
          // Puntos indicadores (máx 15 visibles)
          if (_slides.length <= 20)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _currentPage ? 10 : 6,
                  height: i == _currentPage ? 10 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _currentPage
                        ? Colors.deepPurple.shade300
                        : Colors.white30,
                  ),
                );
              }),
            )
          else
            // Para muchas diapositivas: solo número
            Text(
              '${_currentPage + 1} / ${_slides.length}',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          const SizedBox(height: 4),
          if (_slides.length <= 20)
            Text(
              '${_currentPage + 1} / ${_slides.length}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
        ],
      ),
    );
  }
}
