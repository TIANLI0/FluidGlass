/// Device facts that only `dart:io` can answer, stubbed for platforms without
/// it.
///
/// Zero and the empty string both mean "unknown", which the classifier treats
/// as "do not penalise the device" — guessing low on missing information would
/// quietly downgrade every web build.
int get platformProcessorCount => 0;

String get platformArchitecture => '';
