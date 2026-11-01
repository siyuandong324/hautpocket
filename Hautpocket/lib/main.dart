// Hautpocket 主界面：蓝白纯色简约大气 UI (Android + Flutter Material 3)
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
        scaffoldBackgroundColor: const Color(0xFFF2F7FF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E40AF),
          primary: const Color(0xFF1E40AF),
          onPrimary: Colors.white,
          secondary: const Color(0xFF2563EB),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E40AF),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const HautpocketHomeScreen(),
    );
  }
}

class ScheduleItem {
  final String code;
  final String name;
  final int weekday;
  final String sessions;
  final String weeks;
  final String location;
  final String teacher;
  final double credits;
  bool remind;

  ScheduleItem({
    required this.code,
    required this.name,
    required this.weekday,
    required this.sessions,
    required this.weeks,
    required this.location,
    required this.teacher,
    required this.credits,
    this.remind = true,
  });
}

class GradeRecord {
  final String code;
  final String name;
  final double credits;
  final String score;
  final double gp;
  final String platform;
  final String nature;

  GradeRecord({
    required this.code,
    required this.name,
    required this.credits,
    required this.score,
    required this.gp,
    required this.platform,
    required this.nature,
  });

  double get creditGradePoint => double.parse((credits * gp).toStringAsFixed(2));
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
  String _year = '2025';
  String _termCode = '3'; // 3=第一学期, 12=第二学期
  int _selectedWeekday = DateTime.now().weekday;
  int _syncIntervalMinutes = 30;
  bool _isSyncing = false;
  String _syncStatusMsg = '准备就绪，点击右上角可同步真实教务数据';

  bool _enablePush = true;
  bool _enableAlarm = true;
  int _reminderLeadMinutes = 15;
  bool _creditDescOrder = true;
  String _unselectedNatureFilter = 'ALL';

  final HautJwglxtService _api = HautJwglxtService();
  final CourseReminderService _reminder = CourseReminderService();

  List<ScheduleItem> _scheduleList = [];
  Set<String> _selectedCourseCodes = {};
  List<GradeRecord> _gradeRecords = [];

  @override
  void initState() {
    super.initState();
    _reminder.init();
    _loadDefaultPreset();
    _api.startAutoSync(
      intervalMinutes: _syncIntervalMinutes,
      onSyncTick: _syncFromJwglxt,
    );
    // 启动后自动尝试登录正方教务系统拉取真实数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromJwglxt();
    });
  }

  void _loadDefaultPreset() {
    final firstTermCourses = HautCurriculum2025.allCourses.where((c) => c.semester == 1).toList();
    _selectedCourseCodes = firstTermCourses.map((c) => c.code).toSet();
    _scheduleList = [
      ScheduleItem(code: 'X01261001B', name: '高等数学 A（一）', weekday: 1, sessions: '1-2节 (08:00-09:35)', weeks: '1-16周', location: '莲花街校区 3号楼3201', teacher: '数理系教师', credits: 5.0),
      ScheduleItem(code: 'X01211201B', name: '程序设计基础', weekday: 1, sessions: '3-4节 (10:05-11:40)', weeks: '1-16周', location: '莲花街校区 5号楼5102', teacher: '人工智能学院教师', credits: 3.0),
      ScheduleItem(code: 'T01161001B', name: '思想道德与法治', weekday: 1, sessions: '5-6节 (14:30-16:05)', weeks: '1-16周', location: '莲花街校区 4号楼4105', teacher: '马院教师', credits: 3.0),
      ScheduleItem(code: 'T01111001B', name: '大学英语（一）', weekday: 2, sessions: '1-2节 (08:00-09:35)', weeks: '1-16周', location: '莲花街校区 1号楼1206', teacher: '外语学院教师', credits: 2.0),
      ScheduleItem(code: 'X01261007B', name: '线性代数', weekday: 2, sessions: '3-4节 (10:05-11:40)', weeks: '1-16周', location: '莲花街校区 3号楼3203', teacher: '数理系教师', credits: 2.5),
      ScheduleItem(code: 'Z01211201B', name: '人工智能导论★', weekday: 2, sessions: '5-6节 (14:30-16:05)', weeks: '1-8周', location: '莲花街校区 5号楼5201', teacher: '人工智能学院教师', credits: 1.0),
    ];
    _gradeRecords = firstTermCourses.map((c) {
      const score = '90';
      final gp = HautCurriculum2025.calculateGradePoint(score);
      return GradeRecord(
        code: c.code,
        name: c.name,
        credits: c.credits,
        score: score,
        gp: gp,
        platform: c.platform,
        nature: c.nature,
      );
    }).toList();
  }

  /// 直连河南工业大学正方教务系统拉取真实课表、选课、成绩
  Future<void> _syncFromJwglxt() async {
    setState(() {
      _isSyncing = true;
      _syncStatusMsg = '正在连接 jwglxt.haut.edu.cn 同步真实数据...';
    });
    try {
      await _api.login(_studentId, _password);
      final rawKb = await _api.fetchSchedule(year: _year, termCode: _termCode);
      final rawGrades = await _api.fetchGrades(year: '', termCode: '');
      final rawSelected = await _api.fetchSelectedCourses(year: _year, termCode: _termCode);

      final kbList = (rawKb['kbList'] as List<dynamic>?) ?? [];
      if (kbList.isNotEmpty) {
        _scheduleList = kbList.map((item) {
          final map = item as Map<String, dynamic>;
          return ScheduleItem(
            code: (map['kch_id'] ?? map['kch'] ?? '').toString(),
            name: (map['kcmc'] ?? '').toString(),
            weekday: int.tryParse((map['xqj'] ?? '1').toString()) ?? 1,
            sessions: (map['jc'] ?? map['jcor'] ?? '').toString(),
            weeks: (map['zcd'] ?? '').toString(),
            location: '${map['xqmc'] ?? ''} ${map['cdmc'] ?? ''}'.trim(),
            teacher: (map['xm'] ?? '未公布').toString(),
            credits: double.tryParse((map['xf'] ?? '2.0').toString()) ?? 2.0,
          );
        }).toList();
      }

      if (rawSelected.isNotEmpty) {
        _selectedCourseCodes = rawSelected
            .map((e) => ((e as Map<String, dynamic>)['kch'] ?? '').toString().trim())
            .where((s) => s.isNotEmpty)
            .toSet();
      }

      if (rawGrades.isNotEmpty) {
        _gradeRecords = rawGrades.map((e) {
          final map = e as Map<String, dynamic>;
          final code = (map['kch'] ?? map['kch_id'] ?? '').toString().trim();
          final name = (map['kcmc'] ?? '').toString().trim();
          final scoreStr = (map['cj'] ?? '0').toString().trim();
          final rawJd = double.tryParse((map['jd'] ?? '').toString());
          final xf = double.tryParse((map['xf'] ?? '0').toString()) ?? 0.0;
          final planMatch = HautCurriculum2025.allCourses.where((c) => c.code == code || c.name == name).firstOrNull;
          return GradeRecord(
            code: code,
            name: name,
            credits: xf > 0 ? xf : (planMatch?.credits ?? 2.0),
            score: scoreStr,
            gp: HautCurriculum2025.calculateGradePoint(scoreStr, rawJd: rawJd),
            platform: planMatch?.platform ?? (map['kclbmc'] ?? '通识平台').toString(),
            nature: planMatch?.nature ?? (map['kcxzmc'] ?? '必修').toString(),
          );
        }).toList();
      }

      setState(() {
        _isSyncing = false;
        _syncStatusMsg = '已同步教务系统最新真实数据 (${TimeOfDay.now().format(context)})';
      });
    } catch (e) {
      setState(() {
        _isSyncing = false;
        _syncStatusMsg = '同步提示：$e（当前显示本地缓存数据）';
      });
    }
  }

  /// Tab 1：今日课表、每周课表与双模式提醒
  Widget _buildScheduleTab() {
    final todayCourses = _scheduleList.where((c) => c.weekday == _selectedWeekday).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 顶部同步状态与提醒设置卡
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFDBEAFE)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('上课提醒方式（可同时开启）', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('提前 $_reminderLeadMinutes 分钟', style: const TextStyle(color: Color(0xFF1E40AF), fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilterChip(
                        selected: _enablePush,
                        label: const Text('推送消息提醒'),
                        onSelected: (v) => setState(() => _enablePush = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilterChip(
                        selected: _enableAlarm,
                        label: const Text('系统闹钟提醒'),
                        onSelected: (v) => setState(() => _enableAlarm = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 星期选择栏
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(7, (idx) {
              final day = idx + 1;
              const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
              final selected = _selectedWeekday == day;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(labels[idx]),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedWeekday = day),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        if (todayCourses.isEmpty)
          const Card(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('所选星期暂无排课安排')),
            ),
          )
        else
          ...todayCourses.map((c) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFDBEAFE)),
                ),
                child: ListTile(
                  title: Text('${c.name} (${c.credits}学分)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${c.sessions} | ${c.weeks}\n地点：${c.location} | 教师：${c.teacher}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.alarm_add, color: Color(0xFF1E40AF)),
                    onPressed: () {
                      if (_enablePush) {
                        _reminder.triggerCourseNotification(
                          id: c.hashCode,
                          courseName: c.name,
                          classroom: c.location,
                          teacher: c.teacher,
                          startTime: c.sessions,
                          leadMinutes: _reminderLeadMinutes,
                        );
                      }
                      if (_enableAlarm) {
                        _reminder.setSystemAlarmForCourse(
                          courseName: c.name,
                          classroom: c.location,
                          hour: 8,
                          minute: 0,
                          leadMinutes: _reminderLeadMinutes,
                        );
                      }
                    },
                  ),
                ),
              )),
      ],
    );
  }

  /// Tab 2：选课查询 + 培养方案类目所需学分 + 未选可选学科（按学分大小分类）
  Widget _buildSelectionTab() {
    final gradedCodes = _gradeRecords.map((g) => g.code).toSet();
    final unselected = HautCurriculum2025.allCourses.where((c) {
      if (gradedCodes.contains(c.code) || _selectedCourseCodes.contains(c.code)) return false;
      if (_unselectedNatureFilter != 'ALL' && c.nature != _unselectedNatureFilter) return false;
      return true;
    }).toList();

    final groupedByCredit = <double, List<PlanCourse>>{};
    for (final c in unselected) {
      groupedByCredit.putIfAbsent(c.credits, () => []).add(c);
    }
    final creditKeys = groupedByCredit.keys.toList()
      ..sort((a, b) => _creditDescOrder ? b.compareTo(a) : a.compareTo(b));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('一、培养方案各类目所需学分标准 (总计 169.0 学分)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...HautCurriculum2025.platformRequirements.map((req) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFDBEAFE)),
              ),
              child: ListTile(
                title: Text('${req.platform}（要求 ${req.totalRequired} 学分）', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(req.note),
              ),
            )),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('二、未选但可选学科（按学分大小分类）', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton.icon(
              onPressed: () => setState(() => _creditDescOrder = !_creditDescOrder),
              icon: const Icon(Icons.sort),
              label: Text(_creditDescOrder ? '学分从大到小' : '学分从小到大'),
            ),
          ],
        ),
        ...creditKeys.map((creditVal) {
          final items = groupedByCredit[creditVal]!;
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFDBEAFE)),
            ),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Text('$creditVal 学分档（共 ${items.length} 门可选）', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
              children: items
                  .map((item) => ListTile(
                        dense: true,
                        title: Text('${item.name} [${item.nature}]', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${item.code} · ${item.platform} (${item.module}) · 建议第${item.semester}学期'),
                        trailing: OutlinedButton(
                          onPressed: () => setState(() => _selectedCourseCodes.add(item.code)),
                          child: const Text('+ 加入选课'),
                        ),
                      ))
                  .toList(),
            ),
          );
        }),
      ],
    );
  }

  /// Tab 3：目前已有成绩学科每科学分绩点、总学分绩点与达标还需学分
  Widget _buildGpaTab() {
    double totalCredits = 0;
    double totalCreditGp = 0;
    for (final g in _gradeRecords) {
      totalCredits += g.credits;
      totalCreditGp += g.creditGradePoint;
    }
    final avgGpa = totalCredits > 0 ? (totalCreditGp / totalCredits) : 0.0;
    final remainingTotal = (HautCurriculum2025.totalGraduationCredits - totalCredits).clamp(0.0, 169.0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: const Color(0xFF1E40AF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('学分绩点与培养方案毕业差额总览', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetricCol('总学分绩点', totalCreditGp.toStringAsFixed(2)),
                    _buildMetricCol('平均学分绩点(GPA)', avgGpa.toStringAsFixed(2)),
                    _buildMetricCol('已修总学分', totalCredits.toStringAsFixed(1)),
                    _buildMetricCol('达标还需学分', remainingTotal.toStringAsFixed(1)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('已有成绩学科每科学分绩点明细 (单科学分绩点 = 学分 × 绩点)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        ..._gradeRecords.map((g) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFDBEAFE)),
              ),
              child: ListTile(
                title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${g.code} · ${g.platform} (${g.nature}) · 学分: ${g.credits}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('成绩: ${g.score} | 绩点: ${g.gp.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                    Text('单科学分绩点: ${g.creditGradePoint.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildMetricCol(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }

  void _showSettingsDialog() {
    final idCtrl = TextEditingController(text: _studentId);
    final pwdCtrl = TextEditingController(text: _password);
    final syncCtrl = TextEditingController(text: _syncIntervalMinutes.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('教务账号与自动更新设置'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: idCtrl, decoration: const InputDecoration(labelText: '学号 (yhm)')),
              TextField(controller: pwdCtrl, obscureText: true, decoration: const InputDecoration(labelText: '密码 (mm)')),
              TextField(controller: syncCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '自动更新间隔（分钟）')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              setState(() {
                _studentId = idCtrl.text.trim();
                _password = pwdCtrl.text;
                _syncIntervalMinutes = int.tryParse(syncCtrl.text) ?? 30;
              });
              _api.startAutoSync(intervalMinutes: _syncIntervalMinutes, onSyncTick: _syncFromJwglxt);
              Navigator.pop(ctx);
              _syncFromJwglxt();
            },
            child: const Text('保存并立即同步'),
          ),
        ],
      ),
    );
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hautpocket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  Text(_syncStatusMsg, style: const TextStyle(fontSize: 10, color: Colors.white70), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.sync),
            tooltip: '立即同步真实教务数据',
            onPressed: _isSyncing ? null : _syncFromJwglxt,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '账号与自动同步间隔设置',
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildScheduleTab(),
          _buildSelectionTab(),
          _buildGpaTab(),
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
