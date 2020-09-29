import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ItemSettingsTextFormField extends StatefulWidget {
  String pageTitle, fieldTitle, sharedVariableName;

  ItemSettingsTextFormField(
      this.pageTitle, this.fieldTitle, this.sharedVariableName);

  @override
  _ItemSettingsTextFormFieldState createState() =>
      _ItemSettingsTextFormFieldState();
}

class _ItemSettingsTextFormFieldState extends State<ItemSettingsTextFormField> {
  SharedPreferences prefs;
  String fieldValue;
  TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  _load() async {
    prefs = await SharedPreferences.getInstance();
    fieldValue = prefs.getString(widget.sharedVariableName);
    _controller = TextEditingController(text: fieldValue);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        padding: EdgeInsetsDirectional.only(start: 0),
        leading: Container(
          padding: EdgeInsets.only(left: 0),
          child: IconButton(iconSize: 32,
            icon: Icon(Icons.chevron_left,color: Colors.blue,),
            onPressed: () {
              Navigator.pop(context, fieldValue);
            },
          ),
        ),
        middle: Text(widget.pageTitle),
      ),
      child: SafeArea(
        //bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: widget.fieldTitle,
                  alignLabelWithHint: true,
                  contentPadding:
                      EdgeInsets.only(left: 0, bottom: 4, top: 0, right: 0),
                ),
                onChanged: (value) async {
                  await prefs.setString(widget.sharedVariableName, value);
                  fieldValue = value;
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
