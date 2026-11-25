import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';
import { ListenItem, listenBank, langByKey, recordStudy, completeLesson, refreshAchievements, courseSeed, takePracticeBatch } from '../../model/CourseModel';
import { planFor, LevelPlan, moduleVideo } from '../../model/LevelTraining';
import { expLevelOf } from '../../model/GrowthModel';

// 🌟 听力训练：模拟播放音频（进度条动画），听后选择题，即时反馈
// 🌟 英语按等级取对应语速与题材（L1 单词听辨 / L2 场景对话 / L3 新闻要点 / L4 学术讲座）
// 🌟 一次全对解锁「顺风耳朵」成就；从课程课时进入时自动记录课时进度
@Entry
@Component
struct ListeningPage {
  @StorageLink('languageSetting') language: string = 'en'
  @StorageLink('userExp') userExp: number = 0

  @State idx: number = 0
  @State playing: boolean = false
  @State playProgress: number = 0 // 播放进度 0~100
  @State playedOnce: boolean = false
  @State selected: number = -1
  @State answered: boolean = false
  @State correctCount: number = 0
  @State finished: boolean = false

  // 🌟 分级训练
  @State level: number = 0
  @State planName: string = ''
  @State planColor: string = '#55C873'
  @State listenMode: string = ''
  @State videoUrl: string = ''

  private items: ListenItem[] = []
  private timer: number = -1
  courseId: string = ''
  lessonIndex: number = -1
  startTime: number = 0

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, string>;
    if (params && params['courseId']) {
      this.courseId = params['courseId'];
      this.lessonIndex = params['lessonIndex'] !== undefined ? Number(params['lessonIndex']) : -1;
    }
    if (this.language === 'en') {
      let p: LevelPlan = planFor(this.courseId, expLevelOf(this.userExp))
      this.level = p.level
      this.planName = p.name
      this.planColor = p.color
      this.listenMode = p.methods[3]
      this.videoUrl = moduleVideo(p, 'listen').url
      let allL = p.listen.slice()
      if (this.lessonIndex >= 0) {
        // 课时进入：同一课时始终对应同一批听力材料
        let start = (this.lessonIndex + courseSeed(this.courseId)) % allL.length
        this.items = allL.slice(start).concat(allL.slice(0, start)).slice(0, Math.min(3, allL.length))
      } else {
        // 🌟 自由练习：每则材料在一个周期内最多出现两次，避免反复刷到同一批题
        this.items = takePracticeBatch(allL, 'listen', p.level, 3, (l: ListenItem) => l.audioText)
      }
    } else {
      // 🌟 自由练习：每则材料在一个周期内最多出现两次（其他语种同样生效）
      this.items = takePracticeBatch(listenBank(this.language), 'listen', 0, 3, (l: ListenItem) => l.audioText)
    }
    this.startTime = Date.now()
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer)
      this.timer = -1
    }
  }

  cur(): ListenItem {
    return this.items[this.idx]
  }

  // 🌟 模拟播放音频：进度条走完后展示题目
  play() {
    if (this.playing) {
      return
    }
    this.playing = true
    this.playProgress = 0
    this.timer = setInterval(() => {
      this.playProgress += 4
      if (this.playProgress >= 100) {
        clearInterval(this.timer)
        this.timer = -1
        this.playing = false
        this.playedOnce = true
      }
    }, 90)
  }

  pick(optionIdx: number) {
    if (this.answered || !this.playedOnce) {
      return
    }
    this.selected = optionIdx
    this.answered = true
    if (optionIdx === this.cur().answer) {
      this.correctCount++
    }
  }

  next() {
    if (this.idx >= this.items.length - 1) {
      this.finish()
    } else {
      this.idx++
      this.playProgress = 0
      this.playedOnce = false
      this.selected = -1
      this.answered = false
    }
  }

  finish() {
    this.finished = true
    let perfect = this.correctCount === this.items.length
    if (perfect) {
      AppStorage.setOrCreate('listenPerfect', true)
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
    this.idx = 0
    this.playProgress = 0
    this.playedOnce = false
    this.selected = -1
    this.answered = false
    this.correctCount = 0
    this.finished = false
    this.startTime = Date.now()
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Text(`听力训练 · ${langByKey(this.language).name}`).fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 16 })
      }.width('100%').height(60).padding({ left: 16 })

      if (!this.finished) {
        Scroll() {
          Column() {
            if (this.language === 'en') {
              Row({ space: 8 }) {
                Text(`L${this.level + 1}`)
                  .fontSize(12).fontWeight(FontWeight.Bold).fontColor(Color.White)
                  .padding({ left: 9, right: 9, top: 3, bottom: 3 })
                  .backgroundColor(this.planColor).borderRadius(8)
                Text(`${this.planName} · ${this.listenMode}`)
                  .fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                Blank()
                if (this.videoUrl !== '') {
                  Row({ space: 3 }) {
                    Text('教学视频').fontSize(11).fontColor(this.planColor)
                    SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(10).fontColor([this.planColor])
                  }
                  .onClick(() => {
                    router.pushUrl({ url: 'pages/common/WebViewPage', params: { url: this.videoUrl } })
                  })
                }
              }
              .width('90%')
              .padding(12)
              .margin({ top: 4 })
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(14)
              .border({ width: 1, color: `${this.planColor}33` })
            }
            Text(`${this.idx + 1}/${this.items.length}`)
              .fontSize(13).fontColor($r('app.color.text_sub')).margin({ top: 10 })
            Stack({ alignContent: Alignment.Start }) {
              Row().width('100%').height(6).borderRadius(3).backgroundColor($r('app.color.field_bg'))
              Row()
                .width(`${(this.idx + 1) / this.items.length * 100}%`)
                .height(6).borderRadius(3).backgroundColor($r('app.color.primary'))
            }.width('90%').margin({ top: 8 })

            // 音频播放卡片
            Column({ space: 14 }) {
              // 播放按钮
              Column() {
                SymbolGlyph(this.playing ? $r('sys.symbol.face_smiling') : $r('sys.symbol.message'))
                  .fontSize(30).fontColor([Color.White])
              }
              .width(76).height(76).borderRadius(38)
              .backgroundColor(this.playing ? '#E8873E' : $r('app.color.primary'))
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .scale({ x: this.playing ? 1.06 : 1, y: this.playing ? 1.06 : 1 })
              .onClick(() => this.play())

              // 模拟声波
              Row({ space: 4 }) {
                ForEach([0, 1, 2, 3, 4, 5, 6, 7], (i: number) => {
                  Column()
                    .width(5)
                    .height(this.playing ? 10 + Math.abs(Math.sin((i + this.playProgress) / 2)) * 24 : 10)
                    .borderRadius(3)
                    .backgroundColor(this.playing ? '#9DBDF9' : '#C9D8F755')
                }, (i: number) => `${i}_${this.playProgress}`)
              }.height(40)

              Stack({ alignContent: Alignment.Start }) {
                Row().width('90%').height(5).borderRadius(3).backgroundColor('#C9D8F755')
                Row()
                  .width(`${this.playProgress}%`)
                  .height(5).borderRadius(3).backgroundColor($r('app.color.primary'))
              }.width('90%')

              Text(this.playing ? '正在播放，请认真听…' : (this.playedOnce ? '可以重听一遍再作答' : '点击上方按钮播放音频'))
                .fontSize(13).fontColor($r('app.color.text_sub'))
            }
            .width('90%')
            .padding(20)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(20)
            .margin({ top: 20 })
            .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 5 })

            // 题目与选项：播放完成后展示
            if (this.playedOnce) {
              Column({ space: 12 }) {
                Text(this.cur().question)
                  .fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                  .width('100%')

                ForEach(this.cur().options, (opt: string, i: number) => {
                  Row({ space: 10 }) {
                    Text(String.fromCharCode(65 + i))
                      .fontSize(13).fontWeight(FontWeight.Bold)
                      .width(26).height(26).borderRadius(13)
                      .fontColor(this.answered && i === this.cur().answer ? Color.White : $r('app.color.text_sub'))
                      .backgroundColor(this.answered && i === this.cur().answer ? '#55C873' : (this.answered && i === this.selected ? '#EF4444' : $r('app.color.field_bg')))
                      .textAlign(TextAlign.Center)
                    Text(opt).fontSize(15).fontColor($r('app.color.text_main')).layoutWeight(1)
                    if (this.answered && i === this.cur().answer) {
                      SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(18).fontColor(['#55C873'])
                    }
                  }
                  .width('100%')
                  .padding(13)
                  .borderRadius(14)
                  .backgroundColor(this.answered && i === this.cur().answer ? '#55C87314' : (this.answered && i === this.selected ? '#EF444414' : $r('app.color.field_bg')))
                  .onClick(() => this.pick(i))
                }, (opt: string, i: number) => `${this.idx}_${i}_${this.answered ? 1 : 0}_${this.selected}`)
              }
              .width('90%')
              .alignItems(HorizontalAlign.Start)
              .padding(18)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(20)
              .margin({ top: 14 })
              .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 5 })

              if (this.answered) {
                Text(this.idx >= this.items.length - 1 ? '查看结果' : '下一题')
                  .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
                  .width('90%').textAlign(TextAlign.Center)
                  .padding({ top: 13, bottom: 13 })
                  .backgroundColor($r('app.color.primary')).borderRadius(22)
                  .margin({ top: 18 })
                  .onClick(() => this.next())
              }
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
          SymbolGlyph(this.correctCount === this.items.length ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.star'))
            .fontSize(64)
            .fontColor([this.correctCount === this.items.length ? '#55C873' : '#E8B93E'])
          Text(this.correctCount === this.items.length ? '全部听对，耳朵很灵！' : '训练完成！')
            .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Text(`答对 ${this.correctCount}/${this.items.length} 题`)
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
}
