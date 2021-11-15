import 'package:flutter/cupertino.dart';

class BouncingNeverScrollable extends BouncingScrollPhysics {
  const BouncingNeverScrollable({ScrollPhysics? parent})
      : super(parent: parent);

  @override
  BouncingNeverScrollable applyTo(ScrollPhysics? ancestor) {
    return BouncingNeverScrollable(parent: buildParent(ancestor));
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;

  @override
  bool get allowImplicitScrolling => false;
}
