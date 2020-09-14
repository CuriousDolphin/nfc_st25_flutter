import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';

import 'package:nfc_st25/utils/nfc_st25_tag.dart';

import 'utils/nfc_st25_tag.dart';

class NfcSt25 {
  static const MethodChannel _channel = const MethodChannel('nfc_st25');

  static const EventChannel _eventChannel = const EventChannel("nfc_st25/tags");

  static Stream<dynamic> _tagStream;

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<bool> get nfcAvailability async {
    final bool availability =
        await _channel.invokeMethod('checkNfcAvailability');
    return availability;
  }

  static Future<Uint8List> get readMailbox async {
    final Uint8List msg = await _channel.invokeMethod('readMailbox');
    return msg;
  }

  static Future<String> resetMailBox() async {
    final String ris = await _channel.invokeMethod('resetMailbox');
    return ris;
  }

  static Future<MailBox> getMailBoxInfo() async {
    Map<dynamic, dynamic> map = await _channel.invokeMethod('getMailboxInfo');
    return MailBox.fromMap(map);
  }

  static Future<String> writeMailBoxByte(Uint8List msg) async {
    final String ris = await _channel.invokeMethod('writeMailbox', msg);
    return ris;
  }

  static void _createTagStream() {
    _tagStream = _eventChannel
        .receiveBroadcastStream()
        .map<St25Tag>((event) => St25Tag.fromMap(event));
  }

  static Stream<St25Tag> startReading() {
    if (_tagStream == null) {
      _createTagStream();
    }
    // Create a StreamController to wrap the tag stream. Any errors will be
    // converted to their matching exception classes. The controller stream will
    // be closed if the errors are fatal.
    StreamController<St25Tag> controller = StreamController();
    final stream = _tagStream;
    // Listen for tag reads.
    final subscription = stream.listen(
      (tag) => controller.add(tag),
      onError: (error) {
        /* error = _mapException(error);
        if (!throwOnUserCancel && error is NFCUserCanceledSessionException) {
          return;
        }*/
        controller.addError(error);

        //controller.close();
      },
      onDone: () {
        _tagStream = null;
        return controller.close();
      },
      // cancelOnError: false
      // cancelOnError cannot be used as the stream would cancel BEFORE the error
      // was sent to the controller stream
    );

    controller.onCancel = () {
      subscription.cancel();
    };

    try {
      _channel.invokeMethod("startReading");
    } catch (error) {
      print("error on reading " + error.toString());
      throw error;
    }
    return controller.stream;
  }
}
