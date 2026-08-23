import 'package:flutter/material.dart';
import 'search_controller.dart';

/// 搜索页（液态玻璃深色风格）
class SearchPage extends StatefulWidget {
  /// 点击结果进房回调（与订阅列表同一入口）
  final void Function(String roomId, String nickname, String avatarUrl)
      onOpenRoom;

  const SearchPage({super.key, required this.onOpenRoom});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final SearchController _ctrl = SearchController();
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onCtrl);
  }

  void _onCtrl() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onCtrl);
    _ctrl.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    _ctrl.submit();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          _buildBar(),
          const SizedBox(height: 16),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ================= 顶部搜索栏 =================
  Widget _buildBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.search, color: Color(0xFF29C5F6), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    onSubmitted: (_) => _submit(),
                    textInputAction: TextInputAction.search,
                    onChanged: _ctrl.setKeyword,
                    decoration: const InputDecoration(
                      hintText: '搜索主播 / 输入房间号',
                      hintStyle:
                          TextStyle(color: Colors.white38, fontSize: 15),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _submit,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_forward,
                color: Color(0xFF29C5F6)),
          ),
        ),
      ],
    );
  }

  // ================= 结果区域 =================
  Widget _buildBody() {
    if (_ctrl.loading) {
      return const Center(
        child: CircularProgressIndicator(
            color: Color(0xFF29C5F6), strokeWidth: 2.5),
      );
    }
    final err = _ctrl.error;
    if (err != null) {
      return Center(
        child: Text(err, style: const TextStyle(color: Colors.white38)),
      );
    }
    if (!_ctrl.searched) {
      return const Center(
        child: Text('搜索主播，或直接输入房间号进入',
            style: TextStyle(color: Colors.white24)),
      );
    }
    if (_ctrl.items.isEmpty) {
      return const Center(
        child: Text('未找到相关主播',
            style: TextStyle(color: Colors.white38)),
      );
    }
    return ListView.separated(
      itemCount: _ctrl.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _buildCard(_ctrl.items[i]),
    );
  }

  Widget _buildCard(HuyaSearchItem it) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () =>
            widget.onOpenRoom(it.roomId, it.nickname, it.avatarUrl),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white10,
                backgroundImage: it.avatarUrl.isNotEmpty
                    ? NetworkImage(it.avatarUrl)
                    : null,
                child: it.avatarUrl.isEmpty
                    ? Text(it.nickname.isNotEmpty ? it.nickname[0] : '?')
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      it.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: it.isLive
                                ? Colors.redAccent.withOpacity(0.2)
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            it.isLive ? '直播中' : '未开播',
                            style: TextStyle(
                                fontSize: 11,
                                color: it.isLive
                                    ? Colors.redAccent
                                    : Colors.white38),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('房间 ${it.roomId}',
                            style: const TextStyle(
                                color: Colors.white30, fontSize: 12)),
                        if (it.totalCount > 0) ...[
                          const SizedBox(width: 8),
                          Text('${_ctrl.wan(it.totalCount)}热度',
                              style: const TextStyle(
                                  color: Colors.white30, fontSize: 12)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}
