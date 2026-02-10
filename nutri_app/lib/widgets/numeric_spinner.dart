import 'package:flutter/material.dart';

/// Widget de spinner numérico con scroll/rueda
/// Simula el comportamiento de un picker de números con scroll
class NumericSpinner extends StatefulWidget {
  final int value;
  final int minValue;
  final int maxValue;
  final ValueChanged<int> onChanged;
  final String label;
  final bool hasDecimal;
  final int decimalPlaces;
  final double? width;
  final double height;

  const NumericSpinner({
    Key? key,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.onChanged,
    required this.label,
    this.hasDecimal = false,
    this.decimalPlaces = 0,
    this.width,
    this.height = 200,
  }) : super(key: key);

  @override
  State<NumericSpinner> createState() => _NumericSpinnerState();
}

class _NumericSpinnerState extends State<NumericSpinner> {
  late FixedExtentScrollController _scrollController;
  late int _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
    _scrollController = FixedExtentScrollController(
      initialItem: widget.value - widget.minValue,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateValue(int newIndex) {
    final newValue = widget.minValue + newIndex;
    if (newValue != _currentValue) {
      setState(() {
        _currentValue = newValue;
      });
      widget.onChanged(newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Container(
          width: widget.width ?? 100,
          height: widget.height,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[50],
          ),
          child: Stack(
            children: [
              // Divisor superior
              Positioned(
                top: widget.height / 2 - 20,
                left: 0,
                right: 0,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.blue[400]!, width: 2),
                      bottom: BorderSide(color: Colors.blue[400]!, width: 2),
                    ),
                    color: Colors.blue[50],
                  ),
                ),
              ),
              // Scroll picker
              ListWheelScrollView(
                controller: _scrollController,
                itemExtent: 40,
                perspective: 0.005,
                diameterRatio: 1.6,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: _updateValue,
                children: List<Widget>.generate(
                  widget.maxValue - widget.minValue + 1,
                  (index) {
                    final value = widget.minValue + index;
                    return Center(
                      child: Text(
                        value.toString().padLeft(2, '0'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'Valor: $_currentValue',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ),
      ],
    );
  }
}

/// Widget de spinner para decimales
/// Combina un spinner de enteros con otro de decimales
class DecimalNumericSpinner extends StatefulWidget {
  final double value;
  final int intMinValue;
  final int intMaxValue;
  final int decimalPlaces;
  final ValueChanged<double> onChanged;
  final String label;
  final double? width;
  final double height;

  const DecimalNumericSpinner({
    Key? key,
    required this.value,
    required this.intMinValue,
    required this.intMaxValue,
    this.decimalPlaces = 2,
    required this.onChanged,
    required this.label,
    this.width,
    this.height = 200,
  }) : super(key: key);

  @override
  State<DecimalNumericSpinner> createState() => _DecimalNumericSpinnerState();
}

class _DecimalNumericSpinnerState extends State<DecimalNumericSpinner> {
  late FixedExtentScrollController _intController;
  late FixedExtentScrollController _decimalController;
  late int _intPart;
  late int _decimalPart;

  @override
  void initState() {
    super.initState();
    _intPart = widget.value.toInt();

    // Calcular la parte decimal
    final decimalValue = widget.value - _intPart;
    final divisor = _pow10(widget.decimalPlaces);
    _decimalPart = (decimalValue * divisor).round();

    _intController = FixedExtentScrollController(
      initialItem: _intPart - widget.intMinValue,
    );
    _decimalController = FixedExtentScrollController(
      initialItem: _decimalPart,
    );
  }

  int _pow10(int exponent) {
    int result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  @override
  void dispose() {
    _intController.dispose();
    _decimalController.dispose();
    super.dispose();
  }

  void _updateValue() {
    final decimalDivisor = _pow10(widget.decimalPlaces);
    final newValue = _intPart + (_decimalPart / decimalDivisor);
    widget.onChanged(newValue.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Spinner para parte entera
            SizedBox(
              width: (widget.width ?? 150) * 0.6,
              height: widget.height,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[50],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: widget.height / 2 - 20,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.blue[400]!, width: 2),
                            bottom:
                                BorderSide(color: Colors.blue[400]!, width: 2),
                          ),
                          color: Colors.blue[50],
                        ),
                      ),
                    ),
                    ListWheelScrollView(
                      controller: _intController,
                      itemExtent: 40,
                      perspective: 0.005,
                      diameterRatio: 1.6,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _intPart = widget.intMinValue + index;
                        });
                        _updateValue();
                      },
                      children: List<Widget>.generate(
                        widget.intMaxValue - widget.intMinValue + 1,
                        (index) {
                          final value = widget.intMinValue + index;
                          return Center(
                            child: Text(
                              value.toString().padLeft(3, '0'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Separador decimal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            // Spinner para decimales
            SizedBox(
              width: (widget.width ?? 150) * 0.3,
              height: widget.height,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[50],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: widget.height / 2 - 20,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.blue[400]!, width: 2),
                            bottom:
                                BorderSide(color: Colors.blue[400]!, width: 2),
                          ),
                          color: Colors.blue[50],
                        ),
                      ),
                    ),
                    ListWheelScrollView(
                      controller: _decimalController,
                      itemExtent: 40,
                      perspective: 0.005,
                      diameterRatio: 1.6,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _decimalPart = index;
                        });
                        _updateValue();
                      },
                      children: List<Widget>.generate(
                        _pow10(widget.decimalPlaces),
                        (index) {
                          return Center(
                            child: Text(
                              index
                                  .toString()
                                  .padLeft(widget.decimalPlaces, '0'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'Valor: $_intPart.${_decimalPart.toString().padLeft(widget.decimalPlaces, '0')}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
          ),
        ),
      ],
    );
  }
}
