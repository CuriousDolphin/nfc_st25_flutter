// To parse this JSON data, do
//
//     final st25Tag = st25TagFromMap(jsonString);

import 'dart:convert';

class St25Tag {
  St25Tag({
    this.name,
    this.description,
    this.uid,
    this.memorySize,
    this.mailBox,
  });

  String name;
  String description;
  String uid;
  int memorySize;
  MailBox mailBox;

  factory St25Tag.fromJson(String str) => St25Tag.fromMap(json.decode(str));

  String toJson() => json.encode(toMap());

  factory St25Tag.fromMap(Map<dynamic, dynamic> json) => St25Tag(
        name: json["name"] == null ? null : json["name"],
        description: json["description"] == null ? null : json["description"],
        uid: json["uid"] == null ? null : json["uid"],
        memorySize: json["memory_size"] == null ? null : json["memory_size"],
        mailBox:
            json["mail_box"] == null ? null : MailBox.fromMap(json["mail_box"]),
      );

  Map<String, dynamic> toMap() => {
        "name": name == null ? null : name,
        "description": description == null ? null : description,
        "uid": uid == null ? null : uid,
        "memory_size": memorySize == null ? null : memorySize,
        "mail_box": mailBox == null ? null : mailBox.toMap(),
      };
}

class MailBox {
  MailBox({
    this.mailboxEnabled,
    this.msgPutByController,
    this.msgPutByNfc,
    this.msgMissByController,
    this.msgMissByNfc,
  });

  bool mailboxEnabled;
  bool msgPutByController;
  bool msgPutByNfc;
  bool msgMissByController;
  bool msgMissByNfc;

  @override
  String toString() {
    return " mailboxEnabled: $mailboxEnabled\n msgPutByController: $msgPutByController\n msgPutByNfc: $msgPutByNfc\n msgMissByController: $msgMissByController\n msgMissByNfc:$msgMissByNfc \n ";
  }

  factory MailBox.fromJson(String str) => MailBox.fromMap(json.decode(str));

  String toJson() => json.encode(toMap());

  factory MailBox.fromMap(Map<dynamic, dynamic> json) => MailBox(
        mailboxEnabled:
            json["mailbox_enabled"] == null ? null : json["mailbox_enabled"],
        msgPutByController: json["msg_put_by_controller"] == null
            ? null
            : json["msg_put_by_controller"],
        msgPutByNfc:
            json["msg_put_by_nfc"] == null ? null : json["msg_put_by_nfc"],
        msgMissByController: json["msg_miss_by_controller"] == null
            ? null
            : json["msg_miss_by_controller"],
        msgMissByNfc:
            json["msg_miss_by_nfc"] == null ? null : json["msg_miss_by_nfc"],
      );

  Map<String, dynamic> toMap() => {
        "mailbox_enabled": mailboxEnabled == null ? null : mailboxEnabled,
        "msg_put_by_controller":
            msgPutByController == null ? null : msgPutByController,
        "msg_put_by_nfc": msgPutByNfc == null ? null : msgPutByNfc,
        "msg_miss_by_controller":
            msgMissByController == null ? null : msgMissByController,
        "msg_miss_by_nfc": msgMissByNfc == null ? null : msgMissByNfc,
      };
}
