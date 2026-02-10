class ListaCompraItem {
  int? codigo;
  int codigoUsuario; // FK a usuario - requerido
  String nombre;
  String? descripcion;
  String
      categoria; // 'frutas', 'verduras', 'carnes', 'lacteos', 'panaderia', 'congelados', 'otros'
  double? cantidad;
  String? unidad; // 'kg', 'l', 'unidades', 'paquete', etc.
  String comprado; // 'S' o 'N'
  DateTime? fechaCaducidad;
  DateTime? fechaCompra;
  String? notas;
  int? codusuarioa;
  DateTime? fechaa;
  int? codusuariom;
  DateTime? fecham;

  ListaCompraItem({
    this.codigo,
    required this.codigoUsuario,
    required this.nombre,
    this.descripcion,
    this.categoria = 'otros',
    this.cantidad,
    this.unidad,
    this.comprado = 'N',
    this.fechaCaducidad,
    this.fechaCompra,
    this.notas,
    this.codusuarioa,
    this.fechaa,
    this.codusuariom,
    this.fecham,
  });

  factory ListaCompraItem.fromJson(Map<String, dynamic> json) {
    return ListaCompraItem(
      codigo:
          json['codigo'] != null ? int.parse(json['codigo'].toString()) : null,
      codigoUsuario: int.parse(json['codigo_usuario'].toString()),
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      categoria: json['categoria'] ?? 'otros',
      cantidad: json['cantidad'] != null
          ? double.parse(json['cantidad'].toString())
          : null,
      unidad: json['unidad'],
      comprado: json['comprado'] ?? 'N',
      fechaCaducidad: json['fecha_caducidad'] != null
          ? DateTime.parse(json['fecha_caducidad'])
          : null,
      fechaCompra: json['fecha_compra'] != null
          ? DateTime.parse(json['fecha_compra'])
          : null,
      notas: json['notas'],
      codusuarioa: json['codusuarioa'] != null
          ? int.parse(json['codusuarioa'].toString())
          : null,
      fechaa: json['fechaa'] != null ? DateTime.parse(json['fechaa']) : null,
      codusuariom: json['codusuariom'] != null
          ? int.parse(json['codusuariom'].toString())
          : null,
      fecham: json['fecham'] != null ? DateTime.parse(json['fecham']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (codigo != null) 'codigo': codigo,
      'codigo_usuario': codigoUsuario,
      'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      'categoria': categoria,
      if (cantidad != null) 'cantidad': cantidad,
      if (unidad != null) 'unidad': unidad,
      'comprado': comprado,
      if (fechaCaducidad != null)
        'fecha_caducidad': fechaCaducidad!.toIso8601String(),
      if (fechaCompra != null) 'fecha_compra': fechaCompra!.toIso8601String(),
      if (notas != null) 'notas': notas,
      if (codusuarioa != null) 'codusuarioa': codusuarioa,
      if (fechaa != null) 'fechaa': fechaa!.toIso8601String(),
      if (codusuariom != null) 'codusuariom': codusuariom,
      if (fecham != null) 'fecham': fecham!.toIso8601String(),
    };
  }

  // Método para verificar si está por caducar (menos de 3 días)
  bool get estaPorCaducar {
    if (fechaCaducidad == null) return false;
    final diasRestantes = fechaCaducidad!.difference(DateTime.now()).inDays;
    return diasRestantes <= 3 && diasRestantes >= 0;
  }

  // Método para verificar si ya caducó
  bool get haCaducado {
    if (fechaCaducidad == null) return false;
    return fechaCaducidad!.isBefore(DateTime.now());
  }

  // Obtener el icono según la categoría
  static String getCategoriaIcon(String categoria) {
    switch (categoria) {
      case 'frutas':
        return '🍎';
      case 'verduras':
        return '🥬';
      case 'carnes':
        return '🍖';
      case 'lacteos':
        return '🥛';
      case 'panaderia':
        return '🍞';
      case 'congelados':
        return '🧊';
      case 'bebidas':
        return '🥤';
      case 'conservas':
        return '🥫';
      case 'limpieza':
        return '🧼';
      case 'higiene':
        return '🧴';
      default:
        return '🛒';
    }
  }

  // Obtener el nombre de la categoría en español
  static String getCategoriaNombre(String categoria) {
    switch (categoria) {
      case 'frutas':
        return 'Frutas';
      case 'verduras':
        return 'Verduras';
      case 'carnes':
        return 'Carnes';
      case 'lacteos':
        return 'Lácteos';
      case 'panaderia':
        return 'Panadería';
      case 'congelados':
        return 'Congelados';
      case 'bebidas':
        return 'Bebidas';
      case 'conservas':
        return 'Conservas';
      case 'limpieza':
        return 'Limpieza';
      case 'higiene':
        return 'Higiene';
      default:
        return 'Otros';
    }
  }

  // Lista de categorías disponibles
  static List<String> get categorias => [
        'frutas',
        'verduras',
        'carnes',
        'lacteos',
        'panaderia',
        'congelados',
        'bebidas',
        'conservas',
        'limpieza',
        'higiene',
        'otros',
      ];

  // Lista de unidades disponibles
  static List<String> get unidades => [
        'unidades',
        'kg',
        'g',
        'l',
        'ml',
        'paquete',
        'bolsa',
        'lata',
        'bote',
      ];
}
