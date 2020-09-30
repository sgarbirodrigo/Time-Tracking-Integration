import 'package:timetrackingintegration/toggl/toggl.dart';
import 'package:timetrackingintegration/tools/constants.dart';
import 'package:timetrackingintegration/tools/settings_screen/itemSettings_dateselect.dart';
import 'package:timetrackingintegration/tools/settings_screen/itemSettings_itemslist.dart';
import 'package:timetrackingintegration/tools/settings_screen/itemSettings_number.dart';
import 'package:timetrackingintegration/tools/settings_screen/itemSettings_textformfield.dart';
import 'package:timetrackingintegration/tools/settings_screen/itemSettings_timeselect.dart';
import 'package:timetrackingintegration/tools/tools.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:package_info/package_info.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../jira/jira.dart';

class AppSettings {
  static void showSettingsPanel(BuildContext context) async {
    return showCupertinoModalBottomSheet(
        expand: true,
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context, scrollController) {
          return ModalWithNavigator(
            scrollController: scrollController,
          );
        });
  }
}

class ModalWithNavigator extends StatefulWidget {
  final ScrollController scrollController;

  ModalWithNavigator({Key key, this.scrollController}) : super(key: key);

  @override
  _ModalWithNavigatorState createState() => _ModalWithNavigatorState();
}

class _ModalWithNavigatorState extends State<ModalWithNavigator> {
  bool lockInBackground = true;
  SharedPreferences prefs;
  String jiraEmail,
      jiraToken,
      jiraDomain,
      jiraSelectedProject_id,
      togglToken,
      togglSelectedWorkspace_name,
      togglSelectedProject_name;
  DateTime dateSince;
  Duration durationMin;
  int numberPomodoro;
  String _version;
  _load() async {
    prefs = await SharedPreferences.getInstance();
    jiraEmail = (await prefs.getString(SharedPreferenceConstants.EMAIL_JIRA)) ??
        "Insert your Jira Email";
    jiraToken = (await prefs.getString(SharedPreferenceConstants.TOKEN_JIRA)) ??
        "Insert your Jira Token";
    jiraDomain = (await prefs.getString(SharedPreferenceConstants.DOMAIN_JIRA)) ??
        "Insert your Jira Domain";
    togglToken =
        (await prefs.getString(SharedPreferenceConstants.TOKEN_TOGGL)) ??
            "Insert your Toggl Token";
    jiraSelectedProject_id = (await prefs.getString(SharedPreferenceConstants.PROJECT_JIRA_ID)) ??
        "Select your Project";
    print("priject ID: $jiraSelectedProject_id");
    togglSelectedWorkspace_name =
        (await prefs.getString(SharedPreferenceConstants.WORKSPACE_TOGGL)) ??
            "Select your workspace";
    togglSelectedProject_name =
        (await prefs.getString(SharedPreferenceConstants.PROJECT_TOGGL)) ??
            "Select your project";
    dateSince = DateTime.tryParse(
        await prefs.getString(SharedPreferenceConstants.DATE_SINCE));
    numberPomodoro = await prefs.getInt(SharedPreferenceConstants.POMODORO_QUANT);
    durationMin = Duration(
            milliseconds:
                (await prefs.getInt(SharedPreferenceConstants.DURATION_MIN))) ??
        Duration(hours: 2, minutes: 30);

    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    String appName = packageInfo.appName;
    String packageName = packageInfo.packageName;
    String version = packageInfo.version;
    String buildNumber = packageInfo.buildNumber;

    print("AppName: $appName / packageName: $packageName / version: $version / buildNumber: $buildNumber");

    _version = "$version+$buildNumber";
    setState(() {});
  }

  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    bool togglValid = true;

    return Material(
      child: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (context) => Builder(
            builder: (context) => CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(
                  leading: Container(), middle: Text('Settings')),
              child: SafeArea(
                bottom: false,
                child: StatefulBuilder(
                  builder: (context, setStateIn) {
                    try {
                      togglValid = togglToken.isNotEmpty;
                    } catch (e) {
                      togglValid = false;
                    }
                    return Container(
                      child: SettingsList(
                        sections: [
                          SettingsSection(
                            title: 'Jira',
                            tiles: [
                              SettingsTile(
                                title: 'Email',
                                subtitle: jiraEmail,
                                leading: Icon(Icons.email),
                                onTap: () async {
                                  jiraEmail = await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ItemSettingsTextFormField(
                                              "Jira Email",
                                              "Email",
                                              SharedPreferenceConstants
                                                  .EMAIL_JIRA),
                                    ),
                                  );
                                  setStateIn(() {});
                                },
                              ),
                              SettingsTile(
                                title: 'Token',
                                subtitle: Tools.isStringValid(jiraToken)
                                    ? "*************"
                                    : "Inser your token",
                                leading: Icon(Icons.security),
                                onTap: () async {
                                  jiraToken = await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ItemSettingsTextFormField(
                                              "Jira Token",
                                              "Token",
                                              SharedPreferenceConstants
                                                  .TOKEN_JIRA),
                                    ),
                                  );
                                  setStateIn(() {});
                                },
                              ),
                              SettingsTile(
                                title: 'Domain',
                                subtitle: Tools.isStringValid(jiraDomain)
                                    ? jiraDomain
                                    : "Inser your Domain",
                                leading: Icon(Icons.wb_cloudy),
                                onTap: () async {
                                  jiraDomain = await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ItemSettingsTextFormField(
                                              "Jira Domain",
                                              "Domain",
                                              SharedPreferenceConstants
                                                  .DOMAIN_JIRA),
                                    ),
                                  );
                                  setStateIn(() {});
                                },
                              ),
                              SettingsTile(
                                title: 'Project',
                                leading: Icon(Icons.work),
                                subtitle: Tools.isStringValid(jiraSelectedProject_id)
                                    ? "Select your jira Project"
                                    : jiraSelectedProject_id,
                                onTap: () async {
                                  jiraSelectedProject_id =
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ItemSettingsListItem(
                                              "Jira Project",
                                              SharedPreferenceConstants
                                                  .PROJECT_JIRA, () {
                                            Jira jira = Jira();
                                            return jira.getProjects();
                                          }),
                                    ),
                                  );
                                  setStateIn(() {});
                                },
                              ),
                            ],
                          ),
                          togglValid
                              ? SettingsSection(
                                  title: 'Toggl',
                                  tiles: [
                                    SettingsTile(
                                      title: 'Token',
                                      subtitle: jiraToken != null
                                          ? "*************"
                                          : "Inser your token",
                                      leading: Icon(Icons.security),
                                      onTap: () async {
                                        togglToken =
                                            await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ItemSettingsTextFormField(
                                                    "Toggl Token",
                                                    "Token",
                                                    SharedPreferenceConstants
                                                        .TOKEN_TOGGL),
                                          ),
                                        );
                                        setStateIn(() {});
                                      },
                                    ),
                                    SettingsTile(
                                      title: 'Workspace',
                                      leading: Icon(Icons.work),
                                      subtitle: togglToken.isEmpty
                                          ? "Insert your token"
                                          : togglSelectedWorkspace_name,
                                      onTap: () async {
                                        togglSelectedWorkspace_name =
                                            await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ItemSettingsListItem(
                                                    "Toggl Workspace",
                                                    SharedPreferenceConstants
                                                        .WORKSPACE_TOGGL, () {
                                              Toggl toggl = Toggl();
                                              return toggl.getWorkspaces();
                                            }),
                                          ),
                                        );
                                        setStateIn(() {});
                                      },
                                    ),
                                    SettingsTile(
                                      title: 'Project',
                                      leading: Icon(Icons.folder_open),
                                      subtitle: togglToken.isEmpty
                                          ? "Insert your token"
                                          : togglSelectedProject_name,
                                      onTap: () async {
                                        togglSelectedProject_name =
                                            await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ItemSettingsListItem(
                                                    "Toggl Project",
                                                    SharedPreferenceConstants
                                                        .PROJECT_TOGGL, () {
                                              Toggl toggl = Toggl();
                                              return toggl.getUserProjects();
                                            }),
                                          ),
                                        );
                                        print(togglSelectedProject_name);
                                        setStateIn(() {});
                                      },
                                    ),
                                  ],
                                )
                              : SettingsSection(
                                  title: 'Toggl',
                                  tiles: [
                                    SettingsTile(
                                      title: 'Token',
                                      subtitle: jiraToken != null
                                          ? "*************"
                                          : "Inser your token",
                                      leading: Icon(Icons.security),
                                      onTap: () async {
                                        togglToken =
                                            await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ItemSettingsTextFormField(
                                                    "Toggl Token",
                                                    "Token",
                                                    SharedPreferenceConstants
                                                        .TOKEN_TOGGL),
                                          ),
                                        );
                                        setStateIn(() {});
                                      },
                                    ),
                                  ],
                                ),
                          SettingsSection(
                            title: 'Pomodoro',
                            tiles: [
                              SettingsTile(
                                title: 'Minimum Daily',
                                subtitle: durationMin != null
                                    ? "${durationMin.toString().split(".")[0]}"
                                    : "Select a minimum",
                                leading: Icon(Icons.av_timer),
                                onTap: () async {
                                  durationMin =
                                      await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ItemSettingsTime(
                                          "Daily Minimum",
                                          SharedPreferenceConstants
                                              .DURATION_MIN),
                                    ),
                                  );
                                  setStateIn(() {});
                                },
                              ),
                              SettingsTile(
                                title: 'Session',
                                subtitle: numberPomodoro != null
                                    ? "${numberPomodoro.toString()}"
                                    : "Number of Pomodoros",
                                leading: Icon(Icons.av_timer),
                                onTap: () async {
                                  numberPomodoro=
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ItemSettingsNumber(
                                              "Pomodores",
                                              "Number",
                                              SharedPreferenceConstants
                                                  .POMODORO_QUANT),
                                    ),
                                  );
                                  setStateIn(() {});
                                },
                              ),
                              SettingsTile(
                                title: 'Since',
                                subtitle: dateSince != null
                                    ? "${dateSince.day.toString().padLeft(2, "0")}/${dateSince.month.toString().padLeft(2, "0")}/${dateSince.year}"
                                    : "Select a date",
                                leading: Icon(Icons.date_range),
                                onTap: () async {
                                  dateSince = await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ItemSettingsDate(
                                          "Since",
                                          SharedPreferenceConstants.DATE_SINCE),
                                    ),
                                  );
                                  setStateIn(() {});
                                },
                              ),
                            ],
                          ),
                          SettingsSection(
                            title: 'General',
                            tiles: [
                              SettingsTile(
                                title: 'Version',
                                subtitle: _version,
                                leading: Icon(Icons.insert_emoticon),
                                onTap: null,
                              ),
                              /*SettingsTile(
                                title: 'Help',
                                leading: Icon(Icons.help_outline),
                                onTap: () async {},
                              ),*/
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
