import 'package:timetrackingintegration/tools/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetrackingintegration/tools/sql_db.dart';

import '../lib/jira/jira.dart';
import 'tokens/test_tokens.dart';

void main() {
  Jira jira = Jira();
  SharedPreferences.setMockInitialValues({
    SharedPreferenceConstants.EMAIL_JIRA: TestConstants.EMAIL_JIRA,
    SharedPreferenceConstants.TOKEN_JIRA: TestConstants.TOKEN_JIRA,
    SharedPreferenceConstants.DOMAIN_JIRA: TestConstants.DOMAIN_JIRA,
    SharedPreferenceConstants.PROJECT_JIRA: TestConstants.PROJECT_JIRA
  });
  test('Test Jira List Projects', () async {
    Map<String, String> projects = await jira.getProjects();
    print("Projects $projects");
    expect(projects.length, isNot(0));
  });
  test('Test Jira List Issues', () async {
    JiraIssues issues = await jira.getIssues();
    print("Issues: ${issues.issues.length}");
    expect(issues.issues.length, isNot(0));
  });
  test('Sql test', () async {
    SqlDatabase sqlDatabase = SqlDatabase();
    await sqlDatabase.createInstance();

    final List<Map<String, dynamic>> maps =
        await sqlDatabase.getTable(SQL_TABLE_CONSTANTS.USER_DATA);
    print(maps);

    sqlDatabase.closeDB();
  });
}
