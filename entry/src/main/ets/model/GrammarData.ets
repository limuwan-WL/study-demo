// 🌟 英语语法题库原始数据：每条格式「题干|选项1;选项2;选项3;选项4|答案序号|解析」
// 纯数据文件（不 import 任何模块，避免与 CourseModel 循环依赖）
// 由 CourseModel.grammarBank('en') 解析为 GrammarQ，共 1000 题（手写 60 + 模板生成 940）
// 覆盖：主谓一致、名词、时态、被动语态、情态动词、非谓语、冠词、代词、
// 介词、连词与从句、比较等级、反意疑问、感叹句、特殊句型、情景交际
export const EN_GRAMMAR_RAW: string[] = [
  'She ___ a student.|is;are;am;be|0|She 是第三人称单数，be 动词用 is。',
  'They ___ my friends.|is;are;am;be|1|They 是复数，be 动词用 are。',
  'I ___ from China.|am;is;are;be|0|主语 I 搭配 be 动词 am。',
  'The cat ___ on the bed.|is;are;am;were|0|The cat 是第三人称单数，用 is。',
  'There ___ a book on the desk.|is;are;be;am|0|there be 结构遵循就近原则，a book 单数用 is。',
  'There ___ many trees in the park.|is;are;was;be|1|many trees 是复数，用 are。',
  'He ___ not at home yesterday.|is;are;was;were|2|yesterday 表过去，第三人称单数用 was。',
  'We ___ happy last night.|are;is;was;were|3|last night 表过去，We 搭配 were。',
  'Look! The children ___ playing football.|is;are;am;be|1|children 是复数，现在进行时用 are playing。',
  'My father and mother ___ both teachers.|is;are;was;am|1|并列主语是复数，用 are。',
  'Everyone ___ here.|is;are;am;be|0|everyone 等不定代词作单数，用 is。',
  'The news ___ exciting.|is;are;am;be|0|news 以 s 结尾但不可数，作单数。',
  'Mathematics ___ my favorite subject.|is;are;am;be|0|学科名词作单数，用 is。',
  'Each of us ___ a dictionary.|have;has;is;are|1|each of + 复数名词作单数，用 has。',
  'Neither answer ___ correct.|is;are;am;be|0|neither 表示两者都不，作单数。',
  'Ten years ___ a long time.|is;are;am;be|0|时间段作整体看待，用单数 is。',
  'The police ___ looking for the thief.|is;are;was;am|1|police 是集合名词，通常作复数。',
  'My glasses ___ on the table.|is;are;was;be|1|glasses（眼镜）由两部分组成，常用复数。',
  'One of my friends ___ from Canada.|come;comes;coming;is come|1|one of + 复数名词作单数，动词加 s。',
  'The number of students ___ increasing.|is;are;am;be|0|the number of 指「…的数量」，作单数。',
  'A number of books ___ on the shelf.|is;are;was;be|1|a number of 意为「许多」，后接复数动词。',
  'Either you or he ___ right.|is;are;am;be|0|either...or 遵循就近原则，he 单数用 is。',
  'Not only the students but also the teacher ___ late.|was;were;is;are|0|not only...but also 就近原则，the teacher 单数。',
  'Physics ___ not easy to learn.|is;are;am;were|0|学科名词作单数，用 is。',
  'Tom with his friends ___ playing basketball now.|is;are;am;were|0|with 短语不影响主语，主语 Tom 单数。',
  'There ___ some milk in the glass.|is;are;have;has|0|milk 不可数，用 is。',
  'There ___ two cups of tea on the table.|is;are;was;be|1|two cups 是复数，用 are。',
  'Both of them ___ good at English.|is;are;am;be|1|both of them 表示两者都，作复数。',
  'Nobody ___ in the room.|is;are;am;were|0|nobody 不定代词作单数。',
  'My family ___ a big one.|is;are;am;be|0|family 指整体时作单数。',
  'I have two ___.|knife;knifes;knives;knive|2|knife 的复数是 knives，f 变 ves。',
  'There are five ___ in the zoo.|wolf;wolfs;wolves;wolfes|2|wolf 的复数是 wolves，f 变 ves。',
  'How many ___ are there in a year?|month;months;months\';monthies|1|month 的复数直接加 s。',
  'I bought three ___ of bread.|loaf;loafs;loaves;loafes|2|loaf 的复数是 loaves，f 变 ves。',
  'Please give me two ___.|box;boxes;boxs;boxen|1|box 以 x 结尾，复数加 es。',
  'The ___ are singing in the tree.|bird;birds;birdes;birdies|1|bird 的复数直接加 s。',
  'There ___ some water in the bottle.|is;are;have;has|0|water 不可数，用 is。',
  'I would like two ___ of coffee.|cup;cups;cupes;cupies|1|cup 的复数直接加 s。',
  'She bought two ___.|potato;potatoes;potatos;potatoe|1|potato 的复数加 es。',
  'There are many ___ on the farm.|sheep;sheeps;sheepes;sheepies|0|sheep 单复数同形。',
  'Look at those ___! They are eating grass.|deer;deers;deeres;deeries|0|deer 单复数同形。',
  'His ___ are big.|foot;foots;feet;feetes|2|foot 的复数是 feet，oo 变 ee。',
  'The child is brushing his ___.|tooth;tooths;teeth;toothes|2|tooth 的复数是 teeth，oo 变 ee。',
  'Three ___ visited our school yesterday.|woman;womans;women;womanes|2|woman 的复数是 women。',
  'Two ___ are playing chess.|man;mannes;men;manes|2|man 的复数是 men。',
  'Autumn is the best ___ to visit Beijing.|time;times;timies;times\'|0|「最佳时机」用 a/the best time，单数。',
  'I need some ___ about the school.|information;informations;informing;informs|0|information 不可数，没有复数形式。',
  'He gave me a useful piece of ___.|advice;advices;advising;advise|0|advice 不可数，「一条建议」用 a piece of advice。',
  'We had a lot of ___ last night.|rain;rains;raining;rained|0|rain 表雨水时不可数。',
  'The factory has five hundred ___.|worker;workers;workeres;workeries|1|数词后接可数名词复数 workers。',
  'This is ___ bedroom.|Tom and Mary\'s;Tom\'s and Mary\'s;Tom and Mary;Toms and Marys|0|两人共用某物只在最后一个名词后加 \'s。',
  'These are ___ books.|the children\'s;the childrens\';the children;children\'s the|0|children 是复数，所有格直接加 \'s。',
  'June 1st is ___ Day.|Child;Children;Childrens;Children\'s|3|儿童节固定表达为 Children\'s Day。',
  'There are sixty ___ in an hour.|minute;minutes;minute\'s;minutes\'|1|sixty 后接复数 minutes。',
  'I\'m hungry. I want something ___.|eat;to eat;eating;ate|1|不定式 to eat 作后置定语修饰 something。',
  'This is the ___ office.|teacher;teacher\'s;teachers\';teachers|2|多位老师共用的办公室用复数所有格 teachers\'。',
  'He bought ___ yesterday.|two pairs of shoes;two pair of shoes;two pairs of shoe;two pair shoes|0|pair 有复数形式，shoes 也用复数。',
  'Would you like ___?|some tea;some teas;a tea;teas|0|tea 不可数，「来点茶」用 some tea。',
  'The population of China ___ very large.|is;are;am;were|0|population 表人口总数时作单数。',
  '___ weather it is today!|What fine;What a fine;How fine;How a fine|0|weather 不可数，What + 形容词 + 不可数名词。',
]

// ==================== 模板生成区：手写 60 题 + 生成 940 题 = 1000 题 ====================
// 生成规则完全确定：每个模板族做「主语 × 动词/名词/搭配」笛卡尔组合，答案由语法规则机械推导，
// 选项按序号轮转，保证四选项互不相同且正确答案位置均匀分布

class VerbForms {
  base: string = ''
  third: string = ''
  ing: string = ''
  past: string = ''
  obj: string = ''

  constructor(base: string, third: string, ing: string, past: string, obj: string) {
    this.base = base
    this.third = third
    this.ing = ing
    this.past = past
    this.obj = obj
  }
}

// 10 个动词：四种形态拼写互不相同（保证选项不重复）
const GEN_VERBS: VerbForms[] = [
  new VerbForms('play', 'plays', 'playing', 'played', 'football'),
  new VerbForms('watch', 'watches', 'watching', 'watched', 'TV'),
  new VerbForms('clean', 'cleans', 'cleaning', 'cleaned', 'the room'),
  new VerbForms('wash', 'washes', 'washing', 'washed', 'clothes'),
  new VerbForms('study', 'studies', 'studying', 'studied', 'English'),
  new VerbForms('like', 'likes', 'liking', 'liked', 'music'),
  new VerbForms('love', 'loves', 'loving', 'loved', 'sports'),
  new VerbForms('do', 'does', 'doing', 'did', 'homework'),
  new VerbForms('teach', 'teaches', 'teaching', 'taught', 'math'),
  new VerbForms('write', 'writes', 'writing', 'wrote', 'letters')
]

// 第三人称单数主语 / 非三单主语
const SINGULAR_SUBJECTS: string[] = ['He', 'She', 'Tom', 'Mary', 'My father', 'Her brother', 'The boy', 'Lucy', 'John', 'This student']
const NON_THIRD_SUBJECTS: string[] = ['I', 'We', 'You', 'They', 'The students', 'My friends', 'Tom and Jack', 'The children', 'His parents', 'People']
// 进行时用：is 组 / are 组
const IS_SUBJECTS: string[] = ['He', 'She', 'Tom', 'The boy', 'Lucy']
const ARE_SUBJECTS: string[] = ['They', 'We', 'The children', 'My friends', 'Tom and Jack']

class PluralNoun {
  sing: string = ''
  plural: string = ''
  wrong1: string = ''
  wrong2: string = ''
  scene: string = '' // 该名词专属的场景状语，保证同族题干全局唯一

  constructor(sing: string, plural: string, wrong1: string, wrong2: string, scene: string) {
    this.sing = sing
    this.plural = plural
    this.wrong1 = wrong1
    this.wrong2 = wrong2
    this.scene = scene
  }
}

const GEN_NOUNS: PluralNoun[] = [
  new PluralNoun('child', 'children', 'childs', 'childrens', 'at the birthday party'),
  new PluralNoun('man', 'men', 'mans', 'manies', 'in the office'),
  new PluralNoun('woman', 'women', 'womans', 'womenes', 'in the clothes shop'),
  new PluralNoun('foot', 'feet', 'foots', 'feetes', 'in the picture'),
  new PluralNoun('tooth', 'teeth', 'tooths', 'teethes', 'in the diagram'),
  new PluralNoun('mouse', 'mice', 'mouses', 'mousees', 'under the sofa'),
  new PluralNoun('knife', 'knives', 'knifes', 'knivees', 'in the kitchen'),
  new PluralNoun('wolf', 'wolves', 'wolfs', 'wolvees', 'in the forest'),
  new PluralNoun('leaf', 'leaves', 'leafs', 'leavees', 'on the tree'),
  new PluralNoun('box', 'boxes', 'boxs', 'boxies', 'on the shelf'),
  new PluralNoun('watch', 'watches', 'watchs', 'watchies', 'in the shop window'),
  new PluralNoun('potato', 'potatoes', 'potatos', 'potatoies', 'in the basket'),
  new PluralNoun('tomato', 'tomatoes', 'tomatos', 'tomatoies', 'in the salad'),
  new PluralNoun('photo', 'photos', 'photoes', 'photoies', 'on the wall'),
  new PluralNoun('city', 'cities', 'citys', 'citizes', 'on the map'),
  new PluralNoun('story', 'stories', 'storys', 'storizes', 'in the book'),
  new PluralNoun('boy', 'boys', 'boies', 'boyes', 'in the playground'),
  new PluralNoun('girl', 'girls', 'girles', 'girlies', 'in the classroom'),
  new PluralNoun('book', 'books', 'bookes', 'bookies', 'on the desk'),
  new PluralNoun('sheep', 'sheep', 'sheeps', 'sheepies', 'on the farm')
]

class PrepPattern {
  head: string = ''
  prep: string = ''
  objs: string[] = []
  ds: string[] = []

  constructor(head: string, prep: string, objs: string[], ds: string[]) {
    this.head = head
    this.prep = prep
    this.objs = objs
    this.ds = ds
  }
}

const GEN_PREPS: PrepPattern[] = [
  new PrepPattern('He is good', 'at', ['English', 'math', 'music', 'sports', 'drawing'], ['in', 'on', 'for']),
  new PrepPattern('She is interested', 'in', ['music', 'science', 'art', 'history', 'math'], ['at', 'on', 'for']),
  new PrepPattern('The child is afraid', 'of', ['dogs', 'snakes', 'thunder', 'darkness', 'heights'], ['at', 'in', 'on']),
  new PrepPattern('Please listen', 'to', ['the teacher', 'the song', 'the story', 'the music', 'me'], ['at', 'in', 'on']),
  new PrepPattern('Look', 'at', ['the blackboard', 'the picture', 'the bird', 'the map', 'the moon'], ['in', 'on', 'for']),
  new PrepPattern('They arrived', 'in', ['Beijing', 'Shanghai', 'China', 'Wuhan', 'Nanjing'], ['at', 'on', 'to']),
  new PrepPattern('We are waiting', 'for', ['the bus', 'you', 'him', 'the answer', 'the result'], ['at', 'in', 'on']),
  new PrepPattern('Children depend', 'on', ['their parents', 'him', 'her', 'the team', 'luck'], ['in', 'at', 'for']),
  new PrepPattern('This book belongs', 'to', ['me', 'him', 'the club', 'her', 'them'], ['with', 'for', 'on']),
  new PrepPattern('He is late', 'for', ['school', 'work', 'class', 'the meeting', 'the party'], ['to', 'in', 'at']),
  new PrepPattern('My bag is different', 'from', ['yours', 'his', 'hers', 'theirs', 'mine'], ['with', 'to', 'of']),
  new PrepPattern('The bottle is full', 'of', ['water', 'milk', 'juice', 'tea', 'books'], ['with', 'in', 'by']),
  new PrepPattern('We are proud', 'of', ['our team', 'him', 'her', 'the result', 'China'], ['for', 'with', 'in']),
  new PrepPattern('The teacher is strict', 'with', ['us', 'them', 'him', 'her', 'the students'], ['to', 'about', 'of']),
  new PrepPattern('She is angry', 'about', ['his words', 'the result', 'the news', 'the plan', 'this'], ['with', 'to', 'of']),
  new PrepPattern('The city is famous', 'for', ['its food', 'its bridges', 'the temple', 'the museum', 'its parks'], ['as', 'to', 'of']),
  new PrepPattern('My home is far', 'from', ['the station', 'school', 'the park', 'the airport', 'the hospital'], ['to', 'of', 'at']),
  new PrepPattern('The bank is close', 'to', ['the school', 'the park', 'the hospital', 'the station', 'the shop'], ['from', 'of', 'with']),
  new PrepPattern('She is married', 'to', ['a doctor', 'a teacher', 'an engineer', 'a farmer', 'a nurse'], ['with', 'from', 'of']),
  new PrepPattern('We are worried', 'about', ['the exam', 'him', 'her', 'the result', 'the trip'], ['of', 'with', 'for'])
]

class AdjForms {
  base: string = ''
  comp: string = ''
  sup: string = ''
  wrong: string = ''
  s1: string = '' // 该形容词专属的比较句一，保证题干全局唯一
  s2: string = '' // 该形容词专属的比较句二，保证题干全局唯一

  constructor(base: string, comp: string, sup: string, wrong: string, s1: string, s2: string) {
    this.base = base
    this.comp = comp
    this.sup = sup
    this.wrong = wrong
    this.s1 = s1
    this.s2 = s2
  }
}

const GEN_ADJS: AdjForms[] = [
  new AdjForms('tall', 'taller', 'tallest', 'more tall',
    'My brother is ___ than my sister.', 'This tree is ___ than that tree.'),
  new AdjForms('big', 'bigger', 'biggest', 'more big',
    'My schoolbag is ___ than yours.', 'This apple is ___ than that one.'),
  new AdjForms('happy', 'happier', 'happiest', 'more happy',
    'Mary looks ___ today than yesterday.', 'The children are ___ than before.'),
  new AdjForms('good', 'better', 'best', 'more good',
    'My English is ___ than my math.', 'This film is ___ than that one.'),
  new AdjForms('many', 'more', 'most', 'manyer',
    'There are ___ books in this shop than in that shop.', 'I can see ___ birds today than yesterday.'),
  new AdjForms('beautiful', 'more beautiful', 'most beautiful', 'beautifuller',
    'This garden is ___ than that one.', 'Her dress is ___ than mine.'),
  new AdjForms('fast', 'faster', 'fastest', 'more fast',
    'This car is ___ than that bike.', 'This train is ___ than that bus.'),
  new AdjForms('slow', 'slower', 'slowest', 'more slow',
    'My computer is ___ than yours.', 'The old bus is ___ than the new one.'),
  new AdjForms('old', 'older', 'oldest', 'more old',
    'My grandfather is ___ than my father.', 'This temple is ___ than that bridge.'),
  new AdjForms('young', 'younger', 'youngest', 'more young',
    'My sister is ___ than me.', 'The students in Class One are ___ than the students in Class Two.'),
  new AdjForms('long', 'longer', 'longest', 'more long',
    'This river is ___ than that river.', 'Her hair is ___ than mine.'),
  new AdjForms('short', 'shorter', 'shortest', 'more short',
    'This ruler is ___ than that one.', 'My pencil is ___ than yours.'),
  new AdjForms('hot', 'hotter', 'hottest', 'more hot',
    'It is ___ today than yesterday.', 'This soup is ___ than that soup.'),
  new AdjForms('cold', 'colder', 'coldest', 'more cold',
    'It is ___ in winter than in autumn.', 'This drink is ___ than that one.'),
  new AdjForms('easy', 'easier', 'easiest', 'more easy',
    'This book is ___ than that one.', 'The first question is ___ than the second one.'),
  new AdjForms('hard', 'harder', 'hardest', 'more hard',
    'This task is ___ than that task.', 'This chair is ___ than that sofa.'),
  new AdjForms('bad', 'worse', 'worst', 'more bad',
    'The weather is ___ today than yesterday.', 'His answer is ___ than mine.'),
  new AdjForms('little', 'less', 'least', 'littler',
    'There is ___ water in this bottle than in that one.', 'She has ___ money than her brother.'),
  new AdjForms('far', 'farther', 'farthest', 'more far',
    'My home is ___ from school than yours.', 'This shop is ___ from here than that one.'),
  new AdjForms('careful', 'more careful', 'most careful', 'carefuller',
    'Tom is ___ than Jack.', 'Mary is ___ than her brother.')
]

// 反意疑问句模板：肯定陈述 + 否定反问
class TagPattern {
  stems: string[] = []
  tag: string = ''

  constructor(stems: string[], tag: string) {
    this.stems = stems
    this.tag = tag
  }
}

const GEN_TAGS: TagPattern[] = [
  new TagPattern(['He is a student', 'He is a teacher', 'He is a doctor', 'He is a nurse', 'He is a worker',
    'He is a farmer', 'He is a singer', 'He is a driver', 'He is a cook', 'He is a writer'], "isn't he"),
  new TagPattern(['They are students', 'They are teachers', 'They are workers', 'They are farmers', 'They are doctors',
    'They are nurses', 'They are singers', 'They are drivers', 'They are friends', 'They are classmates'], "aren't they"),
  new TagPattern(['She likes music', 'She likes sports', 'She likes English', 'She likes art', 'She likes science',
    'She likes math', 'She likes cooking', 'She likes reading', 'She likes swimming', 'She likes painting'], "doesn't she"),
  new TagPattern(['Tom plays football', 'Tom watches TV', 'Tom reads books', 'Tom studies English', 'Tom cleans the room',
    'Tom washes clothes', 'Tom does homework', 'Tom teaches math', 'Tom writes letters', 'Tom likes music'], "doesn't he"),
  new TagPattern(['We are students', 'We are friends', 'We are classmates', 'We are teachers', 'We are workers',
    'We are happy', 'We are ready', 'We are busy', 'We are late', 'We are a family'], "aren't we"),
  new TagPattern(['You like English', 'You like music', 'You like sports', 'You like art', 'You like science',
    'You like math', 'You like coffee', 'You like tea', 'You like reading', 'You like traveling'], "don't you"),
  new TagPattern(['He can swim', 'He can skate', 'He can sing', 'He can dance', 'He can cook',
    'He can drive', 'He can run', 'He can jump', 'He can read', 'He can write'], "can't he"),
  new TagPattern(['Mary will come', 'Mary will go', 'Mary will leave', 'Mary will return', 'Mary will arrive',
    'Mary will help', 'Mary will stay', 'Mary will win', 'Mary will join', 'Mary will call'], "won't she"),
  new TagPattern(['It is a dog', 'It is a cat', 'It is a bird', 'It is a fish', 'It is a rabbit',
    'It is a duck', 'It is a pig', 'It is a horse', 'It is a sheep', 'It is a panda'], "isn't it"),
  new TagPattern(['They have finished', 'They have arrived', 'They have left', 'They have eaten', 'They have started',
    'They have won', 'They have returned', 'They have gone', 'They have come', 'They have agreed'], "haven't they")
]

const TAG_DISTRACTORS_POS: string[] = ['is he', 'does he', 'are they', 'do you', 'can he', 'will she', 'is it', 'have they', 'does she', 'are we']

function buildGeneratedGrammar(): string[] {
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

  // F1 一般现在时·三单（100 题）
  SINGULAR_SUBJECTS.forEach((s: string) => {
    GEN_VERBS.forEach((v: VerbForms) => {
      push(`${s} ___ ${v.obj} every day.`, v.third, [v.base, v.ing, v.past],
        'every day 表示习惯性动作，主语是第三人称单数，动词用第三人称单数形式。')
    })
  })
  // F2 一般现在时·非三单（100 题）
  NON_THIRD_SUBJECTS.forEach((s: string) => {
    GEN_VERBS.forEach((v: VerbForms) => {
      push(`${s} ___ ${v.obj} every day.`, v.base, [v.third, v.ing, v.past],
        'every day 表示习惯性动作，主语不是第三人称单数，动词用原形。')
    })
  })
  // F3 现在进行时（100 题）
  IS_SUBJECTS.forEach((s: string) => {
    GEN_VERBS.forEach((v: VerbForms) => {
      push(`Look! ${s} ___ ${v.obj}.`, `is ${v.ing}`, [`are ${v.ing}`, v.third, v.base],
        'Look! 提示动作正在进行，用现在进行时 be + V-ing；主语是单数，be 用 is。')
    })
  })
  ARE_SUBJECTS.forEach((s: string) => {
    GEN_VERBS.forEach((v: VerbForms) => {
      push(`Look! ${s} ___ ${v.obj}.`, `are ${v.ing}`, [`is ${v.ing}`, v.base, v.past],
        'Look! 提示动作正在进行，用现在进行时 be + V-ing；主语是复数，be 用 are。')
    })
  })
  // F4 一般过去时（100 题）
  IS_SUBJECTS.concat(ARE_SUBJECTS).forEach((s: string) => {
    GEN_VERBS.forEach((v: VerbForms) => {
      push(`${s} ___ ${v.obj} yesterday.`, v.past, [v.base, v.third, v.ing],
        'yesterday 表示过去发生的动作，动词用过去式。')
    })
  })
  // F5 一般将来时（100 题）
  IS_SUBJECTS.concat(ARE_SUBJECTS).forEach((s: string) => {
    GEN_VERBS.forEach((v: VerbForms) => {
      push(`${s} ___ ${v.obj} tomorrow.`, `will ${v.base}`, [v.third, v.ing, v.past],
        'tomorrow 表示将来的动作，用 will + 动词原形。')
    })
  })
  // F6 一般疑问句 Do/Does（100 题）
  IS_SUBJECTS.concat(['Mary', 'My father', 'Her brother', 'John', 'This student']).forEach((s: string) => {
    GEN_VERBS.forEach((v: VerbForms) => {
      push(`___ ${s} ${v.base} ${v.obj} every day?`, 'Does', ['Do', 'Is', 'Are'],
        '主语是第三人称单数，一般疑问句用 Does 开头，句中动词用原形。')
    })
  })
  // F7 反意疑问句（100 题）
  GEN_TAGS.forEach((p: TagPattern, pi: number) => {
    p.stems.forEach((stem: string) => {
      let d1 = TAG_DISTRACTORS_POS[pi]
      let d2 = GEN_TAGS[(pi + 3) % GEN_TAGS.length].tag
      let d3 = TAG_DISTRACTORS_POS[(pi + 5) % TAG_DISTRACTORS_POS.length]
      push(`${stem}, ___?`, p.tag, [d1, d2, d3],
        '陈述部分为肯定，反意疑问部分用否定形式，前后人称与助动词保持一致。')
    })
  })
  // F8 名词复数（100 题）：每个名词带专属场景状语，20 × 5 个句式 → 100 条题干互不相同
  GEN_NOUNS.forEach((n: PluralNoun) => {
    let frames: string[] = [
      `There are three ___ ${n.scene}.`,
      `I can see many ___ ${n.scene}.`,
      `How many ___ are there ${n.scene}?`,
      `She counted five ___ ${n.scene}.`,
      `Look! There are lots of ___ ${n.scene}.`
    ]
    frames.forEach((f: string) => {
      push(f, n.plural, [n.sing === n.plural ? `${n.sing}es` : n.sing, n.wrong1, n.wrong2],
        `${n.sing} 的复数形式是 ${n.plural}，数词与 many 后接可数名词复数。`)
    })
  })
  // F9 介词固定搭配（100 题）
  GEN_PREPS.forEach((p: PrepPattern) => {
    p.objs.forEach((o: string) => {
      push(`${p.head} ___ ${o}.`, p.prep, p.ds, `固定搭配：${p.head} ${p.prep} ${o}，介词用 ${p.prep}。`)
    })
  })
  // F10 形容词比较级（40 题）：每个形容词两条专属比较句 → 40 条题干互不相同
  GEN_ADJS.forEach((a: AdjForms) => {
    push(a.s1, a.comp, [a.base, a.sup, a.wrong], `than 前用比较级，${a.base} 的比较级是 ${a.comp}。`)
    push(a.s2, a.comp, [a.base, a.sup, a.wrong], `than 前用比较级，${a.base} 的比较级是 ${a.comp}。`)
  })
  return out
}

// 手写 60 题的原始答案位置分布不均（30/19/9/2），这里按选项轮转重排为 15/15/15/15，
// 生成部分本身按 serial % 4 轮转（每种 235 题），合起来答案位置正好 250/250/250/250
function balancedRawAnswers(): string[] {
  let out: string[] = []
  EN_GRAMMAR_RAW.forEach((line: string, i: number) => {
    let parts = line.split('|')
    if (parts.length < 4) {
      out.push(line)
      return
    }
    let opts = parts[1].split(';')
    let orig = Number(parts[2])
    let slot = i % 4
    let shift = (orig - slot + 4) % 4
    let rotated = opts.slice(shift).concat(opts.slice(0, shift))
    out.push(`${parts[0]}|${rotated.join(';')}|${slot}|${parts[3]}`)
  })
  return out
}

// 🌟 完整题库：手写 60 + 生成 940 = 1000 题
export const EN_GRAMMAR_ALL: string[] = balancedRawAnswers().concat(buildGeneratedGrammar())
