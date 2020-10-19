import 'package:timetrackingintegration/alarm/alarm.dart';
import 'package:timetrackingintegration/jira/jira.dart';
import 'package:timetrackingintegration/pomodoro/threedots.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:timetrackingintegration/tools/sql_db.dart';
import 'package:wakelock/wakelock.dart';

var PI = 3.14;

class Pomodoro extends StatefulWidget {
  Issue selectedIssue;
  Function onStop,
      onStatusChange,
      onError,
      onPlay,
      onPause,
      onBreak,
      onCancel,
      onTimeTick;
  Color activeColor;
  bool countTime, isAnimating = false;
  Duration elapsedToday;
  Duration dailyMinimum;
  int numberPomodore;
  double heightSize;

  Pomodoro(
      {this.selectedIssue,
      this.onStop,
      this.onBreak,
      this.onCancel,
      this.activeColor,
      this.onStatusChange,
      this.countTime,
      this.numberPomodore,
      this.elapsedToday,
      this.dailyMinimum,
      this.onError,
      this.onPause,
      this.onPlay,
      this.isAnimating,
      this.onTimeTick,  this.heightSize}) {
    if (this.selectedIssue != null) {
      if (this.selectedIssue.fields != null) {
        if (this.selectedIssue.fields.summary.isEmpty) {
          this.selectedIssue = null;
        }
      }
    }
  }

  @override
  _PomodoroState createState() => _PomodoroState();
}

class _PomodoroState extends State<Pomodoro> with TickerProviderStateMixin {
  bool hasUserCancelled = false;
  AnimationController animationController;
  DateTime startDate;
  SqlDatabase sqlDatabase;
  TimerData timerData;
  Duration totalDuration = Duration(minutes: 0),
      elapsedDuration = Duration(minutes: 0);

  String get timerString {
    try {
      Duration duration = animationController.duration *
          (animationController.value == 0 ? 1 : animationController.value);
      widget.onTimeTick(Duration(
          milliseconds: animationController.duration.inMilliseconds -
              duration.inMilliseconds));
      return '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    } catch (e) {
      print("error: ${e}");
      return '00:00';
    }
  }

  String get timerFutureString {
    //todo
    try {
      Duration duration = animationController.duration *
          (animationController.value == 0 ? 1 : animationController.value);

      return '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    } catch (e) {
      print("error: ${e}");
      return '00:00';
    }
  }

  double validWidth = 0;

  _loadDB() async {
    sqlDatabase = SqlDatabase();
    await sqlDatabase.createInstance();
    await _loadTimerData();
  }

  _loadTimerData() async {
    timerData = await sqlDatabase.getTimerData();
    //print("Pomodore: ${timerData.toJson()}");
    if (timerData.status == "paused") {
      Issue jiraIssue = Issue();
      Fields fields = Fields(summary: timerData.taskName);
      jiraIssue.key = timerData.taskId;
      jiraIssue.fields = fields;
      widget.selectedIssue = jiraIssue;
      Duration expectedDuration =
          Duration(milliseconds: timerData.timerExpectedDurationMilli);
      DateTime startedDate = DateTime.fromMillisecondsSinceEpoch(
          timerData.runningTimerStartMillisinceepoch);
      Duration elapsedDuration = Duration(milliseconds: 0);

      timerData.timersQueue.forEach((TimerSQL timer) {
        elapsedDuration = Duration(
            milliseconds:
                elapsedDuration.inMilliseconds + timer.elapsedMilliseconds);
      });

      Duration restingTime = Duration(
          milliseconds:
              expectedDuration.inMilliseconds - elapsedDuration.inMilliseconds);

      print("total: $expectedDuration - elapsed: $elapsedDuration");

      this.totalDuration = expectedDuration;
      this.elapsedDuration = elapsedDuration;

      animationController.duration = this.totalDuration;
      animationController.value = 1 -
          (this.elapsedDuration.inMilliseconds /
              this.totalDuration.inMilliseconds);
      setState(() {});
    } else if (timerData.status == "playing") {
      Issue jiraIssue = Issue();
      Fields fields = Fields(summary: timerData.taskName);
      jiraIssue.key = timerData.taskId;
      jiraIssue.fields = fields;
      widget.selectedIssue = jiraIssue;
      print("issue: ${widget.selectedIssue.fields.summary}");
      Duration expectedDuration =
          Duration(milliseconds: timerData.timerExpectedDurationMilli);
      DateTime startedDate = DateTime.fromMillisecondsSinceEpoch(
          timerData.runningTimerStartMillisinceepoch);
      Duration elapsedDuration = Duration(milliseconds: 0);

      if (timerData.timersQueue != null) {
        timerData.timersQueue.forEach((TimerSQL timer) {
          elapsedDuration = Duration(
              milliseconds:
                  elapsedDuration.inMilliseconds + timer.elapsedMilliseconds);
        });
      }
      Duration restingTime = Duration(
          milliseconds:
              expectedDuration.inMilliseconds - elapsedDuration.inMilliseconds);

      print("total: $expectedDuration - elapsed: $elapsedDuration");

      this.totalDuration = expectedDuration;
      this.elapsedDuration = elapsedDuration;

      Duration runningElapsed = Duration(
          milliseconds: DateTime.now().millisecondsSinceEpoch -
              timerData.runningTimerStartMillisinceepoch);

      animationController.duration = this.totalDuration;
      double value = 1 -
          ((this.elapsedDuration.inMilliseconds +
                  runningElapsed.inMilliseconds) /
              this.totalDuration.inMilliseconds);
      if (value > 0) {
        animationController.value = value;
        animationController.reverse();
      } else {
        widget.onBreak();
        animationController.value = 0;
        finishAndSave();
      }

      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDB();
    animationController =
        AnimationController(vsync: this, duration: this.totalDuration)
          ..addStatusListener((status) {
            if (timerData != null) {
              if (timerData.status == "paused") {
                widget.onStatusChange(true);
              } else if (timerData.status == "playing") {
                widget.onStatusChange(true);
              } else {
                widget.onStatusChange(animationController.isAnimating);
              }
            }
            if (status == AnimationStatus.dismissed &&
                animationController.value == 0 &&
                !hasUserCancelled) {
              widget.onPause();
              finishAndSave();
            }
          });
  }

  void finishAndSave() {
    widget.onStatusChange(false);
    Wakelock.disable();
    Duration elapsedTime = Duration(
        milliseconds: (((1 - animationController.value) *
                animationController.duration.inMilliseconds))
            .toInt());
    Duration restTime = Duration(
        milliseconds: (animationController.value *
                animationController.duration.inMilliseconds)
            .toInt());
    animationController.reset();
    setNewTimer(restTime);
    widget.onStop(elapsedTime, startDate);
    setState(() {});
  }

  void setNewTimer(Duration duration) {
    this.animationController.duration = duration;
    setState(() {});
  }

  void playPauseCounter() {
    if (widget.selectedIssue != null) {
      if (this.animationController.duration.inMilliseconds > 0) {
        Alarm alarm = Alarm();
        if (animationController.isAnimating) {
          animationController.stop();
          alarm.cancelAll();
          Wakelock.disable();
          widget.onPause();
        } else {
          Wakelock.enable();
          hasUserCancelled = false;
          startDate = DateTime.now();
          double value = (animationController.value == 0.0)
              ? 1.0
              : animationController.value;
          Duration duration_new = this.animationController.duration * value;
          alarm.scheduleNotification(
              "Timer Finished!",
              "You've been focused for ${duration_new.inMinutes.toString()} minutes into ${widget.selectedIssue.fields.summary.length > 25 ? widget.selectedIssue.fields.summary.substring(0, 24) : widget.selectedIssue.fields.summary}. Save your progress for later analysis.",
              duration_new);
          animationController.reverse(from: value);
          widget.onPlay(duration_new);
        }
        setState(() {});
      } else {
        widget.onError("You should focus for more than ZERO :)");
      }
    } else {
      widget.onError("Choose a task to focus!");
    }
  }

  void stopCounter() {
    Wakelock.disable();
    hasUserCancelled = true;
    animationController.reset();
    widget.onCancel();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (validWidth <= 0) {
      double width = MediaQuery.of(context).size.width - 64;
      double height = MediaQuery.of(context).size.height;
      validWidth = width < height * 0.5 ? width * 0.9 : height * 0.4;
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          height: 24,
        ),
        Container(
        //width: validWidth,
          //width: MediaQuery.of(context).size.width*0.7,
          width: widget.heightSize-96,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20)
              ],
              color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 1.0,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      left: 8,
                      right: 8,
                      top: 8,
                      bottom: 8,
                      child: AnimatedBuilder(
                        animation: animationController,
                        builder: (BuildContext context, Widget child) {
                          return CustomPaint(
                            painter: TimerPainter(
                                animation: animationController,
                                backgroundColor: Colors.white,
                                color: widget.activeColor),
                          );
                        },
                      ),
                    ),
                    Align(
                      alignment: FractionalOffset.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            widget.countTime ? Icons.timer : Icons.timer_off,
                            size: 36,
                            color: widget.countTime
                                ? widget.activeColor
                                : Colors.grey.withOpacity(0.6),
                          ),
                          GestureDetector(
                            child: AnimatedBuilder(
                                animation: animationController,
                                builder: (_, Widget child) {
                                  return Text(
                                    timerString,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 72,
                                        color: widget.activeColor,
                                        fontWeight: FontWeight.w400),
                                  );
                                }),
                            onTap: () {
                              if (!animationController.isAnimating &&
                                  animationController.value == 0) {
                                showCupertinoModalPopup<void>(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return Center(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Container(
                                                width: 300,
                                                height: 100,
                                                decoration: BoxDecoration(
                                                    boxShadow: <BoxShadow>[
                                                      BoxShadow(
                                                          color: Colors.white,
                                                          blurRadius: 0.5)
                                                    ],
                                                    // border: Border.all(color: Colors.green,width: 4),
                                                    borderRadius:
                                                        BorderRadius.all(
                                                            Radius.circular(
                                                                16))),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  child: CupertinoTimerPicker(
                                                    mode:
                                                        CupertinoTimerPickerMode
                                                            .hms,
                                                    initialTimerDuration:
                                                        this.totalDuration,
                                                    onTimerDurationChanged:
                                                        (Duration newTimer) {
                                                      setNewTimer(newTimer);
                                                    },
                                                  ),
                                                )),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: <Widget>[
                                                RaisedButton(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 16),
                                                  child: Text(
                                                    "50 min",
                                                    style: TextStyle(
                                                        color:
                                                            widget.activeColor,
                                                        fontSize: 16),
                                                  ),
                                                  color: Colors.white,
                                                  onPressed: () {
                                                    setNewTimer(
                                                        Duration(minutes: 50));
                                                    Navigator.pop(context);
                                                  },
                                                ),
                                                Container(
                                                  width: 8,
                                                ),
                                                RaisedButton(
                                                  child: Text(
                                                    "25 min",
                                                    style: TextStyle(
                                                        color:
                                                            widget.activeColor,
                                                        fontSize: 16),
                                                  ),
                                                  color: Colors.white,
                                                  onPressed: () {
                                                    setNewTimer(
                                                        Duration(minutes: 25));
                                                    Navigator.pop(context);
                                                  },
                                                ),
                                                Container(
                                                  width: 8,
                                                ),
                                                RaisedButton(
                                                  child: Text(
                                                    "5 min",
                                                    style: TextStyle(
                                                        color:
                                                            widget.activeColor,
                                                        fontSize: 16),
                                                  ),
                                                  color: Colors.white,
                                                  onPressed: () {
                                                    setNewTimer(
                                                        Duration(minutes: 5));
                                                    Navigator.pop(context);
                                                  },
                                                ),
                                              ],
                                            ),
                                          ]),
                                    );
                                  },
                                );
                              }
                            },
                          ),
                          !animationController.isAnimating
                              ? ThreeDots(
                                  dailyMinimum: widget.dailyMinimum,
                                  elapsedToday: widget.elapsedToday,
                                  activeColor: widget.activeColor,
                                  numberOfPomodores: widget.numberPomodore,
                                  onClick: (Duration remain) {
                                    //print("returned: $remain");
                                    setNewTimer(remain);
                                  },
                                )
                              : Container(),
                          Container(
                            height: 16,
                          ),
                          Container(
                            width: validWidth * 0.8,
                            child: Text(
                              widget.selectedIssue != null
                                  ? widget.selectedIssue.fields.summary
                                  : "Select a task",
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  fontSize: 18,
                                  color: Colors.black.withOpacity(0.5)),
                            ),
                          ), /*Container(height: 36,)*/
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 16,
        ),
        Container(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              (animationController.value > 0 &&
                      !animationController.isAnimating)
                  ? FloatingActionButton(
                      backgroundColor: Colors.white,
                      child: AnimatedBuilder(
                          animation: animationController,
                          builder: (_, Widget child) {
                            return Icon(
                              Icons.stop,
                              color: widget.activeColor,
                            );
                          }),
                      onPressed: () async {
                        // show the dialog
                        var result = await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text("Confirm"),
                              content: Text(
                                  "Are you sure about canceling the timer?"),
                              actions: [
                                FlatButton(
                                  child: Text("No"),
                                  onPressed: () {
                                    Navigator.of(context).pop("no");
                                  },
                                ),
                                FlatButton(
                                  child: Text("Yes"),
                                  onPressed: () {
                                    Navigator.of(context).pop("yes");
                                  },
                                ),
                              ],
                            );
                          },
                        );
                        if (result == "yes") {
                          stopCounter();
                        }
                      },
                    )
                  : Container(),
              (animationController.value > 0 &&
                      !animationController.isAnimating)
                  ? Container(
                      width: 16,
                    )
                  : Container(),
              FloatingActionButton(
                backgroundColor: Colors.white,
                child: AnimatedBuilder(
                    animation: animationController,
                    builder: (_, Widget child) {
                      return Icon(
                          animationController.isAnimating
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: widget.activeColor);
                    }),
                onPressed: () {
                  playPauseCounter();
                },
              ),
              (animationController.value > 0 &&
                      !animationController.isAnimating)
                  ? Container(
                      width: 16,
                    )
                  : Container(),
              (animationController.value > 0 &&
                      !animationController.isAnimating)
                  ? FloatingActionButton(
                      backgroundColor: Colors.white,
                      child: AnimatedBuilder(
                          animation: animationController,
                          builder: (_, Widget child) {
                            return Text(
                              "Save",
                              style: TextStyle(
                                  color: widget.activeColor,
                                  fontWeight: FontWeight.w400),
                            );
                          }),
                      onPressed: () async {
                        hasUserCancelled = true;
                        finishAndSave();
                      },
                    )
                  : Container()
            ],
          ),
        ),
      ],
    );
  }
}

class TimerPainter extends CustomPainter {
  final Animation<double> animation;
  final Color backgroundColor;
  final Color color;

  TimerPainter({this.animation, this.backgroundColor, this.color})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(size.center(Offset.zero), size.width / 2.0, paint);
    paint.color = color;
    double progress = (1.0 - animation.value) * 2 * PI;
    canvas.drawArc(Offset.zero & size, PI * 1.5, -progress, false, paint);
  }

  @override
  bool shouldRepaint(TimerPainter old) {
    return animation.value != old.animation.value ||
        color != old.color ||
        backgroundColor != old.backgroundColor;
  }
}
