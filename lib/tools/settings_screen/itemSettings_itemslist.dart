import 'package:TimeTrackingIntegration/toggl/toggl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ItemSettingsListItem extends StatefulWidget {
  String pageTitle, sharedVariableName;
  Function builder;

  ItemSettingsListItem(this.pageTitle, this.sharedVariableName,this.builder);

  @override
  _ItemSettingsListItemState createState() => _ItemSettingsListItemState();
}

class _ItemSettingsListItemState extends State<ItemSettingsListItem> {
  SharedPreferences prefs;
  String fieldValue;

  TextEditingController _controller;
  Map mapListLoaded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  _load() async {
    prefs = await SharedPreferences.getInstance();
    fieldValue = prefs.getString(widget.sharedVariableName);
    _controller = TextEditingController(text: fieldValue);
    mapListLoaded = await widget.builder();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        padding: EdgeInsetsDirectional.only(start: 0),
        leading: Container(
          padding: EdgeInsets.only(left: 0),
          child: IconButton(
            iconSize: 32,
            icon: Icon(
              Icons.chevron_left,
              color: Colors.blue,
            ),
            onPressed: () {
              Navigator.pop(context, fieldValue);
            },
          ),
        ),
        middle: Text(widget.pageTitle),
      ),
      child: SafeArea(
        //bottom: false,
        child: mapListLoaded != null
            ? ListView.builder(
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                itemCount: mapListLoaded.length,
                itemBuilder: (BuildContext context, int index) {
                  return GestureDetector(
                      onTap: () async {
                        fieldValue =
                            mapListLoaded.values.toList()[index].toString();
                        await prefs.setInt(
                            widget.sharedVariableName.replaceAll("name", "id"),
                            int.tryParse(
                                mapListLoaded.keys.toList()[index].toString()));
                        await prefs.setString(widget.sharedVariableName,
                            mapListLoaded.values.toList()[index].toString());
                        setState(() {});
                      },
                      child: Container(
                          color: Colors.white,
                          child: Column(
                            children: <Widget>[
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 12),
                                child: Row(
                                  children: <Widget>[
                                    Text(mapListLoaded.values
                                        .toList()[index]
                                        .toString()),
                                    Expanded(child: Container(),),
                                    fieldValue ==
                                            mapListLoaded.values
                                                .toList()[index]
                                                .toString()
                                        ? Icon(Icons.done,size: 16,color: Colors.blue,)
                                        : Container(/*width: 24*/),
                                    Container(width: 12,)
                                  ],
                                ),
                              ),
                              Container(
                                color: Colors.black12.withOpacity(0.1),
                                height: 1,
                                width: index == mapListLoaded.length - 1
                                    ? MediaQuery.of(context).size.width
                                    : MediaQuery.of(context).size.width * 0.95,
                              )
                            ],
                          )));
                })
            : Center(
                child: Container(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(),
              )),
      ),
    );
  }
}
