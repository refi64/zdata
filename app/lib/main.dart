import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:android_app_info/android_app_info.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'dart:async';
import 'dart:io';


void main() {
  runApp(new Zdata());
}


String shownAppName(AndroidAppInfo app) => app.label ?? app.name ?? app.packageName;


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

class Root extends StatefulWidget {
  @override
  _RootState createState() => new _RootState();
}


enum Tool { fusecompress, fusermount, mountsh, umountsh }


const Map<Tool, String> TOOL_NAMES = const {
  Tool.fusecompress: 'fusecompress',
  Tool.fusermount: 'fusermount',
  Tool.mountsh: 'mount.sh',
  Tool.umountsh: 'umount.sh',
};


enum Action { enable, disable }


class _RootState extends State<Root> {
  List<AndroidAppInfo> _apps;
  Directory _storagedir;
  Map<Tool, File> _tools;
  List<bool> _enabled;

  @override
  initState() {
    super.initState();
    loadAll();
  }

  Future loadAll() async {
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

    if (arch == 'armv7l') {
      bindir = 'bin-arm';
    } else if (arch == 'armv8') {
      bindir = 'bin-arm64';
    } else {
      // asume ARM for now
      bindir = 'bin-arm';
    }

    var datadir = await getApplicationDocumentsDirectory();
    var storagedir = new Directory(path.join(datadir.path, 'storage'));

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
      _storagedir = storagedir;
      _tools = tools;
    });
  }

  Future loadApps() async {
    var apps = (await AndroidAppInfo.getInstalledApplications())
                .where((app) => app.hasLaunchIntent).toList()
                ..sort((a, b) => shownAppName(a).toLowerCase().compareTo(
                                  shownAppName(b).toLowerCase()));

    setState(() {
      _apps = apps;
      _enabled = new List<bool>.filled(apps.length, false, growable: true);
    });
  }

  Future loadEnabled() async {
    // XXX: laziness: ls -1 <dir> is easier than basename path manipulations...
    var proc = await Process.run('ls', ['-1', _storagedir.path]);
    var present = proc.stdout.split('\n');
    debugPrint('present: $present');

    var newEnabled = <bool>[];
    for (var i=0; i<_apps.length; i++) {
      newEnabled.add(present.contains(_apps[i].packageName));
    }

    setState(() {
      _enabled = newEnabled;
    });
  }

  Widget runAction(Action action, AndroidAppInfo app) {
    Tool tool;

    switch (action) {
    case Action.enable:
      tool = Tool.mountsh;
      break;
    case Action.disable:
      tool = Tool.umountsh;
      break;
    }

    var proc = Process.run('su', ['-c', 'sh', _tools[tool].path, app.packageName]);
    return new ActionPage(proc: proc, action: action, app: app);
  }

  void onTap(BuildContext context, AndroidAppInfo app, bool isenabled) {
    var message;
    Action action;

    if (isenabled) {
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
            child: new Text('Nevermind...'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          new FlatButton(
            child: new Text('Go ahead!!'),
            onPressed: () {
              Navigator.of(context).push(new MaterialPageRoute<Null>(
                builder: (BuildContext context) => runAction(action, app),
              ));
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var body;

    if (_apps != null) {
      body = new AppSelectorWidget(
        apps: _apps,
        enabled: _enabled,
        onTap: onTap,
      );
    } else {
      var message = _tools == null ? 'Loading tools...'
                                   : 'Loading application list...';
      body = new Center(
        child: new Column(
          children: <Widget>[
            new CircularProgressIndicator(value: null),
            new Text(message),
          ],
        ),
      );
    }

    return new Scaffold(
      appBar: new AppBar(
        title: new Text('zdata'),
      ),
      body: body,
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
              return new Column(
                children: [
                  new CircularProgressIndicator(value: null),
                  new Text('Please wait...'),
                ],
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
          leading: new Image.memory(app.icon ?? app.defaultIcon),
          title: new Text(shownAppName(app)),
          subtitle: new Text(app.dataDir),
          trailing: new Text(isenabled ? 'ENABLED' : 'DISABLED'),
          onTap: () { onTap(context, app, isenabled); },
        );
      },
    );
  }
}
