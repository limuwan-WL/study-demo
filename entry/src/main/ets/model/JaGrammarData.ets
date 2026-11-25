// 🌟 日语语法千题库（独立数据源）：模板生成 1000 题，语法正确、选项互异、答案下标合法
// 格式：题干|选项1;选项2;选项3;选项4|答案序号|解析

const JA_NOUNS: string[] = [
  '本', '水', 'ご飯', 'コーヒー', 'りんご',
  '服', 'かばん', '靴', '映画', '音楽',
  '写真', '手紙', '傘', '時計', '車',
  '自転車', 'パソコン', '携帯', '財布', '牛乳'
]

const JA_PLACES: string[] = [
  '学校', '図書館', '公園', '喫茶店', 'レストラン',
  '会社', '市場', '銀行', '病院', '家',
  '店', '映画館', '運動場', 'デパート', '薬局',
  '本屋', '劇場', '博物館', '空港', '駅'
]

class JaVerb {
  obj: string = ''
  present: string = ''
  past: string = ''
  prog: string = ''
  neg: string = ''

  constructor(obj: string, present: string, past: string, prog: string, neg: string) {
    this.obj = obj
    this.present = present
    this.past = past
    this.prog = prog
    this.neg = neg
  }
}

const JA_VERBS: JaVerb[] = [
  new JaVerb('ご飯を', '食べます', '食べました', '食べています', '食べません'),
  new JaVerb('本を', '読みます', '読みました', '読んでいます', '読みません'),
  new JaVerb('映画を', '見ます', '見ました', '見ています', '見ません'),
  new JaVerb('コーヒーを', '飲みます', '飲みました', '飲んでいます', '飲みません'),
  new JaVerb('手紙を', '書きます', '書きました', '書いています', '書きません'),
  new JaVerb('宿題を', 'します', 'しました', 'しています', 'しません'),
  new JaVerb('歌を', '歌います', '歌いました', '歌っています', '歌いません'),
  new JaVerb('服を', '買います', '買いました', '買っています', '買いません'),
  new JaVerb('バスを', '待ちます', '待ちました', '待っています', '待ちません'),
  new JaVerb('日本語を', '勉強します', '勉強しました', '勉強しています', '勉強しません')
]

const JA_SUBJECTS: string[] = ['私は', '私たちは', '彼は', '彼女は', '友達は', '弟は', '先生は', '学生は', '家族は', '母は']

const JA_PAST_TIMES: string[] = [
  '昨日', '先週', '先月', '去年', '今朝',
  '昨日の昼', 'ゆうべ', '一昨日', '先週の金曜日', '今日の朝'
]

const JA_HABIT_TIMES: string[] = [
  '毎日', 'たいてい', 'いつも', 'よく', '時々',
  '毎週', '毎朝', '週末', 'ふだん', '年末'
]

const JA_THINGS: string[] = ['本', '机', '椅子', 'テレビ', '冷蔵庫', '時計', '傘', 'かばん', '車', '自転車']

function buildJapaneseGrammar(): string[] {
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

  // F1 宾格助词「を」（20 名词 × 5 句式 = 100）
  JA_NOUNS.forEach((n: string) => {
    let frames: string[] = [
      `私は${n}___買いました。`,
      `私は${n}___持っています。`,
      `私は${n}___探しています。`,
      `${n}___ください。`,
      `私は${n}___選びました。`
    ]
    frames.forEach((q: string) => {
      push(q, 'を', ['は', 'が', 'に'], `他动词的宾语用宾格助词「を」。`)
    })
  })

  // F2 主题助词「は」（20 名词 × 5 句式 = 100）
  JA_NOUNS.forEach((n: string) => {
    let frames: string[] = [
      `${n}___どうですか。`,
      `${n}___いいです。`,
      `${n}___有名です。`,
      `${n}___好きではありません。`,
      `${n}___ありません。`
    ]
    frames.forEach((q: string) => {
      push(q, 'は', ['が', 'を', 'に'], `提示已知主题、并对其展开说明时用主题助词「は」。`)
    })
  })

  // F3 主格助词「が」（20 名词 × 5 句式 = 100）
  JA_NOUNS.forEach((n: string) => {
    let frames: string[] = [
      `${n}___あります。`,
      `${n}___ありません。`,
      `${n}___多いです。`,
      `${n}___必要です。`,
      `${n}___人気です。`
    ]
    frames.forEach((q: string) => {
      push(q, 'が', ['は', 'を', 'に'], `表示存在、状态主体或新信息时用主格助词「が」。`)
    })
  })

  // F4 到达点「に」（20 场所 × 5 句式 = 100）
  JA_PLACES.forEach((p: string) => {
    let frames: string[] = [
      `${p}___行きます。`,
      `${p}___来ます。`,
      `${p}___着きました。`,
      `${p}___います。`,
      `${p}___あります。`
    ]
    frames.forEach((q: string) => {
      push(q, 'に', ['で', 'を', 'が'], `移动的到达点或存在的位置用助词「に」。`)
    })
  })

  // F5 动作场所「で」（20 场所 × 5 句式 = 100）
  JA_PLACES.forEach((p: string) => {
    let frames: string[] = [
      `${p}___勉強します。`,
      `${p}___働きます。`,
      `${p}___会いました。`,
      `${p}___待ちました。`,
      `${p}___休みました。`
    ]
    frames.forEach((q: string) => {
      push(q, 'で', ['に', 'を', 'が'], `动作发生的场所用助词「で」。`)
    })
  })

  // F6 过去时（10 动宾 × 10 时间 = 100）
  JA_VERBS.forEach((v: JaVerb) => {
    JA_PAST_TIMES.forEach((t: string) => {
      push(`${t}、私は${v.obj}___。`, v.past, [v.present, v.prog, v.neg],
        `「${t}」表示过去，动词用过去时「${v.past}」。`)
    })
  })

  // F7  habitual 现在时（10 动宾 × 10 频率词 = 100）
  JA_VERBS.forEach((v: JaVerb) => {
    JA_HABIT_TIMES.forEach((t: string) => {
      push(`${t}、私は${v.obj}___。`, v.present, [v.past, v.prog, v.neg],
        `「${t}」表示习惯性动作，动词用现在时「${v.present}」。`)
    })
  })

  // F8 进行时（10 主语 × 10 动宾 = 100）
  JA_VERBS.forEach((v: JaVerb) => {
    JA_SUBJECTS.forEach((s: string) => {
      push(`今、${s}${v.obj}___。`, v.prog, [v.present, v.past, v.neg],
        `「今」表示正在进行，动词用「${v.prog}」。`)
    })
  })

  // F9 否定形（10 主语 × 10 动宾 = 100）
  JA_VERBS.forEach((v: JaVerb) => {
    JA_SUBJECTS.forEach((s: string) => {
      push(`${s}${v.obj}___。`, v.neg, [v.present, v.past, v.prog],
        `否定的礼貌表达用「${v.neg}」。`)
    })
  })

  // F10 存在句「があります」（10 场所 × 10 物品 = 100）
  JA_PLACES.slice(0, 10).forEach((p: string) => {
    JA_THINGS.forEach((t: string) => {
      push(`${p}に${t}___。`, 'があります', ['がいます', 'をあります', 'にあります'],
        `无生命物的存在用「${t}があります」。`)
    })
  })

  return out
}

export const JA_GRAMMAR_ALL: string[] = buildJapaneseGrammar()
