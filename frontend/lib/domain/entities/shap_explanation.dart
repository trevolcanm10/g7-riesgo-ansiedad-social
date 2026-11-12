class ShapFactor {
  final String nombre;
  final double valor;
  final String direccion;
  const ShapFactor({required this.nombre, required this.valor, required this.direccion});
}

class ShapExplanation {
  final bool disponible;
  final List<ShapFactor> factores;
  const ShapExplanation({required this.disponible, required this.factores});
}
