import 'dart:async';
import 'dart:io';

import 'package:timetrackingintegration/tools/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' show Codec, base64, json, utf8;
import 'package:shared_preferences/shared_preferences.dart';
import '../tools/tools.dart';

class Jira {
  int maxResults;

  Jira({this.maxResults = 50}) {}

  Codec<String, String> stringToBase64 = utf8.fuse(base64);

  Future<Map<String, String>> get _headerAuth async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String email = prefs.getString(SharedPreferenceConstants.EMAIL_JIRA);
    String token = prefs.getString(SharedPreferenceConstants.TOKEN_JIRA);

    Codec<String, String> stringToBase64 = utf8.fuse(base64);
    return {
      "Accept": "application/json",
      "Authorization": "Basic " +
          stringToBase64.encode(email + ":" + token),
    };
  }

  Future<String> get _projectId async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String project = prefs.getString(SharedPreferenceConstants.PROJECT_JIRA);
    return project;
  }

  Future<String> get _domainId async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String domain = prefs.getString(SharedPreferenceConstants.DOMAIN_JIRA);
    return domain;
  }

  Future<JiraIssues> getIssues() async {
    try {
      String url = Uri.encodeFull(
          "https://${await _domainId}.atlassian.net/rest/api/2/search?&maxResults=" +
              this.maxResults.toString() +
              "&fields=summary,status,timespent,customfield_10016,parent&jql=project=${await _projectId} AND issueType=Story AND statusCategory = ${JiraStatusConstants.IN_PROGRESS}");
      http.Response response = await (http.get(
        url,
        headers: await _headerAuth,
      ));

      JiraIssues data =
      JiraIssues.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      return data;
    }catch(e){
      print("error on get issues: $e");
      return null;
    }
  }

  Future<int> updateIssue(String key) async {
    var body = json.encode({
      "transition": {"id": "31"},
      "update": {
        "comment": [
          {
            "add": {"body": "Progress updated via app."}
          }
        ]
      },
    });
    String url =
        "https://${await _domainId}.atlassian.net/rest/api/2/issue/${key}/transitions?expand=transitions.fields";

    var response = await http.post(
      url,
      headers:  await _headerAuth,
      body: body,
    );

    return response.statusCode;
  }

  Future<Map<String, String>> getProjects() async {
    http.Response response = await (http.get(
      Uri.encodeFull("https://${await _domainId}.atlassian.net/rest/api/2/project"),
      headers: await _headerAuth,
    ));
    Map<String, String> workspaces = Map<String, String>();

    try {
      (Tools.BodyBytesToJson(response.bodyBytes) as List).forEach((item) {
        print("project: $item");
        if (item["name"] != null) {
          workspaces[item["key"]] = item["name"];
        }
      });
    } catch (e) {
      print("error: ${e}");
    }

    return workspaces;
  }
}

class Parent {
  String id;
  String key;
  String self;
  Fields fields;

  Parent({this.id, this.key, this.self, this.fields});

  Parent.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    key = json['key'];
    self = json['self'];
    fields =
        json['fields'] != null ? new Fields.fromJson(json['fields']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['key'] = this.key;
    data['self'] = this.self;
    if (this.fields != null) {
      data['fields'] = this.fields.toJson();
    }
    return data;
  }
}

class JiraIssues {
  String expand;
  int startAt;
  int maxResults;
  int total;
  List<Issues> issues;

  JiraIssues(
      {this.expand, this.startAt, this.maxResults, this.total, this.issues});

  JiraIssues.fromJson(Map<String, dynamic> json) {
    expand = json['expand'];
    startAt = json['startAt'];
    maxResults = json['maxResults'];
    total = json['total'];
    if (json['issues'] != null) {
      issues = List<Issues>();
      json['issues'].forEach((v) {
        issues.add(Issues.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['expand'] = this.expand;
    data['startAt'] = this.startAt;
    data['maxResults'] = this.maxResults;
    data['total'] = this.total;
    if (this.issues != null) {
      data['issues'] = this.issues.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Issues {
  String expand;
  String id;
  String self;
  String key;
  Fields fields;

  Issues({this.expand, this.id, this.self, this.key, this.fields});

  Issues.fromJson(Map<String, dynamic> json) {
    expand = json['expand'];
    id = json['id'];
    self = json['self'];
    key = json['key'];
    fields = json['fields'] != null ? Fields.fromJson(json['fields']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['expand'] = this.expand;
    data['id'] = this.id;
    data['self'] = this.self;
    data['key'] = this.key;
    if (this.fields != null) {
      data['fields'] = this.fields.toJson();
    }
    return data;
  }
}

class Fields {
  String summary;
  Status status;
  int timespent;
  Parent parent;
  double customfield_10016;

  Fields({
    this.summary,
    this.status,
    this.timespent,
    this.parent,
  });

  Fields.fromJson(Map<String, dynamic> json) {
    summary = json['summary'];
    timespent = json["timespent"];
    customfield_10016 = json["customfield_10016"];
    parent = json['parent'] != null ? Parent.fromJson(json['parent']) : null;
    status = json['status'] != null ? Status.fromJson(json['status']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['summary'] = this.summary;
    if (this.parent != null) {
      data['parent'] = this.parent.toJson();
    }
    data["timespent"] = this.timespent;
    data["customfield_10016"] = this.customfield_10016;
    if (this.status != null) {
      data['status'] = this.status.toJson();
    }
    return data;
  }
}

class Status {
  String self;
  String description;
  String iconUrl;
  String name;
  String id;
  StatusCategory statusCategory;

  Status(
      {this.self,
      this.description,
      this.iconUrl,
      this.name,
      this.id,
      this.statusCategory});

  Status.fromJson(Map<String, dynamic> json) {
    self = json['self'];
    description = json['description'];
    iconUrl = json['iconUrl'];
    name = json['name'];
    id = json['id'];
    statusCategory = json['statusCategory'] != null
        ? StatusCategory.fromJson(json['statusCategory'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['self'] = this.self;
    data['description'] = this.description;
    data['iconUrl'] = this.iconUrl;
    data['name'] = this.name;
    data['id'] = this.id;
    if (this.statusCategory != null) {
      data['statusCategory'] = this.statusCategory.toJson();
    }
    return data;
  }
}

class StatusCategory {
  String self;
  int id;
  String key;
  String colorName;
  String name;

  StatusCategory({this.self, this.id, this.key, this.colorName, this.name});

  StatusCategory.fromJson(Map<String, dynamic> json) {
    self = json['self'];
    id = json['id'];
    key = json['key'];
    colorName = json['colorName'];
    name = json['name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['self'] = this.self;
    data['id'] = this.id;
    data['key'] = this.key;
    data['colorName'] = this.colorName;
    data['name'] = this.name;
    return data;
  }
}
