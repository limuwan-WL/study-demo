import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { PracticeQuestion, QType } from '../../model/DataModel'
import {
  TaskItem,
  PracticeSubmission,
  AnalysisTiming,
  PracticeMode,
  findTask,
  latestActiveTaskOfType,
  autoPublishDue,
  newPracticeTask,
  notifyTask,
  launchTask,
  endTask,
  withdrawTask,
  isObjectiveQuestion,
  objectiveScore,
  subjectiveFullScore,
  submissionScore,
  analysisVisible,
  canSubmitAgain,
  effectiveStatus,
  remainText,
  fmtDateTime,
  fmtClock,
  statusName,
  statusColor,
  classStudents,
  awardPoints,
  practiceCsvRows
} from '../../model/InteractionModel'
import { DateTimeDialog } from '../../components/TaskDialogs'
import { CsvExport } from '../../utils/CsvExport'
import { MessageCenter } from '../../model/MessageCenterModel'

// ==================== 随堂练习 ====================
// 🌟 教师：出题、限时/永久开放、迟交规则、次数与修改、解析时机、自动判分 + 主观题批阅
// 🌟 学生：限时作答、图片上传、查看解析
// ⚠️ 本地演示：题目与提交记录保存在本机，无后端判分服务
@Entry
@Component
export struct PracticePage {
  @StorageLink('interactionTasks') tasks: TaskItem[] = []
  @StorageLink('userRole') userRole: string = 'student'
  @StorageLink('nickname') nickname: string = '张同学'
  @State taskId: string = ''
  @State tab: string = 'edit'
  @State now: number = Date.now()
  // 🌟 题目乱序：answerOrder 保存原始题目下标序列，进入任务时生成一次，避免重渲染抖动
  @State answerOrder: number[] = []
  @State orderedTaskId: string = ''
  // 🌟 切屏提醒：EntryAbility.onBackground 写入时间戳，此处监听
  @StorageLink('appBgStamp') @Watch('onAppBg') appBgStamp: number = 0
  @State leaveWarned: number = 0

  // 题目编辑
  @State editingId: string = ''
  @State editTitle: string = ''
  @State editType: QType = 'single'
  @State editOpts: string[] = []
  @State editSingle: number = 0
  @State editMulti: number[] = []
  @State editText: string = ''
  @State editAnalysis: string = ''

  // 学生作答
  @State answers: string[] = []

  // 批阅
  @State showGrade: boolean = false
  @State gradeSubId: string = ''
  @State gradeScore: number = 0

  private timer: number = -1

  startController: CustomDialogController = new CustomDialogController({
    builder: DateTimeDialog({
      title: '设置开始时间',
      initial: Date.now(),
      onConfirm: (ts: number) => {
        let t = this.current()
        if (t !== undefined) {
          t.startAt = ts
          this.tasks = this.tasks.slice()
        }
      }
    }),
    customStyle: true
  })

  endController: CustomDialogController = new CustomDialogController({
    builder: DateTimeDialog({
      title: '设置截止时间',
      initial: Date.now() + 30 * 60000,
      onConfirm: (ts: number) => {
        let t = this.current()
        if (t !== undefined) {
          t.endAt = ts
          this.tasks = this.tasks.slice()
        }
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
    if (wantCreate || this.taskId === '') {
      let latest = latestActiveTaskOfType(this.tasks, 'practice', Date.now())
      if (latest !== undefined && !wantCreate) {
        this.taskId = latest.id
      }
    }
    if (this.taskId === '' && this.canManage()) {
      this.createNew()
    }
    this.now = Date.now()
    this.initAnswers()
    this.rebuildOrder()
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

  practiceTasks(): TaskItem[] {
    return this.tasks.filter((t: TaskItem) => t.type === 'practice')
  }

  initAnswers(): void {
    let t = this.current()
    if (t === undefined) {
      this.answers = []
      return
    }
    let mine = this.myLatest(t)
    if (mine !== undefined) {
      this.answers = mine.answers.slice()
    } else {
      let arr: string[] = []
      for (let i = 0; i < t.questions.length; i++) {
        arr.push('')
      }
      this.answers = arr
    }
  }

  // 🌟 生成本次作答的题目顺序：开启乱序时按任务 id 做稳定打乱
  rebuildOrder(): void {
    let t = this.current()
    if (t === undefined) {
      this.answerOrder = []
      this.orderedTaskId = ''
      return
    }
    let arr: number[] = []
    for (let i = 0; i < t.questions.length; i++) {
      arr.push(i)
    }
    if (t.shuffleQuestions === true) {
      let seed = 20261118
      for (let i = 0; i < t.id.length; i++) {
        seed = (seed * 31 + t.id.charCodeAt(i)) % 233280
      }
      for (let i = arr.length - 1; i > 0; i--) {
        seed = (seed * 9301 + 49297) % 233280
        let j = seed % (i + 1)
        let tmp = arr[i]
        arr[i] = arr[j]
        arr[j] = tmp
      }
    }
    this.answerOrder = arr
    this.orderedTaskId = t.id
  }

  displayOrder(t: TaskItem): number[] {
    if (this.orderedTaskId === t.id && this.answerOrder.length === t.questions.length) {
      return this.answerOrder
    }
    let arr: number[] = []
    for (let i = 0; i < t.questions.length; i++) {
      arr.push(i)
    }
    return arr
  }

  // 🌟 切屏提醒：仅在作答进行中的练习任务里生效
  onAppBg(): void {
    let t = this.current()
    if (t === undefined || t.switchRemind !== true || this.canManage()) {
      return
    }
    if (effectiveStatus(t, this.now) !== 'ongoing') {
      return
    }
    this.leaveWarned += 1
    AlertDialog.show({
      title: '检测到切屏',
      message: `本次作答已记录 ${this.leaveWarned} 次离开页面，请专注作答。`,
      confirm: {
        value: '继续作答',
        action: () => {
        }
      }
    })
  }

  createNew(): void {
    let seed: PracticeQuestion[] = []
    let q1 = new PracticeQuestion('1. 请编辑题目内容', 'single')
    q1.opts = ['选项A', '选项B', '选项C']
    q1.answer = 0
    seed.push(q1)
    let t = newPracticeTask('随堂练习', seed)
    this.tasks = [t].concat(this.tasks)
    this.taskId = t.id
    this.tab = 'edit'
  }

  // ---------------- 题目编辑 ----------------
  openEditor(q: PracticeQuestion): void {
    this.editingId = q.id
    this.editTitle = q.title
    this.editType = q.type
    this.editOpts = q.opts.slice()
    this.editAnalysis = q.analysis
    if (q.type === 'single' || q.type === 'judge') {
      this.editSingle = q.answer as number
      this.editMulti = []
      this.editText = ''
    } else if (q.type === 'multi') {
      this.editMulti = (q.answer as number[]).slice()
      this.editSingle = 0
      this.editText = ''
    } else {
      this.editText = q.answer as string
      this.editSingle = 0
      this.editMulti = []
    }
  }

  switchType(type: QType): void {
    this.editType = type
    this.editSingle = 0
    this.editMulti = []
    this.editText = ''
    if (type === 'single' || type === 'multi') {
      this.editOpts = ['选项A', '选项B']
    } else if (type === 'judge') {
      this.editOpts = ['正确', '错误']
    } else {
      this.editOpts = []
    }
  }

  addQuestion(type: QType): void {
    let t = this.current()
    if (t === undefined) {
      return
    }
    let q = new PracticeQuestion('新题目', type)
    t.questions = t.questions.concat([q])
    this.tasks = this.tasks.slice()
    this.openEditor(q)
  }

  saveQuestion(q: PracticeQuestion): void {
    if (this.editTitle.trim() === '') {
      promptAction.showToast({ message: '请填写题干' })
      return
    }
    q.title = this.editTitle.trim()
    q.type = this.editType
    q.opts = (this.editType === 'essay' || this.editType === 'fill' || this.editType === 'image')
      ? [] : this.editOpts.slice()
    q.analysis = this.editAnalysis
    if (this.editType === 'single' || this.editType === 'judge') {
      q.answer = this.editSingle
    } else if (this.editType === 'multi') {
      q.answer = this.editMulti.slice()
    } else {
      q.answer = this.editText
    }
    this.tasks = this.tasks.slice()
    this.editingId = ''
    promptAction.showToast({ message: '题目已保存' })
  }

  deleteQuestion(q: PracticeQuestion): void {
    let t = this.current()
    if (t === undefined) {
      return
    }
    t.questions = t.questions.filter((x: PracticeQuestion) => x.id !== q.id)
    this.tasks = this.tasks.slice()
    if (this.editingId === q.id) {
      this.editingId = ''
    }
  }

  // ---------------- 任务设置 ----------------
  setMode(m: PracticeMode): void {
    let t = this.current()
    if (t === undefined) {
      return
    }
    t.practiceMode = m
    if (m === 'open') {
      t.endAt = 0
      t.allowLate = false
    } else if (t.startAt === 0) {
      t.startAt = Date.now()
      t.endAt = Date.now() + 30 * 60000
    }
    this.tasks = this.tasks.slice()
  }

  publish(t: TaskItem): void {
    if (t.questions.length === 0) {
      promptAction.showToast({ message: '请先添加题目' })
      return
    }
    if (t.practiceMode === 'timed' && t.endAt === 0) {
      t.endAt = Date.now() + 30 * 60000
    }
    if (t.practiceMode === 'open') {
      t.endAt = 0
    }
    if (t.startAt === 0) {
      t.startAt = Date.now()
    }
    launchTask(t)
    this.tasks = this.tasks.slice()
    notifyTask(t, `【随堂练习】${t.title} 已发布（${t.practiceMode === 'timed' ? '限时作答' : '永久开放'}），请同学们及时完成。`)
    promptAction.showToast({ message: '练习已发布' })
  }

  finish(t: TaskItem): void {
    AlertDialog.show({
      title: '提前结束',
      message: '结束后学生无法继续提交，已提交内容保留。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '结束', fontColor: '#F59E0B', action: () => {
          endTask(t)
          this.tasks = this.tasks.slice()
          notifyTask(t, `【随堂练习】${t.title} 已结束。`)
          promptAction.showToast({ message: '练习已结束' })
        }
      }
    })
  }

  revoke(t: TaskItem): void {
    AlertDialog.show({
      title: '撤回练习',
      message: '撤回后学生无法继续作答，已提交记录仍保留在台账。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '撤回', fontColor: '#EF4444', action: () => {
          withdrawTask(t)
          this.tasks = this.tasks.slice()
          notifyTask(t, `【随堂练习】${t.title} 已被撤回，请停止作答。`)
          promptAction.showToast({ message: '练习已撤回' })
        }
      }
    })
  }

  // ---------------- 判分与批阅 ----------------
  myLatest(t: TaskItem): PracticeSubmission | undefined {
    let mine = t.submissions.filter((s: PracticeSubmission) => s.student === this.nickname)
    if (mine.length === 0) {
      return undefined
    }
    return mine[mine.length - 1]
  }

  gradeSub(): PracticeSubmission | undefined {
    let hit = this.current() === undefined ? [] :
      this.current()!.submissions.filter((s: PracticeSubmission) => s.id === this.gradeSubId)
    return hit.length > 0 ? hit[0] : undefined
  }

  openGrade(s: PracticeSubmission): void {
    this.gradeSubId = s.id
    this.gradeScore = s.subjectiveScore
    this.showGrade = true
  }

  saveGrade(): void {
    let s = this.gradeSub()
    if (s === undefined) {
      return
    }
    s.subjectiveScore = this.gradeScore
    s.graded = true
    this.tasks = this.tasks.slice()
    this.showGrade = false
    // 🌟 批阅完成写入消息中心「作业批阅」分类，点击可直达该练习
    let cur = this.current()
    MessageCenter.pushIfEnabled('homework', '作业批阅',
      `你的「${cur === undefined ? '随堂练习' : cur.title}」已批阅，主观题得分 ${this.gradeScore}`,
      '', 'pages/study/PracticePage', cur === undefined ? '' : cur.id)
    promptAction.showToast({ message: '批阅完成' })
  }

  avgScore(t: TaskItem): number {
    if (t.submissions.length === 0) {
      return 0
    }
    let sum = 0
    t.submissions.forEach((s: PracticeSubmission) => {
      sum += submissionScore(s)
    })
    return Math.round(sum / t.submissions.length * 10) / 10
  }

  accuracy(t: TaskItem, qi: number): number {
    if (t.submissions.length === 0 || t.questions[qi] === undefined) {
      return 0
    }
    let right = 0
    let answered = 0
    t.submissions.forEach((s: PracticeSubmission) => {
      let a = s.answers[qi]
      if (a !== undefined && a !== '') {
        answered++
        if (objectiveScore([t.questions[qi]], [a]) > 0) {
          right++
        }
      }
    })
    return answered === 0 ? 0 : Math.round(right / answered * 100)
  }

  unsubmitted(t: TaskItem): string[] {
    let names: string[] = []
    classStudents().forEach((n: string) => {
      let hit = t.submissions.filter((s: PracticeSubmission) => s.student === n)
      if (hit.length === 0) {
        names.push(n)
      }
    })
    return names
  }

  exportData(t: TaskItem): void {
    try {
      let ctx = getContext(this) as common.UIAbilityContext
      let path = CsvExport.write(ctx, `practice_${t.id}.csv`, practiceCsvRows(t))
      AlertDialog.show({
        title: '导出完成（CSV）',
        message: `已生成 Excel 兼容的 CSV：\n${path}\n\n端上不生成真正的 .xlsx，请用 Excel / WPS 打开。`,
        confirm: { value: '知道了', action: () => {} }
      })
    } catch (e) {
      promptAction.showToast({ message: '导出失败' })
    }
  }

  // ---------------- 学生作答 ----------------
  setAnswer(i: number, v: string): void {
    let arr = this.answers.slice()
    arr[i] = v
    this.answers = arr
  }

  answerAt(i: number): string {
    return this.answers[i] === undefined ? '' : this.answers[i]
  }

  toggleMulti(i: number, opt: number): void {
    let cur = this.answerAt(i) === '' ? [] : this.answerAt(i).split(',')
    let key = String(opt)
    let next: string[] = []
    cur.forEach((x: string) => {
      if (x !== key) {
        next.push(x)
      }
    })
    if (cur.length === next.length) {
      next.push(key)
    }
    next.sort((a: string, b: string) => Number(a) - Number(b))
    this.setAnswer(i, next.join(','))
  }

  isMultiChecked(i: number, opt: number): boolean {
    return this.answerAt(i).split(',').includes(String(opt))
  }

  async pickImage(i: number): Promise<void> {
    try {
      let options = new photoAccessHelper.PhotoSelectOptions()
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      options.maxSelectNumber = 1
      let result = await new photoAccessHelper.PhotoViewPicker().select(options)
      if (result.photoUris.length === 0) {
        return
      }
      let ctx = getContext(this) as common.UIAbilityContext
      let dest = `${ctx.filesDir}/practice_${Date.now()}.jpg`
      let src = fs.openSync(result.photoUris[0], fs.OpenMode.READ_ONLY)
      fs.copyFileSync(src.fd, dest)
      fs.closeSync(src)
      this.setAnswer(i, dest)
      promptAction.showToast({ message: '图片已添加' })
    } catch (e) {
      promptAction.showToast({ message: '选择图片失败' })
    }
  }

  submit(t: TaskItem): void {
    if (this.canManage()) {
      promptAction.showToast({ message: '预览模式：不会记录提交与学分' })
      return
    }
    let now = Date.now()
    // 🌟 用任务自身状态判断撤回 / 手动结束；endAt 过期单独作为「迟交」处理，
    //    否则自动结束状态会让 allowLate / latePenalty 永远不可达
    if (t.status === 'withdrawn') {
      promptAction.showToast({ message: '练习已撤回，无法作答' })
      return
    }
    if (t.status !== 'ongoing') {
      promptAction.showToast({ message: '练习已结束，无法提交' })
      return
    }
    if (t.startAt > 0 && now < t.startAt) {
      promptAction.showToast({ message: '练习尚未开始' })
      return
    }
    let late = false
    if (t.endAt > 0 && now >= t.endAt) {
      if (!t.allowLate) {
        promptAction.showToast({ message: '已超过截止时间，且不允许迟交' })
        return
      }
      late = true
    }
    if (!canSubmitAgain(t, this.nickname)) {
      promptAction.showToast({ message: t.allowEdit ? `已达到最大提交次数（${t.maxSubmits} 次）` : '本练习不允许修改答案' })
      return
    }
    let mine = t.submissions.filter((s: PracticeSubmission) => s.student === this.nickname)
    let sub = new PracticeSubmission(this.nickname, this.answers.slice())
    sub.attempt = mine.length + 1
    sub.late = late
    sub.penalty = late ? t.latePenalty : 0
    sub.objectiveScore = objectiveScore(t.questions, this.answers)
    t.submissions = t.submissions.concat([sub])
    this.tasks = this.tasks.slice()
    let gain = mine.length === 0 ? awardPoints('practice', this.nickname) : 0
    promptAction.showToast({ message: gain > 0 ? `提交成功，客观题 ${sub.objectiveScore} 分，获得 ${gain} 学分` : '提交成功' })
  }

  // ---------------- 视图 ----------------
  typeName(t: string): string {
    if (t === 'single') {
      return '单选'
    }
    if (t === 'multi') {
      return '多选'
    }
    if (t === 'judge') {
      return '判断'
    }
    if (t === 'fill') {
      return '填空'
    }
    if (t === 'image') {
      return '图片上传'
    }
    return '简答'
  }

  @Builder
  header() {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(20).fontColor([$r('app.color.text_main')])
        .onClick(() => router.back())
      Column({ space: 2 }) {
        Text('随堂练习').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Text(`数据结构与算法 · ${this.userRole === 'assistant' ? '助教' : this.userRole === 'teacher' ? '授课教师' : '学生'}视角`)
          .fontSize(11).fontColor($r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (this.canManage()) {
        Text('+ 新建')
          .fontSize(12).fontColor(Color.White)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor($r('app.color.primary')).borderRadius(16)
          .onClick(() => this.createNew())
      }
    }
    .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 8 })
  }

  @Builder
  taskChips() {
    if (this.practiceTasks().length > 0) {
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.practiceTasks(), (t: TaskItem) => {
            Text(`${t.title}${effectiveStatus(t, this.now) === 'pending' ? '（草稿）' : ''}`)
              .fontSize(12)
              .fontColor(this.taskId === t.id ? Color.White : $r('app.color.text_main'))
              .backgroundColor(this.taskId === t.id ? '#3F7EF6' : $r('app.color.field_bg'))
              .padding({ left: 12, right: 12, top: 6, bottom: 6 }).borderRadius(14)
              .onClick(() => {
                this.taskId = t.id
                this.editingId = ''
                this.initAnswers()
              })
          }, (t: TaskItem) => t.id)
        }.padding({ left: 16, right: 16 })
      }.scrollBar(BarState.Off).width('100%').margin({ bottom: 6 })
    }
  }

  @Builder
  tabChip(key: string, label: string) {
    Text(label)
      .fontSize(13)
      .fontColor(this.tab === key ? Color.White : $r('app.color.text_main'))
      .backgroundColor(this.tab === key ? '#3F7EF6' : $r('app.color.field_bg'))
      .padding({ left: 14, right: 14, top: 6, bottom: 6 }).borderRadius(14)
      .onClick(() => {
        this.tab = key
      })
  }

  @Builder
  optionEditor(i: number) {
    Row({ space: 8 }) {
      Text(`${String.fromCharCode(65 + i)}`).fontSize(12).fontColor($r('app.color.text_sub')).width(18)
      TextInput({ text: this.editOpts[i], placeholder: `选项 ${i + 1}` })
        .height(36).fontSize(13).layoutWeight(1)
        .backgroundColor($r('app.color.field_bg')).borderRadius(8)
        .onChange((v: string) => {
          let arr = this.editOpts.slice()
          arr[i] = v
          this.editOpts = arr
        })
      if ((this.editType === 'single' || this.editType === 'multi') && this.editOpts.length > 2) {
        Text('删除').fontSize(11).fontColor('#EF4444')
          .onClick(() => {
            let arr = this.editOpts.filter((x: string, idx: number) => idx !== i)
            this.editOpts = arr
            if (this.editSingle >= arr.length) {
              this.editSingle = 0
            }
            this.editMulti = this.editMulti.filter((x: number) => x !== i && x < arr.length)
          })
      }
    }.width('100%')
  }

  @Builder
  questionEditor(q: PracticeQuestion) {
    Column({ space: 10 }) {
      Text('编辑题目').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).width('100%')
      TextArea({ text: this.editTitle, placeholder: '请输入题干' })
        .height(64).fontSize(13).backgroundColor($r('app.color.field_bg')).borderRadius(8)
        .onChange((v: string) => {
          this.editTitle = v
        })
      Scroll() {
        Row({ space: 6 }) {
          ForEach(['single', 'multi', 'judge', 'fill', 'essay', 'image'] as QType[], (tp: QType) => {
            Text(this.typeName(tp))
              .fontSize(11)
              .fontColor(this.editType === tp ? Color.White : $r('app.color.text_main'))
              .backgroundColor(this.editType === tp ? '#3F7EF6' : $r('app.color.field_bg'))
              .padding({ left: 10, right: 10, top: 4, bottom: 4 }).borderRadius(10)
              .onClick(() => this.switchType(tp))
          }, (tp: QType) => tp)
        }
      }.scrollBar(BarState.Off)

      if (this.editType === 'single' || this.editType === 'multi' || this.editType === 'judge') {
        Text('选项（点击左侧圆点设置正确答案）').fontSize(11).fontColor($r('app.color.text_hint')).width('100%')
        ForEach(this.editOpts, (o: string, i: number) => {
          Row({ space: 8 }) {
            Circle()
              .width(18).height(18)
              .fill(this.editType === 'multi'
                ? (this.editMulti.includes(i) ? '#3F7EF6' : $r('app.color.field_bg'))
                : (this.editSingle === i ? '#3F7EF6' : $r('app.color.field_bg')))
              .onClick(() => {
                if (this.editType === 'multi') {
                  if (this.editMulti.includes(i)) {
                    this.editMulti = this.editMulti.filter((x: number) => x !== i)
                  } else {
                    this.editMulti = this.editMulti.concat([i])
                  }
                } else {
                  this.editSingle = i
                }
              })
            if (this.editType === 'judge') {
              Text(o).fontSize(13).layoutWeight(1).fontColor($r('app.color.text_main'))
            } else {
              this.optionEditor(i)
            }
          }.width('100%')
        }, (o: string, i: number) => `${i}_${o}`)
        if (this.editType === 'single' || this.editType === 'multi') {
          Text('+ 添加选项').fontSize(12).fontColor('#3F7EF6')
            .onClick(() => {
              this.editOpts = this.editOpts.concat([`选项${String.fromCharCode(65 + this.editOpts.length)}`])
            })
        }
      } else if (this.editType === 'fill') {
        TextInput({ text: this.editText, placeholder: '填写标准答案（用于自动判分）' })
          .height(38).fontSize(13).backgroundColor($r('app.color.field_bg')).borderRadius(8)
          .onChange((v: string) => {
            this.editText = v
          })
      } else {
        Text(this.editType === 'image' ? '图片上传题由教师逐份批阅' : '简答题由教师逐份批阅')
          .fontSize(11).fontColor($r('app.color.text_hint')).width('100%')
      }

      TextInput({ text: this.editAnalysis, placeholder: '答案解析（可选）' })
        .height(38).fontSize(13).backgroundColor($r('app.color.field_bg')).borderRadius(8)
        .onChange((v: string) => {
          this.editAnalysis = v
        })

      Row({ space: 10 }) {
        Text('取消').fontSize(13).fontColor($r('app.color.text_sub'))
          .layoutWeight(1).height(36).textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.field_bg')).borderRadius(18)
          .onClick(() => {
            this.editingId = ''
          })
        Text('保存题目').fontSize(13).fontColor(Color.White)
          .layoutWeight(1).height(36).textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.primary')).borderRadius(18)
          .onClick(() => this.saveQuestion(q))
      }.width('100%')
    }
    .width('100%').padding(12).backgroundColor($r('app.color.field_bg')).borderRadius(10)
  }

  @Builder
  questionCard(q: PracticeQuestion, i: number) {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text(`${i + 1}`).fontSize(11).fontColor(Color.White)
          .width(20).height(20).textAlign(TextAlign.Center)
          .backgroundColor('#3F7EF6').borderRadius(10)
        Text(this.typeName(q.type)).fontSize(10).fontColor('#3F7EF6')
          .padding({ left: 6, right: 6, top: 1, bottom: 1 })
          .border({ width: 1, color: '#3F7EF6' }).borderRadius(8)
        Blank()
        if (this.canManage() && effectiveStatus(this.current()!, this.now) !== 'withdrawn') {
          Text('编辑').fontSize(11).fontColor('#3F7EF6')
            .onClick(() => this.openEditor(q))
          Text('删除').fontSize(11).fontColor('#EF4444')
            .onClick(() => this.deleteQuestion(q))
        }
      }.width('100%')
      Text(q.title).fontSize(13).fontColor($r('app.color.text_main')).width('100%').lineHeight(19)
      if (q.opts.length > 0 && q.type !== 'judge') {
        Text(q.opts.map((o: string, idx: number) => `${String.fromCharCode(65 + idx)}. ${o}`).join('   '))
          .fontSize(11).fontColor($r('app.color.text_hint')).width('100%').maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('92%').padding(12).backgroundColor($r('app.color.card_bg')).borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  editTab(t: TaskItem) {
    Scroll() {
      Column({ space: 10 }) {
        if (this.canManage()) {
          Row({ space: 8 }) {
            Text('+ 单选').fontSize(11).fontColor('#3F7EF6').onClick(() => this.addQuestion('single'))
            Text('+ 多选').fontSize(11).fontColor('#3F7EF6').onClick(() => this.addQuestion('multi'))
            Text('+ 判断').fontSize(11).fontColor('#3F7EF6').onClick(() => this.addQuestion('judge'))
            Text('+ 填空').fontSize(11).fontColor('#3F7EF6').onClick(() => this.addQuestion('fill'))
            Text('+ 简答').fontSize(11).fontColor('#3F7EF6').onClick(() => this.addQuestion('essay'))
            Text('+ 图片').fontSize(11).fontColor('#3F7EF6').onClick(() => this.addQuestion('image'))
          }.width('92%').padding({ top: 4, bottom: 4 })
        }
        ForEach(t.questions, (q: PracticeQuestion, i: number) => {
          if (this.editingId === q.id) {
            Column() {
              this.questionEditor(q)
            }.width('92%')
          } else {
            this.questionCard(q, i)
          }
        }, (q: PracticeQuestion) => q.id)
        if (t.questions.length === 0) {
          Text('暂无题目，点击上方按钮添加').fontSize(13).fontColor($r('app.color.text_hint')).margin({ top: 30 })
        }
        Blank().height(20)
      }.width('100%')
    }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
  }

  @Builder
  switchRow(label: string, tip: string, on: boolean, onChange: (v: boolean) => void) {
    Row() {
      Column({ space: 2 }) {
        Text(label).fontSize(13).fontColor($r('app.color.text_main'))
        if (tip !== '') {
          Text(tip).fontSize(10).fontColor($r('app.color.text_hint'))
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: on })
        .selectedColor('#3F7EF6')
        .onChange((v: boolean) => onChange(v))
    }.width('100%')
  }

  @Builder
  settingTab(t: TaskItem) {
    Scroll() {
      Column({ space: 12 }) {
        TextInput({ text: t.title, placeholder: '练习标题' })
          .height(42).fontSize(14).backgroundColor($r('app.color.card_bg')).borderRadius(10)
          .onChange((v: string) => {
            t.title = v
            this.tasks = this.tasks.slice()
          })

        Column({ space: 12 }) {
          Text('作答模式').fontSize(12).fontColor($r('app.color.text_hint')).width('100%')
          Row({ space: 8 }) {
            Text('限时作答').fontSize(13)
              .fontColor(t.practiceMode === 'timed' ? Color.White : $r('app.color.text_main'))
              .backgroundColor(t.practiceMode === 'timed' ? '#3F7EF6' : $r('app.color.field_bg'))
              .padding({ left: 14, right: 14, top: 7, bottom: 7 }).borderRadius(14)
              .onClick(() => this.setMode('timed'))
            Text('永久开放').fontSize(13)
              .fontColor(t.practiceMode === 'open' ? Color.White : $r('app.color.text_main'))
              .backgroundColor(t.practiceMode === 'open' ? '#3F7EF6' : $r('app.color.field_bg'))
              .padding({ left: 14, right: 14, top: 7, bottom: 7 }).borderRadius(14)
              .onClick(() => this.setMode('open'))
          }.width('100%')

          if (t.practiceMode === 'timed') {
            Row() {
              Text('开始时间').fontSize(13).fontColor($r('app.color.text_main')).layoutWeight(1)
              Text(fmtDateTime(t.startAt) === '' ? '未设置' : fmtDateTime(t.startAt))
                .fontSize(12).fontColor('#3F7EF6')
                .onClick(() => this.startController.open())
            }.width('100%')
            Row() {
              Text('截止时间').fontSize(13).fontColor($r('app.color.text_main')).layoutWeight(1)
              Text(fmtDateTime(t.endAt) === '' ? '未设置' : fmtDateTime(t.endAt))
                .fontSize(12).fontColor('#3F7EF6')
                .onClick(() => this.endController.open())
            }.width('100%')
            this.switchRow('允许迟交', '迟交将按比例扣分', t.allowLate, (v: boolean): void => {
              t.allowLate = v
              this.tasks = this.tasks.slice()
            })
            if (t.allowLate) {
              Row() {
                Text('迟交扣分比例').fontSize(13).fontColor($r('app.color.text_main')).layoutWeight(1)
                Text(`${t.latePenalty}%`).fontSize(13).fontColor('#EF4444')
              }.width('100%')
              Slider({ value: t.latePenalty, min: 0, max: 50, step: 5 })
                .selectedColor('#F59E0B')
                .onChange((v: number) => {
                  t.latePenalty = v
                  this.tasks = this.tasks.slice()
                })
            }
          }
        }.width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(12)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 12 }) {
          Row() {
            Text('单用户提交次数').fontSize(13).fontColor($r('app.color.text_main')).layoutWeight(1)
            Row({ space: 10 }) {
              Text('－').fontSize(16).fontColor($r('app.color.text_main'))
                .width(26).height(26).textAlign(TextAlign.Center)
                .backgroundColor($r('app.color.field_bg')).borderRadius(13)
                .onClick(() => {
                  if (t.maxSubmits > 1) {
                    t.maxSubmits--
                    this.tasks = this.tasks.slice()
                  }
                })
              Text(`${t.maxSubmits}`).fontSize(14).fontColor($r('app.color.text_main'))
              Text('＋').fontSize(16).fontColor($r('app.color.text_main'))
                .width(26).height(26).textAlign(TextAlign.Center)
                .backgroundColor($r('app.color.field_bg')).borderRadius(13)
                .onClick(() => {
                  if (t.maxSubmits < 5) {
                    t.maxSubmits++
                    this.tasks = this.tasks.slice()
                  }
                })
            }
          }.width('100%')
          this.switchRow('允许修改答案', '关闭后仅可提交一次', t.allowEdit, (v: boolean): void => {
            t.allowEdit = v
            this.tasks = this.tasks.slice()
          })
          Text('解析查看时机').fontSize(12).fontColor($r('app.color.text_hint')).width('100%')
          Row({ space: 8 }) {
            Text('提交后可见').fontSize(13)
              .fontColor(t.analysisTiming === 'submit' ? Color.White : $r('app.color.text_main'))
              .backgroundColor(t.analysisTiming === 'submit' ? '#3F7EF6' : $r('app.color.field_bg'))
              .padding({ left: 12, right: 12, top: 6, bottom: 6 }).borderRadius(12)
              .onClick(() => {
                t.analysisTiming = 'submit'
                this.tasks = this.tasks.slice()
              })
            Text('全部结束后').fontSize(13)
              .fontColor(t.analysisTiming === 'end' ? Color.White : $r('app.color.text_main'))
              .backgroundColor(t.analysisTiming === 'end' ? '#3F7EF6' : $r('app.color.field_bg'))
              .padding({ left: 12, right: 12, top: 6, bottom: 6 }).borderRadius(12)
              .onClick(() => {
                t.analysisTiming = 'end'
                this.tasks = this.tasks.slice()
              })
          }.width('100%')
          this.switchRow('题目随机乱序', '学生作答时题目顺序随机', t.shuffleQuestions === true, (v: boolean): void => {
            t.shuffleQuestions = v
            this.tasks = this.tasks.slice()
            this.rebuildOrder()
          })
          this.switchRow('作答切屏提醒', '学生离开页面时记录并弹窗提醒', t.switchRemind === true, (v: boolean): void => {
            t.switchRemind = v
            this.tasks = this.tasks.slice()
          })
        }.width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(12)
        .alignItems(HorizontalAlign.Start)

        Row({ space: 10 }) {
          if (t.status === 'pending') {
            Text('发布练习').fontSize(14).fontColor(Color.White)
              .layoutWeight(1).height(42).textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.primary')).borderRadius(21)
              .onClick(() => this.publish(t))
          } else if (effectiveStatus(t, this.now) === 'ongoing') {
            Text('提前结束').fontSize(14).fontColor(Color.White)
              .layoutWeight(1).height(42).textAlign(TextAlign.Center)
              .backgroundColor('#F59E0B').borderRadius(21)
              .onClick(() => this.finish(t))
          }
          if (t.status === 'pending' || effectiveStatus(t, this.now) === 'ongoing') {
            Text('撤回').fontSize(14).fontColor(Color.White)
              .layoutWeight(1).height(42).textAlign(TextAlign.Center)
              .backgroundColor('#EF4444').borderRadius(21)
              .onClick(() => this.revoke(t))
          }
        }.width('92%')

        Text('本地演示：无后端判分服务，客观题在本机自动判分，主观题由教师逐份批阅。')
          .fontSize(11).fontColor($r('app.color.text_hint')).width('92%')
        Blank().height(20)
      }.width('100%').padding({ top: 6 })
    }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
  }

  @Builder
  subCard(t: TaskItem, s: PracticeSubmission) {
    Row({ space: 8 }) {
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(s.student).fontSize(14).fontColor($r('app.color.text_main'))
          Text(`第 ${s.attempt} 次`).fontSize(10).fontColor($r('app.color.text_hint'))
          if (s.late) {
            Text('迟交').fontSize(10).fontColor('#F59E0B')
          }
        }
        Text(`${fmtClock(s.submitAt)} · 客观 ${s.objectiveScore} + 主观 ${s.subjectiveScore} = ${submissionScore(s)} 分`)
          .fontSize(11).fontColor($r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text(s.graded ? '已批阅' : '去批阅')
        .fontSize(12).fontColor(s.graded ? '#10B981' : Color.White)
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor(s.graded ? '#E8F7F0' : '#3F7EF6').borderRadius(12)
        .onClick(() => this.openGrade(s))
    }
    .width('92%').padding(12).backgroundColor($r('app.color.card_bg')).borderRadius(12)
  }

  @Builder
  gradingTab(t: TaskItem) {
    Scroll() {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text(`共 ${t.submissions.length} 次提交 · ${countNames(t)} 人参与`)
            .fontSize(12).fontColor($r('app.color.text_sub'))
          Blank()
          Text('导出成绩').fontSize(12).fontColor('#3F7EF6')
            .onClick(() => this.exportData(t))
        }.width('92%').padding({ top: 4, bottom: 4 })
        ForEach(t.submissions, (s: PracticeSubmission) => {
          this.subCard(t, s)
        }, (s: PracticeSubmission) => s.id)
        if (t.submissions.length === 0) {
          Text('暂无提交记录').fontSize(13).fontColor($r('app.color.text_hint')).margin({ top: 30 })
        }
        Blank().height(30)
      }.width('100%')
    }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
  }

  @Builder
  statsTab(t: TaskItem) {
    Scroll() {
      Column({ space: 12 }) {
        Row({ space: 8 }) {
          Column({ space: 2 }) {
            Text(`${t.submissions.length}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#3F7EF6')
            Text('提交次数').fontSize(11).fontColor($r('app.color.text_sub'))
          }.layoutWeight(1).padding(10).backgroundColor($r('app.color.card_bg')).borderRadius(10)
          Column({ space: 2 }) {
            Text(`${countNames(t)}/${t.total}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#10B981')
            Text('参与人数').fontSize(11).fontColor($r('app.color.text_sub'))
          }.layoutWeight(1).padding(10).backgroundColor($r('app.color.card_bg')).borderRadius(10)
          Column({ space: 2 }) {
            Text(`${this.avgScore(t)}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#F59E0B')
            Text('平均分').fontSize(11).fontColor($r('app.color.text_sub'))
          }.layoutWeight(1).padding(10).backgroundColor($r('app.color.card_bg')).borderRadius(10)
        }.width('92%')

        Column({ space: 8 }) {
          Text('客观题正确率').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).width('100%')
          ForEach(t.questions, (q: PracticeQuestion, i: number) => {
            if (isObjectiveQuestion(q)) {
              Column({ space: 4 }) {
                Text(`${i + 1}. ${q.title}`).fontSize(12).fontColor($r('app.color.text_main'))
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                Row() {
                  Row().width(`${this.accuracy(t, i)}%`).height(5).backgroundColor('#3F7EF6').borderRadius(3)
                }.width('100%').height(5).backgroundColor($r('app.color.field_bg')).borderRadius(3)
                Text(`正确率 ${this.accuracy(t, i)}%`).fontSize(10).fontColor($r('app.color.text_hint'))
              }.width('100%').alignItems(HorizontalAlign.Start)
            }
          }, (q: PracticeQuestion) => `stat_${q.id}`)
        }.width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(12)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 6 }) {
          Text('未提交学生').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).width('100%')
          Text(this.unsubmitted(t).length === 0 ? '全部学生已提交' : this.unsubmitted(t).join('、'))
            .fontSize(12).fontColor($r('app.color.text_sub')).width('100%')
          Text('本地演示数据：提交记录保存在本机，未接入后端统计服务。')
            .fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
        }.width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(12)
        .alignItems(HorizontalAlign.Start)
        Blank().height(30)
      }.width('100%').padding({ top: 6 })
    }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
  }

  @Builder
  answerInput(t: TaskItem, q: PracticeQuestion, i: number) {
    Column({ space: 8 }) {
      Text(`${i + 1}. ${q.title}`).fontSize(14).fontColor($r('app.color.text_main')).width('100%').lineHeight(20)
      Text(this.typeName(q.type)).fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
      if (q.type === 'single' || q.type === 'judge') {
        ForEach(q.opts, (o: string, oi: number) => {
          Row({ space: 8 }) {
            Circle().width(16).height(16)
              .fill(this.answerAt(i) === String(oi) ? '#3F7EF6' : $r('app.color.field_bg'))
            Text(`${String.fromCharCode(65 + oi)}. ${o}`).fontSize(13).fontColor($r('app.color.text_main')).layoutWeight(1)
          }.width('100%').padding({ top: 6, bottom: 6 })
          .onClick(() => {
            if (effectiveStatus(t, this.now) === 'ongoing') {
              this.setAnswer(i, String(oi))
            }
          })
        }, (o: string, oi: number) => `opt_${i}_${oi}`)
      } else if (q.type === 'multi') {
        ForEach(q.opts, (o: string, oi: number) => {
          Row({ space: 8 }) {
            Circle().width(16).height(16)
              .fill(this.isMultiChecked(i, oi) ? '#3F7EF6' : $r('app.color.field_bg'))
            Text(`${String.fromCharCode(65 + oi)}. ${o}`).fontSize(13).fontColor($r('app.color.text_main')).layoutWeight(1)
          }.width('100%').padding({ top: 6, bottom: 6 })
          .onClick(() => {
            if (effectiveStatus(t, this.now) === 'ongoing') {
              this.toggleMulti(i, oi)
            }
          })
        }, (o: string, oi: number) => `mopt_${i}_${oi}`)
      } else if (q.type === 'fill') {
        TextInput({ text: this.answerAt(i), placeholder: '请输入答案' })
          .height(38).fontSize(13).backgroundColor($r('app.color.field_bg')).borderRadius(8)
          .onChange((v: string) => this.setAnswer(i, v))
      } else if (q.type === 'image') {
        if (this.answerAt(i) !== '') {
          Image(this.answerAt(i)).width(120).height(90).borderRadius(8).objectFit(ImageFit.Cover)
        }
        Text(this.answerAt(i) === '' ? '上传作答图片' : '重新选择图片')
          .fontSize(12).fontColor('#3F7EF6')
          .onClick(() => this.pickImage(i))
        Text('图片保存在本机应用沙箱，仅本地演示').fontSize(10).fontColor($r('app.color.text_hint'))
      } else {
        TextArea({ text: this.answerAt(i), placeholder: '请输入作答内容' })
          .height(80).fontSize(13).backgroundColor($r('app.color.field_bg')).borderRadius(8)
          .onChange((v: string) => this.setAnswer(i, v))
      }
    }
    .width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  answerTab(t: TaskItem) {
    Scroll() {
      Column({ space: 10 }) {
        Column({ space: 6 }) {
          Row() {
            Text(t.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).layoutWeight(1)
            Text(statusName(effectiveStatus(t, this.now))).fontSize(11).fontColor(Color.White)
              .backgroundColor(statusColor(effectiveStatus(t, this.now)))
              .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(10)
          }.width('100%')
          Text(t.practiceMode === 'timed'
            ? `限时：${fmtDateTime(t.startAt)} - ${fmtDateTime(t.endAt)} · ${remainText(t.endAt, this.now)}`
            : '永久开放')
            .fontSize(11).fontColor($r('app.color.text_sub')).width('100%')
          Text(`共 ${t.questions.length} 题 · 允许提交 ${t.maxSubmits} 次 · ${t.allowEdit ? '可修改答案' : '不可修改答案'}`
            + (t.allowLate ? ` · 迟交扣 ${t.latePenalty}%` : '')
            + (t.shuffleQuestions === true ? ' · 题目已乱序' : '')
            + (t.switchRemind === true ? ' · 切屏提醒已开启' : ''))
            .fontSize(11).fontColor($r('app.color.text_hint')).width('100%')
          Text('本地演示：客观题自动判分，主观题由教师批阅。')
            .fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
        }.width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(12)
        .alignItems(HorizontalAlign.Start)

        if (this.myLatest(t) !== undefined) {
          Column({ space: 4 }) {
            Text('我的最近一次提交')
              .fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).width('100%')
            Text(`客观题 ${this.myLatest(t)!.objectiveScore} 分 · 主观题 ${this.myLatest(t)!.subjectiveScore} 分`
              + ` · 总分 ${submissionScore(this.myLatest(t)!)} 分`)
              .fontSize(12).fontColor('#3F7EF6').width('100%')
            Text(this.myLatest(t)!.late ? `迟交，已扣 ${this.myLatest(t)!.penalty}%` : '按时提交')
              .fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
          }.width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(12)
          .alignItems(HorizontalAlign.Start)
        }

        ForEach(this.displayOrder(t), (qi: number, di: number) => {
          Column({ space: 6 }) {
            this.answerInput(t, t.questions[qi], qi)
            if (analysisVisible(t, this.myLatest(t), this.now)) {
              Column({ space: 3 }) {
                Text(`正确答案：${this.correctText(t.questions[qi])}`).fontSize(11).fontColor('#10B981')
                if (t.questions[qi].analysis !== '') {
                  Text(`解析：${t.questions[qi].analysis}`).fontSize(11).fontColor($r('app.color.text_sub'))
                }
              }.width('92%').padding(10).backgroundColor('#E8F7F0').borderRadius(8)
              .alignItems(HorizontalAlign.Start)
            }
          }.width('100%').alignItems(HorizontalAlign.Center)
        }, (qi: number) => `ans_${t.id}_${qi}`)

        if (this.myLatest(t) !== undefined && t.analysisTiming === 'end' && effectiveStatus(t, this.now) !== 'ended') {
          Text('解析将在全部任务结束后开放').fontSize(11).fontColor($r('app.color.text_hint')).width('92%')
        }

        if (effectiveStatus(t, this.now) === 'ongoing') {
          Text(this.myLatest(t) === undefined ? '提交答案' : (t.allowEdit ? '重新提交' : '已提交'))
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
            .height(44).width('92%').textAlign(TextAlign.Center)
            .backgroundColor(t.allowEdit && this.myLatest(t) !== undefined ? '#10B981' : $r('app.color.primary'))
            .borderRadius(22)
            .opacity(t.allowEdit || this.myLatest(t) === undefined ? 1 : 0.5)
            .onClick(() => this.submit(t))
        } else {
          Text(effectiveStatus(t, this.now) === 'withdrawn' ? '任务已撤回，无法作答' : '任务已结束')
            .fontSize(13).fontColor($r('app.color.text_hint')).width('92%').textAlign(TextAlign.Center)
        }
        Blank().height(30)
      }.width('100%').padding({ top: 6 }).alignItems(HorizontalAlign.Center)
    }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
  }

  correctText(q: PracticeQuestion): string {
    if (q.type === 'single' || q.type === 'judge') {
      let idx = q.answer as number
      return q.opts[idx] === undefined ? '' : `${String.fromCharCode(65 + idx)}. ${q.opts[idx]}`
    }
    if (q.type === 'multi') {
      return (q.answer as number[]).map((x: number) => String.fromCharCode(65 + x)).join('、')
    }
    return q.answer as string
  }

  @Builder
  gradeSheet() {
    if (this.gradeSub() !== undefined) {
      Column({ space: 12 }) {
        Text(`批阅 · ${this.gradeSub()!.student}`)
          .fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Text(`客观题 ${this.gradeSub()!.objectiveScore} 分（系统自动判分）`)
          .fontSize(12).fontColor($r('app.color.text_sub'))
        if (this.current() !== undefined) {
          ForEach(this.current()!.questions, (q: PracticeQuestion, i: number) => {
            if (!isObjectiveQuestion(q) && this.gradeSub() !== undefined) {
              Column({ space: 4 }) {
                Text(`${i + 1}. ${q.title}`).fontSize(12).fontColor($r('app.color.text_main')).width('100%')
                Text(this.gradeSub()!.answers[i] === undefined || this.gradeSub()!.answers[i] === ''
                  ? '（未作答）' : this.gradeSub()!.answers[i])
                  .fontSize(12).fontColor($r('app.color.text_sub')).width('100%')
              }.width('100%').padding(10).backgroundColor($r('app.color.field_bg')).borderRadius(8)
              .alignItems(HorizontalAlign.Start)
            }
          }, (q: PracticeQuestion) => `grade_${q.id}`)
        }
        Row() {
          Text('主观题得分').fontSize(13).fontColor($r('app.color.text_main')).layoutWeight(1)
          Text(`${this.gradeScore} / ${this.current() === undefined ? 0 : subjectiveFullScore(this.current()!.questions)}`)
            .fontSize(13).fontColor('#3F7EF6')
        }.width('100%')
        Slider({
          value: this.gradeScore, min: 0,
          max: this.current() === undefined ? 100 : Math.max(1, subjectiveFullScore(this.current()!.questions)),
          step: 1
        })
          .selectedColor('#3F7EF6')
          .onChange((v: number) => {
            this.gradeScore = v
          })
        Text('保存批阅')
          .fontSize(15).fontColor(Color.White)
          .height(42).width('100%').textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.primary')).borderRadius(21)
          .onClick(() => this.saveGrade())
      }
      .width('100%').padding(20).alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    Column() {
      this.header()
      this.taskChips()
      if (this.current() === undefined) {
        Column({ space: 10 }) {
          Text('暂无随堂练习').fontSize(14).fontColor($r('app.color.text_sub'))
          if (this.canManage()) {
            Text('新建练习').fontSize(14).fontColor(Color.White)
              .padding({ left: 18, right: 18, top: 9, bottom: 9 })
              .backgroundColor($r('app.color.primary')).borderRadius(20)
              .onClick(() => this.createNew())
          }
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.canManage()) {
        Row({ space: 8 }) {
          this.tabChip('edit', '出题')
          this.tabChip('setting', '设置')
          this.tabChip('grading', '批阅')
          this.tabChip('stats', '统计')
          this.tabChip('answer', '预览作答')
        }.width('100%').padding({ left: 16, right: 16, bottom: 8 })

        if (this.tab === 'edit') {
          this.editTab(this.current()!)
        } else if (this.tab === 'setting') {
          this.settingTab(this.current()!)
        } else if (this.tab === 'grading') {
          this.gradingTab(this.current()!)
        } else if (this.tab === 'stats') {
          this.statsTab(this.current()!)
        } else {
          this.answerTab(this.current()!)
        }
      } else {
        this.answerTab(this.current()!)
      }
    }
    .width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
    .bindSheet($$this.showGrade, this.gradeSheet(), { detents: [SheetSize.MEDIUM, SheetSize.LARGE], showClose: true })
  }
}

// 参与人数（去重）
function countNames(t: TaskItem): number {
  let names: string[] = []
  t.submissions.forEach((s: PracticeSubmission) => {
    if (!names.includes(s.student)) {
      names.push(s.student)
    }
  })
  return names.length
}
