import 'package:flutter_svg/flutter_svg.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:timetrackingintegration/jira/jira.dart';
import 'package:timetrackingintegration/toggl/toggl.dart';
import 'package:timetrackingintegration/tools/constants.dart';
import 'package:timetrackingintegration/tools/settings.dart';
import 'package:timetrackingintegration/tools/tools.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetrackingintegration/widgets/image_loader.dart';

class MyTopBar extends StatefulWidget {
  Function onRequestReload;
  Duration timeElapsedToday, timeDebt;
  bool isAnimating;

  MyTopBar(
      {this.onRequestReload,
      this.timeElapsedToday,
      this.timeDebt,
      this.isAnimating,
      Key key})
      : super(key: key);

  @override
  _MyTopBarState createState() => _MyTopBarState();
}

class Correlation {
  String avatar_url;
  String jira_project_id, jira_project_name;
  String toggl_project_id, toggl_project_name;

  Correlation(
      {this.avatar_url,
      this.jira_project_id,
      this.jira_project_name,
      this.toggl_project_id,
      this.toggl_project_name});
}

class _MyTopBarState extends State<MyTopBar> {
  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  RefreshStatus _status = RefreshStatus.idle;
  AnimationController _animationController;
  Map<String, int> _selectedTogglProjectKey = new Map();
  Toggl _toggl;
  Jira _jira;
  Map<int, String> toggl_projects;
  Map<String, dynamic> jira_projects;
  List<Correlation> correlationsList = [];
  Map<String, String> _jira_header;
  SharedPreferences prefs;
  String jiraSelectedProject_id, projectId, avatarUrl;

  _loadProjects() async {
    correlationsList.clear();
    prefs = await SharedPreferences.getInstance();
    _toggl = Toggl();
    toggl_projects = await _toggl.getUserProjects();
    _jira = Jira();
    _jira_header = await _jira.headerAuth;
    jira_projects = await _jira.getProjectsListAvatar();
    correlationsList.clear();
    jira_projects.forEach((key, value) {
      int saved_correlation;
      try {
        saved_correlation = prefs.getInt(
            "${SharedPreferenceConstants.JIRATOGGLECORRELATION}_${key}");
      } catch (e) {
        saved_correlation = null;
      }
      correlationsList.add(Correlation(
          avatar_url: value["avatar"],
          jira_project_id: key,
          jira_project_name: value["name"],
          toggl_project_id: saved_correlation.toString(),
          toggl_project_name: "name Toggl"));
      _selectedTogglProjectKey.putIfAbsent(key, () => saved_correlation);
    });
    jiraSelectedProject_id =
        (await prefs.getString(SharedPreferenceConstants.PROJECT_JIRA)) ?? null;
    projectId = prefs
        .getInt(
            SharedPreferenceConstants.PROJECT_TOGGL.replaceAll("name", "id"))
        .toString();
    avatarUrl =
        await prefs.getString(SharedPreferenceConstants.PROJECT_JIRA_AVATAR);

    print("jira selected $jiraSelectedProject_id - $projectId");
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          !widget.isAnimating
              ? GestureDetector(
                  onTap: () {
                    showDialog(
                      barrierDismissible: false,
                        context: context,
                        builder: (BuildContext context) {
                          return StatefulBuilder(builder: (context, setState) {
                            return Dialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4.0)),
                              //this right here
                              child: Container(
                                //height: 200,
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Jira - Toggl Project Correlation',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.black87,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Container(
                                        margin:
                                            EdgeInsets.symmetric(vertical: 8),
                                        height: 1,
                                        color: Colors.black12,
                                      ),
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: correlationsList
                                            .map((Correlation correlation) {
                                          return GestureDetector(
                                            onTap: () async {
                                              await prefs.setString(
                                                  SharedPreferenceConstants
                                                      .PROJECT_JIRA,
                                                  correlation
                                                      .jira_project_name);
                                              await prefs.setString(
                                                  SharedPreferenceConstants
                                                      .PROJECT_JIRA_AVATAR,
                                                  correlation.avatar_url);

                                              int togglId = int.tryParse(
                                                  correlation.toggl_project_id);
                                              await prefs.setInt(
                                                  SharedPreferenceConstants
                                                      .PROJECT_TOGGL
                                                      .replaceAll("name", "id"),
                                                  togglId);
                                              jiraSelectedProject_id =
                                                  correlation.jira_project_name;

                                              setState(() {});
                                            },
                                            child: Container(
                                              width: MediaQuery.of(context).size.width,
                                              color: jiraSelectedProject_id ==
                                                      correlation
                                                          .jira_project_name
                                                  ? Colors.lightBlue
                                                      .withOpacity(0.1)
                                                  : Colors.transparent,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Container(
                                                    width: 36.0,
                                                    height: 36.0,
                                                    margin: EdgeInsets.only(
                                                        left: 0,
                                                        right: 8,
                                                        top: 0),
                                                    child: JiraAvatarLoader(
                                                      url: correlation
                                                          .avatar_url,
                                                      headers: _jira_header,
                                                    ),
                                                  ),
                                                  Container(
                                                    width: 110,
                                                    child: Text(
                                                      correlation
                                                          .jira_project_name,
                                                      textAlign: TextAlign.left,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Container(),
                                                  ),
                                                  Container(width: 100,
                                                    child: DropdownButton(
                                                        isExpanded:true,
                                                      hint:
                                                          Text("Toggl..."),
                                                      value: _selectedTogglProjectKey[
                                                          correlation
                                                              .jira_project_id],
                                                      onChanged: (newValue) {
                                                        setState(() {
                                                          _selectedTogglProjectKey
                                                              .update(
                                                                  correlation
                                                                      .jira_project_id,
                                                                  (value) =>
                                                                      newValue);
                                                          int pos =
                                                              correlationsList
                                                                  .indexOf(
                                                                      correlation);

                                                          correlation
                                                                  .toggl_project_id =
                                                              newValue
                                                                  .toString();
                                                          correlation
                                                                  .toggl_project_name =
                                                              toggl_projects[
                                                                  newValue];

                                                          correlationsList[
                                                                  pos] =
                                                              correlation;
                                                          prefs.setInt(
                                                              "${SharedPreferenceConstants.JIRATOGGLECORRELATION}_${correlation.jira_project_id}",
                                                              newValue);
                                                        });
                                                      },
                                                      items: toggl_projects
                                                          .entries
                                                          .map((entry) {
                                                        return DropdownMenuItem(
                                                          child:
                                                              Text(entry.value),
                                                          value: entry.key,
                                                        );
                                                      }).toList(),
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      Container(
                                        margin:
                                            EdgeInsets.symmetric(vertical: 8),
                                        height: 1,
                                        color: Colors.black12,
                                      ),
                                      SizedBox(
                                        //width: 128.0,
                                        child: RaisedButton(
                                          onPressed: () {
                                            widget.onRequestReload();
                                            Navigator.pop(context);
                                            _loadProjects();
                                            setState(() {});
                                          },
                                          child: Text(
                                            "OK",
                                            style:
                                                TextStyle(color: Colors.white),
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
                        });
                  },
                  child: Container(
                    width: 36.0,
                    height: 36.0,
                    margin: EdgeInsets.only(left: 16, top: 0),
                    child: ClipOval(
                      child: JiraAvatarLoader(
                        url: avatarUrl,
                        headers: _jira_header,
                      ),
                    ),
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 0.8, // soften the shadow
                          spreadRadius: 0.8, //extend the shadow
                          offset: Offset(
                            0, // Move to right 10  horizontally
                            0, // Move to bottom 5 Vertically
                          ),
                        )
                      ],
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                )
              : Container(
                  width: 52,
                  height: 36,
                ),
          Expanded(
            child: Container(),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                "Today: ${Tools.getStringFormatedFromDuration(widget.timeElapsedToday)}",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    shadows: <Shadow>[
                      Shadow(
                        offset: Offset(0.0, 0.0),
                        blurRadius: 6.0,
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
                        blurRadius: 8.0,
                        color: Color.fromARGB(128, 0, 0, 0),
                      ),
                    ],
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Expanded(child: Container()),
          Container(
            width: 36,
            child: !widget.isAnimating
                ? IconButton(
                    icon: Icon(Icons.settings),
                    color: Colors.white,
                    onPressed: () async {
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
