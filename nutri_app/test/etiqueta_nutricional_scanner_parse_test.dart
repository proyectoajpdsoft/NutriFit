import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_app/screens/etiqueta_nutricional_scanner_screen.dart';

void main() {
  group('NutrientesPorPorcion.parse', () {
    // --- Basic single-column per-100g label (Spanish) -----------------------
    test('parses a simple single-column Spanish label', () {
      const ocr = '''
Información nutricional
Grasas 15 g
de las cuales saturadas 2 g
Hidratos de carbono 45 g
de los cuales azúcares 10 g
Fibra 4 g
Proteínas 8 g
Sal 1 g
''';
      final result = NutrientesPorPorcion.parse(ocr);
      expect(result.grasasGr, closeTo(15.0, 0.01));
      expect(result.azucarGr, closeTo(10.0, 0.01));
      expect(result.proteinaGr, closeTo(8.0, 0.01));
      expect(result.salGr, closeTo(1.0, 0.01));
    });

    // --- Two-column label (per 100g | per portion) --------------------------
    test('picks per-portion (last) value when two values and no hints', () {
      // Format typical of EU labels: first value is per 100g, second per portion
      const ocr = '''
Información nutricional
Grasas 15 g 4.5 g
Proteínas 8 g 2.4 g
de los cuales azúcares 10 g 3 g
Sal 1 g 0.3 g
''';
      final result = NutrientesPorPorcion.parse(ocr);
      expect(result.grasasGr, closeTo(4.5, 0.01));
      expect(result.azucarGr, closeTo(3.0, 0.01));
      expect(result.proteinaGr, closeTo(2.4, 0.01));
      expect(result.salGr, closeTo(0.3, 0.01));
    });

    // --- Per-portion hint present -------------------------------------------
    test('picks the correct value when serving hint is on the same line', () {
      const ocr = '''
Grasas por porción 4.5 g
Proteínas por porción 2.4 g
Azúcares por porción 3 g
Sal por porción 0.3 g
''';
      final result = NutrientesPorPorcion.parse(ocr);
      expect(result.grasasGr, closeTo(4.5, 0.01));
      expect(result.azucarGr, closeTo(3.0, 0.01));
      expect(result.proteinaGr, closeTo(2.4, 0.01));
      expect(result.salGr, closeTo(0.3, 0.01));
    });

    // --- Sodium to salt conversion ------------------------------------------
    test('converts sodium (mg) to estimated salt', () {
      const ocr = '''
Sodio 400 mg
''';
      final result = NutrientesPorPorcion.parse(ocr);
      // 400 mg sodium → 0.4 g → × 2.5 = 1.0 g salt
      expect(result.salGr, closeTo(1.0, 0.01));
    });

    // --- Multi-line OCR: value on next line ---------------------------------
    test('finds value on the next line when keyword line has no value', () {
      const ocr = '''
Grasas
15 g
Proteínas
8 g
Azúcares
10 g
Sal
1 g
''';
      final result = NutrientesPorPorcion.parse(ocr);
      expect(result.grasasGr, closeTo(15.0, 0.01));
      expect(result.azucarGr, closeTo(10.0, 0.01));
      expect(result.proteinaGr, closeTo(8.0, 0.01));
      expect(result.salGr, closeTo(1.0, 0.01));
    });

    // --- OCR error: 'O' instead of '0' -------------------------------------
    test('corrects OCR substitution O to 0 in numeric context', () {
      // '1Og' should be parsed as 10g; 'O.5 g' as 0.5g; '1O g' as 10g; 'O g' as 0g
      const ocr = '''
Grasas 1Og
Proteinas O.5 g
Azucares 1O g
Sal O g
''';
      final result = NutrientesPorPorcion.parse(ocr);
      expect(result.grasasGr, closeTo(10.0, 0.01));
      expect(result.proteinaGr, closeTo(0.5, 0.01));
      expect(result.azucarGr, closeTo(10.0, 0.01));
      expect(result.salGr, closeTo(0.0, 0.01));
    });

    // --- OCR error: 'l' instead of '1' before unit or between digits --------
    test('corrects OCR substitution l to 1 before unit or between digits', () {
      // '1l g' should be parsed as 11g; '1l5 g' as 115g
      const ocr = '''
Proteinas 1l g
Azucares 1l5 g
''';
      final result = NutrientesPorPorcion.parse(ocr);
      expect(result.proteinaGr, closeTo(11.0, 0.01));
      expect(result.azucarGr, closeTo(115.0, 0.01));
    });

    // --- Comma as decimal separator -----------------------------------------
    test('handles comma decimal separator', () {
      const ocr = '''
Grasas 15,5 g
Proteínas 8,3 g
Azúcares 10,2 g
Sal 1,1 g
''';
      final result = NutrientesPorPorcion.parse(ocr);
      expect(result.grasasGr, closeTo(15.5, 0.01));
      expect(result.proteinaGr, closeTo(8.3, 0.01));
      expect(result.azucarGr, closeTo(10.2, 0.01));
      expect(result.salGr, closeTo(1.1, 0.01));
    });

    // --- 'gr' unit ----------------------------------------------------------
    test('handles gr as unit for grams', () {
      const ocr = '''
Grasas 15 gr
Proteínas 8 gr
Azúcares 10 gr
Sal 1 gr
''';
      final result = NutrientesPorPorcion.parse(ocr);
      expect(result.grasasGr, closeTo(15.0, 0.01));
      expect(result.proteinaGr, closeTo(8.0, 0.01));
      expect(result.azucarGr, closeTo(10.0, 0.01));
      expect(result.salGr, closeTo(1.0, 0.01));
    });

    // --- Accented characters ------------------------------------------------
    test('handles accented Spanish labels', () {
      const ocr = '''
Grasas totales 19,9 g
  de las cuales saturadas 2,4 g
Hidratos de carbono 45,5 g
  de los cuales azúcares 5,9 g
Fibra alimentaria 5,7 g
Proteínas 11,3 g
Sal 1,1 g
''';
      final result = NutrientesPorPorcion.parse(ocr);
      expect(result.grasasGr, closeTo(19.9, 0.01));
      expect(result.azucarGr, closeTo(5.9, 0.01));
      expect(result.proteinaGr, closeTo(11.3, 0.01));
      expect(result.salGr, closeTo(1.1, 0.01));
    });

    // --- All nutrients null --------------------------------------------------
    test('returns all null when OCR text has no recognisable values', () {
      const ocr = 'Este texto no contiene ningún valor nutricional reconocible';
      final result = NutrientesPorPorcion.parse(ocr);
      expect(result.azucarGr, isNull);
      expect(result.salGr, isNull);
      expect(result.grasasGr, isNull);
      expect(result.proteinaGr, isNull);
      expect(result.porcionGr, isNull);
    });

    // --- Serving size extraction --------------------------------------------
    test('extracts serving size', () {
      const ocr = '''
Porción: 30 g
Grasas 4.5 g
Sal 0.3 g
''';
      final result = NutrientesPorPorcion.parse(ocr);
      expect(result.porcionGr, closeTo(30.0, 0.01));
    });

    // --- English label ------------------------------------------------------
    test('parses English-language label', () {
      const ocr = '''
Nutrition facts
Total fat 15 g
Sugars 10 g
Protein 8 g
Salt 1 g
''';
      final result = NutrientesPorPorcion.parse(ocr);
      expect(result.grasasGr, closeTo(15.0, 0.01));
      expect(result.azucarGr, closeTo(10.0, 0.01));
      expect(result.proteinaGr, closeTo(8.0, 0.01));
      expect(result.salGr, closeTo(1.0, 0.01));
    });
  });
}
