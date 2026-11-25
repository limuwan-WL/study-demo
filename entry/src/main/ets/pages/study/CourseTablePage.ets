import router from '@ohos.router';
import { promptAction, componentSnapshot } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { formatDate, getTodayStr } from '../../model/DataModel';
import {
  CourseItem, ParsedCourse, TableTheme, TABLE_THEMES, tableThemeByKey,
  weekdayName, timeToMinutes, todayWeekday, sortCourses, copyCourse, coursesOnDay,
  DEFAULT_SLOT_TIMES, defaultSlotEnd, courseRenderKey, ensureStudentCourses
} from '../../model/TimetableModel';
import { Permission } from '../../model/PermissionModel';
import { parseIcsText, IcsParseResult, timeRangeText } from '../../utils/IcsImporter';
import { XlsxImporter, XlsxParseResult } from '../../utils/XlsxImporter';
import { TimetableSync } from '../../utils/TimetableSync';
import { CourseReminder, ReminderResult } from '../../utils/CourseReminder';

const TIME_COL_W: number = 58
const DAY_COL_W: number = 114
const ROW_H: number = 108

class CalCell {
  day: number = 0
  date: string = ''
  inMonth: boolean = false
  isToday: boolean = false
}

// ==================== 导入预览 ====================
@CustomDialog
struct ImportPreviewDialog {
  controller: CustomDialogController
  fileName: string = ''
  rows: ParsedCourse[] = []
  mappings: string[] = []
  @State mode: string = 'overwrite'
  onApply: (mode: string) => void = () => {}
  onClose: () => void = () => {}

  aboutToDisappear(): void {
    this.onClose()
  }

  @Builder
  mapChip(text: string) {
    Text(text)
      .fontSize(10).fontColor($r('app.color.primary'))
      .backgroundColor($r('app.color.primary_weak'))
      .borderRadius(8).padding({ left: 6, right: 6, top: 3, bottom: 3 })
      .margin({ right: 6, bottom: 6 })
  }

  @Builder
  modeCard(title: string, desc: string, value: string) {
    Column({ space: 3 }) {
      Text(title).fontSize(13).fontWeight(FontWeight.Medium)
        .fontColor(this.mode === value ? $r('app.color.primary') : $r('app.color.text_main'))
      Text(desc).fontSize(10).fontColor($r('app.color.text_sub')).maxLines(2)
    }
    .layoutWeight(1).alignItems(HorizontalAlign.Start).padding(10)
    .backgroundColor(this.mode === value ? $r('app.color.primary_weak') : $r('app.color.field_bg'))
    .borderRadius(10)
    .border({ width: 1, color: this.mode === value ? $r('app.color.primary') : Color.Transparent })
    .onClick(() => this.mode = value)
  }

  build() {
    Column({ space: 10 }) {
      Column({ space: 3 }) {
        Text('导入预览').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Text(`${this.fileName} · 共 ${this.rows.length} 门课程`).fontSize(12).fontColor($r('app.color.text_sub'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.width('100%').alignItems(HorizontalAlign.Start)

      Text('字段自动映射').fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.mappings, (m: string) => {
          this.mapChip(m)
        }, (m: string) => m)
      }.width('100%')

      List({ space: 8 }) {
        ForEach(this.rows, (r: ParsedCourse, idx: number) => {
          ListItem() {
            Row({ space: 10 }) {
              Column({ space: 3 }) {
                Text(r.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`${weekdayName(r.dayOfWeek)} ${timeRangeText(r.startTime, r.endTime)}`)
                  .fontSize(11).fontColor($r('app.color.primary'))
                Text(`${r.location === '' ? '地点：—' : '地点：' + r.location} · ${r.teacher === '' ? '教师：—' : '教师：' + r.teacher}`)
                  .fontSize(11).fontColor($r('app.color.text_sub'))
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text(`${idx + 1}`).fontSize(10).fontColor($r('app.color.text_hint'))
            }
            .width('100%').padding(10).backgroundColor($r('app.color.field_bg')).borderRadius(8)
          }
        }, (r: ParsedCourse, idx: number) => `${idx}_${r.name}_${r.dayOfWeek}_${r.startTime}`)
      }
      .layoutWeight(1).width('100%').scrollBar(BarState.Off)

      Text('导入模式').fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
      Row({ space: 8 }) {
        this.modeCard('覆盖导入', '清空当前课表，只保留本次导入', 'overwrite')
        this.modeCard('追加导入', '保留现有课程，自动跳过重复', 'append')
      }.width('100%')

      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).backgroundColor($r('app.color.btn_cancel'))
          .onClick(() => this.controller.close())
        Button('确认导入').layoutWeight(1)
          .onClick(() => {
            this.onApply(this.mode)
            this.controller.close()
          })
      }.width('100%').margin({ top: 4 })
    }
    .padding(18).width('92%').height(560)
    .backgroundColor($r('app.color.card_bg')).borderRadius(18)
  }
}

// ==================== 导入错误提示 ====================
@CustomDialog
struct ImportErrorDialog {
  controller: CustomDialogController
  typeLabel: string = ''
  title: string = ''
  message: string = ''
  hint: string = ''
  onClose: () => void = () => {}

  aboutToDisappear(): void {
    this.onClose()
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text(this.typeLabel)
          .fontSize(10).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .backgroundColor('#EF4444').borderRadius(6).padding({ left: 6, right: 6, top: 2, bottom: 2 })
        Text(this.title).fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      }.width('100%')

      Text(this.message).fontSize(13).lineHeight(20).fontColor($r('app.color.text_body')).width('100%')
      if (this.hint !== '') {
        Text(this.hint)
          .fontSize(12).lineHeight(18).fontColor($r('app.color.text_sub')).width('100%')
          .padding(10).backgroundColor($r('app.color.field_bg')).borderRadius(8)
      }
      Button('我知道了').width('100%').backgroundColor('#3F7EF6')
        .onClick(() => this.controller.close())
    }
    .padding(20).width('86%').backgroundColor($r('app.color.card_bg')).borderRadius(18)
    .alignItems(HorizontalAlign.Start)
  }
}

// ==================== 表格主题切换 ====================
@CustomDialog
struct TableThemeDialog {
  controller: CustomDialogController
  currentKey: string = 'classic'
  onPick: (key: string) => void = () => {}
  onClose: () => void = () => {}

  aboutToDisappear(): void {
    this.onClose()
  }

  build() {
    Column({ space: 10 }) {
      Text('表格主题').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        .width('100%').margin({ bottom: 2 })
      ForEach(TABLE_THEMES, (t: TableTheme) => {
        Row({ space: 12 }) {
          Row({ space: 3 }) {
            ForEach(t.palette.slice(0, 4), (c: string) => {
              Row().width(12).height(20).backgroundColor(c).borderRadius(3)
            }, (c: string, idx: number) => `${t.key}_${idx}`)
          }
          Column({ space: 2 }) {
            Text(t.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
            Text(t.desc).fontSize(11).fontColor($r('app.color.text_sub'))
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          if (this.currentKey === t.key) {
            Text('✓').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
          }
        }
        .width('100%').padding(12).borderRadius(10)
        .backgroundColor(this.currentKey === t.key ? $r('app.color.primary_weak') : $r('app.color.field_bg'))
        .onClick(() => {
          this.onPick(t.key)
          this.controller.close()
        })
      }, (t: TableTheme) => t.key)
    }
    .padding(18).width('90%').backgroundColor($r('app.color.card_bg')).borderRadius(18)
  }
}

// ==================== 同时段多课程浮层 ====================
@CustomDialog
struct SlotDialog {
  controller: CustomDialogController
  title: string = ''
  courses: CourseItem[] = []
  palette: string[] = []
  onPickCourse: (id: string) => void = () => {}
  onClose: () => void = () => {}

  aboutToDisappear(): void {
    this.onClose()
  }

  colorOf(c: CourseItem): string {
    let idx = c.colorIndex % this.palette.length
    return idx >= 0 && idx < this.palette.length ? this.palette[idx] : '#3F7EF6'
  }

  build() {
    Column({ space: 10 }) {
      Text('该时段课程').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        .width('100%')
      Text(this.title).fontSize(12).fontColor($r('app.color.text_sub')).width('100%')
      Scroll() {
        Column({ space: 8 }) {
          ForEach(this.courses, (c: CourseItem) => {
            Row({ space: 10 }) {
              Row().width(4).height(42).backgroundColor(this.colorOf(c)).borderRadius(2)
              Column({ space: 3 }) {
                Text(c.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`${timeRangeText(c.startTime, c.endTime)} · ${c.location === '' ? '地点待补充' : c.location}`)
                  .fontSize(11).fontColor($r('app.color.text_sub'))
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(c.teacher === '' ? '任课教师待补充' : `任课教师：${c.teacher}`)
                  .fontSize(11).fontColor($r('app.color.text_sub'))
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text('设置').fontSize(12).fontColor($r('app.color.primary'))
            }
            .width('100%').padding(10).backgroundColor($r('app.color.field_bg')).borderRadius(10)
            .onClick(() => {
              this.controller.close()
              this.onPickCourse(c.id)
            })
          }, (c: CourseItem) => c.id)
        }.width('100%')
      }
      .constraintSize({ maxHeight: 420 }).width('100%').scrollBar(BarState.Off)
      Button('关闭').width('100%').backgroundColor($r('app.color.btn_cancel'))
        .onClick(() => this.controller.close())
    }
    .padding(18).width('90%').backgroundColor($r('app.color.card_bg')).borderRadius(18)
  }
}

// ==================== 单门课程详情（颜色 / 提醒） ====================
@CustomDialog
struct CourseDetailDialog {
  controller: CustomDialogController
  course: CourseItem = new CourseItem('', '', '', 1, '08:00', '09:40')
  palette: string[] = []
  onColor: (index: number) => void = () => {}
  onReminder: (on: boolean, minutes: number) => Promise<boolean> = () => Promise.resolve(false)
  @State colorIndex: number = 0
  @State reminderOn: boolean = false
  @State reminderMinutes: number = 10
  @State busy: boolean = false
  @State note: string = ''
  onClose: () => void = () => {}

  aboutToDisappear(): void {
    this.onClose()
  }

  aboutToAppear(): void {
    this.colorIndex = this.course.colorIndex
    this.reminderOn = this.course.reminderEnabled
    this.reminderMinutes = this.course.reminderMinutes
  }

  @Builder
  infoRow(label: string, value: string) {
    Row({ space: 8 }) {
      Text(label).fontSize(12).fontColor($r('app.color.text_sub')).width(56)
      Text(value === '' ? '—' : value).fontSize(13).fontColor($r('app.color.text_main')).layoutWeight(1)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('100%')
  }

  @Builder
  minuteChip(m: number) {
    Text(`提前 ${m} 分钟`)
      .fontSize(11)
      .fontColor(this.reminderMinutes === m ? Color.White : $r('app.color.text_sub'))
      .backgroundColor(this.reminderMinutes === m ? '#3F7EF6' : $r('app.color.field_bg'))
      .borderRadius(10).padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .onClick(() => this.applyMinutes(m))
  }

  applyMinutes(m: number) {
    let wasOn = this.reminderOn
    this.reminderMinutes = m
    if (!wasOn) {
      return
    }
    this.busy = true
    this.onReminder(true, m).then((ok: boolean) => {
      this.busy = false
      if (!ok) {
        this.note = '提醒时间更新失败，请查看提示'
      }
    })
  }

  handleToggle(on: boolean) {
    this.busy = true
    this.onReminder(on, this.reminderMinutes).then((ok: boolean) => {
      this.busy = false
      this.reminderOn = ok ? on : !on
      this.note = ok ? (on ? '已开启每周上课提醒' : '已关闭上课提醒') : '提醒设置失败，请查看提示'
    }).catch((err: BusinessError) => {
      this.busy = false
      this.reminderOn = !on
      this.note = '提醒设置失败'
    })
  }

  build() {
    Column({ space: 14 }) {
      Text(this.course.name).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        .width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      Column({ space: 6 }) {
        this.infoRow('上课时段', `${weekdayName(this.course.dayOfWeek)} ${timeRangeText(this.course.startTime, this.course.endTime)}`)
        this.infoRow('授课地点', this.course.location)
        this.infoRow('任课教师', this.course.teacher)
      }.width('100%')

      Divider().color($r('app.color.divider_color'))

      Column({ space: 8 }) {
        Text('课程颜色').fontSize(12).fontColor($r('app.color.text_sub')).width('100%')
        Row({ space: 8 }) {
          ForEach(this.palette, (color: string, idx: number) => {
            Stack() {
              Row().width(26).height(26).backgroundColor(color).borderRadius(13)
              if (this.colorIndex === idx) {
                Text('✓').fontSize(13).fontWeight(FontWeight.Bold).fontColor(Color.White)
              }
            }
            .width(32).height(32).borderRadius(16)
            .border({ width: 2, color: this.colorIndex === idx ? '#3F7EF6' : Color.Transparent })
            .onClick(() => {
              this.colorIndex = idx
              this.onColor(idx)
            })
          }, (color: string, idx: number) => `${idx}_${color}`)
        }.width('100%')
        Text('颜色跟随表格主题切换，也可以单独修改这一门课').fontSize(10).fontColor($r('app.color.text_hint'))
          .width('100%')
      }.width('100%').alignItems(HorizontalAlign.Start)

      Divider().color($r('app.color.divider_color'))

      Row() {
        Column({ space: 2 }) {
          Text('上课日程提醒').fontSize(13).fontColor($r('app.color.text_main'))
          Text(`每周${weekdayName(this.course.dayOfWeek)}课前系统推送`).fontSize(10).fontColor($r('app.color.text_hint'))
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.reminderOn })
          .enabled(!this.busy)
          .onChange((v: boolean) => this.handleToggle(v))
      }.width('100%')

      if (this.reminderOn) {
        Row({ space: 8 }) {
          ForEach([5, 10, 15, 30], (m: number) => {
            this.minuteChip(m)
          }, (m: number) => `${m}`)
        }.width('100%')
      }
      if (this.note !== '') {
        Text(this.note).fontSize(11).fontColor($r('app.color.text_sub')).width('100%')
      }

      Button('完成').width('100%').backgroundColor('#3F7EF6')
        .onClick(() => this.controller.close())
    }
    .padding(20).width('88%').backgroundColor($r('app.color.card_bg')).borderRadius(18)
    .alignItems(HorizontalAlign.Start)
  }
}

// ==================== 云端同步（本地模拟） ====================
@CustomDialog
struct SyncDialog {
  controller: CustomDialogController
  account: string = ''
  localCount: number = 0
  cloudCount: number = 0
  cloudTime: string = ''
  onPush: () => Promise<string> = () => Promise.resolve('')
  onPull: () => Promise<string> = () => Promise.resolve('')
  @State busy: boolean = false
  @State result: string = ''
  onClose: () => void = () => {}

  aboutToDisappear(): void {
    this.onClose()
  }

  run(action: string) {
    if (this.busy) {
      return
    }
    this.busy = true
    let task = action === 'push' ? this.onPush() : this.onPull()
    task.then((msg: string) => {
      this.busy = false
      this.result = msg
    }).catch((err: BusinessError) => {
      this.busy = false
      this.result = '同步失败，请稍后重试'
    })
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text('课表云同步').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Text('模拟').fontSize(10).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .backgroundColor('#E8A33E').borderRadius(6).padding({ left: 6, right: 6, top: 2, bottom: 2 })
      }.width('100%')

      Text('当前工程没有真实后端，这里的「云端」是本机模拟快照层，仅用于演示换设备登录后的拉取流程。')
        .fontSize(12).lineHeight(18).fontColor($r('app.color.text_sub')).width('100%')

      Column({ space: 6 }) {
        this.infoLine('同步账号', this.account === '' ? '未登录账号' : this.account)
        this.infoLine('本地课程', `${this.localCount} 门`)
        this.infoLine('云端课程', `${this.cloudCount} 门`)
        this.infoLine('最近同步', this.cloudTime === '' ? '暂无记录' : this.cloudTime)
      }
      .width('100%').padding(12).backgroundColor($r('app.color.field_bg')).borderRadius(10)

      Row({ space: 10 }) {
        Button('上传到云端').layoutWeight(1).backgroundColor('#3F7EF6').enabled(!this.busy)
          .onClick(() => this.run('push'))
        Button('从云端拉取').layoutWeight(1).backgroundColor('#55C873').enabled(!this.busy)
          .onClick(() => this.run('pull'))
      }.width('100%')

      if (this.result !== '') {
        Text(this.result).fontSize(12).fontColor($r('app.color.text_body')).width('100%')
      }
      Button('关闭').width('100%').backgroundColor($r('app.color.btn_cancel'))
        .onClick(() => this.controller.close())
    }
    .padding(20).width('88%').backgroundColor($r('app.color.card_bg')).borderRadius(18)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  infoLine(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor($r('app.color.text_sub'))
      Blank()
      Text(value).fontSize(12).fontColor($r('app.color.text_main')).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1).textAlign(TextAlign.End)
    }.width('100%')
  }
}

// ==================== 课程表主页 ====================
@Entry
@Component
struct CourseTablePage {
  @StorageLink('courseTable') courseTable: CourseItem[] = []
  @StorageLink('courseTableTheme') themeKey: string = 'classic'
  @StorageLink('regAccount') account: string = ''
  @State viewMode: string = 'week'
  @State weekOffset: number = 0
  @State monthOffset: number = 0
  @State selectedDate: string = ''
  @State dialogOpen: boolean = false
  private hoverTimer: number = -1

  // 导入预览数据
  @State previewRows: ParsedCourse[] = []
  @State previewMappings: string[] = []
  @State previewFileName: string = ''

  previewController: CustomDialogController = new CustomDialogController({
    builder: ImportPreviewDialog({}),
    customStyle: true
  })
  errorController: CustomDialogController = new CustomDialogController({
    builder: ImportErrorDialog({}),
    customStyle: true
  })
  themeController: CustomDialogController = new CustomDialogController({
    builder: TableThemeDialog({}),
    customStyle: true
  })
  slotController: CustomDialogController = new CustomDialogController({
    builder: SlotDialog({}),
    customStyle: true
  })
  detailController: CustomDialogController = new CustomDialogController({
    builder: CourseDetailDialog({}),
    customStyle: true
  })
  syncController: CustomDialogController = new CustomDialogController({
    builder: SyncDialog({}),
    customStyle: true
  })

  aboutToAppear(): void {
    // 换设备登录后本地为空时，自动从「模拟云端」拉取该账号的课表
    if (this.courseTable.length === 0 && this.account !== '') {
      let cloud = TimetableSync.pull(this.account)
      if (cloud.length > 0) {
        this.courseTable = sortCourses(cloud)
        promptAction.showToast({ message: `已从模拟云端恢复 ${cloud.length} 门课程` })
      }
    }
    // 🌟 学生端：本地仍为空且从未自动生成过时，生成一份默认课表
    if (this.courseTable.length === 0 && Permission.isStudent()) {
      if (ensureStudentCourses()) {
        promptAction.showToast({ message: '已为你自动生成课表' })
      }
    }
  }

  aboutToDisappear(): void {
    if (this.hoverTimer > 0) {
      clearTimeout(this.hoverTimer)
    }
  }

  theme(): TableTheme {
    return tableThemeByKey(this.themeKey)
  }

  courseColor(c: CourseItem): string {
    let palette = this.theme().palette
    let idx = c.colorIndex % palette.length
    return idx >= 0 && idx < palette.length ? palette[idx] : '#3F7EF6'
  }

  // ---------- 周视图 ----------
  weekStartDate(): Date {
    let now = new Date()
    let day = now.getDay()
    let monday = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    monday.setDate(monday.getDate() - (day === 0 ? 6 : day - 1) + this.weekOffset * 7)
    return monday
  }

  weekDates(): string[] {
    let monday = this.weekStartDate()
    let days: string[] = []
    for (let i = 0; i < 7; i++) {
      days.push(formatDate(new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + i)))
    }
    return days
  }

  weekTitle(): string {
    let days = this.weekDates()
    return `${days[0].slice(5)} ~ ${days[6].slice(5)}`
  }

  weekSlotTimes(): string[] {
    // 🌟 先铺满标准作息时段，再并入课程里出现的自定义开始时间（如 09:30）
    let times: string[] = DEFAULT_SLOT_TIMES.slice()
    this.courseTable.forEach((c: CourseItem) => {
      if (times.indexOf(c.startTime) < 0) {
        times.push(c.startTime)
      }
    })
    return times.sort((a: string, b: string) => timeToMinutes(a) - timeToMinutes(b))
  }

  slotEndText(slot: string): string {
    let ends: string[] = []
    this.courseTable.forEach((c: CourseItem) => {
      if (c.startTime === slot && ends.indexOf(c.endTime) < 0) {
        ends.push(c.endTime)
      }
    })
    return ends.length > 0 ? ends[0] : defaultSlotEnd(slot)
  }

  coursesAt(day: number, slot: string): CourseItem[] {
    return this.courseTable.filter((c: CourseItem) => c.dayOfWeek === day && c.startTime === slot)
  }

  // ---------- 月视图 ----------
  monthDate(): Date {
    let now = new Date()
    return new Date(now.getFullYear(), now.getMonth() + this.monthOffset, 1)
  }

  monthTitle(): string {
    let d = this.monthDate()
    return `${d.getFullYear()}年${d.getMonth() + 1}月`
  }

  monthCells(): CalCell[] {
    let first = this.monthDate()
    let year = first.getFullYear()
    let month = first.getMonth()
    let daysInMonth = new Date(year, month + 1, 0).getDate()
    let firstWeekday = first.getDay() === 0 ? 7 : first.getDay()
    let startOffset = firstWeekday - 1
    let cells: CalCell[] = []
    for (let i = 0; i < 42; i++) {
      let cell = new CalCell()
      let dayNum = i - startOffset + 1
      if (dayNum >= 1 && dayNum <= daysInMonth) {
        let date = formatDate(new Date(year, month, dayNum))
        cell.day = dayNum
        cell.date = date
        cell.inMonth = true
        cell.isToday = date === getTodayStr()
      }
      cells.push(cell)
    }
    return cells
  }

  weekdayOfDate(date: string): number {
    let parts = date.split('-')
    if (parts.length < 3) {
      return 1
    }
    let d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]))
    let w = d.getDay()
    return w === 0 ? 7 : w
  }

  dateCourses(date: string): CourseItem[] {
    return coursesOnDay(this.courseTable, this.weekdayOfDate(date))
  }

  // ---------- 课程数据更新 ----------
  updateCourse(id: string, mutate: (c: CourseItem) => void) {
    this.courseTable = this.courseTable.map((c: CourseItem) => {
      if (c.id !== id) {
        return c
      }
      let next = copyCourse(c)
      mutate(next)
      return next
    })
  }

  findCourse(id: string): CourseItem | undefined {
    return this.courseTable.find((c: CourseItem) => c.id === id)
  }

  setCourseColor(id: string, index: number) {
    this.updateCourse(id, (c: CourseItem) => {
      c.colorIndex = index
    })
  }

  async toggleReminder(id: string, on: boolean, minutes: number): Promise<boolean> {
    let course = this.findCourse(id)
    if (course === undefined) {
      return false
    }
    if (on) {
      let res: ReminderResult = await CourseReminder.publish(course, minutes)
      if (!res.ok) {
        promptAction.showToast({ message: res.message })
        return false
      }
      this.updateCourse(id, (c: CourseItem) => {
        c.reminderEnabled = true
        c.reminderMinutes = minutes
        c.reminderId = res.reminderId
      })
      promptAction.showToast({ message: res.message })
      return true
    }
    await CourseReminder.cancel(course.reminderId)
    this.updateCourse(id, (c: CourseItem) => {
      c.reminderEnabled = false
      c.reminderId = 0
    })
    promptAction.showToast({ message: '已关闭上课提醒' })
    return true
  }

  // ---------- 弹窗 ----------
  openTheme() {
    if (this.dialogOpen) {
      return
    }
    this.dialogOpen = true
    this.themeController = new CustomDialogController({
      builder: TableThemeDialog({
        currentKey: this.themeKey,
        onPick: (key: string) => {
          this.themeKey = key
          promptAction.showToast({ message: `已切换为「${tableThemeByKey(key).name}」` })
        },
        onClose: () => {
          this.dialogOpen = false
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.themeController.open()
  }

  openSlot(day: number, slot: string) {
    let list = this.coursesAt(day, slot)
    if (list.length === 0) {
      return
    }
    if (list.length === 1) {
      this.openDetail(list[0].id)
      return
    }
    if (this.dialogOpen) {
      return
    }
    this.dialogOpen = true
    this.slotController = new CustomDialogController({
      builder: SlotDialog({
        title: `${weekdayName(day)} ${slot} 同时段 ${list.length} 门课程`,
        courses: list,
        palette: this.theme().palette,
        onPickCourse: (id: string) => {
          this.dialogOpen = false
          setTimeout(() => {
            this.openDetail(id)
          }, 160)
        },
        onClose: () => {
          this.dialogOpen = false
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.slotController.open()
  }

  openDetail(id: string) {
    let course = this.findCourse(id)
    if (course === undefined || this.dialogOpen) {
      return
    }
    this.dialogOpen = true
    this.detailController = new CustomDialogController({
      builder: CourseDetailDialog({
        course: course,
        palette: this.theme().palette,
        onColor: (index: number) => {
          this.setCourseColor(id, index)
        },
        onReminder: (on: boolean, minutes: number) => this.toggleReminder(id, on, minutes),
        onClose: () => {
          this.dialogOpen = false
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.detailController.open()
  }

  // 🌟 一键导出课表为图片：截取完整周课表节点 → PNG 写入应用文件目录
  async exportTimetableImage(): Promise<void> {
    if (this.courseTable.length === 0) {
      promptAction.showToast({ message: '课表为空，先导入课程后再导出' })
      return
    }
    if (this.viewMode !== 'week') {
      promptAction.showToast({ message: '请切换到「本周课表」后导出图片' })
      return
    }
    try {
      let pm = await componentSnapshot.get('timetableExport')
      let packer = image.createImagePacker()
      let opt: image.PackingOption = { format: 'image/png', quality: 100 }
      let buf = await packer.packing(pm, opt)
      let ctx = getContext(this) as common.UIAbilityContext
      let dest = `${ctx.filesDir}/timetable_${Date.now()}.png`
      let f = fs.openSync(dest, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
      fs.writeSync(f.fd, buf)
      fs.closeSync(f)
      packer.release()
      pm.release()
      promptAction.showToast({ message: '课表图片已生成并保存到应用文件目录，可直接分享' })
    } catch (e) {
      promptAction.showToast({ message: '导出失败：当前课表渲染异常，请稍后重试' })
    }
  }

  openSync() {
    if (this.dialogOpen) {
      return
    }
    this.dialogOpen = true
    this.syncController = new CustomDialogController({
      builder: SyncDialog({
        account: this.account,
        localCount: this.courseTable.length,
        cloudCount: TimetableSync.cloudCount(this.account),
        cloudTime: TimetableSync.cloudTime(this.account),
        onPush: () => this.doSyncPush(),
        onPull: () => this.doSyncPull(),
        onClose: () => {
          this.dialogOpen = false
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.syncController.open()
  }

  async doSyncPush(): Promise<string> {
    if (this.courseTable.length === 0) {
      return '本地暂无课程，无法上传'
    }
    let stamp = TimetableSync.push(this.account, this.courseTable)
    promptAction.showToast({ message: `已上传 ${this.courseTable.length} 门课程（模拟）` })
    return `上传成功：${this.courseTable.length} 门课程 · ${stamp}`
  }

  async doSyncPull(): Promise<string> {
    let cloud = TimetableSync.pull(this.account)
    if (cloud.length === 0) {
      return '云端暂无该账号的课表快照'
    }
    this.courseTable = sortCourses(cloud)
    promptAction.showToast({ message: `已拉取 ${cloud.length} 门课程（模拟）` })
    return `拉取成功：${cloud.length} 门课程 · ${TimetableSync.cloudTime(this.account)}`
  }

  openError(typeLabel: string, title: string, message: string, hint: string) {
    if (this.dialogOpen) {
      return
    }
    this.dialogOpen = true
    this.errorController = new CustomDialogController({
      builder: ImportErrorDialog({
        typeLabel: typeLabel,
        title: title,
        message: message,
        hint: hint,
        onClose: () => {
          this.dialogOpen = false
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.errorController.open()
  }

  // ---------- 文件导入 ----------
  readTextFromUri(uri: string): string {
    let file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
    let stat = fs.statSync(file.fd)
    let buf = new ArrayBuffer(stat.size)
    let readLen = fs.readSync(file.fd, buf)
    fs.closeSync(file)
    let decoder = util.TextDecoder.create('utf-8')
    return decoder.decodeToString(new Uint8Array(buf, 0, readLen))
  }

  async pickImportFile() {
    if (this.dialogOpen) {
      return
    }
    try {
      let context = getContext(this) as common.UIAbilityContext
      let documentPicker = new picker.DocumentViewPicker(context)
      let options = new picker.DocumentSelectOptions()
      options.maxSelectNumber = 1
      options.fileSuffixFilters = ['.ics', '.xlsx']
      let uris = await documentPicker.select(options)
      if (uris === undefined || uris.length === 0) {
        return
      }
      let uri = uris[0]
      let fileName = uri
      let slash = fileName.lastIndexOf('/')
      if (slash >= 0) {
        fileName = fileName.substring(slash + 1)
      }
      try {
        fileName = decodeURIComponent(fileName)
      } catch (e) {
        // 文件名解码失败时保留原样
      }
      let lower = fileName.toLowerCase()
      if (lower.endsWith('.xlsx')) {
        // 🌟 xlsx：zlib 解压 + XML 解析（本地离线，无需三方库）
        let ctx = getContext(this) as common.UIAbilityContext
        let xr: XlsxParseResult = await XlsxImporter.parse(uri, ctx.cacheDir)
        if (!xr.ok) {
          let label = xr.errorType === 'missing' ? '缺少必要列' : '解析失败'
          this.openError(label, '课表解析失败', xr.message,
            'xlsx 表头需包含：课程名称、星期、开始时间（或「上课时间」08:00-09:40）；地点、结束时间、教师可缺省。')
          return
        }
        this.openPreview(fileName, xr.courses, xr.mappings)
        if (xr.skipped > 0) {
          promptAction.showToast({ message: xr.message })
        }
        return
      }
      if (!lower.endsWith('.ics')) {
        this.openError('格式不支持', '无法识别的文件类型',
          `当前文件「${fileName}」不是课表支持的格式。`, '请选择 .ics 或 .xlsx 课表文件。')
        return
      }
      let text = ''
      try {
        text = this.readTextFromUri(uri)
      } catch (e) {
        this.openError('解析失败', '文件读取失败',
          '无法读取所选文件，可能是文件已被移动、权限不足或文件损坏。', '请重新选择文件后再试。')
        return
      }
      let result: IcsParseResult = parseIcsText(text)
      if (!result.ok) {
        let label = result.errorType === 'format' ? '格式问题' : (result.errorType === 'missing' ? '字段缺失' : '解析失败')
        let title = result.errorType === 'format' ? '课表格式不正确' :
          (result.errorType === 'missing' ? '缺少必要字段' : '课表解析失败')
        this.openError(label, title, result.message,
          '必要字段：课程名称（SUMMARY）与上课时段（DTSTART）。地点与教师可以缺省。')
        return
      }
      this.openPreview(fileName, result.courses, result.mappings)
      if (result.skipped > 0) {
        promptAction.showToast({ message: result.message })
      }
    } catch (err) {
      this.openError('解析失败', '导入未完成',
        '选择或解析文件时发生异常，文件可能已损坏或编码不受支持。', '请确认文件为标准 .ics 或 .xlsx 课表后重试。')
    }
  }

  // 🌟 统一导入预览：ics / xlsx 共用同一套预览、映射说明与覆盖/追加逻辑
  openPreview(fileName: string, cards: ParsedCourse[], mappings: string[]) {
    this.previewRows = cards
    this.previewMappings = mappings
    this.previewFileName = fileName
    this.dialogOpen = true
    this.previewController = new CustomDialogController({
      builder: ImportPreviewDialog({
        fileName: fileName,
        rows: cards,
        mappings: mappings,
        onApply: (mode: string) => {
          this.applyImport(mode, cards)
        },
        onClose: () => {
          this.dialogOpen = false
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.previewController.open()
  }

  applyImport(mode: string, rows: ParsedCourse[]) {
    let existing = this.courseTable.slice()
    let imported: CourseItem[] = []
    // 同一门课（同名）在一周内多个时段复用同一个颜色
    let nameColors: Record<string, number> = {}
    let colorCursor = this.courseTable.length
    rows.forEach((r: ParsedCourse) => {
      let old = existing.find((c: CourseItem) => c.name === r.name && c.dayOfWeek === r.dayOfWeek &&
        c.startTime === r.startTime)
      let sameName = existing.find((c: CourseItem) => c.name === r.name)
      let color = colorCursor % 8
      if (old !== undefined) {
        color = old.colorIndex
      } else if (nameColors[r.name] !== undefined) {
        color = nameColors[r.name]
      } else if (sameName !== undefined) {
        color = sameName.colorIndex
      } else {
        colorCursor++
      }
      nameColors[r.name] = color
      let item = new CourseItem(r.name, r.location, r.teacher, r.dayOfWeek, r.startTime, r.endTime, color)
      if (old !== undefined) {
        item.reminderEnabled = old.reminderEnabled
        item.reminderMinutes = old.reminderMinutes
        item.reminderId = old.reminderId
      }
      imported.push(item)
    })

    if (mode === 'append') {
      let merged = existing.slice()
      imported.forEach((item: CourseItem) => {
        let duplicated = merged.some((c: CourseItem) => c.name === item.name && c.dayOfWeek === item.dayOfWeek &&
          c.startTime === item.startTime)
        if (!duplicated) {
          merged.push(item)
        }
      })
      this.courseTable = sortCourses(merged)
    } else {
      // 覆盖导入：取消被替换课程的系统提醒，避免遗留孤儿提醒
      existing.forEach((c: CourseItem) => {
        if (c.reminderEnabled && c.reminderId > 0) {
          CourseReminder.cancel(c.reminderId)
        }
      })
      this.courseTable = sortCourses(imported)
    }
    promptAction.showToast({ message: `导入成功：${this.courseTable.length} 门课程` })
  }

  // ---------- 周视图 UI ----------
  startHover(day: number, slot: string) {
    if (this.coursesAt(day, slot).length <= 1 || this.dialogOpen) {
      return
    }
    this.hoverTimer = setTimeout(() => {
      this.openSlot(day, slot)
    }, 500)
  }

  cancelHover() {
    if (this.hoverTimer > 0) {
      clearTimeout(this.hoverTimer)
      this.hoverTimer = -1
    }
  }

  @Builder
  weekHeaderCell(date: string, idx: number) {
    Column({ space: 3 }) {
      Text(weekdayName(idx + 1)).fontSize(11).fontWeight(FontWeight.Medium).fontColor(this.theme().headerText)
      Text(date.slice(5)).fontSize(10)
        .fontColor(date === getTodayStr() ? Color.White : this.theme().textSub)
        .backgroundColor(date === getTodayStr() ? '#3F7EF6' : Color.Transparent)
        .borderRadius(7).padding({ left: 4, right: 4 })
    }
    .width(DAY_COL_W).height(48).justifyContent(FlexAlign.Center)
    .backgroundColor(this.theme().headerBg)
    .border({ width: { right: 1, bottom: 1 }, color: this.theme().border })
  }

  @Builder
  courseBlock(c: CourseItem) {
    Column({ space: 1 }) {
      Text(c.name).fontSize(11).fontWeight(FontWeight.Medium).fontColor(this.theme().chipText)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      Text(c.location === '' ? '地点待补充' : c.location)
        .fontSize(9).fontColor(this.theme().chipText).opacity(0.92)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      Text(c.teacher === '' ? '教师待补充' : c.teacher)
        .fontSize(9).fontColor(this.theme().chipText).opacity(0.92)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      Text(timeRangeText(c.startTime, c.endTime))
        .fontSize(9).fontColor(this.theme().chipText).opacity(0.92)
        .maxLines(1).width('100%')
    }
    .width('100%').height('100%').padding(5)
    .backgroundColor(this.courseColor(c))
    .borderRadius(5)
  }

  @Builder
  weekCell(day: number, slot: string) {
    // 🌟 同一格多节课并行展示（横向等分），不再互相覆盖导致看起来「一天只有一节课」
    Row({ space: 2 }) {
      if (this.coursesAt(day, slot).length === 0) {
        Text('').layoutWeight(1).height('100%')
      } else {
        ForEach(this.coursesAt(day, slot), (c: CourseItem) => {
          Column() {
            this.courseBlock(c)
          }
          .layoutWeight(1)
          .height('100%')
        }, (c: CourseItem) => courseRenderKey(c))
      }
    }
    .width(DAY_COL_W).height(ROW_H).padding(4)
    .backgroundColor(this.theme().bg)
    .border({ width: { right: 1, bottom: 1 }, color: this.theme().border })
    .onClick(() => this.openSlot(day, slot))
    .onHover((isHover: boolean) => {
      if (isHover) {
        this.startHover(day, slot)
      } else {
        this.cancelHover()
      }
    })
  }

  @Builder
  weekRow(slot: string) {
    Row() {
      Column({ space: 2 }) {
        Text(slot).fontSize(12).fontWeight(FontWeight.Medium).fontColor(this.theme().textMain)
        Text(this.slotEndText(slot)).fontSize(9).fontColor(this.theme().textSub)
      }
      .width(TIME_COL_W).height(ROW_H).justifyContent(FlexAlign.Center)
      .border({ width: { right: 1, bottom: 1 }, color: this.theme().border })

      ForEach([1, 2, 3, 4, 5, 6, 7], (day: number) => {
        this.weekCell(day, slot)
      }, (day: number) => `${day}_${slot}`)
    }.height(ROW_H)
  }

  @Builder
  weekTable() {
    Scroll() {
      Column() {
        Row() {
          Text('时段').fontSize(11).fontWeight(FontWeight.Medium).fontColor(this.theme().headerText)
            .width(TIME_COL_W).height(48).textAlign(TextAlign.Center)
            .backgroundColor(this.theme().headerBg)
            .border({ width: { right: 1, bottom: 1 }, color: this.theme().border })
          ForEach(this.weekDates(), (date: string, idx: number) => {
            this.weekHeaderCell(date, idx)
          }, (date: string) => date)
        }
        ForEach(this.weekSlotTimes(), (slot: string) => {
          this.weekRow(slot)
        }, (slot: string) => slot)
      }
      .width(TIME_COL_W + DAY_COL_W * 7)
      .backgroundColor(this.theme().bg)
      .border({ width: 1, color: this.theme().border })
      // 🌟 导出节点：截图时包含完整一周课表（不受横向滚动视口裁剪）
      .id('timetableExport')
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  // ---------- 月视图 UI ----------
  @Builder
  monthChip(c: CourseItem) {
    Text(c.name)
      .fontSize(8).fontColor(this.theme().chipText)
      .backgroundColor(this.courseColor(c)).borderRadius(2)
      .padding({ left: 2, right: 2, top: 1, bottom: 1 })
      .width('100%').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  monthCell(cell: CalCell) {
    Column({ space: 2 }) {
      Row() {
        Text(cell.inMonth ? `${cell.day}` : '')
          .fontSize(11)
          .fontWeight(cell.isToday ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(cell.isToday ? Color.White : this.theme().textMain)
          .width(20).height(20).textAlign(TextAlign.Center)
          .backgroundColor(cell.isToday ? '#3F7EF6' : Color.Transparent)
          .borderRadius(10)
        Blank()
      }.width('100%')
      if (cell.inMonth) {
        ForEach(this.dateCourses(cell.date).slice(0, 2), (c: CourseItem) => {
          this.monthChip(c)
        }, (c: CourseItem) => `${cell.date}_${courseRenderKey(c)}`)
        if (this.dateCourses(cell.date).length > 2) {
          Text(`+${this.dateCourses(cell.date).length - 2}`).fontSize(8).fontColor(this.theme().textSub)
            .width('100%')
        }
      }
    }
    .width('100%').height(76).padding(3).alignItems(HorizontalAlign.Start)
    .backgroundColor(cell.inMonth ? this.theme().bg : $r('app.color.card_bg'))
    .border({
      width: this.selectedDate === cell.date ? 2 : 0.5,
      color: this.selectedDate === cell.date ? '#3F7EF6' : this.theme().border
    })
    .borderRadius(4)
    .onClick(() => {
      if (!cell.inMonth) {
        return
      }
      this.selectedDate = this.selectedDate === cell.date ? '' : cell.date
    })
  }

  @Builder
  monthGrid() {
    Grid() {
      ForEach(this.monthCells(), (cell: CalCell, idx: number) => {
        GridItem() {
          this.monthCell(cell)
        }
      }, (cell: CalCell, idx: number) => `${idx}_${cell.date}`)
    }
    .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
    .columnsGap(2).rowsGap(2)
    .width('100%')
  }

  @Builder
  dayCourseRow(c: CourseItem) {
    Row({ space: 10 }) {
      Row().width(4).height(40).backgroundColor(this.courseColor(c)).borderRadius(2)
      Column({ space: 2 }) {
        Text(c.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${timeRangeText(c.startTime, c.endTime)} · ${c.location === '' ? '地点待补充' : c.location} · ${c.teacher === '' ? '教师待补充' : c.teacher}`)
          .fontSize(11).fontColor($r('app.color.text_sub'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.text_hint')])
    }
    .width('100%').padding(10).backgroundColor($r('app.color.card_bg')).borderRadius(10)
    .onClick(() => this.openDetail(c.id))
  }

  @Builder
  selectedDayPanel() {
    Column({ space: 8 }) {
      Row() {
        Text(`${this.selectedDate} ${weekdayName(this.weekdayOfDate(this.selectedDate))}`)
          .fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Text('收起').fontSize(12).fontColor($r('app.color.text_sub'))
          .onClick(() => this.selectedDate = '')
      }.width('100%')
      if (this.dateCourses(this.selectedDate).length === 0) {
        Text('当天没有课程').fontSize(12).fontColor($r('app.color.text_sub')).width('100%').padding({ top: 6 })
      } else {
        ForEach(this.dateCourses(this.selectedDate), (c: CourseItem) => {
          this.dayCourseRow(c)
        }, (c: CourseItem) => courseRenderKey(c))
      }
    }
    .width('100%').padding(12).margin({ top: 10 })
    .backgroundColor($r('app.color.field_bg')).borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Text('课程表').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          .margin({ left: 14 })
        Blank()
        Text('导出').fontSize(12).fontColor($r('app.color.primary'))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.primary_weak')).borderRadius(12)
          .onClick(() => this.exportTimetableImage())
        Text('导入').fontSize(12).fontColor($r('app.color.primary'))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.primary_weak')).borderRadius(12).margin({ left: 6 })
          .onClick(() => this.pickImportFile())
        Text('主题').fontSize(12).fontColor($r('app.color.primary'))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.primary_weak')).borderRadius(12).margin({ left: 6 })
          .onClick(() => this.openTheme())
        Text('同步').fontSize(12).fontColor($r('app.color.primary'))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.primary_weak')).borderRadius(12).margin({ left: 6, right: 14 })
          .onClick(() => this.openSync())
      }.width('100%').height(60).padding({ left: 16 })

      if (this.courseTable.length === 0) {
        // 空课表引导
        Column({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.inbox')).fontSize(56).fontColor([$r('app.color.text_hint')])
          Text('导入课表文件，查看你的课程安排').fontSize(15).fontColor($r('app.color.text_sub'))
          Text('支持 .ics 与 .xlsx；xlsx 需含「课程名称 / 星期 / 开始时间」表头').fontSize(11).fontColor($r('app.color.text_hint'))
          Button('导入课表').fontSize(14).height(40).backgroundColor('#3F7EF6').margin({ top: 8 })
            .onClick(() => this.pickImportFile())
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        // 视图切换 + 翻页
        Row({ space: 8 }) {
          Row() {
            Text('本周课表').fontSize(12).fontWeight(FontWeight.Medium)
              .fontColor(this.viewMode === 'week' ? Color.White : $r('app.color.text_sub'))
              .backgroundColor(this.viewMode === 'week' ? '#3F7EF6' : Color.Transparent)
              .borderRadius(11).padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .onClick(() => this.viewMode = 'week')
            Text('本月视图').fontSize(12).fontWeight(FontWeight.Medium)
              .fontColor(this.viewMode === 'month' ? Color.White : $r('app.color.text_sub'))
              .backgroundColor(this.viewMode === 'month' ? '#3F7EF6' : Color.Transparent)
              .borderRadius(11).padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .onClick(() => this.viewMode = 'month')
          }.padding(2).backgroundColor($r('app.color.field_bg')).borderRadius(13)
          Blank()
          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(16).fontColor([$r('app.color.text_sub')])
              .onClick(() => {
                if (this.viewMode === 'week') {
                  this.weekOffset--
                } else {
                  this.monthOffset--
                  this.selectedDate = ''
                }
              })
            Text(this.viewMode === 'week' ? this.weekTitle() : this.monthTitle())
              .fontSize(12).fontColor($r('app.color.text_main')).width(108).textAlign(TextAlign.Center)
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([$r('app.color.text_sub')])
              .onClick(() => {
                if (this.viewMode === 'week') {
                  this.weekOffset++
                } else {
                  this.monthOffset++
                  this.selectedDate = ''
                }
              })
          }
        }.width('90%').margin({ bottom: 8 })

        if (this.viewMode === 'week') {
          Scroll() {
            Column() {
              this.weekTable()
            }.width('100%').alignItems(HorizontalAlign.Center).padding({ left: 10, right: 10, bottom: 20 })
          }
          .layoutWeight(1).width('100%').scrollBar(BarState.Off)
          .align(Alignment.Top)
        } else {
          Scroll() {
            Column({ space: 6 }) {
              Row() {
                ForEach(['一', '二', '三', '四', '五', '六', '日'], (w: string) => {
                  Text(`周${w}`).fontSize(11).fontColor($r('app.color.text_sub')).layoutWeight(1).textAlign(TextAlign.Center)
                }, (w: string) => w)
              }.width('100%').margin({ top: 2, bottom: 2 })
              this.monthGrid()
              if (this.selectedDate !== '') {
                this.selectedDayPanel()
              }
            }.width('92%').padding({ bottom: 24 })
          }
          .layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top)
        }
      }
    }
    .width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }
}
