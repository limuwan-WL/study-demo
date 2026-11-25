import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import {
  TaskItem,
  SigninMode,
  SigninEntry,
  signinModeName,
  signinStatusName,
  statusName,
  statusColor,
  effectiveStatus,
  remainText,
  fmtClock,
  fmtDateTime,
  countSigned,
  countLeave,
  countAbsent,
  newSigninTask,
  launchTask,
  endTask,
  notifyTask,
  awardPoints,
  signinCsvRows,
  latestActiveTaskOfType,
  autoPublishDue,
  findTask
} from '../../model/InteractionModel'
import { CsvExport } from '../../utils/CsvExport'
import { TaskReminder, ReminderResult } from '../../utils/CourseReminder'
import { GeoHelper, GeoResult, DEFAULT_SIGNIN_LAT, DEFAULT_SIGNIN_LNG } from '../../utils/GeoHelper'
import { DateTimeDialog } from '../../components/TaskDialogs'

// ==================== 课堂签到 ====================
// 🌟 教师：位置 / 验证码 / 图案三种方式发起签到，台账支持补签、请假与 CSV 导出
// 🌟 学生：按教师设定的方式签到
// ⚠️ 位置签到使用系统定位（LocationKit）；未授权/定位失败时回退演示距离并在界面标注；导出为 Excel 兼容 CSV
@Entry
@Component
export struct SigninPage {
  @StorageLink('interactionTasks') tasks: TaskItem[] = []
  @StorageLink('userRole') userRole: string = 'student'
  @StorageLink('nickname') nickname: string = '张同学'
  @State taskId: string = ''
  @State now: number = Date.now()
  @State showCreate: boolean = false
  @State filter: string = 'all'

  // 创建表单
  @State title: string = '课堂签到'
  @State mode: SigninMode = 'location'
  @State radius: number = 100
  @State virtualCheck: boolean = true
  @State validMinutes: number = 30
  @State allowMakeup: boolean = true
  @State pattern: number[] = []
  @State schedule: boolean = false
  @State publishAt: number = 0

  // 学生签到
  @State codeInput: string = ''
  @State signPattern: number[] = []
  // 演示距离（真实定位不可用时的回退，界面上明确标注为演示数据）
  @State mockDistance: number = 42
  @State mockFakeLocation: boolean = false
  // 🌟 真实定位：教师签到点与学生当前位置
  @State createLat: number = 0
  @State createLng: number = 0
  @State pickingPoint: boolean = false
  @State realDistance: number = -1
  @State locating: boolean = false
  @State locationHint: string = ''
  private timer: number = -1

  publishController: CustomDialogController = new CustomDialogController({
    builder: DateTimeDialog({
      title: '设置签到发起时间',
      initial: Date.now() + 10 * 60000,
      onConfirm: (ts: number) => {
        this.publishAt = ts
      }
    }),
    customStyle: true
  })

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, string>
    let wantCreate = params !== undefined && params['create'] === '1'
    let wantId = params !== undefined && params['taskId'] !== undefined ? params['taskId'] : ''
    if (wantId !== '') {
      this.taskId = wantId
    }
    if (this.taskId === '') {
      let latest = latestActiveTaskOfType(this.tasks, 'signin', Date.now())
      if (latest !== undefined) {
        this.taskId = latest.id
      }
    }
    if (wantCreate || (this.taskId === '' && this.canManage())) {
      this.showCreate = true
    }
    this.now = Date.now()
    this.timer = setInterval(() => {
      this.now = Date.now()
      if (autoPublishDue(this.tasks, this.now)) {
        this.tasks = this.tasks.slice()
      }
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

  current(): TaskItem | undefined {
    return findTask(this.tasks, this.taskId)
  }

  signinTasks(): TaskItem[] {
    return this.tasks.filter((t: TaskItem) => t.type === 'signin')
  }

  statusOf(t: TaskItem): string {
    return effectiveStatus(t, this.now)
  }

  // ---------------- 创建签到 ----------------
  togglePattern(i: number): void {
    if (this.pattern.includes(i)) {
      this.pattern = this.pattern.filter((p: number) => p !== i)
    } else {
      this.pattern = this.pattern.concat([i])
    }
  }

  // ---------------- 真实定位 ----------------
  async pickSigninPoint(): Promise<void> {
    this.pickingPoint = true
    let ctx = getContext(this) as common.UIAbilityContext
    let g: GeoResult = await GeoHelper.locate(ctx)
    this.pickingPoint = false
    if (!g.ok) {
      promptAction.showToast({ message: g.message })
      return
    }
    this.createLat = g.lat
    this.createLng = g.lng
    promptAction.showToast({ message: '已获取当前位置作为签到点' })
  }

  async locateMe(t: TaskItem): Promise<void> {
    this.locating = true
    this.locationHint = '正在获取定位…'
    let ctx = getContext(this) as common.UIAbilityContext
    let g: GeoResult = await GeoHelper.locate(ctx)
    this.locating = false
    if (!g.ok) {
      this.realDistance = -1
      this.locationHint = g.message
      return
    }
    if (t.signinLat === 0 && t.signinLng === 0) {
      this.realDistance = -1
      this.locationHint = '教师未设置签到点坐标，无法计算真实距离；可继续使用演示距离'
      return
    }
    this.realDistance = GeoHelper.distanceMeters(g.lat, g.lng, t.signinLat, t.signinLng)
    this.locationHint = `已获取真实定位：距签到点 ${this.realDistance} 米`
  }

  createSignin(): void {
    let name = this.title.trim() === '' ? '课堂签到' : this.title.trim()
    if (this.mode === 'pattern' && this.pattern.length < 4) {
      promptAction.showToast({ message: '图案签到请至少连接 4 个点' })
      return
    }
    let lat = this.mode === 'location' ? this.createLat : 0
    let lng = this.mode === 'location' ? this.createLng : 0
    let usingDemo = false
    if (this.mode === 'location' && lat === 0 && lng === 0) {
      // 未获取真实坐标时退回演示坐标，界面上会标注，避免签到时无法计算距离
      lat = DEFAULT_SIGNIN_LAT
      lng = DEFAULT_SIGNIN_LNG
      usingDemo = true
    }
    let t = newSigninTask(name, this.mode, this.radius, this.virtualCheck, this.validMinutes, this.allowMakeup, lat, lng)
    if (this.mode === 'pattern') {
      t.pattern = this.pattern.slice()
      t.patternUsed = false
    }
    if (this.schedule) {
      if (this.publishAt <= Date.now()) {
        promptAction.showToast({ message: '请选择未来的发起时间' })
        return
      }
      // 🌟 定时发布：先置为待发布，到点由任务页/签到页本地计时自动发起
      t.status = 'pending'
      t.publishAt = this.publishAt
      t.endAt = 0
      t.codeExpireAt = 0
      t.code = ''
    }
    this.tasks = [t].concat(this.tasks)
    this.taskId = t.id
    this.showCreate = false
    this.pattern = []
    if (this.schedule) {
      notifyTask(t, `${name} 将于 ${fmtDateTime(t.publishAt)} 发起签到，请提前进入课程准备`, false, '签到提醒')
      // 🌟 同步设置系统后台提醒，退到后台也能按时发起
      TaskReminder.schedule(t.id, '课堂签到定时发起', `${name} 将于 ${fmtDateTime(t.publishAt)} 发起签到`, t.publishAt)
        .then((r: ReminderResult) => {
          promptAction.showToast({ message: `已设置定时发起 · ${r.message}` })
        })
    } else {
      notifyTask(t, `【课堂签到】${name} 已发起（${signinModeName(this.mode)}），有效 ${this.validMinutes} 分钟，请同学们及时签到。`,
        true, '签到提醒')
      promptAction.showToast({ message: usingDemo ? '签到已发起（签到点为演示坐标）' : '签到已发起，已同步班级群本地通知' })
    }
  }

  // ---------------- 教师操作 ----------------
  refreshCode(t: TaskItem): void {
    t.code = String(Math.floor(1000 + Math.random() * 9000))
    let until = Date.now() + t.validMinutes * 60000
    t.codeExpireAt = t.endAt > 0 && t.endAt < until ? t.endAt : until
    this.tasks = this.tasks.slice()
    promptAction.showToast({ message: `验证码已刷新：${t.code}` })
  }

  redrawPattern(t: TaskItem): void {
    this.pattern = []
    t.pattern = []
    t.patternUsed = false
    this.tasks = this.tasks.slice()
    promptAction.showToast({ message: '请重新绘制签到图案' })
  }

  confirmRedraw(t: TaskItem): void {
    if (this.pattern.length < 4) {
      promptAction.showToast({ message: '请至少连接 4 个点' })
      return
    }
    t.pattern = this.pattern.slice()
    t.patternUsed = false
    this.tasks = this.tasks.slice()
    this.pattern = []
    promptAction.showToast({ message: '签到图案已更新' })
  }

  endSignin(t: TaskItem): void {
    AlertDialog.show({
      title: '结束签到',
      message: '结束后学生将无法继续签到，台账仍可查看与导出。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '结束', fontColor: '#F59E0B', action: () => {
          endTask(t)
          this.tasks = this.tasks.slice()
          TaskReminder.cancel(t.id)
          notifyTask(t, `【课堂签到】${t.title} 已结束。`, true, '签到提醒')
          promptAction.showToast({ message: '签到已结束' })
        }
      }
    })
  }

  markMakeup(t: TaskItem, e: SigninEntry): void {
    if (!t.allowMakeup) {
      promptAction.showToast({ message: '本次签到未开启手动补签' })
      return
    }
    e.status = 'makeup'
    e.time = Date.now()
    e.method = '教师补签'
    e.note = '教师手动补签'
    this.tasks = this.tasks.slice()
    promptAction.showToast({ message: `已为 ${e.student} 补签` })
  }

  markLeave(t: TaskItem, e: SigninEntry): void {
    e.status = 'leave'
    e.time = 0
    e.method = ''
    e.note = '教师标记请假'
    this.tasks = this.tasks.slice()
    promptAction.showToast({ message: `已标记 ${e.student} 请假` })
  }

  cancelLeave(t: TaskItem, e: SigninEntry): void {
    e.status = 'absent'
    e.note = ''
    this.tasks = this.tasks.slice()
    promptAction.showToast({ message: '已取消请假标记' })
  }

  exportLedger(t: TaskItem): void {
    try {
      let ctx = getContext(this) as common.UIAbilityContext
      let path = CsvExport.write(ctx, `signin_${t.id}.csv`, signinCsvRows(t))
      AlertDialog.show({
        title: '导出完成（CSV）',
        message: `已生成 Excel 兼容的 CSV 文件：\n${path}\n\n端上不生成真正的 .xlsx，请用 Excel / WPS 直接打开该 CSV（UTF-8 带 BOM，中文不乱码）。`,
        confirm: { value: '知道了', action: () => {} }
      })
    } catch (e) {
      promptAction.showToast({ message: '导出失败，请稍后重试' })
    }
  }

  visibleEntries(t: TaskItem): SigninEntry[] {
    if (this.filter === 'signed') {
      return t.signinEntries.filter((e: SigninEntry) => e.status === 'signed' || e.status === 'makeup')
    }
    if (this.filter === 'absent') {
      return t.signinEntries.filter((e: SigninEntry) => e.status === 'absent')
    }
    if (this.filter === 'leave') {
      return t.signinEntries.filter((e: SigninEntry) => e.status === 'leave')
    }
    return t.signinEntries
  }

  // ---------------- 学生签到 ----------------
  myEntry(t: TaskItem): SigninEntry | undefined {
    let hit = t.signinEntries.filter((e: SigninEntry) => e.student === this.nickname)
    return hit.length > 0 ? hit[0] : undefined
  }

  isMySigned(t: TaskItem): boolean {
    let e = this.myEntry(t)
    return e !== undefined && (e.status === 'signed' || e.status === 'makeup')
  }

  myStatusName(t: TaskItem): string {
    let e = this.myEntry(t)
    return e === undefined ? '未签到' : signinStatusName(e.status)
  }

  mySignTime(t: TaskItem): number {
    let e = this.myEntry(t)
    return e === undefined ? 0 : e.time
  }

  doSignin(t: TaskItem, method: string): void {
    let now = Date.now()
    if (effectiveStatus(t, now) !== 'ongoing') {
      promptAction.showToast({ message: '签到已结束，无法继续签到' })
      return
    }
    let e = this.myEntry(t)
    if (e !== undefined && (e.status === 'signed' || e.status === 'makeup')) {
      promptAction.showToast({ message: '你已签到，无需重复签到' })
      return
    }
    e = e === undefined ? new SigninEntry(this.nickname) : e
    e.status = 'signed'
    e.time = now
    e.method = method
    e.note = ''
    if (t.signinEntries.filter((x: SigninEntry) => x.student === this.nickname).length === 0) {
      t.signinEntries = t.signinEntries.concat([e])
    }
    if (t.signinMode === 'pattern') {
      t.patternUsed = true
      this.signPattern = []
    }
    this.tasks = this.tasks.slice()
    let gain = awardPoints('signin', this.nickname)
    promptAction.showToast({ message: gain > 0 ? `签到成功，获得 ${gain} 学分` : '签到成功' })
  }

  submitCode(t: TaskItem): void {
    if (t.codeExpireAt > 0 && Date.now() > t.codeExpireAt) {
      promptAction.showToast({ message: '验证码已过期，请让教师刷新' })
      return
    }
    if (this.codeInput.trim() !== t.code) {
      promptAction.showToast({ message: '验证码不正确' })
      return
    }
    this.doSignin(t, '验证码')
    this.codeInput = ''
  }

  submitLocation(t: TaskItem): void {
    // 🌟 优先使用真实定位距离；未获取到定位时回退演示距离，并在提示中说明
    let real = this.realDistance >= 0
    let dist = real ? this.realDistance : this.mockDistance
    if (dist > t.radius) {
      promptAction.showToast({ message: `${real ? '当前' : '演示'}距离 ${dist} 米，超出 ${t.radius} 米签到半径` })
      return
    }
    if (t.virtualCheck && this.mockFakeLocation) {
      promptAction.showToast({ message: '虚拟定位校验未通过，请关闭模拟定位后重试' })
      return
    }
    this.doSignin(t, '位置')
  }

  submitPattern(t: TaskItem): void {
    if (t.patternUsed) {
      promptAction.showToast({ message: '本次图案已被使用，请等待教师重新绘制' })
      return
    }
    if (this.signPattern.length !== t.pattern.length) {
      promptAction.showToast({ message: '图案不正确，请按教师绘制的顺序连接' })
      return
    }
    for (let i = 0; i < t.pattern.length; i++) {
      if (t.pattern[i] !== this.signPattern[i]) {
        promptAction.showToast({ message: '图案不正确，请重试' })
        return
      }
    }
    this.doSignin(t, '图案')
  }

  // ---------------- 通用视图 ----------------
  @Builder
  header() {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(20).fontColor([$r('app.color.text_main')])
        .onClick(() => router.back())
      Column({ space: 2 }) {
        Text('课堂签到').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Text(`数据结构与算法 · ${this.userRole === 'assistant' ? '助教' : this.userRole === 'teacher' ? '授课教师' : '学生'}视角`)
          .fontSize(11).fontColor($r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (this.canManage() && !this.showCreate) {
        Text('+ 发起签到')
          .fontSize(12).fontWeight(FontWeight.Medium).fontColor(Color.White)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor($r('app.color.primary')).borderRadius(16)
          .onClick(() => {
            this.title = '课堂签到'
            this.pattern = []
            this.showCreate = true
          })
      }
    }
    .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 10 })
  }

  @Builder
  modeChip(m: SigninMode) {
    Text(signinModeName(m))
      .fontSize(13)
      .fontColor(this.mode === m ? Color.White : $r('app.color.text_main'))
      .backgroundColor(this.mode === m ? '#3F7EF6' : $r('app.color.field_bg'))
      .padding({ left: 14, right: 14, top: 7, bottom: 7 }).borderRadius(16)
      .onClick(() => {
        this.mode = m
      })
  }

  // 🌟 教师端图案绘制：直接读写 this.pattern，避免 @Builder 按值传参导致点击后圆点不刷新
  @Builder
  teacherPatternGrid() {
    Grid() {
      ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8], (i: number) => {
        GridItem() {
          Stack() {
            Circle()
              .width(46).height(46)
              .fill(this.pattern.includes(i) ? '#3F7EF6' : $r('app.color.field_bg'))
            if (this.pattern.includes(i)) {
              // 显示连接顺序，教师能直观看到已绘制的轨迹
              Text(`${this.pattern.indexOf(i) + 1}`)
                .fontSize(13).fontWeight(FontWeight.Bold).fontColor(Color.White)
            }
          }
          .onClick(() => this.togglePattern(i))
        }
      }, (i: number) => `teacher_dot_${i}_${this.pattern.includes(i) ? this.pattern.indexOf(i) + 1 : 0}`)
    }
    .columnsTemplate('1fr 1fr 1fr').columnsGap(16).rowsGap(16)
    .width(170).height(170)
  }

  // 🌟 学生端图案绘制：直接读写 this.signPattern，保证点亮与顺序实时刷新
  @Builder
  studentPatternGrid() {
    Grid() {
      ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8], (i: number) => {
        GridItem() {
          Stack() {
            Circle()
              .width(46).height(46)
              .fill(this.signPattern.includes(i) ? '#3F7EF6' : $r('app.color.field_bg'))
            if (this.signPattern.includes(i)) {
              Text(`${this.signPattern.indexOf(i) + 1}`)
                .fontSize(13).fontWeight(FontWeight.Bold).fontColor(Color.White)
            }
          }
          .onClick(() => {
            if (!this.signPattern.includes(i)) {
              this.signPattern = this.signPattern.concat([i])
            }
          })
        }
      }, (i: number) => `student_dot_${i}_${this.signPattern.includes(i) ? this.signPattern.indexOf(i) + 1 : 0}`)
    }
    .columnsTemplate('1fr 1fr 1fr').columnsGap(16).rowsGap(16)
    .width(170).height(170)
  }

  @Builder
  createView() {
    Scroll() {
      Column({ space: 14 }) {
        Text('发起签到').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).width('100%')
        TextInput({ text: this.title, placeholder: '签到标题' })
          .height(42).fontSize(14).backgroundColor($r('app.color.field_bg')).borderRadius(12)
          .padding({ left: 12, right: 12 })
          .onChange((v: string) => {
            this.title = v
          })

        Text('签到方式').fontSize(12).fontColor($r('app.color.text_hint')).width('100%')
        Row({ space: 8 }) {
          this.modeChip('location')
          this.modeChip('code')
          this.modeChip('pattern')
        }.width('100%')

        if (this.mode === 'location') {
          Row() {
            Text('签到半径').fontSize(14).fontColor($r('app.color.text_main')).layoutWeight(1)
            Text(`${this.radius} 米`).fontSize(14).fontColor('#3F7EF6')
          }.width('100%')
          Slider({ value: this.radius, min: 50, max: 1000, step: 50 })
            .selectedColor('#3F7EF6')
            .onChange((v: number) => {
              this.radius = v
            })
          // 🌟 真实定位签到点：发起前获取教师当前位置
          Row({ space: 10 }) {
            Column({ space: 2 }) {
              Text('签到点').fontSize(14).fontColor($r('app.color.text_main'))
              Text(this.createLat === 0 && this.createLng === 0
                ? '未获取，将使用演示坐标（上海人民广场）'
                : `已获取 ${this.createLat.toFixed(5)}, ${this.createLng.toFixed(5)}`)
                .fontSize(10).fontColor($r('app.color.text_hint'))
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Button(this.pickingPoint ? '定位中…' : '获取当前位置')
              .fontSize(11).height(30).padding({ left: 10, right: 10 })
              .backgroundColor($r('app.color.primary_weak')).fontColor($r('app.color.primary'))
              .enabled(!this.pickingPoint)
              .onClick(() => this.pickSigninPoint())
          }.width('100%')
          Row() {
            Column({ space: 2 }) {
              Text('虚拟定位校验').fontSize(14).fontColor($r('app.color.text_main'))
              Text('开启后做模拟定位开关自检（系统接口无法可靠识别第三方模拟定位）').fontSize(10).fontColor($r('app.color.text_hint'))
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.virtualCheck })
              .selectedColor('#3F7EF6')
              .onChange((v: boolean) => {
                this.virtualCheck = v
              })
          }.width('100%')
        } else if (this.mode === 'code') {
          Text('发起后自动生成 4 位数字验证码，可在签到进行中手动刷新；验证码有效期与签到有效时长一致。')
            .fontSize(12).fontColor($r('app.color.text_sub')).width('100%').lineHeight(19)
        } else {
          Text('按顺序连接至少 4 个点作为签到图案，单次签到使用一次后即失效。')
            .fontSize(12).fontColor($r('app.color.text_sub')).width('100%')
          this.teacherPatternGrid()
          Row({ space: 10 }) {
            Text(`已连接 ${this.pattern.length} 个点`).fontSize(12).fontColor($r('app.color.text_hint'))
            Text('清除').fontSize(12).fontColor('#EF4444')
              .onClick(() => {
                this.pattern = []
              })
          }.width('100%')
        }

        Row() {
          Text('有效时长').fontSize(14).fontColor($r('app.color.text_main')).layoutWeight(1)
          Text(`${this.validMinutes} 分钟`).fontSize(14).fontColor('#3F7EF6')
        }.width('100%')
        Slider({ value: this.validMinutes, min: 5, max: 120, step: 5 })
          .selectedColor('#3F7EF6')
          .onChange((v: number) => {
            this.validMinutes = v
          })
        Text('超过有效时长自动关闭，学生无法继续签到').fontSize(10).fontColor($r('app.color.text_hint')).width('100%')

        Row() {
          Text('允许教师手动补签').fontSize(14).fontColor($r('app.color.text_main')).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.allowMakeup })
            .selectedColor('#3F7EF6')
            .onChange((v: boolean) => {
              this.allowMakeup = v
            })
        }.width('100%')

        Row() {
          Column({ space: 2 }) {
            Text('定时发起').fontSize(14).fontColor($r('app.color.text_main'))
            Text('到点自动发起（本地计时，无后端调度）').fontSize(10).fontColor($r('app.color.text_hint'))
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.schedule })
            .selectedColor('#3F7EF6')
            .onChange((v: boolean) => {
              this.schedule = v
              if (v && this.publishAt === 0) {
                this.publishAt = Date.now() + 10 * 60000
              }
            })
        }.width('100%')
        if (this.schedule) {
          Row() {
            Text(`发起时间：${fmtDateTime(this.publishAt)}`).fontSize(13).fontColor('#3F7EF6').layoutWeight(1)
            Text('选择时间')
              .fontSize(12).fontColor('#3F7EF6')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .border({ width: 1, color: '#3F7EF6' }).borderRadius(12)
              .onClick(() => this.publishController.open())
          }.width('100%')
        }

        Text('位置签到使用系统定位计算与签到点的距离；未授权定位时回退为演示距离并在签到页标注。')
          .fontSize(11).fontColor($r('app.color.text_hint')).width('100%')

        Row({ space: 10 }) {
          Text('取消')
            .fontSize(15).fontColor($r('app.color.text_sub'))
            .layoutWeight(1).height(44).textAlign(TextAlign.Center)
            .backgroundColor($r('app.color.field_bg')).borderRadius(22)
            .onClick(() => {
              this.showCreate = false
            })
          Text('发起签到')
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
            .layoutWeight(2).height(44).textAlign(TextAlign.Center)
            .backgroundColor($r('app.color.primary')).borderRadius(22)
            .onClick(() => this.createSignin())
        }.width('100%')
      }
      .width('92%').padding(16).backgroundColor($r('app.color.card_bg')).borderRadius(16)
      .alignItems(HorizontalAlign.Start).margin({ top: 6, bottom: 20 })
    }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
  }

  @Builder
  statBox(label: string, value: number, color: string) {
    Column({ space: 2 }) {
      Text(`${value}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor(color)
      Text(label).fontSize(11).fontColor($r('app.color.text_sub'))
    }
    .layoutWeight(1).padding(10).backgroundColor($r('app.color.card_bg')).borderRadius(10)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  taskHeader(t: TaskItem) {
    Column({ space: 10 }) {
      Row() {
        Text(t.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).layoutWeight(1)
        Text(statusName(effectiveStatus(t, this.now)))
          .fontSize(11).fontColor(Color.White)
          .backgroundColor(statusColor(effectiveStatus(t, this.now)))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(10)
      }.width('100%')
      Row({ space: 10 }) {
        Text(`方式：${signinModeName(t.signinMode)}`).fontSize(12).fontColor($r('app.color.text_sub'))
        if (effectiveStatus(t, this.now) === 'pending') {
          Text(t.publishAt > 0 ? `将于 ${fmtDateTime(t.publishAt)} 自动发起` : '待发布')
            .fontSize(12).fontColor('#F59E0B')
        } else {
          Text(`截止：${fmtDateTime(t.endAt) === '' ? '不限时' : fmtDateTime(t.endAt)}`)
            .fontSize(12).fontColor($r('app.color.text_sub'))
        }
      }.width('100%')
      if (effectiveStatus(t, this.now) !== 'pending') {
        Row({ space: 8 }) {
          Text(remainText(t.endAt, this.now))
            .fontSize(12).fontColor(t.endAt > 0 && t.endAt <= this.now ? '#EF4444' : '#10B981')
          if (t.signinMode === 'location') {
            Text(`半径 ${t.radius} 米 · ${t.signinLat === 0 && t.signinLng === 0 ? '签到点未设置（演示坐标）' : '签到点已设置'}`)
              .fontSize(12).fontColor($r('app.color.text_hint'))
          }
        }.width('100%')
      }

      if (this.canManage() && effectiveStatus(t, this.now) === 'pending') {
        Row({ space: 8 }) {
          Text('立即发起')
            .fontSize(12).fontColor(Color.White)
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .backgroundColor($r('app.color.primary')).borderRadius(14)
            .onClick(() => {
              launchTask(t)
              this.tasks = this.tasks.slice()
              TaskReminder.cancel(t.id)
              notifyTask(t, `【课堂签到】${t.title} 已发起，请同学们及时签到。`, true, '签到提醒')
              promptAction.showToast({ message: '签到已发起' })
            })
          Text('取消定时')
            .fontSize(12).fontColor('#EF4444')
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .border({ width: 1, color: '#EF4444' }).borderRadius(14)
            .onClick(() => {
              this.tasks = this.tasks.filter((x: TaskItem) => x.id !== t.id)
              this.taskId = ''
              TaskReminder.cancel(t.id)
              promptAction.showToast({ message: '已取消定时签到' })
            })
        }.width('100%')
      }

      if (this.canManage() && effectiveStatus(t, this.now) !== 'pending') {
        if (t.signinMode === 'code') {
          Row({ space: 10 }) {
            Column({ space: 2 }) {
              Text('当前验证码').fontSize(11).fontColor($r('app.color.text_hint'))
              Text(t.code).fontSize(26).fontWeight(FontWeight.Bold).fontColor('#3F7EF6')
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('刷新验证码')
              .fontSize(12).fontColor(Color.White)
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .backgroundColor($r('app.color.primary')).borderRadius(14)
              .onClick(() => this.refreshCode(t))
          }.width('100%')
          Text(`验证码有效期至 ${fmtClock(t.codeExpireAt)}`)
            .fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
          Text('刷新仅更换验证码，不会延长签到有效时长')
            .fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
        } else if (t.signinMode === 'pattern') {
          Row({ space: 12 }) {
            Column({ space: 2 }) {
              Text(t.patternUsed ? '本次图案已使用，需重新绘制' : '当前签到图案')
                .fontSize(11).fontColor(t.patternUsed ? '#EF4444' : $r('app.color.text_hint'))
              Row({ space: 4 }) {
                ForEach(t.pattern, (p: number) => {
                  Text(`${p + 1}`).fontSize(11).fontColor(Color.White)
                    .width(20).height(20).textAlign(TextAlign.Center)
                    .backgroundColor('#3F7EF6').borderRadius(10)
                }, (p: number, i: number) => `${p}_${i}`)
              }
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('重新绘制')
              .fontSize(12).fontColor(Color.White)
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .backgroundColor($r('app.color.primary')).borderRadius(14)
              .onClick(() => this.redrawPattern(t))
          }.width('100%')
          if (t.pattern.length === 0) {
            this.teacherPatternGrid()
            Text('按顺序连接至少 4 个点，绘制完成后点击下方按钮保存')
              .fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
            Text('保存图案')
              .fontSize(13).fontColor(Color.White)
              .height(34).width('100%').textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.primary')).borderRadius(16)
              .onClick(() => this.confirmRedraw(t))
          }
        }

        Row({ space: 8 }) {
          Text('导出签到台账')
            .fontSize(12).fontColor('#3F7EF6')
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .border({ width: 1, color: '#3F7EF6' }).borderRadius(14)
            .onClick(() => this.exportLedger(t))
          Text('结束签到')
            .fontSize(12).fontColor(Color.White)
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .backgroundColor('#F59E0B').borderRadius(14)
            .onClick(() => this.endSignin(t))
        }.width('100%')
      }
    }
    .width('92%').padding(16).backgroundColor($r('app.color.card_bg')).borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ledgerRow(t: TaskItem, e: SigninEntry) {
    Row({ space: 8 }) {
      Column({ space: 3 }) {
        Text(e.student).fontSize(14).fontColor($r('app.color.text_main'))
        Text(e.time > 0 ? `${fmtClock(e.time)} · ${e.method}` : (e.note === '' ? '—' : e.note))
          .fontSize(10).fontColor($r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text(signinStatusName(e.status))
        .fontSize(11)
        .fontColor(e.status === 'signed' || e.status === 'makeup' ? '#10B981'
          : e.status === 'leave' ? '#F59E0B' : '#EF4444')
      if (this.canManage()) {
        if (e.status === 'absent') {
          Text('补签').fontSize(11).fontColor('#3F7EF6').padding({ left: 6, right: 6, top: 3, bottom: 3 })
            .onClick(() => this.markMakeup(t, e))
          Text('请假').fontSize(11).fontColor('#F59E0B').padding({ left: 6, right: 6, top: 3, bottom: 3 })
            .onClick(() => this.markLeave(t, e))
        } else if (e.status === 'leave') {
          Text('取消请假').fontSize(11).fontColor($r('app.color.text_sub')).padding({ left: 6, right: 6, top: 3, bottom: 3 })
            .onClick(() => this.cancelLeave(t, e))
        }
      }
    }
    .width('100%').padding({ top: 9, bottom: 9, left: 12, right: 12 })
  }

  @Builder
  teacherDetail(t: TaskItem) {
    Scroll() {
      Column({ space: 12 }) {
        this.taskHeader(t)
        Row({ space: 8 }) {
          this.statBox('已签到', countSigned(t), '#10B981')
          this.statBox('未签到', countAbsent(t), '#EF4444')
          this.statBox('请假', countLeave(t), '#F59E0B')
        }.width('92%')

        Column({ space: 0 }) {
          Row({ space: 8 }) {
            ForEach(['all', 'signed', 'absent', 'leave'], (f: string) => {
              Text(f === 'all' ? '全部' : f === 'signed' ? '已签到' : f === 'absent' ? '未签到' : '请假')
                .fontSize(12)
                .fontColor(this.filter === f ? Color.White : $r('app.color.text_main'))
                .backgroundColor(this.filter === f ? '#3F7EF6' : $r('app.color.field_bg'))
                .padding({ left: 10, right: 10, top: 5, bottom: 5 }).borderRadius(12)
                .onClick(() => {
                  this.filter = f
                })
            }, (f: string) => f)
            Blank()
          }.width('100%').padding(10)

          Row() {
            Text('姓名').fontSize(12).fontWeight(FontWeight.Bold).layoutWeight(1).fontColor($r('app.color.text_sub'))
            Text('签到状态').fontSize(12).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_sub'))
          }.width('100%').padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.field_bg'))

          ForEach(this.visibleEntries(t), (e: SigninEntry) => {
            this.ledgerRow(t, e)
            Divider().color($r('app.color.divider_color')).margin({ left: 12, right: 12 })
          }, (e: SigninEntry) => `${e.student}_${e.status}_${e.time}`)
        }.width('92%').backgroundColor($r('app.color.card_bg')).borderRadius(14).clip(true)

        Text('台账为准实时本地数据；导出为 Excel 兼容 CSV（非 .xlsx）')
          .fontSize(11).fontColor($r('app.color.text_hint')).width('92%')
        Blank().height(20)
      }.width('100%').padding({ top: 6, bottom: 20 })
    }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
  }

  @Builder
  studentPanel(t: TaskItem) {
    Scroll() {
      Column({ space: 14 }) {
        this.taskHeader(t)
        Column({ space: 12 }) {
          Row() {
            Text('我的签到').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).layoutWeight(1)
            Text(this.myStatusName(t))
              .fontSize(12).fontColor(this.isMySigned(t) ? '#10B981' : '#EF4444')
          }.width('100%')

          if (effectiveStatus(t, this.now) !== 'ongoing') {
            Text(effectiveStatus(t, this.now) === 'pending' ? '签到尚未开始，请等待教师发起' : '该签到已结束，无法继续签到')
              .fontSize(13).fontColor($r('app.color.text_hint')).width('100%')
          } else if (this.isMySigned(t)) {
            Text(`已于 ${fmtClock(this.mySignTime(t))} 完成签到`).fontSize(13).fontColor('#10B981').width('100%')
          } else if (t.signinMode === 'location') {
            // 🌟 真实定位优先：获取成功显示实际距离，失败/未设置签到点回退演示距离并明确标注
            Text(this.realDistance >= 0
              ? `真实定位：距签到点 ${this.realDistance} 米（签到半径 ${t.radius} 米）`
              : `演示距离：${this.mockDistance} 米（签到半径 ${t.radius} 米）`)
              .fontSize(13)
              .fontColor((this.realDistance >= 0 ? this.realDistance : this.mockDistance) <= t.radius ? '#10B981' : '#EF4444')
              .width('100%')
            Text(this.locationHint !== '' ? this.locationHint
              : '点击「获取当前位置」使用系统定位；未获取时按演示距离签到')
              .fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
            Text(this.locating ? '定位中…' : '获取当前位置')
              .fontSize(12).fontColor('#3F7EF6')
              .onClick(() => {
                if (!this.locating) {
                  this.locateMe(t)
                }
              })
            Text('重新模拟定位（仅演示回退）')
              .fontSize(11).fontColor($r('app.color.text_hint'))
              .onClick(() => {
                this.realDistance = -1
                this.mockDistance = Math.floor(10 + Math.random() * 180)
              })
            if (t.virtualCheck) {
              Row() {
                Text('模拟虚拟定位（演示自检）').fontSize(13).fontColor($r('app.color.text_main')).layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.mockFakeLocation })
                  .selectedColor('#F59E0B')
                  .onChange((v: boolean) => {
                    this.mockFakeLocation = v
                  })
              }.width('100%')
            }
            Text('确认签到')
              .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
              .height(44).width('100%').textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.primary')).borderRadius(22)
              .onClick(() => this.submitLocation(t))
          } else if (t.signinMode === 'code') {
            Text(`请输入教师给出的 4 位验证码${t.codeExpireAt > 0 && this.now > t.codeExpireAt ? '（已过期，请联系教师刷新）' : ''}`)
              .fontSize(12).fontColor($r('app.color.text_sub')).width('100%')
            TextInput({ text: this.codeInput, placeholder: '4 位数字验证码' })
              .type(InputType.Number).maxLength(4).height(46).fontSize(18)
              .backgroundColor($r('app.color.field_bg')).borderRadius(12)
              .onChange((v: string) => {
                this.codeInput = v
              })
            Text('确认签到')
              .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
              .height(44).width('100%').textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.primary')).borderRadius(22)
              .onClick(() => this.submitCode(t))
          } else {
            Text(t.patternUsed ? '本次图案签到已被使用，请等待教师重新绘制' : '请按教师绘制的顺序连接图案')
              .fontSize(12).fontColor(t.patternUsed ? '#EF4444' : $r('app.color.text_sub')).width('100%')
            this.studentPatternGrid()
            Row({ space: 20 }) {
              Text(`已连接 ${this.signPattern.length} 个点`).fontSize(12).fontColor($r('app.color.text_hint'))
              Text('重画').fontSize(12).fontColor('#EF4444')
                .onClick(() => {
                  this.signPattern = []
                })
            }
            Text('确认签到')
              .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
              .height(44).width('100%').textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.primary')).borderRadius(22)
              .onClick(() => this.submitPattern(t))
          }
        }
        .width('92%').padding(16).backgroundColor($r('app.color.card_bg')).borderRadius(16)
        .alignItems(HorizontalAlign.Start)
        Blank().height(20)
      }.width('100%').padding({ top: 6 })
    }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
  }

  @Builder
  taskSwitch() {
    if (this.signinTasks().length > 1) {
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.signinTasks(), (t: TaskItem) => {
            Text(t.title)
              .fontSize(12)
              .fontColor(this.taskId === t.id ? Color.White : $r('app.color.text_main'))
              .backgroundColor(this.taskId === t.id ? '#3F7EF6' : $r('app.color.field_bg'))
              .padding({ left: 12, right: 12, top: 6, bottom: 6 }).borderRadius(14)
              .onClick(() => {
                this.taskId = t.id
                this.showCreate = false
              })
          }, (t: TaskItem) => t.id)
        }.padding({ left: 16, right: 16 })
      }.scrollBar(BarState.Off).width('100%').margin({ bottom: 8 })
    }
  }

  build() {
    Column() {
      this.header()
      if (this.showCreate && this.canManage()) {
        this.createView()
      } else if (this.current() === undefined) {
        Column({ space: 10 }) {
          Text(this.canManage() ? '还没有签到任务' : '当前没有进行中的课堂签到')
            .fontSize(14).fontColor($r('app.color.text_sub'))
          if (this.canManage()) {
            Text('发起签到')
              .fontSize(14).fontColor(Color.White)
              .padding({ left: 18, right: 18, top: 9, bottom: 9 })
              .backgroundColor($r('app.color.primary')).borderRadius(20)
              .onClick(() => {
                this.showCreate = true
              })
          }
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        this.taskSwitch()
        if (this.canManage()) {
          this.teacherDetail(this.current()!)
        } else {
          this.studentPanel(this.current()!)
        }
      }
    }
    .width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }
}
