import 'package:timetrackingintegration/toggl/toggl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ItemSettingsTime extends StatefulWidget {
  String pageTitle, sharedVariableName;

  ItemSettingsTime(this.pageTitle, this.sharedVariableName);

  @override
  _ItemSettingsTimeState createState() => _ItemSettingsTimeState();
}

class _ItemSettingsTimeState extends State<ItemSettingsTime> {
  SharedPreferences prefs;
  Duration duration;

  @override
  void initState() {
    super.initState();
    _load();
  }

  _load() async {
    prefs = await SharedPreferences.getInstance();
    try {
      int milliseconds = await prefs.getInt(widget.sharedVariableName);
      duration =
          Duration(milliseconds: milliseconds);
    } catch (e) {

      print("erro _load: $e");
      duration = Duration(hours: 2, minutes: 30);
    }

    print("load: $duration");
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        padding: EdgeInsetsDirectional.only(start: 0),
        leading: Container(
          padding: EdgeInsets.only(left: 0),
          child: IconButton(
            iconSize: 32,
            icon: Icon(
              Icons.chevron_left,
              color: Colors.blue,
            ),
            onPressed: () {
              Navigator.pop(context, duration);
            },
          ),
        ),
        middle: Text(widget.pageTitle),
      ),
      child: SafeArea(
        child: duration!=null?Column(
          children: <Widget>[
            Expanded(
              child: Container(
                //color: Colors.white,
                height: 200,
                child: CupertinoTimerPicker(
                  backgroundColor: Colors.black12.withOpacity(0.01),
                  //mode: CupertinoDatePickerMode.date,
                  mode: CupertinoTimerPickerMode.hm,
                  initialTimerDuration:
                      duration,
                  //backgroundColor: Colors.black12.withOpacity(0.01),
                  onTimerDurationChanged: (durationUpdated) async {
                    duration = durationUpdated;
                    var result = await prefs.setInt(
                        widget.sharedVariableName, duration.inMilliseconds);

                  },
                ),
              ),
            )
          ],
        ):Center(child: Container(child: CircularProgressIndicator(),),),
      ),
    );
  }
}
