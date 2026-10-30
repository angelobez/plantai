import 'package:flutter/material.dart';

/// How far the white panel goes over the photo, and its corner radius.
const _panelOverlap = 26.0;

/// The scrolling layout of the Tela da espécie and the Tela da planta
/// (`M-especie`, `M-planta`): [photo] on top, [photoHeight] tall, and a white
/// panel with rounded top corners over its bottom edge holding [children].
class PhotoPanelScroll extends StatelessWidget {
  const PhotoPanelScroll({
    super.key,
    required this.photo,
    required this.photoHeight,
    required this.children,
  });

  final Widget photo;
  final double photoHeight;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: photoHeight,
            child: ColoredBox(color: const Color(0xFF7FA886), child: photo),
          ),
          Transform.translate(
            offset: const Offset(0, -_panelOverlap),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(_panelOverlap),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A screen body under a [RoundBackButton]-style overlay: [body] fills the
/// screen and [overlay] sits at its top-left corner, inside the safe area.
class TopLeftOverlay extends StatelessWidget {
  const TopLeftOverlay({super.key, required this.body, required this.overlay});

  final Widget body;
  final Widget overlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        body,
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: Padding(padding: const EdgeInsets.all(14), child: overlay),
          ),
        ),
      ],
    );
  }
}
