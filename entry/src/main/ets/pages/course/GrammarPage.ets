import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';
import { GrammarQ, grammarBank, langByKey, recordStudy, completeLesson, refreshAchievements, takeBatch, advanceBatchCursor, lessonBatch, planOf, courseSeed, takePracticeBatch, practiceSize } from '../../model/CourseModel';
import { planFor, LevelPlan, moduleVideo } from '../../model/LevelTraining';
import { expLevelOf } from '../../model/GrowthModel';

// 🌟 语法练习：单选题即时批改 + 解析；一次全对解锁「语法达人」成就
// 🌟 英语按等级取对应语法专题（L1 基础句型 / L2 时态 / L3 从句被动 / L4 高级结构）
// 🌟 从课程课时进入（带 courseId/lessonIndex 参数）时，完成后自动记录课时进度
@Entry
@Component
struct GrammarPage {
  @StorageLink('languageSetting') language: string = 'en'
  @StorageLink('userExp') userExp: number = 0

  @State idx: number = 0
  @State selected: number = -1
  @State answered: boolean = false
  @State correctCount: number = 0
  @State finished: boolean = false

  // 🌟 分级训练
  @State level: number = 0
  @State planName: string = ''
  @State planGoal: string = ''
  @State planColor: string = '#55C873'
  @State grammarFocus: string = ''
  @State videoUrl: string = ''

  private questions: GrammarQ[] = []
  courseId: string = ''
  lessonIndex: number = -1
  startTime: number = 0

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, string>;
    if (params && params['courseId']) {
      this.courseId = params['courseId'];
      this.lessonIndex = params['lessonIndex'] !== undefined ? Number(params['lessonIndex']) : -1;
    }
    this.loadQuestions()
    this.startTime = Date.now()
  }

  // 🌟 选题：英语按等级取专题题库；其他语种沿用批次轮换
  loadQuestions(): void {
    if (this.language === 'en') {
      let p: LevelPlan = planFor(this.courseId, expLevelOf(this.userExp))
      this.level = p.level
      this.planName = p.name
      this.planGoal = p.goal
      this.planColor = p.color
      this.grammarFocus = p.grammarFocus
      this.videoUrl = moduleVideo(p, 'grammar').url
      let allQ = p.grammar.slice()
      if (this.lessonIndex >= 0) {
        // 课时进入：同一课时始终对应同一批题目
        let start = (this.lessonIndex + courseSeed(this.courseId)) % allQ.length
        this.questions = this.shuffle(allQ.slice(start).concat(allQ.slice(0, start)).slice(0, Math.min(5, allQ.length)))
      } else {
        // 🌟 自由练习：每道题在一个周期内最多出现两次，避免反复刷到同一批题
        this.questions = this.shuffle(takePracticeBatch(allQ, 'grammar', p.level, 5, (q: GrammarQ) => q.question))
      }
    } else {
      this.level = 0
      this.planName = ''
      this.grammarFocus = ''
      this.videoUrl = ''
      let all = grammarBank(this.language)
      let plan = planOf('grammar', this.language)
      let size = practiceSize('grammar', this.language)
      let batch = this.lessonIndex >= 0 ? lessonBatch(all, plan, this.lessonIndex, courseSeed(this.courseId), size) : takeBatch(all, plan, size)
      this.questions = this.shuffle(batch)
    }
    this.idx = 0
    this.selected = -1
    this.answered = false
    this.correctCount = 0
    this.finished = false
    this.startTime = Date.now()
  }

  // 🌟 等级训练信息条
  @Builder
  levelBanner() {
    Row({ space: 8 }) {
      Text(`L${this.level + 1}`)
        .fontSize(12).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .padding({ left: 9, right: 9, top: 3, bottom: 3 })
        .backgroundColor(this.planColor).borderRadius(8)
      Column({ space: 3 }) {
        Text(`${this.planName} · ${this.grammarFocus}`)
          .fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
        Text(this.planGoal).fontSize(11).fontColor($r('app.color.text_hint'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Row({ space: 3 }) {
        Text('视频').fontSize(11).fontColor(this.planColor)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(10).fontColor([this.planColor])
      }
      .onClick(() => {
        if (this.videoUrl !== '') {
          router.pushUrl({ url: 'pages/common/WebViewPage', params: { url: this.videoUrl } })
        }
      })
    }
    .width('90%')
    .padding(12)
    .margin({ top: 4 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .border({ width: 1, color: `${this.planColor}33` })
  }

  // Fisher-Yates 洗牌，返回新数组
  shuffle(arr: GrammarQ[]): GrammarQ[] {
    let a = arr.slice()
    for (let i = a.length - 1; i > 0; i--) {
      let j = Math.floor(Math.random() * (i + 1))
      let tmp = a[i]
      a[i] = a[j]
      a[j] = tmp
    }
    return a
  }

  cur(): GrammarQ {
    return this.questions[this.idx]
  }

  pick(optionIdx: number) {
    if (this.answered) {
      return
    }
    this.selected = optionIdx
    this.answered = true
    if (optionIdx === this.cur().answer) {
      this.correctCount++
    }
  }

  next() {
    if (this.idx >= this.questions.length - 1) {
      this.finish()
    } else {
      this.idx++
      this.selected = -1
      this.answered = false
    }
  }

  finish() {
    this.finished = true
    let perfect = this.correctCount === this.questions.length
    if (perfect) {
      AppStorage.setOrCreate('quizPerfect', true)
    }
    // 🌟 自由练习完成一批后推进游标：「再练一次」与下次进入都会换到下一批新题
    if (this.lessonIndex < 0 && this.language !== 'en') {
      advanceBatchCursor(planOf('grammar', this.language), grammarBank(this.language).length, practiceSize('grammar', this.language))
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
    // 🌟 重新选题：批次游标已在完成时推进，本次取到下一批新题
    this.loadQuestions()
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Text(`语法练习 · ${langByKey(this.language).name}`).fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 16 })
      }.width('100%').height(60).padding({ left: 16 })

      if (!this.finished) {
        Scroll() {
          Column() {
            if (this.language === 'en') {
              this.levelBanner()
            }
            Text(`本批 ${this.questions.length} 题 · 进度 ${this.idx + 1}/${this.questions.length} · 剩余 ${this.questions.length - this.idx - 1} · 答对 ${this.correctCount}`)
              .fontSize(13).fontColor($r('app.color.text_sub')).margin({ top: 8 })
            Stack({ alignContent: Alignment.Start }) {
              Row().width('100%').height(6).borderRadius(3).backgroundColor($r('app.color.field_bg'))
              Row()
                .width(`${(this.idx + 1) / this.questions.length * 100}%`)
                .height(6).borderRadius(3).backgroundColor($r('app.color.primary'))
            }.width('90%').margin({ top: 8 })

            // 题目卡片
            Column({ space: 16 }) {
              Text(this.cur().question)
                .fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                .width('100%')

              ForEach(this.cur().options, (opt: string, i: number) => {
                Row({ space: 10 }) {
                  Text(String.fromCharCode(65 + i))
                    .fontSize(13).fontWeight(FontWeight.Bold)
                    .width(26).height(26).borderRadius(13)
                    .fontColor(this.answered && i === this.cur().answer ? Color.White : $r('app.color.text_sub'))
                    .backgroundColor(this.optionBg(i))
                    .textAlign(TextAlign.Center)
                  Text(opt).fontSize(15)
                    .fontColor(this.optionText(i))
                    .layoutWeight(1)
                  if (this.answered && i === this.cur().answer) {
                    SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(18).fontColor(['#55C873'])
                  }
                  if (this.answered && i === this.selected && i !== this.cur().answer) {
                    SymbolGlyph($r('sys.symbol.circle')).fontSize(18).fontColor(['#EF4444'])
                  }
                }
                .width('100%')
                .padding(14)
                .borderRadius(14)
                .backgroundColor(this.rowBg(i))
                .border({ width: this.selected === i && this.answered ? 1.5 : 0, color: this.selected === i && i !== this.cur().answer ? '#EF4444' : Color.Transparent })
                .onClick(() => this.pick(i))
              }, (opt: string, i: number) => `${this.idx}_${i}_${this.answered ? 1 : 0}_${this.selected}`)
            }
            .width('90%')
            .padding(20)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(20)
            .margin({ top: 20 })
            .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 5 })

            // 解析
            if (this.answered) {
              Column({ space: 6 }) {
                Text(this.selected === this.cur().answer ? '回答正确！' : '回答错误')
                  .fontSize(14).fontWeight(FontWeight.Bold)
                  .fontColor(this.selected === this.cur().answer ? '#55C873' : '#EF4444')
                Text(this.cur().explain).fontSize(13).fontColor($r('app.color.text_body')).lineHeight(20)
              }
              .width('90%')
              .alignItems(HorizontalAlign.Start)
              .padding(14)
              .backgroundColor(this.selected === this.cur().answer ? '#55C87314' : '#EF444414')
              .borderRadius(14)
              .margin({ top: 14 })

              Text(this.idx >= this.questions.length - 1 ? '查看结果' : '下一题')
                .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
                .width('90%').textAlign(TextAlign.Center)
                .padding({ top: 13, bottom: 13 })
                .backgroundColor($r('app.color.primary')).borderRadius(22)
                .margin({ top: 18 })
                .onClick(() => this.next())
            }
          }
          .width('100%')
          .padding({ bottom: 30 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      } else {
        // 结果页
        Column({ space: 16 }) {
          SymbolGlyph(this.correctCount === this.questions.length ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.star'))
            .fontSize(64)
            .fontColor([this.correctCount === this.questions.length ? '#55C873' : '#E8B93E'])
          Text(this.correctCount === this.questions.length ? '全部答对，太棒了！' : '练习完成！')
            .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Text(this.language === 'en'
            ? `答对 ${this.correctCount}/${this.questions.length} 题 · L${this.level + 1} ${this.planName}专项：${this.grammarFocus}`
            : `答对 ${this.correctCount}/${this.questions.length} 题（本批 ${this.questions.length} 题，全库 ${grammarBank(this.language).length} 题）`)
            .fontSize(14).fontColor($r('app.color.text_sub'))
          Row({ space: 12 }) {
            Text('再练一次')
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
              .onClick(() => router.back())
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

  optionBg(i: number): ResourceColor {
    if (this.answered && i === this.cur().answer) {
      return '#55C873'
    }
    if (this.answered && i === this.selected && i !== this.cur().answer) {
      return '#EF4444'
    }
    return $r('app.color.field_bg')
  }

  optionText(i: number): ResourceColor {
    return $r('app.color.text_main')
  }

  rowBg(i: number): ResourceColor {
    if (this.answered && i === this.cur().answer) {
      return '#55C87314'
    }
    if (this.answered && i === this.selected && i !== this.cur().answer) {
      return '#EF444414'
    }
    return $r('app.color.field_bg')
  }
}
