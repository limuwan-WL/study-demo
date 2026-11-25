// ==================== 学科课程数据模型 ====================
// 20 门学科：小学(语文/数学/英语·柔和风)、初中(7科·专业简约风)、大学(10科·备考复习风)
// 每科配置：筛选维度(年级/版本)、模块、主题色、导航/筛选/卡片/列表/交互风格变体

import { ContentUnit, unitsOf } from './SubjectContent'

export type Stage = 'primary' | 'middle' | 'uni'

export class SubjectConfig {
  id: string = ''
  name: string = ''
  stage: Stage = 'primary'
  page: string = '' // 路由页
  c1: string = '' // 主题色（渐变起）
  c2: string = '' // 主题色（渐变止/深色）
  navStyle: number = 0 // 顶部导航变体 0渐变大标题 1白色极简+下划线 2实色条+徽标 3深色学术条
  filterStyle: number = 0 // 筛选变体 0柔和圆药丸 1下划线标签 2描边方标签 3实色圆片
  cardStyle: number = 0 // 卡片变体 0横幅图卡 1顶部色条卡 2左色条列表行 3时间轴卡 4备考密集卡 5深色代码卡
  columns: number = 2 // 瀑布流列数
  f1Label: string = ''
  f1: string[] = []
  f2Label: string = ''
  f2: string[] = []
  modules: string[] = []
  topics: string[] = []

  constructor(id: string, name: string, stage: Stage, page: string, c1: string, c2: string,
    navStyle: number, filterStyle: number, cardStyle: number, columns: number,
    f1Label: string, f1: string[], f2Label: string, f2: string[], modules: string[], topics: string[]) {
    this.id = id
    this.name = name
    this.stage = stage
    this.page = page
    this.c1 = c1
    this.c2 = c2
    this.navStyle = navStyle
    this.filterStyle = filterStyle
    this.cardStyle = cardStyle
    this.columns = columns
    this.f1Label = f1Label
    this.f1 = f1
    this.f2Label = f2Label
    this.f2 = f2
    this.modules = modules
    this.topics = topics
  }
}

export function stageName(stage: Stage): string {
  if (stage === 'primary') {
    return '小学'
  }
  if (stage === 'middle') {
    return '初中'
  }
  return '大学'
}

const PRIMARY_TEACHERS: string[] = ['王老师', '李老师', '陈老师']
const MIDDLE_TEACHERS: string[] = ['刘老师', '赵老师', '周老师']
const UNI_TEACHERS: string[] = ['林教授', '吴教授', '郑教授']

function teachersOf(stage: Stage): string[] {
  if (stage === 'primary') {
    return PRIMARY_TEACHERS
  }
  if (stage === 'middle') {
    return MIDDLE_TEACHERS
  }
  return UNI_TEACHERS
}

function g(n: number): string {
  return `${n}年级`
}

function grades(from: number, to: number): string[] {
  let list: string[] = []
  for (let i = from; i <= to; i++) {
    list.push(g(i))
  }
  return list
}

export const SUBJECTS: SubjectConfig[] = [
  // ==================== 小学 · 柔和风 ====================
  new SubjectConfig('chinese', '语文', 'primary', 'pages/subjects/ChinesePage', '#F2724B', '#E8553A',
    0, 0, 0, 2, '年级', grades(1, 6), '教材版本', ['部编版'],
    ['课文精讲', '生字词', '同步课件', '阅读理解', '作文', '背诵打卡', '单元测'],
    ['《秋天的雨》课文精读', '《背影》名篇赏析', '记叙文写作提速', '《论语》十二章文言串讲', '非连续性文本阅读技巧', '古诗鉴赏与默写']),
  new SubjectConfig('math', '数学', 'primary', 'pages/subjects/MathPage', '#4FA8F7', '#2F7FE0',
    0, 0, 1, 2, '年级', grades(1, 6), '教材版本', ['人教版', '苏教版', '北师大版'],
    ['知识点精讲', '口算', '应用题', '思维训练', '公式', '习题'],
    ['分数应用题突破', '鸡兔同笼与假设法', '圆柱与圆锥专题', '简便运算技巧大全', '行程问题画图法', '几何图形拼接专题']),
  // 🌟 英语模块：进入专属英语学习页（L1~L4 分级训练 + 互动练习 + 课程知识链接）
  new SubjectConfig('english', '英语', 'primary', 'pages/subjects/EnglishPage', '#4C8BF5', '#3F7EF6',
    0, 0, 0, 2, '年级', grades(3, 6), '教材版本', ['人教版PEP', '外研版', '译林版'],
    ['分级训练', '单词记忆', '语法练习', '口语跟读', '听力训练'],
    ['字母与音标', '高频词汇', '日常问候', '情景会话', '基础时态', '听说训练']),
  // 🌟 初中英语：接在小学英语之后，7~9 年级人教版同步课程，沿用英语学习页结构
  new SubjectConfig('englishmiddle', '英语', 'middle', 'pages/subjects/EnglishMiddlePage', '#4C8BF5', '#3F7EF6',
    1, 1, 1, 2, '年级', [g(7), g(8), g(9)], '教材版本', ['人教版', '外研版', '译林版'],
    ['分级训练', '单词记忆', '语法练习', '口语跟读', '听力训练'],
    ['时态综合', '从句入门', '中考阅读', '情景会话', '写作训练', '听力突破']),

  // ==================== 初中 · 专业简约风 ====================
  new SubjectConfig('physics', '物理', 'middle', 'pages/subjects/PhysicsPage', '#4A7BB5', '#2F5A8F',
    1, 1, 1, 2, '年级', [g(8), g(9)], '教材版本', ['人教版'],
    ['课堂精讲', '实验视频', '公式', '计算题专项', '真题'],
    ['力与运动关系精讲', '压强与浮力专项', '电路与欧姆定律', '电功率计算突破', '凸透镜成像规律', '质量与密度实验']),
  new SubjectConfig('chemistry', '化学', 'middle', 'pages/subjects/ChemistryPage', '#26A69A', '#00796B',
    2, 2, 2, 1, '年级', [g(9)], '教材版本', ['人教版'],
    ['精讲', '实验', '化学方程式', '推断题', '真题'],
    ['走进化学实验室', '分子和原子', '质量守恒定律', '金属活动性顺序', '酸碱盐中和反应', '化学方程式配平']),
  new SubjectConfig('history', '历史', 'middle', 'pages/subjects/HistoryPage', '#B07C3E', '#8A5D2A',
    3, 3, 3, 1, '年级', [g(7), g(8), g(9)], '教材版本', ['人教版'],
    ['课程精讲', '历史时间轴', '材料题', '背诵提纲', '真题'],
    ['中国古代政治制度', '近代化探索历程', '辛亥革命与民国', '新民主主义革命起点', '资本主义时代曙光', '两次世界大战比较']),
  new SubjectConfig('biology', '生物', 'middle', 'pages/subjects/BiologyPage', '#5BAF5F', '#3E8A44',
    1, 0, 1, 2, '年级', [g(7), g(8)], '教材版本', ['人教版'],
    ['课堂精讲', '结构图', '实验讲解', '识图专项', '背诵清单', '真题'],
    ['细胞的结构与功能', '光合作用与呼吸作用', '人体血液循环系统', '生态系统的组成', '生物的遗传与变异', '显微镜使用与装片制作']),
  new SubjectConfig('morality', '道德与法治', 'middle', 'pages/subjects/MoralityPage', '#C75B5B', '#A93E3E',
    2, 2, 2, 1, '年级', [g(7), g(8), g(9)], '教材版本', ['人教版'],
    ['课程精讲', '核心考点', '辨析题', '材料大题', '时政拓展', '真题'],
    ['友谊与成长同行', '师长情谊与感恩', '生命教育专题', '法律就在我们身边', '公民权利与义务', '社会责任与担当']),
  new SubjectConfig('geography', '地理', 'middle', 'pages/subjects/GeographyPage', '#4AA9BC', '#2E8698',
    1, 1, 1, 2, '年级', [g(7), g(8)], '教材版本', ['人教版'],
    ['课堂精讲', '识图填图', '地形图', '气候专项', '地图练习', '真题'],
    ['地球的运动与四季', '等高线地形图判读', '天气与气候', '世界的语言与宗教', '中国的自然环境', '河流与湖泊']),

  // ==================== 大学 · 备考复习风 ====================
  new SubjectConfig('advmath', '高等数学', 'uni', 'pages/subjects/AdvMathPage', '#5C6BC0', '#3949AB',
    2, 2, 4, 2, '分册', ['上册', '下册'], '考研方向', ['考研数一', '考研数二', '考研数三'],
    ['知识点精讲', '公式大全', '典型例题', '专项习题', '期末卷', '考研真题'],
    ['极限与连续精讲', '导数与微分技巧', '中值定理证明题', '不定积分换元法', '定积分应用专题', '级数敛散性判别', '多元函数微分', '二重积分计算']),
  new SubjectConfig('uniphysics', '大学物理', 'uni', 'pages/subjects/UniPhysicsPage', '#6B7C99', '#4C5B75',
    1, 2, 4, 2, '模块方向', ['力学', '热学', '电磁学', '光学', '近代物理'], '', [],
    ['精讲', '模型讲解', '公式', '计算题', '实验要点', '期末真题'],
    ['刚体转动惯量', '简谐运动与机械波', '高斯定理应用', '安培力与洛伦兹力', '光的干涉与衍射', '狭义相对论基础']),
  new SubjectConfig('unichem', '大学化学', 'uni', 'pages/subjects/UniChemistryPage', '#8E6FC8', '#6A4AA8',
    2, 2, 2, 1, '分支', ['无机化学', '有机化学', '分析化学', '物理化学'], '', [],
    ['机理讲解', '方程式', '计算题', '实验要点', '习题', '真题'],
    ['化学键与晶体结构', '氧化还原配平技巧', '酸碱滴定曲线', '原电池与电解池', 'SN1/SN2反应机理', '配合物价键理论']),
  new SubjectConfig('csbasic', '计算机基础', 'uni', 'pages/subjects/CSBasicsPage', '#4A5A6E', '#2E3A4A',
    3, 2, 5, 1, '课程方向', ['计算机导论', '操作系统', '计算机网络', '数据结构'], '', [],
    ['概念精讲', '原理图', '简答题库', '复习提纲'],
    ['计算机发展史与分类', '进程与线程辨析', 'OSI与TCP/IP模型', 'TCP三次握手', '时间复杂度与空间复杂度', '存储器层次结构']),
  new SubjectConfig('clang', 'C语言程序设计', 'uni', 'pages/subjects/CProgrammingPage', '#4C8BF6', '#2F62C4',
    3, 2, 5, 2, '知识专题', ['基础语法', '数组指针', '函数', '结构体', '文件操作'], '', [],
    ['语法精讲', '代码示例', '编程题', '错题解析'],
    ['指针与地址精讲', '二维数组与行指针', '函数递归调用', '结构体与链表', '文件读写fopen家族', 'malloc与内存泄漏']),
  new SubjectConfig('modernchinese', '现代汉语', 'uni', 'pages/subjects/ModernChinesePage', '#BA6878', '#9C4E62',
    1, 1, 2, 1, '知识板块', ['语音', '文字', '词汇', '语法', '修辞'], '', [],
    ['精讲', '易混辨析', '简答练习', '背诵考点', '真题'],
    ['声母韵母辨音', '汉字造字法', '词义的扩大与缩小', '层次分析法切分句子', '比喻与借喻辨析', '量词的语法特征']),
  new SubjectConfig('psychology', '普通心理学', 'uni', 'pages/subjects/PsychologyPage', '#C77DA4', '#A65682',
    0, 0, 1, 2, '研究领域', ['认知', '情绪', '动机', '人格', '发展心理'], '', [],
    ['理论精讲', '经典实验', '名词解释', '论述专项', '考研考点'],
    ['注意的双加工理论', '记忆的三级加工', '经典条件反射实验', '马斯洛需要层次', '皮亚杰认知发展阶段', '艾森克人格理论']),
  new SubjectConfig('microecon', '微观经济学', 'uni', 'pages/subjects/MicroEconomicsPage', '#3D9A6A', '#2A7A50',
    2, 2, 4, 2, '理论专题', ['供求理论', '效用论', '生产成本', '市场结构', '博弈论'], '', [],
    ['理论精讲', '图形分析', '公式推导', '计算题', '论述题'],
    ['需求曲线与弹性', '无差异曲线与预算线', '规模报酬与成本曲线', '完全竞争与垄断比较', '古诺模型与纳什均衡', '价格歧视三种类型']),
  // 🌟 大学韩语：课程目录复用现有 8 门韩语分级课程（8 门 × 5 课时 = 40 课时）
  new SubjectConfig('korean', '韩语', 'uni', 'pages/subjects/KoreanPage', '#8B5CF6', '#6D3FD1',
    2, 2, 4, 2, '等级', ['初级', '中级', '高级'], '', [],
    ['分级训练', '单词记忆', '语法练习', '口语跟读', '听力训练'],
    ['韩语发音', '生活词汇', '校园会话', '职场表达', '篇章阅读', '翻译实务']),
  // 🌟 大学日语：课程目录按英语的 8 门 × 5 课时结构组织
  new SubjectConfig('japanese', '日语', 'uni', 'pages/subjects/JapanesePage', '#E85D75', '#C23A55',
    2, 2, 4, 2, '等级', ['初级', '中级', '高级'], '', [],
    ['分级训练', '单词记忆', '语法练习', '口语跟读', '听力训练'],
    ['五十音入门', '日常词汇', '基础语法', '校园会话', '职场表达', '翻译实务'])
]

export function subjectById(id: string): SubjectConfig {
  let s = SUBJECTS.find((x: SubjectConfig) => x.id === id)
  return s !== undefined ? s : SUBJECTS[0]
}

export function subjectsByStage(stage: Stage): SubjectConfig[] {
  return SUBJECTS.filter((x: SubjectConfig) => x.stage === stage)
}

// ==================== 课程卡片数据（按筛选确定性生成） ====================

export class SubjectCourse {
  id: string = ''
  title: string = ''
  subjectId: string = ''
  subjectName: string = ''
  stage: Stage = 'primary'
  c1: string = ''
  c2: string = ''
  module: string = ''
  filter1: string = ''
  filter2: string = ''
  teacher: string = ''
  lessons: number = 0
  minutes: number = 0
  heat: number = 0
  tag: string = ''
  progress: number = 0 // 备考风展示的模拟学习进度
  desc: string = ''
}

// 🌟 稳定的字符串散列：让不同筛选组合生成不同的课程内容（切换年级/版本/模块即可看到变化）
function strHash(s: string): number {
  let h = 0
  for (let i = 0; i < s.length; i++) {
    h = (h * 31 + s.charCodeAt(i)) % 9973
  }
  return h
}

// ==================== 兜底主题池 ====================
// 🌟 实际课程内容来自 SubjectContent.CURRICULUM（按「学科+年级/分册」维护）；
// 这里只在该学科未配置对应年级时兜底，避免出现空列表。
const TOPIC_GROUPS: Record<string, string[]> = {
  // 语文（小学，按年级）
  'chinese|一年级': ['拼音与识字', '《秋天》课文精读', '看图写话入门', '古诗《咏鹅》', '生字笔顺', '口语交际'],
  'chinese|二年级': ['《小蝌蚪找妈妈》精读', '量词与词语搭配', '看图写话', '古诗《赠汪伦》', '造句训练', '短文阅读'],
  'chinese|三年级': ['《秋天的雨》课文精读', '段落大意概括', '习作：写一个人', '古诗《山行》', '修改病句', '词语积累'],
  'chinese|四年级': ['《观潮》课文精读', '说明文阅读', '习作：写一件事', '文言启蒙《精卫填海》', '句子衔接', '非连续性文本'],
  'chinese|五年级': ['《慈母情深》精读', '散文阅读技巧', '习作：写景', '《论语》十二章文言串讲', '说明方法辨析', '古诗鉴赏与默写'],
  'chinese|六年级': ['《鲁滨逊漂流记》梗概', '记叙文写作提速', '《背影》名篇赏析', '非连续性文本阅读技巧', '综合性学习', '小升初真题'],
  // 数学（小学，按年级）
  'math|一年级': ['20以内加减法', '认识图形', '位置与顺序', '口算天天练', '简单应用题', '人民币的认识'],
  'math|二年级': ['100以内加减法', '表内乘法', '长度单位', '认识时间', '两步计算应用题', '图形拼组'],
  'math|三年级': ['多位数乘法', '分数的初步认识', '长方形与正方形周长', '时分秒', '归一应用题', '面积初步'],
  'math|四年级': ['大数的认识', '三位数乘法', '平行四边形与梯形', '运算律', '行程问题画图法', '条形统计图'],
  'math|五年级': ['小数乘除法', '分数加减法', '鸡兔同笼与假设法', '多边形的面积', '方程初步', '因数与倍数'],
  'math|六年级': ['分数应用题突破', '圆柱与圆锥专题', '比与比例', '百分数与折扣', '几何图形拼接专题', '简便运算技巧大全'],
  // 物理（初中）
  'physics|8年级': ['力与运动关系精讲', '压强与浮力专项', '质量与密度实验', '声现象与光现象', '物态变化', '简单机械与功'],
  'physics|9年级': ['电路与欧姆定律', '电功率计算突破', '凸透镜成像规律', '电与磁', '能源与能量守恒', '家庭电路安全'],
  // 化学（初中）
  'chemistry|9年级': ['走进化学实验室', '分子和原子', '质量守恒定律', '金属活动性顺序', '酸碱盐中和反应', '化学方程式配平'],
  // 历史
  'history|7年级': ['中国古代政治制度', '夏商周与春秋战国', '秦汉大一统', '丝绸之路与对外交流', '隋唐盛世', '宋元明清制度演变'],
  'history|8年级': ['近代化探索历程', '鸦片战争与不平等条约', '辛亥革命与民国', '新民主主义革命起点', '抗日战争', '解放战争'],
  'history|9年级': ['资本主义时代曙光', '两次世界大战比较', '冷战格局', '世界多极化', '工业革命影响', '全球化与中国'],
  // 生物
  'biology|7年级': ['细胞的结构与功能', '显微镜使用与装片制作', '生物圈中的绿色植物', '光合作用与呼吸作用', '人体营养与消化', '人体呼吸与循环'],
  'biology|8年级': ['人体血液循环系统', '生态系统的组成', '生物的遗传与变异', '动物的运动与行为', '细菌真菌与疾病', '健康与免疫'],
  // 道德与法治
  'morality|7年级': ['友谊与成长同行', '师长情谊与感恩', '生命教育专题', '认识自我', '集体生活', '情绪管理'],
  'morality|8年级': ['法律就在我们身边', '公民权利与义务', '遵守社会规则', '社会责任与担当', '网络生活', '国家利益'],
  'morality|9年级': ['富强与创新', '民主与法治', '守望精神家园', '与世界共发展', '时政热点', '中考考点'],
  // 地理
  'geography|7年级': ['地球的运动与四季', '等高线地形图判读', '天气与气候', '世界的语言与宗教', '大洲与大洋', '海陆变迁'],
  'geography|8年级': ['中国的自然环境', '河流与湖泊', '中国的农业与工业', '人口与城市', '交通运输', '区域差异'],
  // 高等数学（分册）
  'advmath|上册': ['极限与连续精讲', '导数与微分技巧', '中值定理证明题', '不定积分换元法', '定积分应用专题', '函数单调性与极值'],
  'advmath|下册': ['级数敛散性判别', '多元函数微分', '二重积分计算', '曲线与曲面积分', '微分方程求解', '傅里叶级数'],
  // 大学物理（模块方向）
  'uniphysics|力学': ['刚体转动惯量', '简谐运动与机械波', '动量守恒与碰撞', '牛顿定律与受力分析', '刚体定轴转动', '功与能量守恒'],
  'uniphysics|热学': ['热力学第一定律', '理想气体状态方程', '气体动理论', '熵与热力学第二定律', '循环过程与效率', '热量传递方式'],
  'uniphysics|电磁学': ['高斯定理应用', '安培力与洛伦兹力', '静电场与电势', '电容与电场能量', '电磁感应与法拉第定律', '麦克斯韦方程组'],
  'uniphysics|光学': ['光的干涉与衍射', '几何光学成像', '光的偏振', '双缝干涉定量分析', '薄膜干涉应用', '光的量子性'],
  'uniphysics|近代物理': ['狭义相对论基础', '量子力学初步', '光电效应与康普顿散射', '波粒二象性', '原子能级与光谱', '德布罗意波'],
  // 大学化学（分支）
  'unichem|无机化学': ['化学键与晶体结构', '配合物价键理论', '元素周期律', '酸碱理论', '氧化还原反应', '主族元素性质'],
  'unichem|有机化学': ['SN1/SN2反应机理', '有机合成路线设计', '芳香烃亲电取代', '醇酚醚性质', '羰基加成反应', '立体化学与手性'],
  'unichem|分析化学': ['酸碱滴定曲线', '氧化还原滴定', '配位滴定原理', '误差与数据处理', '分光光度法', '色谱分析基础'],
  'unichem|物理化学': ['原电池与电解池', '化学热力学', '化学动力学', '相平衡与相图', '表面现象与胶体', '电化学应用'],
  // 计算机基础（课程方向）
  'csbasic|计算机导论': ['计算机发展史与分类', '存储器层次结构', '数据的二进制表示', '冯诺依曼体系结构', '操作系统概述', '编程语言发展'],
  'csbasic|操作系统': ['进程与线程辨析', '进程调度算法', '死锁与银行家算法', '虚拟内存与页面置换', '文件系统结构', '并发与同步'],
  'csbasic|计算机网络': ['OSI与TCP/IP模型', 'TCP三次握手', 'IP地址与子网划分', 'HTTP与HTTPS', '路由与交换', '网络拥塞控制'],
  'csbasic|数据结构': ['时间复杂度与空间复杂度', '栈与队列应用', '二叉树的遍历', '图的存储与遍历', '排序算法对比', '哈希表冲突处理'],
  // C 语言（知识专题）
  'clang|基础语法': ['C语言数据类型', '运算符与优先级', '控制流程语句', '格式化输入输出', '预处理指令', '常见语法错误'],
  'clang|数组指针': ['指针与地址精讲', '二维数组与行指针', '数组作为函数参数', '指针与字符串', '函数指针应用', 'malloc与内存泄漏'],
  'clang|函数': ['函数递归调用', '函数声明与定义', '参数传递机制', '作用域与生命周期', '内联函数与宏', '模块化编程'],
  'clang|结构体': ['结构体与链表', '结构体内存布局', '联合体与枚举', '链表增删改查', '结构体数组排序', '类型别名typedef'],
  'clang|文件操作': ['文件读写 fopen 家族', '文本文件与二进制文件', '文件定位 fseek', '错误处理与 feof', '综合文件管理项目', '配置读写实战'],
  // 现代汉语（知识板块）
  'modernchinese|语音': ['声母韵母辨音', '声调与变调', '儿化与轻声', '音节结构分析', '语音规范化', '朗读技巧'],
  'modernchinese|文字': ['汉字造字法', '汉字结构类型', '形声字分析', '错别字辨析', '汉字简化规律', '字体与书法'],
  'modernchinese|词汇': ['词义的扩大与缩小', '同义词与反义词', '量词的语法特征', '熟语与成语', '词汇构成方式', '新词语现象'],
  'modernchinese|语法': ['层次分析法切分句子', '词类与句法功能', '句子成分分析', '复句类型', '语序与搭配', '常见语法病句'],
  'modernchinese|修辞': ['比喻与借喻辨析', '排比与对偶', '拟人与夸张', '反复与设问', '修辞综合运用', '语体与风格'],
  // 普通心理学（研究领域）
  'psychology|认知': ['注意的双加工理论', '记忆的三级加工', '知觉的组织原则', '思维与问题解决', '语言加工机制', '认知负荷理论'],
  'psychology|情绪': ['情绪的两维模型', '情绪调节策略', '表情与情绪识别', '情绪与动机关系', '应激与应对', '正负情绪的功能'],
  'psychology|动机': ['马斯洛需要层次', '内在动机与外在动机', '成就动机理论', '自我决定理论', '目标设置理论', '动机冲突类型'],
  'psychology|人格': ['艾森克人格理论', '大五人格模型', '人格特质与测量', '人格形成因素', '心理防御机制', '人格障碍概览'],
  'psychology|发展心理': ['皮亚杰认知发展阶段', '埃里克森心理社会发展', '依恋类型', '语言发展里程碑', '青少年心理特点', '老年认知变化'],
  // 微观经济学（理论专题）
  'microecon|供求理论': ['需求曲线与弹性', '供给曲线与弹性', '均衡价格形成', '价格管制影响', '蛛网模型', '消费者剩余'],
  'microecon|效用论': ['无差异曲线与预算线', '边际效用递减', '消费者均衡', '序数效用与基数效用', '显示性偏好', '替代与互补'],
  'microecon|生产成本': ['规模报酬与成本曲线', '短期成本分类', '长期成本与规模经济', '边际成本与平均成本', '机会成本', '成本最小化'],
  'microecon|市场结构': ['完全竞争与垄断比较', '垄断厂商定价', '寡头市场特征', '垄断竞争', '市场进入壁垒', '效率与福利分析'],
  'microecon|博弈论': ['古诺模型与纳什均衡', '囚徒困境', '零和与非零和博弈', '序贯博弈与策略', '信号博弈', '博弈论应用']
};

// 🌟 按筛选条件取主题池；没有配置时回落到学科默认主题
export function topicsFor(cfg: SubjectConfig, f1: string): string[] {
  let group = TOPIC_GROUPS[`${cfg.id}|${f1}`]
  return group !== undefined ? group : cfg.topics
}

// 🌟 方向类筛选（非年级）会在标题前缀，让筛选结果一眼对应
function isDirectionLabel(label: string): boolean {
  return label !== '年级' && label !== '教材版本'
}

// 🌟 一条课程种子：来自哪个模块 + 该模块下的真实主题
class CourseSeed {
  module: string = ''
  topic: string = ''

  constructor(module: string, topic: string) {
    this.module = module
    this.topic = topic
  }
}

// 🌟 按「年级/分册 + 模块」取课程种子，模块切换后内容真实变化
function seedsFor(cfg: SubjectConfig, f1: string, mod: string): CourseSeed[] {
  let seeds: CourseSeed[] = []
  let units: ContentUnit[] = unitsOf(cfg.id, f1)
  if (units.length > 0) {
    if (mod !== '全部') {
      let hit: ContentUnit | undefined = units.find((x: ContentUnit) => x.module === mod)
      if (hit !== undefined) {
        hit.topics.forEach((t: string) => {
          seeds.push(new CourseSeed(mod, t))
        })
        return seeds
      }
      // 该年级未配置此模块时，用兜底主题池保证列表不为空
      topicsFor(cfg, f1).forEach((t: string) => {
        seeds.push(new CourseSeed(mod, t))
      })
      return seeds
    }
    // 🌟 「全部」时各模块轮流取一条，卡片模块标签与标题始终对应
    let depth = 0
    units.forEach((x: ContentUnit) => {
      depth = Math.max(depth, x.topics.length)
    })
    for (let k = 0; k < depth; k++) {
      units.forEach((x: ContentUnit) => {
        if (k < x.topics.length) {
          seeds.push(new CourseSeed(x.module, x.topics[k]))
        }
      })
    }
    return seeds
  }
  let names: string[] = mod === '全部' ? cfg.modules : [mod]
  names.forEach((m: string) => {
    topicsFor(cfg, f1).forEach((t: string) => {
      seeds.push(new CourseSeed(m, t))
    })
  })
  return seeds
}

// 🌟 确定性生成：同筛选组合结果稳定，tick 用于下拉刷新轮换内容
export function subjectCourses(cfg: SubjectConfig, f1: string, f2: string, mod: string, tick: number): SubjectCourse[] {
  let list: SubjectCourse[] = []
  let teachers = teachersOf(cfg.stage)
  let useF2 = cfg.f2.length > 0
  let seeds: CourseSeed[] = seedsFor(cfg, f1, mod)
  if (seeds.length === 0) {
    return list
  }
  let count = Math.min(12, seeds.length)
  let off = tick % seeds.length
  for (let i = 0; i < count; i++) {
    let seed = seeds[(i + off) % seeds.length]
    let h = strHash(`${cfg.id}_${f1}_${f2}_${seed.module}_${seed.topic}`)
    let c = new SubjectCourse()
    c.id = `${cfg.id}_${i}_${tick}_${f1}_${f2}_${seed.module}`
    // 🌟 方向类筛选在标题中显式带上方向名，年级类只展示主题（年级已在描述中出现）
    if (isDirectionLabel(cfg.f1Label) && f1 !== '') {
      c.title = `${f1}｜${seed.topic}`
    } else {
      c.title = seed.topic
    }
    c.subjectId = cfg.id
    c.subjectName = cfg.name
    c.stage = cfg.stage
    c.c1 = cfg.c1
    c.c2 = cfg.c2
    c.module = seed.module
    c.filter1 = f1
    c.filter2 = useF2 ? f2 : ''
    c.teacher = teachers[h % teachers.length]
    c.lessons = 8 + (h % 13)
    c.minutes = 20 + (h % 26)
    c.heat = 600 + (h % 6200)
    if (seed.module.indexOf('真题') >= 0) {
      c.tag = '真题'
    } else if (seed.module.indexOf('背诵') >= 0 || seed.module.indexOf('打卡') >= 0) {
      c.tag = '打卡'
    } else if (h % 3 === 0) {
      c.tag = '精品'
    } else {
      c.tag = '免费'
    }
    c.progress = 10 + (h % 86)
    c.desc = `${cfg.name}·${seed.module} | ${f1}${c.filter2 !== '' ? ' ' + c.filter2 : ''}：${seed.topic}，共 ${c.lessons} 讲，每讲约 ${c.minutes} 分钟，由${c.teacher}主讲。`
    list.push(c)
  }
  return list
}

// 🌟 课程详情：按课程生成章节列表
export class CourseChapter {
  index: number = 0
  title: string = ''
  minutes: number = 0
  free: boolean = false

  constructor(index: number, title: string, minutes: number, free: boolean) {
    this.index = index
    this.title = title
    this.minutes = minutes
    this.free = free
  }
}

// 🌟 章节结构按「模块类型」变化：精讲 / 公式 / 计算题 / 实验 / 真题 / 背诵 / 识图 / 模型 / 辨析 …
// 不再是「第N讲 + 循环主题」的同一套模板
function chapterParts(module: string): string[] {
  if (module.indexOf('实验') >= 0) {
    return ['实验原理与器材', '操作步骤演示', '数据记录与处理', '误差分析', '实验报告撰写', '拓展实验']
  }
  if (module.indexOf('真题') >= 0 || module.indexOf('期末卷') >= 0 || module.indexOf('单元测') >= 0) {
    return ['考点分布扫描', '命题规律解读', '典型真题精讲', '答题模板', '限时模拟训练', '错题复盘']
  }
  if (module.indexOf('背诵') >= 0 || module.indexOf('打卡') >= 0) {
    return ['知识框架速记', '分块记忆', '默写检验', '易错点提醒', '串背复习', '限时挑战']
  }
  if (module.indexOf('识图') >= 0 || module.indexOf('结构图') >= 0 || module.indexOf('地形图') >= 0 ||
    module.indexOf('地图') >= 0 || module.indexOf('图形') >= 0 || module.indexOf('时间轴') >= 0) {
    return ['图表要素识读', '关键信息标注', '对比分析', '动手绘图练习', '综合应用', '读图专项测评']
  }
  if (module.indexOf('公式') >= 0 || module.indexOf('方程式') >= 0) {
    return ['公式推导', '适用条件', '典型套用', '变式训练', '易错提醒', '公式速查']
  }
  if (module.indexOf('计算') >= 0 || module.indexOf('习题') >= 0) {
    return ['读题建模', '解题方法选择', '分步求解', '规范书写', '同类变式', '限时训练']
  }
  if (module.indexOf('模型') >= 0) {
    return ['模型的建立', '参数与假设', '典型案例', '迁移应用', '模型局限', '综合演练']
  }
  if (module.indexOf('辨析') >= 0 || module.indexOf('易混') >= 0) {
    return ['概念界定', '常见误判', '对比分析', '实例辨析', '自测清单', '综合应用']
  }
  if (module.indexOf('简答') >= 0 || module.indexOf('论述') >= 0 || module.indexOf('材料') >= 0) {
    return ['题型特征', '材料阅读方法', '要点拆解', '规范作答', '高分范例', '模拟演练']
  }
  if (module.indexOf('错题') >= 0) {
    return ['错因归类', '典型错题重做', '思路纠正', '同类变式训练', '自测检验', '复盘总结']
  }
  if (module.indexOf('代码') >= 0 || module.indexOf('编程') >= 0) {
    return ['需求与思路', '核心代码演示', '边界条件处理', '调试与排错', '动手实现', '拓展挑战']
  }
  if (module.indexOf('课文') >= 0 || module.indexOf('阅读') >= 0) {
    return ['朗读与整体感知', '重点词句品析', '结构与写法梳理', '主题情感归纳', '课后习题精讲', '同主题拓展阅读']
  }
  if (module.indexOf('生字') >= 0 || module.indexOf('单词') >= 0 || module.indexOf('词汇') >= 0) {
    return ['字音字形辨析', '组词与搭配', '易错书写纠正', '语境中运用', '听写与默写', '词语积累拓展']
  }
  if (module.indexOf('作文') >= 0 || module.indexOf('习作') >= 0 || module.indexOf('写话') >= 0) {
    return ['审题与立意', '选材与构思', '提纲与结构', '片段示范修改', '全文润色', '佳作点评']
  }
  if (module.indexOf('口语') >= 0 || module.indexOf('听力') >= 0) {
    return ['语音语调打磨', '常用表达积累', '情景对话跟读', '听力精听训练', '口语输出练习', '综合演练']
  }
  // 精讲 / 课堂精讲 / 理论精讲 / 概念精讲 ……
  return ['概念导入', '重点剖析', '例题演示', '随堂练习', '方法归纳', '作业与小结']
}

// 🌟 课程标题去掉方向前缀，取真正的主题
function baseTopicOf(title: string, cfg: SubjectConfig): string {
  let idx = title.lastIndexOf('｜')
  if (idx >= 0 && idx < title.length - 1) {
    return title.substring(idx + 1).trim()
  }
  idx = title.lastIndexOf(' · ')
  if (idx >= 0 && idx < title.length - 3) {
    return title.substring(idx + 3).trim()
  }
  return title !== '' ? title : cfg.topics[0]
}

export function chaptersOf(cfg: SubjectConfig, course: SubjectCourse): CourseChapter[] {
  let list: CourseChapter[] = []
  let total = Math.min(course.lessons, 12)
  let base = baseTopicOf(course.title, cfg)
  let parts = chapterParts(course.module)
  let seed = strHash(course.module + base)
  for (let i = 0; i < total; i++) {
    let title = ''
    if (i === 0) {
      title = `课程导学：${base} 学习路径`
    } else if (i === total - 1 && total > 2) {
      title = `阶段测评：${base} 综合检测`
    } else {
      let k = i - 1
      let p = parts[(k + seed) % parts.length]
      // 🌟 课时超过章节类型数时，第二轮加「强化」前缀，避免出现完全相同的讲题名
      if (k >= parts.length) {
        p = `强化·${p}`
      }
      title = `第${i + 1}讲 ${p}｜${base}`
    }
    list.push(new CourseChapter(i + 1, title, course.minutes + (i % 5) * 3, i < 2))
  }
  return list
}
