import 'package:famedlysdk/famedlysdk.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:flutter/widgets.dart';

import 'date_time_extension.dart';

extension RoomStatusExtension on Room {
  Presence get directChatPresence => client.presences[directChatMatrixID];

  String getLocalizedStatus(BuildContext context) {
    if (isDirectChat) {
      if (directChatPresence != null) {
        if (directChatPresence.currentlyActive == true) {
          return 'Jetzt gerade aktiv';
        }
        return 'Zuletzt gesehen: ${directChatPresence.time.localizedTimeShort(context)}';
      }
      return 'Zuletzt gesehen vor sehr langer Zeit';
    }
    return '$mJoinedMemberCount Mitglieder';
  }
}
