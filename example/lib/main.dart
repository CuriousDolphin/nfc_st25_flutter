import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:nfc_st25/nfc_st25.dart';
import 'package:nfc_st25/utils/nfc_st25_tag.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Test",
      home: ExamplePage(),
    );
  }
}

class ExamplePage extends StatefulWidget {
  @override
  _ExamplePage createState() => _ExamplePage();
}

class _ExamplePage extends State<ExamplePage> {
  String _platformVersion = 'Unknown';
  bool nfcAvailability = false;
  St25Tag lastTag;
  bool loading = false;
  Uint8List last_msg;
  List<String> logs = [];
  MailBox mailBoxInfo;
  ScrollController _scrollController = new ScrollController();

  List<dynamic> commands = [
    [0, 1, 0],
    [0, 1, 1],
    [0, 1, 2],
  ];

  StreamSubscription<St25Tag> _subscription;

  // needed for snackbar
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    initPlatformState();
    NfcSt25.nfcAvailability.then((value) => {
          setState(() {
            nfcAvailability = value;
          })
        });
    startListen();
  }

  startListen() {
    _subscription = NfcSt25.startReading().listen((tag) {
      log("TAG FOUND: " + tag.uid);
      //showSnackBar("Tag found " + tag.uid, false);
      setState(() {
        lastTag = tag;
        mailBoxInfo = tag.mailBox;
      });
    }, onError: (e) => log(e.toString()));
  }

  clearLogs() {
    setState(() {
      logs = [];
    });
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await NfcSt25.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  void log(String s) {
    print(s);
    setState(() {
      logs.add(s);
    });
    goBottomLog();
  }

  goBottomLog() {
    if (_scrollController.hasClients) {
      var scrollPosition = _scrollController.position;

      _scrollController.animateTo(
        scrollPosition.maxScrollExtent + 200,
        duration: new Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> readMailBoxMsg() async {
    int cnt = 0;
    Uint8List msg;
    while (cnt < 5) {
      try {
        log("Read try #" + cnt.toString());
        if (cnt > 0) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
        msg = await NfcSt25.readMailbox;
        last_msg = msg;
        log("READ MSG (" + msg.length.toString() + ") : " + msg.toString());
        break;
      } catch (e) {
        log("failed read  -> " + e.toString());
        cnt++;
      }
    }

    setState(() {
      last_msg = msg;
    });
  }

  Future<void> resetMailBox() async {
    try {
      await NfcSt25.resetMailBox();
      log("SUCCESSFUL RESET MAILBOX");
    } catch (e) {
      log("Error reset mailbox" + e.toString());
      //showSnackBar("failed to reset mailbox -> " + e.toString(), true);
    }
  }

  Future<void> getMailBoxInfo() async {
    MailBox mailbox;
    try {
      mailbox = await NfcSt25.getMailBoxInfo();
      //showSnackBar("SUCCESSFUL RESET MAILBOX", false);
      log("GET MAILBOX INFO :\n" + mailbox.toString());
      setState(() {
        mailBoxInfo = mailbox;
      });
    } catch (e) {
      setState(() {
        mailBoxInfo = null;
      });
      log("failed get mailbox info ->" + e.toString());
      //showSnackBar("failed to reset mailbox -> " + e.toString(), true);
    }
  }

  Future<bool> writeMailBoxMsg(List<int> data) async {
    Uint8List msg = Uint8List.fromList(data);
    try {
      await NfcSt25.writeMailBoxByte(msg);
      log("SUCCESSFUL SENT " + msg.toString());
      return true;
    } catch (e) {
      log("failed to write mailbox -> " + e.toString());
      return false;
    }
  }

  Future<void> writeAndRead(List<int> data) async {
    bool success = await writeMailBoxMsg(data);
    if (success) {
      await readMailBoxMsg();
    }
  }

  showSnackBar(String text, bool error) {
    final snackBar = SnackBar(
      content: Text(text),
      backgroundColor: error ? Colors.red : null,
      action: SnackBarAction(
        label: 'Ok',
        onPressed: () {
          // Some code to undo the change.
        },
      ),
    );

    _scaffoldKey.currentState.showSnackBar(snackBar);
  }

  Widget _tapCard() {
    return Container(
      padding: EdgeInsets.all(16),
      child: nfcAvailability
          ? Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Expanded(
                      child: Card(
                          child: Container(
                              height: 300,
                              padding: EdgeInsets.all(8),
                              child: Stack(children: [
                                Positioned(
                                    top: 0,
                                    left: 0,
                                    child: Text(
                                      "Please tap a tag !",
                                      style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold),
                                    )),
                                Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Icon(
                                      Icons.nfc,
                                      size: 128,
                                      color: Colors.black38,
                                    ))
                              ]))))
                ])
          : Text("Nfc unavailable."),
    );
  }

  Widget _myAppBar() {
    if (lastTag == null)
      return AppBar(
        title: const Text('ST25 nfc plugin example'),
      );

    return AppBar(
      title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lastTag.name),
            Text(lastTag.uid,
                style: TextStyle(color: Colors.white, fontSize: 14.0))
          ]),
      actions: [
        IconButton(icon: Icon(Icons.cancel), onPressed: () => invalidateAll())
      ],
    );
  }

  invalidateAll() {
    log("INVALIDATE DATA");
    setState(() {
      lastTag = null;
      logs = [];
      mailBoxInfo = null;
    });
  }

  void showWriteDialog(bool read) {
    // flutter defined function
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: new Text("Select command to send"),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              children: commands
                  .map((e) => RaisedButton(
                        onPressed: () {
                          //writeMailBoxMsg(e);
                          read ? writeAndRead(e) : writeMailBoxMsg(e);
                          Navigator.of(context).pop();
                        },
                        child: Text(e.toString()),
                      ))
                  .toList()),
          actions: <Widget>[
            // usually buttons at the bottom of the dialog
            new FlatButton(
              child: new Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        key: _scaffoldKey,
        appBar: _myAppBar(),
        body: lastTag == null
            ? _tapCard()
            : Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 200,
                      padding: EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text("Description: " + lastTag.description),
                          Text("Memory size: " + lastTag.memorySize.toString()),
                          SizedBox(height: 25),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                RaisedButton(
                                    child: Text("Write and read"),
                                    onPressed: () => showWriteDialog(
                                        true) //writeMailBoxMsg(),
                                    ),
                                RaisedButton(
                                    child: Text("Read"),
                                    onPressed: () => readMailBoxMsg()),
                                RaisedButton(
                                    child: Text("Write"),
                                    onPressed: () => showWriteDialog(
                                        false) //writeMailBoxMsg(),
                                    ),
                              ]),
                        ],
                      ),
                    ),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                              color: Colors.blue,
                              child: ListTile(
                                title: Text(
                                  "MILBOX INFO",
                                  style: TextStyle(color: Colors.white),
                                ),
                                trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.arrow_downward,
                                          color: Colors.white,
                                        ),
                                        onPressed: () => getMailBoxInfo(),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.restore,
                                          color: Colors.white,
                                        ),
                                        onPressed: () => resetMailBox(),
                                      ),
                                    ]),
                              )),
                          Container(
                            padding: EdgeInsets.all(8),
                            child: Text(mailBoxInfo.toString()),
                            color: Colors.black12,
                          ),
                        ]),
                    Container(
                        color: Colors.blue,
                        child: ListTile(
                          //leading: Icon(Icons.code),
                          title: Text(
                            "Logs",
                            style: TextStyle(color: Colors.white),
                          ),
                          trailing: IconButton(
                            onPressed: () => clearLogs(),
                            icon: Icon(
                              Icons.clear,
                              color: Colors.white,
                            ),
                          ),
                        )),
                    Expanded(
                        child: Container(
                      color: Colors.black12,
                      child: new ListView.builder(
                        itemCount: logs.length,
                        controller: _scrollController,
                        itemBuilder: (BuildContext ctxt, int index) {
                          return Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [Text(logs[index]), Divider()]));
                        },
                      ),
                    ))
                  ],
                ),
              ),
      ),
    );
  }
}
