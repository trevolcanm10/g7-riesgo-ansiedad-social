import 'package:flutter/material.dart';

/// Modelo para cada página del onboarding
class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });
}

/// Pantalla de Onboarding con carousel de 3 páginas
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.psychology,
      title: 'Comprende tu Salud Mental',
      description:
          'Obtén análisis personalizados sobre tus niveles de ansiedad con evaluaciones de Inteligencia Artificial adaptadas a la vida universitaria.',
    ),
    _OnboardingPage(
      icon: Icons.analytics_outlined,
      title: 'Evaluación de Riesgo con IA',
      description:
          'Nuestro modelo de Machine Learning analiza 15 indicadores clave para proporcionar niveles de riesgo precisos y detección temprana de la ansiedad.',
    ),
    _OnboardingPage(
      icon: Icons.auto_awesome_outlined,
      title: 'Recomendaciones Personalizadas',
      description:
          'Recibe sugerencias de bienestar a tu medida y realiza un seguimiento de tu progreso a lo largo del tiempo para mejorar tu salud mental.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _goToLogin();
    }
  }

  void _goToLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8E0FF), // pastel lavender top
              Color(0xFFF5F5FC), // whitish-silver center
              Color(0xFFD0F0EC), // soft mint/teal bottom right
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ==========================================
              // SKIP BUTTON (top right)
              // ==========================================
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _goToLogin,
                  child: const Text(
                    'Saltar',
                    style: TextStyle(
                      color: Color(0xFF0D9488),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),

              // ==========================================
              // PAGE VIEW (illustration + text)
              // ==========================================
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ==========================================
                          // ICON BADGE
                          // ==========================================
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                page.icon,
                                size: 60,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),

                          // ==========================================
                          // TITLE
                          // ==========================================
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ==========================================
                          // DESCRIPTION
                          // ==========================================
                          Text(
                            page.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF94A3B8),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ==========================================
              // PAGINATION DOTS
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF6366F1)
                          : const Color(0xFFCBD5E1).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // ==========================================
              // NEXT / GET STARTED BUTTON
              // ==========================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1 ? 'Comenzar' : 'Siguiente >',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}