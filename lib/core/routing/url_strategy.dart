// Configures the browser URL strategy on web (path-based instead of
// hash-based). A no-op on mobile/desktop.
//
// This indirection exists because `package:flutter_web_plugins` pulls in
// `dart:ui_web`, which the non-web compilers can't resolve — importing it
// directly from `main.dart` breaks mobile/desktop builds even behind a
// `kIsWeb` runtime check, since the import itself is resolved at compile
// time. `dart.library.html` is only defined for web compiles, so the
// conditional export picks the right implementation per platform.
export 'url_strategy_io.dart' if (dart.library.html) 'url_strategy_web.dart';
