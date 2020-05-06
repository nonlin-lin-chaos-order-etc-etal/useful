import 'package:famedlysdk/famedlysdk.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:link_text/link_text.dart';
import 'package:html/dom.dart' as dom;
import 'package:flutter_advanced_networkimage/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'matrix.dart';
import 'spoiler.dart';

class HtmlMessage extends StatelessWidget {
  final String html;
  final Color textColor;

  const HtmlMessage({this.html, this.textColor});

  static const _allowedElements = [
    "font", "del", "h1", "h2", "h3", "h4", "h5", "h6", "blockquote",
    "p", "a", "ul", "ol", "sup", "sub", "li", "b", "i", "u", "strong",
    "em", "strike", "code", "hr", "br", "div", "table", "thead", "tbody",
    "tr", "th", "td", "caption", "pre", "span", "img",
  ];

  // copied from https://github.com/Sub6Resources/flutter_html/blob/e03bdaf59dc610a0bb7f267895cd27a672cde373/lib/html_parser.dart#L912
  String trimStringHtml(String stringToTrim) {
    stringToTrim = stringToTrim.replaceAll("\n", "");
    while (stringToTrim.contains("  ")) {
      stringToTrim = stringToTrim.replaceAll("  ", " ");
    }
    return stringToTrim;
  }

  double getDimensions(String dim, [double ratio = 1.0]) {
    if (dim == null) {
      return 800 * ratio;
    }
    try {
      final number = double.parse(dim);
      if (number == null) {
        return 800 * ratio;
      }
      return number * ratio;
    } catch (e) {
      return 800 * ratio;
    }
  }

  @override
  Widget build(BuildContext context) {
    // there is no need to pre-validate the html, as we validate it while rendering
    return Html(
      data: html,
      defaultTextStyle: TextStyle(color: textColor),
      shrinkToFit: true,
      useRichText: false,
      onLinkTap: (String url) {
        if (url == null || url.isEmpty) {
          return;
        }
        launch(url);
      },
      customRender: (node, children) {
        if (node is dom.Element) {
          if (!_allowedElements.contains(node.localName)) {
            // okay, we don't allow the element, so let's just reutrn its children
            return Wrap(children: children);
          }
          switch (node.localName) {
            case "img": 
              if (node.attributes['src'] != null && node.attributes['src'].startsWith("mxc://")) {
                // we have a valid image to render
                final width = node.attributes['width'];
                final height = node.attributes['height'];
                final url = Uri.parse(node.attributes['src'])?.getThumbnail(
                  Matrix.of(context).client,
                  width: getDimensions(width, MediaQuery.of(context).devicePixelRatio),
                  height: getDimensions(height, MediaQuery.of(context).devicePixelRatio),
                  method: ThumbnailMethod.scale,
                );
                return Image(
                  image: AdvancedNetworkImage(
                    url,
                    useDiskCache: !kIsWeb,
                  ),
                  width: width != null ? getDimensions(width) : null,
                  height: height != null ? getDimensions(height) : null,
                  errorBuilder: (c, e, s) => Text(node.attributes['alt']),
                );
              }
              return Text(node.attributes['alt']);
            case "span":
              // we need to hackingly check the outerHtml as the atributes don't contain blank ones, somehow
              if (node.attributes['data-mx-spoiler'] != null || node.outerHtml.split(">")[0].contains("data-mx-spoiler")) {
                return Spoiler(
                  reason: node.attributes['data-mx-spoiler'],
                  content: Wrap(children: children),
                );
              }
              return null;
          }
        } else if (node is dom.Text) {
          //We don't need to worry about rendering extra whitespace
          if (node.text.trim() == "" && !node.text.contains(" ")) {
            return Wrap();
          }
          if (node.text.trim() == "" && node.text.contains(" ")) {
            node.text = " ";
          }

          String finalText = trimStringHtml(node.text);
          //Temp fix for https://github.com/flutter/flutter/issues/736
          if (finalText.endsWith(" ")) {
            return Container(
                padding: EdgeInsets.only(right: 2.0), child: LinkText(
                  text: finalText,
                  textStyle: TextStyle(), // hack to inherit the style
                ));
          } else {
            return LinkText(
              text: finalText,
              textStyle: TextStyle(), // hack to inherit the style
            );
          }
        }
        return null;
      },
    );
  }
}
