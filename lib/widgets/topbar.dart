import 'package:timetrackingintegration/tools/constants.dart';
import 'package:timetrackingintegration/tools/settings.dart';
import 'package:timetrackingintegration/tools/tools.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyTopBar extends StatefulWidget {
  Function onRequestReload;
  Duration timeElapsedToday, timeDebt;
  bool isAnimating;

  MyTopBar(
      {this.onRequestReload,
      this.timeElapsedToday,
      this.timeDebt,
      this.isAnimating});

  @override
  _MyTopBarState createState() => _MyTopBarState();
}

class _MyTopBarState extends State<MyTopBar> {
  @override
  void initState() {
    super.initState();
  }
  String _value;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 8,
          ),
          /*Container(
            width: 32,
            child: !widget.isAnimating
                ? IconButton(
                    icon: Icon(Icons.refresh),
                    tooltip: "Refresh",
                    color: Colors.white,
                    onPressed: () async {
                      widget.onRequestReload();
                    },
                  )
                : null,
          ),*/
          Container(width: 64),
          /*Container(
            width: 32,
            child: !widget.isAnimating
                ? IconButton(
                    icon: Icon(Icons.text_fields),
                    tooltip: "Test button",
                    color: Colors.white,
                    onPressed: () async {
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      String email_jira = prefs.getString(
                              SharedPreferenceConstants.EMAIL_JIRA) ??
                          "";

                      String token_jira = prefs.getString(
                              SharedPreferenceConstants.TOKEN_JIRA) ??
                          "";

                      String token_toggl = prefs.getString(
                              SharedPreferenceConstants.TOKEN_TOGGL) ??
                          "";
                      print("email_jira: $email_jira");
                      print("token_jira: $token_jira");
                      print("token_toggl: $token_toggl");
                    },
                  )
                : null,
          ),*/
          Expanded(
            child: Container(
              color: Colors.transparent,
            ),
          ),
          Column(
            children: <Widget>[
              Text(
                "Today: ${Tools.getStringFormatedFromDuration(widget.timeElapsedToday)}",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    shadows: <Shadow>[
                      Shadow(
                        offset: Offset(1.0, 1.0),
                        blurRadius: 10.0,
                        color: Color.fromARGB(128, 0, 0, 0),
                      ),
                    ],
                    fontWeight: FontWeight.bold),
              ),
              Text(
                "Balance: ${Tools.getStringFormatedFromDuration(widget.timeDebt)}",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    shadows: <Shadow>[
                      Shadow(
                        offset: Offset(1.0, 1.0),
                        blurRadius: 10.0,
                        color: Color.fromARGB(128, 0, 0, 0),
                      ),
                    ],
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Expanded(child: Container()),
          Container(width: 32),
          Container(
            width: 32,
            child: !widget.isAnimating
                ? IconButton(
                    icon: Icon(Icons.settings),
                    color: Colors.white,
                    onPressed: () async {
                      //_showSettingsDialog(context);
                      await AppSettings.showSettingsPanel(context);
                      widget.onRequestReload();
                    },
                  )
                : null,
          ),
          Container(
            width: 16,
          )
        ],
      ),
    );
  }
}
