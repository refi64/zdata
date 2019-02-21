import 'package:flutter/material.dart';

import 'package:device_apps/device_apps.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(App());

class App extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        fontFamily: 'Montserrat',
        primaryColor: const Color(0xff0d47a1),
        accentColor: const Color(0xff0d47a1),
      ),
      home: Home(),
    );
  }
}

class Home extends StatefulWidget {
  HomeState createState() => HomeState();
}

class HomeState extends State<Home> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('zdata'),
        centerTitle: true,
        backgroundColor: Colors.white,
        iconTheme: IconTheme.of(context).copyWith(color: Colors.black),
        textTheme: Theme.of(context).textTheme.apply(bodyColor: Colors.black),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(),
            ListTile(
              title: const Text('Settings'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: const Icon(Icons.apps), title: const Text('Apps')),
          BottomNavigationBarItem(icon: const Icon(Icons.folder), title: const Text('Files')),
        ],
        currentIndex: index,
        onTap: (newIndex) {
          setState(() {
            index = newIndex;
          });
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => null,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Center(child: const Text('123')),
    );
  }
}
