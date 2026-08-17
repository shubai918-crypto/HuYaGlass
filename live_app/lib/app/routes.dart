import 'package:get/get.dart';
import '../modules/home/home_page.dart';
import '../modules/live_play/live_play_page.dart';
import '../modules/search/search_page.dart';
import '../modules/follow/follow_page.dart';
import '../modules/settings/settings_page.dart';

class AppRoutes {
  static const home = '/home';
  static const livePlay = '/live_play';
  static const search = '/search';
  static const follow = '/follow';
  static const settings = '/settings';

  static final pages = [
    GetPage(name: home, page: () => const HomePage()),
    GetPage(name: livePlay, page: () => const LivePlayPage()),
    GetPage(name: search, page: () => const SearchPage()),
    GetPage(name: follow, page: () => const FollowPage()),
    GetPage(name: settings, page: () => const SettingsPage()),
  ];
}
