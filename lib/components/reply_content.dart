import 'package:famedlysdk/famedlysdk.dart';
import 'package:fluffychat/i18n/i18n.dart';
import 'package:flutter/material.dart';

import 'html_message.dart';

class ReplyContent extends StatelessWidget {
  final Event replyEvent;
  final bool lightText;

  const ReplyContent(this.replyEvent, {this.lightText = false, Key key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget replyBody;
    if (
      [EventTypes.Message, EventTypes.Encrypted].contains(replyEvent.type) &&
      [MessageTypes.Text, MessageTypes.Notice, MessageTypes.Emote].contains(replyEvent.messageType) &&
      !replyEvent.redacted && replyEvent.content['format'] == 'org.matrix.custom.html' && replyEvent.content['formatted_body'] is String
    ) {
      String html = replyEvent.content['formatted_body'];
      if (replyEvent.messageType == MessageTypes.Emote) {
        html = "* $html";
      }
      replyBody = ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: 18,
        ),
        child: HtmlMessage(
          html: html,
          textColor: lightText
              ? Colors.white
              : Theme.of(context).textTheme.bodyText2.color,
        ),
      );
    } else {
      replyBody = Text(
        replyEvent?.getLocalizedBody(
              I18n.of(context),
              withSenderNamePrefix: false,
              hideReply: true,
            ) ??
            "",
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(
            color: lightText
                ? Colors.white
                : Theme.of(context).textTheme.bodyText2.color),
      );
    }
    return Row(
      children: <Widget>[
        Container(
          width: 3,
          height: 36,
          color: lightText ? Colors.white : Theme.of(context).primaryColor,
        ),
        SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                (replyEvent?.sender?.calcDisplayname() ?? "") + ":",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      lightText ? Colors.white : Theme.of(context).primaryColor,
                ),
              ),
              replyBody,
            ],
          ),
        ),
      ],
    );
  }
}
