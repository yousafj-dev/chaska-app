import 'package:flutter/material.dart';

/// Shared route observer: feed video cards subscribe to their own
/// route so they can pause when another page is pushed on top of
/// them (profile, sound page, create flow…) and resume when the
/// user comes back — the same pattern the feed uses to stop audio
/// leaking out of the feed.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
