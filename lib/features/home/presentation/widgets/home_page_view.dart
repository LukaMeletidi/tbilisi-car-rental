import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/features/home/presentation/home_layout.dart';

/// The key of dot [index] of the page view [name], for tests.
ValueKey<String> homePageDotKey(String name, int index) =>
    ValueKey('home-$name-dot-$index');

/// Pages swiped sideways, with a row of dots below them: the dot of the
/// shown page is filled, and a tap on a dot opens its page. Used by every
/// Home block with pages.
///
/// The swipe also works with a mouse drag (for Chrome). The view is as tall
/// as its tallest page at the current width and text size, so no page is
/// cut off; a shorter page is stretched to that height.
///
/// The dots are hidden from screen readers; the pages can be scrolled.
class HomePageView extends StatefulWidget {
  const HomePageView({
    super.key,
    required this.name,
    required this.pages,
    this.pagePadding = const EdgeInsets.symmetric(horizontal: homeGutter),
  });

  /// A short name for the keys of the dots, unique on the page.
  final String name;

  final List<Widget> pages;

  /// Around each page, inside the swiped area.
  final EdgeInsets pagePadding;

  @override
  State<HomePageView> createState() => _HomePageViewState();
}

class _HomePageViewState extends State<HomePageView> {
  final _controller = PageController();
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      for (final page in widget.pages)
        Padding(padding: widget.pagePadding, child: page),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          fit: StackFit.passthrough,
          children: [
            // Invisible copies of all pages: the tallest one gives the
            // height. They take no taps and are not read aloud.
            for (final page in pages)
              Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: page,
              ),
            Positioned.fill(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                  },
                ),
                child: PageView(
                  controller: _controller,
                  onPageChanged: (index) => setState(() => _page = index),
                  children: pages,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: _Dots(
            name: widget.name,
            count: pages.length,
            current: _page,
            onTap: _open,
          ),
        ),
      ],
    );
  }
}

/// One dot per page; each has a tap area of 32 by 32 pixels.
class _Dots extends StatelessWidget {
  const _Dots({
    required this.name,
    required this.count,
    required this.current,
    required this.onTap,
  });

  final String name;
  final int count;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          GestureDetector(
            key: homePageDotKey(name, i),
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            child: SizedBox.square(
              dimension: 32,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == current
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
