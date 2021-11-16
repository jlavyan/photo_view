import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class TransformAnimation extends StatefulWidget {
  TransformAnimation(
      {required this.child,
      required this.transform,
      required this.basePosition,
      required this.controller,
      required this.photoViewController});

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

  double _start = 0;
  @override
  void initState() {
    super.initState();

    _controller.applyOffset = applyOffset;
  }

  @override
  void dispose() {
    super.dispose();

    controller?.dispose();
  }

  void _initialize({required Duration duration}) {
    controller?.dispose();

    controller = AnimationController(vsync: this, duration: duration);
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

  void applyOffset(
      {required TranslateInformation from,
      required TranslateInformation to,
      required Duration duration,
      required Curve curve}) {
    _initialize(duration: duration);

    final _controller = controller;
    assert(_controller != null, 'controller must be initialized');
    if (_controller == null) {
      return;
    }
    _start = _transform.offset.dy;
    final dy = _transform.offset.dy + to.offset.dy;
    animation = Tween<double>(begin: 0, end: -dy)
        .animate(CurvedAnimation(parent: _controller, curve: curve));

    controller?.forward();
  }

  void _animaitonChange() {
    final offset =
        Offset(_transform.offset.dx, _start + (animation?.value ?? 0));
    _photoViewController?.updateMultiple(position: offset);
  }
}

class TransformController {
  TransformController();

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
