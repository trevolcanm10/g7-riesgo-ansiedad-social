import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<AuthViewModel>().restaurarSesion();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    if (!auth.sessionChecked || auth.isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.restoreError != null || auth.logoutFailed) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                auth.restoreError ?? auth.error ?? 'No se pudo cerrar sesión.',
              ),
              ElevatedButton(
                onPressed: () =>
                    auth.logoutFailed ? auth.logout() : auth.restaurarSesion(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (auth.isAuthenticated) return const HomeScreen();
    return const LoginScreen();
  }
}

/// Guards existing routes without putting navigation in the data layer.
class SessionProtected extends StatelessWidget {
  final Widget child;
  const SessionProtected({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return auth.isAuthenticated
        ? KeyedSubtree(key: ValueKey(auth.sessionRevision), child: child)
        : const SessionGate();
  }
}
