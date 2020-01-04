import 'package:bubble/bubble.dart';
import 'package:famedlysdk/famedlysdk.dart';
import 'package:fluffychat/components/dialogs/redact_message_dialog.dart';
import 'package:fluffychat/components/message_content.dart';
import 'package:fluffychat/utils/chat_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../avatar.dart';
import '../matrix.dart';
import 'state_message.dart';

class Message extends StatelessWidget {
  final Event event;

  const Message(this.event);

  @override
  Widget build(BuildContext context) {
    if (event.typeKey != "m.room.message") return StateMessage(event);

    Client client = Matrix.of(context).client;
    final bool ownMessage = event.senderId == client.userID;
    Alignment alignment = ownMessage ? Alignment.topRight : Alignment.topLeft;
    Color color = Theme.of(context).secondaryHeaderColor;
    BubbleNip nip = ownMessage ? BubbleNip.rightBottom : BubbleNip.leftBottom;
    final Color textColor = ownMessage ? Colors.white : Colors.black;
    MainAxisAlignment rowMainAxisAlignment =
        ownMessage ? MainAxisAlignment.end : MainAxisAlignment.start;

    if (ownMessage) {
      color = event.status == -1
          ? Colors.redAccent
          : Theme.of(context).primaryColor;
    }
    List<PopupMenuEntry<String>> popupMenuList = [];
    if (!event.redacted && (event.type == EventTypes.Text || event.type == EventTypes.Reply)) {
      popupMenuList.add(
        const PopupMenuItem<String>(
          value: "copy",
          child: Text('Copy message'),
        ),
      );
    }
    if (event.canRedact && !event.redacted && event.status > 1) {
      popupMenuList.add(
        const PopupMenuItem<String>(
          value: "remove",
          child: Text('Remove message'),
        ),
      );
    }
    if (ownMessage && event.status == -1) {
      popupMenuList.add(
        const PopupMenuItem<String>(
          value: "resend",
          child: Text('Send again'),
        ),
      );
      popupMenuList.add(
        const PopupMenuItem<String>(
          value: "delete",
          child: Text('Delete message'),
        ),
      );
    }

    var _tapPosition;

    void _storePosition(TapDownDetails details) {
      _tapPosition = details.globalPosition;
    }

    void _showPopupMenu() {
      final RenderBox overlay = Overlay.of(context).context.findRenderObject();
      showMenu(
        context: context,
        position: RelativeRect.fromRect(
            _tapPosition & Size(40, 40), // smaller rect, the touch area
            Offset.zero & overlay.size // Bigger rect, the entire screen
            ),
        items: popupMenuList,
        //elevation: 8.0,
      ).then<void>((String choice) async {
        // choice would be null if user taps on outside the popup menu
        // (causing it to close without making selection)
        if (choice == null) return;

        switch (choice) {
          case "remove":
            await showDialog(
              context: context,
              builder: (BuildContext context) => RedactMessageDialog(event),
            );
            break;
          case "resend":
            await event.sendAgain();
            break;
          case "delete":
            await event.remove();
            break;
          case "copy":
            await Clipboard.setData(ClipboardData(text: event.text));
            Scaffold.of(context).showSnackBar(SnackBar(
              content: Text("Copied to Clipboard"),
            ));

            break;
        }
      });
    }

    List<Widget> rowChildren = [
      Expanded(
        child: GestureDetector(
          // This does not give the tap position ...
          onTap: _showPopupMenu,

          // Have to remember it on tap-down.
          onTapDown: _storePosition,
          child: Opacity(
            opacity: event.status == 0 ? 0.5 : 1,
            child: Bubble(
              elevation: 0,
              alignment: alignment,
              margin: BubbleEdges.symmetric(horizontal: 4),
              color: color,
              nip: nip,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        ownMessage ? "You" : event.sender.calcDisplayname(),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        ChatTime(event.time).toEventTimeString(),
                        style: TextStyle(color: textColor, fontSize: 12),
                      ),
                    ],
                  ),
                  MessageContent(
                    event,
                    textColor: textColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
    if (ownMessage) {
      rowChildren.add(Avatar(event.sender.avatarUrl));
    } else {
      rowChildren.insert(0, Avatar(event.sender.avatarUrl));
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: rowMainAxisAlignment,
        children: rowChildren,
      ),
    );
  }
}
