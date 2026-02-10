import 'package:flutter/material.dart';

class EsfuerzoSlider extends StatefulWidget {
  final int valor;
  final ValueChanged<int> onChanged;
  final bool showDescription;
  final bool showIndicators;
  final bool compact;
  final bool showTitle;
  final Alignment valueAlignment;

  const EsfuerzoSlider({
    super.key,
    required this.valor,
    required this.onChanged,
    this.showDescription = true,
    this.showIndicators = true,
    this.compact = false,
    this.showTitle = true,
    this.valueAlignment = Alignment.centerRight,
  });

  @override
  State<EsfuerzoSlider> createState() => _EsfuerzoSliderState();
}

class _EsfuerzoSliderState extends State<EsfuerzoSlider> {
  late int _valor;

  @override
  void initState() {
    super.initState();
    _valor = widget.valor;
  }

  String _getNivelTexto(int valor) {
    if (valor <= 3) {
      return 'Fácil';
    } else if (valor <= 6) {
      return 'Moderado';
    } else if (valor <= 9) {
      return 'Duro';
    } else {
      return 'Esfuerzo máximo';
    }
  }

  String _getDescripcion(int valor) {
    if (valor <= 3) {
      return '¿Qué es fácil?\nPodías hablar con normalidad.\nRespirababas sin problemas.\nTe sentías muy bien';
    } else if (valor <= 6) {
      return '¿Qué es moderado?\nPodías hablar, pero de forma entrecortada.\nTe costaba un poco respirar.\nEn tu zona de confort, pero con dificultades.';
    } else if (valor <= 9) {
      return '¿Qué es duro?\nCasi no podías hablar.\nRespirababas con dificultad.\nFuera de tu zona de confort.';
    } else {
      return '¿Qué es el esfuerzo máximo?\nHas alcanzado tu límite físico.\nTe has quedado sin aliento.\nNo podías hablar o apenas recordabas quién eras.';
    }
  }

  String _getEmoji(int valor) {
    if (valor <= 3) return '😊';
    if (valor <= 6) return '💪';
    if (valor <= 9) return '🔥';
    return '⚡';
  }

  Color _getColor(int valor) {
    if (valor <= 3) {
      return Colors.green;
    } else if (valor <= 6) {
      return Colors.orange;
    } else if (valor <= 9) {
      return Colors.red;
    } else {
      return Colors.deepOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(_valor);
    final padding = widget.compact ? 8.0 : 16.0;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: widget.compact
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_getEmoji(_valor)} ${_getNivelTexto(_valor)} ($_valor/10)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                )
              : (widget.showTitle
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nivel de esfuerzo',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_getEmoji(_valor)} ${_getNivelTexto(_valor)} ($_valor/10)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Align(
                      alignment: widget.valueAlignment,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_getEmoji(_valor)} ${_getNivelTexto(_valor)} ($_valor/10)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    )),
        ),
        SizedBox(height: widget.compact ? 8 : 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: widget.compact ? 6 : 8,
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: widget.compact ? 10 : 14,
                elevation: widget.compact ? 2 : 4,
              ),
              valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
            ),
            child: Slider(
              value: _valor.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: color,
              inactiveColor: Colors.grey[300],
              label: _valor.toString(),
              onChanged: (value) {
                setState(() {
                  _valor = value.toInt();
                });
                widget.onChanged(_valor);
              },
            ),
          ),
        ),
        if (widget.showDescription) ...[
          SizedBox(height: widget.compact ? 8 : 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                _getDescripcion(_valor),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.5,
                    ),
              ),
            ),
          ),
        ],
        if (widget.showIndicators) ...[
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _valor = 2; // Valor medio de "Fácil"
                      });
                      widget.onChanged(_valor);
                    },
                    child: _buildIndicador(
                      context,
                      '😊',
                      'Fácil',
                      Colors.green,
                      _valor <= 3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _valor = 5; // Valor medio de "Moderado"
                      });
                      widget.onChanged(_valor);
                    },
                    child: _buildIndicador(
                      context,
                      '💪',
                      'Moderado',
                      Colors.orange,
                      _valor > 3 && _valor <= 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _valor = 8; // Valor medio de "Duro"
                      });
                      widget.onChanged(_valor);
                    },
                    child: _buildIndicador(
                      context,
                      '🔥',
                      'Duro',
                      Colors.red,
                      _valor > 6 && _valor <= 9,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _valor = 10; // Valor máximo
                      });
                      widget.onChanged(_valor);
                    },
                    child: _buildIndicador(
                      context,
                      '⚡',
                      'Máximo',
                      Colors.deepOrange,
                      _valor > 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIndicador(
    BuildContext context,
    String emoji,
    String label,
    Color color,
    bool activo,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: activo ? color.withOpacity(0.2) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: activo ? color : Colors.grey[300]!,
          width: activo ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: activo ? FontWeight.bold : FontWeight.normal,
              color: activo ? color : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
