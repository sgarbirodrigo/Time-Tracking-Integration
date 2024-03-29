import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:timetrackingintegration/tools/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Tools {
  static dynamic BodyBytesToJson(Uint8List responseBodyBytes) {
    try {
      return json.decode(utf8.decode(responseBodyBytes));
    } catch (e) {
      print("error on bodyBytes: $e");
      return null;
    }
  }

  static String getStringFormatedFromDuration(Duration duration) {
    String stringDebtTime;
    if (duration != null) {
      stringDebtTime = '${duration.toString().split(".")[0]}';
    } else {
      stringDebtTime = "...";
    }
    return stringDebtTime;
  }

  static String generateRandomString(int length) {
    const chars = "abcdefghijklmnopqrstuvwxyz0123456789";
    Random rnd = Random(DateTime.now().millisecondsSinceEpoch);
    String result = "";
    for (var i = 0; i < length; i++) {
      result += chars[rnd.nextInt(chars.length)];
    }
    return result;
  }

  static bool isStringValid(String value) {
    if (value == null) {
      return false;
    }
    if (value == "") {
      return false;
    }
    if (value.isEmpty) {
      return false;
    }
    return true;
  }

  static void showInsertTokensAlert(BuildContext context, String message) {
    Widget okButton = FlatButton(
      child: Text("OK"),
      onPressed: () {
        Navigator.of(context).pop();
        AppSettings.showSettingsPanel(context);
      },
    );
    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("Invalid Tokens"),
      content: Text(message),
      actions: [
        okButton,
      ],
    );
    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  static Color getBackgroundColor(Duration elapsed, Duration minimum) {
    try {

      elapsed = Duration(milliseconds: Duration(minutes:260).inMilliseconds);
      print("${elapsed}/${minimum}");
      Color color;

      Color zeroColor = Colors.red;
      Color intermedium = Colors.orange;
      Color minimumColor = Colors.green;
      Color bestColor = Colors.blue;

      double proportion = elapsed.inMilliseconds / minimum.inMilliseconds;
      print(proportion);
      if (proportion < 0.5) {
        color = Color.lerp(zeroColor, intermedium, proportion/0.5);
      } else if (proportion >= 0.5 && proportion <= 1) {
        color = Color.lerp(intermedium, minimumColor, (proportion-0.5)/0.5);
      } else {
        color = Color.lerp(minimumColor, bestColor, (proportion - 1));
      }
      return color;
    } catch (e) {
      print("background color error: $e");
      return Colors.grey;
    }
  }
}
