import '../backdrop.dart';

/// A backdrop that draws nothing.
class EmptyBackdrop extends Backdrop {
  const EmptyBackdrop();

  @override
  bool get isCoordinatesDependent => false;

  @override
  void drawBackdrop(BackdropDrawContext context) {}

  @override
  bool operator ==(Object other) => other is EmptyBackdrop;

  @override
  int get hashCode => (EmptyBackdrop).hashCode;
}

/// The shared [EmptyBackdrop] instance.
const Backdrop emptyBackdrop = EmptyBackdrop();
