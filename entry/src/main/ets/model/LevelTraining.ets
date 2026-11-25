// ==================== 英语分级训练内容 ====================
// 🌟 L1~L4 每个等级拥有独立的训练目标、训练方式与题库内容，
// 不再用同一套模板按游标切片复用：
//   L1 入门：翻卡认词 · 音标跟读 · 日常问候 · 单词听辨
//   L2 初级：看词选义 · 时态单选 · 情景跟读 · 场景听力
//   L3 中级：看义选词 · 从句/被动单选 · 观点陈述 · 新闻听力
//   L4 高级：拼写默写 · 高级语法辨析 · 演讲跟读 · 学术听力
// 教学视频：按等级 + 训练模块匹配 B 站对应主题的搜索结果
import { WordItem, GrammarQ, SpeakItem, ListenItem } from './CourseModel';
import { LEVEL_NAMES, LEVEL_COLORS } from './GrowthModel';

// ==================== B 站检索：模块主题 → 检索词 ====================
// 🌟 检索词清洗：统一中英文分隔，去掉冒号/斜杠/顿号等标点并合并多余空格，
// 避免 B 站搜索页收到「一般现在时 / 过去时」这类带斜杠的关键词导致结果跑偏
function cleanKeyword(raw: string): string {
  let dirty: string = '·:：/、，,。;；|｜!！?？()（）【】[]{}<>《》"\'`~@#$%^&*+='
  let out: string = ''
  let lastSpace: boolean = false
  for (let i = 0; i < raw.length; i++) {
    let ch: string = raw.charAt(i)
    if (ch === ' ' || ch === '\t' || ch === '\n' || ch === '\r' || dirty.indexOf(ch) >= 0) {
      if (!lastSpace && out.length > 0) {
        out += ' '
        lastSpace = true
      }
    } else {
      out += ch
      lastSpace = false
    }
  }
  return out.trim()
}

// 🌟 B 站视频搜索结果页：只检索视频分区，检索词由调用方提供真实知识点
export function biliSearch(keyword: string): string {
  return `https://search.bilibili.com/video?keyword=${encodeURIComponent(cleanKeyword(keyword))}`
}

// 🌟 模块 → 中文标签 的受控映射
function moduleLabel(module: string): string {
  if (module === 'grammar') {
    return '语法'
  }
  if (module === 'speak') {
    return '口语'
  }
  if (module === 'listen') {
    return '听力'
  }
  return '单词'
}

// 🌟 模块 → 真实训练重点（不含「学习路径 / 综合检测 / 知识区」这类结构词）
function moduleTopic(plan: LevelPlan, module: string): string {
  if (module === 'grammar') {
    return plan.grammarFocus !== '' ? plan.grammarFocus : '基础语法'
  }
  if (module === 'speak') {
    return plan.methods.length > 2 ? plan.methods[2] : '跟读'
  }
  if (module === 'listen') {
    return plan.methods.length > 3 ? plan.methods[3] : '听辨'
  }
  // 单词：优先「词汇」类重点，其次「名词」类重点，缺省用第一项（如 L1 的字母与音标）
  let focus = plan.focus.length > 0 ? plan.focus[0] : '基础词汇'
  for (let i = 0; i < plan.focus.length; i++) {
    if (plan.focus[i].indexOf('词汇') >= 0) {
      focus = plan.focus[i]
    }
  }
  if (focus.indexOf('词汇') < 0) {
    for (let i = 0; i < plan.focus.length; i++) {
      if (plan.focus[i].indexOf('名词') >= 0) {
        focus = plan.focus[i]
      }
    }
  }
  return focus
}

// 检索词 = 「英语 + 模块」 + 该等级的真实训练重点，例如「英语听力 单词听辨」
export function moduleTopicKeyword(plan: LevelPlan, module: string): string {
  return `英语${moduleLabel(module)} ${moduleTopic(plan, module)}`
}

export function moduleVideoUrl(plan: LevelPlan, module: string): string {
  return biliSearch(moduleTopicKeyword(plan, module))
}

export class VideoRef {
  title: string = '';
  url: string = '';
  tag: string = '';

  constructor(title: string, url: string, tag: string) {
    this.title = title;
    this.url = url;
    this.tag = tag;
  }
}

export class LevelPlan {
  level: number = 0;
  name: string = '';
  color: string = '';
  goal: string = '';          // 本等级训练目标
  methods: string[] = [];     // 四类训练对应的方式（不同等级不同）
  focus: string[] = [];       // 训练重点
  wordMode: string = 'flip';  // 单词训练玩法：flip / choice / choice_cn / spell
  grammarFocus: string = '';  // 语法训练侧重
  words: WordItem[] = [];
  grammar: GrammarQ[] = [];
  speak: SpeakItem[] = [];
  listen: ListenItem[] = [];
}

function parseWords(raw: string[]): WordItem[] {
  let list: WordItem[] = [];
  raw.forEach((line: string) => {
    let p = line.split('|');
    if (p.length >= 3) {
      list.push(new WordItem(p[0], p[1], p[2]));
    }
  });
  return list;
}

function parseQuestions(raw: string[]): GrammarQ[] {
  let list: GrammarQ[] = [];
  raw.forEach((line: string) => {
    let p = line.split('|');
    if (p.length >= 4) {
      list.push(new GrammarQ(p[0], p[1].split(';'), Number(p[2]), p[3]));
    }
  });
  return list;
}

function parseSpeaks(raw: string[]): SpeakItem[] {
  let list: SpeakItem[] = [];
  raw.forEach((line: string) => {
    let p = line.split('|');
    if (p.length >= 2) {
      list.push(new SpeakItem(p[0], p[1]));
    }
  });
  return list;
}

function parseListens(raw: string[]): ListenItem[] {
  let list: ListenItem[] = [];
  raw.forEach((line: string) => {
    let p = line.split('|');
    if (p.length >= 4) {
      list.push(new ListenItem(p[0], p[1], p[2].split(';'), Number(p[3])));
    }
  });
  return list;
}

function buildPlan(level: number, name: string, color: string, goal: string,
  methods: string[], focus: string[], wordMode: string, grammarFocus: string,
  wordsRaw: string[], qRaw: string[], sRaw: string[], lRaw: string[]): LevelPlan {
  let p = new LevelPlan();
  p.level = level;
  p.name = name;
  p.color = color;
  p.goal = goal;
  p.methods = methods;
  p.focus = focus;
  p.wordMode = wordMode;
  p.grammarFocus = grammarFocus;
  p.words = parseWords(wordsRaw);
  p.grammar = parseQuestions(qRaw);
  p.speak = parseSpeaks(sRaw);
  p.listen = parseListens(lRaw);
  return p;
}

// 🌟 取某个练习模块对应的教学视频：标题与检索词同源，不会出现「标题说主题 A、点开搜 B」
export function moduleVideo(plan: LevelPlan, module: string): VideoRef {
  // 标题只写「等级 · 真实训练重点」，模块标签由页面上的徽标（单词/语法/口语/听力）承担
  return new VideoRef(`${plan.name} · ${moduleTopic(plan, module)}`,
    moduleVideoUrl(plan, module), 'B站视频')
}

// ==================== L1 入门 ====================
const L1_WORDS: string[] = [
  'apple|/ˈæpl/|苹果', 'cat|/kæt/|猫', 'dog|/dɔːɡ/|狗', 'book|/bʊk/|书',
  'mother|/ˈmʌðər/|妈妈', 'water|/ˈwɔːtər/|水', 'happy|/ˈhæpi/|开心的', 'run|/rʌn/|跑步',
  'school|/skuːl/|学校', 'milk|/mɪlk/|牛奶', 'red|/red/|红色的', 'friend|/frend/|朋友'
];
const L1_QUESTIONS: string[] = [
  'She ___ a student.|is;are;am;be|0|主语 she 是第三人称单数，be 动词用 is。',
  'This ___ my book.|is;are;am;be|0|this 指单数事物，用 is。',
  'I ___ a new pen.|have;has;having;haves|0|主语 I 后面用动词原形 have。',
  'There ___ two apples on the table.|is;are;am;be|1|two apples 是复数，用 are。',
  'The cat ___ small.|is;are;am;have|0|the cat 为单数，用 is。',
  '___ is your name?|What;Who;Where;How|0|询问姓名用 What is your name?'
];
const L1_SPEAK: string[] = [
  'Good morning!|早上好！', 'Nice to meet you.|很高兴认识你。',
  'My name is Lily.|我叫莉莉。', 'How are you today?|你今天好吗？',
  'This is my book.|这是我的书。', 'Thank you very much.|非常感谢。'
];
const L1_LISTEN: string[] = [
  "Hello, I'm Tom.|What's the speaker's name?|Tom;Lily;Jack|0",
  "It's a red apple.|What color is the apple?|Red;Green;Blue|0",
  'I have two cats.|How many cats does the speaker have?|One;Two;Three|1',
  'Good morning, Miss Li.|What time of day is it?|Morning;Afternoon;Evening|0'
];

// ==================== L2 初级 ====================
const L2_WORDS: string[] = [
  'schedule|/ˈskedʒuːl/|日程表', 'hobby|/ˈhɑːbi/|爱好', 'weather|/ˈweðər/|天气',
  'travel|/ˈtrævl/|旅行', 'delicious|/dɪˈlɪʃəs/|美味的', 'introduce|/ˌɪntrəˈdjuːs/|介绍',
  'borrow|/ˈbɔːroʊ/|借入', 'decide|/dɪˈsaɪd/|决定', 'festival|/ˈfestɪvl/|节日',
  'subway|/ˈsʌbweɪ/|地铁', 'homework|/ˈhoʊmwɜːrk/|作业', 'practice|/ˈpræktɪs/|练习'
];
const L2_QUESTIONS: string[] = [
  'He ___ to school every day.|go;goes;going;went|1|every day 表习惯，主语第三人称单数用 goes。',
  'Look! They ___ football now.|play;plays;are playing;played|2|Look 与 now 提示现在进行时。',
  'I ___ my homework yesterday.|do;did;does;doing|1|yesterday 表过去，用一般过去时 did。',
  'There are many ___ on the farm.|sheep;sheeps;sheepes;sheepses|0|sheep 单复数同形。',
  "We usually get up ___ seven o'clock.|at;on;in;for|0|具体时刻前用介词 at。",
  'She is good ___ drawing.|at;in;on;for|0|be good at 表示擅长。',
  'If it ___ tomorrow, we will stay at home.|rain;rains;will rain;rained|1|if 条件句遵循主将从现。'
];
const L2_SPEAK: string[] = [
  'Could you help me, please?|你能帮我一下吗？',
  'I usually go to school by bike.|我通常骑自行车上学。',
  'What do you do in your free time?|你空闲时间做什么？',
  'Would you like some tea?|你想喝点茶吗？',
  'I have been learning English for two years.|我学英语已经两年了。',
  'Let me introduce my friend to you.|让我把我的朋友介绍给你。'
];
const L2_LISTEN: string[] = [
  'I usually go to the library by bike.|How does the speaker go to the library?|By bike;By bus;On foot|0',
  'The movie starts at seven thirty.|When does the movie start?|At 7:00;At 7:30;At 8:00|1',
  "My favorite subject is English.|What is the speaker's favorite subject?|Math;History;English|2",
  'There will be a meeting tomorrow afternoon.|When is the meeting?|Tomorrow morning;Tomorrow afternoon;Tonight|1'
];

// ==================== L3 中级 ====================
const L3_WORDS: string[] = [
  'environment|/ɪnˈvaɪrənmənt/|环境', 'technology|/tekˈnɑːlədʒi/|科技', 'improve|/ɪmˈpruːv/|改善',
  'opportunity|/ˌɑːpərˈtuːnəti/|机会', 'experience|/ɪkˈspɪriəns/|经验', 'communicate|/kəˈmjuːnɪkeɪt/|交流',
  'effective|/ɪˈfektɪv/|有效的', 'pressure|/ˈpreʃər/|压力', 'balance|/ˈbæləns/|平衡',
  'creative|/kriˈeɪtɪv/|有创造力的', 'resource|/ˈriːsɔːrs/|资源', 'evidence|/ˈevɪdəns/|证据'
];
const L3_QUESTIONS: string[] = [
  'This is the house ___ we lived in last year.|which;who;what;where|0|先行词是物且作介词宾语，用 which。',
  'He said that he ___ busy the next day.|is;will be;would be;was|2|主句过去时，从句用过去将来 would be。',
  'The problem ___ at the meeting yesterday.|discussed;was discussed;discuss;is discussing|1|问题被讨论，用过去时被动语态。',
  '___ hard, and you will pass the exam.|Work;Working;To work;Worked|0|祈使句 + and + 陈述句结构。',
  'If I ___ you, I would take the chance.|am;was;were;be|2|与现在事实相反的虚拟语气用 were。',
  'The book ___ on the desk belongs to me.|lying;lay;lies;lied|0|现在分词作定语，表主动进行。'
];
const L3_SPEAK: string[] = [
  'In my opinion, reading helps us think more deeply.|在我看来，阅读能帮助我们思考更深入。',
  'What I want to stress is the importance of teamwork.|我想强调的是团队合作的重要性。',
  'I could not agree more with your point of view.|我非常同意你的观点。',
  'Compared with last year, the situation has improved a lot.|与去年相比，情况有了很大改善。',
  'It is difficult for beginners to keep a habit.|对初学者来说，坚持一个习惯是困难的。',
  'We should take action before the problem gets worse.|我们应该在问题恶化之前采取行动。'
];
const L3_LISTEN: string[] = [
  'The meeting has been put off until Friday because of the weather.|Why was the meeting put off?|Because of the weather;Because of the holiday;Because of the traffic|0',
  'Although the task was difficult, they finished it on time.|What can we learn about the task?|It was easy;It was finished on time;It was cancelled|1',
  'The number of online learners has doubled in the past three years.|What happened to online learners?|They decreased;They doubled;They stayed the same|1'
];

// ==================== L4 高级 ====================
const L4_WORDS: string[] = [
  'analyze|/əˈnæləz/|分析', 'significant|/ˈsɪɡnɪfɪkənt/|显著的', 'phenomenon|/fəˈnɑːmɪnən/|现象',
  'sustainable|/səˈsteɪnəbl/|可持续的', 'controversy|/ˈkɑːntrəvɜːrsi/|争议', 'perspective|/pərˈspektɪv/|视角',
  'implication|/ˌɪmplɪˈkeɪʃn/|影响', 'comprehensive|/ˌkɑːmprɪˈhensɪv/|全面的', 'demonstrate|/dɪˈmɑːnstreɪt/|论证',
  'hypothesis|/haɪˈpɑːθəsɪs/|假设', 'inevitable|/ɪnˈevɪtəbl/|不可避免的', 'substantial|/səbˈstænʃl/|大量的'
];
const L4_QUESTIONS: string[] = [
  'Not until he lost his health ___ the value of it.|he realized;did he realize;he did realize;realized he|1|否定词置于句首，主句用部分倒装。',
  'The research, ___ in 2020, has shaped current policy.|conducted;conducting;to conduct;conducts|0|过去分词作后置定语，表被动完成。',
  'It is essential that every member ___ the rule.|observe;observes;observed;observing|0|It is essential that 从句用虚拟语气动词原形。',
  '___ more carefully, the experiment would have succeeded.|If conducted;Conducted;Conducting;To conduct|0|虚拟条件句省略 if 后用分词形式。',
  'Hardly ___ the hall when the lights went out.|he had entered;had he entered;he entered;did he enter|1|hardly 置于句首用部分倒装。',
  'Only when we understand ourselves ___ others.|can we understand;we can understand;we understand can;understood we can|0|only 引导状语置句首，主句倒装。'
];
const L4_SPEAK: string[] = [
  'The data suggests a significant shift in consumer behavior.|数据显示消费者的行为发生了显著变化。',
  'While some argue for the benefits, others emphasize the risks.|有人主张其益处，也有人强调风险。',
  'It is widely acknowledged that education shapes social mobility.|教育塑造社会流动性，这一点已被广泛认可。',
  'In the long run, sustainable development outweighs short-term profits.|从长远看，可持续发展比短期利润更重要。',
  'To what extent should technology be allowed to influence our decisions?|科技应该在多大程度上影响我们的决定？',
  'My presentation today will focus on three key aspects.|我今天的展示将聚焦三个关键方面。'
];
const L4_LISTEN: string[] = [
  'Researchers have found that sleep quality directly affects memory performance.|What does the study focus on?|Sleep and memory;Diet and exercise;Work and income|0',
  "The lecture argues that artificial intelligence will not replace teachers but reshape their roles.|What is the speaker's view on AI in education?|It will replace teachers;It will reshape teachers' roles;It will be banned|1",
  'Although the sample size was limited, the findings were consistent with earlier studies.|What can be concluded about the findings?|They were inconsistent;They matched earlier studies;They were rejected|1'
];

export const EN_LEVEL_PLANS: LevelPlan[] = [
  buildPlan(0, '入门', '#55C873', '认读高频基础词，能用问候语完成自我介绍',
    ['翻卡认词', '音标跟读', '日常问候', '单词听辨'], ['字母与音标', '高频名词', '问候用语', '数字时间'],
    'flip', '基础句型与 be 动词',
    L1_WORDS, L1_QUESTIONS, L1_SPEAK, L1_LISTEN),
  buildPlan(1, '初级', '#3F7EF6', '掌握日常场景表达，能完成购物、出行等简单对话',
    ['看词选义', '时态单选', '情景跟读', '场景听力'], ['日常词汇', '一般时态', '情景句型', '名词复数'],
    'choice', '一般现在时 / 过去时 / 介词',
    L2_WORDS, L2_QUESTIONS, L2_SPEAK, L2_LISTEN),
  buildPlan(2, '中级', '#E8A33E', '读懂长难句，能就熟悉话题有条理地表达观点',
    ['看义选词', '从句单选', '观点陈述', '新闻听力'], ['话题词汇', '从句与被动', '观点表达', '长句拆解'],
    'choice_cn', '从句 / 被动语态 / 非谓语',
    L3_WORDS, L3_QUESTIONS, L3_SPEAK, L3_LISTEN),
  buildPlan(3, '高级', '#EF4444', '学术与职场场景自如输出，能论证、演讲与辩论',
    ['拼写默写', '高级语法辨析', '演讲跟读', '学术听力'], ['学术词汇', '倒装与虚拟', '论证表达', '讲座听力'],
    'spell', '倒装 / 虚拟语气 / 独立主格',
    L4_WORDS, L4_QUESTIONS, L4_SPEAK, L4_LISTEN)
];

export function levelPlan(level: number): LevelPlan {
  let lv = Math.max(0, Math.min(3, level));
  return EN_LEVEL_PLANS[lv];
}

// 🌟 从课程 id（en_l0_0）解析等级；无课程参数时按用户经验等级取对应难度
export function levelFromCourseId(courseId: string): number {
  let i = courseId.indexOf('_l');
  if (i < 0) {
    return 0;
  }
  let n = Number(courseId.substring(i + 2, i + 3));
  return n >= 0 && n <= 3 ? n : 0;
}

export function planFor(courseId: string, expLevel: number): LevelPlan {
  let lv = courseId === '' ? expLevel : levelFromCourseId(courseId);
  return levelPlan(lv);
}

// ==================== 各语种分级方案（语种课程内页展示） ====================
// 与英语同构：每个等级有独立目标、四类训练方式、训练重点与内容量
export class LevelBrief {
  level: number = 0
  name: string = ''
  color: string = ''
  goal: string = ''
  methods: string[] = []      // 单词 / 语法 / 口语 / 听力 的训练方式
  grammarFocus: string = ''   // 语法训练侧重
  topics: string[] = []       // 四个模块的教学视频主题
  counts: number[] = []       // 词汇 / 语法 / 口语 / 听力 的内容量
}

function mkBrief(level: number, goal: string, methods: string[], grammarFocus: string,
  topics: string[], counts: number[]): LevelBrief {
  let b = new LevelBrief()
  b.level = level
  b.name = LEVEL_NAMES[level]
  b.color = LEVEL_COLORS[level]
  b.goal = goal
  b.methods = methods
  b.grammarFocus = grammarFocus
  b.topics = topics
  b.counts = counts
  return b
}

const JA_BRIEFS: LevelBrief[] = [
  mkBrief(0, '认读五十音与高频词，能用问候语完成自我介绍',
    ['假名认读', '助词单选', '日常问候', '假名听辨'], '基础判断句与助词',
    ['五十音', '判断句与助词', '问候与自我介绍', '假名听辨'], [12, 6, 6, 4]),
  mkBrief(1, '掌握助词与动词变形，能完成购物、出行等日常对话',
    ['看词选义', 'て形单选', '情景跟读', '场景听力'], '动词て形与形容词活用',
    ['日常词汇', '动词て形', '校园情景会话', '场景听力'], [12, 7, 6, 4]),
  mkBrief(2, '读懂中篇材料，能就熟悉话题有条理地表达观点',
    ['看义选词', '敬语单选', '观点陈述', '新闻听力'], '敬语与被动使役',
    ['话题词汇', '敬语与语态', '观点表达', '新闻听力'], [12, 6, 6, 3]),
  mkBrief(3, '长句与敬语自如输出，能演讲、辩论与翻译',
    ['拼写默写', '高级语法辨析', '演讲跟读', '学术听力'], '长句结构与敬语进阶',
    ['学术词汇', '长句与敬语进阶', '演讲与辩论', '讲座听力'], [12, 6, 6, 3])
]

const KO_BRIEFS: LevelBrief[] = [
  mkBrief(0, '认读四十音与高频词，能用敬语问候完成自我介绍',
    ['谚文认读', '语尾单选', '日常问候', '单词听辨'], '语序、语尾与敬语称呼',
    ['四十音', '语序与语尾', '问候与自我介绍', '单词听辨'], [12, 6, 6, 4]),
  mkBrief(1, '掌握助词与过去时，能在校园、生活场景开口交流',
    ['看词选义', '助词单选', '情景跟读', '场景听力'], '助词与过去时 -았/었',
    ['生活词汇', '助词与过去时', '校园情景会话', '场景听力'], [12, 7, 6, 4]),
  mkBrief(2, '读懂长句材料，能就熟悉话题表达个人观点',
    ['看义选词', '连接词单选', '观点陈述', '新闻听力'], '连接词与定语形',
    ['话题词汇', '连接词与定语形', '观点表达', '新闻听力'], [12, 6, 6, 3]),
  mkBrief(3, '敬语与长句自如输出，能职场演讲与翻译',
    ['拼写默写', '高级语法辨析', '演讲跟读', '学术听力'], '被动使动与敬语进阶',
    ['职场词汇', '被动使动与敬语', '演讲与辩论', '讲座听力'], [12, 6, 6, 3])
]

const ZH_BRIEFS: LevelBrief[] = [
  mkBrief(0, '掌握拼音声调与基础词，能用问候语完成自我介绍',
    ['拼音认读', '量词单选', '日常问候', '声调听辨'], '基本语序与量词搭配',
    ['声母韵母', '语序与量词', '问候与自我介绍', '声调听辨'], [12, 6, 6, 4]),
  mkBrief(1, '掌握量词与「了/着/过」，能完成日常会话',
    ['看词选义', '量词单选', '情景跟读', '场景听力'], '量词与动态助词辨析',
    ['生活词汇', '量词与助词', '校园情景会话', '场景听力'], [12, 7, 6, 4]),
  mkBrief(2, '读懂中篇材料，能就熟悉话题有条理地表达',
    ['看义选词', '把字句单选', '观点陈述', '新闻听力'], '把字句、被字句与补语',
    ['话题词汇', '特殊句式', '观点表达', '新闻听力'], [12, 6, 6, 3]),
  mkBrief(3, '书面语与成语自如运用，能演讲与专题写作',
    ['拼写默写', '高级语法辨析', '演讲跟读', '学术听力'], '文言基础与修辞运用',
    ['成语与书面语', '文言与修辞', '演讲与辩论', '讲座听力'], [12, 6, 6, 3])
]

// 英语：直接复用 EN_LEVEL_PLANS，保证与英语训练内容完全一致
function briefFromPlan(p: LevelPlan): LevelBrief {
  let b = new LevelBrief()
  b.level = p.level
  b.name = p.name
  b.color = p.color
  b.goal = p.goal
  b.methods = p.methods
  b.grammarFocus = p.grammarFocus
  b.topics = [moduleTopic(p, 'word'), moduleTopic(p, 'grammar'), moduleTopic(p, 'speak'), moduleTopic(p, 'listen')]
  b.counts = [p.words.length, p.grammar.length, p.speak.length, p.listen.length]
  return b
}

export function levelBriefOf(lang: string, level: number): LevelBrief {
  let lv = Math.max(0, Math.min(3, level))
  if (lang === 'ja') {
    return JA_BRIEFS[lv]
  }
  if (lang === 'ko') {
    return KO_BRIEFS[lv]
  }
  if (lang === 'zh') {
    return ZH_BRIEFS[lv]
  }
  return briefFromPlan(levelPlan(lv))
}

// 🌟 某个模块的教学视频：标题与检索词同源（等级 · 真实训练重点）
export function briefModuleVideo(brief: LevelBrief, langName: string, module: string): VideoRef {
  let topic = moduleTopicOfBrief(brief, module)
  return new VideoRef(`${brief.name} · ${topic}`,
    biliSearch(`${langName}${moduleLabel(module)} ${topic}`), 'B站视频')
}

function moduleTopicOfBrief(brief: LevelBrief, module: string): string {
  let idx = module === 'grammar' ? 1 : (module === 'speak' ? 2 : (module === 'listen' ? 3 : 0))
  if (brief.topics.length > idx) {
    return brief.topics[idx]
  }
  return brief.grammarFocus
}

// 🌟 单词训练玩法文案（与页面实际交互一致）
export function wordModeLabel(mode: string): string {
  if (mode === 'choice') {
    return '看词选义';
  }
  if (mode === 'choice_cn') {
    return '看义选词';
  }
  if (mode === 'spell') {
    return '拼写默写';
  }
  return '翻卡认词';
}
