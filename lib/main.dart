import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'screens/tv_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Tenta habilitar o máximo de FPS (Android/TV)
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (e) {
    debugPrint('Erro ao setar high refresh rate: $e');
  }

  // Tela cheia — ideal para TV
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const VettiFlowTv());
}

class VettiFlowTv extends StatelessWidget {
  const VettiFlowTv({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VETTI Flow — TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0073BB)),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const TvDashboardScreen(),
    );
  }
}
