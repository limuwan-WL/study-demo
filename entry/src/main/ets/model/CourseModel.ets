import { formatDate, formatTime } from './DataModel';
import { onLessonComplete, onPractice } from './GrowthModel';
import { EN_WORD_RAW } from './WordData';
import { EN_GRAMMAR_ALL } from './GrammarData';
import { KO_WORD_RAW } from './KoWordData';
import { KO_GRAMMAR_ALL } from './KoGrammarData';
import { ZH_WORD_RAW } from './ZhWordData';
import { ZH_GRAMMAR_ALL } from './ZhGrammarData';
import { JA_WORD_RAW } from './JaWordData';
import { JA_GRAMMAR_ALL } from './JaGrammarData';

// ==================== 学习语言 ====================

export class LangOption {
  key: string = '' // ko / en / zh / ja
  name: string = ''
  tag: string = '' // 圆形标签文字
  sample: string = '' // 语言示例
  color: string = ''

  constructor(key: string, name: string, tag: string, sample: string, color: string) {
    this.key = key
    this.name = name
    this.tag = tag
    this.sample = sample
    this.color = color
  }
}

export const LANGUAGES: LangOption[] = [
  new LangOption('ko', '韩语', '한', '안녕하세요', '#8B5CF6'),
  new LangOption('en', '英语', 'EN', 'Hello!', '#3F7EF6'),
  new LangOption('ja', '日语', 'あ', 'こんにちは', '#E85D75'),
  new LangOption('zh', '汉语', '中', '你好！', '#EF4444')
]

export function langByKey(key: string): LangOption {
  return LANGUAGES.find((l: LangOption) => l.key === key) ?? LANGUAGES[1]
}

// ==================== 分级课程体系 ====================

export class Lesson {
  title: string = ''
  constructor(title: string) {
    this.title = title
  }
}

export class Course {
  id: string = '' // 格式：{lang}_l{level}_{idx}
  level: number = 0 // 0~3 对应 L1~L4
  title: string = ''
  desc: string = ''
  color: string = ''
  lessons: Lesson[] = []

  constructor(id: string, level: number, title: string, desc: string, color: string, lessons: Lesson[]) {
    this.id = id
    this.level = level
    this.title = title
    this.desc = desc
    this.color = color
    this.lessons = lessons
  }
}

// 🌟 等级统一由经验值驱动，常量收口到 GrowthModel（此处 re-export 保持旧引用可用）
export { LEVEL_NAMES, LEVEL_COLORS } from './GrowthModel';

function mkLessons(titles: string[]): Lesson[] {
  let list: Lesson[] = []
  titles.forEach((t: string) => list.push(new Lesson(t)))
  return list
}

// 🌟 每种语言 4 个级别 × 2 门课程 × 5 节课；课程 id 带语言前缀，进度互不干扰
// 🌟 每门课程的课时都按「语言 + 等级 + 课程主题」单独编写，不再多种语言共用同一套标题
export function coursesOf(lang: string): Course[] {
  let list: Course[] = []
  let l = (titles: string[]): Lesson[] => mkLessons(titles)
  if (lang === 'ko') {
    list.push(new Course('ko_l0_0', 0, '韩语发音与问候', '从四十音到日常问候，零基础起步', '#55C873',
      l(['四十音：单元音', '四十音：辅音', '收音与连音规则', '问候与自我介绍', '数字与敬语称呼'])))
    list.push(new Course('ko_l0_1', 0, '生活词汇起步', '高频生活词汇轻松记', '#55C873',
      l(['家人与称谓', '韩餐与点单词汇', '校园与交通词汇', '颜色·数字·日期', '天气与季节表达'])))
    list.push(new Course('ko_l1_0', 1, '基础语法精讲', '助词、语尾与句型一站式通关', '#3F7EF6',
      l(['韩语句序与语尾', '主格助词 은/는', '宾格助词 을/를', '过去时 -았/었', '否定 안/지 않다'])))
    list.push(new Course('ko_l1_1', 1, '校园情景会话', '校园与生活场景开口说', '#3F7EF6',
      l(['校园问路对话', '食堂点餐对话', '便利店购物', '地铁公交换乘', '电话礼仪用语'])))
    list.push(new Course('ko_l2_0', 2, '进阶语法与阅读', '长句拆解与阅读策略', '#E8A33E',
      l(['连接词 -아서/어서', '定语形 -는/-은', '被动与使动', '新闻长句阅读', '段落写作入门'])))
    list.push(new Course('ko_l2_1', 2, '职场情景会话', '进阶场景流利表达', '#E8A33E',
      l(['面试自我介绍', '小组讨论发言', '旅行预订沟通', '韩语新闻听力', '主题演讲表达'])))
    list.push(new Course('ko_l3_0', 3, '高级专题精研', '学术与文学进阶', '#EF4444',
      l(['学术论文写作', '韩语文学选读', '中韩翻译实务', '敬语体系进阶', '专题研究设计'])))
    list.push(new Course('ko_l3_1', 3, '流利表达特训', '即兴到专业的高阶输出', '#EF4444',
      l(['即兴发言训练', '辩论与反驳', '商务邮件写作', '交替传译入门', '综合口译演练'])))
  } else if (lang === 'ja') {
    list.push(new Course('ja_l0_0', 0, '五十音与问候', '从五十音到日常问候，零基础起步', '#55C873',
      l(['五十音：平假名', '五十音：片假名', '浊音·半浊音与拗音', '问候与自我介绍', '数字与时间表达'])))
    list.push(new Course('ja_l0_1', 0, '日常词汇起步', '高频生活词汇轻松记', '#55C873',
      l(['家人与称谓', '饮食与点单', '校园与交通', '颜色·数字·日期', '天气与季节'])))
    list.push(new Course('ja_l1_0', 1, '基础语法精讲', '判断句、助词与用言活用一站式通关', '#3F7EF6',
      l(['判断句 です/ではありません', '指示词 これ/それ/あれ', '动词ます形', '过去时 ました/でした', '助词 は/が/を/に'])))
    list.push(new Course('ja_l1_1', 1, '校园情景会话', '校园与生活场景开口说', '#3F7EF6',
      l(['校园问路对话', '食堂点餐对话', '便利店购物', '电车公交换乘', '电话礼仪用语'])))
    list.push(new Course('ja_l2_0', 2, '进阶语法与阅读', 'て形句型与中篇阅读策略', '#E8A33E',
      l(['动词て形与句型', '形容词活用', '可能形与意志形', '中篇阅读策略', '段落写作入门'])))
    list.push(new Course('ja_l2_1', 2, '职场情景会话', '进阶场景流利表达', '#E8A33E',
      l(['面试自我介绍', '会议讨论发言', '旅行预订沟通', '日语新闻听力', '主题演讲表达'])))
    list.push(new Course('ja_l3_0', 3, '高级专题精研', '敬语、文学与翻译进阶', '#EF4444',
      l(['敬语体系进阶', '日语文学选读', '中日翻译实务', '学术写作结构', '专题研究设计'])))
    list.push(new Course('ja_l3_1', 3, '流利表达特训', '即兴到专业的高阶输出', '#EF4444',
      l(['即兴发言训练', '辩论与反驳', '商务邮件写作', '交替传译入门', '综合口译演练'])))
  } else if (lang === 'zh') {
    list.push(new Course('zh_l0_0', 0, '汉语拼音与问候', '拼音声调与日常问候入门', '#55C873',
      l(['声母 b p m f', '韵母与四声', '轻声与儿化', '问候与自我介绍', '数字与量词'])))
    list.push(new Course('zh_l0_1', 0, '生活词汇起步', '高频生活词汇轻松记', '#55C873',
      l(['家人与称谓', '饮食与点单', '校园与问路', '颜色·数字·日期', '天气与季节'])))
    list.push(new Course('zh_l1_0', 1, '基础语法精讲', '语序、量词与句型通关', '#3F7EF6',
      l(['基本语序与句子成分', '量词搭配', '了/着/过辨析', '疑问句与反问句', '比较句'])))
    list.push(new Course('zh_l1_1', 1, '校园情景会话', '校园与生活场景开口说', '#3F7EF6',
      l(['校园问路对话', '食堂点餐对话', '市场购物讲价', '公交地铁出行', '打电话与留言'])))
    list.push(new Course('zh_l2_0', 2, '进阶语法与阅读', '特殊句式与阅读策略', '#E8A33E',
      l(['把字句', '被字句', '趋向补语与结果补语', '长句阅读策略', '写作基础训练'])))
    list.push(new Course('zh_l2_1', 2, '职场情景会话', '进阶场景流利表达', '#E8A33E',
      l(['面试自我介绍', '课堂讨论发言', '旅行规划沟通', '中文新闻听力', '演讲表达训练'])))
    list.push(new Course('zh_l3_0', 3, '高级专题精研', '成语、古文与书面表达', '#EF4444',
      l(['成语与俗语运用', '文言文入门', '书面语与口语转换', '跨文化交际', '专题研究写作'])))
    list.push(new Course('zh_l3_1', 3, '流利表达特训', '即兴到专业的高阶输出', '#EF4444',
      l(['即兴发言', '辩论技巧', '商务沟通礼仪', '模拟主持', '综合表达演练'])))
  } else {
    list.push(new Course('en_l0_0', 0, '发音与问候', '音标入门与日常问候', '#55C873',
      l(['音标：元音与辅音', '拼读规则与重音', '问候与自我介绍', '数字·时间·日期', '课堂指令与礼貌用语'])))
    list.push(new Course('en_l0_1', 0, '日常词汇起步', '高频生活词汇轻松记', '#55C873',
      l(['家居与房间陈设', '超市购物与食材', '身体部位与就医', '交通标识与方向', '天气与穿衣搭配'])))
    list.push(new Course('en_l1_0', 1, '基础语法精讲', '时态、句型一站式通关', '#3F7EF6',
      l(['一般现在时', '一般过去时', '现在进行时', '疑问句与否定句', '介词与冠词'])))
    list.push(new Course('en_l1_1', 1, '校园情景会话', '校园与生活场景开口说', '#3F7EF6',
      l(['问路与指路', '餐厅点餐', '购物与讲价', '出行与交通', '电话与留言'])))
    list.push(new Course('en_l2_0', 2, '进阶语法与阅读', '从句与长难句拆解', '#E8A33E',
      l(['定语从句', '状语从句', '被动语态', '长难句拆解', '阅读策略与推断'])))
    list.push(new Course('en_l2_1', 2, '职场情景会话', '进阶场景流利表达', '#E8A33E',
      l(['面试自我介绍', '课堂讨论发言', '旅行计划沟通', '新闻要点复述', '小型演讲表达'])))
    list.push(new Course('en_l3_0', 3, '高级专题精研', '学术写作与文学欣赏', '#EF4444',
      l(['学术写作结构', '文献阅读与笔记', '翻译技巧', '跨文化交际', '研究方法入门'])))
    list.push(new Course('en_l3_1', 3, '流利表达特训', '即兴到专业的高阶输出', '#EF4444',
      l(['即兴发言', '辩论与反驳', '商务谈判', '模拟口译', '综合表达演练'])))
  }
  return list
}

// ==================== 互动学习内容库 ====================

export class WordItem {
  word: string = ''
  ipa: string = ''
  meaning: string = ''
  constructor(word: string, ipa: string, meaning: string) {
    this.word = word
    this.ipa = ipa
    this.meaning = meaning
  }
}

export class GrammarQ {
  question: string = ''
  options: string[] = []
  answer: number = 0
  explain: string = ''
  constructor(question: string, options: string[], answer: number, explain: string) {
    this.question = question
    this.options = options
    this.answer = answer
    this.explain = explain
  }
}

export class SpeakItem {
  text: string = ''
  translation: string = ''
  constructor(text: string, translation: string) {
    this.text = text
    this.translation = translation
  }
}

export class ListenItem {
  audioText: string = ''
  question: string = ''
  options: string[] = []
  answer: number = 0
  constructor(audioText: string, question: string, options: string[], answer: number) {
    this.audioText = audioText
    this.question = question
    this.options = options
    this.answer = answer
  }
}

// 🌟 单词库：各语种使用各自独立的词库数据文件（不共用数据）
export function wordBank(lang: string): WordItem[] {
  let raw: string[] = EN_WORD_RAW
  if (lang === 'ko') {
    raw = KO_WORD_RAW
  } else if (lang === 'ja') {
    raw = JA_WORD_RAW
  } else if (lang === 'zh') {
    raw = ZH_WORD_RAW
  }
  // 解析「单词|发音|释义」原始数据（按单词去重）
  let list: WordItem[] = []
  let seen: string[] = []
  raw.forEach((line: string) => {
    let parts = line.split('|')
    if (parts.length >= 3 && !seen.includes(parts[0])) {
      seen.push(parts[0])
      list.push(new WordItem(parts[0], parts[1], parts[2]))
    }
  })
  return list
}

// 🌟 语法题库：单选 + 解析（各语种使用各自独立的题库数据文件）
export function grammarBank(lang: string): GrammarQ[] {
  let raw: string[] = EN_GRAMMAR_ALL
  if (lang === 'ko') {
    raw = KO_GRAMMAR_ALL
  } else if (lang === 'ja') {
    raw = JA_GRAMMAR_ALL
  } else if (lang === 'zh') {
    raw = ZH_GRAMMAR_ALL
  }
  let list: GrammarQ[] = []
  raw.forEach((line: string) => {
    let parts = line.split('|')
    if (parts.length >= 4) {
      list.push(new GrammarQ(parts[0], parts[1].split(';'), Number(parts[2]), parts[3]))
    }
  })
  return list
}

// 🌟 跟读句库
export function speakBank(lang: string): SpeakItem[] {
  let list: SpeakItem[] = []
  if (lang === 'ko') {
    list.push(new SpeakItem('안녕하세요, 반갑습니다.', '你好，见到你很高兴。'))
    list.push(new SpeakItem('감사합니다.', '谢谢。'))
    list.push(new SpeakItem('어디에 가요?', '你去哪里？'))
    list.push(new SpeakItem('이거 주세요.', '请给我这个。'))
    list.push(new SpeakItem('한국어를 배우고 있어요.', '我正在学韩语。'))
    list.push(new SpeakItem('내일 봐요!', '明天见！'))
  } else if (lang === 'ja') {
    list.push(new SpeakItem('こんにちは、はじめまして。', '你好，初次见面。'))
    list.push(new SpeakItem('ありがとうございます。', '谢谢。'))
    list.push(new SpeakItem('駅はどこですか？', '车站在哪里？'))
    list.push(new SpeakItem('これをお願いします。', '请给我这个。'))
    list.push(new SpeakItem('日本語を勉強しています。', '我正在学习日语。'))
    list.push(new SpeakItem('また明日会いましょう。', '明天见。'))
  } else if (lang === 'zh') {
    list.push(new SpeakItem('你好，很高兴认识你。', 'Hello, nice to meet you.'))
    list.push(new SpeakItem('请问，图书馆在哪里？', 'Excuse me, where is the library?'))
    list.push(new SpeakItem('我每天早上七点起床。', 'I get up at seven every morning.'))
    list.push(new SpeakItem('一起吃午饭吧！', "Let's have lunch together!"))
    list.push(new SpeakItem('祝你学习进步！', 'Wish you progress in study!'))
    list.push(new SpeakItem('明天见！', 'See you tomorrow!'))
  } else {
    list.push(new SpeakItem('Good morning, everyone!', '大家早上好！'))
    list.push(new SpeakItem('Nice to meet you.', '很高兴见到你。'))
    list.push(new SpeakItem('Practice makes perfect.', '熟能生巧。'))
    list.push(new SpeakItem('Where is the library?', '图书馆在哪里？'))
    list.push(new SpeakItem('I would like a cup of coffee.', '我想要一杯咖啡。'))
    list.push(new SpeakItem('Have a nice day!', '祝你今天愉快！'))
  }
  return list
}

// 🌟 听力题库：先「播放」再答题
export function listenBank(lang: string): ListenItem[] {
  let list: ListenItem[] = []
  if (lang === 'ko') {
    list.push(new ListenItem('지금 몇 시예요?', '这句话在问什么？', ['几点了', '多少钱', '去哪里'], 0))
    list.push(new ListenItem('학교에 갑니다.', '说话人要去哪里？', ['公司', '学校', '家'], 1))
    list.push(new ListenItem('커피 좋아하세요?', '这句话在问什么？', ['要咖啡吗', '咖啡多少钱', '喜欢咖啡吗'], 2))
    list.push(new ListenItem('내일 만나요.', '什么时候见面？', ['今天', '明天', '昨天'], 1))
  } else if (lang === 'ja') {
    list.push(new ListenItem('今、何時ですか。', '这句话在问什么？', ['几点了', '多少钱', '去哪里'], 0))
    list.push(new ListenItem('学校へ行きます。', '说话人要去哪里？', ['公司', '学校', '家'], 1))
    list.push(new ListenItem('コーヒーが好きですか。', '这句话在问什么？', ['要咖啡吗', '咖啡多少钱', '喜欢咖啡吗'], 2))
    list.push(new ListenItem('明日会いましょう。', '什么时候见面？', ['今天', '明天', '昨天'], 1))
  } else if (lang === 'zh') {
    list.push(new ListenItem('今天星期三，明天我们有考试。', '什么时候考试？', ['今天', '明天', '后天'], 1))
    list.push(new ListenItem('我坐地铁去学校，大概要二十分钟。', '说话人怎么去学校？', ['地铁', '公交', '骑车'], 0))
    list.push(new ListenItem('图书馆早上八点开门。', '图书馆几点开门？', ['七点', '八点', '九点'], 1))
    list.push(new ListenItem('这份面条十二块，加鸡蛋十五块。', '加鸡蛋的面条多少钱？', ['十二块', '十五块', '二十块'], 1))
  } else {
    list.push(new ListenItem("The class begins at eight o'clock.", 'When does the class begin?', ['At 7:00', 'At 8:00', 'At 9:00'], 1))
    list.push(new ListenItem('I usually go to the library by bike.', 'How does the speaker go to the library?', ['By bike', 'By bus', 'On foot'], 0))
    list.push(new ListenItem('My favorite subject is English.', "What's the speaker's favorite subject?", ['Math', 'History', 'English'], 2))
    list.push(new ListenItem('There will be a meeting tomorrow afternoon.', 'When is the meeting?', ['Tomorrow afternoon', 'Tonight', 'Tomorrow morning'], 0))
  }
  return list
}

// ==================== 社区打卡 ====================

export class CheckinItem {
  id: string = ''
  author: string = ''
  content: string = ''
  lang: string = ''
  time: string = ''
  createdAt: number = 0
  likes: number = 0
  liked: boolean = false

  constructor(author: string, content: string, lang: string, createdAt: number) {
    this.id = Date.now().toString() + Math.random().toString()
    this.author = author
    this.content = content
    this.lang = lang
    this.createdAt = createdAt
    this.time = createdAt === 0 ? formatTime(new Date()) : formatStamp(createdAt)
  }
}

function formatStamp(ts: number): string {
  let d = new Date(ts)
  return `${formatDate(d).slice(5)} ${formatTime(d)}`
}

export function defaultCheckins(): CheckinItem[] {
  let now = Date.now()
  let list: CheckinItem[] = []
  list.push(new CheckinItem('学霸小李', '打卡 Day 12！今天背完 30 个韩语单词，坚持就是胜利～', 'ko', now - 3600000))
  list.push(new CheckinItem('李同学', '英语听力训练全对，继续加油！', 'en', now - 86400000))
  list.push(new CheckinItem('热心同学', '跟读了一个小时英语口语，舌头都顺了哈哈', 'en', now - 2 * 86400000))
  list.push(new CheckinItem('萌新报到', '第一节课打卡！中文声调有点难，慢慢来', 'zh', now - 3 * 86400000))
  return list
}

// ==================== 成就激励系统 ====================

export class Achievement {
  id: string = ''
  name: string = ''
  desc: string = ''
  icon: Resource
  color: string = ''

  constructor(id: string, name: string, desc: string, icon: Resource, color: string) {
    this.id = id
    this.name = name
    this.desc = desc
    this.icon = icon
    this.color = color
  }
}

export const ACHIEVEMENTS: Achievement[] = [
  new Achievement('a_first', '初出茅庐', '完成第 1 节课', $r('sys.symbol.star_fill'), '#E8B93E'),
  new Achievement('a_lesson10', '小有所成', '累计完成 10 节课', $r('sys.symbol.graduationcap'), '#8B5CF6'),
  new Achievement('a_word10', '词汇新星', '掌握 10 个单词', $r('sys.symbol.leaf_fill'), '#55C873'),
  new Achievement('a_word30', '词汇大师', '掌握 30 个单词', $r('sys.symbol.checkmark_circle'), '#14B8A6'),
  new Achievement('a_quiz', '语法达人', '语法练习一次全对', $r('sys.symbol.gamecontroller_fill'), '#6366F1'),
  new Achievement('a_listen', '顺风耳朵', '听力训练一次全对', $r('sys.symbol.face_smiling'), '#0EA5E9'),
  new Achievement('a_streak3', '持之以恒', '连续学习 3 天', $r('sys.symbol.flame_fill'), '#F97316'),
  new Achievement('a_checkin', '社区之星', '完成首次社区打卡', $r('sys.symbol.heart_fill'), '#EF4444')
]

// ==================== 练习批次轮换 ====================

// 🌟 每套练习题量：30 个（题库不足 30 时直接使用整库）
export const PRACTICE_BATCH: number = 30

// 🌟 批次方案：每个语种 / 每个模块一份，拥有独立的游标键、起始偏移与步长，
// 因此不同科目取到的句子互不相同，也不共用同一套切片参数
export class BatchPlan {
  cursorKey: string = ''
  lessonBase: number = 0
  lessonStride: number = 1

  constructor(cursorKey: string, lessonBase: number, lessonStride: number) {
    this.cursorKey = cursorKey
    this.lessonBase = lessonBase
    this.lessonStride = lessonStride
  }
}

export const BATCH_PLANS: Record<string, BatchPlan> = {
  'word_en': new BatchPlan('word_en', 0, 1),
  'grammar_en': new BatchPlan('grammar_en', 3, 1),
  'word_ko': new BatchPlan('word_ko', 7, 2),
  'grammar_ko': new BatchPlan('grammar_ko', 11, 2),
  'word_zh': new BatchPlan('word_zh', 15, 3),
  'grammar_zh': new BatchPlan('grammar_zh', 19, 3),
  'word_ja': new BatchPlan('word_ja', 23, 4),
  'grammar_ja': new BatchPlan('grammar_ja', 27, 4)
}

// 🌟 每轮题量：以英语为基准（单词 8、语法 5、口语 4、听力 3），日语/韩语与英语对齐；
// 汉语未在本次调整范围内，单词/语法仍保持原来的 30 题批次
export function practiceSize(kind: string, lang: string): number {
  let englishSize = kind === 'word' ? 8 : (kind === 'grammar' ? 5 : (kind === 'speak' ? 4 : 3))
  if (lang === 'en' || lang === 'ja' || lang === 'ko') {
    return englishSize
  }
  if (kind === 'speak' || kind === 'listen') {
    return englishSize
  }
  return PRACTICE_BATCH
}

export function planOf(kind: string, lang: string): BatchPlan {
  let key = `${kind}_${lang}`
  let plan = BATCH_PLANS[key]
  return plan === undefined ? new BatchPlan(key, 0, 1) : plan
}

// 🌟 自由练习取当前批次：游标持久化在 batchCursor（完成一批后 advanceBatchCursor 推进，下一轮换新题）
export function takeBatch<T>(all: T[], plan: BatchPlan, size: number = PRACTICE_BATCH): T[] {
  if (all.length <= size) {
    return all.slice()
  }
  let map = AppStorage.get<Record<string, number>>('batchCursor')
  let cur = map !== undefined && map[plan.cursorKey] !== undefined ? map![plan.cursorKey] : 0
  let start = (cur * size) % all.length
  let out: T[] = []
  for (let i = 0; i < size; i++) {
    out.push(all[(start + i) % all.length])
  }
  return out
}

// 🌟 完成一批后推进游标：下次练习切换到不同的一批，循环覆盖整个题库
export function advanceBatchCursor(plan: BatchPlan, total: number, size: number = PRACTICE_BATCH): void {
  if (total <= size) {
    return
  }
  let map = AppStorage.get<Record<string, number>>('batchCursor')
  let copy: Record<string, number> = {}
  if (map !== undefined) {
    Object.keys(map).forEach((k: string) => {
      copy[k] = map![k]
    })
  }
  let batchCount = Math.ceil(total / size)
  let cur = copy[plan.cursorKey] !== undefined ? copy[plan.cursorKey] : 0
  copy[plan.cursorKey] = (cur + 1) % batchCount
  AppStorage.setOrCreate('batchCursor', copy)
}

// 🌟 课程种子：由课程 id 计算稳定散列，保证不同课程取到不同的课时切片
export function courseSeed(courseId: string): number {
  let sum = 0
  for (let i = 0; i < courseId.length; i++) {
    sum = (sum * 31 + courseId.charCodeAt(i)) % 100003
  }
  return sum
}

// 🌟 课时练习确定性选题：同一课时始终对应同一批题（与课程列表展示一致），
// 起始位置由该语种自己的 lessonBase / lessonStride 与课程种子共同决定，不同科目互不重叠
export function lessonBatch<T>(all: T[], plan: BatchPlan, lessonIndex: number, seed: number, size: number = PRACTICE_BATCH): T[] {
  if (all.length <= size) {
    return all.slice()
  }
  let start = (plan.lessonBase + seed * size + lessonIndex * size * plan.lessonStride) % all.length
  let out: T[] = []
  for (let i = 0; i < size; i++) {
    out.push(all[(start + i) % all.length])
  }
  return out
}

// ==================== 进度与统计工具 ====================

// 🌟 某课程已完成课时的明细下标（lessonDoneIndexes: courseId -> "0,2,4"）
// 旧数据只有完成数量时，按「前 n 节已完成」兼容读取，保证分子不会超过分母
function lessonIndexesOf(courseId: string): number[] {
  let detail = AppStorage.get<Record<string, string>>('lessonDoneIndexes')
  if (detail !== undefined && detail[courseId] !== undefined && detail[courseId] !== '') {
    let list: number[] = []
    detail[courseId].split(',').forEach((x: string) => {
      if (x !== '') {
        let n = Number(x)
        if (!list.includes(n)) {
          list.push(n)
        }
      }
    })
    return list
  }
  let map = AppStorage.get<Record<string, number>>('courseProgress')
  let done = map !== undefined && map[courseId] !== undefined ? map[courseId] : 0
  let seed: number[] = []
  for (let i = 0; i < done; i++) {
    seed.push(i)
  }
  return seed
}

// 🌟 某课程已完成课时数（按实际完成的课时下标去重统计，重复完成不计数）
export function lessonsDone(courseId: string): number {
  return lessonIndexesOf(courseId).length
}

export function completeLesson(courseId: string, lessonIndex: number): boolean {
  let idxs = lessonIndexesOf(courseId)
  if (idxs.includes(lessonIndex)) {
    return false // 该课时已完成过，不重复计数
  }
  idxs.push(lessonIndex)
  let map = AppStorage.get<Record<string, number>>('courseProgress')
  let copy: Record<string, number> = {}
  if (map !== undefined) {
    Object.keys(map).forEach((k: string) => {
      copy[k] = map![k]
    })
  }
  copy[courseId] = idxs.length
  AppStorage.setOrCreate('courseProgress', copy)
  let detail = AppStorage.get<Record<string, string>>('lessonDoneIndexes')
  let dcopy: Record<string, string> = {}
  if (detail !== undefined) {
    Object.keys(detail).forEach((k: string) => {
      dcopy[k] = detail![k]
    })
  }
  dcopy[courseId] = idxs.join(',')
  AppStorage.setOrCreate('lessonDoneIndexes', dcopy)
  // 🌟 完成课程：发放经验与硬币奖励（成长体系）
  onLessonComplete()
  return true
}

// 🌟 当前语言累计完成课时数
export function totalLessonsDone(lang: string): number {
  let total = 0
  coursesOf(lang).forEach((c: Course) => {
    total += lessonsDone(c.id)
  })
  return total
}

// 🌟 学习日志：date -> 当日学习分钟数（全局历史保留，供成长体系使用）
export function recordStudy(minutes: number, subject: string = ''): void {
  let map = AppStorage.get<Record<string, number>>('studyLog')
  let copy: Record<string, number> = {}
  if (map !== undefined) {
    Object.keys(map).forEach((k: string) => {
      copy[k] = map![k]
    })
  }
  let today = formatDate(new Date())
  copy[today] = (copy[today] === undefined ? 0 : copy[today]) + minutes
  AppStorage.setOrCreate('studyLog', copy)
  // 🌟 同时写入按语言/学科分账的日志：课程页的今日/累计/连续学习只读自己那份，避免串课程
  if (subject !== '') {
    let all = AppStorage.get<Record<string, Record<string, number>>>('studyLogBySubject')
    let next: Record<string, Record<string, number>> = {}
    if (all !== undefined) {
      Object.keys(all).forEach((k: string) => {
        next[k] = all![k]
      })
    }
    let scoped = next[subject]
    if (scoped === undefined) {
      scoped = {}
    }
    scoped[today] = (scoped[today] === undefined ? 0 : scoped[today]) + minutes
    next[subject] = scoped
    AppStorage.setOrCreate('studyLogBySubject', next)
  }
  // 🌟 完成一次练习：发放经验与硬币奖励（成长体系）
  onPractice()
}

// 🌟 按语言/学科读取学习日志（不跨课程串数据）
export function subjectStudyLog(subject: string): Record<string, number> {
  if (subject === '') {
    return {}
  }
  let all = AppStorage.get<Record<string, Record<string, number>>>('studyLogBySubject')
  if (all === undefined || all[subject] === undefined) {
    return {}
  }
  return all[subject]
}

export function subjectTodayMinutes(subject: string): number {
  let n = subjectStudyLog(subject)[formatDate(new Date())]
  return n === undefined ? 0 : n
}

export function subjectTotalMinutes(subject: string): number {
  let map = subjectStudyLog(subject)
  let total = 0
  Object.keys(map).forEach((k: string) => {
    total += map[k]
  })
  return total
}

export function subjectStreak(subject: string): number {
  let map = subjectStudyLog(subject)
  let streak = 0
  let d = new Date()
  if (map[formatDate(d)] === undefined) {
    d = new Date(d.getTime() - 86400000)
  }
  while (map[formatDate(d)] !== undefined && map[formatDate(d)] > 0) {
    streak++
    d = new Date(d.getTime() - 86400000)
  }
  return streak
}

export function todayMinutes(): number {
  let map = AppStorage.get<Record<string, number>>('studyLog')
  if (map === undefined) {
    return 0
  }
  let n = map[formatDate(new Date())]
  return n === undefined ? 0 : n
}

// 🌟 连续学习天数：从今天（未学则从昨天）往前数连续有记录的天数
export function calcStreak(): number {
  let map = AppStorage.get<Record<string, number>>('studyLog')
  if (map === undefined) {
    return 0
  }
  let streak = 0
  let d = new Date()
  if (map[formatDate(d)] === undefined) {
    d = new Date(d.getTime() - 86400000)
  }
  while (map[formatDate(d)] !== undefined && map[formatDate(d)] > 0) {
    streak++
    d = new Date(d.getTime() - 86400000)
  }
  return streak
}

export function totalStudyMinutes(): number {
  let map = AppStorage.get<Record<string, number>>('studyLog')
  if (map === undefined) {
    return 0
  }
  let total = 0
  Object.keys(map).forEach((k: string) => {
    total += map![k]
  })
  return total
}

// 🌟 已掌握单词数：wordKnown 存「语言+单词」组合键，避免重复计数
export function masterWord(lang: string, word: string): boolean {
  let key = `${lang}_${word}`
  let known = AppStorage.get<string[]>('wordKnown') ?? []
  if (known.includes(key)) {
    return false
  }
  let copy = known.slice()
  copy.push(key)
  AppStorage.setOrCreate('wordKnown', copy)
  return true
}

export function masteredCount(): number {
  let known = AppStorage.get<string[]>('wordKnown') ?? []
  return known.length
}

// 🌟 检查并解锁成就：返回新解锁的成就名列表（用于 toast 提示）
export function refreshAchievements(lang: string): string[] {
  let got = AppStorage.get<string[]>('achievementList') ?? []
  let unlocked = got.slice()
  const add = (id: string): void => {
    if (!unlocked.includes(id)) {
      unlocked.push(id)
    }
  }
  let lessons = totalLessonsDone(lang)
  if (lessons >= 1) {
    add('a_first')
  }
  if (lessons >= 10) {
    add('a_lesson10')
  }
  let words = masteredCount()
  if (words >= 10) {
    add('a_word10')
  }
  if (words >= 30) {
    add('a_word30')
  }
  if (calcStreak() >= 3) {
    add('a_streak3')
  }
  let checkins = AppStorage.get<CheckinItem[]>('checkinList') ?? []
  let nickname = AppStorage.get<string>('nickname') ?? ''
  if (checkins.some((c: CheckinItem) => c.author === nickname)) {
    add('a_checkin')
  }
  if (AppStorage.get<boolean>('quizPerfect') === true) {
    add('a_quiz')
  }
  if (AppStorage.get<boolean>('listenPerfect') === true) {
    add('a_listen')
  }
  AppStorage.setOrCreate('achievementList', unlocked)
  let fresh: string[] = []
  unlocked.forEach((id: string) => {
    if (!got.includes(id)) {
      let a = ACHIEVEMENTS.find((x: Achievement) => x.id === id)
      if (a !== undefined) {
        fresh.push(a.name)
      }
    }
  })
  return fresh
}

// 🌟 个性化路径推荐：按级别顺序找到第一节未完成的课
export class PathRecommend {
  courseId: string = ''
  courseTitle: string = ''
  lessonIndex: number = 0
  lessonTitle: string = ''
  level: number = 0
  color: string = ''
  progressDone: number = 0
  progressTotal: number = 0
}

export function recommendPath(lang: string): PathRecommend {
  let rec = new PathRecommend()
  let courses = coursesOf(lang)
  for (let i = 0; i < courses.length; i++) {
    let c = courses[i]
    let done = lessonsDone(c.id)
    if (done < c.lessons.length) {
      rec.courseId = c.id
      rec.courseTitle = c.title
      rec.lessonIndex = done
      rec.lessonTitle = c.lessons[done].title
      rec.level = c.level
      rec.color = c.color
      rec.progressDone = done
      rec.progressTotal = c.lessons.length
      return rec
    }
  }
  // 全部完成：推荐回到最后一节复习
  let last = courses[courses.length - 1]
  rec.courseId = last.id
  rec.courseTitle = last.title
  rec.lessonIndex = 0
  rec.lessonTitle = `${last.lessons[0].title}（复习）`
  rec.level = last.level
  rec.color = last.color
  rec.progressDone = last.lessons.length
  rec.progressTotal = last.lessons.length
  return rec
}

// 🌟 课时 -> 互动模块：0 单词 1 语法 2 口语 3 听力
export function lessonModule(lessonIndex: number): string {
  const mods: string[] = ['word', 'grammar', 'speak', 'listen']
  return mods[lessonIndex % 4]
}

// 🌟 课时 → 训练模块：优先按课时主题关键词匹配，避免「语法课」跳进单词训练
export function moduleOfLesson(title: string, lessonIndex: number): string {
  if (title.indexOf('听力') >= 0 || title.indexOf('听辨') >= 0 || title.indexOf('听') >= 0 ||
    title.indexOf('讲座') >= 0 || title.indexOf('复述') >= 0) {
    return 'listen'
  }
  if (title.indexOf('语法') >= 0 || title.indexOf('时态') >= 0 || title.indexOf('过去时') >= 0 ||
    title.indexOf('现在时') >= 0 || title.indexOf('进行时') >= 0 || title.indexOf('将来时') >= 0 ||
    title.indexOf('从句') >= 0 || title.indexOf('语态') >= 0 || title.indexOf('语气') >= 0 ||
    title.indexOf('助词') >= 0 || title.indexOf('介词') >= 0 || title.indexOf('冠词') >= 0 ||
    title.indexOf('量词') >= 0 || title.indexOf('句') >= 0 || title.indexOf('补语') >= 0 ||
    title.indexOf('否定') >= 0 || title.indexOf('疑问') >= 0 || title.indexOf('比较') >= 0 ||
    title.indexOf('辨析') >= 0 || title.indexOf('语序') >= 0 || title.indexOf('连接词') >= 0 ||
    title.indexOf('定语') >= 0 || title.indexOf('被动') >= 0 || title.indexOf('使动') >= 0) {
    return 'grammar'
  }
  if (title.indexOf('口语') >= 0 || title.indexOf('会话') >= 0 || title.indexOf('对话') >= 0 ||
    title.indexOf('表达') >= 0 || title.indexOf('发言') >= 0 || title.indexOf('演讲') >= 0 ||
    title.indexOf('辩论') >= 0 || title.indexOf('谈判') >= 0 || title.indexOf('口译') >= 0 ||
    title.indexOf('主持') >= 0 || title.indexOf('问候') >= 0 || title.indexOf('自我介绍') >= 0 ||
    title.indexOf('沟通') >= 0 || title.indexOf('电话') >= 0 || title.indexOf('留言') >= 0 ||
    title.indexOf('出行') >= 0 || title.indexOf('问路') >= 0 || title.indexOf('点餐') >= 0 ||
    title.indexOf('食堂') >= 0 || title.indexOf('便利店') >= 0 || title.indexOf('地铁') >= 0 ||
    title.indexOf('公交') >= 0 || title.indexOf('换乘') >= 0 || title.indexOf('讲价') >= 0 ||
    title.indexOf('传译') >= 0) {
    return 'speak'
  }
  if (title.indexOf('单词') >= 0 || title.indexOf('词汇') >= 0 || title.indexOf('词') >= 0 ||
    title.indexOf('音标') >= 0 || title.indexOf('拼读') >= 0 || title.indexOf('发音') >= 0 ||
    title.indexOf('声母') >= 0 || title.indexOf('韵母') >= 0 || title.indexOf('声调') >= 0 ||
    title.indexOf('字母') >= 0 || title.indexOf('成语') >= 0 || title.indexOf('俗语') >= 0 ||
    title.indexOf('时间') >= 0 || title.indexOf('日期') >= 0 || title.indexOf('数字') >= 0 ||
    title.indexOf('天气') >= 0 || title.indexOf('季节') >= 0 || title.indexOf('标识') >= 0 ||
    title.indexOf('食材') >= 0 || title.indexOf('音') >= 0) {
    return 'word'
  }
  return lessonModule(lessonIndex)
}

// ==================== 互动学习防重复选题 ====================

// 🌟 自由练习选题：每个练习在一个周期内最多出现两次
// 规则：出现次数少的练习优先；同一次数内按游标轮换，避免连续两批完全相同；
// 当所有练习都已出现两次时清零本等级记录，进入下一周期
export function takePracticeBatch<T>(all: T[], kind: string, level: number, batchSize: number,
  keyOf: (item: T) => string): T[] {
  let prefix = `${kind}_l${level}_`
  let counts: Record<string, number> = {}
  let storedCounts = AppStorage.get<Record<string, number>>('practiceSeen')
  if (storedCounts !== undefined) {
    let sc: Record<string, number> = storedCounts
    Object.keys(sc).forEach((k: string) => {
      counts[k] = sc[k]
    })
  }
  let cursors: Record<string, number> = {}
  let storedCursors = AppStorage.get<Record<string, number>>('practiceCursor')
  if (storedCursors !== undefined) {
    let sd: Record<string, number> = storedCursors
    Object.keys(sd).forEach((k: string) => {
      cursors[k] = sd[k]
    })
  }
  let cursorKey = `${kind}_l${level}`
  let cursor = cursors[cursorKey] === undefined ? 0 : cursors[cursorKey]

  let countOf = (item: T): number => {
    let n = counts[prefix + keyOf(item)]
    return n === undefined ? 0 : n
  }

  let avail = all.filter((it: T) => countOf(it) < 2)
  if (avail.length === 0 && all.length > 0) {
    // 全部练习都已出现两次：清零本等级记录，重新进入新一轮
    Object.keys(counts).forEach((k: string) => {
      if (k.indexOf(prefix) === 0) {
        counts[k] = 0
      }
    })
    avail = all.slice()
  }

  // 次数少的优先；同一次数内按游标轮换顺序
  let sorted = avail.slice().sort((a: T, b: T) => countOf(a) - countOf(b))
  let minCount = sorted.length > 0 ? countOf(sorted[0]) : 0
  let tier: T[] = sorted.filter((it: T) => countOf(it) === minCount)
  let rest: T[] = sorted.filter((it: T) => countOf(it) > minCount)
  let off = tier.length > 0 ? cursor % tier.length : 0
  let ordered = tier.slice(off).concat(tier.slice(0, off)).concat(rest)
  let picked = ordered.slice(0, Math.min(batchSize, ordered.length))

  // 记录本次出现次数 + 推进游标
  picked.forEach((it: T) => {
    counts[prefix + keyOf(it)] = countOf(it) + 1
  })
  cursors[cursorKey] = cursor + batchSize
  AppStorage.setOrCreate('practiceSeen', counts)
  AppStorage.setOrCreate('practiceCursor', cursors)
  return picked
}

export function modulePageUrl(module: string): string {
  if (module === 'word') {
    return 'pages/course/WordMemoryPage'
  }
  if (module === 'grammar') {
    return 'pages/course/GrammarPage'
  }
  if (module === 'speak') {
    return 'pages/course/SpeakingPage'
  }
  return 'pages/course/ListeningPage'
}
