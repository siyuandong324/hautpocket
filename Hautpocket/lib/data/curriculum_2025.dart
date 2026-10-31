// 河南工业大学 2025 版人工智能专业人才培养方案完整数据集与绩点算法
// 数据来源：《人工智能专业-河南工业大学2025版专业人才培养方案.pdf》

class PlanCourse {
  final String code;
  final String name;
  final double credits;
  final String platform; // 通识平台 | 学科平台 | 专业平台 | 能力拓展
  final String module;   // 思政类、外语类、数理类、学科自主课程、专业必修课程、专业选修课程、集中实践环节、专业拓展类等
  final String nature;   // 必修 | 选修 | 集中实践
  final int semester;    // 推荐修读学期 1~8
  final String direction; // 适用方向

  const PlanCourse({
    required this.code,
    required this.name,
    required this.credits,
    required this.platform,
    required this.module,
    required this.nature,
    required this.semester,
    this.direction = '',
  });
}

class PlatformRequirement {
  final String platform;
  final double totalRequired;
  final double compulsoryRequired;
  final double electiveRequired;
  final double practiceRequired;
  final String note;

  const PlatformRequirement({
    required this.platform,
    required this.totalRequired,
    required this.compulsoryRequired,
    required this.electiveRequired,
    required this.practiceRequired,
    required this.note,
  });
}

class HautCurriculum2025 {
  static const double totalGraduationCredits = 169.0;
  static const double totalCompulsoryCredits = 137.0; // 含必修理论 102.5 + 集中实践 34.5
  static const double totalElectiveCredits = 32.0;    // 通识选修 6 + 专业选修 14 + 能力拓展选修 12
  static const double totalPracticeCredits = 52.5;    // 实践教学学分占总学分 31.07%

  static const List<PlatformRequirement> platformRequirements = [
    PlatformRequirement(
      platform: '通识平台',
      totalRequired: 48.5,
      compulsoryRequired: 39.5,
      electiveRequired: 6.0,
      practiceRequired: 3.0,
      note: '必修+实践共36门(42.5学分)，公共选修课最低修读6学分（跨6大模块）',
    ),
    PlatformRequirement(
      platform: '学科平台',
      totalRequired: 44.5,
      compulsoryRequired: 42.5,
      electiveRequired: 0.0,
      practiceRequired: 2.0,
      note: '数理类必修6门(23.5学分) + 学科自主必修7门(19学分) + 物理实验(2学分)',
    ),
    PlatformRequirement(
      platform: '专业平台',
      totalRequired: 62.0,
      compulsoryRequired: 20.5,
      electiveRequired: 14.0,
      practiceRequired: 27.5,
      note: '专业必修8门(20.5学分) + 集中实践8门(27.5学分) + 专业选修最低14学分(通用≥7.5, 方向≥6.5)',
    ),
    PlatformRequirement(
      platform: '能力拓展',
      totalRequired: 14.0,
      compulsoryRequired: 0.0,
      electiveRequired: 12.0,
      practiceRequired: 2.0,
      note: '专业拓展选修最低12学分 + 创新创业实践类必修2门(2学分)',
    ),
  ];

  /// 根据河南工业大学 5.0 制标准及正方系统规则计算单科绩点 (GP)
  static double calculateGradePoint(String scoreStr, {double? rawJd}) {
    if (rawJd != null && rawJd > 0) return rawJd;
    final clean = scoreStr.trim();
    final numScore = double.tryParse(clean);
    if (numScore != null) {
      if (numScore < 60) return 0.0;
      return double.parse(((numScore - 50.0) / 10.0).clamp(0.0, 5.0).toStringAsFixed(2));
    }
    switch (clean) {
      case '优秀':
      case '优':
        return 4.5;
      case '良好':
      case '良':
        return 3.5;
      case '中等':
      case '中':
        return 2.5;
      case '及格':
        return 1.5;
      case '合格':
      case '通过':
        return 2.5;
      default:
        return 0.0;
    }
  }

  /// 2025版人工智能专业培养方案全部课程清单（表十二）
  static const List<PlanCourse> allCourses = [
    // 一、通识平台 (必修+实践 42.5 学分, 公共选修 6.0 学分)
    PlanCourse(code: 'T01161001B', name: '思想道德与法治', credits: 3.0, platform: '通识平台', module: '思政类', nature: '必修', semester: 1),
    PlanCourse(code: 'T01161002B', name: '中国近现代史纲要', credits: 3.0, platform: '通识平台', module: '思政类', nature: '必修', semester: 2),
    PlanCourse(code: 'T01161003B', name: '马克思主义基本原理', credits: 3.0, platform: '通识平台', module: '思政类', nature: '必修', semester: 3),
    PlanCourse(code: 'T01161004B', name: '毛泽东思想和中国特色社会主义理论体系概论', credits: 3.0, platform: '通识平台', module: '思政类', nature: '必修', semester: 4),
    PlanCourse(code: 'T01161005B', name: '习近平新时代中国特色社会主义思想概论', credits: 3.0, platform: '通识平台', module: '思政类', nature: '必修', semester: 5),
    PlanCourse(code: 'T01161006B', name: '形势与政策（一）', credits: 0.3, platform: '通识平台', module: '思政类', nature: '必修', semester: 1),
    PlanCourse(code: 'T01161007B', name: '形势与政策（二）', credits: 0.3, platform: '通识平台', module: '思政类', nature: '必修', semester: 2),
    PlanCourse(code: 'T01161008B', name: '形势与政策（三）', credits: 0.3, platform: '通识平台', module: '思政类', nature: '必修', semester: 3),
    PlanCourse(code: 'T01161009B', name: '形势与政策（四）', credits: 0.3, platform: '通识平台', module: '思政类', nature: '必修', semester: 4),
    PlanCourse(code: 'T01161010B', name: '形势与政策（五）', credits: 0.4, platform: '通识平台', module: '思政类', nature: '必修', semester: 5),
    PlanCourse(code: 'T01161011B', name: '形势与政策（六）', credits: 0.4, platform: '通识平台', module: '思政类', nature: '必修', semester: 6),
    PlanCourse(code: 'T01111001B', name: '大学英语（一）', credits: 2.0, platform: '通识平台', module: '外语类', nature: '必修', semester: 1),
    PlanCourse(code: 'T01111002B', name: '大学英语（二）', credits: 2.0, platform: '通识平台', module: '外语类', nature: '必修', semester: 2),
    PlanCourse(code: 'T01111003B', name: '大学英语（三）', credits: 2.0, platform: '通识平台', module: '外语类', nature: '必修', semester: 3),
    PlanCourse(code: 'T01111006B', name: '跨文化交际', credits: 2.0, platform: '通识平台', module: '外语类', nature: '必修', semester: 4),
    PlanCourse(code: 'T04051001B', name: '军事理论', credits: 2.0, platform: '通识平台', module: '军事类', nature: '必修', semester: 1),
    PlanCourse(code: 'T04051002B', name: '军事技能', credits: 2.0, platform: '通识平台', module: '军事类', nature: '集中实践', semester: 1),
    PlanCourse(code: 'T01191001B', name: '大学体育（一）', credits: 1.0, platform: '通识平台', module: '体育类', nature: '必修', semester: 1),
    PlanCourse(code: 'T01191002B', name: '大学体育（二）', credits: 1.0, platform: '通识平台', module: '体育类', nature: '必修', semester: 2),
    PlanCourse(code: 'T01191003B', name: '大学体育（三）', credits: 1.0, platform: '通识平台', module: '体育类', nature: '必修', semester: 3),
    PlanCourse(code: 'T01191004B', name: '大学体育（四）', credits: 1.0, platform: '通识平台', module: '体育类', nature: '必修', semester: 4),
    PlanCourse(code: 'T01161012B', name: '劳动教育（理论）', credits: 0.5, platform: '通识平台', module: '劳动教育类', nature: '必修', semester: 1),
    PlanCourse(code: 'T04081001B', name: '劳动教育（实践）一', credits: 0.2, platform: '通识平台', module: '劳动教育类', nature: '集中实践', semester: 2),
    PlanCourse(code: 'T04081002B', name: '劳动教育（实践）二', credits: 0.2, platform: '通识平台', module: '劳动教育类', nature: '集中实践', semester: 3),
    PlanCourse(code: 'T04081003B', name: '劳动教育（实践）三', credits: 0.2, platform: '通识平台', module: '劳动教育类', nature: '集中实践', semester: 4),
    PlanCourse(code: 'T04081004B', name: '劳动教育（实践）四', credits: 0.2, platform: '通识平台', module: '劳动教育类', nature: '集中实践', semester: 5),
    PlanCourse(code: 'T04081005B', name: '劳动教育（实践）五', credits: 0.2, platform: '通识平台', module: '劳动教育类', nature: '集中实践', semester: 6),
    PlanCourse(code: 'T03051001B', name: '生涯教育', credits: 0.5, platform: '通识平台', module: '就业创业类', nature: '必修', semester: 1),
    PlanCourse(code: 'T03051002B', name: '创新教育', credits: 0.5, platform: '通识平台', module: '就业创业类', nature: '必修', semester: 3),
    PlanCourse(code: 'T03051003B', name: '创业教育', credits: 0.5, platform: '通识平台', module: '就业创业类', nature: '必修', semester: 4),
    PlanCourse(code: 'T03051004B', name: '就业教育', credits: 0.5, platform: '通识平台', module: '就业创业类', nature: '必修', semester: 6),
    PlanCourse(code: 'T01161013B', name: '国家安全教育', credits: 1.0, platform: '通识平台', module: '国家安全教育', nature: '必修', semester: 2),
    PlanCourse(code: 'T01131001B', name: '音乐鉴赏', credits: 1.0, platform: '通识平台', module: '人文艺术类', nature: '必修', semester: 1),
    PlanCourse(code: 'T01141002B', name: '粮食文化', credits: 1.0, platform: '通识平台', module: '人文艺术类', nature: '必修', semester: 2),
    PlanCourse(code: 'T01131002B', name: '美术鉴赏', credits: 1.0, platform: '通识平台', module: '人文艺术类', nature: '必修', semester: 4),
    PlanCourse(code: 'T04051003B', name: '心理健康教育', credits: 2.0, platform: '通识平台', module: '心理健康教育', nature: '必修', semester: 1),

    // 二、学科平台 (共 44.5 学分)
    PlanCourse(code: 'X01261001B', name: '高等数学 A（一）', credits: 5.0, platform: '学科平台', module: '数理类', nature: '必修', semester: 1),
    PlanCourse(code: 'X01261002B', name: '高等数学 A（二）', credits: 6.0, platform: '学科平台', module: '数理类', nature: '必修', semester: 2),
    PlanCourse(code: 'X01261007B', name: '线性代数', credits: 2.5, platform: '学科平台', module: '数理类', nature: '必修', semester: 1),
    PlanCourse(code: 'X01261008B', name: '概率论与数理统计', credits: 3.0, platform: '学科平台', module: '数理类', nature: '必修', semester: 3),
    PlanCourse(code: 'X01271001B', name: '大学物理 A（一）', credits: 3.0, platform: '学科平台', module: '数理类', nature: '必修', semester: 2),
    PlanCourse(code: 'X01271002B', name: '大学物理 A（二）', credits: 4.0, platform: '学科平台', module: '数理类', nature: '必修', semester: 3),
    PlanCourse(code: 'X01211201B', name: '程序设计基础', credits: 3.0, platform: '学科平台', module: '学科自主课程', nature: '必修', semester: 1),
    PlanCourse(code: 'X01211202B', name: '离散数学', credits: 3.0, platform: '学科平台', module: '学科自主课程', nature: '必修', semester: 2),
    PlanCourse(code: 'X01211203B', name: '文献检索与论文写作', credits: 1.0, platform: '学科平台', module: '学科自主课程', nature: '必修', semester: 3),
    PlanCourse(code: 'X01211204B', name: '电路与电子技术', credits: 3.0, platform: '学科平台', module: '学科自主课程', nature: '必修', semester: 4),
    PlanCourse(code: 'X01211205B', name: '操作系统原理', credits: 3.0, platform: '学科平台', module: '学科自主课程', nature: '必修', semester: 4),
    PlanCourse(code: 'X01211206B', name: '计算机网络', credits: 3.0, platform: '学科平台', module: '学科自主课程', nature: '必修', semester: 5),
    PlanCourse(code: 'X01211207B', name: '计算机组成原理', credits: 3.0, platform: '学科平台', module: '学科自主课程', nature: '必修', semester: 5),
    PlanCourse(code: 'X01271006B', name: '物理实验', credits: 2.0, platform: '学科平台', module: '集中实践环节', nature: '集中实践', semester: 3),

    // 三、专业平台 - 专业必修课程 (8门, 20.5学分)
    PlanCourse(code: 'Z01211201B', name: '人工智能导论★', credits: 1.0, platform: '专业平台', module: '专业必修课程', nature: '必修', semester: 1),
    PlanCourse(code: 'Z01211202B', name: 'Python 程序设计', credits: 2.5, platform: '专业平台', module: '专业必修课程', nature: '必修', semester: 2),
    PlanCourse(code: 'Z01211203B', name: '机器学习', credits: 3.0, platform: '专业平台', module: '专业必修课程', nature: '必修', semester: 3),
    PlanCourse(code: 'Z01211204B', name: '数据结构', credits: 3.0, platform: '专业平台', module: '专业必修课程', nature: '必修', semester: 3),
    PlanCourse(code: 'Z01211205B', name: '神经网络与深度学习', credits: 3.0, platform: '专业平台', module: '专业必修课程', nature: '必修', semester: 4),
    PlanCourse(code: 'Z01211206B', name: '大语言模型★', credits: 2.5, platform: '专业平台', module: '专业必修课程', nature: '必修', semester: 5),
    PlanCourse(code: 'Z01211207B', name: '计算机视觉★', credits: 2.5, platform: '专业平台', module: '专业必修课程', nature: '必修', semester: 5),
    PlanCourse(code: 'Z01211208B', name: '信号与系统', credits: 3.0, platform: '专业平台', module: '专业必修课程', nature: '必修', semester: 5),

    // 三、专业平台 - 专业选修课程 (14门可选, 最低修满 14.0 学分)
    PlanCourse(code: 'Z01211209B', name: 'Linux 操作系统★', credits: 2.0, platform: '专业平台', module: '专业选修课程', nature: '选修', semester: 2, direction: '所有方向'),
    PlanCourse(code: 'Z01211210B', name: '面向对象程序设计（Java）', credits: 3.0, platform: '专业平台', module: '专业选修课程', nature: '选修', semester: 3, direction: '所有方向'),
    PlanCourse(code: 'Z01211211B', name: '数据库系统原理及应用', credits: 3.0, platform: '专业平台', module: '专业选修课程', nature: '选修', semester: 4, direction: '所有方向'),
    PlanCourse(code: 'Z01211212B', name: '数字信号处理', credits: 3.0, platform: '专业平台', module: '专业选修课程', nature: '选修', semester: 6, direction: '所有方向'),
    PlanCourse(code: 'Z01211213B', name: '大模型技术微调与实践▲', credits: 2.5, platform: '专业平台', module: '专业选修课程', nature: '选修', semester: 6, direction: '所有方向'),
    PlanCourse(code: 'Z01211214B', name: '人工智能数学基础', credits: 2.0, platform: '专业平台', module: '专业选修课程', nature: '选修', semester: 3, direction: '方向一：智能算法'),
    PlanCourse(code: 'Z01211215B', name: '最优化原理与方法', credits: 2.0, platform: '专业平台', module: '专业选修课程', nature: '选修', semester: 4, direction: '方向一：智能算法'),
    PlanCourse(code: 'Z01211216B', name: '算法设计与分析', credits: 3.0, platform: '专业平台', module: '专业选修课程', nature: '选修', semester: 5, direction: '方向一：智能算法'),
    PlanCourse(code: 'Z01211217B', name: '机器人建模与仿真▲', credits: 3.0, platform: '专业平台', module: '专业选修课程', nature: '选修', semester: 3, direction: '方向二：智能感知'),
    PlanCourse(code: 'Z01211218B', name: '语音信息处理▲', credits: 3.0, platform: '专业平台', module: '专业选修课程', nature: '选修', semester: 5, direction: '方向二：智能感知'),
    PlanCourse(code: 'Z01211219B', name: '智能感知与应用▲', credits: 2.5, platform: '专业平台', module: '专业选修课程', nature: '选修', semester: 6, direction: '方向二：智能感知'),
    PlanCourse(code: 'Z01211220B', name: '智能体平台应用▲', credits: 2.5, platform: '专业平台', module: '专业选修课程', nature: '选修', semester: 2, direction: '方向三：智能系统'),
    PlanCourse(code: 'Z01211221B', name: 'Python Web 开发基础▲', credits: 3.0, platform: '专业平台', module: '专业选修课程', nature: '选修', semester: 4, direction: '方向三：智能系统'),
    PlanCourse(code: 'Z01211222B', name: '智能系统设计与开发▲', credits: 3.0, platform: '专业平台', module: '专业选修课程', nature: '选修', semester: 5, direction: '方向三：智能系统'),

    // 三、专业平台 - 集中实践环节 (8门, 27.5学分)
    PlanCourse(code: 'Z01211223B', name: '科学计算库综合实践▲', credits: 2.0, platform: '专业平台', module: '集中实践环节', nature: '集中实践', semester: 2),
    PlanCourse(code: 'Z01211224B', name: '机器学习实践▲', credits: 2.0, platform: '专业平台', module: '集中实践环节', nature: '集中实践', semester: 3),
    PlanCourse(code: 'Z01211225B', name: '深度学习实践▲', credits: 2.0, platform: '专业平台', module: '集中实践环节', nature: '集中实践', semester: 4),
    PlanCourse(code: 'Z01211226B', name: '大语言模型实践▲', credits: 2.0, platform: '专业平台', module: '集中实践环节', nature: '集中实践', semester: 5),
    PlanCourse(code: 'Z01211227B', name: '计算机视觉实践▲', credits: 2.0, platform: '专业平台', module: '集中实践环节', nature: '集中实践', semester: 5),
    PlanCourse(code: 'Z01211228B', name: '人工智能应用综合实训▲', credits: 6.0, platform: '专业平台', module: '集中实践环节', nature: '集中实践', semester: 6),
    PlanCourse(code: 'Z01211229B', name: '行业实习实践▲', credits: 4.0, platform: '专业平台', module: '集中实践环节', nature: '集中实践', semester: 7),
    PlanCourse(code: 'Z01211230B', name: '毕业设计★', credits: 7.5, platform: '专业平台', module: '集中实践环节', nature: '集中实践', semester: 8),

    // 四、能力拓展 - 专业拓展类选修 (13门可选, 最低修满 12.0 学分)
    PlanCourse(code: 'N01211201B', name: '程序设计进阶', credits: 2.0, platform: '能力拓展', module: '专业拓展类', nature: '选修', semester: 2),
    PlanCourse(code: 'N01211202B', name: '数字图像处理', credits: 3.0, platform: '能力拓展', module: '专业拓展类', nature: '选修', semester: 4),
    PlanCourse(code: 'N01211203B', name: 'ROS 机器人开发▲', credits: 3.0, platform: '能力拓展', module: '专业拓展类', nature: '选修', semester: 4),
    PlanCourse(code: 'N01211204B', name: '具身智能▲', credits: 2.5, platform: '能力拓展', module: '专业拓展类', nature: '选修', semester: 6),
    PlanCourse(code: 'N01211205B', name: 'RAG 应用与实践▲', credits: 2.5, platform: '能力拓展', module: '专业拓展类', nature: '选修', semester: 6),
    PlanCourse(code: 'N01211206B', name: '大模型智能测试技术▲', credits: 3.0, platform: '能力拓展', module: '专业拓展类', nature: '选修', semester: 6),
    PlanCourse(code: 'N01211207B', name: '复杂图像处理与理解', credits: 2.0, platform: '能力拓展', module: '专业拓展类', nature: '选修', semester: 6),
    PlanCourse(code: 'N01211208B', name: '项目设计与管理', credits: 2.0, platform: '能力拓展', module: '专业拓展类', nature: '选修', semester: 6),
    PlanCourse(code: 'N01211209B', name: '人工智能伦理与法律', credits: 1.0, platform: '能力拓展', module: '专业拓展类', nature: '选修', semester: 7),
    PlanCourse(code: 'N01211210B', name: '粮食信息分析与处理', credits: 2.0, platform: '能力拓展', module: '专业拓展类', nature: '选修', semester: 7),
    PlanCourse(code: 'N01211211B', name: '高级机器学习', credits: 2.0, platform: '能力拓展', module: '专业拓展类', nature: '选修', semester: 7),
    PlanCourse(code: 'N01211212B', name: '数据安全与隐私保护', credits: 2.0, platform: '能力拓展', module: '专业拓展类', nature: '选修', semester: 7),
    PlanCourse(code: 'N01211213B', name: '增强现实技术与应用', credits: 2.0, platform: '能力拓展', module: '专业拓展类', nature: '选修', semester: 7),

    // 四、能力拓展 - 创新创业实践类 (2门必修, 2.0 学分)
    PlanCourse(code: 'N01211214B', name: '创新创业实践', credits: 1.0, platform: '能力拓展', module: '创新创业实践类', nature: '集中实践', semester: 6),
    PlanCourse(code: 'N01211215B', name: '科研训练实践', credits: 1.0, platform: '能力拓展', module: '创新创业实践类', nature: '集中实践', semester: 6),
  ];
}
