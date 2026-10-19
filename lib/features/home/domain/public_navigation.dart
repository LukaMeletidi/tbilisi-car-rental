/// The navigation of the public app (Phase 6b): its four tabs, which page
/// shows the bottom bar, and where Android's system Back goes. Pure Dart.
library;

/// The tabs of the public app, in the order of the bottom bar. The index of
/// a tab is the index of its branch in the router.
enum PublicTab { home, cars, about, faq }

/// The first page of each tab.
const publicHomePath = '/';
const publicCarsPath = '/cars';
const publicAboutPath = '/about';
const publicFaqPath = '/faq';

String _withoutTrailingSlash(String path) =>
    path.length > 1 && path.endsWith('/')
    ? path.substring(0, path.length - 1)
    : path;

/// The tab of [path] when it is a tab page, or null for every other
/// address: the car page, the booking form, the thank-you page, the admin
/// area and unknown addresses. Only a tab page shows the bottom bar.
PublicTab? publicTabOf(String path) {
  switch (_withoutTrailingSlash(path)) {
    case publicHomePath:
      return PublicTab.home;
    case publicCarsPath:
      return PublicTab.cars;
    case publicAboutPath:
      return PublicTab.about;
    case publicFaqPath:
      return PublicTab.faq;
  }
  return null;
}

/// The first page of [tab].
String publicTabPath(PublicTab tab) {
  switch (tab) {
    case PublicTab.home:
      return publicHomePath;
    case PublicTab.cars:
      return publicCarsPath;
    case PublicTab.about:
      return publicAboutPath;
    case PublicTab.faq:
      return publicFaqPath;
  }
}

/// Where Android's system Back goes on a tab page, or null when the shell
/// leaves it to the router (on Home: the app is left, as today on the
/// catalog). On the web the browser's Back follows its history and is
/// never intercepted, so [isWeb] always gives null.
PublicTab? publicSystemBackTarget({required bool isWeb, required String path}) {
  if (isWeb) return null;
  final tab = publicTabOf(path);
  if (tab == null || tab == PublicTab.home) return null;
  return PublicTab.home;
}
