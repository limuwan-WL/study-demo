import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';
import {
  Course, Lesson, ACHIEVEMENTS, coursesOf, moduleOfLesson, modulePageUrl
} from '../../model/CourseModel';
import { LEVEL_NAMES, LEVEL_COLORS, expLevelOf } from '../../model/GrowthModel';
import { LevelBrief, VideoRef, levelBriefOf, briefModuleVideo, biliSearch } from '../../model/LevelTraining';

// ==================== 语种课程内页（韩语 / 日语 / 现代汉语共用） ====================
// 🌟 课程相关内容不再罗列在课程首页，统一收进语种课程内页：
//   顶部学习横幅 → 互动学习模块 → 分级课程体系（L1~L4 + 训练方案 + 课程课时）→ 学习进度追踪
@Component
export struct LanguageCoursePage {
  @Prop lang: string = 'ko'
  @Prop title: string = '韩语'
  @Prop color: string = '#8B5CF6'

  @StorageLink('courseProgress') courseProgress: Record<string, number> = {}
  // 🌟 只读当前语种的学习日志，避免把其他语言的今日/累计/连续学习算进来
  @StorageLink('studyLogBySubject') studyLogBySubject: Record<string, Record<string, number>> = {}
  @StorageLink('wordKnown') wordKnown: string[] = []
  @StorageLink('achievementList') achievements: string[] = []
  @StorageLink('userExp') userExp: number = 0

  @State levelIdx: number = 0 // 当前选中的级别（0~3）
  @State expandedId: string = '' // 展开课时的课程 id

  expLv(): number {
    return expLevelOf(this.userExp)
  }

  brief(): LevelBrief {
    return levelBriefOf(this.lang, this.levelIdx)
  }

  courses(): Course[] {
    return coursesOf(this.lang).filter((c: Course) => c.level === this.levelIdx)
  }

  courseDone(courseId: string): number {
    let n = this.courseProgress[courseId]
    return n === undefined ? 0 : n
  }

  // 本语种累计完成课时
  totalDone(): number {
    let total = 0
    coursesOf(this.lang).forEach((c: Course) => {
      total += this.courseDone(c.id)
    })
    return total
  }

  masteredWords(): number {
    return this.wordKnown.filter((k: string) => k.startsWith(`${this.lang}_`)).length
  }

  // 🌟 当前语种的学习日志（不存在时返回空表，不借用其他语种数据）
  langLog(): Record<string, number> {
    let map = this.studyLogBySubject[this.lang]
    return map === undefined ? {} : map
  }

  streak(): number {
    let log = this.langLog()
    let streak = 0
    let d = new Date()
    if (log[dateKey(d)] === undefined) {
      d = new Date(d.getTime() - 86400000)
    }
    while (log[dateKey(d)] !== undefined && log[dateKey(d)] > 0) {
      streak++
      d = new Date(d.getTime() - 86400000)
    }
    return streak
  }

  todayMinutes(): number {
    let n = this.langLog()[dateKey(new Date())]
    return n === undefined ? 0 : n
  }

  totalMinutes(): number {
    let log = this.langLog()
    let total = 0
    Object.keys(log).forEach((k: string) => {
      total += log[k]
    })
    return total
  }

  last7Days(): DayStat[] {
    let log = this.langLog()
    let list: DayStat[] = []
    let week: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
    for (let i = 6; i >= 0; i--) {
      let d = new Date(Date.now() - i * 86400000)
      let n = log[dateKey(d)]
      list.push(new DayStat(week[d.getDay()], n === undefined ? 0 : n, i === 0))
    }
    return list
  }

  barHeight(minutes: number): number {
    let max = 1
    this.last7Days().forEach((d: DayStat) => {
      max = Math.max(max, d.minutes)
    })
    return Math.max(6, minutes / max * 72)
  }

  openUrl(url: string) {
    router.pushUrl({ url: 'pages/common/WebViewPage', params: { url: url } })
  }

  // 自由练习：切换当前学习语种后进入对应模块
  openModule(module: string) {
    AppStorage.setOrCreate('languageSetting', this.lang)
    router.pushUrl({ url: modulePageUrl(module) })
  }

  openLesson(c: Course, idx: number, lesson: Lesson) {
    if (idx < this.courseDone(c.id)) {
      promptAction.showToast({ message: '这节课已完成，可以复习或继续下一课' })
      return
    }
    AppStorage.setOrCreate('languageSetting', this.lang)
    router.pushUrl({
      url: modulePageUrl(moduleOfLesson(lesson.title, idx)),
      params: { courseId: c.id, lessonIndex: `${idx}` }
    })
  }

  // ===== 顶部学习横幅（原课程首页的课程学习卡片，下沉到课程内页） =====
  @Builder
  banner() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 5 }) {
          Text('课程学习').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White)
          Row({ space: 4 }) {
            Text(`当前学习：${this.title} · LV${this.expLv() + 1} ${LEVEL_NAMES[this.expLv()]}`)
              .fontSize(12).fontColor('#DCE9FB')
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(11).fontColor(['#DCE9FB'])
          }.alignItems(VerticalAlign.Center)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)

        Text(`L${this.levelIdx + 1}`)
          .fontSize(12).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor('#33FFFFFF').borderRadius(14)
      }.width('100%').alignItems(VerticalAlign.Center)

      Row({ space: 14 }) {
        Row({ space: 5 }) {
          SymbolGlyph($r('sys.symbol.flame_fill')).fontSize(14).fontColor(['#FFD48A'])
          Text(`连续 ${this.streak()} 天`).fontSize(12).fontColor(Color.White)
        }
        Row({ space: 5 }) {
          SymbolGlyph($r('sys.symbol.graduationcap')).fontSize(14).fontColor(['#FFD48A'])
          Text(`已完成 ${this.totalDone()} 课`).fontSize(12).fontColor(Color.White)
        }
        Row({ space: 5 }) {
          SymbolGlyph($r('sys.symbol.star_fill')).fontSize(14).fontColor(['#FFD48A'])
          Text(`成就 ${this.achievements.length}/${ACHIEVEMENTS.length}`).fontSize(12).fontColor(Color.White)
        }
      }
    }
    .width('90%')
    .alignItems(HorizontalAlign.Start)
    .padding(20)
    .linearGradient({ angle: 135, colors: [['#4C8BF5', 0], ['#3F7EF6', 1]] })
    .borderRadius(20)
    .margin({ top: 14 })
    .shadow({ radius: 10, color: 'rgba(63,126,246,0.25)', offsetY: 5 })
  }

  // ===== 互动学习模块：单词 / 语法 / 口语 / 听力 四张练习卡 =====
  @Builder
  moduleCard(char: string, cardColor: string, moduleTitle: string, desc: string, module: string) {
    Column() {
      Row() {
        Text(char).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .width(36).height(36).backgroundColor(cardColor).borderRadius(10).textAlign(TextAlign.Center)
        Text(moduleTitle).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
          .margin({ left: 10 })
      }.width('100%').alignItems(VerticalAlign.Center)
      Text(desc).fontSize(11).fontColor($r('app.color.text_sub')).width('100%').margin({ top: 8, left: 2 })
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16).padding(14)
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 5 })
    .onClick(() => this.openModule(module))
  }

  @Builder
  moduleGrid() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        this.moduleCard('词', '#3F7EF6', '单词记忆', `${this.brief().name} · ${this.brief().methods[0]}`, 'word')
        this.moduleCard('法', '#8B5CF6', '语法练习', this.brief().grammarFocus, 'grammar')
      }
      Row({ space: 12 }) {
        this.moduleCard('说', '#E8A33E', '口语跟读', `${this.brief().name} · ${this.brief().methods[2]}`, 'speak')
        this.moduleCard('听', '#55C873', '听力训练', `${this.brief().name} · ${this.brief().methods[3]}`, 'listen')
      }
    }.width('90%')
  }

  // ===== 分级课程体系：等级切换 + 训练方案 + 课程列表 =====
  @Builder
  levelTabs() {
    Row({ space: 8 }) {
      ForEach(LEVEL_NAMES, (name: string, idx: number) => {
        Text(`L${idx + 1} ${name}`)
          .fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor(this.levelIdx === idx ? Color.White : $r('app.color.text_sub'))
          .padding({ top: 7, bottom: 7 })
          .backgroundColor(this.levelIdx === idx ? LEVEL_COLORS[idx] : $r('app.color.card_bg'))
          .borderRadius(14)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.levelIdx = idx
            this.expandedId = ''
          })
      }, (name: string, idx: number) => `${this.lang}_${name}_${this.levelIdx === idx ? 1 : 0}`)
    }.width('90%')
  }

  // 单个练习模块的教学视频行
  @Builder
  moduleVideoRow(label: string, module: string) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(9).fontColor(Color.White)
        .width(28).textAlign(TextAlign.Center)
        .padding({ top: 2, bottom: 2 })
        .backgroundColor(this.brief().color).borderRadius(5)
      Text(briefModuleVideo(this.brief(), this.title, module).title)
        .fontSize(11).fontColor($r('app.color.text_main'))
        .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text('B站视频').fontSize(9).fontColor($r('app.color.text_hint'))
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(11).fontColor([$r('app.color.text_hint')])
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
    .onClick(() => {
      let video: VideoRef = briefModuleVideo(this.brief(), this.title, module)
      this.openUrl(video.url)
    })
  }

  @Builder
  levelPlanCard() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(`L${this.levelIdx + 1}`)
          .fontSize(12).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .padding({ left: 9, right: 9, top: 3, bottom: 3 })
          .backgroundColor(this.brief().color).borderRadius(8)
        Column({ space: 3 }) {
          Text(`${this.brief().name}训练方案`)
            .fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
          Text(this.brief().goal)
            .fontSize(11).fontColor($r('app.color.text_hint'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.width('100%').alignItems(VerticalAlign.Center)

      Row({ space: 6 }) {
        ForEach(this.brief().methods, (m: string) => {
          Text(m)
            .fontSize(10).fontColor($r('app.color.primary'))
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor($r('app.color.primary_weak')).borderRadius(8)
        }, (m: string) => `L${this.levelIdx}_${this.lang}_${m}`)
      }.width('100%')

      Row({ space: 12 }) {
        Text(`词汇 ${this.brief().counts[0]}`).fontSize(10).fontColor($r('app.color.text_sub'))
        Text(`语法 ${this.brief().counts[1]}`).fontSize(10).fontColor($r('app.color.text_sub'))
        Text(`口语 ${this.brief().counts[2]}`).fontSize(10).fontColor($r('app.color.text_sub'))
        Text(`听力 ${this.brief().counts[3]}`).fontSize(10).fontColor($r('app.color.text_sub'))
      }.width('100%')

      Column({ space: 6 }) {
        this.moduleVideoRow('单词', 'word')
        this.moduleVideoRow('语法', 'grammar')
        this.moduleVideoRow('口语', 'speak')
        this.moduleVideoRow('听力', 'listen')
      }.width('100%')
    }
    .width('90%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .margin({ top: 12 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .border({ width: 1, color: `${this.brief().color}26` })
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 4 })
  }

  @Builder
  courseCard(c: Course) {
    Column() {
      Row({ space: 10 }) {
        Text(`L${c.level + 1}`)
          .fontSize(12).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .width(38).height(38).backgroundColor(c.color).borderRadius(10).textAlign(TextAlign.Center)
        Column({ space: 3 }) {
          Text(c.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(c.desc).fontSize(11).fontColor($r('app.color.text_sub'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)

        Text(`${this.courseDone(c.id)}/${c.lessons.length}`)
          .fontSize(12).fontColor($r('app.color.text_sub'))
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .rotate({ angle: this.expandedId === c.id ? 90 : 0 })
          .fontColor([$r('app.color.text_sub')])
      }.width('100%').alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.expandedId = this.expandedId === c.id ? '' : c.id
      })

      Stack({ alignContent: Alignment.Start }) {
        Row().width('100%').height(6).borderRadius(3).backgroundColor($r('app.color.field_bg'))
        Row()
          .width(`${this.courseDone(c.id) / c.lessons.length * 100}%`)
          .height(6).borderRadius(3).backgroundColor(c.color)
      }.width('100%').margin({ top: 12 })
      .onClick(() => {
        this.expandedId = this.expandedId === c.id ? '' : c.id
      })

      if (this.expandedId === c.id) {
        Column() {
          // 课程讲解视频：链接到本课程对应的知识网站
          Row({ space: 8 }) {
            Text('讲解')
              .fontSize(10).fontColor(c.color)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(`${c.color}1A`)
              .borderRadius(6)
            Text(`${this.title} · ${c.title}`)
              .fontSize(12).fontColor($r('app.color.text_main')).layoutWeight(1)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('B站视频').fontSize(11).fontColor('#00A1D6')
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([$r('app.color.text_hint')])
          }
          .width('100%').height(40)
          .onClick(() => {
            this.openUrl(biliSearch(`${this.title} ${c.title}`))
          })

          ForEach(c.lessons, (lesson: Lesson, idx: number) => {
            Row({ space: 8 }) {
              SymbolGlyph(idx < this.courseDone(c.id) ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
                .fontSize(18)
                .fontColor([idx < this.courseDone(c.id) ? '#55C873' : $r('app.color.text_hint')])
              Text(lesson.title).fontSize(13).fontColor($r('app.color.text_main')).layoutWeight(1)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text('知识')
                .fontSize(10).fontColor(c.color)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(8)
                .border({ width: 1, color: c.color })
                .onClick(() => {
                  this.openUrl(biliSearch(`${this.title} ${lesson.title}`))
                })
              if (idx < this.courseDone(c.id)) {
                Text('已完成').fontSize(11).fontColor($r('app.color.text_hint'))
              } else {
                Text('开始学习')
                  .fontSize(11).fontColor(Color.White)
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .backgroundColor(c.color).borderRadius(10)
              }
            }
            .width('100%').height(44)
            .onClick(() => this.openLesson(c, idx, lesson))
          }, (lesson: Lesson, idx: number) => `${c.id}_${idx}_${idx < this.courseDone(c.id) ? 1 : 0}`)
        }.width('100%').margin({ top: 6 })
      }
    }
    .width('100%')
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16).padding(16)
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 5 })
  }

  // ===== 学习进度追踪 =====
  @Builder
  statBlock(label: string, value: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      Text(label).fontSize(11).fontColor($r('app.color.text_sub'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  progressCard() {
    Column({ space: 14 }) {
      Row() {
        this.statBlock('累计课时', `${this.totalDone()}`)
        this.statBlock('掌握单词', `${this.masteredWords()}`)
        this.statBlock('连续打卡', `${this.streak()} 天`)
        this.statBlock('累计学习', `${this.totalMinutes()} 分`)
      }.width('100%')

      Divider().color($r('app.color.divider_color'))

      Row() {
        Text('近 7 日学习').fontSize(12).fontColor($r('app.color.text_sub'))
        Blank()
        Text(`今日 ${this.todayMinutes()} 分钟`).fontSize(11).fontColor($r('app.color.primary'))
      }.width('100%')

      Row() {
        ForEach(this.last7Days(), (d: DayStat) => {
          Column({ space: 6 }) {
            Column()
              .width(16)
              .height(this.barHeight(d.minutes))
              .borderRadius(4)
              .backgroundColor(d.minutes > 0 ? (d.isToday ? $r('app.color.primary') : '#9DBDF9') : $r('app.color.field_bg'))
            Text(d.minutes > 0 ? `${d.minutes}` : '')
              .fontSize(9).fontColor($r('app.color.text_hint'))
            Text(d.label).fontSize(10)
              .fontColor(d.isToday ? $r('app.color.primary') : $r('app.color.text_hint'))
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.End)
          .alignItems(HorizontalAlign.Center)
        }, (d: DayStat) => `${d.label}_${d.minutes}_${d.isToday ? 1 : 0}`)
      }
      .width('100%')
      .height(110)
      .alignItems(VerticalAlign.Bottom)
    }
    .width('90%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(20)
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 5 })
  }

  @Builder
  sectionTitle(text: string) {
    Text(text)
      .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      .width('90%').margin({ top: 20, bottom: 12 })
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('‹')
          .fontSize(30)
          .fontColor($r('app.color.text_main'))
          .width(40)
          .onClick(() => router.back())
        Text(`${this.title} · 分级课程`)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_main'))
        Blank()
        Text('L1-L4')
          .fontSize(11)
          .fontColor(this.color)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(`${this.color}18`)
          .borderRadius(8)
      }
      .width('100%')
      .padding({ left: 6, right: 14, top: 8, bottom: 8 })

      Scroll() {
        Column() {
          this.banner()

          this.sectionTitle('互动学习模块')
          this.moduleGrid()

          this.sectionTitle('分级课程体系')
          this.levelTabs()
          this.levelPlanCard()

          Column({ space: 12 }) {
            ForEach(this.courses(), (c: Course) => {
              this.courseCard(c)
            }, (c: Course) => `${c.id}_${this.expandedId === c.id ? 1 : 0}_${this.courseDone(c.id)}`)
          }.width('90%').margin({ top: 12 })

          this.sectionTitle('学习进度追踪')
          this.progressCard()

          Blank().height(30)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}

// ==================== 页面内辅助类型与工具 ====================

function dateKey(d: Date): string {
  let m = (d.getMonth() + 1).toString().padStart(2, '0')
  let day = d.getDate().toString().padStart(2, '0')
  return `${d.getFullYear()}-${m}-${day}`
}

class DayStat {
  label: string = ''
  minutes: number = 0
  isToday: boolean = false

  constructor(label: string, minutes: number, isToday: boolean) {
    this.label = label
    this.minutes = minutes
    this.isToday = isToday
  }
}
