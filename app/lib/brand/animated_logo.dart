import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// طبقات الشعار. كلها تشترك في viewBox واحد (155 124 960 960)،
/// لذلك تُرصّ فوق بعضها بالحجم نفسه وتتطابق تمامًا.
const _pomegranate = 'assets/brand/pomegranate.svg';
const _leaf = 'assets/brand/leaf.svg';
const _truck = 'assets/brand/truck.svg';
const _snowflake = 'assets/brand/snowflake.svg';
const logoLayers = [_pomegranate, _leaf, _truck, _snowflake];

/// تحويل نقطة من إحداثيات الـ viewBox إلى Alignment داخل المربع.
Alignment _at(double x, double y) =>
    Alignment((x - 155) / 960 * 2 - 1, (y - 124) / 960 * 2 - 1);

final _bodyCenter = _at(515, 690);
final _leafBase = _at(676, 384);
final _snowCenter = _at(688, 758);

/// يحمّل طبقات الشعار مسبقًا حتى تبدأ الحركة دون وميض.
Future<void> precacheLogo() async {
  await Future.wait([
    for (final path in logoLayers)
      () {
        final loader = SvgAssetLoader(path);
        return svg.cache.putIfAbsent(loader.cacheKey(null), () => loader.loadBytes(null));
      }(),
  ]);
}

/// الشعار الثابت.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/brand/logo.svg',
        width: size,
        height: size,
        semanticsLabel: 'شعار حاسبة الرمان',
      );
}

/// الشعار المتحرك: تظهر الرمانة، ثم الورقة، ثم يدخل البراد، ثم تدور ندفة الثلج.
/// المدة 1.6 ثانية. مع «تقليل الحركة» يظهر الشعار بتلاشٍ قصير فقط.
class AnimatedLogo extends StatefulWidget {
  const AnimatedLogo({super.key, this.size = 220, this.onFinished});

  final double size;
  final VoidCallback? onFinished;

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _reduceMotion = false;
  bool _started = false;

  late final Animation<double> _pom = _interval(0.0, 0.375, Curves.easeOutCubic);
  late final Animation<double> _leafIn = _interval(0.22, 0.6, Curves.easeOutCubic);
  late final Animation<double> _truckFade = _interval(0.28, 0.4, Curves.easeOut);
  late final Animation<double> _truckMove = _interval(0.28, 0.78, Curves.easeOutBack);
  late final Animation<double> _snow = _interval(0.625, 1.0, Curves.easeOutCubic);

  Animation<double> _interval(double begin, double end, Curve curve) =>
      CurvedAnimation(parent: _controller, curve: Interval(begin, end, curve: curve));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _controller.duration = _reduceMotion ? const Duration(milliseconds: 250) : const Duration(milliseconds: 1600);
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      await precacheLogo().timeout(const Duration(seconds: 2));
    } catch (_) {
      // إن تأخر التحميل تبدأ الحركة على أي حال.
    }
    if (!mounted) return;
    await _controller.forward();
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _layer(String asset) => SvgPicture.asset(asset, width: widget.size, height: widget.size);

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      label: 'شعار حاسبة الرمان',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (_reduceMotion) {
              return Opacity(
                opacity: _controller.value,
                child: Stack(children: [for (final l in logoLayers) _layer(l)]),
              );
            }
            return Stack(
              children: [
                Opacity(
                  opacity: _pom.value,
                  child: Transform.scale(
                    scale: 0.85 + 0.15 * _pom.value,
                    alignment: _bodyCenter,
                    child: _layer(_pomegranate),
                  ),
                ),
                Opacity(
                  opacity: _leafIn.value,
                  child: Transform.rotate(
                    angle: -28 * math.pi / 180 * (1 - _leafIn.value),
                    alignment: _leafBase,
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * _leafIn.value,
                      alignment: _leafBase,
                      child: _layer(_leaf),
                    ),
                  ),
                ),
                Opacity(
                  opacity: _truckFade.value,
                  child: Transform.translate(
                    // البراد يتجه يمينًا في الشعار، فيدخل من اليسار.
                    offset: Offset(-140 / 960 * size * (1 - _truckMove.value), 0),
                    child: _layer(_truck),
                  ),
                ),
                Opacity(
                  opacity: _snow.value,
                  child: Transform.rotate(
                    angle: -math.pi / 2 * (1 - _snow.value),
                    alignment: _snowCenter,
                    child: Transform.scale(
                      scale: 0.4 + 0.6 * _snow.value,
                      alignment: _snowCenter,
                      child: _layer(_snowflake),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
