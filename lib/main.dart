import 'package:timetrackingintegration/tools/constants.dart';
import 'package:timetrackingintegration/tools/custom_scrollcontrol.dart';
import 'package:timetrackingintegration/tools/settings.dart';
import 'package:timetrackingintegration/tools/tools.dart';
import 'package:timetrackingintegration/widgets/topbar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'alarm/alarm.dart';
import 'jira/jira.dart';
import 'pomodoro/pomodoro.dart';
import 'toggl/toggl.dart';

void main() {
  Alarm.initialMainConfig();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
            body: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.light, child: MainPage())),
      ),
    );
  });
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Streams are created so that app can respond to notification-related events since the plugin is initialised in the `main` function
final BehaviorSubject<ReceivedNotification> didReceiveLocalNotificationSubject =
    BehaviorSubject<ReceivedNotification>();

final BehaviorSubject<String> selectNotificationSubject =
    BehaviorSubject<String>();

NotificationAppLaunchDetails notificationAppLaunchDetails;

class ReceivedNotification {
  final int id;
  final String title;
  final String body;
  final String payload;

  ReceivedNotification({
    @required this.id,
    @required this.title,
    @required this.body,
    @required this.payload,
  });
}

class _MainPageState extends State<MainPage> {
  Toggl toggl;
  Jira jira;
  JiraIssues jiraIssues;
  Issues selectedIssue;
  int numberPomodore;
  Duration timeDebt, timeElapsedToday, dailyMinimum;
  Color activeColor = Colors.green;
  bool countTime;
  TextEditingController _extraDescriptionController;
  SharedPreferences prefs;
  bool isAnimating = false;
  bool isPendingView = true;
  bool isTokensOk = true;
  List<String> recents = List();
  RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  ScrollController _scrollController = ScrollController();

  final MethodChannel platform =
      MethodChannel('crossingthestreams.io/resourceResolver');

  void initState() {
    super.initState();
    toggl = Toggl();
    countTime = true;
    _extraDescriptionController = TextEditingController(text: "");
    _scrollController = ScrollController();

    _requestIOSPermissions();
    _loadData();
  }

  _checkTokens() async {
    String email_jira =
        prefs.getString(SharedPreferenceConstants.EMAIL_JIRA) ?? "";

    String token_jira =
        prefs.getString(SharedPreferenceConstants.TOKEN_JIRA) ?? "";

    String token_toggl =
        prefs.getString(SharedPreferenceConstants.TOKEN_TOGGL) ?? "";

    if (!Tools.isStringValid(email_jira)) {
      isTokensOk = false;
    }

    if (!Tools.isStringValid(token_jira)) {
      isTokensOk = false;
    }
    if (!Tools.isStringValid(token_toggl)) {
      isTokensOk = false;
    }
  }

  _loadSharedPreferences() async {
    numberPomodore =
        (await prefs.getInt(SharedPreferenceConstants.POMODORO_QUANT)) ?? 3;
    dailyMinimum = Duration(
        milliseconds:
            (await prefs.getInt(SharedPreferenceConstants.DURATION_MIN) ??
                Duration(hours: 3, minutes: 0).inMilliseconds));
  }

  void _requestIOSPermissions() {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  @override
  void dispose() {
    didReceiveLocalNotificationSubject.close();
    selectNotificationSubject.close();
    super.dispose();
  }

  _loadData() async {
    prefs = await SharedPreferences.getInstance();
    isTokensOk = true;
    await _checkTokens();
    await _loadSharedPreferences();
    await _loadDebtTime();
    await _loadJiraIssues();
    setState(() {});
  }

  _loadJiraIssues() async {
    try {
      jira = Jira(maxResults: 50);
      JiraIssues jiraResult = await jira.getIssues();
      recents = await toggl.getRecents();
      this.selectedIssue = jiraResult.issues[0];
      setState(() {
        this.jiraIssues = jiraResult;
      });
    } catch (e) {
      this.selectedIssue = null;
      recents = List();
      jiraIssues = null;
      isTokensOk = false;
    }
  }

  void _loadDebtTime() async {
    try {
      Duration minDaily = Duration(
          milliseconds:
              (await prefs.getInt(SharedPreferenceConstants.DURATION_MIN)) ??
                  Duration(hours: 2, minutes: 30).inMilliseconds);
      DateTime since = DateTime.tryParse(
          await prefs.getString(SharedPreferenceConstants.DATE_SINCE));
      timeDebt = await toggl.getAccumulatedDebit(since, minDaily);
      timeElapsedToday = await toggl.getAccumulatedTime(DateTime.now());
      //print("timeDebt:$timeDebt");
      //print("timeElapsedToday:$timeElapsedToday");
      /*if (timeDebt.isNegative ||
          timeElapsedToday.inMilliseconds < minDaily.inMilliseconds) {
        activeColor = Colors.red;
      } else {
        activeColor = Colors.green;
      }*/
      activeColor = Tools.getBackgroundColor(timeElapsedToday, minDaily);
    } catch (e) {
      isTokensOk = false;
      print("load toggl error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    var data = MediaQuery.of(context);
    double heightFinal = data.size.height - 54 - kToolbarHeight;
    return RefreshConfiguration(
        headerTriggerDistance: 10.0,
        // header trigger refresh trigger distance
        springDescription:
            SpringDescription(stiffness: 170, damping: 16, mass: 1.9),
        // custom spring back animate,the props meaning see the flutter api
        maxOverScrollExtent: 24,
        //The maximum dragging range of the head. Set this property if a rush out of the view area occurs
        maxUnderScrollExtent: 0,
        // Maximum dragging range at the bottom
        enableScrollWhenRefreshCompleted: true,
        //This property is incompatible with PageView and TabBarView. If you need TabBarView to slide left and right, you need to set it to true.
        enableLoadingWhenFailed: true,
        //In the case of load failure, users can still trigger more loads by gesture pull-up.
        hideFooterWhenNotFull: true,
        // Disable pull-up to load more functionality when Viewport is less than one screen
        enableBallisticLoad: false,
        // trigger load more by BallisticScrollActivity
        child: Material(
          color: activeColor,
          child: SafeArea(
            top: true,
            child: SmartRefresher(
              enablePullDown: true,
              enablePullUp: false,
              physics: CustomScrollPhysics(),
              header: WaterDropHeader(
                waterDropColor: Colors.lightBlue,
                complete: Icon(Icons.cloud_done,color: Colors.white,),
              ),
              controller: _refreshController,
              onRefresh: _onRefresh,
              onLoading: _onLoading,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: MyTopBar(
                      isAnimating: isAnimating,
                      timeDebt: timeDebt,
                      timeElapsedToday: timeElapsedToday,
                      onRequestReload: () {
                        _loadData();
                      },
                    ),
                  ),
                  isTokensOk
                      ? Positioned(
                          top: !isAnimating ? 36 : 0,
                          left: 0,
                          right: 0,
                          bottom: isAnimating ? 0 : null,
                          child: Pomodoro(
                              dailyMinimum: dailyMinimum,
                              numberPomodore: numberPomodore,
                              elapsedToday: timeElapsedToday,
                              activeColor: activeColor,
                              selectedIssue: this.selectedIssue,
                              countTime: countTime,
                              onStatusChange: (isAnimating) {
                                print("Status: ${isAnimating}");
                                this.isAnimating = isAnimating;
                                setState(() {});
                              },
                              onFinish: (elapsedTime, startDate) async {
                                bool ring = true;
                                Future.delayed(
                                    const Duration(milliseconds: 500),
                                    () async {
                                  while (ring) {
                                    await FlutterRingtonePlayer.play(
                                        android: AndroidSounds.alarm,
                                        ios: IosSounds.alarm,
                                        looping: true,
                                        volume: 1.0,
                                        asAlarm: true);
                                    await Future.delayed(
                                        const Duration(seconds: 2));
                                  }
                                });
                                String task;
                                if (isPendingView) {
                                  print(
                                      "ElapsedTime: ${elapsedTime} \n StartDate: ${startDate}");
                                  task = this.selectedIssue.key +
                                      ": " +
                                      this.selectedIssue.fields.summary;
                                } else {
                                  task = _extraDescriptionController.text;
                                }
                                var result = await _showDialog(
                                    context, elapsedTime, task, startDate);
                                print("dialog result: ${result}");
                                setState(() {
                                  ring = false;
                                });
                                if (result == "save") {
                                  if (!isPendingView) {
                                    await toggl.postTime(
                                        duration: elapsedTime,
                                        startDate: startDate,
                                        countTime: countTime,
                                        description:
                                            _extraDescriptionController.text);
                                  } else {
                                    await toggl.postTime(
                                        description:
                                            "${this.selectedIssue.key}: ${this.selectedIssue.fields.summary}",
                                        duration: elapsedTime,
                                        startDate: startDate,
                                        sprint: this
                                            .selectedIssue
                                            .fields
                                            .parent
                                            .fields
                                            .summary);
                                  }
                                  _loadData();
                                }
                              }),
                        )
                      : Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          top: 42,
                          child: Center(
                              child: Container(
                                  height: 64,
                                  width: 256,
                                  child: RaisedButton(
                                    onPressed: () {
                                      AppSettings.showSettingsPanel(context);
                                    },
                                    color: Colors.white,
                                    child: Text(
                                      "You must insert your Jira and Toggl tokens",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.deepOrangeAccent,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w300),
                                    ),
                                  )))),
                  isTokensOk
                      ? Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: 64.0,
                              maxHeight: heightFinal - data.size.width,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                isAnimating
                                    ? Container()
                                    : Row(
                                        children: <Widget>[
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 16, top: 0, bottom: 0),
                                            child: FlatButton(
                                              child: Text(
                                                'Pending',
                                                textAlign: TextAlign.left,
                                                style: TextStyle(
                                                    shadows: isPendingView
                                                        ? <Shadow>[
                                                            Shadow(
                                                              offset:
                                                                  Offset(0, 0),
                                                              blurRadius: 4,
                                                              color: Color
                                                                  .fromARGB(127,
                                                                      0, 0, 0),
                                                            )
                                                          ]
                                                        : null,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w400,
                                                    color: Colors.white),
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  isPendingView = true;
                                                  if (this.jiraIssues != null) {
                                                    this.selectedIssue = this
                                                        .jiraIssues
                                                        .issues[0];
                                                  }
                                                  countTime = true;
                                                });
                                              },
                                            ),
                                          ),
                                          Expanded(
                                            child: Container(),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 0, bottom: 0, right: 16),
                                            child: FlatButton(
                                              child: Text(
                                                'Extra',
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                    shadows: !isPendingView
                                                        ? <Shadow>[
                                                            Shadow(
                                                              offset:
                                                                  Offset(0, 0),
                                                              blurRadius: 4,
                                                              color: Color
                                                                  .fromARGB(127,
                                                                      0, 0, 0),
                                                            )
                                                          ]
                                                        : null,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w400,
                                                    color: Colors.white),
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  isPendingView = false;
                                                  this.selectedIssue = Issues(
                                                      fields: Fields(
                                                          summary:
                                                              _extraDescriptionController
                                                                  .text));
                                                });
                                              },
                                            ),
                                          )
                                        ],
                                      ),
                                AnimatedContainer(
                                  height: !isAnimating
                                      ? heightFinal - data.size.width - 48
                                      : 0,
                                  child: Card(
                                      clipBehavior: Clip.antiAlias,
                                      margin: EdgeInsets.only(
                                          left: 8, right: 8, top: 0, bottom: 8),
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(4.0),
                                      ),
                                      child: isPendingView
                                          ? history(context)
                                          : extras(context)),
                                  duration: Duration(milliseconds: 300),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Container(),
                ],
              ),
            ),
          ),
        ));
  }

  void _onRefresh() async {
    await _loadData();
    // if failed,use refreshFailed()
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    // monitor network fetch
    await Future.delayed(Duration(milliseconds: 1000));
    // if failed,use loadFailed(),if no data return,use LoadNodata()
    if (mounted) setState(() {});
    _refreshController.loadComplete();
  }

  Widget extras(BuildContext context) {
    return Column(children: <Widget>[
      Container(
        color: activeColor.withOpacity(0.1),
        padding: EdgeInsets.only(left: 0, bottom: 16, right: 16, top: 16),
        child: Row(children: <Widget>[
          Container(
            width: 16,
          ),
          Expanded(
            child: TextField(
              controller: _extraDescriptionController,
              decoration: InputDecoration(
                suffix: _extraDescriptionController.text.isNotEmpty
                    ? GestureDetector(
                        child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              "CLEAR",
                              style: TextStyle(fontSize: 12),
                            )),
                        onTap: () {
                          _extraDescriptionController.clear();
                          this.selectedIssue = null;
                          setState(() {});
                        },
                      )
                    : null,
                labelText: "What do you wanna do?",
                alignLabelWithHint: true,
                contentPadding:
                    EdgeInsets.only(left: 0, bottom: 0, top: 0, right: 0),
              ),
              onChanged: (value) async {
                Issues jiraIssue = Issues();
                Fields fields =
                    Fields(summary: _extraDescriptionController.text);

                jiraIssue.fields = fields;
                this.selectedIssue = jiraIssue;
                if (_extraDescriptionController.text.isEmpty) {
                  this.selectedIssue = null;
                }
                setState(() {});
              },
            ),
          ),
          IconButton(
            tooltip: "Discount from goal",
            icon: Icon(
              countTime ? Icons.timer : Icons.timer_off,
              color: countTime ? activeColor : Colors.grey.withOpacity(0.6),
            ),
            onPressed: () {
              setState(() {
                countTime = !countTime;
              });
            },
          )
        ]),
      ),
      Container(color: Colors.grey.withOpacity(0.5), height: 0.5),
      Container(
          color: Colors.grey.withOpacity(0.1),
          height: 24,
          child: Center(child: Text("Recent"))),
      recents.isNotEmpty
          ? Expanded(
              child: ListView.builder(
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  itemCount: recents.length,
                  itemBuilder: (BuildContext context, int index) {
                    return GestureDetector(
                        onTap: () {
                          _extraDescriptionController.text = recents[index];
                          Issues jiraIssue = Issues();
                          Fields fields =
                              Fields(summary: _extraDescriptionController.text);

                          jiraIssue.fields = fields;
                          this.selectedIssue = jiraIssue;
                          setState(() {});
                        },
                        child: Container(
                            color: Colors.white,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.max,
                                children: <Widget>[
                                  Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      child: Text(
                                        recents[index],
                                        style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 16),
                                      )),
                                  Container(
                                      color: Colors.grey.withOpacity(0.5),
                                      height: 0.5)
                                ])));
                  }))
          : Container()
    ]);
  }

  Widget history(BuildContext context) {
    return Container(
      child: this.jiraIssues != null
          ? ListView.builder(
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              itemCount: this.jiraIssues.issues.length,
              itemBuilder: (BuildContext context, int index) {
                return item(
                    context,
                    this.jiraIssues.issues[index],
                    this.jiraIssues.issues[index].key ==
                        (this.selectedIssue != null
                            ? this.selectedIssue.key
                            : ""));
              })
          : Container(),
    );
  }

  String getSpentAmount(int seconds) {
    if (seconds == null) {
      return "-";
    }
    return "${Duration(seconds: seconds).toString().split(".")[0]}";
  }

  _showDialog(
      BuildContext context, Duration elapsedTime, String taskDone, startDate) {
    return showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              height: 300,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.check,
                    color: Colors.green,
                    size: 96,
                  ),
                  Text(
                    "DONE",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 38),
                  ),
                  Container(
                    height: 16,
                  ),
                  Expanded(
                    child: Text(
                      "You've focused for ${elapsedTime.toString().split(".")[0]} into ${taskDone}",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w200,
                          color: Colors.black87,
                          fontSize: 16),
                    ),
                  ),
                  Container(
                    height: 16,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      FlatButton(
                        child: Text(
                          "Cancel",
                        ),
                        onPressed: () {
                          Navigator.of(context).pop("cancel");
                        },
                      ),
                      Container(
                        width: 16,
                      ),
                      RaisedButton(
                        color: Colors.green,
                        child: Text(
                          "Save",
                          style: TextStyle(color: Colors.white),
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop("save");
                        },
                      )
                    ],
                  )
                ],
              ),
            ),
          );
        });
  }

  Widget item(BuildContext context, Issues issue, bool active) {
    return Column(children: <Widget>[
      GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              this.selectedIssue = issue;
            });
          },
          child: Slidable(
            actionPane: SlidableDrawerActionPane(),
            actionExtentRatio: 0.25,
            child: Container(
                color: active
                    ? activeColor.withOpacity(0.1)
                    : activeColor.withOpacity(0),
                padding: EdgeInsets.only(
                  left: 0,
                  right: 16,
                ),
                child: Row(children: <Widget>[
                  active
                      ? Container(
                          width: 4,
                          height: 64,
                          color: activeColor,
                        )
                      : Container(
                          width: 4,
                          height: 64,
                        ),
                  Container(
                    width: 16,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          issue.fields.summary,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.normal,
                              color: Colors.black87),
                        ),
                        Text(
                          issue.key,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey,
                          ),
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                      width: 48,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Text(issue.fields.customfield_10016.toString(),
                              style: TextStyle(
                                  color: Colors.grey,
                                  decoration: TextDecoration.none,
                                  fontWeight: FontWeight.w500)),
                          Text(
                            //todo let the user select the unit used
                            "Pag.",
                            style: TextStyle(
                              fontSize: 10.0,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ))
                ])),
            actions: <Widget>[],
            secondaryActions: <Widget>[
              IconSlideAction(
                caption: 'Mark as done',
                color: Colors.blue,
                icon: Icons.done_outline,
                onTap: () async {
                  int responseStatus = await jira.updateIssue(issue.key);
                  print("Response code: $responseStatus");
                  if (responseStatus >= 200 && responseStatus < 300) {
                    _loadData();
                  }
                },
              ),
            ],
          )),
      Container(color: Colors.grey.withOpacity(0.5), height: 0.5)
    ]);
  }
}
