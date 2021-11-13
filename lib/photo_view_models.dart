import 'dart:ui';

import 'package:flutter/widgets.dart';

typedef ScaleUpdateCallback = void Function(ChangeUpdateDetails updateDetails);

typedef ScaleStartCallback = void Function(ChangeStartDetails updateDetails);

typedef ScaleEndCallback = void Function(ChangeEndDetails updateDetails);

class ChangeUpdateDetails {
  ChangeUpdateDetails(
      {required this.focalPoint, required this.scale, required this.rotation});
  Offset focalPoint;
  double scale;
  double rotation;
}

class ChangeStartDetails {
  ChangeStartDetails({required this.focalPoint});

  ChangeStartDetails.fromScale(ScaleStartDetails details)
      : focalPoint = details.focalPoint;

  Offset focalPoint;
}

class ChangeEndDetails {
  ChangeEndDetails({required this.velocity});

  ChangeEndDetails.fromScale(ScaleEndDetails details)
      : velocity = details.velocity;

  Velocity velocity;
}
