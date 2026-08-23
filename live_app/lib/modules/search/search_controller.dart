import 'package:flutter/foundation.dart';
import 'package:live_core/src/huya/huya_search.dart';

/// 搜索页控制器：关键词 / 加载 / 错误 / 结果 状态管理
class HuyaSearchController extends ChangeNotifier { // ★ 改名
  String _keyword = '';
  bool _loading = false;
  bool _searched = false;
  String? _error;
  List<HuyaSearchItem> _items = [];

  String get keyword => _keyword;
  bool get loading => _loading;
  bool get searched => _searched;
  String? get error => _error;
  List<HuyaSearchItem> get items => List.unmodifiable(_items);

  void setKeyword(String v) {
    _keyword = v;
    notifyListeners();
  }

  void clear() {
    _keyword = '';
    _items = [];
    _searched = false;
    _error = null;
    notifyListeners();
  }

  Future<void> submit() async {
    final q = _keyword.trim();
    if (q.isEmpty || _loading) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      if (RegExp(r'^\d{3,12}$').hasMatch(q)) {
        final room = await HuyaSearchApi.getRoom(q);
        _items = room != null
            ? [room]
            : [HuyaSearchItem(roomId: q, nickname: '房间 $q')];
      } else {
        _items = await HuyaSearchApi.search(q);
      }
      _searched = true;
    } catch (_) {
      _error = '搜索失败，请检查网络后重试';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  String wan(int n) =>
      n >= 10000 ? '${(n / 10000).toStringAsFixed(1)}万' : '$n';
}
