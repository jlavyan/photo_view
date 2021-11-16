import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class TransformAnimation extends StatefulWidget {
  TransformAnimation({
    required this.child,
    required this.transform,
    required this.basePosition,
    required this.controller,
    required this.photoViewController,
  });

  final Widget child;
  final TranslateInformation transform;
  final AlignmentGeometry? basePosition;

  final TransformController controller;
  final PhotoViewControllerBase? photoViewController;
  @override
  State<StatefulWidget> createState() {
    return _State();
  }
}

class _State extends State<TransformAnimation> with TickerProviderStateMixin {
  TransformController get _controller => widget.controller;
  PhotoViewControllerBase? get _photoViewController =>
      widget.photoViewController;

  AnimationController? controller;
  Animation<double>? animation;

  TranslateInformation get _transform => widget.transform;

  Tween<double>? _tween;
  double _start = 0;
  @override
  void initState() {
    super.initState();

    _initialize();
    _controller.applyOffset = applyOffset;
    _controller.cancel = cancel;
  }

  @override
  void dispose() {
    super.dispose();

    controller?.dispose();
  }

  void _initialize() {
    controller = AnimationController(vsync: this, duration: Duration.zero);
    controller?.addListener(_animaitonChange);
  }

  @override
  Widget build(BuildContext context) {
    final transform = Matrix4.identity()
      ..translate(_transform.offset.dx, _transform.offset.dy)
      ..scale(_transform.scale)
      ..rotateZ(_transform.rotation);
    return Transform(
      child: widget.child,
      transform: transform,
      alignment: widget.basePosition,
    );
  }

  void cancel() {
    controller?.stop();
  }

  void applyOffset(
      {required TranslateInformation from,
      required TranslateInformation to,
      required Duration duration,
      required Curve curve}) {
    final _controller = controller;

    assert(_controller != null, 'controller must be initialized');
    if (_controller == null) {
      return;
    }
    _controller.value = from.offset.dy;

    final double start = _controller.value == 1 ? 0 : _controller.value;
    if (_controller.isAnimating) {
      setNewPosition(from: start, controller: _controller, to: to);
    } else {
      restartAnimation(
          duration: duration,
          from: start,
          to: to,
          curve: curve,
          controller: _controller);
    }
  }

  void setNewPosition({
    required double from,
    required AnimationController controller,
    required TranslateInformation to,
  }) {
    _tween?.begin = from;
    controller.reset();

    final dy = calculateEnd(to);
    _tween?.end = -dy;
    controller.forward();
  }

  void restartAnimation(
      {required Duration duration,
      required double from,
      required TranslateInformation to,
      required AnimationController controller,
      required Curve curve}) {
    controller.duration = duration;
    _start = _transform.offset.dy;
    final dy = calculateEnd(to);
    _tween = Tween<double>(begin: 0, end: -dy);
    animation =
        _tween?.animate(CurvedAnimation(parent: controller, curve: curve));

    controller.forward(from: from);
  }

  double calculateEnd(TranslateInformation to) {
    final dy = _transform.offset.dy + to.offset.dy;
    return dy;
  }

  void _animaitonChange() {
    final offset =
        Offset(_transform.offset.dx, _start + (animation?.value ?? 0));
    _photoViewController?.updateMultiple(position: offset);
  }
}

class TransformController {
  TransformController();

  late VoidCallback cancel;
  late TransformAnimationMethod applyOffset;
}

typedef TransformAnimationMethod = void Function(
    {required TranslateInformation from,
    required TranslateInformation to,
    required Duration duration,
    required Curve curve});

class TranslateInformation {
  TranslateInformation(
      {required this.offset, required this.scale, required this.rotation});
  Offset offset;
  double scale;
  double rotation;
}
