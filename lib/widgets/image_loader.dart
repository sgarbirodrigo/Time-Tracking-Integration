import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:timetrackingintegration/jira/jira.dart';
import 'package:webview_flutter/webview_flutter.dart';

class JiraAvatarLoader extends StatefulWidget {
  String url;
  Map<String, String> headers;
  JiraAvatarLoader({this.url, this.headers}) {
    //print("check url: ${this.url}");
  }

  @override
  State<StatefulWidget> createState() {
    return _JiraAvatarLoaderState();
  }
}

class _JiraAvatarLoaderState extends State<JiraAvatarLoader> {
  @override
  void initState() {
    super.initState();
    //print("init loader");
    _loadAvatar();
  }

  Image image;

  int isSVG = 0;

  _loadAvatar() async {
    Jira jira = Jira();
    //print("enter load");
    if (widget.url != null) {
      //print("url NOT null");
      try {
        image = await jira.getAvatar(widget.url);
        isSVG = 1;
      } catch (e) {
        print("error load avatar: ${e.hashCode}");
        isSVG = -1;
      }
    } else {
      print("url null");
      isSVG = 0;
    }
    //print("url: ${widget.url}");
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    //print("isSVG: $isSVG");
    Widget imageWidget;
    double size = 48;
    if (isSVG == 1) {
      imageWidget = Container(
          width: size,
          height: size,
          margin: EdgeInsets.only(left: 0, right: 0, top: 0),
          child: SvgPicture.network(
            widget.url,
            headers: widget.headers,
            semanticsLabel: 'Avatar',
            placeholderBuilder: (BuildContext context) =>
                Container(child: const CircularProgressIndicator()),
          ));
    } else if (isSVG == -1) {
      imageWidget = Container(
        width: size,
        height: size,
        margin: EdgeInsets.only(left: 0, right: 0, top: 0),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(widget.url, headers: widget.headers),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else if (isSVG == 0) {
      imageWidget = Container();
    }
    return imageWidget;
  }
}
