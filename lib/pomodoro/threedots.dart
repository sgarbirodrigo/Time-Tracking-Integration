import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ThreeDots extends StatefulWidget {
  Duration elapsedToday, dailyMinimum;
  int numberOfPomodores;
  int activePomodores = 1;
  Color activeColor;
  Function onClick;

  ThreeDots(
      {this.elapsedToday = const Duration(hours: 0),
      this.dailyMinimum = const Duration(hours: 2, minutes: 30),
      this.numberOfPomodores,
      this.onClick,
      this.activeColor}) {
    if (this.elapsedToday == null) {
      this.elapsedToday = Duration(hours: 0);
    }
    if (dailyMinimum == null) {
      this.dailyMinimum = Duration(hours: 2, minutes: 30);
    }
    if (numberOfPomodores == null) {
      this.numberOfPomodores = 3;
    }
    try {
      activePomodores = (elapsedToday.inMilliseconds ~/
          (dailyMinimum.inMilliseconds / numberOfPomodores));

    } catch (e) {
      activePomodores = 0;
      print("error thredots: $e");
    }
  }

  @override
  _ThreeDotsState createState() => _ThreeDotsState();
}

class _ThreeDotsState extends State<ThreeDots> {
  @override
  Widget build(BuildContext context) {
    //print("active ${widget.activePomodores}");
    return Container(
      alignment: Alignment.center,
      height: 10,
      child: ListView.builder(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          itemCount: widget.numberOfPomodores,
          itemBuilder: (BuildContext context, int index) {
            return GestureDetector(
              onTap: () {
                //print("active dot: ${widget.activePomodores}");
                //print("index:$index");
                if (index + 1 > widget.activePomodores) {
                  Duration remaining =
                      widget.dailyMinimum - widget.elapsedToday;
                  Duration byPomodore = Duration(
                      milliseconds: (widget.dailyMinimum.inMilliseconds ~/
                          widget.numberOfPomodores));
                  int numDiscount = widget.numberOfPomodores - index - 1;
                  Duration remain = remaining -
                      (Duration(
                          milliseconds:
                              numDiscount * byPomodore.inMilliseconds));
                  widget.onClick(remain);
                }
              },
              child: Container(
                padding: EdgeInsets.only(left: 4, right: 4),
                child: Container(
                  height: 10,
                  width: 10,
                  decoration: BoxDecoration(
                    color: widget.activePomodores > index
                        ? widget.activeColor
                        : Colors.black12,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            );
          }),
    );
  }
}
