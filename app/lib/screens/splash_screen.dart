import 'dart:async';

import 'package:flutter/material.dart';

import '../brand/animated_logo.dart';
import '../theme/app_theme.dart';

/// شاشة البداية: الشعار المتحرك ونص «حاسبة الحسناوي» لمدة ثلاث ثوانٍ.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.nextBuilder, this.duration = const Duration(seconds: 3)});

  final WidgetBuilder nextBuilder;
  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _showText = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _goNext);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _showText = true;
    } else if (!_showText) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _showText = true);
      });
    }
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, _, _) => widget.nextBuilder(context),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final logoSize = (shortest * 0.56).clamp(160.0, 300.0);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedLogo(size: logoSize),
            const SizedBox(height: 20),
            AnimatedOpacity(
              opacity: _showText ? 1 : 0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              child: AnimatedSlide(
                offset: _showText ? Offset.zero : const Offset(0, 0.25),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                child: const Text(
                  'حاسبة الحسناوي',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 32,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
