import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import {
  TaskItem,
  TaskStatus,
  TaskType,
  defaultTasks,
  statusName,
  statusColor,
  taskTypeName,
  taskTypeIcon,
  effectiveStatus,
  taskDoneCount,
  fmtDateTime,
  fmtClock,
  remainText,
  launchTask,
  endTask,
  withdrawTask,
  notifyTask,
  autoPublishDue
} from '../../model/InteractionModel'
import { DateTimeDialog } from '../../components/TaskDialogs'
import { TaskReminder, ReminderResult } from '../../utils/CourseReminder'

// ==================== 互动任务管理（教师 / 助教） ====================
// 🌟 任务统一台账：定时发布、提前结束、撤回后学生无法继续作答
@Entry
@Component
export struct TaskPage {
  @StorageLink('interactionTasks') tasks: TaskItem[] = []
  @StorageLink('userRole') userRole: string = 'student'
  @State filter: string = 'all'
  @State now: number = Date.now()
  @State showQuick: boolean = false
  @State scheduleTaskId: string = ''
  private timer: number = -1

  dateController: CustomDialogController = new CustomDialogController({
    builder: DateTimeDialog({
      title: '定时发布',
      initial: Date.now() + 30 * 60000,
      onConfirm: (ts: number) => {
        this.applySchedule(ts)
      }
    }),
    customStyle: true
  })

  aboutToAppear(): void {
    if (this.tasks.length === 0) {
      this.tasks = defaultTasks()
    }
    this.now = Date.now()
    this.timer = setInterval(() => {
      this.now = Date.now()
      this.autoPublish()
    }, 1000)
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer)
    }
  }

  canManage(): boolean {
    return this.userRole === 'teacher' || this.userRole === 'assistant'
  }

  // 🌟 到点的定时任务自动发布（本地计时，无后端调度）
  autoPublish(): void {
    let changed = autoPublishDue(this.tasks, this.now)
    if (changed) {
      this.tasks = this.tasks.slice()
      // 🌟 已发布的任务不再需要后台提醒
      this.tasks.forEach((t: TaskItem) => {
        if (t.status !== 'pending') {
          TaskReminder.cancel(t.id)
        }
      })
    }
  }

  filtered(): TaskItem[] {
    if (this.filter === 'all') {
      return this.tasks
    }
    return this.tasks.filter((t: TaskItem) => t.type === this.filter)
  }

  publish(t: TaskItem): void {
    launchTask(t)
    this.tasks = this.tasks.slice()
    TaskReminder.cancel(t.id)
    notifyTask(t, `【${taskTypeName(t.type)}】${t.title} 已发布，请同学们及时参与。`)
    promptAction.showToast({ message: '任务已发布（已同步班级群本地通知）' })
  }

  openSchedule(t: TaskItem): void {
    this.scheduleTaskId = t.id
    this.dateController.open()
  }

  applySchedule(ts: number): void {
    let t = this.tasks.find((x: TaskItem) => x.id === this.scheduleTaskId)
    if (t === undefined) {
      return
    }
    t.publishAt = ts
    this.tasks = this.tasks.slice()
    // 🌟 同步发布系统后台提醒：应用退到后台也能在设定时间提醒
    TaskReminder.schedule(t.id, '教学任务定时发布', `「${t.title}」将于 ${fmtDateTime(ts)} 自动发布`, ts)
      .then((r: ReminderResult) => {
        promptAction.showToast({ message: `已设为 ${fmtDateTime(ts)} 定时发布 · ${r.message}` })
      })
  }

  endEarly(t: TaskItem): void {
    AlertDialog.show({
      title: '提前结束',
      message: `结束后学生将无法继续参与「${t.title}」，确认结束？`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '提前结束', fontColor: '#F59E0B', action: () => {
          endTask(t)
          this.tasks = this.tasks.slice()
          TaskReminder.cancel(t.id)
          notifyTask(t, `【${taskTypeName(t.type)}】${t.title} 已提前结束。`)
          promptAction.showToast({ message: '任务已提前结束' })
        }
      }
    })
  }

  withdraw(t: TaskItem): void {
    AlertDialog.show({
      title: '撤回任务',
      message: '撤回后学生无法继续作答，已提交的数据会保留在台账中。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '撤回', fontColor: '#EF4444', action: () => {
          withdrawTask(t)
          this.tasks = this.tasks.slice()
          TaskReminder.cancel(t.id)
          notifyTask(t, `【${taskTypeName(t.type)}】${t.title} 已被教师撤回，请停止作答。`)
          promptAction.showToast({ message: '任务已撤回' })
        }
      }
    })
  }

  pageOf(type: TaskType): string {
    if (type === 'signin') {
      return 'pages/study/SigninPage'
    }
    if (type === 'practice') {
      return 'pages/study/PracticePage'
    }
    if (type === 'survey') {
      return 'pages/study/SurveyPage'
    }
    return 'pages/study/RandomPickPage'
  }

  openTask(t: TaskItem): void {
    router.pushUrl({ url: this.pageOf(t.type), params: { taskId: t.id } })
  }

  openData(t: TaskItem): void {
    router.pushUrl({ url: 'pages/study/DataViewPage', params: { taskId: t.id } })
  }

  createTask(type: TaskType): void {
    this.showQuick = false
    router.pushUrl({ url: this.pageOf(type), params: { create: '1' } })
  }

  @Builder
  statChip(label: string, count: number) {
    Column({ space: 2 }) {
      Text(`${count}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      Text(label).fontSize(11).fontColor($r('app.color.text_hint'))
    }
    .layoutWeight(1).padding(8).backgroundColor($r('app.color.card_bg')).borderRadius(8)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  infoLine(t: TaskItem) {
    Column({ space: 3 }) {
      Row({ space: 6 }) {
        Text(`${taskTypeIcon(t.type)} ${taskTypeName(t.type)}`).fontSize(11).fontColor($r('app.color.text_sub'))
        if (t.publishAt > 0 && t.status === 'pending') {
          Text(`定时发布 ${fmtDateTime(t.publishAt)}`).fontSize(11).fontColor('#F59E0B')
        }
        if (t.status === 'withdrawn' && t.withdrawnAt > 0) {
          Text(`撤回于 ${fmtDateTime(t.withdrawnAt)}`).fontSize(11).fontColor('#94A3B8')
        }
      }.width('100%')
      if (t.endAt > 0 && effectiveStatus(t, this.now) !== 'withdrawn') {
        Row({ space: 6 }) {
          Text(`截止 ${fmtDateTime(t.endAt)}`).fontSize(11).fontColor($r('app.color.text_hint'))
          Text(remainText(t.endAt, this.now))
            .fontSize(11)
            .fontColor(t.endAt <= this.now ? '#EF4444' : '#10B981')
        }.width('100%')
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  actionButton(label: string, color: string, onTap: () => void) {
    Text(label)
      .fontSize(12).fontWeight(FontWeight.Medium)
      .fontColor(color === '#94A3B8' ? $r('app.color.text_main') : Color.White)
      .textAlign(TextAlign.Center)
      .layoutWeight(1).height(30)
      .backgroundColor(color)
      .borderRadius(8)
      .margin({ right: 6 })
      .onClick(() => onTap())
  }

  @Builder
  taskCard(t: TaskItem) {
    Column({ space: 8 }) {
      Row() {
        Text(`${taskTypeIcon(t.type)} ${t.title}`).fontSize(14).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_main')).layoutWeight(1)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(statusName(effectiveStatus(t, this.now)))
          .fontSize(11).fontColor(Color.White)
          .backgroundColor(statusColor(effectiveStatus(t, this.now)))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(10)
      }.width('100%')

      this.infoLine(t)

      Row({ space: 6 }) {
        Text(t.type === 'random' ? `抽选 ${t.picks.length} 次` : `参与 ${taskDoneCount(t)}/${t.total} 人`)
          .fontSize(12).fontColor($r('app.color.text_hint'))
        Blank()
        if (t.type !== 'random') {
          Text(`${t.total > 0 ? Math.round(taskDoneCount(t) / t.total * 100) : 0}%`)
            .fontSize(11).fontColor($r('app.color.text_sub'))
        }
      }.width('100%')

      if (t.type !== 'random') {
        Row() {
          Row()
            .width(`${t.total > 0 ? taskDoneCount(t) / t.total * 100 : 0}%`)
            .height(4).backgroundColor('#3F7EF6').borderRadius(2)
        }.width('100%').height(4).backgroundColor($r('app.color.field_bg')).borderRadius(2)
      }

      if (this.canManage()) {
        Row() {
          if (effectiveStatus(t, this.now) === 'pending') {
            this.actionButton('立即发布', '#3F7EF6', (): void => this.publish(t))
            this.actionButton('定时发布', '#F59E0B', (): void => this.openSchedule(t))
            this.actionButton('撤回', '#EF4444', (): void => this.withdraw(t))
          } else if (effectiveStatus(t, this.now) === 'ongoing') {
            this.actionButton('查看数据', '#3F7EF6', (): void => this.openData(t))
            this.actionButton('进入任务', '#10B981', (): void => this.openTask(t))
            this.actionButton('结束', '#F59E0B', (): void => this.endEarly(t))
          } else {
            this.actionButton('查看数据', '#3F7EF6', (): void => this.openData(t))
            this.actionButton('再次发起', '#94A3B8', (): void => this.createTask(t.type))
          }
        }.width('100%').margin({ top: 2 })
      } else {
        Row() {
          this.actionButton('进入任务', '#3F7EF6', (): void => this.openTask(t))
        }.width('100%')
      }
    }
    .width('100%').padding(12).backgroundColor($r('app.color.card_bg')).borderRadius(12)
  }

  @Builder
  quickSheet() {
    Column({ space: 10 }) {
      Text('发起互动任务').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      Text('任务将同步到班级群（本地模拟通知，无真实推送服务）')
        .fontSize(11).fontColor($r('app.color.text_hint')).width('100%')
      ForEach(['signin', 'practice', 'survey', 'random'] as TaskType[], (tp: TaskType) => {
        Row({ space: 12 }) {
          Text(taskTypeIcon(tp)).fontSize(20).width(36).textAlign(TextAlign.Center)
          Column({ space: 2 }) {
            Text(taskTypeName(tp)).fontSize(15).fontColor($r('app.color.text_main'))
            Text(tp === 'signin' ? '位置 / 验证码 / 图案签到' : tp === 'practice' ? '限时或永久开放的随堂练习'
              : tp === 'survey' ? '匿名或实名的调查问卷' : '从指定学生池随机抽选作答')
              .fontSize(11).fontColor($r('app.color.text_hint'))
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.text_hint')])
        }
        .width('100%').padding({ top: 12, bottom: 12, left: 12, right: 12 })
        .backgroundColor($r('app.color.field_bg')).borderRadius(12)
        .onClick(() => this.createTask(tp))
      }, (tp: TaskType) => tp)
    }.width('100%').padding(20).alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20).fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Column({ space: 2 }) {
          Text('互动任务').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Text(`数据结构与算法 · ${this.userRole === 'assistant' ? '助教' : this.userRole === 'teacher' ? '授课教师' : '学生'}视角`)
            .fontSize(11).fontColor($r('app.color.text_hint'))
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        if (this.canManage()) {
          Text('+ 发起')
            .fontSize(13).fontWeight(FontWeight.Medium).fontColor(Color.White)
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .backgroundColor($r('app.color.primary')).borderRadius(16)
            .onClick(() => {
              this.showQuick = true
            })
        }
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 10 })

      Row({ space: 8 }) {
        this.statChip('待发布', this.tasks.filter((t: TaskItem) => effectiveStatus(t, this.now) === 'pending').length)
        this.statChip('进行中', this.tasks.filter((t: TaskItem) => effectiveStatus(t, this.now) === 'ongoing').length)
        this.statChip('已结束', this.tasks.filter((t: TaskItem) => effectiveStatus(t, this.now) === 'ended').length)
        this.statChip('已撤回', this.tasks.filter((t: TaskItem) => effectiveStatus(t, this.now) === 'withdrawn').length)
      }.width('100%').padding({ left: 16, right: 16, bottom: 10 })

      Scroll() {
        Row({ space: 8 }) {
          ForEach(['all', 'signin', 'practice', 'survey', 'random'], (f: string) => {
            Text(f === 'all' ? '全部' : `${taskTypeIcon(f)} ${taskTypeName(f)}`)
              .fontSize(13)
              .fontColor(this.filter === f ? Color.White : $r('app.color.text_main'))
              .backgroundColor(this.filter === f ? '#3F7EF6' : $r('app.color.field_bg'))
              .padding({ left: 12, right: 12, top: 5, bottom: 5 }).borderRadius(14)
              .onClick(() => {
                this.filter = f
              })
          }, (f: string) => f)
        }.padding({ left: 16, right: 16 })
      }.scrollBar(BarState.Off).margin({ bottom: 10 })

      List({ space: 10 }) {
        ForEach(this.filtered(), (t: TaskItem) => {
          ListItem() {
            this.taskCard(t)
          }
        }, (t: TaskItem) => t.id)
        if (this.filtered().length === 0) {
          ListItem() {
            Column({ space: 8 }) {
              Text(this.canManage() ? '暂无任务，点击右上角「+ 发起」创建' : '暂无互动任务')
                .fontSize(13).fontColor($r('app.color.text_hint'))
              Text('本地演示：任务与台账保存在本机，不依赖后端服务')
                .fontSize(11).fontColor($r('app.color.text_hint'))
            }.padding(30)
          }
        }
      }.width('92%').layoutWeight(1).scrollBar(BarState.Off)

      Blank().height(16)
    }
    .width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
    .bindSheet($$this.showQuick, this.quickSheet(), { detents: [SheetSize.MEDIUM], showClose: true })
  }
}
