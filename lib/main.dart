import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/tv_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
