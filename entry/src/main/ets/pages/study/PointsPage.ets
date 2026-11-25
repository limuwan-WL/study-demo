import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { PointRecord } from '../../model/DataModel'
import {
  PointRule,
  POINT_ACTIONS,
  PointAction,
  COURSE_ID,
  COURSE_NAME,
  ruleOf,
  saveRule,
  studentPointTotal,
  pointsCsvRows,
  normalizeCourseId
} from '../../model/InteractionModel'
import { CsvExport } from '../../utils/CsvExport'
import { EmptyState } from '../../components/StatusViews'

// ==================== 学分管理 ====================
// 🌟 教师：自定义签到 / 练习 / 抽选分值，单次上限与课程总上限，课程学分开关
// 🌟 助教：只读，不能修改学分规则
// 🌟 学生：查看个人学分明细（学分独立于课程考试成绩）
// ⚠️ 本地演示：学分台账保存在本机，导出为 Excel 兼容 CSV
@Entry
@Component
export struct PointsPage {
  @StorageLink('pointRecords') records: PointRecord[] = []
  @StorageLink('userRole') userRole: string = 'student'
  @StorageLink('nickname') nickname: string = '张同学'
  @State rule: PointRule = new PointRule()

  aboutToAppear(): void {
    this.rule = ruleOf(COURSE_ID)
  }

  isTeacher(): boolean {
    return this.userRole === 'teacher'
  }

  canViewAll(): boolean {
    return this.userRole === 'teacher' || this.userRole === 'assistant'
  }

  cloneRule(): PointRule {
    let r = new PointRule()
    r.enabled = this.rule.enabled
    r.signin = this.rule.signin
    r.practice = this.rule.practice
    r.random = this.rule.random
    r.singleCap = this.rule.singleCap
    r.courseCap = this.rule.courseCap
    return r
  }

  persist(): void {
    saveRule(COURSE_ID, this.cloneRule())
    AppStorage.setOrCreate('pointEnabled', this.rule.enabled)
  }

  guardEdit(): boolean {
    if (!this.isTeacher()) {
      promptAction.showToast({ message: '仅授课教师可修改学分规则，助教与学生只读' })
      return false
    }
    return true
  }

  setEnabled(v: boolean): void {
    if (!this.guardEdit()) {
      return
    }
    this.rule.enabled = v
    this.persist()
    promptAction.showToast({ message: v ? '已开启本课程学分' : '已关闭本课程学分，关闭后不再发放' })
  }

  changeValue(key: string, delta: number): void {
    if (!this.guardEdit()) {
      return
    }
    if (key === 'signin') {
      this.rule.signin = Math.max(0, Math.min(50, this.rule.signin + delta))
    } else if (key === 'practice') {
      this.rule.practice = Math.max(0, Math.min(50, this.rule.practice + delta))
    } else if (key === 'random') {
      this.rule.random = Math.max(0, Math.min(50, this.rule.random + delta))
    } else if (key === 'singleCap') {
      this.rule.singleCap = Math.max(1, Math.min(100, this.rule.singleCap + delta))
    } else if (key === 'courseCap') {
      this.rule.courseCap = Math.max(10, Math.min(1000, this.rule.courseCap + delta))
    }
    this.persist()
  }

  currentRecords(): PointRecord[] {
    let owner = this.canViewAll() ? '' : this.nickname
    return this.records.filter((r: PointRecord) => {
      let cid = normalizeCourseId(r.courseId)
      if (cid !== COURSE_ID) {
        return false
      }
      return owner === '' || r.student === owner
    })
  }

  myTotal(): number {
    return studentPointTotal(this.records, this.nickname, COURSE_ID)
  }

  percent(total: number): string {
    let cap = this.rule.courseCap <= 0 ? 1 : this.rule.courseCap
    return `${Math.min(100, Math.round(total / cap * 100))}%`
  }

  exportLedger(): void {
    try {
      let ctx = getContext(this) as common.UIAbilityContext
      let owner = this.canViewAll() ? '' : this.nickname
      let path = CsvExport.write(ctx, `points_${Date.now()}.csv`, pointsCsvRows(this.records, COURSE_ID, owner))
      AlertDialog.show({
        title: '导出完成（CSV）',
        message: `已生成 Excel 兼容的 CSV：\n${path}\n\n端上不生成真正的 .xlsx，请用 Excel / WPS 直接打开该 CSV（UTF-8 带 BOM）。`,
        confirm: { value: '知道了', action: () => {} }
      })
    } catch (e) {
      promptAction.showToast({ message: '导出失败' })
    }
  }

  @Builder
  header() {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(20).fontColor([$r('app.color.text_main')])
        .onClick(() => router.back())
      Column({ space: 2 }) {
        Text(this.canViewAll() ? '学分管理' : '我的学分').fontSize(18).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_main'))
        Text(`${COURSE_NAME} · ${this.userRole === 'assistant' ? '助教（只读）' : this.userRole === 'teacher' ? '授课教师' : '学生'}视角`)
          .fontSize(11).fontColor($r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (this.canViewAll()) {
        Text('导出')
          .fontSize(12).fontColor('#3F7EF6')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .border({ width: 1, color: '#3F7EF6' }).borderRadius(14)
          .onClick(() => this.exportLedger())
      }
    }
    .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 10 })
  }

  @Builder
  stepButton(text: string, onTap: () => void) {
    Text(text)
      .fontSize(15).fontColor(this.isTeacher() ? $r('app.color.text_main') : $r('app.color.text_hint'))
      .width(28).height(28).textAlign(TextAlign.Center)
      .backgroundColor($r('app.color.field_bg')).borderRadius(14)
      .onClick(() => onTap())
  }

  @Builder
  stepRow(label: string, tip: string, value: number, key: string) {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(label).fontSize(13).fontColor($r('app.color.text_main'))
        if (tip !== '') {
          Text(tip).fontSize(10).fontColor($r('app.color.text_hint'))
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      this.stepButton('－', (): void => this.changeValue(key, -1))
      Text(`${value}`).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#3F7EF6').width(34).textAlign(TextAlign.Center)
      this.stepButton('＋', (): void => this.changeValue(key, 1))
    }.width('100%')
  }

  @Builder
  recordRow(r: PointRecord, showStudent: boolean) {
    Row({ space: 8 }) {
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(r.action).fontSize(13).fontColor($r('app.color.text_main'))
          if (showStudent) {
            Text(r.student === '' ? '未标记学生' : r.student)
              .fontSize(10).fontColor($r('app.color.text_hint'))
          }
        }
        Text(r.time).fontSize(10).fontColor($r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text(`+${r.points}`).fontSize(14).fontWeight(FontWeight.Bold).fontColor('#10B981')
      Text(`累计 ${r.total}`).fontSize(10).fontColor($r('app.color.text_hint'))
    }
    .width('100%').padding({ top: 10, bottom: 10, left: 12, right: 12 })
  }

  build() {
    Column() {
      this.header()
      Scroll() {
        Column({ space: 12 }) {
          // 课程学分开关
          Column({ space: 10 }) {
            Row() {
              Column({ space: 2 }) {
                Text(COURSE_NAME).fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
                Text('学分独立于课程考试成绩，可单独开关')
                  .fontSize(10).fontColor($r('app.color.text_hint'))
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.rule.enabled })
                .selectedColor('#3F7EF6')
                .enabled(this.isTeacher())
                .onChange((v: boolean) => this.setEnabled(v))
            }.width('100%')
            if (!this.rule.enabled) {
              Text('本课程学分功能已关闭，签到 / 练习 / 抽选不再发放学分')
                .fontSize(11).fontColor('#EF4444').width('100%')
            }
            if (this.userRole === 'assistant') {
              Text('助教仅可查看学分规则，无法修改分值、上限与开关')
                .fontSize(11).fontColor('#F59E0B').width('100%')
            }
          }.width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(14)
          .alignItems(HorizontalAlign.Start)

          if (this.canViewAll()) {
            Column({ space: 14 }) {
              Row() {
                Text('学分规则').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).layoutWeight(1)
                Text(this.isTeacher() ? '修改后自动保存' : '只读')
                  .fontSize(10).fontColor($r('app.color.text_hint'))
              }.width('100%')
              ForEach(POINT_ACTIONS, (a: PointAction) => {
                this.stepRow(a.label, a.key === 'signin' ? '每完成一次有效签到' : a.key === 'practice'
                  ? '每次提交随堂练习' : '被抽中并标记完成答题', a.key === 'signin' ? this.rule.signin
                  : a.key === 'practice' ? this.rule.practice : this.rule.random, a.key)
              }, (a: PointAction) => a.key)
              Divider().color($r('app.color.divider_color'))
              this.stepRow('单次分值上限', '单次行为最多获得的学分', this.rule.singleCap, 'singleCap')
              this.stepRow('课程学分总分上限', `当前课程上限 ${this.rule.courseCap} 分`, this.rule.courseCap, 'courseCap')
              Text('发放时会同时受单次上限与课程总分上限约束，达到上限后不再增加。')
                .fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
            }.width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(14)
            .alignItems(HorizontalAlign.Start)
          } else {
            Column({ space: 8 }) {
              Text('学分规则').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).width('100%')
              Text(`完成签到：+${this.rule.signin} 分`).fontSize(12).fontColor($r('app.color.text_main')).width('100%')
              Text(`提交随堂练习：+${this.rule.practice} 分`).fontSize(12).fontColor($r('app.color.text_main')).width('100%')
              Text(`被抽中并完成答题：+${this.rule.random} 分`).fontSize(12).fontColor($r('app.color.text_main')).width('100%')
              Text(`单次上限 ${this.rule.singleCap} 分 · 课程总分上限 ${this.rule.courseCap} 分`)
                .fontSize(12).fontColor($r('app.color.text_sub')).width('100%')
            }.width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(14)
            .alignItems(HorizontalAlign.Start)
          }

          // 学生个人学分
          if (!this.canViewAll()) {
            Column({ space: 10 }) {
              Row() {
                Text('我的学分').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).layoutWeight(1)
                Text(`${this.myTotal()} / ${this.rule.courseCap}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#3F7EF6')
              }.width('100%')
              Row() {
                Row().width(this.percent(this.myTotal())).height(6).backgroundColor('#3F7EF6').borderRadius(3)
              }.width('100%').height(6).backgroundColor($r('app.color.field_bg')).borderRadius(3)
              Text(`本课程学分独立于考试成绩；达到 ${this.rule.courseCap} 分后不再增加。`)
                .fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
            }.width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(14)
            .alignItems(HorizontalAlign.Start)
          }

          // 台账
          Column({ space: 0 }) {
            Row() {
              Text(this.canViewAll() ? '学分明细台账' : '我的学分明细')
                .fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).layoutWeight(1)
              Text(`${this.currentRecords().length} 条`).fontSize(11).fontColor($r('app.color.text_hint'))
            }.width('100%').padding(12)
            ForEach(this.currentRecords(), (r: PointRecord) => {
              this.recordRow(r, this.canViewAll())
              Divider().color($r('app.color.divider_color')).margin({ left: 12, right: 12 })
            }, (r: PointRecord) => r.id)
            if (this.currentRecords().length === 0) {
              EmptyState({
                icon: $r('sys.symbol.book'),
                title: '暂无学分明细',
                desc: '签到、提交练习、抽选完成后会自动记入学分'
              })
            }
          }.width('92%').backgroundColor($r('app.color.card_bg')).borderRadius(14).clip(true)
          .alignItems(HorizontalAlign.Start)

          Text('本地演示：学分在签到 / 提交练习 / 抽选完成时自动记账，数据保存在本机；导出为 Excel 兼容 CSV。')
            .fontSize(11).fontColor($r('app.color.text_hint')).width('92%')
          Blank().height(30)
        }.width('100%').padding({ top: 4 }).alignItems(HorizontalAlign.Center)
      }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
    }
    .width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }
}
