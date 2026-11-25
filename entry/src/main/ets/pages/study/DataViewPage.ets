import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { PracticeQuestion, SurveyQuestion } from '../../model/DataModel'
import {
  TaskItem,
  SigninEntry,
  PracticeSubmission,
  SurveyResponse,
  PickEntry,
  findTask,
  effectiveStatus,
  statusName,
  statusColor,
  taskTypeName,
  taskTypeIcon,
  signinModeName,
  signinStatusName,
  fmtClock,
  fmtDateTime,
  countSigned,
  countLeave,
  countAbsent,
  submissionScore,
  isObjectiveQuestion,
  objectiveScore,
  surveyOptionCount,
  surveyScaleAvg,
  classStudents,
  signinCsvRows,
  practiceCsvRows,
  nowTs
} from '../../model/InteractionModel'
import { CsvExport } from '../../utils/CsvExport'
import { Guard } from '../../utils/Guard'

// ==================== 互动任务数据 ====================
// 🌟 教师 / 助教：任务详情、学生完成台账与作答统计
// 🌟 签到台账明确标记「已签到 / 未签到 / 请假」，支持补签与导出
// ⚠️ 本地演示：统计数据来自本机台账，无后端报表服务；导出为 Excel 兼容 CSV
@Entry
@Component
export struct DataViewPage {
  @StorageLink('interactionTasks') tasks: TaskItem[] = []
  @StorageLink('userRole') userRole: string = 'student'
  @State taskId: string = ''
  @State filter: string = 'all'
  @State now: number = Date.now()
  private timer: number = -1

  aboutToAppear(): void {
    // 🌟 台账仅对授课教师 / 助教 / 管理员开放，学生不可查看班级数据
    if (!Guard.staff('查看教学台账')) {
      router.back()
      return
    }
    let params = router.getParams() as Record<string, string>
    let wantId = params !== undefined && params['taskId'] !== undefined ? params['taskId'] : ''
    if (wantId !== '') {
      this.taskId = wantId
    } else if (this.tasks.length > 0) {
      this.taskId = this.tasks[0].id
    }
    this.now = Date.now()
    this.timer = setInterval(() => {
      this.now = Date.now()
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

  exportSignin(t: TaskItem): void {
    try {
      let ctx = getContext(this) as common.UIAbilityContext
      let path = CsvExport.write(ctx, `signin_${t.id}.csv`, signinCsvRows(t))
      AlertDialog.show({
        title: '导出完成（CSV）',
        message: `签到台账已导出为 Excel 兼容 CSV：\n${path}\n\n端上不生成真正的 .xlsx，请用 Excel / WPS 打开。`,
        confirm: { value: '知道了', action: () => {} }
      })
    } catch (e) {
      promptAction.showToast({ message: '导出失败' })
    }
  }

  exportPractice(t: TaskItem): void {
    try {
      let ctx = getContext(this) as common.UIAbilityContext
      let path = CsvExport.write(ctx, `practice_${t.id}.csv`, practiceCsvRows(t))
      AlertDialog.show({
        title: '导出完成（CSV）',
        message: `练习成绩已导出为 Excel 兼容 CSV：\n${path}\n\n端上不生成真正的 .xlsx，请用 Excel / WPS 打开。`,
        confirm: { value: '知道了', action: () => {} }
      })
    } catch (e) {
      promptAction.showToast({ message: '导出失败' })
    }
  }

  makeup(t: TaskItem, e: SigninEntry): void {
    e.status = 'makeup'
    e.time = nowTs()
    e.method = '教师补签'
    e.note = '教师手动补签'
    this.tasks = this.tasks.slice()
    promptAction.showToast({ message: `已为 ${e.student} 补签` })
  }

  leave(t: TaskItem, e: SigninEntry): void {
    e.status = 'leave'
    e.time = 0
    e.method = ''
    e.note = '教师标记请假'
    this.tasks = this.tasks.slice()
    promptAction.showToast({ message: `已标记 ${e.student} 请假` })
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

  submittedNames(t: TaskItem): number {
    let names: string[] = []
    t.submissions.forEach((s: PracticeSubmission) => {
      if (!names.includes(s.student)) {
        names.push(s.student)
      }
    })
    return names.length
  }

  unsubmittedNames(t: TaskItem): string[] {
    let names: string[] = []
    classStudents().forEach((n: string) => {
      let hit = t.submissions.filter((s: PracticeSubmission) => s.student === n)
      if (hit.length === 0) {
        names.push(n)
      }
    })
    return names
  }

  @Builder
  header() {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(20).fontColor([$r('app.color.text_main')])
        .onClick(() => router.back())
      Column({ space: 2 }) {
        Text('任务数据').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Text(`${this.userRole === 'assistant' ? '助教' : '授课教师'}视角 · 本地台账`)
          .fontSize(11).fontColor($r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }
    .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 8 })
  }

  @Builder
  taskSwitcher() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.tasks, (t: TaskItem) => {
          Text(`${taskTypeIcon(t.type)} ${t.title}`)
            .fontSize(12)
            .fontColor(this.taskId === t.id ? Color.White : $r('app.color.text_main'))
            .backgroundColor(this.taskId === t.id ? '#3F7EF6' : $r('app.color.field_bg'))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 }).borderRadius(14)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .onClick(() => {
              this.taskId = t.id
              this.filter = 'all'
            })
        }, (t: TaskItem) => t.id)
      }.padding({ left: 16, right: 16 })
    }.scrollBar(BarState.Off).width('100%').margin({ bottom: 8 })
  }

  @Builder
  summary(t: TaskItem) {
    Column({ space: 6 }) {
      Row() {
        Text(`${taskTypeIcon(t.type)} ${t.title}`).fontSize(16).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_main')).layoutWeight(1)
        Text(statusName(effectiveStatus(t, this.now))).fontSize(11).fontColor(Color.White)
          .backgroundColor(statusColor(effectiveStatus(t, this.now)))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(10)
      }.width('100%')
      Text(`${taskTypeName(t.type)} · 发起人 ${t.teacherName === '' ? '教师' : t.teacherName}`)
        .fontSize(11).fontColor($r('app.color.text_sub')).width('100%')
      if (t.endAt > 0) {
        Text(`截止 ${fmtDateTime(t.endAt)}`).fontSize(11).fontColor($r('app.color.text_hint')).width('100%')
      }
      if (t.status === 'withdrawn') {
        Text(`已撤回于 ${fmtDateTime(t.withdrawnAt)}，学生无法继续作答`)
          .fontSize(11).fontColor('#EF4444').width('100%')
      }
    }
    .width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(14)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  statBox(label: string, value: string, color: string) {
    Column({ space: 2 }) {
      Text(value).fontSize(18).fontWeight(FontWeight.Bold).fontColor(color)
      Text(label).fontSize(11).fontColor($r('app.color.text_sub'))
    }
    .layoutWeight(1).padding(10).backgroundColor($r('app.color.card_bg')).borderRadius(10)
    .alignItems(HorizontalAlign.Center)
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
      if (this.canManage() && e.status === 'absent') {
        Text('补签').fontSize(11).fontColor('#3F7EF6').padding({ left: 6, right: 6 })
          .onClick(() => this.makeup(t, e))
        Text('请假').fontSize(11).fontColor('#F59E0B').padding({ left: 6, right: 6 })
          .onClick(() => this.leave(t, e))
      }
    }
    .width('100%').padding({ top: 10, bottom: 10, left: 12, right: 12 })
  }

  @Builder
  signinView(t: TaskItem) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        this.statBox('已签到', `${countSigned(t)}`, '#10B981')
        this.statBox('未签到', `${countAbsent(t)}`, '#EF4444')
        this.statBox('请假', `${countLeave(t)}`, '#F59E0B')
      }.width('92%')
      Row({ space: 8 }) {
        Text(`签到方式：${signinModeName(t.signinMode)}`).fontSize(11).fontColor($r('app.color.text_sub'))
        Blank()
        Text('导出签到台账（CSV）').fontSize(12).fontColor('#3F7EF6')
          .onClick(() => this.exportSignin(t))
      }.width('92%')
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
      }.width('92%')
      Column({ space: 0 }) {
        ForEach(this.visibleEntries(t), (e: SigninEntry) => {
          this.ledgerRow(t, e)
          Divider().color($r('app.color.divider_color')).margin({ left: 12, right: 12 })
        }, (e: SigninEntry) => `${e.student}_${e.status}_${e.time}`)
      }.width('92%').backgroundColor($r('app.color.card_bg')).borderRadius(12).clip(true)
      Text('签到状态明确区分「已签到 / 未签到 / 请假 / 补签」；数据为本机台账。')
        .fontSize(10).fontColor($r('app.color.text_hint')).width('92%')
    }.width('100%').alignItems(HorizontalAlign.Center)
  }

  @Builder
  practiceView(t: TaskItem) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        this.statBox('参与人数', `${this.submittedNames(t)}/${t.total}`, '#3F7EF6')
        this.statBox('提交次数', `${t.submissions.length}`, '#10B981')
        this.statBox('平均分', `${this.avgScore(t)}`, '#F59E0B')
      }.width('92%')
      Row({ space: 8 }) {
        Text(`客观题满分 ${t.questions.length > 0 ? Math.round(100 / t.questions.length *
          t.questions.filter((q: PracticeQuestion) => isObjectiveQuestion(q)).length * 10) / 10 : 0} 分`)
          .fontSize(11).fontColor($r('app.color.text_sub'))
        Blank()
        Text('导出成绩（CSV）').fontSize(12).fontColor('#3F7EF6')
          .onClick(() => this.exportPractice(t))
      }.width('92%')

      Column({ space: 8 }) {
        Text('提交记录').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).width('100%')
        ForEach(t.submissions, (s: PracticeSubmission) => {
          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Text(`${s.student} · 第 ${s.attempt} 次${s.late ? '（迟交）' : ''}`)
                .fontSize(12).fontColor($r('app.color.text_main'))
              Text(`${fmtClock(s.submitAt)} · 客观 ${s.objectiveScore} + 主观 ${s.subjectiveScore}`)
                .fontSize(10).fontColor($r('app.color.text_hint'))
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text(`${submissionScore(s)} 分`).fontSize(13).fontWeight(FontWeight.Bold).fontColor('#3F7EF6')
            Text(s.graded ? '已批阅' : '待批阅').fontSize(10)
              .fontColor(s.graded ? '#10B981' : '#F59E0B')
          }.width('100%').padding({ top: 8, bottom: 8 })
        }, (s: PracticeSubmission) => s.id)
        if (t.submissions.length === 0) {
          Text('暂无提交记录').fontSize(12).fontColor($r('app.color.text_hint')).width('100%')
        }
      }.width('92%').padding(12).backgroundColor($r('app.color.card_bg')).borderRadius(12)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 8 }) {
        Text('客观题正确率').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).width('100%')
        ForEach(t.questions, (q: PracticeQuestion, i: number) => {
          if (isObjectiveQuestion(q)) {
            Column({ space: 4 }) {
              Text(`${i + 1}. ${q.title}`).fontSize(11).fontColor($r('app.color.text_main')).width('100%')
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              Row() {
                Row().width(`${this.accuracy(t, i)}%`).height(5).backgroundColor('#3F7EF6').borderRadius(3)
              }.width('100%').height(5).backgroundColor($r('app.color.field_bg')).borderRadius(3)
              Text(`正确率 ${this.accuracy(t, i)}%`).fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
            }.width('100%')
          }
        }, (q: PracticeQuestion) => `dv_${q.id}`)
      }.width('92%').padding(12).backgroundColor($r('app.color.card_bg')).borderRadius(12)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text('未提交学生').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).width('100%')
        Text(this.unsubmittedNames(t).length === 0 ? '全部学生已提交' : this.unsubmittedNames(t).join('、'))
          .fontSize(12).fontColor($r('app.color.text_sub')).width('100%')
        Text('迟到提交按教师配置的扣分比例折算总分。').fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
      }.width('92%').padding(12).backgroundColor($r('app.color.card_bg')).borderRadius(12)
      .alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(HorizontalAlign.Center)
  }

  @Builder
  surveyView(t: TaskItem) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        this.statBox('回收份数', `${t.responses.length}`, '#3F7EF6')
        this.statBox('发布方式', t.anonymous ? '匿名' : '实名', '#10B981')
        this.statBox('题目数', `${t.surveyQuestions.length}`, '#F59E0B')
      }.width('92%')
      if (t.anonymous) {
        Text('匿名问卷：作答记录不关联学生个人信息，统计中不展示姓名。')
          .fontSize(10).fontColor('#10B981').width('92%')
      }
      ForEach(t.surveyQuestions, (q: SurveyQuestion, qi: number) => {
        Column({ space: 8 }) {
          Text(`${qi + 1}. ${q.title}`).fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_main')).width('100%')
          if (q.type === 'single' || q.type === 'multi') {
            ForEach(q.opts, (o: string, oi: number) => {
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
            }, (o: string, oi: number) => `dvopt_${q.id}_${oi}`)
          } else if (q.type === 'scale') {
            Text(`平均分 ${surveyScaleAvg(t, qi)} / ${q.maxScale}`)
              .fontSize(12).fontColor('#3F7EF6').width('100%')
            Row() {
              Row()
                .width(`${q.maxScale > 0 ? surveyScaleAvg(t, qi) / q.maxScale * 100 : 0}%`)
                .height(5).backgroundColor('#3F7EF6').borderRadius(3)
            }.width('100%').height(5).backgroundColor($r('app.color.field_bg')).borderRadius(3)
          } else {
            ForEach(t.responses, (r: SurveyResponse, ri: number) => {
              if (r.answers[qi] !== undefined && r.answers[qi] !== '') {
                Column({ space: 2 }) {
                  Text(t.anonymous ? `匿名同学 ${ri + 1}` : r.student).fontSize(10).fontColor($r('app.color.text_hint'))
                  Text(r.answers[qi]).fontSize(12).fontColor($r('app.color.text_main'))
                }.width('100%').padding(8).backgroundColor($r('app.color.field_bg')).borderRadius(8)
                .alignItems(HorizontalAlign.Start)
              }
            }, (r: SurveyResponse) => `dvessay_${q.id}_${r.id}`)
          }
        }.width('92%').padding(12).backgroundColor($r('app.color.card_bg')).borderRadius(12)
        .alignItems(HorizontalAlign.Start)
      }, (q: SurveyQuestion) => `dvsq_${q.id}`)
    }.width('100%').alignItems(HorizontalAlign.Center)
  }

  @Builder
  randomView(t: TaskItem) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        this.statBox('抽选次数', `${t.picks.length}`, '#3F7EF6')
        this.statBox('已完成', `${t.picks.filter((p: PickEntry) => p.resolution === 'answered').length}`, '#10B981')
        this.statBox('拒绝', `${t.picks.filter((p: PickEntry) => p.resolution === 'refused').length}`, '#EF4444')
      }.width('92%')
      Column({ space: 0 }) {
        ForEach(t.picks, (p: PickEntry) => {
          Row({ space: 8 }) {
            Column({ space: 3 }) {
              Text(p.student).fontSize(14).fontColor($r('app.color.text_main'))
              Text(`${fmtDateTime(p.pickedAt)}${p.remark === '' ? '' : ` · 备注：${p.remark}`}`)
                .fontSize(10).fontColor($r('app.color.text_hint'))
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text(p.resolution === 'answered' ? '已完成答题' : p.resolution === 'refused' ? '拒绝作答' : '待作答')
              .fontSize(11)
              .fontColor(p.resolution === 'answered' ? '#10B981' : p.resolution === 'refused' ? '#EF4444' : '#F59E0B')
          }.width('100%').padding({ top: 10, bottom: 10, left: 12, right: 12 })
          Divider().color($r('app.color.divider_color')).margin({ left: 12, right: 12 })
        }, (p: PickEntry) => p.id)
        if (t.picks.length === 0) {
          Text('暂无抽选记录').fontSize(12).fontColor($r('app.color.text_hint')).padding(16)
        }
      }.width('92%').backgroundColor($r('app.color.card_bg')).borderRadius(12).clip(true)
      Text('抽选记录计入互动任务台账；通知为本地模拟，无真实推送服务。')
        .fontSize(10).fontColor($r('app.color.text_hint')).width('92%')
    }.width('100%').alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      this.header()
      if (!this.canManage()) {
        Column({ space: 8 }) {
          Text('仅授课教师 / 助教可查看任务数据').fontSize(14).fontColor($r('app.color.text_sub'))
          Text('学生可在对应任务页查看自己的作答与学分').fontSize(11).fontColor($r('app.color.text_hint'))
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.current() === undefined) {
        Text('暂无任务数据').fontSize(14).fontColor($r('app.color.text_hint'))
          .width('100%').layoutWeight(1).textAlign(TextAlign.Center)
      } else {
        this.taskSwitcher()
        Scroll() {
          Column({ space: 12 }) {
            this.summary(this.current()!)
            if (this.current()!.type === 'signin') {
              this.signinView(this.current()!)
            } else if (this.current()!.type === 'practice') {
              this.practiceView(this.current()!)
            } else if (this.current()!.type === 'survey') {
              this.surveyView(this.current()!)
            } else {
              this.randomView(this.current()!)
            }
            Blank().height(30)
          }.width('100%').padding({ top: 4 })
        }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }
}
