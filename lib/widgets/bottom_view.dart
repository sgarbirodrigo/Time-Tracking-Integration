/*
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:timetrackingintegration/jira/jira.dart';

class BottomView extends StatefulWidget {
  Function onRequestReload;
  Duration timeElapsedToday, timeDebt;
  bool isAnimating;
  bool isPendingView;

  BottomView(
      {this.onRequestReload,
        this.timeElapsedToday,
        this.timeDebt,
        this.isAnimating});

  @override
  _BottomViewState createState() => _BottomViewState();
}
class _BottomViewState extends State<BottomView> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
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
            widget.isAnimating
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
                          shadows: widget.isPendingView
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
                          shadows: !widget.isPendingView
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
                        widget.isPendingView = false;
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
              height: !widget.isAnimating
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
                  child: widget.isPendingView
                      ? history(context)
                      : extras(context)),
              duration: Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }
}
*/
