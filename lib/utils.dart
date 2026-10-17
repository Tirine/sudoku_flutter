import 'package:flutter/foundation.dart';

void printDebug(String string) {
  if (kDebugMode) {
    print(string);
  }
}
