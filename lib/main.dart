import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme_controller.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return _AppRoot();
  }
}

class _AppRoot extends StatefulWidget {
  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  final ThemeController _controller = ThemeController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onThemeChanged);
    _controller.load();
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isLoaded) {
      return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }
    final theme = ThemeData(
      brightness: _controller.isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: _controller.isDark ? Brightness.dark : Brightness.light),
    );
    return MaterialApp(
      title: 'DialDesk',
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
