import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_advanced_networkimage/provider.dart';
import 'package:famedlysdk/famedlysdk.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';

import 'chat_list.dart';
import '../components/adaptive_page_layout.dart';
import '../components/matrix.dart';
import '../components/dialogs/simple_dialogs.dart';
import '../l10n/l10n.dart';

class EmotesSettingsView extends StatelessWidget {
  final Room room;
  final bool readonly;

  EmotesSettingsView({this.room, this.readonly});

  @override
  Widget build(BuildContext context) {
    return AdaptivePageLayout(
      primaryPage: FocusPage.SECOND,
      firstScaffold: ChatList(),
      secondScaffold: EmotesSettings(room: room, readonly: readonly),
    );
  }
}

class EmotesSettings extends StatefulWidget {
  final Room room;
  final bool readonly;

  EmotesSettings({this.room, this.readonly});

  @override
  _EmotesSettingsState createState() => _EmotesSettingsState();
}

class _EmoteEntry {
  String emote;
  String mxc;
  _EmoteEntry({this.emote, this.mxc});

  String get emoteClean => emote.substring(1, emote.length - 1);
}

class _EmotesSettingsState extends State<EmotesSettings> {
  List<_EmoteEntry> emotes;
  bool showSave = false;
  TextEditingController newEmoteController = TextEditingController();
  TextEditingController newMxcController = TextEditingController();

  Future<void> _save(BuildContext context) async {
    if (widget.readonly) {
      return;
    }
    debugPrint("Saving....");
    final client = Matrix.of(context).client;
    // be sure to preserve any data not in "short"
    Map<String, dynamic> content;
    if (widget.room != null) {
      content = widget.room.getState('im.ponies.room_emotes')?.content ?? <String, dynamic>{};
    } else {
      content = client.accountData['im.ponies.user_emotes']?.content ?? <String, dynamic>{};
    }
    debugPrint(content.toString());
    content['short'] = <String, String>{};
    for (final emote in emotes) {
      content['short'][emote.emote] = emote.mxc;
    }
    debugPrint(content.toString());
    var path = '';
    if (widget.room != null) {
      path = '/client/r0/rooms/${widget.room.id}/state/im.ponies.room_emotes/';
    } else {
      path = '/client/r0/user/${client.userID}/account_data/im.ponies.user_emotes';
    }
    debugPrint(path);
    await SimpleDialogs(context).tryRequestWithLoadingDialog(
      client.jsonRequest(
        type: HTTPType.PUT,
        action: path,
        data: content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Client client = Matrix.of(context).client;
    if (emotes == null) {
      emotes = <_EmoteEntry>[];
      Map<String, dynamic> emoteSource;
      if (widget.room != null) {
        emoteSource = widget.room.getState('im.ponies.room_emotes')?.content;
      } else {
        emoteSource = client.accountData['im.ponies.user_emotes']?.content;
      }
      if (emoteSource != null && emoteSource['short'] is Map) {
        emoteSource['short'].forEach((key, value) {
          if (key is String && value is String && value.startsWith('mxc://')) {
            emotes.add(_EmoteEntry(emote: key, mxc: value));
          }
        });
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).emoteSettings),
      ),
      floatingActionButton: showSave ? FloatingActionButton(
        child: Icon(Icons.save, color: Theme.of(context).primaryColor),
        onPressed: () async {
          await _save(context);
          setState(() {
            showSave = false;
          });
        },
        backgroundColor: Theme.of(context).textTheme.bodyText2.color,
        foregroundColor: Theme.of(context).scaffoldBackgroundColor,
      ) : null,
      body: Column(
        children: <Widget>[
          if (!widget.readonly)
            Container(
              child: ListTile(
                leading: Container(
                  width: 180.0,
                  child: TextField(
                    controller: newEmoteController,
                    autocorrect: false,
                    minLines: 1,
                    maxLines: 1,
                    decoration: InputDecoration(
                      hintText: L10n.of(context).emoteShortcode,
                      prefixText: ':',
                      suffixText: ':',
                      prefixStyle: TextStyle(color: Theme.of(context).primaryColor),
                      suffixStyle: TextStyle(color: Theme.of(context).primaryColor),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                title: _EmoteImagePicker(newMxcController),
                trailing: InkWell(
                  child: Icon(
                    Icons.add,
                    color: Colors.green,
                    size: 32.0,
                  ),
                  onTap: () async {
                    debugPrint("blah");
                    if (newEmoteController.text == null || newEmoteController.text.isEmpty || newMxcController.text == null || newMxcController.text.isEmpty) {
                      await SimpleDialogs(context).inform(contentText: L10n.of(context).emoteWarnNeedToPick);
                      return;
                    }
                    final emoteCode = ':${newEmoteController.text}:';
                    final mxc = newMxcController.text;
                    if (emotes.indexWhere((e) => e.emote == emoteCode && e.mxc != mxc) != -1) {
                      await SimpleDialogs(context).inform(contentText: L10n.of(context).emoteExists);
                      return;
                    }
                    if (!RegExp(r'^:[-\w]+:$').hasMatch(emoteCode)) {
                      await SimpleDialogs(context).inform(contentText: L10n.of(context).emoteInvalid);
                      return;
                    }
                    emotes.add(_EmoteEntry(emote: emoteCode, mxc: mxc));
                    await _save(context);
                    setState(() {
                      newEmoteController.text = '';
                      newMxcController.text = '';
                      showSave = false;
                    });
                  },
                ),
              ),
              padding: EdgeInsets.only(
                bottom: 8.0,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(width: 2.0, color: Theme.of(context).primaryColor)),
              ),
            ),
          Expanded(
            child: ListView.separated(
              separatorBuilder: (BuildContext context, int i) => Container(),
              itemCount: emotes.length + 1,
              itemBuilder: (BuildContext context, int i) {
                if (i >= emotes.length) {
                  return Container(height: 70);
                }
                final emote = emotes[i];
                final controller = TextEditingController();
                controller.text = emote.emoteClean;
                return ListTile(
                  leading: Container(
                    width: 180.0,
                    child: widget.readonly ?
                        Text(emote.emote)
                      : TextField(
                        controller: controller,
                        autocorrect: false,
                        minLines: 1,
                        maxLines: 1,
                        decoration: InputDecoration(
                          hintText: L10n.of(context).emoteShortcode,
                          prefixText: ':',
                          suffixText: ':',
                          prefixStyle: TextStyle(color: Theme.of(context).primaryColor),
                          suffixStyle: TextStyle(color: Theme.of(context).primaryColor),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (s) {
                          final emoteCode = ':${s}:';
                          if (emotes.indexWhere((e) => e.emote == emoteCode && e.mxc != emote.mxc) != -1) {
                            controller.text = emote.emoteClean;
                            SimpleDialogs(context).inform(contentText: L10n.of(context).emoteExists);
                            return;
                          }
                          if (!RegExp(r'^:[-\w]+:$').hasMatch(emoteCode)) {
                            controller.text = emote.emoteClean;
                            SimpleDialogs(context).inform(contentText: L10n.of(context).emoteInvalid);
                            return;
                          }
                          setState(() {
                            emote.emote = emoteCode;
                            showSave = true;
                          });
                        },
                      ),
                  ),
                  title: _EmoteImage(emote.mxc),
                  trailing: widget.readonly ? null : InkWell(
                    child: Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                      size: 32.0,
                    ),
                    onTap: () => setState(() {
                      emotes.removeWhere((e) => e.emote == emote.emote);
                      showSave = true;
                    }),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmoteImage extends StatelessWidget {
  final String mxc;
  _EmoteImage(this.mxc);

  @override
  Widget build(BuildContext context) {
    final size = 64.0;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final url = Uri.parse(mxc)?.getThumbnail(
      Matrix.of(context).client,
      width: size * devicePixelRatio,
      height: size * devicePixelRatio,
      method: ThumbnailMethod.scale,
    );
    return Image(
      image: AdvancedNetworkImage(
        url,
        useDiskCache: !kIsWeb,
      ),
      width: size,
      height: size,
    );
  }
}

class _EmoteImagePicker extends StatefulWidget {
  final TextEditingController controller;

  _EmoteImagePicker(this.controller);

  @override
  _EmoteImagePickerState createState() => _EmoteImagePickerState();
}

class _EmoteImagePickerState extends State<_EmoteImagePicker> {
  @override
  Widget build(BuildContext context) {
    if (widget.controller.text == null || widget.controller.text.isEmpty) {
      return FlatButton(
        child: Text(L10n.of(context).pickImage),
        onPressed: () async {
          if (kIsWeb) {
            showToast(L10n.of(context).notSupportedInWeb);
            return;
          }
          File file = await ImagePicker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 50,
              maxWidth: 600,
              maxHeight: 600);
          if (file == null) return;
          final uploadResp = await SimpleDialogs(context).tryRequestWithLoadingDialog(
            Matrix.of(context).client.upload(
              MatrixFile(bytes: await file.readAsBytes(), path: file.path),
            ),
          );
          setState(() {
            widget.controller.text = uploadResp;
          });
        },
      );
    } else {
      return _EmoteImage(widget.controller.text);
    }
  }
}
