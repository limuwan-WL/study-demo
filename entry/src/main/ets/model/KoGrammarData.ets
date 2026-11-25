// 🌟 韩语语法千题库（独立数据源）：模板生成 1000 题，语法正确、选项互异
// 格式：题干|选项1;选项2;选项3;选项4|答案序号|解析

class KoNoun {
  word: string = ''
  topic: string = ''
  subj: string = ''
  obj: string = ''

  constructor(word: string, topic: string, subj: string, obj: string) {
    this.word = word
    this.topic = topic
    this.subj = subj
    this.obj = obj
  }
}

const KO_NOUNS: KoNoun[] = [
  new KoNoun('책', '책은', '책이', '책을'),
  new KoNoun('물', '물은', '물이', '물을'),
  new KoNoun('밥', '밥은', '밥이', '밥을'),
  new KoNoun('커피', '커피는', '커피가', '커피를'),
  new KoNoun('사과', '사과는', '사과가', '사과를'),
  new KoNoun('옷', '옷은', '옷이', '옷을'),
  new KoNoun('가방', '가방은', '가방이', '가방을'),
  new KoNoun('신발', '신발은', '신발이', '신발을'),
  new KoNoun('영화', '영화는', '영화가', '영화를'),
  new KoNoun('음악', '음악은', '음악이', '음악을'),
  new KoNoun('사진', '사진은', '사진이', '사진을'),
  new KoNoun('편지', '편지는', '편지가', '편지를'),
  new KoNoun('우산', '우산은', '우산이', '우산을'),
  new KoNoun('시계', '시계는', '시계가', '시계를'),
  new KoNoun('자동차', '자동차는', '자동차가', '자동차를'),
  new KoNoun('자전거', '자전거는', '자전거가', '자전거를'),
  new KoNoun('컴퓨터', '컴퓨터는', '컴퓨터가', '컴퓨터를'),
  new KoNoun('휴대폰', '휴대폰은', '휴대폰이', '휴대폰을'),
  new KoNoun('지갑', '지갑은', '지갑이', '지갑을'),
  new KoNoun('우유', '우유는', '우유가', '우유를')
]

const KO_PLACES: string[] = [
  '학교', '도서관', '공원', '카페', '식당', '회사', '시장', '은행', '병원', '집',
  '가게', '영화관', '운동장', '백화점', '약국', '서점', '극장', '박물관', '공항', '역'
]

class KoVerb {
  obj: string = ''
  present: string = ''
  past: string = ''
  future: string = ''
  prog: string = ''
  neg: string = ''

  constructor(obj: string, present: string, past: string, future: string, prog: string, neg: string) {
    this.obj = obj
    this.present = present
    this.past = past
    this.future = future
    this.prog = prog
    this.neg = neg
  }
}

const KO_VERBS: KoVerb[] = [
  new KoVerb('밥을', '먹어요', '먹었어요', '먹을 거예요', '먹고 있어요', '안 먹어요'),
  new KoVerb('책을', '읽어요', '읽었어요', '읽을 거예요', '읽고 있어요', '안 읽어요'),
  new KoVerb('영화를', '봐요', '봤어요', '볼 거예요', '보고 있어요', '안 봐요'),
  new KoVerb('커피를', '마셔요', '마셨어요', '마실 거예요', '마시고 있어요', '안 마셔요'),
  new KoVerb('편지를', '써요', '썼어요', '쓸 거예요', '쓰고 있어요', '안 써요'),
  new KoVerb('숙제를', '해요', '했어요', '할 거예요', '하고 있어요', '안 해요'),
  new KoVerb('노래를', '불러요', '불렀어요', '부를 거예요', '부르고 있어요', '안 불러요'),
  new KoVerb('옷을', '사요', '샀어요', '살 거예요', '사고 있어요', '안 사요'),
  new KoVerb('버스를', '기다려요', '기다렸어요', '기다릴 거예요', '기다리고 있어요', '안 기다려요'),
  new KoVerb('한국어를', '배워요', '배웠어요', '배울 거예요', '배우고 있어요', '안 배워요')
]

const KO_SUBJECTS: string[] = [
  '저는', '우리는', '그는', '그녀는', '친구는', '동생은', '선생님은', '학생은', '가족은', '엄마는'
]

const KO_PAST_TIMES: string[] = [
  '어제', '지난주에', '지난달에', '작년에', '아침에', '점심에', '저녁에', '그저께', '지난 금요일에', '오늘 아침에'
]

const KO_PRESENT_TIMES: string[] = [
  '매일', '보통', '항상', '자주', '가끔', '늘', '매주', '매일 아침', '주말마다', '보통 저녁에'
]

const KO_FUTURE_TIMES: string[] = [
  '내일', '다음 주에', '다음 달에', '내년에', '주말에', '오늘 저녁에', '곧', '이번 주에', '방학에', '3시에'
]

function buildKoreanGrammar(): string[] {
  let out: string[] = []
  let serial = 0
  const push = (q: string, correct: string, ds: string[], ex: string): void => {
    let opts = [correct].concat(ds)
    let k = serial % 4
    let rotated = opts.slice(k).concat(opts.slice(0, k))
    let ans = (4 - k) % 4
    out.push(`${q}|${rotated.join(';')}|${ans}|${ex}`)
    serial++
  }

  // F1 宾格助词 을/를（20 × 5 = 100）
  KO_NOUNS.forEach((n: KoNoun) => {
    const frames: string[] = [
      `저는 ${n.word}___ 샀어요.`,
      `저는 ${n.word}___ 좋아해요.`,
      `${n.word}___ 주세요.`,
      `저는 ${n.word}___ 찾아요.`,
      `저는 ${n.word}___ 가져왔어요.`
    ]
    frames.forEach((q: string) => {
      push(q, n.obj, [n.topic, n.subj, '에'], `宾格助词：${n.word} 作宾语时用 ${n.obj}。`)
    })
  })
  // F2 主题助词 은/는（20 × 5 = 100）
  KO_NOUNS.forEach((n: KoNoun) => {
    const frames: string[] = [
      `${n.word}___ 어때요?`,
      `${n.word}___ 재미있어요.`,
      `${n.word}___ 비싸요.`,
      `${n.word}___ 괜찮아요.`,
      `${n.word}___ 좋아요.`
    ]
    frames.forEach((q: string) => {
      push(q, n.topic, [n.subj, n.obj, '에'], `主题助词：${n.word} 作主题时用 ${n.topic}。`)
    })
  })
  // F3 主格助词 이/가（20 × 5 = 100）
  KO_NOUNS.forEach((n: KoNoun) => {
    const frames: string[] = [
      `${n.word}___ 있어요.`,
      `${n.word}___ 없어요.`,
      `${n.word}___ 많아요.`,
      `${n.word}___ 필요해요.`,
      `${n.word}___ 유명해요.`
    ]
    frames.forEach((q: string) => {
      push(q, n.subj, [n.topic, n.obj, '에'], `主格助词：${n.word} 作主语时用 ${n.subj}。`)
    })
  })
  // F4 场所助词 에（20 × 5 = 100）
  KO_PLACES.forEach((p: string) => {
    const frames: string[] = [
      `${p}___ 가요.`,
      `${p}___ 와요.`,
      `${p}___ 있어요.`,
      `${p}___ 도착했어요.`,
      `${p}___ 갑니다.`
    ]
    frames.forEach((q: string) => {
      push(q, '에', ['에서', '을/를', '이/가'], `表示方向、目的地或存在场所用助词 에。`)
    })
  })
  // F5 动作场所助词 에서（20 × 5 = 100）
  KO_PLACES.forEach((p: string) => {
    const frames: string[] = [
      `${p}___ 공부해요.`,
      `${p}___ 일해요.`,
      `${p}___ 만났어요.`,
      `${p}___ 기다렸어요.`,
      `${p}___ 쉬었어요.`
    ]
    frames.forEach((q: string) => {
      push(q, '에서', ['에', '을/를', '이/가'], `表示动作发生的场所用助词 에서。`)
    })
  })
  // F6 过去时（10 动宾 × 10 时间 = 100）
  KO_VERBS.forEach((v: KoVerb) => {
    KO_PAST_TIMES.forEach((t: string) => {
      push(`${t}, 저는 ${v.obj} ___ .`, v.past, [v.present, v.future, v.prog],
        `${t} 表示已发生，谓语用过去式 ${v.past}。`)
    })
  })
  // F7 一般现在时（10 × 10 = 100）
  KO_VERBS.forEach((v: KoVerb) => {
    KO_PRESENT_TIMES.forEach((t: string) => {
      push(`${t}, 저는 ${v.obj} ___ .`, v.present, [v.past, v.future, v.prog],
        `${t} 表示习惯性动作，谓语用现在时 ${v.present}。`)
    })
  })
  // F8 将来时（10 × 10 = 100）
  KO_VERBS.forEach((v: KoVerb) => {
    KO_FUTURE_TIMES.forEach((t: string) => {
      push(`${t}, 저는 ${v.obj} ___ .`, v.future, [v.present, v.past, v.prog],
        `${t} 表示将来，谓语用 ${v.future}。`)
    })
  })
  // F9 现在进行时（10 主语 × 10 动宾 = 100）
  KO_VERBS.forEach((v: KoVerb) => {
    KO_SUBJECTS.forEach((s: string) => {
      push(`지금 ${s} ${v.obj} ___ .`, v.prog, [v.present, v.past, v.future],
        `지금 提示动作正在进行，用现在进行时 ${v.prog}。`)
    })
  })
  // F10 否定（10 × 10 = 100）
  KO_VERBS.forEach((v: KoVerb) => {
    KO_SUBJECTS.forEach((s: string) => {
      push(`${s} ${v.obj} ___ .`, v.neg, [v.present, v.past, v.future],
        `谓词前加 안 构成否定：${v.neg}。`)
    })
  })
  return out
}

export const KO_GRAMMAR_ALL: string[] = buildKoreanGrammar()
