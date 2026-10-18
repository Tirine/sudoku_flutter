import 'package:flutter/foundation.dart';

void printDebug(String string) {
  if (kDebugMode) {
    print(string);
  }
}

// Name makes it clear
// ignore: avoid_positional_boolean_parameters
bool debugIsNotMounted(bool mounted) {
  if (kDebugMode) {
    if (!mounted) {
      printDebug('Unexpected not mounted.');
      throw StateError('Unexpected not mounted.');
    }
  }
  return !mounted;
}
