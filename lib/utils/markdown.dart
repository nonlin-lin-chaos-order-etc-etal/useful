import 'package:markdown/markdown.dart';
import 'dart:convert';

bool isRightFlanking(InlineParser parser, int runStart, int runEnd) {
  final String whitespace = ' \t\r\n';
  bool rightFlanking = false;
}

class LinebreakSyntax extends InlineSyntax {
  LinebreakSyntax() : super(r"\n");

  @override
  bool onMatch(InlineParser parser, Match match) {
    parser.addNode(Element.empty("br"));
    return true;
  }
}

class SpoilerSyntax extends TagSyntax {
  Map<String, String> reasonMap = Map();
  SpoilerSyntax() : super(
    r"\|\|(?:([^\|]+)\|(?!\|))?",
    requiresDelimiterRun: true,
    end: r"\|\|",
  );

  @override
  bool onMatch(InlineParser parser, Match match) {
    if (super.onMatch(parser, match)) {
      reasonMap[match.input] = match[1];
      return true;
    }
    return false;
  }

  @override
  bool onMatchEnd(InlineParser parser, Match match, TagState state) {
    final element = Element('span', state.children);
    element.attributes["data-mx-spoiler"] = htmlEscape.convert(reasonMap[match.input] ?? "");
    parser.addNode(element);
    return true;
  }
}


String markdown(String text) {
  String ret;
  try {
    ret = markdownToHtml(text,
      extensionSet: ExtensionSet.commonMark,
      inlineSyntaxes: [StrikethroughSyntax(), LinebreakSyntax(), SpoilerSyntax()],
    );
  } catch (err, stacktrace) {
    print(stacktrace.toString());
    throw err;
  }
    
  bool stripPTags = "<p>".allMatches(ret).length <= 1;
  if (stripPTags) {
    final otherBlockTags = ["table", "pre", "ol", "ul", "h1", "h2", "h3", "h4", "h5", "h6", "blockquote"];
    for (final tag in otherBlockTags) {
      if (ret.contains("</${tag}>")) {
        stripPTags = false;
        break;
      }
    }
  }
  if (stripPTags) {
    ret = ret.replaceAll("<p>", "").replaceAll("</p>", "");
  }
  return ret.trim().replaceAll(new RegExp(r"(<br />)+$"), "");
}
