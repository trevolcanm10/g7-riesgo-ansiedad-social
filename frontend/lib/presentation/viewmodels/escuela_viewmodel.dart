import 'package:flutter/foundation.dart';
import '../../../domain/entities/escuela.dart';
import '../../../domain/usecases/obtener_escuelas_usecase.dart';

/// ViewModel del catálogo de escuelas profesionales.
///
/// Expone los estados de carga, error y lista para que la presentación
/// consuma el catálogo sin conocer el detalle de cómo se carga (asset local).
class EscuelaViewModel extends ChangeNotifier {
  final ObtenerEscuelasUseCase _obtenerEscuelasUseCase;

  EscuelaViewModel(this._obtenerEscuelasUseCase);

  // ==========================================
  // ESTADOS
  // ==========================================
  bool _cargando = false;
  String? _error;
  List<Escuela> _escuelas = const [];

  bool get cargando => _cargando;
  String? get error => _error;
  List<Escuela> get escuelas => _escuelas;

  /// Carga el catálogo de escuelas.
  ///
  /// Si ya hay datos no vuelve a cargar; si hubo error permite reintentar.
  /// Debe llamarse fuera de la construcción de widgets (por ejemplo, con
  /// `addPostFrameCallback` desde `initState`) para no notificar durante
  /// el build.
  Future<void> cargarEscuelas() async {
    if (_cargando || _escuelas.isNotEmpty) return;

    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _escuelas = await _obtenerEscuelasUseCase();
      _error = null;
    } catch (_) {
      _escuelas = const [];
      _error = 'No se pudo cargar el catálogo de escuelas';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }
}
