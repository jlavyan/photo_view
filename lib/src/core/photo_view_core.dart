import 'package:flutter/widgets.dart';
import 'package:photo_view/photo_view.dart'
    show
        PhotoViewScaleState,
        PhotoViewHeroAttributes,
        PhotoViewImageTapDownCallback,
        PhotoViewImageTapUpCallback,
        ScrollFinishEdgeCallback,
        ScrollEdge,
        ScaleStateCycle;
import 'package:photo_view/photo_view_gesture_detector.dart';
import 'package:photo_view/photo_view_hit_corners.dart';
import 'package:photo_view/photo_view_models.dart';
import 'package:photo_view/src/controller/photo_view_controller.dart';
import 'package:photo_view/src/controller/photo_view_controller_delegate.dart';
import 'package:photo_view/src/controller/photo_view_scalestate_controller.dart';
import 'package:photo_view/src/utils/photo_view_utils.dart';

const _defaultDecoration = const BoxDecoration(
  color: const Color.fromRGBO(0, 0, 0, 1.0),
);

/// Internal widget in which controls all animations lifecycle, core responses
/// to user gestures, updates to  the controller state and mounts the entire PhotoView Layout
class PhotoViewCore extends StatefulWidget {
  const PhotoViewCore({
    Key? key,
    required this.imageProvider,
    required this.backgroundDecoration,
    required this.gaplessPlayback,
    required this.heroAttributes,
    required this.scrollFinishEdgeCallback,
    required this.enableRotation,
    required this.enableMove,
    required this.enableMoveOnMinScale,
    required this.onTapUp,
    required this.onTapDown,
    required this.gestureDetectorBehavior,
    required this.controller,
    required this.scaleBoundaries,
    required this.scaleStateCycle,
    required this.scaleStateController,
    required this.basePosition,
    required this.tightMode,
    required this.bouncing,
    required this.filterQuality,
    required this.disableGestures,
    required this.gestureOut,
    required this.enableDoubleTap,
  })  : customChild = null,
        super(key: key);

  const PhotoViewCore.customChild({
    Key? key,
    required this.customChild,
    required this.backgroundDecoration,
    required this.heroAttributes,
    required this.scrollFinishEdgeCallback,
    required this.enableRotation,
    required this.enableMove,
    required this.enableMoveOnMinScale,
    required this.onTapUp,
    required this.onTapDown,
    required this.gestureDetectorBehavior,
    required this.controller,
    required this.scaleBoundaries,
    required this.scaleStateCycle,
    required this.scaleStateController,
    required this.basePosition,
    required this.tightMode,
    required this.bouncing,
    required this.filterQuality,
    required this.disableGestures,
    required this.enableDoubleTap,
    required this.gestureOut,
  })  : imageProvider = null,
        gaplessPlayback = false,
        super(key: key);

  final Decoration? backgroundDecoration;
  final ImageProvider? imageProvider;
  final bool gaplessPlayback;
  final PhotoViewHeroAttributes? heroAttributes;
  final ScrollFinishEdgeCallback? scrollFinishEdgeCallback;
  final bool enableRotation;
  final bool enableMove;
  final bool enableMoveOnMinScale;
  final Widget? customChild;

  final PhotoViewControllerBase? controller;
  final PhotoViewScaleStateController? scaleStateController;
  final ScaleBoundaries scaleBoundaries;
  final ScaleStateCycle scaleStateCycle;
  final Alignment basePosition;
  final PhotoViewGestureAbstract? gestureOut;

  final PhotoViewImageTapUpCallback? onTapUp;
  final PhotoViewImageTapDownCallback? onTapDown;

  final HitTestBehavior? gestureDetectorBehavior;
  final bool tightMode;
  final bool bouncing;
  final bool disableGestures;
  final bool enableDoubleTap;

  final FilterQuality filterQuality;

  @override
  State<StatefulWidget> createState() {
    return PhotoViewCoreState();
  }

  bool get hasCustomChild => customChild != null;
}

class PhotoViewCoreState extends State<PhotoViewCore>
    with
        TickerProviderStateMixin,
        PhotoViewControllerDelegate,
        HitCornersDetector {
  late Offset _normalizedPosition;
  double? _scaleBefore;
  double? _rotationBefore;

  AnimationController? _scaleAnimationController;
  late Animation<double> _scaleAnimation;

  AnimationController? _positionAnimationController;
  late Animation<Offset> _positionAnimation;

  AnimationController? _rotationAnimationController;
  late Animation<double> _rotationAnimation;

  ScrollController? _verticalScrollController;
  ScrollController? _horizontalScrollController;

  PhotoViewHeroAttributes? get heroAttributes => widget.heroAttributes;

  ScaleBoundaries? cachedScaleBoundaries;

  void handleScaleAnimation() {
    scale = _scaleAnimation.value;
  }

  void handlePositionAnimate() {
    controller!.position = _positionAnimation.value;
  }

  void handleRotationAnimation() {
    controller!.rotation = _rotationAnimation.value;
  }

  void handleVeritcalScrollListener() {
    final double scrollPosition =
        _verticalScrollController!.position.pixels * scale!;
    final double percent =
        scrollPosition.abs() * 100.0 / scaleBoundaries.childSize!.height;

    final ScrollEdge edge =
        scrollPosition > 0 ? ScrollEdge.bottom : ScrollEdge.top;

    if (widget.scrollFinishEdgeCallback != null) {
      widget.scrollFinishEdgeCallback!(edge, percent);
    }
  }

  void handleHorizontalScrollListener() {
    final double scrollPosition =
        _horizontalScrollController!.position.pixels * scale!;
    final double percent =
        scrollPosition.abs() * 100.0 / scaleBoundaries.childSize!.width;

    final ScrollEdge edge =
        scrollPosition > 0 ? ScrollEdge.right : ScrollEdge.left;

    if (widget.scrollFinishEdgeCallback != null) {
      widget.scrollFinishEdgeCallback!(edge, percent);
    }
  }

  void onScaleStart(ChangeStartDetails details) {
    _rotationBefore = controller?.rotation;
    _scaleBefore = scale;
    _normalizedPosition = details.focalPoint - controller!.position!;
    _scaleAnimationController!.stop();
    _positionAnimationController!.stop();
    _rotationAnimationController!.stop();
  }

  void onScaleUpdate(
    ChangeUpdateDetails updateDetails,
  ) {
    final scale = updateDetails.scale;
    final focalPoint = updateDetails.focalPoint;
    final rotation = updateDetails.rotation;
    final double newScale = _scaleBefore! * scale;
    final Offset delta = focalPoint - _normalizedPosition;

    updateScaleStateFromNewScale(newScale);

    updateMultiple(
      scale: newScale,
      position:
          widget.enableMove ? clampPosition(position: delta * scale) : null,
      rotation: widget.enableRotation ? _rotationBefore! + rotation : null,
      rotationFocusPoint: widget.enableRotation ? focalPoint : null,
    );
  }

  void onScaleEnd(ChangeEndDetails details) {
    final double _scale = scale!;
    final Offset? _position = controller!.position;
    final double maxScale = scaleBoundaries.maxScale!;
    final double minScale = scaleBoundaries.minScale;

    //animate back to maxScale if gesture exceeded the maxScale specified
    if (_scale > maxScale) {
      final double scaleComebackRatio = maxScale / _scale;
      animateScale(_scale, maxScale);
      final Offset clampedPosition = clampPosition(
        position: _position! * scaleComebackRatio,
        scale: maxScale,
      );
      animatePosition(_position, clampedPosition);
      return;
    }

    //animate back to minScale if gesture fell smaller than the minScale specified
    if (_scale < minScale) {
      final double scaleComebackRatio = minScale / _scale;
      animateScale(_scale, minScale);
      animatePosition(
        _position,
        clampPosition(
          position: _position! * scaleComebackRatio,
          scale: minScale,
        ),
      );
      return;
    }
    // get magnitude from gesture velocity
    final double magnitude = details.velocity.pixelsPerSecond.distance;

    // animate velocity only if there is no scale change and a significant magnitude
    if (_scaleBefore! / _scale == 1.0 && magnitude >= 400.0) {
      final Offset direction = details.velocity.pixelsPerSecond / magnitude;
      animatePosition(
        _position,
        widget.enableMove
            ? clampPosition(position: _position! + direction * 100.0)
            : _position,
      );
    }
  }

  void onDoubleTap() {
    nextScaleState();
  }

  void animateScale(double? from, double? to) {
    _scaleAnimation = Tween<double>(
      begin: from,
      end: to,
    ).animate(_scaleAnimationController!);
    _scaleAnimationController!
      ..value = 0.0
      ..fling(velocity: 0.4);
  }

  void animatePosition(Offset? from, Offset? to) {
    _positionAnimation = Tween<Offset>(begin: from, end: to)
        .animate(_positionAnimationController!);
    _positionAnimationController!
      ..value = 0.0
      ..fling(velocity: 0.4);
  }

  void animateRotation(double? from, double to) {
    _rotationAnimation = Tween<double>(begin: from, end: to)
        .animate(_rotationAnimationController!);
    _rotationAnimationController!
      ..value = 0.0
      ..fling(velocity: 0.4);
  }

  void onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      onAnimationStatusCompleted();
    }
  }

  /// Check if scale is equal to initial after scale animation update
  void onAnimationStatusCompleted() {
    if (scaleStateController!.scaleState != PhotoViewScaleState.initial &&
        scale == scaleBoundaries.initialScale) {
      scaleStateController!.setInvisibly(PhotoViewScaleState.initial);
    }
  }

  @override
  void initState() {
    super.initState();
    _scaleAnimationController = AnimationController(vsync: this)
      ..addListener(handleScaleAnimation);
    _scaleAnimationController!.addStatusListener(onAnimationStatus);

    _positionAnimationController = AnimationController(vsync: this)
      ..addListener(handlePositionAnimate);

    _rotationAnimationController = AnimationController(vsync: this)
      ..addListener(handleRotationAnimation);

    _verticalScrollController = ScrollController()
      ..addListener(handleVeritcalScrollListener);

    _horizontalScrollController = ScrollController()
      ..addListener(handleHorizontalScrollListener);

    _initGestureOut();
    initDelegate();
    addAnimateOnScaleStateUpdate(animateOnScaleStateUpdate);

    cachedScaleBoundaries = widget.scaleBoundaries;
  }

  void _initGestureOut() {
    widget.gestureOut
      ?..onDoubleTap = widget.enableDoubleTap ? nextScaleState : null
      ..onScaleStart = onScaleStart
      ..onScaleEnd = onScaleEnd
      ..onScaleUpdate = onScaleUpdate
      ..hitDetector = this
      ..onTapUp = widget.onTapUp == null ? null : onTapUp
      ..onTapDown = widget.onTapDown == null ? null : onTapDown;
  }

  void animateOnScaleStateUpdate(double? prevScale, double? nextScale) {
    animateScale(prevScale, nextScale);
    animatePosition(controller!.position, Offset.zero);
    animateRotation(controller!.rotation, 0.0);
  }

  @override
  void dispose() {
    _scaleAnimationController!.removeStatusListener(onAnimationStatus);
    _scaleAnimationController!.dispose();
    _positionAnimationController!.dispose();
    _rotationAnimationController!.dispose();
    _verticalScrollController!.dispose();
    _horizontalScrollController!.dispose();
    super.dispose();
  }

  void onTapUp(TapUpDetails details) {
    widget.onTapUp?.call(context, details, controller!.value);
  }

  void onTapDown(TapDownDetails details) {
    widget.onTapDown?.call(context, details, controller!.value);
  }

  @override
  Widget build(BuildContext context) {
    // Check if we need a recalc on the scale
    if (widget.scaleBoundaries != cachedScaleBoundaries) {
      markNeedsScaleRecalc = true;
      cachedScaleBoundaries = widget.scaleBoundaries;
    }

    return StreamBuilder(
        stream: controller!.outputStateStream,
        initialData: controller!.prevValue,
        builder: (
          BuildContext context,
          AsyncSnapshot<PhotoViewControllerValue?> snapshot,
        ) {
          if (snapshot.hasData) {
            final PhotoViewControllerValue value = snapshot.data!;
            final useImageScale = widget.filterQuality != FilterQuality.none;
            final computedScale = useImageScale ? 1.0 : scale;

            CornersRange cornersXx = cornersX(scale: scale);
            CornersRange cornersYy = cornersY(scale: scale);
            bool isXEdge = ((value.position!.dx - cornersXx.min).abs() < 0.1 ||
                    (value.position!.dx - cornersXx.max).abs() < 0.1) &&
                scale != 1 &&
                widget.bouncing;
            bool isYEdge = ((value.position!.dy - cornersYy.min).abs() < 0.1 ||
                    (value.position!.dy - cornersYy.max).abs() < 0.1) &&
                scale != 1 &&
                widget.bouncing;

            final matrix = Matrix4.identity()
              ..translate(value.position!.dx, value.position!.dy)
              ..scale(computedScale)
              ..rotateZ(value.rotation!);

            final Widget customChildLayout = CustomSingleChildLayout(
                delegate: _CenterWithOriginalSizeDelegate(
                  scaleBoundaries.childSize,
                  basePosition,
                  useImageScale,
                ),
                child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: isXEdge
                        ? BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics())
                        : NeverScrollableScrollPhysics(),
                    child: SingleChildScrollView(
                        controller: _verticalScrollController,
                        scrollDirection: Axis.vertical,
                        physics: isYEdge
                            ? BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics())
                            : NeverScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints.tight(scaleBoundaries.childSize!),
                          child: _buildHero(),
                        ))));

            final child = Container(
              constraints: widget.tightMode
                  ? BoxConstraints.tight(scaleBoundaries.childSize! * scale!)
                  : null,
              child: Center(
                child: Transform(
                  child: customChildLayout,
                  transform: matrix,
                  alignment: basePosition,
                ),
              ),
              decoration: widget.backgroundDecoration ?? _defaultDecoration,
            );

            if (widget.disableGestures) {
              return child;
            }

            if (widget.gestureOut == null) {
              return PhotoViewGestureDetector(
                child: child,
                onDoubleTap: widget.enableDoubleTap ? nextScaleState : null,
                onScaleStart: onScaleStart,
                onScaleUpdate: onScaleUpdate,
                onScaleEnd: onScaleEnd,
                hitDetector: this,
                onTapUp: widget.onTapUp == null ? null : onTapUp,
                onTapDown: widget.onTapDown == null ? null : onTapDown,
              );
            } else {
              return child;
            }
          } else {
            return Container();
          }
        });
  }

  Widget? _buildHero() {
    return heroAttributes != null
        ? Hero(
            tag: heroAttributes!.tag,
            createRectTween: heroAttributes!.createRectTween,
            flightShuttleBuilder: heroAttributes!.flightShuttleBuilder,
            placeholderBuilder: heroAttributes!.placeholderBuilder,
            transitionOnUserGestures: heroAttributes!.transitionOnUserGestures,
            child: _buildChild()!,
          )
        : _buildChild();
  }

  Widget? _buildChild() {
    return widget.hasCustomChild
        ? widget.customChild
        : Image(
            image: widget.imageProvider!,
            gaplessPlayback: widget.gaplessPlayback,
            filterQuality: widget.filterQuality,
            width: scaleBoundaries.childSize!.width * scale!,
            fit: BoxFit.contain,
          );
  }
}

class _CenterWithOriginalSizeDelegate extends SingleChildLayoutDelegate {
  const _CenterWithOriginalSizeDelegate(
    this.subjectSize,
    this.basePosition,
    this.useImageScale,
  );

  final Size? subjectSize;
  final Alignment basePosition;
  final bool useImageScale;

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final childWidth = useImageScale ? childSize.width : subjectSize!.width;
    final childHeight = useImageScale ? childSize.height : subjectSize!.height;

    final halfWidth = (size.width - childWidth) / 2;
    final halfHeight = (size.height - childHeight) / 2;

    final double offsetX = halfWidth * (basePosition.x + 1);
    final double offsetY = halfHeight * (basePosition.y + 1);
    return Offset(offsetX, offsetY);
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return useImageScale
        ? const BoxConstraints()
        : BoxConstraints.tight(subjectSize!);
  }

  @override
  bool shouldRelayout(_CenterWithOriginalSizeDelegate oldDelegate) {
    return oldDelegate != this;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CenterWithOriginalSizeDelegate &&
          runtimeType == other.runtimeType &&
          subjectSize == other.subjectSize &&
          basePosition == other.basePosition &&
          useImageScale == other.useImageScale;

  @override
  int get hashCode =>
      subjectSize.hashCode ^ basePosition.hashCode ^ useImageScale.hashCode;
}
