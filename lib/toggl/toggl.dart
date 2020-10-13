import 'dart:io';

import 'package:timetrackingintegration/tools/constants.dart';
import 'package:timetrackingintegration/tools/tools.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' show Codec, base64, json, utf8;

import 'package:shared_preferences/shared_preferences.dart';

class Toggl {
  Future<Map<String, String>> get _headerAuth async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString(SharedPreferenceConstants.TOKEN_TOGGL);

    Codec<String, String> stringToBase64 = utf8.fuse(base64);
    return {
      HttpHeaders.authorizationHeader:
          "Basic " + stringToBase64.encode("${token}:api_token"),
      'Content-Type': 'application/json'
    };
  }

  Future<String> get _workspace_id async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String workspaceId = prefs
        .getInt(
        SharedPreferenceConstants.WORKSPACE_TOGGL.replaceAll("name", "id"))
        .toString();
    return workspaceId;
  }
  Future<String> get _project_id async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String projectId = prefs
        .getInt(
        SharedPreferenceConstants.PROJECT_TOGGL.replaceAll("name", "id"))
        .toString();
    return projectId;
  }

  String get _timeZone {
    DateTime now = DateTime.now();
    Duration offSet = now.timeZoneOffset;
    String timezone;
    if (offSet.isNegative) {
      timezone = (offSet.inHours * -1).toString().padLeft(2, "0");
      timezone = "-${timezone}";
    } else {
      timezone = offSet.inHours.toString().padLeft(2, "0");
    }
    return "${timezone}:00";
  }

  String _convertedTogglDate(DateTime date) {
    return date.toIso8601String().substring(0, 19) + _timeZone;
  }

  Future<List> getRecents() async {
    List<String> recents = List();
    int tagExtraId = await getTagIdByName("Extra");
    if (tagExtraId != null) {
      //todo get the project id
      http.Response response = await (http.get(
        Uri.encodeFull(
            "https://toggl.com/reports/api/v2/summary?&workspace_id=${await _workspace_id}&user_agent=tti&project_ids=${await _project_id}&tag_ids=${tagExtraId}&order_desc=on&order_field=duration"),
        headers: await _headerAuth,
      ));
      if ((Tools.BodyBytesToJson(response.bodyBytes)["data"] as List)
          .isNotEmpty) {
        List result =
            Tools.BodyBytesToJson(response.bodyBytes)["data"][0]["items"];
        result.forEach((item) => {recents.add(item["title"]["time_entry"])});
      }
    }
    return recents;
  }

  Future<Duration> getAccumulatedDebit(
      DateTime since, Duration minDiario) async {
    int daysSinceDate = Duration(
                milliseconds: DateTime.now().millisecondsSinceEpoch -
                    since.millisecondsSinceEpoch)
            .inDays +
        1;

    Duration doneTime = await getAccumulatedTime(since);
    Duration(milliseconds: doneTime.inMilliseconds ~/ daysSinceDate);
    return doneTime - (minDiario * daysSinceDate);
  }

  Future<Duration> getAccumulatedTime(DateTime since) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String workspaceId = prefs
        .getInt(
            SharedPreferenceConstants.WORKSPACE_TOGGL.replaceAll("name", "id"))
        .toString();
    int tagBilledId = await getTagIdByName("billed");
    String getBilled = "";
    if (tagBilledId != null) {
      getBilled = "&tag_ids=${tagBilledId}";
    }
    //todo get the project id
    http.Response response = await (http.get(
      Uri.encodeFull(
          "https://toggl.com/reports/api/v2/summary?&workspace_id=${workspaceId}&user_agent=tti&since=${_convertedTogglDate(since)}&until=${_convertedTogglDate(DateTime.now())}&project_ids=${await _project_id}${getBilled}"),
      headers: await _headerAuth,
    ));

    Duration doneTime = Duration(
        milliseconds:
            Tools.BodyBytesToJson(response.bodyBytes)["total_grand"] ?? 0);
    return doneTime;
  }

  Future<Map<String, dynamic>> postTime(
      {@required String description,
      @required Duration duration,
      @required DateTime startDate,
      String sprint,
      bool countTime = true}) async {
    var url = 'https://www.toggl.com/api/v8/time_entries';
    print("date: ${_convertedTogglDate(startDate)}");
    var body = json.encode({
      "time_entry": {
        "description": description,
        "tags": [
          countTime || sprint != null ? "billed" : "",
          sprint != null ? "${sprint}" : "Extra"
        ],
        "duration": duration.inMilliseconds ~/ 1000,
        "start": _convertedTogglDate(startDate),
        "pid": await _project_id,
        "created_with": "curl"
      }
    });

    var response = await http.post(
      url,
      headers: await _headerAuth,
      body: body,
    );
    return Tools.BodyBytesToJson(response.bodyBytes);
  }

  Future<int> getLoggedUserId() async {
    http.Response response = await (http.get(
      Uri.encodeFull("https://www.toggl.com/api/v8/me"),
      headers: await _headerAuth,
    ));
    return Tools.BodyBytesToJson(response.bodyBytes)["data"]["id"];
  }

  Future<Map<int, String>> getUserProjects() async {
    http.Response response = await (http.get(
      Uri.encodeFull(
          "https://www.toggl.com/api/v8/workspaces/${await _workspace_id}/projects"),
      headers: await _headerAuth,
    ));
    Map<int, String> projects = Map<int, String>();
    try {
      (Tools.BodyBytesToJson(response.bodyBytes) as List).forEach((item) {
        if (item["name"] != null) {
          projects[item["id"]] = item["name"];
        }
      });
    } catch (e) {
      print("error: ${e}");
    }
    print(projects);
    return projects;
  }

  Future<Map<int, String>> getWorkspaces() async {
    http.Response response = await (http.get(
      Uri.encodeFull("https://www.toggl.com/api/v8/workspaces"),
      headers: await _headerAuth,
    ));
    Map<int, String> workspaces = Map<int, String>();

    try {
      (Tools.BodyBytesToJson(response.bodyBytes) as List).forEach((item) {
        if (item["name"] != null) {
          workspaces[item["id"]] = item["name"];
        }
      });
    } catch (e) {
      print("error: ${e}");
    }

    return workspaces;
  }

  Future<List> getWorkspacesTags() async {
    http.Response response = await (http.get(
      Uri.encodeFull(
          "https://www.toggl.com/api/v8/workspaces/${await _workspace_id}/tags"),
      headers: await _headerAuth,
    ));
    return Tools.BodyBytesToJson(response.bodyBytes);
  }

  Future<int> getTagIdByName(String name) async {
    int id;
    List result = await getWorkspacesTags();
    result.forEach((tag) {
      if (tag["name"] == name) {
        id = tag["id"];
      }
    });
    return id;
  }
}
