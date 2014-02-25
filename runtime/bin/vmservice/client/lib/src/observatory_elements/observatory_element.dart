// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library observatory_element;

import 'dart:math';
import 'package:polymer/polymer.dart';
import 'package:observatory/observatory.dart';
export 'package:observatory/observatory.dart';

/// Base class for all custom elements. Holds an observable
/// [ObservableApplication] and applies author styles.
@CustomTag('observatory-element')
class ObservatoryElement extends PolymerElement {
  ObservatoryElement.created() : super.created();

  void enteredView() {
    super.enteredView();
  }

  void leftView() {
    super.leftView();
  }

  void attributeChanged(String name, String oldValue, String newValue) {
    super.attributeChanged(name, oldValue, newValue);
  }

  @published ObservatoryApplication app;
  void appChanged(oldValue) {
  }
  bool get applyAuthorStyles => true;

  static String _zeroPad(int value, int pad) {
    String prefix = "";
    while (pad > 1) {
      int pow10 = pow(10, pad - 1);
      if (value < pow10) {
        prefix = prefix + "0";
      }
      pad--;
    }
    return "${prefix}${value}";
  }

  String formatTime(double time) {
    if (time == null) {
      return "-";
    }
    const millisPerHour = 60 * 60 * 1000;
    const millisPerMinute = 60 * 1000;
    const millisPerSecond = 1000;

    var millis = (time * millisPerSecond).round();

    var hours = millis ~/ millisPerHour;
    millis = millis % millisPerHour;

    var minutes = millis ~/ millisPerMinute;
    millis = millis % millisPerMinute;

    var seconds = millis ~/ millisPerSecond;
    millis = millis % millisPerSecond;

    return ("${_zeroPad(hours,2)}"
            ":${_zeroPad(minutes,2)}"
            ":${_zeroPad(seconds,2)}"
            ".${_zeroPad(millis,3)}");

  }

  String formatSize(int bytes) {
    const int bytesPerKB = 1024;
    const int bytesPerMB = 1024 * bytesPerKB;
    const int bytesPerGB = 1024 * bytesPerMB;
    const int bytesPerTB = 1024 * bytesPerGB;

    if (bytes < bytesPerKB) {
      return "${bytes}B";
    } else if (bytes < bytesPerMB) {
      return "${(bytes / bytesPerKB).round()}KB";
    } else if (bytes < bytesPerGB) {
      return "${(bytes / bytesPerMB).round()}MB";
    } else if (bytes < bytesPerTB) {
      return "${(bytes / bytesPerGB).round()}GB";
    } else {
      return "${(bytes / bytesPerTB).round()}TB";
    }
  }

  String fileAndLine(Map frame) {
    var file = frame['script']['user_name'];
    var shortFile = file.substring(file.lastIndexOf('/') + 1);
    return "${shortFile}:${frame['line']}";    
  }
}