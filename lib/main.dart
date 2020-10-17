import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:timetrackingintegration/tools/constants.dart';
import 'package:timetrackingintegration/tools/custom_scrollcontrol.dart';
import 'package:timetrackingintegration/tools/lifecycle.dart';
import 'package:timetrackingintegration/tools/settings.dart';
import 'package:timetrackingintegration/tools/sql_db.dart';
import 'package:timetrackingintegration/tools/tools.dart';
import 'package:timetrackingintegration/widgets/topbar.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
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

class _MainPageState extends State<MainPage> {
  Toggl _toggl;
  Jira _jira;
  JiraIssues _jiraIssues;
  Issue _selectedIssue;
  int _numberPomodore;
  Duration _timeDebt, _timeElapsedToday, _dailyMinimum;
  Color _activeColor = Colors.red;
  bool countTime;
  TextEditingController _extraDescriptionController;
  SharedPreferences _prefs;
  bool _isAnimating = false;
  bool _isPendingView = true;
  SqlDatabase sqlDatabase;
  List<String> _recents = List();
  RefreshController _refreshController = RefreshController();
  final Key linkKey = GlobalKey();

  final MethodChannel platform =
      MethodChannel('crossingthestreams.io/resourceResolver');

  _loadDB() async {
    sqlDatabase = SqlDatabase();
    await sqlDatabase.createInstance();
    await _loadTimerData();
    await _loadData();
  }

  _loadTimerData() async {
    TimerData timerData = await sqlDatabase.getTimerData();
    print("loadData: ${timerData.toJson()}");
    if (timerData.status == "paused") {
      Issue jiraIssue = Issue();
      Fields fields = Fields(summary: timerData.taskName);
      jiraIssue.key = timerData.taskId;
      jiraIssue.fields = fields;
      this._selectedIssue = jiraIssue;

      _isAnimating = true;
    } else if (timerData.status == "playing") {
      Issue jiraIssue = Issue();
      Fields fields = Fields(summary: timerData.taskName);
      jiraIssue.key = timerData.taskId;
      jiraIssue.fields = fields;
      this._selectedIssue = jiraIssue;
      _isAnimating = true;
    }
    setState(() {});
  }

  void initState() {
    super.initState();
    countTime = true;
    _extraDescriptionController = TextEditingController(text: "");
    _requestIOSPermissions();
    _loadDB();
    WidgetsBinding.instance
        .addObserver(LifecycleEventHandler(resumeCallBack: () async {
      print("binded");
      if (sqlDatabase == null) {
        sqlDatabase = SqlDatabase();
        await sqlDatabase.createInstance();
      } else {
        await _loadTimerData();
      }
      _refreshController.requestRefresh();
      setState(() {});
    }));
  }

  _checkTokens() async {
    bool _isTokensOk = true;
    String email_jira =
        _prefs.getString(SharedPreferenceConstants.EMAIL_JIRA) ?? "";

    String token_jira =
        _prefs.getString(SharedPreferenceConstants.TOKEN_JIRA) ?? "";

    String token_toggl =
        _prefs.getString(SharedPreferenceConstants.TOKEN_TOGGL) ?? "";

    //todo diferenciar painel se nao estiver OK os tokens
    if (!Tools.isStringValid(email_jira)) {
      _isTokensOk = false;
    }

    if (!Tools.isStringValid(token_jira)) {
      _isTokensOk = false;
    }
    if (!Tools.isStringValid(token_toggl)) {
      _isTokensOk = false;
    }

    if (!_isTokensOk) {
      print("before");
      await showDialog(
          barrierDismissible: false,
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0)), //this right here
              child: Container(
                //height: 200,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'For the correct integration of this app you must verify your Jira and Toggl tokens.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      SizedBox(
                        //width: 128.0,
                        child: RaisedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await AppSettings.showSettingsPanel(context);
                            await _loadData();
                          },
                          child: Text(
                            "Verify",
                            style: TextStyle(color: Colors.white),
                          ),
                          color: const Color(0xFF1BC0C5),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          });
      print("after");
    }
  }

  _loadSharedPreferences() async {
    _numberPomodore =
        (await _prefs.getInt(SharedPreferenceConstants.POMODORO_QUANT)) ?? 3;
    _dailyMinimum = Duration(
        milliseconds:
            (await _prefs.getInt(SharedPreferenceConstants.DURATION_MIN) ??
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
    print("load data");
    _prefs = await SharedPreferences.getInstance();
    await _checkTokens();
    await _loadSharedPreferences();
    await _loadTogglData();
    await _loadJiraIssues();
    //print("end load data");
    if (mounted) setState(() {});
  }

  _loadJiraIssues() async {
    _jira = Jira();

    try {
      this._jiraIssues = await _jira.getIssues();
      this._selectedIssue = this._jiraIssues.issues[0];
    } catch (e) {
      this._selectedIssue = null;
      _jiraIssues = null;
    }
  }

  void _loadTogglData() async {
    _toggl = Toggl();
    try {
      _timeDebt = await _toggl.getAccumulatedDebit(
          DateTime.tryParse(
              await _prefs.getString(SharedPreferenceConstants.DATE_SINCE)),
          _dailyMinimum);
      _timeElapsedToday = await _toggl.getAccumulatedTime(DateTime.now());
      _recents = await _toggl.getRecents();
      _activeColor = Tools.getBackgroundColor(_timeElapsedToday, _dailyMinimum);
    } catch (e) {
      _recents = List();
      print("load toggl error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    var data = MediaQuery.of(context);
    double heightFinal = data.size.height - 54 - kToolbarHeight;
    return RefreshConfiguration(
        /*headerTriggerDistance: 6.0,
        // header trigger refresh trigger distance
        springDescription:
            SpringDescription(stiffness: 170, damping: 16, mass: 1.9),*/
        // custom spring back animate,the props meaning see the flutter api
        //maxOverScrollExtent: 24,
        //The maximum dragging range of the head. Set this property if a rush out of the view area occurs
        /* maxUnderScrollExtent: 0,*/

        headerBuilder: () => WaterDropMaterialHeader(
              backgroundColor: _activeColor,
            ),
        /*// Maximum dragging range at the bottom
        enableScrollWhenRefreshCompleted: true,
        //This property is incompatible with PageView and TabBarView. If you need TabBarView to slide left and right, you need to set it to true.
        enableLoadingWhenFailed: true,
        //In the case of load failure, users can still trigger more loads by gesture pull-up.
        hideFooterWhenNotFull: true,
        // Disable pull-up to load more functionality when Viewport is less than one screen
        enableBallisticLoad: true,
        // trigger load more by BallisticScrollActivity*/
        child: Material(
          color: _activeColor,
          child: SafeArea(
            top: true,
            child: Stack(
              children: <Widget>[
                /*Container(
              height: 52.0,
              child: AppBar(
                backgroundColor:
                Colors.transparent,
                elevation: dismissAppbar ? 1.0 : 0.0,
                title: SimpleLinkBar(
                  key: linkKey,
                ),
              ),
            ),*/
                SmartRefresher(
                  enablePullDown: true,
                  enablePullUp: false,
                  physics: CustomScrollPhysics(),
                  /*header: WaterDropHeader(
                waterDropColor: Colors.white,
                refresh: Container(),
                idleIcon:Container(),
                complete: Container(),
              ),*/
                  controller: _refreshController,
                  onRefresh: _onRefresh,
                  //onLoading: _onLoading,
                  child: Stack(
                    children: <Widget>[
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: MyTopBar(
                          isAnimating: _isAnimating,
                          timeDebt: _timeDebt,
                          timeElapsedToday: _timeElapsedToday,
                          onRequestReload: () async {
                            //_refreshController.requestLoading();
                            await _refreshController.requestRefresh();
                          },
                        ),
                      ),
                      Positioned(
                        top: !_isAnimating ? 64 : 0,
                        left: 0,
                        right: 0,
                        bottom: _isAnimating ? 0 : null,
                        child: Container(
                          child: Pomodoro(
                              dailyMinimum: _dailyMinimum,
                              numberPomodore: _numberPomodore,
                              elapsedToday: _timeElapsedToday,
                              activeColor: _activeColor,
                              selectedIssue: this._selectedIssue,
                              countTime: countTime,
                              onError: (message) {
                                Scaffold.of(context).showSnackBar(SnackBar(
                                    elevation: 4,
                                    backgroundColor: Colors.white,
                                    action: SnackBarAction(
                                      label: "OK",
                                      onPressed: () {},
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8.0)),
                                    content: Text(
                                      message,
                                      style: TextStyle(color: Colors.black87),
                                    )));
                              },
                              onTimeTick: (Duration duration) {
                                Duration elapsedTotal = Duration(
                                    milliseconds:
                                        _timeElapsedToday.inMilliseconds +
                                            duration.inMilliseconds);
                                _activeColor = Tools.getBackgroundColor(
                                    elapsedTotal, _dailyMinimum);
                              },
                              onStatusChange: (isAnimating) {
                                this._isAnimating = isAnimating;
                                if (mounted) setState(() {});
                              },
                              onPause: () async {
                                await sqlDatabase.pause();
                              },
                              onBreak: () async {
                                await sqlDatabase.hitMax();
                              },
                              onPlay: (duration) async {
                                print("duration $duration");
                                String parentName = "";
                                try {
                                  parentName = _selectedIssue
                                      .fields.parent.fields.summary;
                                } catch (e) {
                                  parentName = null;
                                }

                                await sqlDatabase.play(
                                    duration,
                                    _selectedIssue.key,
                                    _selectedIssue.fields.summary,
                                    parentName);

                                TimerData timerData =
                                    await sqlDatabase.getTimerData();
                                print("timerData: ${timerData.toJson()}");
                              },
                              onCancel: () async {
                                print("cancel");
                                await sqlDatabase.stop();
                                TimerData timerData =
                                    await sqlDatabase.getTimerData();
                                print("timerData: ${timerData.toJson()}");
                                if (mounted) setState(() {});
                              },
                              onStop: (elapsedTimes, startDate) async {
                                print("stop");
                                /* await sqlDatabase.pause();*/
                                TimerData timerData =
                                    await sqlDatabase.getTimerData();
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
                                String description = "", sprint = null;
                                if (timerData.taskId == null) {
                                  description = "${timerData.taskName}";
                                } else {
                                  description =
                                      "${timerData.taskId}: ${timerData.taskName}";
                                  sprint = timerData.taskParentId;
                                }
                                Duration totalElapsed =
                                    Duration(milliseconds: 0);
                                await timerData.timersQueue
                                    .forEach((Timer timer) async {
                                  totalElapsed = Duration(
                                      milliseconds:
                                          totalElapsed.inMilliseconds +
                                              timer.elapsedMilliseconds);
                                });
                                var result = await _showDialog(context,
                                    totalElapsed, description, startDate);
                                setState(() {
                                  ring = false;
                                });

                                if (result == "save") {
                                  ScaffoldFeatureController snackbar = Scaffold
                                          .of(context)
                                      .showSnackBar(SnackBar(
                                          elevation: 4,
                                          backgroundColor: Colors.white,
                                          //action: CircularProgressIndicator(),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8.0)),
                                          content: Container(
                                              height: 32,
                                              child: Row(
                                                children: [
                                                  Container(
                                                      height: 16,
                                                      width: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                        valueColor:
                                                            new AlwaysStoppedAnimation<
                                                                    Color>(
                                                                Colors.blue),
                                                      )),
                                                  Container(
                                                    width: 16,
                                                  ),
                                                  Text(
                                                    "Saving ...",
                                                    style: TextStyle(
                                                        color: Colors.black87),
                                                  )
                                                ],
                                              ))));
                                  try {
                                    await timerData.timersQueue
                                        .forEach((Timer timer) async {
                                      print("timer: ${timer.toJson()}");
                                      await _toggl.postTime(
                                          duration: Duration(
                                              milliseconds:
                                                  timer.elapsedMilliseconds),
                                          startDate: DateTime
                                              .fromMillisecondsSinceEpoch(timer
                                                      .startMillisecondssinceepoch *
                                                  1000),
                                          countTime: countTime,
                                          description: description,
                                          sprint: sprint);
                                    });
                                    await sqlDatabase.stop();
                                    _isAnimating = false;
                                    _refreshController.requestRefresh();
                                  } catch (e) {
                                    print("error ao upload: $e");
                                    //todo try again or cancel
                                  }
                                  snackbar.close();
                                } else {
                                  await sqlDatabase.stop();
                                  _isAnimating = false;
                                  _refreshController.requestRefresh();
                                }
                                setState(() {});
                              }),
                        ),
                      ),
                      Positioned(
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
                              _isAnimating
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
                                                  shadows: _isPendingView
                                                      ? <Shadow>[
                                                          Shadow(
                                                            offset:
                                                                Offset(0, 0),
                                                            blurRadius: 4,
                                                            color:
                                                                Color.fromARGB(
                                                                    127,
                                                                    0,
                                                                    0,
                                                                    0),
                                                          )
                                                        ]
                                                      : null,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w400,
                                                  color: Colors.white),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _isPendingView = true;
                                                if (this._jiraIssues != null) {
                                                  this._selectedIssue = this
                                                      ._jiraIssues
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
                                                  shadows: !_isPendingView
                                                      ? <Shadow>[
                                                          Shadow(
                                                            offset:
                                                                Offset(0, 0),
                                                            blurRadius: 4,
                                                            color:
                                                                Color.fromARGB(
                                                                    127,
                                                                    0,
                                                                    0,
                                                                    0),
                                                          )
                                                        ]
                                                      : null,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w400,
                                                  color: Colors.white),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _isPendingView = false;
                                                this._selectedIssue = Issue(
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
                                height: !_isAnimating
                                    ? heightFinal - data.size.width - 48
                                    : 0,
                                child: Card(
                                    clipBehavior: Clip.antiAlias,
                                    margin: EdgeInsets.only(
                                        left: 8, right: 8, top: 0, bottom: 8),
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                    child: _isPendingView
                                        ? history(context)
                                        : extras(context)),
                                duration: Duration(milliseconds: 300),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                  /*: Container(child: SpinKitPouringHourglass(color: Colors.white,size: 128,),)*/,
                )
              ],
            ),
          ),
        ));
  }

  void _onRefresh() async {
    await _loadData();
    // if failed, use refreshFailed()
    _refreshController.refreshCompleted();
  }

  /*void _onLoading() async {
    // monitor network fetch
    // await Future.delayed(Duration(milliseconds: 1000));
    // if failed,use loadFailed(),if no data return,use LoadNodata()
    if (mounted) setState(() {});
    _refreshController.loadComplete();
  }*/

  Widget extras(BuildContext context) {
    return Column(children: <Widget>[
      Container(
        color: _activeColor.withOpacity(0.1),
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
                          this._selectedIssue = null;
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
                Issue jiraIssue = Issue();
                Fields fields =
                    Fields(summary: _extraDescriptionController.text);
                jiraIssue.fields = fields;
                this._selectedIssue = jiraIssue;
                if (_extraDescriptionController.text.isEmpty) {
                  this._selectedIssue = null;
                }
                setState(() {});
              },
            ),
          ),
          IconButton(
            tooltip: "Discount from goal",
            icon: Icon(
              countTime ? Icons.timer : Icons.timer_off,
              color: countTime ? _activeColor : Colors.grey.withOpacity(0.6),
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
          height: 18,
          child: Center(child: Text("Recent"))),
      _recents.isNotEmpty
          ? Expanded(
              child: ListView.builder(
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  itemCount: _recents.length,
                  itemBuilder: (BuildContext context, int index) {
                    return GestureDetector(
                        onTap: () {
                          _extraDescriptionController.text = _recents[index];
                          Issue jiraIssue = Issue();
                          Fields fields =
                              Fields(summary: _extraDescriptionController.text);

                          jiraIssue.fields = fields;
                          this._selectedIssue = jiraIssue;
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
                                        _recents[index],
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
      child: this._jiraIssues != null
          ? ListView.builder(
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              itemCount: this._jiraIssues.issues.length,
              itemBuilder: (BuildContext context, int index) {
                return item(
                    context,
                    this._jiraIssues.issues[index],
                    this._jiraIssues.issues[index].key ==
                        (this._selectedIssue != null
                            ? this._selectedIssue.key
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

  Widget item(BuildContext context, Issue issue, bool active) {
    return Column(children: <Widget>[
      GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              this._selectedIssue = issue;
            });
          },
          child: Slidable(
            actionPane: SlidableDrawerActionPane(),
            actionExtentRatio: 0.25,
            child: Container(
                color: active
                    ? _activeColor.withOpacity(0.1)
                    : _activeColor.withOpacity(0),
                padding: EdgeInsets.only(
                  left: 0,
                  right: 16,
                ),
                child: Row(children: <Widget>[
                  active
                      ? Container(
                          width: 4,
                          height: 64,
                          color: _activeColor,
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
                        Row(
                          children: [
                            issue.fields.customfield_10023 != null
                                ? Padding(
                                    padding: EdgeInsets.only(right: 8),
                                    child: Icon(
                                      Icons.flag,
                                      color: Colors.red,
                                      size: 12,
                                    ),
                                  )
                                : Container(),
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
                  int responseStatus = await _jira.updateIssue(issue.key);
                  print("Response code: $responseStatus");
                  if (responseStatus >= 200 && responseStatus < 300) {
                    await _refreshController.requestRefresh();
                  }
                },
              ),
            ],
          )),
      Container(color: Colors.grey.withOpacity(0.5), height: 0.5)
    ]);
  }
}
