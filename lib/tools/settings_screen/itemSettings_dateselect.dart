import 'package:TimeTrackingIntegration/toggl/toggl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ItemSettingsDate extends StatefulWidget {
  String pageTitle, sharedVariableName;

  ItemSettingsDate(this.pageTitle, this.sharedVariableName);

  @override
  _ItemSettingsDateState createState() => _ItemSettingsDateState();
}

class _ItemSettingsDateState extends State<ItemSettingsDate> {
  SharedPreferences prefs;
  DateTime date;

  @override
  void initState() {
    super.initState();
    _load();
  }

  _load() async {
    prefs = await SharedPreferences.getInstance();
    date = DateTime.tryParse(await prefs.getString(widget.sharedVariableName));
    if (date == null) {
      date = DateTime.now().add(Duration(seconds: -60));
    }
    print("load: $date");
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
              Navigator.pop(context, date);
            },
          ),
        ),
        middle: Text(widget.pageTitle),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[

            Expanded(
              child: Container(
                //color: Colors.white,
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: date,
                  //backgroundColor: Colors.black12.withOpacity(0.01),
                  maximumDate: DateTime(DateTime.now().year,
                      DateTime.now().month, DateTime.now().day, 23, 59),
                  onDateTimeChanged: (dateUpdated) async {
                    await prefs.setString(
                        widget.sharedVariableName, dateUpdated.toString());
                    print("dateUpdated: $dateUpdated");
                    print("date: $date");
                    date = dateUpdated;
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
