import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live_core/live_core.dart';

class SearchController extends GetxController {
  final searchController = TextEditingController();
  final results = <LiveRoom>[].obs;
  final searching = false.obs;
  final hasSearched = false.obs;

  final HuyaApi _api = HuyaApi();

  Future<void> search(String keyword) async {
    if (keyword.isEmpty) return;
    searching.value = true;
    hasSearched.value = true;

    try {
      final rooms = await _api.searchRooms(keyword);
      results.assignAll(rooms);
    } catch (e) {
      results.clear();
      Get.snackbar('错误', '搜索失败: $e');
    } finally {
      searching.value = false;
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
