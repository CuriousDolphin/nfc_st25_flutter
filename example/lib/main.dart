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

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  bool nfcAvailability;
  St25Tag lastTag;
  bool loading = false;
  Uint8List last_msg = null;
  String logs = "";
  MailBox mailBoxInfo = null;

  // needed for snackbar
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    initPlatformState();
    NfcSt25.nfcAvailability.then((value) => {nfcAvailability = value});
    try {
      StreamSubscription<St25Tag> subscription =
          NfcSt25.startReading().listen((tag) {
        print("NEW TAG FOUND: " + tag.uid);
        log("TAG FOUND: " + tag.uid);
        //showSnackBar("Tag found " + tag.uid, false);
        setState(() {
          lastTag = tag;
          mailBoxInfo = tag.mailBox;
        });
      });

      subscription.onError((e) => print("ERROR ON DISCOVERY " + e.toString()));
    } catch (e) {
      print("ERRRRORRR" + e.toString());
    }
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
    setState(() {
      logs += s + '\n';
    });
  }

  Future<void> readMailBoxMsg() async {
    setState(() {
      loading = true;
    });

    Uint8List msg;
    try {
      msg = await NfcSt25.readMailbox;
      last_msg = msg;
      print("READ MSG " + msg.length.toString() + "_" + msg.toString());
      // showSnackBar( "READ MSG " + msg.length.toString() + "_" + msg.toString(), false);
      log("READ MSG " + msg.length.toString() + "_" + msg.toString());
    } catch (e) {
      print("ERRRRORRR reading msg" + e.toString());
      //showSnackBar("failed to read mailbox -> " + e.toString(), true);
      log("failed to read mailbox -> " + e.toString());
      setState(() {
        last_msg = null;
      });
    }

    setState(() {
      loading = false;
      last_msg = msg;
    });
  }

  Future<void> resetMailBox() async {
    try {
      await NfcSt25.resetMailBox();
      print("SUCCESSFUL RESET MAILBOX");
      //showSnackBar("SUCCESSFUL RESET MAILBOX", false);
      log("SUCCESSFUL RESET MAILBOX");
    } catch (e) {
      log("ERRRRORRR reset mailbox" + e.toString());
      print("ERRRRORRR reset mailbox" + e.toString());
      //showSnackBar("failed to reset mailbox -> " + e.toString(), true);
    }
  }

  Future<void> getMailBoxInfo() async {
    MailBox mailbox;
    try {
      mailbox = await NfcSt25.getMailBoxInfo();
      print("GET MAILBOX INFO" + mailbox.toString());
      //showSnackBar("SUCCESSFUL RESET MAILBOX", false);
      log("GET MAILBOX INFO :\n" + mailbox.toString());
      setState(() {
        mailBoxInfo = mailbox;
      });
    } catch (e) {
      setState(() {
        mailBoxInfo = null;
      });
      log("ERRRRORRR get mailbox info" + e.toString());
      print("ERRRRORRR get mailbox info" + e.toString());
      //showSnackBar("failed to reset mailbox -> " + e.toString(), true);
    }
  }

  Future<void> writeMailBoxMsg() async {
    Uint8List msg = Uint8List.fromList([0, 1, 0]);
    try {
      await NfcSt25.writeMailBoxByte(msg);
      print("SUCCESSFUL SENT " + msg.toString());
      log("SUCCESSFUL SENT " + msg.toString());
    } catch (e) {
      print("ERRRRORRR writing msg" + e.toString());
      log("failed to write mailbox -> " + e.toString());
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('ST25 nfc plugin example'),
      ),
      body: lastTag == null
          ? Center(
              child: Text(
                  'Running on: $_platformVersion\n Nfc availability: $nfcAvailability \n PLEASE TAP A NFC TAG. '),
            )
          : Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(lastTag.name + ' ' + lastTag.uid),
                    SizedBox(height: 25),
                    Text("MAILBOX INFO"),
                    Container(
                      child: Text(mailBoxInfo.toString()),
                      color: Colors.grey,
                    ),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RaisedButton(
                            child: Text("MAILBOX INFO"),
                            onPressed: () => getMailBoxInfo(),
                          ),
                          RaisedButton(
                            child: Text("RESET MAILBOX"),
                            onPressed: () => resetMailBox(),
                          ),
                        ]),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RaisedButton(
                            child: Text("READ MAILBOX"),
                            onPressed: () =>
                                lastTag.mailBox.mailboxEnabled == false
                                    ? null
                                    : readMailBoxMsg(),
                          ),
                          RaisedButton(
                            child: Text("WRITE MAILBOX"),
                            onPressed: () =>
                                lastTag.mailBox.mailboxEnabled == false
                                    ? null
                                    : writeMailBoxMsg(),
                          ),
                        ]),
                    SizedBox(height: 25),
                    Text("LOGS"),
                    Container(
                      height: 300,
                      child: ListView(
                        children: <Widget>[Text(logs)],
                      ),
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
    ));
  }
}
