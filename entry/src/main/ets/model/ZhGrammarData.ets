// 🌟 汉语语法千题库（独立数据源）：模板生成 1000 题，语法正确、选项互异、答案下标合法
// 格式：题干|选项1;选项2;选项3;选项4|答案序号|解析

class ZhMeasureNoun {
  noun: string = ''
  measure: string = ''

  constructor(noun: string, measure: string) {
    this.noun = noun
    this.measure = measure
  }
}

const ZH_MEASURE_NOUNS: ZhMeasureNoun[] = [
  new ZhMeasureNoun('书', '本'),
  new ZhMeasureNoun('桌子', '张'),
  new ZhMeasureNoun('汽车', '辆'),
  new ZhMeasureNoun('衣服', '件'),
  new ZhMeasureNoun('铅笔', '支'),
  new ZhMeasureNoun('花', '朵'),
  new ZhMeasureNoun('船', '条'),
  new ZhMeasureNoun('房子', '座'),
  new ZhMeasureNoun('帽子', '顶'),
  new ZhMeasureNoun('苹果', '个')
]

const ZH_MEASURES: string[] = ['本', '张', '辆', '件', '支', '朵', '条', '座', '顶', '个']

class ZhSlot {
  pre: string = ''
  post: string = ''
  ans: string = ''

  constructor(pre: string, post: string, ans: string) {
    this.pre = pre
    this.post = post
    this.ans = ans
  }
}

// 🌟 的 / 地 / 得 填空：40 + 30 + 30 = 100
const ZH_SLOTS: ZhSlot[] = [
  new ZhSlot('美丽', '风景', '的'),
  new ZhSlot('美丽', '花园', '的'),
  new ZhSlot('美丽', '城市', '的'),
  new ZhSlot('美丽', '眼睛', '的'),
  new ZhSlot('干净', '教室', '的'),
  new ZhSlot('干净', '衣服', '的'),
  new ZhSlot('干净', '街道', '的'),
  new ZhSlot('干净', '房间', '的'),
  new ZhSlot('安静', '夜晚', '的'),
  new ZhSlot('安静', '图书馆', '的'),
  new ZhSlot('安静', '公园', '的'),
  new ZhSlot('安静', '街道', '的'),
  new ZhSlot('温暖', '阳光', '的'),
  new ZhSlot('温暖', '春天', '的'),
  new ZhSlot('温暖', '家', '的'),
  new ZhSlot('温暖', '房间', '的'),
  new ZhSlot('可爱', '小狗', '的'),
  new ZhSlot('可爱', '妹妹', '的'),
  new ZhSlot('可爱', '孩子', '的'),
  new ZhSlot('可爱', '小猫', '的'),
  new ZhSlot('聪明', '学生', '的'),
  new ZhSlot('聪明', '孩子', '的'),
  new ZhSlot('聪明', '脑袋', '的'),
  new ZhSlot('聪明', '小狗', '的'),
  new ZhSlot('明亮', '灯光', '的'),
  new ZhSlot('明亮', '教室', '的'),
  new ZhSlot('明亮', '眼睛', '的'),
  new ZhSlot('明亮', '窗户', '的'),
  new ZhSlot('快乐', '童年', '的'),
  new ZhSlot('快乐', '日子', '的'),
  new ZhSlot('快乐', '歌声', '的'),
  new ZhSlot('快乐', '家庭', '的'),
  new ZhSlot('平静', '湖面', '的'),
  new ZhSlot('平静', '心情', '的'),
  new ZhSlot('平静', '生活', '的'),
  new ZhSlot('平静', '夜晚', '的'),
  new ZhSlot('高大', '树木', '的'),
  new ZhSlot('高大', '楼房', '的'),
  new ZhSlot('高大', '身影', '的'),
  new ZhSlot('高大', '建筑', '的'),
  new ZhSlot('慢慢', '走', '地'),
  new ZhSlot('慢慢', '吃', '地'),
  new ZhSlot('慢慢', '学习', '地'),
  new ZhSlot('高兴', '笑', '地'),
  new ZhSlot('高兴', '说', '地'),
  new ZhSlot('高兴', '跳', '地'),
  new ZhSlot('认真', '听', '地'),
  new ZhSlot('认真', '写', '地'),
  new ZhSlot('认真', '画', '地'),
  new ZhSlot('安静', '坐', '地'),
  new ZhSlot('安静', '站', '地'),
  new ZhSlot('安静', '睡', '地'),
  new ZhSlot('快速', '跑', '地'),
  new ZhSlot('快速', '完成', '地'),
  new ZhSlot('快速', '离开', '地'),
  new ZhSlot('轻轻', '说', '地'),
  new ZhSlot('轻轻', '关', '地'),
  new ZhSlot('轻轻', '放', '地'),
  new ZhSlot('仔细', '看', '地'),
  new ZhSlot('仔细', '检查', '地'),
  new ZhSlot('仔细', '听', '地'),
  new ZhSlot('努力', '学习', '地'),
  new ZhSlot('努力', '工作', '地'),
  new ZhSlot('努力', '跑', '地'),
  new ZhSlot('热情', '招待', '地'),
  new ZhSlot('热情', '欢迎', '地'),
  new ZhSlot('热情', '帮助', '地'),
  new ZhSlot('不停', '点头', '地'),
  new ZhSlot('不停', '鼓掌', '地'),
  new ZhSlot('不停', '问', '地'),
  new ZhSlot('跑', '很快', '得'),
  new ZhSlot('跑', '飞快', '得'),
  new ZhSlot('跑', '很累', '得'),
  new ZhSlot('写', '工整', '得'),
  new ZhSlot('写', '漂亮', '得'),
  new ZhSlot('写', '很慢', '得'),
  new ZhSlot('说', '清楚', '得'),
  new ZhSlot('说', '流利', '得'),
  new ZhSlot('说', '很快', '得'),
  new ZhSlot('睡', '很香', '得'),
  new ZhSlot('睡', '安稳', '得'),
  new ZhSlot('睡', '很晚', '得'),
  new ZhSlot('笑', '开心', '得'),
  new ZhSlot('笑', '灿烂', '得'),
  new ZhSlot('笑', '很甜', '得'),
  new ZhSlot('做', '很好', '得'),
  new ZhSlot('做', '认真', '得'),
  new ZhSlot('做', '很慢', '得'),
  new ZhSlot('唱', '好听', '得'),
  new ZhSlot('唱', '响亮', '得'),
  new ZhSlot('唱', '很响', '得'),
  new ZhSlot('长', '漂亮', '得'),
  new ZhSlot('长', '可爱', '得'),
  new ZhSlot('长', '很高', '得'),
  new ZhSlot('来', '很早', '得'),
  new ZhSlot('来', '及时', '得'),
  new ZhSlot('来', '很晚', '得'),
  new ZhSlot('学', '认真', '得'),
  new ZhSlot('学', '扎实', '得'),
  new ZhSlot('学', '很好', '得')
]

class ZhObjVerb {
  obj: string = ''
  verb: string = ''

  constructor(obj: string, verb: string) {
    this.obj = obj
    this.verb = verb
  }
}

const ZH_OBJ_VERBS: ZhObjVerb[] = [
  new ZhObjVerb('门', '关上'),
  new ZhObjVerb('窗户', '打开'),
  new ZhObjVerb('作业', '写完'),
  new ZhObjVerb('饭', '做好'),
  new ZhObjVerb('衣服', '洗干净'),
  new ZhObjVerb('问题', '解决'),
  new ZhObjVerb('车', '停好'),
  new ZhObjVerb('垃圾', '扔掉'),
  new ZhObjVerb('钥匙', '放好'),
  new ZhObjVerb('书', '收好')
]

const ZH_PUT_SUBJECTS: string[] = ['我', '你', '他', '她', '我们', '他们', '妈妈', '老师', '麻烦你', '记得']

class ZhPassive {
  thing: string = ''
  doer: string = ''
  verb: string = ''

  constructor(thing: string, doer: string, verb: string) {
    this.thing = thing
    this.doer = doer
    this.verb = verb
  }
}

const ZH_PASSIVES: ZhPassive[] = [
  new ZhPassive('杯子', '他', '打破'),
  new ZhPassive('窗户', '风', '吹开'),
  new ZhPassive('自行车', '弟弟', '骑走'),
  new ZhPassive('书', '同学', '借走'),
  new ZhPassive('蛋糕', '孩子', '吃完'),
  new ZhPassive('衣服', '雨', '淋湿'),
  new ZhPassive('手机', '我', '弄丢'),
  new ZhPassive('房间', '妈妈', '打扫'),
  new ZhPassive('问题', '老师', '解决'),
  new ZhPassive('门', '风', '吹关')
]

const ZH_CLAUSE_PAIRS: string[] = [
  '生病了|没来上课',
  '学习努力|考得好',
  '迟到了|被老师批评',
  '忘带钥匙|进不了门',
  '没带伞|衣服湿了',
  '睡得太晚|起不来',
  '吃得太辣|肚子疼',
  '手机没电了|联系不上他',
  '路上堵车|没赶上火车',
  '太累了|很早就睡了',
  '找到工作了|很高兴',
  '第一次来中国|很兴奋',
  '喜欢这首歌|听了很多遍',
  '不会说汉语|需要翻译',
  '丢了钱包|很着急',
  '通过了考试|请大家吃饭',
  '搬家了|离学校更近',
  '想家|给妈妈打电话',
  '感冒了|去看医生',
  '中奖了|请朋友吃饭'
]

const ZH_CONTRAST_PAIRS: string[] = [
  '很累|还在工作',
  '年纪小|很懂事',
  '生病了|来上课',
  '很忙|帮我',
  '个子矮|跑得快',
  '很穷|很开心',
  '成绩一般|很努力',
  '话不多|很热心',
  '起得晚|效率很高',
  '很瘦|力气很大',
  '第一次上台|不紧张',
  '家里很远|每天早到',
  '工作很辛苦|从不抱怨',
  '工资不高|很喜欢这份工作',
  '学汉语不久|说得很好',
  '遇到了困难|没有放弃',
  '很聪明|非常刻苦',
  '周末很忙|抽时间陪我',
  '身体不好|坚持锻炼',
  '心情不好|对大家微笑'
]

const ZH_CONDITION_PAIRS: string[] = [
  '明天下雨|比赛取消',
  '你早到|能买到票',
  '有问题|来找我',
  '价格太贵|我们不买',
  '现在出发|来得及',
  '多吃蔬菜|身体更好',
  '认真复习|考得好',
  '天气好|去公园',
  '有空|给你打电话',
  '不懂|问我',
  '周末不忙|一起吃饭',
  '太晚了|明天再说',
  '坚持下去|会成功',
  '多练习|说得流利',
  '早点睡|明天有精神',
  '带地图|不会迷路',
  '坐地铁|更快到',
  '认真学习|通过考试',
  '天气冷|多穿衣服',
  '喜欢这本书|可以借给你'
]

const ZH_PROGRESS_PAIRS: string[] = [
  '会唱歌|会跳舞',
  '学习好|体育好',
  '聪明|努力',
  '会说英语|会说法语',
  '喜欢读书|喜欢写作',
  '工作认真|待人热情',
  '会做饭|会打扫',
  '跑得快|跳得高',
  '有礼貌|很幽默',
  '长得漂亮|心地善良',
  '学习认真|乐于助人',
  '会说汉语|了解中国文化',
  '数学好|英语好',
  '会弹钢琴|会画画',
  '爱运动|爱旅游',
  '做事细心|很有耐心',
  '时间观念强|从不迟到',
  '有想法|敢尝试',
  '对人有礼貌|对事很认真',
  '胃口好|睡眠好'
]

const ZH_PERSON_SUBJECTS: string[] = ['他', '她', '我的同学', '我们', '他们']

class ZhTrend {
  subject: string = ''
  adj: string = ''

  constructor(subject: string, adj: string) {
    this.subject = subject
    this.adj = adj
  }
}

const ZH_TRENDS: ZhTrend[] = [
  new ZhTrend('天气', '冷'),
  new ZhTrend('他的汉语', '好'),
  new ZhTrend('街上的人', '多'),
  new ZhTrend('工作', '忙'),
  new ZhTrend('生活', '方便'),
  new ZhTrend('城市', '美'),
  new ZhTrend('学习', '难'),
  new ZhTrend('孩子', '高'),
  new ZhTrend('环境', '干净'),
  new ZhTrend('朋友', '少')
]

class ZhCompare {
  a: string = ''
  b: string = ''
  adj: string = ''

  constructor(a: string, b: string, adj: string) {
    this.a = a
    this.b = b
    this.adj = adj
  }
}

const ZH_COMPARES: ZhCompare[] = [
  new ZhCompare('他', '我', '高'),
  new ZhCompare('姐姐', '妹妹', '漂亮'),
  new ZhCompare('今天', '昨天', '冷'),
  new ZhCompare('这本书', '那本书', '贵'),
  new ZhCompare('汽车', '自行车', '快'),
  new ZhCompare('西瓜', '苹果', '大'),
  new ZhCompare('我家', '学校', '远'),
  new ZhCompare('哥哥', '弟弟', '忙'),
  new ZhCompare('这个学生', '那个学生', '聪明'),
  new ZhCompare('夏天', '春天', '热')
]

function buildChineseGrammar(): string[] {
  let out: string[] = []
  let serial = 0
  const push = (q: string, correct: string, ds: string[], ex: string): void => {
    let opts: string[] = [correct].concat(ds)
    let k = serial % 4
    let rotated: string[] = opts.slice(k).concat(opts.slice(0, k))
    let ans = (4 - k) % 4
    out.push(`${q}|${rotated.join(';')}|${ans}|${ex}`)
    serial++
  }

  // F1 量词填空（10 名词 × 10 句式 = 100）
  ZH_MEASURE_NOUNS.forEach((n: ZhMeasureNoun) => {
    let ds: string[] = []
    let start = ZH_MEASURES.indexOf(n.measure)
    for (let j = 1; j <= 3; j++) {
      ds.push(ZH_MEASURES[(start + j) % ZH_MEASURES.length])
    }
    let frames: string[] = [
      `这里有一___${n.noun}。`,
      `这___${n.noun}很漂亮。`,
      `那里有三___${n.noun}。`,
      `那___${n.noun}是谁的？`,
      `我看见了一___${n.noun}。`,
      `他买了两___${n.noun}。`,
      `我想再要一___${n.noun}。`,
      `这___${n.noun}很贵。`,
      `一___${n.noun}就够了。`,
      `每___${n.noun}都很好。`
    ]
    frames.forEach((q: string) => {
      push(q, n.measure, ds, `「${n.noun}」的常用量词是「${n.measure}」。`)
    })
  })

  // F2 的 / 地 / 得（40 + 30 + 30 = 100）
  ZH_SLOTS.forEach((s: ZhSlot) => {
    let ds: string[] = []
    let all: string[] = ['的', '地', '得', '之']
    all.forEach((x: string) => {
      if (x !== s.ans) {
        ds.push(x)
      }
    })
    let rule = s.ans === '的' ? '定语修饰名词时用「的」。' : (s.ans === '地' ? '状语修饰动词时用「地」。' : '动词后的补语用「得」。')
    push(`${s.pre}___${s.post}。`, s.ans, ds, rule)
  })

  // F3 把字句（10 动宾 × 10 句式 = 100）
  ZH_OBJ_VERBS.forEach((p: ZhObjVerb) => {
    ZH_PUT_SUBJECTS.forEach((s: string) => {
      let tail = (s === '麻烦你' || s === '记得') ? '' : '了'
      push(`${s}___${p.obj}${p.verb}${tail}。`, '把', ['被', '给', '让'],
        `把字句：主语 + 把 + 宾语 + 动词 + 补语，强调对「${p.obj}」的处理。`)
    })
  })

  // F4 被字句（10 受事 × 10 句式 = 100）
  ZH_PASSIVES.forEach((p: ZhPassive) => {
    let frames: string[] = [
      `${p.thing}___${p.doer}${p.verb}了。`,
      `我的${p.thing}___${p.doer}${p.verb}了。`,
      `${p.thing}昨天___${p.doer}${p.verb}了。`,
      `${p.thing}已经___${p.doer}${p.verb}了。`,
      `${p.thing}一下子___${p.doer}${p.verb}了。`,
      `${p.thing}不小心___${p.doer}${p.verb}了。`,
      `${p.thing}竟然___${p.doer}${p.verb}了。`,
      `${p.thing}全都___${p.doer}${p.verb}了。`,
      `结果${p.thing}___${p.doer}${p.verb}了。`,
      `${p.thing}刚刚___${p.doer}${p.verb}了。`
    ]
    frames.forEach((q: string) => {
      push(q, '被', ['把', '对', '向'],
        `被字句：受事 + 被 + 施事 + 动词 + 补语，表示「${p.thing}」受到动作影响。`)
    })
  })

  // F5 因为…所以…（20 事理 × 5 主语 = 100）
  ZH_CLAUSE_PAIRS.forEach((pair: string) => {
    let arr = pair.split('|')
    ZH_PERSON_SUBJECTS.forEach((s: string) => {
      push(`${s}因为${arr[0]}，___${s}${arr[1]}。`, '所以', ['但是', '如果', '而且'],
        `前因后果用「因为…所以…」。`)
    })
  })

  // F6 虽然…但是…（20 事理 × 5 主语 = 100）
  ZH_CONTRAST_PAIRS.forEach((pair: string) => {
    let arr = pair.split('|')
    ZH_PERSON_SUBJECTS.forEach((s: string) => {
      push(`${s}虽然${arr[0]}，___${s}${arr[1]}。`, '但是', ['而且', '所以', '因为'],
        `转折关系用「虽然…但是…」。`)
    })
  })

  // F7 如果…就…（20 条件 × 5 问法 = 100）
  let condStems = [
    (a: string, b: string): string => `「${a}，${b}」应该用哪组关联词？`,
    (a: string, b: string): string => `请选出最合适的关联词：${a}，${b}。`,
    (a: string, b: string): string => `${a}，${b}。这两句话之间最恰当的关联词是？`,
    (a: string, b: string): string => `连接「${a}」和「${b}」，哪组关联词最合适？`,
    (a: string, b: string): string => `${a}，${b}。填入哪组关联词最通顺？`
  ]
  ZH_CONDITION_PAIRS.forEach((pair: string) => {
    let arr = pair.split('|')
    condStems.forEach((f: (a: string, b: string) => string) => {
      push(f(arr[0], arr[1]), '如果…就', ['因为…所以', '虽然…但是', '不但…而且'],
        `假设关系用「如果…就…」。`)
    })
  })

  // F8 不但…而且…（20 递进 × 5 主语 = 100）
  ZH_PROGRESS_PAIRS.forEach((pair: string) => {
    let arr = pair.split('|')
    ZH_PERSON_SUBJECTS.forEach((s: string) => {
      push(`${s}不但${arr[0]}，___${arr[1]}。`, '而且', ['但是', '所以', '因为'],
        `递进关系用「不但…而且…」。`)
    })
  })

  // F9 越来越…（10 对象 × 10 句式 = 100）
  ZH_TRENDS.forEach((t: ZhTrend) => {
    let frames: string[] = [
      `最近${t.subject}___${t.adj}了。`,
      `${t.subject}变得___${t.adj}。`,
      `一年一年过去，${t.subject}___${t.adj}。`,
      `${t.subject}一天一天___${t.adj}。`,
      `随着时间推移，${t.subject}___${t.adj}。`,
      `现在${t.subject}___${t.adj}了。`,
      `${t.subject}看起来___${t.adj}了。`,
      `${t.subject}比以前___${t.adj}了。`,
      `大家都觉得${t.subject}___${t.adj}了。`,
      `${t.subject}真的___${t.adj}了。`
    ]
    frames.forEach((q: string) => {
      push(q, '越来越', ['更加', '十分', '比较'],
        `「越来越」表示程度随时间递增。`)
    })
  })

  // F10 比字句（10 对象 × 10 句式 = 100）
  ZH_COMPARES.forEach((c: ZhCompare) => {
    let frames: string[] = [
      `${c.a}___${c.b}${c.adj}。`,
      `${c.a}___${c.b}${c.adj}多了。`,
      `${c.a}___${c.b}${c.adj}一点。`,
      `${c.a}___${c.b}更${c.adj}。`,
      `${c.a}___${c.b}${c.adj}得多。`,
      `${c.a}___${c.b}${c.adj}不少。`,
      `我看${c.a}___${c.b}${c.adj}。`,
      `大家都说${c.a}___${c.b}${c.adj}。`,
      `${c.a}确实___${c.b}${c.adj}。`,
      `${c.a}看上去___${c.b}${c.adj}。`
    ]
    frames.forEach((q: string) => {
      push(q, '比', ['跟', '和', '像'],
        `比较句用「A 比 B + 形容词」。`)
    })
  })

  return out
}

export const ZH_GRAMMAR_ALL: string[] = buildChineseGrammar()
