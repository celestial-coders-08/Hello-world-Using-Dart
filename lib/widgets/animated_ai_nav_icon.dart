import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AnimatedAiNavIcon extends StatefulWidget {
  const AnimatedAiNavIcon({super.key});

  @override
  State<AnimatedAiNavIcon> createState() => _AnimatedAiNavIconState();
}

class _AnimatedAiNavIconState extends State<AnimatedAiNavIcon> {
  late final Future<WebViewController> _controller = _createController();

  Future<WebViewController> _createController() async {
    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.disabled);
    await controller.setBackgroundColor(Colors.transparent);
    await controller.loadFlutterAsset('animated_svg.html');
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: FutureBuilder<WebViewController>(
        future: _controller,
        builder: (context, snapshot) {
          final controller = snapshot.data;
          if (controller == null) {
            return const Icon(Icons.auto_awesome);
          }
          return IgnorePointer(child: WebViewWidget(controller: controller));
        },
      ),
    );
  }
}
