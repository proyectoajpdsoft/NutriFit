import 'dart:convert';

import 'package:nutri_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AdherenciaEstado { cumplido, parcial, noRealizado }

enum AdherenciaTipo { nutri, fit }

class AdherenciaMetricaSemanal {
  const AdherenciaMetricaSemanal({
    required this.tipo,
    required this.porcentaje,
    required this.tendencia,
    required this.logrados,
    required this.planificados,
    required this.estadoHoy,
  });

  final AdherenciaTipo tipo;
  final int porcentaje;
  final int tendencia;
  final double logrados;
  final int planificados;
  final AdherenciaEstado? estadoHoy;
}

class AdherenciaResumenSemanal {
  const AdherenciaResumenSemanal({
    this.nutri,
    this.fit,
    required this.puntosMejora,
  });

  final AdherenciaMetricaSemanal? nutri;
  final AdherenciaMetricaSemanal? fit;
  final List<String> puntosMejora;

  bool get hasData => nutri != null || fit != null;
}

class AdherenciaService {
  static const String _prefsKey = 'adherencia_diaria_v1';
  final ApiService _apiService;

  AdherenciaService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  static const Map<AdherenciaEstado, double> _estadoScore = {
    AdherenciaEstado.cumplido: 1.0,
    AdherenciaEstado.parcial: 0.5,
    AdherenciaEstado.noRealizado: 0.0,
  };

  DateTime _dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _dayKey(DateTime value) {
    final day = _dayOnly(value);
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = _dayOnly(date);
    final offset = normalized.weekday - DateTime.monday;
    return normalized.subtract(Duration(days: offset));
  }

  String _tipoKey(AdherenciaTipo tipo) =>
      tipo == AdherenciaTipo.nutri ? 'nutri' : 'fit';

  String _estadoKey(AdherenciaEstado estado) {
    switch (estado) {
      case AdherenciaEstado.cumplido:
        return 'cumplido';
      case AdherenciaEstado.parcial:
        return 'parcial';
      case AdherenciaEstado.noRealizado:
        return 'no';
    }
  }

  AdherenciaEstado? _parseEstado(dynamic raw) {
    final normalized = (raw ?? '').toString().trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized == 'cumplido') return AdherenciaEstado.cumplido;
    if (normalized == 'parcial') return AdherenciaEstado.parcial;
    if (normalized == 'no') return AdherenciaEstado.noRealizado;
    return null;
  }

  Future<Map<String, dynamic>> _readStore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return <String, dynamic>{};
  }

  Future<void> _writeStore(Map<String, dynamic> store) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(store));
  }

  Map<String, dynamic> _userBucket(
      Map<String, dynamic> store, String userCode) {
    final existing = store[userCode];
    if (existing is Map<String, dynamic>) {
      return existing;
    }
    return <String, dynamic>{};
  }

  Future<bool> registrarEstadoDia({
    required String userCode,
    required AdherenciaTipo tipo,
    required AdherenciaEstado estado,
    DateTime? fecha,
    int? codigoUsuarioObjetivo,
    int? codigoPacienteObjetivo,
    int? codigoUsuarioActor,
  }) async {
    final targetDay = _dayOnly(fecha ?? DateTime.now());
    final targetKey = _dayKey(targetDay);

    try {
      await _apiService.upsertAdherenciaRegistro(
        tipo: _tipoKey(tipo),
        estado: _estadoKey(estado),
        fecha: targetDay,
        codigoUsuario: codigoUsuarioObjetivo,
        codigoPaciente: codigoPacienteObjetivo,
        codigoUsuarioActor: codigoUsuarioActor,
      );
    } catch (_) {
      rethrow;
    }

    final store = await _readStore();
    final userData = _userBucket(store, userCode);
    final existingDay = userData[targetKey];

    final dayData = existingDay is Map<String, dynamic>
        ? Map<String, dynamic>.from(existingDay)
        : <String, dynamic>{};

    dayData[_tipoKey(tipo)] = _estadoKey(estado);
    userData[targetKey] = dayData;
    store[userCode] = userData;

    await _writeStore(store);
    return true;
  }

  Map<String, dynamic> _recordsToStoreByDate(
      List<Map<String, dynamic>> records) {
    final byDay = <String, dynamic>{};

    for (final row in records) {
      final fechaRaw = (row['fecha'] ?? '').toString();
      if (fechaRaw.isEmpty || fechaRaw.length < 10) {
        continue;
      }
      final dayKey = fechaRaw.substring(0, 10);
      final tipoRaw = (row['tipo'] ?? '').toString().trim().toLowerCase();
      final estadoRaw = (row['estado'] ?? '').toString().trim().toLowerCase();
      if (tipoRaw != 'nutri' && tipoRaw != 'fit') {
        continue;
      }
      if (estadoRaw != 'cumplido' &&
          estadoRaw != 'parcial' &&
          estadoRaw != 'no') {
        continue;
      }

      final current = byDay[dayKey];
      final dayData = current is Map<String, dynamic>
          ? Map<String, dynamic>.from(current)
          : <String, dynamic>{};
      dayData[tipoRaw] = estadoRaw;
      byDay[dayKey] = dayData;
    }

    return byDay;
  }

  AdherenciaMetricaSemanal _buildMetrica({
    required AdherenciaTipo tipo,
    required DateTime startWeek,
    required Map<String, dynamic> userData,
    required int planificados,
  }) {
    double currentPoints = 0;
    double previousPoints = 0;

    for (var i = 0; i < 7; i++) {
      final currentDay = startWeek.add(Duration(days: i));
      final currentData = userData[_dayKey(currentDay)];
      if (currentData is Map<String, dynamic>) {
        final estado = _parseEstado(currentData[_tipoKey(tipo)]);
        if (estado != null) {
          currentPoints += _estadoScore[estado] ?? 0;
        }
      }

      final prevDay =
          startWeek.subtract(const Duration(days: 7)).add(Duration(days: i));
      final prevData = userData[_dayKey(prevDay)];
      if (prevData is Map<String, dynamic>) {
        final estado = _parseEstado(prevData[_tipoKey(tipo)]);
        if (estado != null) {
          previousPoints += _estadoScore[estado] ?? 0;
        }
      }
    }

    final maxCurrentPoints = planificados.toDouble();
    final maxPreviousPoints = planificados.toDouble();

    final currentPct = maxCurrentPoints <= 0
        ? 0
        : ((currentPoints / maxCurrentPoints) * 100).round().clamp(0, 100);
    final previousPct = maxPreviousPoints <= 0
        ? 0
        : ((previousPoints / maxPreviousPoints) * 100).round().clamp(0, 100);

    final todayData = userData[_dayKey(DateTime.now())];
    AdherenciaEstado? estadoHoy;
    if (todayData is Map<String, dynamic>) {
      estadoHoy = _parseEstado(todayData[_tipoKey(tipo)]);
    }

    return AdherenciaMetricaSemanal(
      tipo: tipo,
      porcentaje: currentPct,
      tendencia: currentPct - previousPct,
      logrados: currentPoints,
      planificados: planificados,
      estadoHoy: estadoHoy,
    );
  }

  List<String> _buildPuntosMejora(
    AdherenciaMetricaSemanal? nutri,
    AdherenciaMetricaSemanal? fit,
  ) {
    final tips = <String>[];

    if (nutri != null) {
      if (nutri.porcentaje < 60) {
        tips.add('Nutri: intenta cumplir al menos 5 de 7 días esta semana.');
      } else if (nutri.tendencia < 0) {
        tips.add(
            'Nutri: vas a la baja frente a la semana pasada; vuelve a tu rutina base.');
      }
    }

    if (fit != null) {
      if (fit.porcentaje < 60) {
        tips.add(
            'Fit: intenta llegar a 3-4 sesiones semanales, aunque sean cortas.');
      } else if (fit.tendencia < 0) {
        tips.add(
            'Fit: la tendencia ha bajado; agenda tus próximas sesiones hoy.');
      }
    }

    if (tips.isEmpty) {
      tips.add('Buen ritmo. Mantén la constancia para consolidar resultados.');
    }

    return tips.take(3).toList(growable: false);
  }

  Future<AdherenciaResumenSemanal> getResumenSemanal({
    required String userCode,
    required bool incluirNutri,
    required bool incluirFit,
    DateTime? referencia,
    int? codigoUsuarioConsulta,
  }) async {
    final weekStart = _startOfWeek(referencia ?? DateTime.now());
    final prevWeekStart = weekStart.subtract(const Duration(days: 7));
    final currentWeekEnd = weekStart.add(const Duration(days: 6));

    Map<String, dynamic> userData;

    try {
      final remoteRecords = await _apiService.getAdherenciaRegistros(
        fechaDesde: prevWeekStart,
        fechaHasta: currentWeekEnd,
        codigoUsuario: codigoUsuarioConsulta,
      );
      userData = _recordsToStoreByDate(remoteRecords);

      final store = await _readStore();
      store[userCode] = userData;
      await _writeStore(store);
    } catch (_) {
      final store = await _readStore();
      userData = _userBucket(store, userCode);
    }

    final nutri = incluirNutri
        ? _buildMetrica(
            tipo: AdherenciaTipo.nutri,
            startWeek: weekStart,
            userData: userData,
            planificados: 7,
          )
        : null;

    final fit = incluirFit
        ? _buildMetrica(
            tipo: AdherenciaTipo.fit,
            startWeek: weekStart,
            userData: userData,
            planificados: 4,
          )
        : null;

    return AdherenciaResumenSemanal(
      nutri: nutri,
      fit: fit,
      puntosMejora: _buildPuntosMejora(nutri, fit),
    );
  }
}
