import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';
import { SpeakItem, speakBank, langByKey, recordStudy, completeLesson, refreshAchievements, courseSeed, takePracticeBatch } from '../../model/CourseModel';
import { planFor, LevelPlan, moduleVideo } from '../../model/LevelTraining';
import { expLevelOf } from '../../model/GrowthModel';

// 🌟 口语跟读：逐句点击跟读，模拟录音进度动画后记为完成
// 🌟 英语按等级取对应句长与话题（L1 问候短句 / L2 情景对话 / L3 观点陈述 / L4 演讲表达）
// 🌟 从课程课时进入（带 courseId/lessonIndex 参数）时，完成后自动记录课时进度
@Entry
@Component
struct SpeakingPage {
  @StorageLink('languageSetting') language: string = 'en'
  @StorageLink('userExp') userExp: number = 0

  @State idx: number = 0
  @State recording: boolean = false
  @State progress: number = 0 // 模拟录音进度 0~100
  @State doneCount: number = 0
  @State finished: boolean = false

  // 🌟 分级训练
  @State level: number = 0
  @State planName: string = ''
  @State planColor: string = '#55C873'
  @State speakMode: string = ''
  @State videoUrl: string = ''

  private sentences: SpeakItem[] = []
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
      this.speakMode = p.methods[2]
      this.videoUrl = moduleVideo(p, 'speak').url
      let allS = p.speak.slice()
      if (this.lessonIndex >= 0) {
        // 课时进入：同一课时始终对应同一批句子
        let start = (this.lessonIndex + courseSeed(this.courseId)) % allS.length
        this.sentences = allS.slice(start).concat(allS.slice(0, start)).slice(0, Math.min(4, allS.length))
      } else {
        // 🌟 自由练习：每个句子在一个周期内最多出现两次，避免反复刷到同一批题
        this.sentences = takePracticeBatch(allS, 'speak', p.level, 4, (s: SpeakItem) => s.text)
      }
    } else {
      // 🌟 自由练习：每个句子在一个周期内最多出现两次（其他语种同样生效）
      this.sentences = takePracticeBatch(speakBank(this.language), 'speak', 0, 4, (s: SpeakItem) => s.text)
    }
    this.startTime = Date.now()
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer)
      this.timer = -1
    }
  }

  cur(): SpeakItem {
    return this.sentences[this.idx]
  }

  // 🌟 模拟跟读：进度条走完后本句记为完成，自动进入下一句
  startRecording() {
    if (this.recording || this.finished) {
      return
    }
    this.recording = true
    this.progress = 0
    this.timer = setInterval(() => {
      this.progress += 5
      if (this.progress >= 100) {
        clearInterval(this.timer)
        this.timer = -1
        this.recording = false
        this.doneCount++
        if (this.idx >= this.sentences.length - 1) {
          this.finish()
        } else {
          this.idx++
          this.progress = 0
        }
      }
    }, 100)
  }

  finish() {
    this.finished = true
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
    this.progress = 0
    this.doneCount = 0
    this.finished = false
    this.startTime = Date.now()
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Text(`口语跟读 · ${langByKey(this.language).name}`).fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 16 })
      }.width('100%').height(60).padding({ left: 16 })

      if (!this.finished) {
        Column() {
          if (this.language === 'en') {
            Row({ space: 8 }) {
              Text(`L${this.level + 1}`)
                .fontSize(12).fontWeight(FontWeight.Bold).fontColor(Color.White)
                .padding({ left: 9, right: 9, top: 3, bottom: 3 })
                .backgroundColor(this.planColor).borderRadius(8)
              Text(`${this.planName} · ${this.speakMode}`)
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
          Text(`${this.idx + 1}/${this.sentences.length}`)
            .fontSize(13).fontColor($r('app.color.text_sub')).margin({ top: 10 })
          Stack({ alignContent: Alignment.Start }) {
            Row().width('100%').height(6).borderRadius(3).backgroundColor($r('app.color.field_bg'))
            Row()
              .width(`${(this.idx + 1) / this.sentences.length * 100}%`)
              .height(6).borderRadius(3).backgroundColor($r('app.color.primary'))
          }.width('90%').margin({ top: 8 })

          // 跟读句子卡片
          Column({ space: 14 }) {
            Text(this.cur().text)
              .fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White)
              .textAlign(TextAlign.Center)
            Text(this.cur().translation)
              .fontSize(14).fontColor('#DCE9FB')
              .textAlign(TextAlign.Center)
          }
          .width('86%')
          .padding(32)
          .linearGradient({ angle: 135, colors: [['#F0A24C', 0], ['#E8873E', 1]] })
          .borderRadius(24)
          .shadow({ radius: 14, color: 'rgba(232,163,62,0.3)', offsetY: 6 })
          .margin({ top: 24 })

          // 模拟录音波形 + 进度
          Row({ space: 4 }) {
            ForEach([0, 1, 2, 3, 4, 5, 6, 7], (i: number) => {
              Column()
                .width(5)
                .height(this.recording ? 10 + Math.abs(Math.sin((i + this.progress) / 2)) * 26 : 10)
                .borderRadius(3)
                .backgroundColor(this.recording ? Color.White : '#E8A33E55')
            }, (i: number) => `${i}_${this.progress}`)
          }
          .height(44)
          .margin({ top: 24 })

          Stack({ alignContent: Alignment.Start }) {
            Row().width('80%').height(5).borderRadius(3).backgroundColor($r('app.color.field_bg'))
            Row()
              .width(`${this.progress}%`)
              .height(5).borderRadius(3).backgroundColor($r('app.color.primary'))
          }.width('80%').margin({ top: 6 })

          // 麦克风按钮（对话气泡符号，避免 emoji 在部分环境渲染为黑块）
          Column() {
            SymbolGlyph($r('sys.symbol.message')).fontSize(30).fontColor([Color.White])
          }
          .width(84).height(84).borderRadius(42)
          .backgroundColor(this.recording ? '#EF4444' : $r('app.color.primary'))
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .shadow({ radius: 12, color: 'rgba(63,126,246,0.35)', offsetY: 5 })
          .margin({ top: 18 })
          .scale({ x: this.recording ? 1.08 : 1, y: this.recording ? 1.08 : 1 })
          .onClick(() => this.startRecording())

          Text(this.recording ? '正在跟读，请大声念出来…' : '点击麦克风开始跟读')
            .fontSize(13).fontColor($r('app.color.text_sub')).margin({ top: 14 })

          Text(`已完成 ${this.doneCount} 句`)
            .fontSize(12).fontColor($r('app.color.text_hint')).margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        // 完成页
        Column({ space: 16 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(64).fontColor(['#55C873'])
          Text('跟读完成！').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Text('坚持开口练习，口语会越来越流利')
            .fontSize(14).fontColor($r('app.color.text_sub'))
          Row({ space: 12 }) {
            Text('再练一遍')
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
