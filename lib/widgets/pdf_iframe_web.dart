import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

class SimtasPdfWebView extends StatefulWidget {
  final String url;
  const SimtasPdfWebView({super.key, required this.url});

  @override
  State<SimtasPdfWebView> createState() => _SimtasPdfWebViewState();
}

class _SimtasPdfWebViewState extends State<SimtasPdfWebView> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'simtas-pdf-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      iframe.setAttribute('title', 'Preview PDF SIMTAS');
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
