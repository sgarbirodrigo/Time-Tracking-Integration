import 'package:sqflite/sqflite.dart';

class SQL_TABLE_CONSTANTS {
  static String USER_DATA = "UserData";
  static String TIMERS = "Timers";
  static String TIMER_DATA = "TimerData";
}

class SqlDatabase {
  Database db;

  void createInstance() async {
    this.db = await openDatabase('tti.db', version: 5,
        onCreate: (Database db, int version) async {
      print("onCreate");
      await db.execute('CREATE TABLE ${SQL_TABLE_CONSTANTS.USER_DATA} ('
          'jiraDomain TEXT, '
          'jiraToken TEXT,'
          'jiraEmail TEXT, '
          'togglToken TEXT,'
          'defaultJiraProject TEXT,'
          'defaultTogglProject TEXT,'
          'defaultTogglWorkspace TEXT,'
          'sinceMillisecondssinceepoch INTEGER,'
          'sessions INTEGER,'
          'minimumDailyMilliseconds INTEGER'
          ')');
      await db.execute('CREATE TABLE ${SQL_TABLE_CONSTANTS.TIMERS} ('
          'startMillisecondssinceepoch INTEGER, '
          'elapsedMilliseconds INTEGER'
          ')');
      await db.execute('CREATE TABLE ${SQL_TABLE_CONSTANTS.TIMER_DATA} ('
          'status TEXT, '
          'taskId TEXT, '
          'taskName TEXT, '
          'taskParentId TEXT, '
          'runningTimerStartMillisinceepoch INTEGER, '
          'runningTimerStartDurationMilli INTEGER, '
          'timerExpectedDurationMilli INTEGER'
          ')');
    });
  }

  Future<void> clearUserData() async {
    List<Map<String, dynamic>> maps =
        await this.getTable(SQL_TABLE_CONSTANTS.USER_DATA);
    UserData nullUserData = UserData();
    if (maps.length > 0) {
      await this.db.update(
            SQL_TABLE_CONSTANTS.USER_DATA,
            nullUserData.toJson(),
          );
    } else {
      await this.db.insert(
            SQL_TABLE_CONSTANTS.USER_DATA,
            nullUserData.toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
    }
  }

  Future<void> updateUserData(
      {UserData userData, bool subscribeAll = false}) async {
    List<Map<String, dynamic>> maps =
        await this.getTable(SQL_TABLE_CONSTANTS.USER_DATA);
    if (maps.length > 0) {
      var newMap = <String, dynamic>{};
      userData.toJson().forEach((key, value) {
        if (value != null) {
          newMap[key] = value;
        }
      });
      if (subscribeAll) {
        await this.db.update(
              SQL_TABLE_CONSTANTS.USER_DATA,
              userData.toJson(),
            );
      } else {
        await this.db.update(
              SQL_TABLE_CONSTANTS.USER_DATA,
              newMap,
            );
      }
    } else {
      await this.db.insert(
            SQL_TABLE_CONSTANTS.USER_DATA,
            userData.toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
    }
  }

  Future<UserData> getUserData() async {
    List<Map<String, dynamic>> maps =
        await this.getTable(SQL_TABLE_CONSTANTS.USER_DATA);
    if (maps.length == 1) {
      return UserData.fromJson(maps[0]);
    } else if (maps.length == 0) {
      return UserData();
    } else {
      return throw new Exception('Should exist only one row in UserData table');
    }
  }

  Future<List<Map<String, dynamic>>> getTable(String table) async {
    final List<Map<String, dynamic>> maps = await this.db.query(table);
    return maps;
  }

  void closeDB() async {
    await this.db.close();
  }

  Future<void> play(Duration duration, String taskId, String taskName,
      String taskParentName) async {
    List<Map<String, dynamic>> maps =
        await this.getTable(SQL_TABLE_CONSTANTS.TIMER_DATA);

    TimerData timerData;
    if (maps.length > 0) {
      timerData = TimerData.fromJson(maps[0]);
    } else {
      timerData = TimerData();
    }

    timerData.status = "playing";
    timerData.taskName = taskName;
    timerData.taskId = taskId;
    timerData.taskParentId = taskParentName;

    timerData.runningTimerStartMillisinceepoch =
        DateTime.now().millisecondsSinceEpoch;
    timerData.runningTimerStartDurationMilli = duration.inMilliseconds;
    if (timerData.timerExpectedDurationMilli == null) {
      timerData.timerExpectedDurationMilli = duration.inMilliseconds;
    }

    if (maps.length > 0) {
      await this.db.update(
            SQL_TABLE_CONSTANTS.TIMER_DATA,
            timerData.toJson(),
          );
    } else {
      await this.db.insert(
            SQL_TABLE_CONSTANTS.TIMER_DATA,
            timerData.toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
    }
  }

  Future<void> pause() async {
    List<Map<String, dynamic>> maps =
        await this.getTable(SQL_TABLE_CONSTANTS.TIMER_DATA);

    TimerData timerData = TimerData.fromJson(maps[0]);

    timerData.status = "paused";
    Duration elapsed = Duration(
        milliseconds: DateTime.now().millisecondsSinceEpoch -
            timerData.runningTimerStartMillisinceepoch);
    await _addTimeToQueue(
        DateTime.fromMicrosecondsSinceEpoch(
            timerData.runningTimerStartMillisinceepoch),
        elapsed);

    if (maps.length > 0) {
      await this.db.update(
            SQL_TABLE_CONSTANTS.TIMER_DATA,
            timerData.toJson(),
          );
    } else {
      await this.db.insert(
            SQL_TABLE_CONSTANTS.TIMER_DATA,
            timerData.toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
    }
  }
  Future<void> hitMax() async {
    List<Map<String, dynamic>> maps =
    await this.getTable(SQL_TABLE_CONSTANTS.TIMER_DATA);

    TimerData timerData = TimerData.fromJson(maps[0]);

    timerData.status = "paused";
    Duration elapsed = Duration(
        milliseconds:
            timerData.runningTimerStartDurationMilli);
    await _addTimeToQueue(
        DateTime.fromMicrosecondsSinceEpoch(
            timerData.runningTimerStartMillisinceepoch),
        elapsed);

    if (maps.length > 0) {
      await this.db.update(
        SQL_TABLE_CONSTANTS.TIMER_DATA,
        timerData.toJson(),
      );
    } else {
      await this.db.insert(
        SQL_TABLE_CONSTANTS.TIMER_DATA,
        timerData.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> stop() async {
    List<Map<String, dynamic>> maps =
        await this.getTable(SQL_TABLE_CONSTANTS.TIMER_DATA);

    TimerData timerData = TimerData.fromJson(maps[0]);

    timerData.status = null;
    timerData.taskId = null;
    timerData.taskName = null;
    timerData.taskParentId = null;
    timerData.runningTimerStartMillisinceepoch = null;
    timerData.runningTimerStartDurationMilli = null;
    timerData.timerExpectedDurationMilli = null;
    await _clearTimerQueue();
    if (maps.length > 0) {
      await this.db.update(
            SQL_TABLE_CONSTANTS.TIMER_DATA,
            timerData.toJson(),
          );
    } else {
      await this.db.insert(
            SQL_TABLE_CONSTANTS.TIMER_DATA,
            timerData.toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
    }
  }

  _addTimeToQueue(DateTime dateTime, Duration elapsed) async {
    Timer timer = Timer();
    timer.startMillisecondssinceepoch = dateTime.millisecondsSinceEpoch;
    timer.elapsedMilliseconds = elapsed.inMilliseconds;
    await this.db.insert(
          SQL_TABLE_CONSTANTS.TIMERS,
          timer.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
  }

  _clearTimerQueue() async {
    await this.db.delete(
          SQL_TABLE_CONSTANTS.TIMERS,
        );
  }

  Future<List<Timer>> _getTimersOnQueue() async {
    List<Map<String, dynamic>> maps =
        await this.getTable(SQL_TABLE_CONSTANTS.TIMERS);
    if (maps.length > 0) {
      List<Timer> timers = List();
      maps.forEach((map) {
        timers.add(Timer.fromJson(map));
      });
      return timers;
    } else {
      return null;
    }
  }

  Future<TimerData> getTimerData() async {
    List<Map<String, dynamic>> maps =
        await this.getTable(SQL_TABLE_CONSTANTS.TIMER_DATA);
    if (maps.length > 0) {
      TimerData timerData = TimerData.fromJson(maps[0]);
      List<Timer> timers = await _getTimersOnQueue();
      timerData.timersQueue = timers;
      return timerData;
    } else {
      return TimerData();
    }
  }
}

class TimerData {
  String _status, _taskName, _taskId, _taskParentId;
  int _runningTimerStartMillisinceepoch;
  int _runningTimerStartDurationMilli;
  int _timerExpectedDurationMilli;
  List<Timer> _timersQueue;

  get taskParentId => _taskParentId;

  set taskParentId(value) {
    _taskParentId = value;
  }

  int get timerExpectedDurationMilli => _timerExpectedDurationMilli;

  set timerExpectedDurationMilli(int value) {
    _timerExpectedDurationMilli = value;
  }

  get taskName => _taskName;

  set taskName(value) {
    _taskName = value;
  }

  String get status => _status;

  int get runningTimerStartMillisinceepoch => _runningTimerStartMillisinceepoch;

  int get runningTimerStartDurationMilli => _runningTimerStartDurationMilli;

  List<Timer> get timersQueue => _timersQueue;

  set status(String value) {
    _status = value;
  }

  TimerData(
      {String status,
      String taskId,
      String taskName,
      String taskParentId,
      int runningTimerStartMillisinceepoch,
      int runningTimerStartDurationMilli,
      int timerExpectedDurationMilli,
      List<Timer> timersQueue}) {
    _status = status;
    _taskName = taskName;
    _taskId = taskId;
    _taskParentId = taskParentId;
    _timerExpectedDurationMilli = timerExpectedDurationMilli;
    _runningTimerStartMillisinceepoch = runningTimerStartMillisinceepoch;
    _runningTimerStartDurationMilli = runningTimerStartDurationMilli;
    _timersQueue = timersQueue;
  }

  TimerData.fromJson(dynamic json) {
    _status = json["status"];
    _taskId = json["taskId"];
    _taskName = json["taskName"];
    _taskParentId = json["taskParentId"];
    _runningTimerStartMillisinceepoch =
        json["runningTimerStartMillisinceepoch"];
    _timerExpectedDurationMilli = json["timerExpectedDurationMilli"];
    _runningTimerStartDurationMilli = json["runningTimerStartDurationMilli"];
    if (json["timersQueue"] != null) {
      _timersQueue = [];
      json["timersQueue"].forEach((v) {
        _timersQueue.add(Timer.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    map["status"] = _status;
    map["taskId"] = _taskId;
    map["taskName"] = _taskName;
    map["runningTimerStartMillisinceepoch"] = _runningTimerStartMillisinceepoch;
    map["runningTimerStartDurationMilli"] = _runningTimerStartDurationMilli;
    map["timerExpectedDurationMilli"] = _timerExpectedDurationMilli;
    map["taskParentId"] = _taskParentId;
    if (_timersQueue != null) {
      map["timersQueue"] = _timersQueue.map((v) => v.toJson()).toList();
    }
    return map;
  }

  set runningTimerStartMillisinceepoch(int value) {
    _runningTimerStartMillisinceepoch = value;
  }

  set runningTimerStartDurationMilli(int value) {
    _runningTimerStartDurationMilli = value;
  }

  set timersQueue(List<Timer> value) {
    _timersQueue = value;
  }

  get taskId => _taskId;

  set taskId(value) {
    _taskId = value;
  }
}

class Timer {
  int _startMillisecondssinceepoch;
  int _elapsedMilliseconds;

  set startMillisecondssinceepoch(int value) {
    _startMillisecondssinceepoch = value;
  }

  int get startMillisecondssinceepoch => _startMillisecondssinceepoch;

  int get elapsedMilliseconds => _elapsedMilliseconds;

  Timer({int startMillisecondssinceepoch, int elapsedMilliseconds}) {
    _startMillisecondssinceepoch = startMillisecondssinceepoch;
    _elapsedMilliseconds = elapsedMilliseconds;
  }

  Timer.fromJson(dynamic json) {
    _startMillisecondssinceepoch = json["startMillisecondssinceepoch"];
    _elapsedMilliseconds = json["elapsedMilliseconds"];
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    map["startMillisecondssinceepoch"] = _startMillisecondssinceepoch;
    map["elapsedMilliseconds"] = _elapsedMilliseconds;
    return map;
  }

  set elapsedMilliseconds(int value) {
    _elapsedMilliseconds = value;
  }
}

class UserData {
  String _jiraDomain;
  String _jiraToken;
  String _jiraEmail;
  String _togglToken;
  String _defaultJiraProject;
  String _defaultTogglProject;
  String _defaultTogglWorkspace;
  int _sinceMillisecondssinceepoch;
  int _sessions;
  int _minimumDailyMilliseconds;

  String get jiraDomain => _jiraDomain;

  String get jiraToken => _jiraToken;

  String get jiraEmail => _jiraEmail;

  String get togglToken => _togglToken;

  String get defaultJiraProject => _defaultJiraProject;

  String get defaultTogglProject => _defaultTogglProject;

  String get defaultTogglWorkspace => _defaultTogglWorkspace;

  int get sinceMillisecondssinceepoch => _sinceMillisecondssinceepoch;

  int get sessions => _sessions;

  int get minimumDailyMilliseconds => _minimumDailyMilliseconds;

  UserData(
      {String jiraDomain,
      String jiraToken,
      String jiraEmail,
      String togglToken,
      String defaultJiraProject,
      String defaultTogglProject,
      String defaultTogglWorkspace,
      int sinceMillisecondssinceepoch,
      int sessions,
      int minimumDailyMilliseconds}) {
    _jiraDomain = jiraDomain;
    _jiraToken = jiraToken;
    _jiraEmail = jiraEmail;
    _togglToken = togglToken;
    _defaultJiraProject = defaultJiraProject;
    _defaultTogglProject = defaultTogglProject;
    _defaultTogglWorkspace = defaultTogglWorkspace;
    _sinceMillisecondssinceepoch = sinceMillisecondssinceepoch;
    _sessions = sessions;
    _minimumDailyMilliseconds = minimumDailyMilliseconds;
  }

  UserData.fromJson(dynamic json) {
    _jiraDomain = json["jiraDomain"];
    _jiraToken = json["jiraToken"];
    _jiraEmail = json["JiraEmail"];
    _togglToken = json["togglToken"];
    _defaultJiraProject = json["defaultJiraProject"];
    _defaultTogglProject = json["defaultTogglProject"];
    _defaultTogglWorkspace = json["defaultTogglWorkspace"];
    _sinceMillisecondssinceepoch = json["sinceMillisecondssinceepoch"];
    _sessions = json["sessions"];
    _minimumDailyMilliseconds = json["minimumDailyMilliseconds"];
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    map["jiraDomain"] = _jiraDomain;
    map["jiraToken"] = _jiraToken;
    map["JiraEmail"] = _jiraEmail;
    map["togglToken"] = _togglToken;
    map["defaultJiraProject"] = _defaultJiraProject;
    map["defaultTogglProject"] = _defaultTogglProject;
    map["defaultTogglWorkspace"] = _defaultTogglWorkspace;
    map["sinceMillisecondssinceepoch"] = _sinceMillisecondssinceepoch;
    map["sessions"] = _sessions;
    map["minimumDailyMilliseconds"] = _minimumDailyMilliseconds;
    return map;
  }
}
