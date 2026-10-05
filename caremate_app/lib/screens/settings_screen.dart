import 'package:flutter/material.dart';

/// 設定頁（預留，之後加字體大小、語言、緊急聯絡人等）
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: const Center(child: Text('開發中')),
    );
  }
}
