import router from '@ohos.router';
import { LEVEL_NAMES, LEVEL_COLORS } from '../../model/CourseModel';
import {
  EXP_THRESHOLDS, EXP_REWARDS, TEACHER_EXP_REWARDS, TEACHER_GROUP_DAILY_CAP, expLevelOf, levelProgressOf, expToNextOf
} from '../../model/GrowthModel';

// ==================== 等级与权益页 ====================
// 🌟 等级口径统一：全应用等级由经验值驱动（LV1~LV4）
// 经验来源：每日登录 / 聊天消息（日上限）/ 完成课程 / 练习学习 / 社区打卡
// 硬币随经验同步获得，用于购买学科课程

class LevelCondition {
  lv: number = 0
  need: number = 0
  desc: string = ''

  constructor(lv: number, need: number, desc: string) {
    this.lv = lv
    this.need = need
    this.desc = desc
  }
}

// 各等级升级条件：所需累计经验
const LEVEL_CONDITIONS: LevelCondition[] = [
  new LevelCondition(0, EXP_THRESHOLDS[0], `累计获得 ${EXP_THRESHOLDS[0]} 点经验`),
  new LevelCondition(1, EXP_THRESHOLDS[1], `累计获得 ${EXP_THRESHOLDS[1]} 点经验`),
  new LevelCondition(2, EXP_THRESHOLDS[2], `累计获得 ${EXP_THRESHOLDS[2]} 点经验`),
  new LevelCondition(3, EXP_THRESHOLDS[3], `累计获得 ${EXP_THRESHOLDS[3]} 点经验`)
]

class LevelBenefit {
  lv: number = 0
  items: string[] = []

  constructor(lv: number, items: string[]) {
    this.lv = lv
    this.items = items
  }
}

const LEVEL_BENEFITS: LevelBenefit[] = [
  new LevelBenefit(0, ['L1 基础课程全部开放', '学习打卡与社区交流']),
  new LevelBenefit(1, ['解锁 L2 进阶课程', '单词本扩容至 200 词', '学习数据统计']),
  new LevelBenefit(2, ['解锁 L3 高阶课程', '专属中级成就徽章', '新功能优先体验']),
  new LevelBenefit(3, ['全部课程畅学无阻', '专属高级学习报告', '高级身份标识'])
]

class ExpWay {
  name: string = ''
  icon: Resource = $r('sys.symbol.house')
  desc: string = ''

  constructor(name: string, icon: Resource, desc: string) {
    this.name = name
    this.icon = icon
    this.desc = desc
  }
}

// 经验与硬币获取途径（学生）
const EXP_WAYS: ExpWay[] = [
  new ExpWay('每日登录', $r('sys.symbol.house'), `+${EXP_REWARDS['dailyLogin']} 经验 +5 硬币，每天首次启动发放`),
  new ExpWay('聊天交流', $r('sys.symbol.message'), `每条消息 +${EXP_REWARDS['chat']} 经验 +${EXP_REWARDS['chat']} 硬币，每日上限 20 经验 / 10 硬币`),
  new ExpWay('完成课程', $r('sys.symbol.graduationcap'), `每完成一节课 +${EXP_REWARDS['lesson']} 经验 +5 硬币`),
  new ExpWay('练习学习', $r('sys.symbol.gamecontroller_fill'), `单词/语法/口语/听力每完成一次练习 +${EXP_REWARDS['practice']} 经验 +3 硬币`),
  new ExpWay('学习打卡', $r('sys.symbol.flame_fill'), `课程页每日打卡 +${EXP_REWARDS['checkin']} 经验 +2 硬币`)
]

// 🌟 教师等级任务与学生完全不同：围绕教学行为积累经验，且不发放金币
const TEACHER_EXP_WAYS: ExpWay[] = [
  new ExpWay('布置作业', $r('sys.symbol.book'), `每布置一次教学任务 +${TEACHER_EXP_REWARDS['assign']} 经验`),
  new ExpWay('查看学情', $r('sys.symbol.person_filled_badge_plus'), `每天首次查看学生学习进度 +${TEACHER_EXP_REWARDS['progress']} 经验`),
  new ExpWay('班级群互动', $r('sys.symbol.message'), `每条群消息 +${TEACHER_EXP_REWARDS['group']} 经验，每日上限 ${TEACHER_GROUP_DAILY_CAP} 经验`),
  new ExpWay('教学打卡', $r('sys.symbol.flame_fill'), `发布教学打卡 +${TEACHER_EXP_REWARDS['checkin']} 经验`)
]

const TEACHER_LEVEL_BENEFITS: LevelBenefit[] = [
  new LevelBenefit(0, ['基础教学工作台', '布置作业与查看学生提交']),
  new LevelBenefit(1, ['学生学习进度统计', '班级作业数据看板']),
  new LevelBenefit(2, ['作业批改标记', '班级公告置顶']),
  new LevelBenefit(3, ['专属教学成就徽章', '年度教学报告'])
]

@Entry
@Component
struct LevelPage {
  // 🌟 与课程页/学科页共享的成长数据：等级实时同步
  @StorageLink('userExp') userExp: number = 0
  @StorageLink('studyLog') studyLog: Record<string, number> = {}
  @StorageLink('userRole') userRole: string = 'student'

  isTeacher(): boolean {
    return this.userRole === 'teacher'
  }

  expWays(): ExpWay[] {
    return this.isTeacher() ? TEACHER_EXP_WAYS : EXP_WAYS
  }

  benefits(): LevelBenefit[] {
    return this.isTeacher() ? TEACHER_LEVEL_BENEFITS : LEVEL_BENEFITS
  }

  studyLevel(): number {
    return expLevelOf(this.userExp)
  }

  streak(): number {
    let streak = 0
    let d = new Date()
    if (this.studyLog[dateKey(d)] === undefined) {
      d = new Date(d.getTime() - 86400000)
    }
    while (this.studyLog[dateKey(d)] !== undefined && this.studyLog[dateKey(d)] > 0) {
      streak++
      d = new Date(d.getTime() - 86400000)
    }
    return streak
  }

  // 下一个未达成的升级条件所需经验（已满级返回 -1）
  nextNeed(): number {
    for (let i = 0; i < LEVEL_CONDITIONS.length; i++) {
      if (this.userExp < LEVEL_CONDITIONS[i].need) {
        return LEVEL_CONDITIONS[i].need
      }
    }
    return -1
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          // ===== 顶部横幅：当前等级 + 经验进度 =====
          Column({ space: 14 }) {
            Row() {
              SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(22).fontColor([Color.White])
                .onClick(() => router.back())
              Blank()
              Text('等级与权益').fontSize(17).fontWeight(FontWeight.Bold).fontColor(Color.White)
              Blank()
              Row().width(22)
            }.width('100%')

            Row({ space: 14 }) {
              Text(`LV${this.studyLevel() + 1}`)
                .fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White)
                .width(64).height(64).borderRadius(20)
                .backgroundColor('#40FFFFFF')
                .textAlign(TextAlign.Center)
              Column({ space: 5 }) {
                Text(`${LEVEL_NAMES[this.studyLevel()]}等级`)
                  .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White)
                Text(this.studyLevel() >= 3 ? '已达到最高等级，继续保持！'
                  : `再获得 ${expToNextOf(this.userExp)} 点经验升级到 LV${this.studyLevel() + 2} ${LEVEL_NAMES[this.studyLevel() + 1]}`)
                  .fontSize(12).fontColor('#DCE9FB')
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }.width('100%').alignItems(VerticalAlign.Center)

            // 经验进度条
            Stack({ alignContent: Alignment.Start }) {
              Row().width('100%').height(8).borderRadius(4).backgroundColor('#40FFFFFF')
              Row()
                .width(`${levelProgressOf(this.userExp)}%`)
                .height(8).borderRadius(4).backgroundColor(Color.White)
            }.width('100%')

            Text(this.isTeacher() ? `当前经验 ${this.userExp} 点 · 连续教学 ${this.streak()} 天 · 教学任务积累成长`
              : `当前经验 ${this.userExp} 点 · 连续学习 ${this.streak()} 天 · 经验可兑换成长`)
              .fontSize(11).fontColor('#DCE9FB')
          }
          .width('92%')
          .padding(20)
          .linearGradient({ angle: 135, colors: [['#4C8BF5', 0], ['#3F7EF6', 1]] })
          .borderRadius(20)
          .margin({ top: 20 })
          .shadow({ radius: 10, color: 'rgba(63,126,246,0.25)', offsetY: 5 })

          // ===== 经验获取途径（🌟 老师与学生任务不同） =====
          Text(this.isTeacher() ? '教学任务经验' : '经验获取途径')
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
            .width('92%').margin({ top: 20, bottom: 10 })

          Column() {
            ForEach(this.expWays(), (w: ExpWay, idx: number) => {
              Column() {
                Row({ space: 12 }) {
                  Row() {
                    SymbolGlyph(w.icon).fontSize(17).fontColor([$r('app.color.primary')])
                  }
                  .width(38).height(38).borderRadius(11)
                  .backgroundColor($r('app.color.field_bg'))
                  .justifyContent(FlexAlign.Center)

                  Column({ space: 3 }) {
                    Text(w.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                    Text(w.desc).fontSize(10.5).fontColor($r('app.color.text_hint'))
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                }
                .width('100%')
                .padding({ top: 12, bottom: 12 })

                if (idx < this.expWays().length - 1) {
                  Divider().color($r('app.color.divider_color'))
                }
              }
            }, (w: ExpWay) => `${this.userRole}_${w.name}`)
          }
          .width('92%')
          .padding({ left: 16, right: 16 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(16)
          .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 4 })

          // ===== 升级条件 =====
          Text('升级条件').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
            .width('92%').margin({ top: 20, bottom: 10 })

          Column() {
            ForEach(LEVEL_CONDITIONS, (c: LevelCondition, idx: number) => {
              Column() {
                Row({ space: 12 }) {
                  Text(`LV${c.lv + 1}`)
                    .fontSize(12).fontWeight(FontWeight.Bold).fontColor(Color.White)
                    .width(40).height(40).borderRadius(12)
                    .backgroundColor(LEVEL_COLORS[c.lv])
                    .textAlign(TextAlign.Center)
                  Column({ space: 3 }) {
                    Text(LEVEL_NAMES[c.lv]).fontSize(14).fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_main'))
                    Text(c.desc).fontSize(11).fontColor($r('app.color.text_hint'))
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)

                  if (this.userExp >= c.need) {
                    Row({ space: 4 }) {
                      SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(15).fontColor(['#55C873'])
                      Text('已达成').fontSize(11).fontColor('#55C873')
                    }
                  } else if (c.need === this.nextNeed()) {
                    Text(`${this.userExp}/${c.need}`)
                      .fontSize(11).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
                  } else {
                    Row({ space: 4 }) {
                      SymbolGlyph($r('sys.symbol.lock')).fontSize(13).fontColor([$r('app.color.text_hint')])
                      Text('未解锁').fontSize(11).fontColor($r('app.color.text_hint'))
                    }
                  }
                }
                .width('100%')
                .padding({ top: 12, bottom: 12 })

                if (idx < LEVEL_CONDITIONS.length - 1) {
                  Divider().color($r('app.color.divider_color'))
                }
              }
            }, (c: LevelCondition) => `${c.lv}_${this.userExp >= c.need ? 1 : 0}`)
          }
          .width('92%')
          .padding({ left: 16, right: 16 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(16)
          .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 4 })

          // ===== 等级权益 =====
          Text('等级权益').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
            .width('92%').margin({ top: 20, bottom: 10 })

          Column() {
            ForEach(this.benefits(), (b: LevelBenefit, idx: number) => {
              Column() {
                Row({ space: 12 }) {
                  Text(`LV${b.lv + 1}`)
                    .fontSize(12).fontWeight(FontWeight.Bold).fontColor(Color.White)
                    .width(40).height(40).borderRadius(12)
                    .backgroundColor(b.lv <= this.studyLevel() ? LEVEL_COLORS[b.lv] : $r('app.color.text_hint'))
                    .textAlign(TextAlign.Center)
                  Column({ space: 6 }) {
                    ForEach(b.items, (it: string) => {
                      Row({ space: 6 }) {
                        SymbolGlyph(b.lv <= this.studyLevel() ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.lock'))
                          .fontSize(13)
                          .fontColor([b.lv <= this.studyLevel() ? LEVEL_COLORS[b.lv] : $r('app.color.text_hint')])
                        Text(it).fontSize(12)
                          .fontColor(b.lv <= this.studyLevel() ? $r('app.color.text_main') : $r('app.color.text_hint'))
                      }.width('100%')
                    }, (it: string) => it)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)

                  if (b.lv === this.studyLevel()) {
                    Text('当前等级')
                      .fontSize(10).fontColor(Color.White)
                      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                      .backgroundColor(LEVEL_COLORS[b.lv]).borderRadius(9)
                  }
                }
                .width('100%')
                .padding({ top: 12, bottom: 12 })

                if (idx < this.benefits().length - 1) {
                  Divider().color($r('app.color.divider_color'))
                }
              }
            }, (b: LevelBenefit) => `${this.userRole}_${b.lv}_${this.studyLevel() >= b.lv ? 1 : 0}`)
          }
          .width('92%')
          .padding({ left: 16, right: 16 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(16)
          .margin({ bottom: 30 })
          .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 4 })
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

// 学习日期键（yyyy-MM-dd），与课程页 studyLog 口径一致
function dateKey(d: Date): string {
  let m = (d.getMonth() + 1).toString().padStart(2, '0')
  let day = d.getDate().toString().padStart(2, '0')
  return `${d.getFullYear()}-${m}-${day}`
}
