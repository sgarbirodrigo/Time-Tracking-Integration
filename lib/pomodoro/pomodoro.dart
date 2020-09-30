import 'package:timetrackingintegration/alarm/alarm.dart';
import 'package:timetrackingintegration/jira/jira.dart';
import 'package:timetrackingintegration/pomodoro/threedots.dart';
import 'package:timetrackingintegration/tools/constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock/wakelock.dart';

var PI = 3.14;

class Pomodoro extends StatefulWidget {
  /*Duration duration = Duration(seconds: 10);*/
  Issues selectedIssue;
  Function onFinish, onStatusChange;
  Color activeColor;
  bool countTime;
  Duration elapsedToday;
  Duration dailyMinimum;
  int numberPomodore;

  Pomodoro(
      {this.selectedIssue,
      this.onFinish,
      this.activeColor,
      this.onStatusChange,
      this.countTime,
      this.numberPomodore,
      this.elapsedToday,
      this.dailyMinimum}) {
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
  Duration duration = Duration(minutes: 50);
  DateTime startDate;

  String get timerString {
    Duration duration =
        animationController.duration * animationController.value;
    if (duration.inMilliseconds == 0) {
      duration = this.duration;
    }
    return '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  double validWidth = 0;

  @override
  void initState() {
    super.initState();
    //print("InitState Pomodore: ${validWidth}");
    animationController =
        AnimationController(vsync: this, duration: this.duration)
          ..addStatusListener((status) {
            widget.onStatusChange(animationController.isAnimating);

            if (status == AnimationStatus.dismissed &&
                animationController.value == 0 &&
                !hasUserCancelled) {
              //print("auto save");
              finishAndSave();
            }
          });
  }

  void finishAndSave() {
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
    animationController.duration = restTime;
    this.duration = restTime;

    widget.onFinish(elapsedTime, startDate);
    setState(() {});
  }
  _setNewTimer(Duration duration){
    this.duration =
        duration;
    this
        .animationController
        .duration =
        duration;
    setState(() {});
  }

  void startCounter() {
    if (widget.selectedIssue != null) {
      if (this.duration.inMilliseconds > 0) {
        Alarm alarm = Alarm();
        if (animationController.isAnimating) {
          animationController.stop();
          alarm.cancelAll();
          Wakelock.disable();
        } else {
          Wakelock.enable();
          hasUserCancelled = false;
          startDate = DateTime.now();
          double value = (animationController.value == 0.0)
              ? 1.0
              : animationController.value;

          alarm.scheduleNotification(
              "Take a break!", "Pomodoro finished", this.duration * value);
          animationController.reverse(from: value);
        }
        setState(() {});
      } else {
        Scaffold.of(context).showSnackBar(SnackBar(
            elevation: 4,
            backgroundColor: Colors.white,
            action: SnackBarAction(
              label: "OK",
              onPressed: () {},
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0)),
            content: Text(
              "You should focus for more than ZERO :)",
              style: TextStyle(color: Colors.black87),
            )));
      }
    } else {
      Scaffold.of(context).showSnackBar(SnackBar(
          elevation: 4,
          backgroundColor: Colors.white,
          action: SnackBarAction(
            label: "OK",
            onPressed: () {},
          ),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          content: Text(
            'Choose a task to work on',
            style: TextStyle(color: Colors.black87),
          )));
    }
  }

  void stopCounter() {
    Wakelock.disable();
    hasUserCancelled = true;
    animationController.reset();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (validWidth <= 0) {
      double width = MediaQuery.of(context).size.width - 64;
      double height = MediaQuery.of(context).size.height;
      validWidth = width < height * 0.5 ? width*0.9 : height * 0.4;
      //print("valid width: $validWidth");
      //validWidth = 500;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          height: 24,
        ),
        Align(
          alignment: FractionalOffset.center,
          child: Container(
            width: validWidth,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.3), blurRadius: 20)
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
                                                            color: Colors.green,
                                                            blurRadius: 0.8)
                                                      ],
                                                      // border: Border.all(color: Colors.green,width: 4),
                                                      borderRadius:
                                                          BorderRadius.all(
                                                              Radius.circular(
                                                                  16))),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    child: CupertinoTimerPicker(
                                                      mode:
                                                          CupertinoTimerPickerMode
                                                              .hms,
                                                      initialTimerDuration:
                                                          this.duration,
                                                      onTimerDurationChanged:
                                                          (Duration newTimer) {
                                                        _setNewTimer(newTimer);
                                                      },
                                                    ),
                                                  )),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: <Widget>[
                                                  RaisedButton(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 16),
                                                    child: Text(
                                                      "50 min",
                                                      style: TextStyle(
                                                          color: widget
                                                              .activeColor,
                                                          fontSize: 16),
                                                    ),
                                                    color: Colors.white,
                                                    onPressed: () {
                                                      _setNewTimer(
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
                                                          color: widget
                                                              .activeColor,
                                                          fontSize: 16),
                                                    ),
                                                    color: Colors.white,
                                                    onPressed: () {
                                                      _setNewTimer(
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
                                                          color: widget
                                                              .activeColor,
                                                          fontSize: 16),
                                                    ),
                                                    color: Colors.white,
                                                    onPressed: () {
                                                      _setNewTimer(
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
                                      _setNewTimer(remain);
                                    },
                                  )
                                : Container(),
                            Container(
                              height: 16,
                            ),
                            Text(
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
                  startCounter();
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
        Container(
          height: 24,
        )
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
