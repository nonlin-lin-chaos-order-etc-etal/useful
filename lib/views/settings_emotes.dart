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
  @override
  Widget build(BuildContext context) {
    return AdaptivePageLayout(
      primaryPage: FocusPage.SECOND,
      firstScaffold: ChatList(),
      secondScaffold: EmotesSettings(),
    );
  }
}

class EmotesSettings extends StatefulWidget {
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
    final client = Matrix.of(context).client;
    // be sure to preserve any data not in "short"
    final content = client.accountData['im.ponies.user_emotes']?.content ?? <String, dynamic>{};
    content['short'] = <String, String>{};
    for (final emote in emotes) {
      content['short'][emote.emote] = emote.mxc;
    }
    await SimpleDialogs(context).tryRequestWithLoadingDialog(
      client.jsonRequest(
        type: HTTPType.PUT,
        action: '/client/r0/user/${client.userID}/account_data/im.ponies.user_emotes',
        data: content,
      ),
    );
  }

  void dialog(BuildContext context, String text) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(text),
        actions: <Widget>[
          FlatButton(
            child: Text(
              L10n.of(context).confirm.toUpperCase(),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Client client = Matrix.of(context).client;
    if (emotes == null) {
      emotes = <_EmoteEntry>[];
      final userEmotes = client.accountData['im.ponies.user_emotes'];
      if (userEmotes != null && userEmotes.content['short'] is Map) {
        userEmotes.content['short'].forEach((key, value) {
          if (key is String && value is String && value.startsWith('mxc://')) {
            emotes.add(_EmoteEntry(emote: key, mxc: value));
          }
        });
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Emote Settings'),
      ),
      floatingActionButton: showSave ? FloatingActionButton(
        child: Icon(Icons.save),
        onPressed: () async {
          await _save(context);
          setState(() {
            showSave = false;
          });
        },
      ) : null,
      body: Column(
        children: <Widget>[
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
                    hintText: 'Emote Shortcode',
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
                onTap: () => () async {
                  if (newEmoteController.text == null || newEmoteController.text.isEmpty || newMxcController.text == null || newMxcController.text.isEmpty) {
                    dialog(context, 'You need to pick an emote shortcode and an image!');
                    return;
                  }
                  final emoteCode = ':${newEmoteController.text}:';
                  final mxc = newMxcController.text;
                  if (emotes.indexWhere((e) => e.emote == emoteCode && e.mxc != mxc) != -1) {
                    dialog(context, 'Emote already exists!');
                    return;
                  }
                  await _save();
                  setState(() {
                    emotes.add(_EmoteEntry(emote: emoteCode, mxc: mxc));
                    newEmoteController.text = '';
                    newMxcController.text = '';
                    showSave = false;
                  });
                },
              ),
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(width: 1.0, color: Colors.black)),
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
                    child: TextField(
                      controller: controller,
                      autocorrect: false,
                      minLines: 1,
                      maxLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Emote Shortcode',
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
                          dialog(context, 'Emote already exists!');
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
                  trailing: InkWell(
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
  TextEditingController controller;

  _EmoteImagePicker(this.controller);

  @override
  _EmoteImagePickerState createState() => _EmoteImagePickerState();
}

class _EmoteImagePickerState extends State<_EmoteImagePicker> {
  @override
  Widget build(BuildContext context) {
    if (widget.controller.text == null || widget.controller.text.isEmpty) {
      return FlatButton(
        child: Text('Pick Image'),
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
