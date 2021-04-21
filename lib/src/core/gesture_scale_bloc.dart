import 'package:flutter/material.dart';

class GestureScaleBloc extends StatefulWidget {
  GestureScaleBloc(
      {@required this.child,
      @required this.onScaleStart,
      @required this.onScaleUpdate,
      @required this.onScaleEnd});
  final Widget child;

  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;
  final GestureScaleEndCallback onScaleEnd;

  @override
  State<StatefulWidget> createState() {
    return _GestureScaleBlocState();
  }
}

class _GestureScaleBlocState extends State<GestureScaleBloc> {
  int pointers = 0;
  bool get _isEnabled => pointers > 2;
  @override
  Widget build(BuildContext context) {
    return Listener(
        onPointerDown: (event) =>
            pointers++, // When user will, say, scale some image(two pointers/fingers), <onPointerDown> callback will be called two times, and will increase <pointers> variable to two.
        onPointerUp: (event) =>
            pointers--, // This callback will be called when any user touch will be canceled. You can instead callback [(event) => pointers--] use [(event) => pointers = 0] to ensure that <pointers> variable is reseted.
        child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _isEnabled ? widget.onScaleStart : null,
            onScaleUpdate: _isEnabled ? widget.onScaleUpdate : null,
            onScaleEnd: _isEnabled ? widget.onScaleEnd : null,
            child: widget.child));
  }
}
