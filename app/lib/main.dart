/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:android_app_info/android_app_info.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';


void main() {
  runApp(new Zdata());
}


String shownAppName(AndroidAppInfo app) => app.label ?? app.name ?? app.packageName;

Image appIcon(AndroidAppInfo app) => new Image.memory(app.icon ?? app.defaultIcon);


class Zdata extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'zdata',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: new Root(),
    );
  }
}


enum Tool { fusecompress, fusermount, toolbox, mountsh, mountallsh, umountsh, toolboxsh }


const Map<Tool, String> TOOL_NAMES = const {
  Tool.fusecompress: 'fusecompress',
  Tool.fusermount: 'fusermount',
  Tool.toolbox: 'toolbox',
  Tool.mountsh: 'mount.sh',
  Tool.mountallsh: 'mountall.sh',
  Tool.umountsh: 'umount.sh',
  Tool.toolboxsh: 'toolbox.sh',
};


enum Action { enable, disable }


class GlobalFolderInformation {
  Directory datadir, storagedir;
}

final globalFolderInformation = new GlobalFolderInformation();


class Root extends StatefulWidget {
  @override
  _RootState createState() => new _RootState();
}


class _RootState extends State<Root> {
  List<AndroidAppInfo> _apps;
  Map<Tool, File> _tools;
  List<bool> _enabled;
  bool _sufail = false;

  @override
  initState() {
    super.initState();
    requestRootAndLoadAll();
  }

  Future requestRootAndLoadAll() async {
    // To get root access quickly
    var proc, sufail = false;

    try {
      proc = await Process.run('/system/bin/sh', ['-c', 'su', '-c', 'true']);
    } catch (e) {
      debugPrint("error: $e");
      sufail = true;
    }

    if (!sufail) {
      sufail = proc.exitCode != 0;
    }

    setState(() {
      _sufail = sufail;
    });

    loadAll();
  }

  Future loadAll() async {
    // To get root access quickly
    await loadTools();
    loadAppsAndMounts();
  }

  Future loadAppsAndMounts() async {
    await loadApps();
    loadEnabled();
  }

  Future loadTools() async {
    var arch = (await Process.run('uname', ['-m'])).stdout.trim();
    var bindir;

    switch (arch) {
    case 'armv7l':
    case 'armv8':
    case 'arm64':
    case 'aarch64':
      debugPrint('using bin-arm for ${arch}');
      bindir = 'bin-arm';
      break;
    case 'i386':
    case 'i686':
    case 'x86_64':
      debugPrint('using bin-x86 for ${arch}');
      bindir = 'bin-x86';
      break;
    default:
      debugPrint('using bin-arm for unknown arch ${arch}');
      bindir = 'bin-arm';
      break;
    }

    var datadir = await getApplicationDocumentsDirectory();
    var storagedir = new Directory(path.join(datadir.path, 'storage'));

    globalFolderInformation.datadir = datadir;
    globalFolderInformation.storagedir = storagedir;

    if (!await storagedir.exists())
      storagedir.create();

    var tools = <Tool, File>{};
    for (var tool in Tool.values) {
      var name = TOOL_NAMES[tool];

      var dir = name.endsWith('.sh') ? 'script' : bindir;
      var target = new File(path.join(datadir.path, name));

      tools[tool] = target;
      if (tool == Tool.fusecompress && await target.exists()) continue;

      var data = (await rootBundle.load('${dir}/${name}')).buffer.asUint8List();
      var io = target.openWrite();
      io.add(data);
      await io.flush();
      await io.close();
    }

    setState(() {
      _tools = tools;
    });
  }

  Future loadApps() async {
    var apps = (await AndroidAppInfo.getInstalledApplications())
                .where((app) => app.hasLaunchIntent &&
                                app.packageName != 'com.refi64.zdata.app').toList()
                ..sort((a, b) => shownAppName(a).toLowerCase().compareTo(
                                  shownAppName(b).toLowerCase()));

    setState(() {
      _apps = apps;
      _enabled = new List<bool>.filled(apps.length, false, growable: true);
    });
  }

  Future loadEnabled() async {
    var present = await globalFolderInformation.storagedir.list()
                    .where((e) => e is Directory)
                    .map((e) => path.basename(e.path))
                    .toList();
    debugPrint('present: $present');

    var newEnabled = <bool>[];
    for (var i=0; i<_apps.length; i++) {
      newEnabled.add(present.contains(_apps[i].packageName));
    }

    setState(() {
      _enabled = newEnabled;
    });
  }

  void url(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    var body;

    if (_sufail) {
      body = new Center(
        child: new Text('Failed to get root access!'),
      );
    } else if (_apps != null) {
      body = new AppSelectorWidget(
        apps: _apps,
        enabled: _enabled,
        onTap: (BuildContext context, AndroidAppInfo app, bool isenabled) {
          Navigator.of(context).push(new MaterialPageRoute<Null>(
            builder: (BuildContext context) =>
              new AppInfoPage(app: app, enabled: isenabled, tools: _tools),
          ));
        },
      );
    } else {
      var message = _tools == null ? 'Loading tools...' : 'Loading application list...';
      body = new Center(
        child: new Padding(
          padding: new EdgeInsets.only(top: 10.0),
          child: new Column(
            children: <Widget>[
              new CircularProgressIndicator(value: null),
              new Text(message),
            ],
          )
        )
      );
    }

    return new Scaffold(
      appBar: new AppBar(
        title: new Text('zdata'),
      ),
      drawer: new Drawer(
        child: new ListView(
          children: <Widget>[
            new DrawerHeader(
              decoration: new BoxDecoration(color: Colors.blue),
              child: new Text(
                'zdata',
                style: new TextStyle(color: Colors.white),
              ),
            ),
            new ListTile(
              leading: const Icon(null),
              title: const Text('Website'),
              onTap: () => url('https://refi64.com/proj/zdata.html'),
            ),
            new AboutListTile(
              applicationName: 'zdata',
              applicationVersion: '0.1.3',
            ),
          ],
        ),
      ),
      body: body,
    );
  }
}


class AppUsage {
  int actual, apparent;
  AppUsage({this.actual: 1, this.apparent: 1});
}


typedef void OnUsageUpdate(AppUsage usage);

class GlobalUsageCache {
  var _lastKnownUsage = <String, AppUsage>{};

  Future getUsageStream({String app, File toolbox, OnUsageUpdate onUsageUpdate}) async {
    if (!_lastKnownUsage.containsKey(app)) {
      _lastKnownUsage[app] = new AppUsage();

      var proc = await Process.start('/system/bin/sh',
                                     ['-c', 'su -c "sh ${toolbox.path} usage'
                                                      ' /data/data/$app"']);

      proc.stderr
        .transform(UTF8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          debugPrint('stderr from calculating usage of $app: $line');
        });

      proc.stdout
        .transform(UTF8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
          var split = line.split(' ').map(int.parse).toList();
          var apparent = split[0];
          var actual = split[1];

          var usage = new AppUsage(apparent: apparent, actual: actual);
          _lastKnownUsage[app] = usage;

          onUsageUpdate(usage);
        });
    }

    onUsageUpdate(_lastKnownUsage[app]);

    return new Future.value();
  }
}


final globalUsageCache = new GlobalUsageCache();


class AppInfoPage extends StatefulWidget {
  final AndroidAppInfo app;
  final bool enabled;
  final Map<Tool, File> tools;

  AppInfoPage({Key key, this.app, this.enabled, this.tools}): super(key: key);

  @override
  _AppInfoPageState createState() => new _AppInfoPageState();
}


class _AppInfoPageState extends State<AppInfoPage> {
  var _usage = new AppUsage();

  AndroidAppInfo get app => widget.app;
  bool get enabled => widget.enabled;
  Map<Tool, File> get tools => widget.tools;

  Widget runAction(Action action) {
    Tool tool;

    switch (action) {
    case Action.enable:
      tool = Tool.mountsh;
      break;
    case Action.disable:
      tool = Tool.umountsh;
      break;
    }

    var proc = Process.run('/system/bin/sh',
                           ['-c', 'su -c "sh ${tools[tool].path} ${app.packageName}"']);
    return new ActionPage(proc: proc, action: action, app: app);
  }

  void onTap(BuildContext context) {
    var message;
    Action action;

    if (enabled) {
      message = 'Disable zdata for this app? (The device will be restarted afterwards.)';
      action = Action.disable;
    } else {
      message = 'Enable zdata for this app?';
      action = Action.enable;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      child: new AlertDialog(
        title: new Text('Are you sure?'),
        content: new Text("${message} THIS WILL CLEAR ALL THE APP'S DATA!!!!!!"),
        actions: <Widget>[
          new FlatButton(
            child: new Text('NO'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          new FlatButton(
            child: new Text('YES'),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(new MaterialPageRoute<Null>(
                builder: (BuildContext context) => runAction(action),
              ));
            },
          ),
        ],
      ),
    );
  }

  void onUsageUpdate(AppUsage usage) {
    if (_usage.apparent != usage.apparent || _usage.actual != usage.actual) {
      print('apparent: ${usage.apparent}, actual: ${usage.actual}');
      setState(() {
        _usage = usage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var usageWidget;

    if (enabled) {
      globalUsageCache.getUsageStream(app: app.packageName,
                                      toolbox: tools[Tool.toolboxsh],
                                      onUsageUpdate: onUsageUpdate);

      var apparentMb = (_usage.apparent / 1024).toStringAsFixed(4);
      var actualMb = (_usage.actual / 1024).toStringAsFixed(4);
      var savings = ((_usage.apparent - _usage.actual) / _usage.apparent * 100)
                      .toStringAsFixed(4);

      usageWidget = new Padding(
        padding: new EdgeInsets.only(bottom: 10.0),
        child: new Column(
          children: [
            new Text('Uncompressed: $apparentMb MB'),
            new Text('Compressed: $actualMb MB'),
            new Text('Space savings: $savings%'),
          ]
        )
      );
    }

    return new Scaffold(
      appBar: new AppBar(
        title: new Text('zdata: ${shownAppName(app)}'),
      ),
      body: new Column(
        children: [
          new Row(
            children: [
              new Flexible(
                child: new Padding(
                  padding: new EdgeInsets.only(
                    left: 10.0,
                    top: 10.0,
                    bottom: 10.0,
                    right: 10.0
                  ),
                  child: appIcon(app),
                )
              ),
              new Flexible(flex: 3,
                child: new Padding(
                  padding: new EdgeInsets.only(left: 10.0, right: 10.0),
                  child: new Center(
                    child: new Column(
                      children: [
                        new Text(
                          shownAppName(app),
                          textAlign: TextAlign.center,
                          textScaleFactor: 2.0,
                        ),
                        new Text(
                          app.packageName,
                          textAlign: TextAlign.center,
                        ),
                      ]
                    )
                  ),
                )
              ),
              new Flexible(child: new Container()),
            ],
          ),
          new Container(child: usageWidget),
          new RaisedButton(
            child: new Text(enabled ? 'DISABLE' : 'ENABLE'),
            onPressed: () => onTap(context),
          ),
        ],
      ),
    );
  }
}


class ActionPage extends StatefulWidget {
  final Future<ProcessResult> proc;
  final Action action;
  final AndroidAppInfo app;

  ActionPage({Key key, this.proc, this.action, this.app}): super(key: key);

  @override
  _ActionPageState createState() => new _ActionPageState();
}


class _ActionPageState extends State<ActionPage> {
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('zdata: Performing action...'),
      ),
      body: new Center(
        child: new FutureBuilder<ProcessResult>(
          future: widget.proc,
          builder: (BuildContext context, AsyncSnapshot<ProcessResult> snapshot) {
            switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.waiting:
              return new Padding(
                padding: new EdgeInsets.only(top: 10.0),
                child: new Column(
                  children: [
                    new CircularProgressIndicator(value: null),
                    new Text('Please wait...'),
                  ],
                )
              );
            default:
              var message;

              if (snapshot.hasError) {
                message = 'An internal error occurred: ${snapshot.error}';
              } else if (snapshot.data.exitCode != 0) {
                message = 'Internal script failed!';
              } else {
                message = 'Success!';
              }

              if (!snapshot.hasError) {
                debugPrint(snapshot.data.stdout);
                debugPrint(snapshot.data.stderr);
              }

              return new Text(message);
            }
          },
        ),
      ),
    );
  }
}


typedef void AppSelectorWidgetOnTap(BuildContext context, AndroidAppInfo app,
                                    bool isenabled);

class AppSelectorWidget extends StatelessWidget {
  final List<AndroidAppInfo> apps;
  final List<bool> enabled;
  final AppSelectorWidgetOnTap onTap;

  AppSelectorWidget({Key key, this.apps, this.enabled, this.onTap}): super(key: key);

  @override
  Widget build(BuildContext context) {
    return new ListView.builder(
      itemCount: apps.length,
      itemBuilder: (BuildContext context, int index) {
        var app = apps[index];
        var isenabled = enabled[index];

        return new ListTile(
          leading: appIcon(app),
          title: new Text(shownAppName(app)),
          subtitle: new Text(app.dataDir),
          trailing: new Text(isenabled ? 'ENABLED' : 'DISABLED'),
          onTap: () { onTap(context, app, isenabled); },
        );
      },
    );
  }
}
