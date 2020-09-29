import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ItemSettingsNumber extends StatefulWidget {
  String pageTitle, fieldTitle, sharedVariableName;

  ItemSettingsNumber(
      this.pageTitle, this.fieldTitle, this.sharedVariableName);

  @override
  _ItemSettingsNumberState createState() =>
      _ItemSettingsNumberState();
}

class _ItemSettingsNumberState extends State<ItemSettingsNumber> {
  SharedPreferences prefs;
  int fieldValue;
  TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  _load() async {
    prefs = await SharedPreferences.getInstance();
    fieldValue = prefs.getInt(widget.sharedVariableName);
    _controller = TextEditingController(text: fieldValue.toString());
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
                controller: _controller,keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: widget.fieldTitle,
                  alignLabelWithHint: true,
                  contentPadding:
                      EdgeInsets.only(left: 0, bottom: 4, top: 0, right: 0),
                ),
                onChanged: (value) async {
                  fieldValue = int.tryParse(value);
                  await prefs.setInt(widget.sharedVariableName, fieldValue);

                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
