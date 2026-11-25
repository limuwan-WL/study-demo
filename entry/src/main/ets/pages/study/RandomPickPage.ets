import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import {
  TaskItem,
  PickEntry,
  PickPool,
  PickResolution,
  SigninEntry,
  PracticeSubmission,
  pickPoolName,
  classStudents,
  latestTaskOfType,
  newRandomTask,
  notifyTask,
  effectiveStatus,
  statusName,
  statusColor,
  fmtClock,
  fmtDateTime,
  awardPoints,
  findTask
} from '../../model/InteractionModel'

// ==================== 随机抽选 ====================
// 🌟 抽选池：全部学生 / 未签到学生 / 未提交练习学生（取最近一次签到与练习的真实台账）
// 🌟 抽中后向班级群推送通知（本地模拟），拒绝作答可加备注，记录计入任务台账
// ⚠️ 本地演示：无真实推送服务，通知仅写入本地班级群消息
@Entry
@Component
export struct RandomPickPage {
  @StorageLink('interactionTasks') tasks: TaskItem[] = []
  @StorageLink('userRole') userRole: string = 'student'
  @State pool: PickPool = 'all'
  @State now: number = Date.now()
  @State rolling: boolean = false
  @State display: string = '准备抽选'
  @State currentTaskId: string = ''
  @State showRemark: boolean = false
  @State remarkId: string = ''
  @State remarkText: string = ''
  @State remarkStudent: string = ''
  private rollTimer: number = -1
  private clockTimer: number = -1
  private tick: number = 0

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, string>
    let wantId = params !== undefined && params['taskId'] !== undefined ? params['taskId'] : ''
    if (wantId !== '') {
      this.currentTaskId = wantId
      let t = findTask(this.tasks, wantId)
      if (t !== undefined) {
        this.pool = t.pool
      }
    } else {
      let latest = latestTaskOfType(this.tasks, 'random')
      if (latest !== undefined && effectiveStatus(latest, Date.now()) === 'ongoing') {
        this.currentTaskId = latest.id
        this.pool = latest.pool
      }
    }
    this.now = Date.now()
    this.clockTimer = setInterval(() => {
      this.now = Date.now()
    }, 1000)
  }

  aboutToDisappear(): void {
    if (this.clockTimer >= 0) {
      clearInterval(this.clockTimer)
    }
    if (this.rollTimer >= 0) {
      clearInterval(this.rollTimer)
    }
  }

  canManage(): boolean {
    return this.userRole === 'teacher' || this.userRole === 'assistant'
  }

  current(): TaskItem | undefined {
    return findTask(this.tasks, this.currentTaskId)
  }

  latestSignin(): TaskItem | undefined {
    return latestTaskOfType(this.tasks, 'signin')
  }

  latestPractice(): TaskItem | undefined {
    return latestTaskOfType(this.tasks, 'practice')
  }

  unsignedNames(): string[] {
    let t = this.latestSignin()
    if (t === undefined) {
      return []
    }
    let names: string[] = []
    let task: TaskItem = t
    task.signinEntries.forEach((e: SigninEntry) => {
      if (e.status === 'absent') {
        names.push(e.student)
      }
    })
    return names
  }

  unsubmittedNames(): string[] {
    let t = this.latestPractice()
    if (t === undefined) {
      return []
    }
    let names: string[] = []
    let task: TaskItem = t
    classStudents().forEach((n: string) => {
      let hit = task.submissions.filter((s: PracticeSubmission) => s.student === n)
      if (hit.length === 0) {
        names.push(n)
      }
    })
    return names
  }

  candidates(): string[] {
    if (this.pool === 'unsigned') {
      return this.unsignedNames()
    }
    if (this.pool === 'unsubmitted') {
      return this.unsubmittedNames()
    }
    return classStudents()
  }

  poolTip(): string {
    if (this.pool === 'unsigned') {
      return this.latestSignin() === undefined ? '暂无签到任务，抽选池为空' : '取自最近一次签到的「未签到」名单'
    }
    if (this.pool === 'unsubmitted') {
      return this.latestPractice() === undefined ? '暂无随堂练习，抽选池为空' : '取自最近一次练习的「未提交」名单'
    }
    return '班级全部学生'
  }

  ensureTask(): TaskItem {
    let cur = this.current()
    if (cur !== undefined && effectiveStatus(cur, this.now) === 'ongoing') {
      return cur
    }
    let t = newRandomTask(this.pool)
    this.tasks = [t].concat(this.tasks)
    this.currentTaskId = t.id
    return t
  }

  startPick(): void {
    if (this.rolling) {
      return
    }
    let pool = this.candidates()
    if (pool.length === 0) {
      promptAction.showToast({ message: '抽选池为空，请调整抽选范围' })
      return
    }
    this.rolling = true
    this.tick = 0
    this.rollTimer = setInterval(() => {
      this.tick++
      this.display = pool[this.tick % pool.length]
      if (this.tick >= 18) {
        clearInterval(this.rollTimer)
        this.rollTimer = -1
        this.finishPick(pool)
      }
    }, 70)
  }

  finishPick(pool: string[]): void {
    let t = this.ensureTask()
    let already: string[] = []
    t.picks.forEach((p: PickEntry) => already.push(p.student))
    let rest = pool.filter((n: string) => !already.includes(n))
    if (rest.length === 0) {
      rest = pool
    }
    let name = rest[Math.floor(Math.random() * rest.length)]
    let p = new PickEntry(name)
    p.notified = true
    t.picks = t.picks.concat([p])
    t.total = pool.length
    this.tasks = this.tasks.slice()
    this.display = name
    this.rolling = false
    notifyTask(t, `【随机抽选】请 ${name} 同学准备作答（抽选池：${pickPoolName(this.pool)}）。`)
    promptAction.showToast({ message: `已抽中 ${name}，已推送本地通知` })
  }

  markAnswered(t: TaskItem, p: PickEntry): void {
    p.resolution = 'answered'
    let gain = awardPoints('random', p.student)
    this.tasks = this.tasks.slice()
    promptAction.showToast({ message: gain > 0 ? `已记录 ${p.student} 完成答题，获得 ${gain} 学分` : '已记录完成答题' })
  }

  markRefused(t: TaskItem, p: PickEntry): void {
    this.remarkId = p.id
    this.remarkStudent = p.student
    this.remarkText = p.remark
    this.showRemark = true
  }

  saveRemark(): void {
    let t = this.current()
    if (t === undefined) {
      return
    }
    let hit = t.picks.filter((p: PickEntry) => p.id === this.remarkId)
    if (hit.length > 0) {
      hit[0].resolution = 'refused'
      hit[0].remark = this.remarkText.trim()
      this.tasks = this.tasks.slice()
    }
    this.showRemark = false
    promptAction.showToast({ message: '已记录拒绝作答与备注' })
  }

  notifyAgain(p: PickEntry): void {
    let t = this.current()
    if (t !== undefined) {
      notifyTask(t, `【随机抽选】再次提醒 ${p.student} 同学作答。`)
    }
    promptAction.showToast({ message: '已再次推送本地通知' })
  }

  resolutionName(r: PickResolution): string {
    if (r === 'answered') {
      return '已完成答题'
    }
    if (r === 'refused') {
      return '拒绝作答'
    }
    return '待作答'
  }

  resolutionColor(r: PickResolution): string {
    if (r === 'answered') {
      return '#10B981'
    }
    if (r === 'refused') {
      return '#EF4444'
    }
    return '#F59E0B'
  }

  @Builder
  header() {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(20).fontColor([$r('app.color.text_main')])
        .onClick(() => router.back())
      Column({ space: 2 }) {
        Text('随机抽选').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Text(`数据结构与算法 · ${this.userRole === 'assistant' ? '助教' : this.userRole === 'teacher' ? '授课教师' : '学生'}视角`)
          .fontSize(11).fontColor($r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (this.current() !== undefined) {
        Text('查看台账')
          .fontSize(12).fontColor('#3F7EF6')
          .onClick(() => {
            router.pushUrl({ url: 'pages/study/DataViewPage', params: { taskId: this.currentTaskId } })
          })
      }
    }
    .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 10 })
  }

  @Builder
  poolChip(p: PickPool) {
    Text(pickPoolName(p))
      .fontSize(13)
      .fontColor(this.pool === p ? Color.White : $r('app.color.text_main'))
      .backgroundColor(this.pool === p ? '#3F7EF6' : $r('app.color.field_bg'))
      .padding({ left: 14, right: 14, top: 7, bottom: 7 }).borderRadius(16)
      .onClick(() => {
        if (this.rolling) {
          return
        }
        this.pool = p
        this.display = '准备抽选'
      })
  }

  @Builder
  recordRow(t: TaskItem, p: PickEntry) {
    Row({ space: 8 }) {
      Column({ space: 3 }) {
        Text(p.student).fontSize(14).fontColor($r('app.color.text_main'))
        Text(`${fmtClock(p.pickedAt)} · ${p.notified ? '已通知' : '未通知'}${p.remark === '' ? '' : ` · 备注：${p.remark}`}`)
          .fontSize(10).fontColor($r('app.color.text_hint'))
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text(this.resolutionName(p.resolution))
        .fontSize(11).fontColor(this.resolutionColor(p.resolution))
      if (p.resolution === 'pending') {
        Text('完成').fontSize(11).fontColor('#10B981').padding({ left: 6, right: 6 })
          .onClick(() => this.markAnswered(t, p))
        Text('拒绝').fontSize(11).fontColor('#EF4444').padding({ left: 6, right: 6 })
          .onClick(() => this.markRefused(t, p))
        Text('再通知').fontSize(11).fontColor('#3F7EF6').padding({ left: 6, right: 6 })
          .onClick(() => this.notifyAgain(p))
      }
    }
    .width('100%').padding({ top: 10, bottom: 10, left: 12, right: 12 })
  }

  @Builder
  remarkSheet() {
    Column({ space: 12 }) {
      Text(`拒绝作答备注 · ${this.remarkStudent}`)
        .fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      TextArea({ text: this.remarkText, placeholder: '例如：身体不适，已安排课后补答' })
        .height(100).fontSize(13).backgroundColor($r('app.color.field_bg')).borderRadius(10)
        .onChange((v: string) => {
          this.remarkText = v
        })
      Text('保存备注')
        .fontSize(15).fontColor(Color.White)
        .height(42).width('100%').textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.primary')).borderRadius(21)
        .onClick(() => this.saveRemark())
    }.width('100%').padding(20).alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      this.header()
      if (!this.canManage()) {
        Column({ space: 8 }) {
          Text('随机抽选仅授课教师 / 助教可用').fontSize(14).fontColor($r('app.color.text_sub'))
          Text('抽选结果由教师记录并计入任务台账').fontSize(11).fontColor($r('app.color.text_hint'))
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Column({ space: 12 }) {
              Text('抽选池').fontSize(12).fontColor($r('app.color.text_hint')).width('100%')
              Row({ space: 8 }) {
                this.poolChip('all')
                this.poolChip('unsigned')
                this.poolChip('unsubmitted')
              }.width('100%')
              Text(`${this.poolTip()} · 共 ${this.candidates().length} 人`)
                .fontSize(11).fontColor($r('app.color.text_hint')).width('100%')
              Text(this.candidates().join('、') === '' ? '（空）' : this.candidates().join('、'))
                .fontSize(11).fontColor($r('app.color.text_sub')).width('100%').maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }.width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(14)
            .alignItems(HorizontalAlign.Start)

            Column({ space: 10 }) {
              Text(this.rolling ? '抽选中…' : '本次抽中')
                .fontSize(12).fontColor($r('app.color.text_hint'))
              Text(this.display).fontSize(30).fontWeight(FontWeight.Bold)
                .fontColor(this.rolling ? $r('app.color.text_hint') : '#3F7EF6')
              Text('抽中后自动向班级群推送通知（本地模拟，无真实推送服务）')
                .fontSize(10).fontColor($r('app.color.text_hint')).textAlign(TextAlign.Center)
              Text(this.rolling ? '请稍候' : '开始抽选')
                .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
                .height(44).width('70%').textAlign(TextAlign.Center)
                .backgroundColor(this.rolling ? '#94A3B8' : $r('app.color.primary')).borderRadius(22)
                .onClick(() => this.startPick())
            }.width('92%').padding(20).backgroundColor($r('app.color.card_bg')).borderRadius(16)
            .alignItems(HorizontalAlign.Center)

            Column({ space: 0 }) {
              Row() {
                Text('抽选记录').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).layoutWeight(1)
                if (this.current() !== undefined) {
                  Text(statusName(effectiveStatus(this.current()!, this.now)))
                    .fontSize(11).fontColor(Color.White)
                    .backgroundColor(statusColor(effectiveStatus(this.current()!, this.now)))
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(10)
                }
              }.width('100%').padding(12)
              if (this.current() !== undefined) {
                Text(`创建于 ${fmtDateTime(this.current()!.createdAt)} · 记录计入互动任务台账`)
                  .fontSize(10).fontColor($r('app.color.text_hint')).width('100%').padding({ left: 12, bottom: 6 })
                ForEach(this.current()!.picks, (p: PickEntry) => {
                  this.recordRow(this.current()!, p)
                  Divider().color($r('app.color.divider_color')).margin({ left: 12, right: 12 })
                }, (p: PickEntry) => p.id)
                if (this.current()!.picks.length === 0) {
                  Text('暂无抽选记录').fontSize(12).fontColor($r('app.color.text_hint')).padding(16)
                }
              } else {
                Text('尚未开始抽选').fontSize(12).fontColor($r('app.color.text_hint')).padding(16)
              }
            }.width('92%').backgroundColor($r('app.color.card_bg')).borderRadius(14).clip(true)
            .alignItems(HorizontalAlign.Start)

            Text('说明：抽选与通知为本地模拟，未接入真实推送；学分在标记「完成答题」后计入。')
              .fontSize(11).fontColor($r('app.color.text_hint')).width('92%')
            Blank().height(30)
          }.width('100%').padding({ top: 4 })
        }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
    .bindSheet($$this.showRemark, this.remarkSheet(), { detents: [SheetSize.MEDIUM], showClose: true })
  }
}
