// Hautpocket 主界面：蓝白纯色简约大气 UI (Material 3)
// 页面1：今日课表 + 每周课表查询 + 上课提醒（推送通知 / 闹钟提醒双方式）
// 页面2：选课查询 + 培养方案各类目所需学分 + 未选可选课程（按学分大小分类）
// 页面3：已有成绩单科学分绩点与总学分绩点计算 + 达到培养方案标准还需学分统计

import 'dart:async';
import 'package:flutter/material.dart';
import 'data/curriculum_2025.dart';
import 'services/haut_jwglxt_service.dart';
import 'services/reminder_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HautpocketApp());
}

class HautpocketApp extends StatelessWidget {
  const HautpocketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hautpocket',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F8FF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D4ED8),
          primary: const Color(0xFF1D4ED8),
          onPrimary: Colors.white,
          secondary: const Color(0xFF2563EB),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1D4ED8),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const HautpocketHomeScreen(),
    );
  }
}

class HautpocketHomeScreen extends StatefulWidget {
  const HautpocketHomeScreen({super.key});

  @override
  State<HautpocketHomeScreen> createState() => _HautpocketHomeScreenState();
}

class _HautpocketHomeScreenState extends State<HautpocketHomeScreen> {
  int _currentTabIndex = 0;
  String _studentId = '251210100701';
  String _password = 'Csy1230！';
  int _selectedWeek = 9;
  int _selectedWeekday = DateTime.now().weekday;
  int _syncIntervalMinutes = 30;
  DateTime _lastSyncTime = DateTime.now();
  ReminderMode _reminderMode = ReminderMode.both;
  int _reminderLeadMinutes = 15;

  final HautJwglxtService _api = HautJwglxtService();
  final CourseReminderService _reminder = CourseReminderService();

  @override
  void initState() {
    super.initState();
    _reminder.init();
    _api.startAutoSync(
      intervalMinutes: _syncIntervalMinutes,
      onSyncTick: _syncFromJwglxt,
    );
  }

  Future<void> _syncFromJwglxt() async {
    try {
      await _api.login(_studentId, _password);
      await _api.fetchSchedule(year: '2026', termCode: '3');
      setState(() => _lastSyncTime = DateTime.now());
    } catch (_) {
      setState(() => _lastSyncTime = DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/icon/app_icon.png', width: 32, height: 32),
            ),
            const SizedBox(width: 10),
            const Text('Hautpocket', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: '立即同步教务数据',
            onPressed: _syncFromJwglxt,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: const [
          Center(child: Text('第1页：今日课程安排、每周课表与上课提醒（推送/闹钟）')),
          Center(child: Text('第2页：选课查询、培养方案类目学分对比与未选可选学科（按学分大小分类）')),
          Center(child: Text('第3页：单科学分绩点、总学分绩点与培养方案毕业学分差额分析')),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (idx) => setState(() => _currentTabIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: '课表与提醒'),
          NavigationDestination(icon: Icon(Icons.account_tree_outlined), label: '选课与方案'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), label: '绩点与学分'),
        ],
      ),
    );
  }
}
