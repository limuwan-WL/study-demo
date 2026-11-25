import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';
import {
  WordItem, wordBank, langByKey, recordStudy, completeLesson, refreshAchievements, masterWord,
  takeBatch, advanceBatchCursor, lessonBatch, planOf, courseSeed, takePracticeBatch, practiceSize
} from '../../model/CourseModel';
import { planFor, levelPlan, wordModeLabel, LevelPlan, moduleVideo } from '../../model/LevelTraining';
import { expLevelOf } from '../../model/GrowthModel';

// 🌟 单词记忆：按等级切换训练玩法（L1 翻卡认词 / L2 看词选义 / L3 看义选词 / L4 拼写默写）
// 🌟 从课程课时进入（带 courseId/lessonIndex 参数）时，完成后自动记录课时进度
@Entry
@Component
struct WordMemoryPage {
  @StorageLink('languageSetting') language: string = 'en'
  @StorageLink('userExp') userExp: number = 0

  @State idx: number = 0
  @State revealed: boolean = false // 翻卡模式：是否已显示释义
  @State knownInSession: number = 0 // 本次新掌握的单词数
  @State recognized: number = 0 // 本次标记认识的单词数（每批内去重）
  @State finished: boolean = false
  @State sessionKnown: string[] = [] // 本次标记认识的词（防止重复计数）
  @State totalWords: number = 0 // 本语言词库总数
  @State masteredBase: number = 0 // 本轮开始前已掌握数（用于展示累计）

  // 🌟 分级训练
  @State level: number = 0
  @State planName: string = ''
  @State planGoal: string = ''
  @State planColor: string = '#55C873'
  @State mode: string = 'flip'
  @State videoUrl: string = ''

  // 🌟 选择题 / 拼写题状态
  @State options: string[] = []
  @State answerIdx: number = 0
  @State picked: number = -1
  @State answered: boolean = false
  @State inputText: string = ''
  @State spellingChecked: boolean = false
  @State spellRight: boolean = false

  private words: WordItem[] = []
  courseId: string = ''
  lessonIndex: number = -1
  startTime: number = 0

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, string>;
    if (params && params['courseId']) {
      this.courseId = params['courseId'];
      this.lessonIndex = params['lessonIndex'] !== undefined ? Number(params['lessonIndex']) : -1;
    }
    this.loadWords()
    this.startTime = Date.now()
  }

  // 🌟 选题：英语按等级取对应内容；其他语种沿用词库批次
  loadWords(): void {
    let known = AppStorage.get<string[]>('wordKnown') ?? []
    if (this.language === 'en') {
      let plan: LevelPlan = planFor(this.courseId, expLevelOf(this.userExp))
      this.level = plan.level
      this.planName = plan.name
      this.planGoal = plan.goal
      this.planColor = plan.color
      this.mode = plan.wordMode
      this.videoUrl = moduleVideo(plan, 'word').url
      let all = plan.words.slice()
      let picked: WordItem[]
      if (this.lessonIndex >= 0) {
        // 课时进入：同一课时始终对应同一词表窗口
        let start = (this.lessonIndex + courseSeed(this.courseId)) % all.length
        picked = all.slice(start).concat(all.slice(0, start)).slice(0, Math.min(8, all.length))
      } else {
        // 🌟 自由练习：每个单词在一个周期内最多出现两次，避免反复刷到同一批题
        picked = takePracticeBatch(all, 'word', plan.level, 8, (w: WordItem) => w.word)
      }
      this.words = this.shuffle(picked)
      this.totalWords = all.length
      this.masteredBase = all.filter((w: WordItem) => known.includes(`${this.language}_${w.word}`)).length
    } else {
      this.level = 0
      this.planName = ''
      this.planGoal = ''
      this.mode = 'flip'
      let all = wordBank(this.language)
      let plan = planOf('word', this.language)
      let size = practiceSize('word', this.language)
      let batch = this.lessonIndex >= 0 ? lessonBatch(all, plan, this.lessonIndex, courseSeed(this.courseId), size) : takeBatch(all, plan, size)
      let fresh: WordItem[] = []
      let learned: WordItem[] = []
      batch.forEach((w: WordItem) => {
        if (known.includes(`${this.language}_${w.word}`)) {
          learned.push(w)
        } else {
          fresh.push(w)
        }
      })
      this.words = this.shuffle(fresh).concat(this.shuffle(learned))
      this.totalWords = all.length
      this.masteredBase = all.filter((w: WordItem) => known.includes(`${this.language}_${w.word}`)).length
    }
    this.resetSession()
  }

  // 重置本次训练状态并生成当前题目的选项
  resetSession(): void {
    this.sessionKnown = []
    this.recognized = 0
    this.knownInSession = 0
    this.idx = 0
    this.revealed = false
    this.picked = -1
    this.answered = false
    this.inputText = ''
    this.spellingChecked = false
    this.spellRight = false
    this.prepareOptions()
  }

  // Fisher-Yates 洗牌，返回新数组
  shuffle(arr: WordItem[]): WordItem[] {
    let a = arr.slice()
    for (let i = a.length - 1; i > 0; i--) {
      let j = Math.floor(Math.random() * (i + 1))
      let tmp = a[i]
      a[i] = a[j]
      a[j] = tmp
    }
    return a
  }

  // 🌟 选择题干扰项：从同等级词汇中取 3 个不同的释义/单词
  prepareOptions(): void {
    if (this.words.length === 0) {
      this.options = []
      return
    }
    let cur = this.words[this.idx]
    let correct = this.mode === 'choice_cn' ? cur.word : cur.meaning
    let others: string[] = []
    this.words.forEach((w: WordItem) => {
      if (w.word !== cur.word) {
        others.push(this.mode === 'choice_cn' ? w.word : w.meaning)
      }
    })
    let distract: string[] = []
    for (let i = others.length - 1; i > 0; i--) {
      let j = Math.floor(Math.random() * (i + 1))
      let tmp = others[i]
      others[i] = others[j]
      others[j] = tmp
    }
    for (let i = 0; i < others.length; i++) {
      if (distract.length >= 3) {
        break
      }
      if (!distract.includes(others[i]) && others[i] !== correct) {
        distract.push(others[i])
      }
    }
    let opts = distract.concat([correct])
    for (let i = opts.length - 1; i > 0; i--) {
      let j = Math.floor(Math.random() * (i + 1))
      let tmp = opts[i]
      opts[i] = opts[j]
      opts[j] = tmp
    }
    this.options = opts
    this.answerIdx = opts.indexOf(correct)
  }

  cur(): WordItem {
    return this.words[this.idx]
  }

  markKnown() {
    if (!this.sessionKnown.includes(this.cur().word)) {
      // concat 重新赋值可触发刷新，保证「本次认识」实时更新
      this.sessionKnown = this.sessionKnown.concat([this.cur().word])
      this.recognized = this.sessionKnown.length
      if (masterWord(this.language, this.cur().word)) {
        this.knownInSession++
      }
    }
  }

  pick(optionIdx: number) {
    if (this.answered) {
      return
    }
    this.picked = optionIdx
    this.answered = true
    if (optionIdx === this.answerIdx) {
      this.markKnown()
    }
  }

  // L4 拼写校验：忽略大小写与首尾空格
  checkSpelling() {
    if (this.spellingChecked) {
      return
    }
    let input = this.inputText.trim()
    if (input === '') {
      promptAction.showToast({ message: '请输入单词拼写' })
      return
    }
    this.spellingChecked = true
    this.spellRight = input.toLowerCase() === this.cur().word.toLowerCase()
    if (this.spellRight) {
      this.markKnown()
    }
  }

  next() {
    if (this.idx >= this.words.length - 1) {
      this.finish()
    } else {
      this.idx++
      this.revealed = false
      this.picked = -1
      this.answered = false
      this.inputText = ''
      this.spellingChecked = false
      this.spellRight = false
      this.prepareOptions()
    }
  }

  finish() {
    this.finished = true
    // 🌟 其他语种自由练习完成一批后推进游标，下次进入换新题
    if (this.language !== 'en' && this.lessonIndex < 0) {
      advanceBatchCursor(planOf('word', this.language), this.totalWords, practiceSize('word', this.language))
    }
    // 🌟 记录学习时长 + 课时进度 + 成就检查
    let minutes = Math.max(1, Math.round((Date.now() - this.startTime) / 60000))
    recordStudy(minutes, this.language)
    let lessonDone = false
    if (this.courseId !== '' && this.lessonIndex >= 0) {
      lessonDone = completeLesson(this.courseId, this.lessonIndex)
    }
    let fresh = refreshAchievements(this.language)
    let tips: string[] = []
    if (lessonDone) {
      tips.push('课时进度 +1')
    }
    if (fresh.length > 0) {
      tips.push(`解锁成就：${fresh.join('、')}`)
    }
    promptAction.showToast({
      message: tips.length > 0 ? tips.join('，') : `已学习 ${minutes} 分钟`
    })
  }

  restart() {
    this.loadWords()
    this.finished = false
    this.startTime = Date.now()
  }

  back() {
    router.back()
  }

  openVideo() {
    if (this.videoUrl === '') {
      return
    }
    router.pushUrl({ url: 'pages/common/WebViewPage', params: { url: this.videoUrl } })
  }

  // 🌟 等级训练信息条：不同等级显示不同目标与训练方式
  @Builder
  levelBanner() {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(`L${this.level + 1}`)
          .fontSize(12).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .padding({ left: 9, right: 9, top: 3, bottom: 3 })
          .backgroundColor(this.planColor).borderRadius(8)
        Text(`${this.planName}训练 · ${wordModeLabel(this.mode)}`)
          .fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
        Blank()
        if (this.videoUrl !== '') {
          Row({ space: 3 }) {
            Text('教学视频').fontSize(11).fontColor(this.planColor)
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(10).fontColor([this.planColor])
          }
          .onClick(() => this.openVideo())
        }
      }.width('100%').alignItems(VerticalAlign.Center)
      Text(this.planGoal).fontSize(11).fontColor($r('app.color.text_hint')).width('100%')
    }
    .width('90%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .border({ width: 1, color: `${this.planColor}33` })
    .margin({ top: 4 })
  }

  // L1 翻卡卡片
  @Builder
  flipCard() {
    Column({ space: 12 }) {
      if (!this.revealed) {
        Text(this.cur().word)
          .fontSize(34).fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
        Text(this.cur().ipa)
          .fontSize(16)
          .fontColor('#DCE9FB')
        Text('点击卡片查看释义')
          .fontSize(11).fontColor('#9DBDF9')
      } else {
        Text(this.cur().word)
          .fontSize(20).fontWeight(FontWeight.Medium)
          .fontColor('#DCE9FB')
          .textAlign(TextAlign.Center)
        Text(this.cur().meaning)
          .fontSize(32).fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
        Text('点击卡片再看单词')
          .fontSize(11).fontColor('#9DBDF9')
      }
    }
    .width('86%')
    .padding(40)
    .linearGradient({ angle: 135, colors: [['#4C8BF5', 0], ['#3F7EF6', 1]] })
    .borderRadius(24)
    .shadow({ radius: 14, color: 'rgba(63,126,246,0.3)', offsetY: 6 })
    .margin({ top: 20 })
    .onClick(() => {
      this.revealed = !this.revealed
    })
  }

  // L2/L3 选择题卡片（看词选义 / 看义选词）
  @Builder
  choiceCard() {
    Column({ space: 14 }) {
      if (this.mode === 'choice_cn') {
        Text(this.cur().meaning)
          .fontSize(26).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .textAlign(TextAlign.Center)
        Text('选出对应的英文单词')
          .fontSize(11).fontColor('#9DBDF9')
      } else {
        Text(this.cur().word)
          .fontSize(30).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .textAlign(TextAlign.Center)
        Text(this.cur().ipa).fontSize(14).fontColor('#9DBDF9')
        Text('选出正确的中文释义')
          .fontSize(11).fontColor('#9DBDF9')
      }
    }
    .width('86%')
    .padding(26)
    .linearGradient({ angle: 135, colors: [['#4C8BF5', 0], ['#3F7EF6', 1]] })
    .borderRadius(20)
    .shadow({ radius: 12, color: 'rgba(63,126,246,0.28)', offsetY: 5 })
    .margin({ top: 20 })

    Column({ space: 10 }) {
      ForEach(this.options, (opt: string, i: number) => {
        Row({ space: 10 }) {
          Text(String.fromCharCode(65 + i))
            .fontSize(12).fontWeight(FontWeight.Bold)
            .width(24).height(24).borderRadius(12)
            .fontColor(this.answered && i === this.answerIdx ? Color.White : $r('app.color.text_sub'))
            .backgroundColor(this.answered && i === this.answerIdx ? '#55C873'
              : (this.answered && i === this.picked ? '#EF4444' : $r('app.color.field_bg')))
            .textAlign(TextAlign.Center)
          Text(opt).fontSize(14).fontColor($r('app.color.text_main')).layoutWeight(1)
        }
        .width('100%')
        .padding(12)
        .borderRadius(12)
        .backgroundColor(this.answered && i === this.answerIdx ? '#55C87314'
          : (this.answered && i === this.picked ? '#EF444414' : $r('app.color.card_bg')))
        .border({ width: 1, color: $r('app.color.divider_color') })
        .onClick(() => this.pick(i))
      }, (opt: string, i: number) => `${this.idx}_${opt}_${this.answered ? 1 : 0}_${this.picked}`)
    }
    .width('90%')
    .margin({ top: 14 })
  }

  // L4 拼写卡片：看释义写单词
  @Builder
  spellCard() {
    Column({ space: 14 }) {
      Text(this.cur().meaning)
        .fontSize(28).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .textAlign(TextAlign.Center)
      Text(this.cur().ipa).fontSize(14).fontColor('#9DBDF9')
      Text('根据释义与音标写出英文单词')
        .fontSize(11).fontColor('#9DBDF9')
    }
    .width('86%')
    .padding(28)
    .linearGradient({ angle: 135, colors: [['#F0574B', 0], ['#EA3D33', 1]] })
    .borderRadius(20)
    .shadow({ radius: 12, color: 'rgba(239,68,68,0.26)', offsetY: 5 })
    .margin({ top: 20 })

    TextInput({ text: this.inputText, placeholder: '输入英文单词' })
      .width('86%')
      .height(48)
      .margin({ top: 16 })
      .enableKeyboardOnFocus(true)
      .onChange((v: string) => {
        this.inputText = v
      })
      .backgroundColor($r('app.color.card_bg'))

    if (this.spellingChecked) {
      Row({ space: 8 }) {
        Text(this.spellRight ? '拼写正确！' : `拼写有误，正确答案：${this.cur().word}`)
          .fontSize(13).fontColor(this.spellRight ? '#55C873' : '#EF4444')
      }.margin({ top: 10 })
    }
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([$r('app.color.text_main')])
          .onClick(() => this.back())
        Text(`单词记忆 · ${langByKey(this.language).name}`).fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 16 })
      }.width('100%').height(60).padding({ left: 16 })

      if (!this.finished) {
        Column() {
          if (this.language === 'en') {
            this.levelBanner()
          }
          // 进度口径：本批按当前等级词量计，累计掌握按等级词表统计
          Text(`本批 ${this.words.length} 个 · 进度 ${this.idx + 1}/${this.words.length} · 剩余 ${this.words.length - this.idx - 1} · 累计掌握 ${this.masteredBase + this.knownInSession}/${this.totalWords}`)
            .fontSize(12).fontColor($r('app.color.text_sub')).margin({ top: 10 })
          Stack({ alignContent: Alignment.Start }) {
            Row().width('100%').height(6).borderRadius(3).backgroundColor($r('app.color.field_bg'))
            Row()
              .width(`${(this.words.length === 0 ? 0 : (this.idx + 1) / this.words.length * 100)}%`)
              .height(6).borderRadius(3).backgroundColor(this.planColor)
          }.width('90%').margin({ top: 8 })

          if (this.mode === 'flip') {
            this.flipCard()
            // 认识 / 不认识
            Row({ space: 14 }) {
              Text('不认识')
                .fontSize(15).fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_sub'))
                .padding({ left: 30, right: 30, top: 12, bottom: 12 })
                .backgroundColor($r('app.color.card_bg'))
                .borderRadius(22)
                .border({ width: 1, color: $r('app.color.divider_color') })
                .onClick(() => {
                  this.revealed = true
                  setTimeout((): void => this.next(), 400)
                })
              Text('认识')
                .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
                .padding({ left: 30, right: 30, top: 12, bottom: 12 })
                .backgroundColor('#55C873')
                .borderRadius(22)
                .onClick(() => {
                  this.markKnown()
                  this.next()
                })
            }.margin({ top: 24 })
          } else if (this.mode === 'spell') {
            this.spellCard()
            Row({ space: 14 }) {
              Text(this.spellingChecked ? '下一词' : '跳过')
                .fontSize(15).fontWeight(FontWeight.Medium)
                .fontColor(this.spellingChecked ? Color.White : $r('app.color.text_sub'))
                .padding({ left: 34, right: 34, top: 12, bottom: 12 })
                .backgroundColor(this.spellingChecked ? this.planColor : $r('app.color.card_bg'))
                .borderRadius(22)
                .border({ width: this.spellingChecked ? 0 : 1, color: $r('app.color.divider_color') })
                .onClick(() => {
                  if (!this.spellingChecked) {
                    this.spellingChecked = true
                    this.spellRight = false
                  }
                  this.next()
                })
              if (!this.spellingChecked) {
                Text('提交')
                  .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
                  .padding({ left: 34, right: 34, top: 12, bottom: 12 })
                  .backgroundColor(this.planColor).borderRadius(22)
                  .onClick(() => this.checkSpelling())
              }
            }.margin({ top: 20 })
          } else {
            this.choiceCard()
            if (this.answered) {
              Text(this.idx >= this.words.length - 1 ? '查看结果' : '下一词')
                .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
                .width('88%').textAlign(TextAlign.Center)
                .padding({ top: 12, bottom: 12 })
                .backgroundColor(this.planColor).borderRadius(22)
                .margin({ top: 16 })
                .onClick(() => this.next())
            }
          }

          Text(`本次认识 ${this.recognized} 个 · 新掌握 ${this.knownInSession} 个`)
            .fontSize(12).fontColor($r('app.color.text_hint')).margin({ top: 16 })
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        // 完成页
        Column({ space: 16 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(64).fontColor(['#55C873'])
          Text(this.language === 'en' ? `L${this.level + 1} ${this.planName}训练完成！` : '本轮学习完成！')
            .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Text(`本批 ${this.words.length} 个 · 本次认识 ${this.recognized} 个（新掌握 ${this.knownInSession} 个）· 累计掌握 ${this.masteredBase + this.knownInSession}/${this.totalWords}`)
            .fontSize(14).fontColor($r('app.color.text_sub'))
          if (this.language === 'en') {
            Text(`下一阶段：${levelPlan(Math.min(3, this.level + 1)).name} · ${levelPlan(Math.min(3, this.level + 1)).methods[0]}`)
              .fontSize(12).fontColor($r('app.color.text_hint'))
          }
          Row({ space: 12 }) {
            Text('再学一遍')
              .fontSize(14).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.primary'))
              .padding({ left: 24, right: 24, top: 11, bottom: 11 })
              .borderRadius(20)
              .border({ width: 1, color: $r('app.color.primary') })
              .onClick(() => this.restart())
            Text('完成')
              .fontSize(14).fontWeight(FontWeight.Medium).fontColor(Color.White)
              .padding({ left: 24, right: 24, top: 11, bottom: 11 })
              .backgroundColor($r('app.color.primary'))
              .borderRadius(20)
              .onClick(() => this.back())
          }.margin({ top: 10 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
