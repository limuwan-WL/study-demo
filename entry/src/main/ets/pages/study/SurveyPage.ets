import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import { SurveyQuestion, SurveyType } from '../../model/DataModel'
import {
  TaskItem,
  SurveyResponse,
  findTask,
  latestActiveTaskOfType,
  autoPublishDue,
  newSurveyTask,
  notifyTask,
  launchTask,
  endTask,
  withdrawTask,
  effectiveStatus,
  statusName,
  statusColor,
  fmtDateTime,
  remainText,
  surveyOptionCount,
  surveyScaleAvg
} from '../../model/InteractionModel'
import { DateTimeDialog } from '../../components/TaskDialogs'

// ==================== 调查问卷 ====================
// 🌟 教师：单选 / 多选 / 简答 / 量表，匿名或实名发布，查看作答统计
// 🌟 学生：参与作答
// ⚠️ 本地演示：匿名问卷写入空学生标识，不关联个人信息；统计为本机数据
@Entry
@Component
export struct SurveyPage {
  @StorageLink('interactionTasks') tasks: TaskItem[] = []
  @StorageLink('userRole') userRole: string = 'student'
  @StorageLink('nickname') nickname: string = '张同学'
  @State taskId: string = ''
  @State tab: string = 'edit'
  @State now: number = Date.now()
  @State answers: string[] = []
  @State submitted: boolean = false

  // 编辑题目
  @State editingId: string = ''
  @State editTitle: string = ''
  @State editType: SurveyType = 'single'
  @State editOpts: string[] = []
  @State editScale: number = 5

  private timer: number = -1

  endController: CustomDialogController = new CustomDialogController({
    builder: DateTimeDialog({
      title: '设置问卷截止时间',
      initial: Date.now() + 24 * 3600000,
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
    if (this.taskId === '') {
      let latest = latestActiveTaskOfType(this.tasks, 'survey', Date.now())
      if (latest !== undefined) {
        this.taskId = latest.id
      }
    }
    if (this.taskId === '' && this.canManage()) {
      this.createNew()
    }
    this.now = Date.now()
    this.syncAnswers()
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

  surveyTasks(): TaskItem[] {
    return this.tasks.filter((t: TaskItem) => t.type === 'survey')
  }

  syncAnswers(): void {
    let t = this.current()
    if (t === undefined) {
      this.answers = []
      return
    }
    let mine = this.myResponse(t)
    if (mine !== undefined) {
      this.answers = mine.answers.slice()
      this.submitted = true
    } else {
      let arr: string[] = []
      for (let i = 0; i < t.surveyQuestions.length; i++) {
        arr.push('')
      }
      this.answers = arr
      this.submitted = false
    }
  }

  myResponse(t: TaskItem): SurveyResponse | undefined {
    let mine = t.responses.filter((r: SurveyResponse) => r.student === this.nickname && r.student !== '')
    return mine.length > 0 ? mine[mine.length - 1] : undefined
  }

  createNew(): void {
    let q1 = new SurveyQuestion('1. 请编辑问卷题目', 'single')
    q1.opts = ['选项A', '选项B']
    let t = newSurveyTask('调查问卷', [q1], true)
    this.tasks = [t].concat(this.tasks)
    this.taskId = t.id
    this.tab = 'edit'
    this.syncAnswers()
  }

  openEditor(q: SurveyQuestion): void {
    this.editingId = q.id
    this.editTitle = q.title
    this.editType = q.type
    this.editOpts = q.opts.slice()
    this.editScale = q.maxScale
  }

  switchType(tp: SurveyType): void {
    this.editType = tp
    this.editOpts = (tp === 'single' || tp === 'multi') ? ['选项A', '选项B'] : []
    this.editScale = 5
  }

  addQuestion(tp: SurveyType): void {
    let t = this.current()
    if (t === undefined) {
      return
    }
    let q = new SurveyQuestion('新题目', tp)
    t.surveyQuestions = t.surveyQuestions.concat([q])
    this.tasks = this.tasks.slice()
    this.openEditor(q)
  }

  saveQuestion(q: SurveyQuestion): void {
    if (this.editTitle.trim() === '') {
      promptAction.showToast({ message: '请填写题目' })
      return
    }
    q.title = this.editTitle.trim()
    q.type = this.editType
    q.opts = (this.editType === 'single' || this.editType === 'multi') ? this.editOpts.slice() : []
    q.maxScale = this.editScale
    this.tasks = this.tasks.slice()
    this.editingId = ''
    promptAction.showToast({ message: '题目已保存' })
  }

  deleteQuestion(q: SurveyQuestion): void {
    let t = this.current()
    if (t === undefined) {
      return
    }
    t.surveyQuestions = t.surveyQuestions.filter((x: SurveyQuestion) => x.id !== q.id)
    this.tasks = this.tasks.slice()
    if (this.editingId === q.id) {
      this.editingId = ''
    }
  }

  setAnonymous(v: boolean, t: TaskItem): void {
    if (t.responses.length > 0) {
      promptAction.showToast({ message: '已有作答，不能再修改匿名设置' })
      return
    }
    t.anonymous = v
    this.tasks = this.tasks.slice()
  }

  publish(t: TaskItem): void {
    if (t.surveyQuestions.length === 0) {
      promptAction.showToast({ message: '请先添加题目' })
      return
    }
    launchTask(t)
    this.tasks = this.tasks.slice()
    notifyTask(t, `【调查问卷】${t.title} 已发布（${t.anonymous ? '匿名' : '实名'}），请同学们填写。`)
    promptAction.showToast({ message: '问卷已发布' })
  }

  finish(t: TaskItem): void {
    AlertDialog.show({
      title: '提前结束',
      message: '结束后学生无法继续填写。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '结束', fontColor: '#F59E0B', action: () => {
          endTask(t)
          this.tasks = this.tasks.slice()
          notifyTask(t, `【调查问卷】${t.title} 已结束。`)
          promptAction.showToast({ message: '问卷已结束' })
        }
      }
    })
  }

  revoke(t: TaskItem): void {
    AlertDialog.show({
      title: '撤回问卷',
      message: '撤回后学生无法继续填写，已收到的作答会保留。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '撤回', fontColor: '#EF4444', action: () => {
          withdrawTask(t)
          this.tasks = this.tasks.slice()
          notifyTask(t, `【调查问卷】${t.title} 已被撤回。`)
          promptAction.showToast({ message: '问卷已撤回' })
        }
      }
    })
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

  toggleMulti(i: number, oi: number): void {
    let cur = this.answerAt(i) === '' ? [] : this.answerAt(i).split(',')
    let key = String(oi)
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

  isChecked(i: number, oi: number): boolean {
    return this.answerAt(i).split(',').includes(String(oi))
  }

  submit(t: TaskItem): void {
    if (this.canManage()) {
      promptAction.showToast({ message: '预览模式：不会记录作答数据' })
      return
    }
    if (effectiveStatus(t, this.now) !== 'ongoing') {
      promptAction.showToast({ message: '问卷已结束，无法提交' })
      return
    }
    if (!t.anonymous && this.myResponse(t) !== undefined) {
      promptAction.showToast({ message: '你已提交过该问卷' })
      return
    }
    let res = new SurveyResponse(t.anonymous ? '' : this.nickname, this.answers.slice())
    t.responses = t.responses.concat([res])
    this.tasks = this.tasks.slice()
    this.submitted = true
    promptAction.showToast({ message: t.anonymous ? '提交成功（匿名，不记录个人信息）' : '提交成功' })
  }

  typeName(t: string): string {
    if (t === 'single') {
      return '单选'
    }
    if (t === 'multi') {
      return '多选'
    }
    if (t === 'scale') {
      return '量表'
    }
    return '简答'
  }

  // ---------------- 视图 ----------------
  @Builder
  header() {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(20).fontColor([$r('app.color.text_main')])
        .onClick(() => router.back())
      Column({ space: 2 }) {
        Text('调查问卷').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
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
    if (this.surveyTasks().length > 0) {
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.surveyTasks(), (t: TaskItem) => {
            Text(`${t.title}${effectiveStatus(t, this.now) === 'pending' ? '（草稿）' : ''}`)
              .fontSize(12)
              .fontColor(this.taskId === t.id ? Color.White : $r('app.color.text_main'))
              .backgroundColor(this.taskId === t.id ? '#3F7EF6' : $r('app.color.field_bg'))
              .padding({ left: 12, right: 12, top: 6, bottom: 6 }).borderRadius(14)
              .onClick(() => {
                this.taskId = t.id
                this.editingId = ''
                this.syncAnswers()
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
  questionEditor(q: SurveyQuestion) {
    Column({ space: 10 }) {
      TextArea({ text: this.editTitle, placeholder: '请输入题目' })
        .height(60).fontSize(13).backgroundColor($r('app.color.field_bg')).borderRadius(8)
        .onChange((v: string) => {
          this.editTitle = v
        })
      Scroll() {
        Row({ space: 6 }) {
          ForEach(['single', 'multi', 'scale', 'essay'] as SurveyType[], (tp: SurveyType) => {
            Text(this.typeName(tp))
              .fontSize(11)
              .fontColor(this.editType === tp ? Color.White : $r('app.color.text_main'))
              .backgroundColor(this.editType === tp ? '#3F7EF6' : $r('app.color.field_bg'))
              .padding({ left: 10, right: 10, top: 4, bottom: 4 }).borderRadius(10)
              .onClick(() => this.switchType(tp))
          }, (tp: SurveyType) => tp)
        }
      }.scrollBar(BarState.Off)

      if (this.editType === 'single' || this.editType === 'multi') {
        ForEach(this.editOpts, (o: string, i: number) => {
          Row({ space: 8 }) {
            Text(`${String.fromCharCode(65 + i)}`).fontSize(12).fontColor($r('app.color.text_sub')).width(18)
            TextInput({ text: this.editOpts[i], placeholder: `选项 ${i + 1}` })
              .height(34).fontSize(13).layoutWeight(1)
              .backgroundColor($r('app.color.field_bg')).borderRadius(8)
              .onChange((v: string) => {
                let arr = this.editOpts.slice()
                arr[i] = v
                this.editOpts = arr
              })
            if (this.editOpts.length > 2) {
              Text('删除').fontSize(11).fontColor('#EF4444')
                .onClick(() => {
                  this.editOpts = this.editOpts.filter((x: string, idx: number) => idx !== i)
                })
            }
          }.width('100%')
        }, (o: string, i: number) => `sopt_${i}_${o}`)
        Text('+ 添加选项').fontSize(12).fontColor('#3F7EF6')
          .onClick(() => {
            this.editOpts = this.editOpts.concat([`选项${String.fromCharCode(65 + this.editOpts.length)}`])
          })
      } else if (this.editType === 'scale') {
        Row() {
          Text('量表分值').fontSize(13).fontColor($r('app.color.text_main')).layoutWeight(1)
          Text(`1 - ${this.editScale}`).fontSize(13).fontColor('#3F7EF6')
        }.width('100%')
        Slider({ value: this.editScale, min: 3, max: 10, step: 1 })
          .selectedColor('#3F7EF6')
          .onChange((v: number) => {
            this.editScale = v
          })
      } else {
        Text('简答题由学生自由填写，统计页展示全部作答').fontSize(11).fontColor($r('app.color.text_hint')).width('100%')
      }

      Row({ space: 10 }) {
        Text('取消').fontSize(13).fontColor($r('app.color.text_sub'))
          .layoutWeight(1).height(36).textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.field_bg')).borderRadius(18)
          .onClick(() => {
            this.editingId = ''
          })
        Text('保存').fontSize(13).fontColor(Color.White)
          .layoutWeight(1).height(36).textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.primary')).borderRadius(18)
          .onClick(() => this.saveQuestion(q))
      }.width('100%')
    }
    .width('100%').padding(12).backgroundColor($r('app.color.field_bg')).borderRadius(10)
  }

  @Builder
  questionCard(q: SurveyQuestion, i: number) {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text(`${i + 1}`).fontSize(11).fontColor(Color.White)
          .width(20).height(20).textAlign(TextAlign.Center)
          .backgroundColor('#3F7EF6').borderRadius(10)
        Text(this.typeName(q.type)).fontSize(10).fontColor('#3F7EF6')
          .padding({ left: 6, right: 6, top: 1, bottom: 1 })
          .border({ width: 1, color: '#3F7EF6' }).borderRadius(8)
        Blank()
        Text('编辑').fontSize(11).fontColor('#3F7EF6').onClick(() => this.openEditor(q))
        Text('删除').fontSize(11).fontColor('#EF4444').onClick(() => this.deleteQuestion(q))
      }.width('100%')
      Text(q.title).fontSize(13).fontColor($r('app.color.text_main')).width('100%').lineHeight(19)
      if (q.opts.length > 0) {
        Text(q.opts.map((o: string, oi: number) => `${String.fromCharCode(65 + oi)}. ${o}`).join('   '))
          .fontSize(11).fontColor($r('app.color.text_hint')).width('100%').maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      if (q.type === 'scale') {
        Text(`量表：1 - ${q.maxScale} 分`).fontSize(11).fontColor($r('app.color.text_hint'))
      }
    }
    .width('92%').padding(12).backgroundColor($r('app.color.card_bg')).borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  editTab(t: TaskItem) {
    Scroll() {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text('+ 单选').fontSize(11).fontColor('#3F7EF6').onClick(() => this.addQuestion('single'))
          Text('+ 多选').fontSize(11).fontColor('#3F7EF6').onClick(() => this.addQuestion('multi'))
          Text('+ 量表').fontSize(11).fontColor('#3F7EF6').onClick(() => this.addQuestion('scale'))
          Text('+ 简答').fontSize(11).fontColor('#3F7EF6').onClick(() => this.addQuestion('essay'))
        }.width('92%').padding({ top: 4, bottom: 4 })
        ForEach(t.surveyQuestions, (q: SurveyQuestion, i: number) => {
          if (this.editingId === q.id) {
            Column() {
              this.questionEditor(q)
            }.width('92%')
          } else {
            this.questionCard(q, i)
          }
        }, (q: SurveyQuestion) => q.id)
        if (t.surveyQuestions.length === 0) {
          Text('暂无题目，点击上方按钮添加').fontSize(13).fontColor($r('app.color.text_hint')).margin({ top: 30 })
        }
        Blank().height(30)
      }.width('100%')
    }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
  }

  @Builder
  settingTab(t: TaskItem) {
    Scroll() {
      Column({ space: 12 }) {
        TextInput({ text: t.title, placeholder: '问卷标题' })
          .height(42).fontSize(14).backgroundColor($r('app.color.card_bg')).borderRadius(10)
          .onChange((v: string) => {
            t.title = v
            this.tasks = this.tasks.slice()
          })

        Column({ space: 10 }) {
          Row() {
            Column({ space: 2 }) {
              Text('匿名发布').fontSize(13).fontColor($r('app.color.text_main'))
              Text('匿名问卷不记录学生标识，不关联个人信息').fontSize(10).fontColor($r('app.color.text_hint'))
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: t.anonymous })
              .selectedColor('#3F7EF6')
              .onChange((v: boolean) => this.setAnonymous(v, t))
          }.width('100%')
          Row() {
            Text('截止时间').fontSize(13).fontColor($r('app.color.text_main')).layoutWeight(1)
            Text(t.endAt > 0 ? fmtDateTime(t.endAt) : '不限时')
              .fontSize(12).fontColor('#3F7EF6')
              .onClick(() => this.endController.open())
          }.width('100%')
        }.width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(12)
        .alignItems(HorizontalAlign.Start)

        Row({ space: 10 }) {
          if (t.status === 'pending') {
            Text('发布问卷').fontSize(14).fontColor(Color.White)
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

        Text('本地演示：无后端问卷服务，作答与统计保存在本机。')
          .fontSize(11).fontColor($r('app.color.text_hint')).width('92%')
        Blank().height(30)
      }.width('100%').padding({ top: 6 })
    }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
  }

  @Builder
  optionStat(t: TaskItem, qi: number, o: string, oi: number) {
    Column({ space: 4 }) {
      Row() {
        Text(`${String.fromCharCode(65 + oi)}. ${o}`).fontSize(12).fontColor($r('app.color.text_main')).layoutWeight(1)
        Text(`${surveyOptionCount(t, qi, oi)} 人`)
          .fontSize(11).fontColor($r('app.color.text_sub'))
      }.width('100%')
      Row() {
        Row()
          .width(`${t.responses.length > 0 ? surveyOptionCount(t, qi, oi) / t.responses.length * 100 : 0}%`)
          .height(5).backgroundColor('#3F7EF6').borderRadius(3)
      }.width('100%').height(5).backgroundColor($r('app.color.field_bg')).borderRadius(3)
    }.width('100%')
  }

  @Builder
  statsTab(t: TaskItem) {
    Scroll() {
      Column({ space: 10 }) {
        Column({ space: 4 }) {
          Text(t.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).width('100%')
          Text(`${t.anonymous ? '匿名问卷' : '实名问卷'} · 已收到 ${t.responses.length} 份 · ${statusName(effectiveStatus(t, this.now))}`)
            .fontSize(11).fontColor($r('app.color.text_sub')).width('100%')
          Text('本地模拟统计，无后端汇总服务')
            .fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
        }.width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(12)
        .alignItems(HorizontalAlign.Start)

        ForEach(t.surveyQuestions, (q: SurveyQuestion, qi: number) => {
          Column({ space: 8 }) {
            Text(`${qi + 1}. ${q.title}`).fontSize(13).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_main')).width('100%')
            Text(this.typeName(q.type)).fontSize(10).fontColor('#3F7EF6')
            if (q.type === 'single' || q.type === 'multi') {
              ForEach(q.opts, (o: string, oi: number) => {
                this.optionStat(t, qi, o, oi)
              }, (o: string, oi: number) => `stat_${q.id}_${oi}`)
            } else if (q.type === 'scale') {
              Column({ space: 4 }) {
                Text(`平均分 ${surveyScaleAvg(t, qi)} / ${q.maxScale}`)
                  .fontSize(12).fontColor('#3F7EF6').width('100%')
                Row() {
                  Row()
                    .width(`${q.maxScale > 0 ? surveyScaleAvg(t, qi) / q.maxScale * 100 : 0}%`)
                    .height(5).backgroundColor('#3F7EF6').borderRadius(3)
                }.width('100%').height(5).backgroundColor($r('app.color.field_bg')).borderRadius(3)
              }.width('100%')
            } else {
              Column({ space: 6 }) {
                ForEach(t.responses, (r: SurveyResponse, ri: number) => {
                  if (r.answers[qi] !== undefined && r.answers[qi] !== '') {
                    Column({ space: 2 }) {
                      Text(t.anonymous ? `匿名同学 ${ri + 1}` : r.student)
                        .fontSize(10).fontColor($r('app.color.text_hint'))
                      Text(r.answers[qi]).fontSize(12).fontColor($r('app.color.text_main'))
                    }.width('100%').padding(8).backgroundColor($r('app.color.field_bg')).borderRadius(8)
                    .alignItems(HorizontalAlign.Start)
                  }
                }, (r: SurveyResponse) => `essay_${q.id}_${r.id}`)
              }.width('100%')
            }
          }.width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(12)
          .alignItems(HorizontalAlign.Start)
        }, (q: SurveyQuestion) => `statq_${q.id}`)
        Blank().height(30)
      }.width('100%').padding({ top: 6 }).alignItems(HorizontalAlign.Center)
    }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
  }

  @Builder
  answerTab(t: TaskItem) {
    Scroll() {
      Column({ space: 10 }) {
        Column({ space: 4 }) {
          Row() {
            Text(t.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).layoutWeight(1)
            Text(statusName(effectiveStatus(t, this.now))).fontSize(11).fontColor(Color.White)
              .backgroundColor(statusColor(effectiveStatus(t, this.now)))
              .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(10)
          }.width('100%')
          Text(`${t.anonymous ? '匿名问卷' : '实名问卷'} · ${t.surveyQuestions.length} 题`)
            .fontSize(11).fontColor($r('app.color.text_sub')).width('100%')
          if (t.endAt > 0) {
            Text(`截止 ${fmtDateTime(t.endAt)} · ${remainText(t.endAt, this.now)}`)
              .fontSize(11).fontColor($r('app.color.text_hint')).width('100%')
          }
          if (t.anonymous) {
            Text('匿名提交，不记录你的姓名与个人信息（本地演示）')
              .fontSize(10).fontColor('#10B981').width('100%')
          }
        }.width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(12)
        .alignItems(HorizontalAlign.Start)

        if (this.submitted && (t.anonymous || this.myResponse(t) !== undefined)) {
          Text('已提交，感谢参与')
            .fontSize(13).fontColor('#10B981').width('92%').padding(12)
            .backgroundColor('#E8F7F0').borderRadius(10).textAlign(TextAlign.Center)
        }

        ForEach(t.surveyQuestions, (q: SurveyQuestion, i: number) => {
          Column({ space: 8 }) {
            Text(`${i + 1}. ${q.title}`).fontSize(14).fontColor($r('app.color.text_main')).width('100%').lineHeight(20)
            if (q.type === 'single') {
              ForEach(q.opts, (o: string, oi: number) => {
                Row({ space: 8 }) {
                  Circle().width(16).height(16)
                    .fill(this.answerAt(i) === String(oi) ? '#3F7EF6' : $r('app.color.field_bg'))
                  Text(`${String.fromCharCode(65 + oi)}. ${o}`).fontSize(13).fontColor($r('app.color.text_main')).layoutWeight(1)
                }.width('100%').padding({ top: 5, bottom: 5 })
                .onClick(() => {
                  if (!this.submitted && effectiveStatus(t, this.now) === 'ongoing') {
                    this.setAnswer(i, String(oi))
                  }
                })
              }, (o: string, oi: number) => `aopt_${i}_${oi}`)
            } else if (q.type === 'multi') {
              ForEach(q.opts, (o: string, oi: number) => {
                Row({ space: 8 }) {
                  Circle().width(16).height(16)
                    .fill(this.isChecked(i, oi) ? '#3F7EF6' : $r('app.color.field_bg'))
                  Text(`${String.fromCharCode(65 + oi)}. ${o}`).fontSize(13).fontColor($r('app.color.text_main')).layoutWeight(1)
                }.width('100%').padding({ top: 5, bottom: 5 })
                .onClick(() => {
                  if (!this.submitted && effectiveStatus(t, this.now) === 'ongoing') {
                    this.toggleMulti(i, oi)
                  }
                })
              }, (o: string, oi: number) => `amopt_${i}_${oi}`)
            } else if (q.type === 'scale') {
              Row({ space: 6 }) {
                ForEach(this.scaleRange(q.maxScale), (n: number) => {
                  Text(`${n}`).fontSize(13)
                    .fontColor(this.answerAt(i) === String(n) ? Color.White : $r('app.color.text_main'))
                    .width(32).height(32).textAlign(TextAlign.Center)
                    .backgroundColor(this.answerAt(i) === String(n) ? '#3F7EF6' : $r('app.color.field_bg'))
                    .borderRadius(16)
                    .onClick(() => {
                      if (!this.submitted) {
                        this.setAnswer(i, String(n))
                      }
                    })
                }, (n: number) => `scale_${i}_${n}`)
              }.width('100%')
            } else {
              TextArea({ text: this.answerAt(i), placeholder: '请输入你的回答' })
                .height(80).fontSize(13).backgroundColor($r('app.color.field_bg')).borderRadius(8)
                .onChange((v: string) => {
                  if (!this.submitted) {
                    this.setAnswer(i, v)
                  }
                })
            }
          }.width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(12)
          .alignItems(HorizontalAlign.Start)
        }, (q: SurveyQuestion) => `aq_${q.id}`)

        if (!this.submitted && effectiveStatus(t, this.now) === 'ongoing') {
          Text('提交问卷')
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
            .height(44).width('92%').textAlign(TextAlign.Center)
            .backgroundColor($r('app.color.primary')).borderRadius(22)
            .onClick(() => this.submit(t))
        }
        Blank().height(30)
      }.width('100%').padding({ top: 6 }).alignItems(HorizontalAlign.Center)
    }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
  }

  scaleRange(max: number): number[] {
    let arr: number[] = []
    for (let i = 1; i <= max; i++) {
      arr.push(i)
    }
    return arr
  }

  build() {
    Column() {
      this.header()
      this.taskChips()
      if (this.current() === undefined) {
        Column({ space: 10 }) {
          Text('暂无调查问卷').fontSize(14).fontColor($r('app.color.text_sub'))
          if (this.canManage()) {
            Text('新建问卷').fontSize(14).fontColor(Color.White)
              .padding({ left: 18, right: 18, top: 9, bottom: 9 })
              .backgroundColor($r('app.color.primary')).borderRadius(20)
              .onClick(() => this.createNew())
          }
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.canManage()) {
        Row({ space: 8 }) {
          this.tabChip('edit', '出题')
          this.tabChip('setting', '设置')
          this.tabChip('stats', '统计')
          this.tabChip('answer', '预览作答')
        }.width('100%').padding({ left: 16, right: 16, bottom: 8 })
        if (this.tab === 'edit') {
          this.editTab(this.current()!)
        } else if (this.tab === 'setting') {
          this.settingTab(this.current()!)
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
  }
}
