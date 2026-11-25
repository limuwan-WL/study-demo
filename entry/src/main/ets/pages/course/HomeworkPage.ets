import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';
import {
  Homework, HomeworkSubmission, StudentProgress, mockStudentProgress, subsOf, mySub, subTypeName, fmtTime,
  SEED_HW_ID, ensureGradedHomework
} from '../../model/HomeworkModel';
import { Permission } from '../../model/PermissionModel';
import { NetworkState } from '../../utils/NetworkState';
import { OfflineDraft, OfflineDraftStore } from '../../utils/OfflineDraft';
import { OfflineBar, EmptyState } from '../../components/StatusViews';

// 🌟 布置作业弹窗（老师）
@CustomDialog
struct AssignDialog {
  controller: CustomDialogController
  onConfirm: (title: string, content: string) => void = () => {}
  @State title: string = ''
  @State content: string = ''

  build() {
    Column({ space: 14 }) {
      Text('布置作业').fontSize(18).fontWeight(FontWeight.Bold)
      TextInput({ text: this.title, placeholder: '作业标题，如：背诵第 3 课单词' })
        .height(44).fontSize(14).backgroundColor($r('app.color.field_bg')).borderRadius(12)
        .padding({ left: 12, right: 12 })
        .onChange((v: string) => {
          this.title = v
        })
      TextArea({ text: this.content, placeholder: '作业要求说明（可选）' })
        .height(90).fontSize(14).backgroundColor($r('app.color.field_bg')).borderRadius(12)
        .padding(12)
        .onChange((v: string) => {
          this.content = v
        })
      Row({ space: 12 }) {
        Text('取消').fontSize(15).fontColor($r('app.color.text_sub'))
          .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 10, bottom: 10 })
          .onClick(() => this.controller.close())
        Text('发布').fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
          .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 10, bottom: 10 })
          .backgroundColor($r('app.color.primary')).borderRadius(20)
          .onClick(() => {
            if (this.title.trim() === '') {
              promptAction.showToast({ message: '请填写作业标题' })
              return
            }
            this.onConfirm(this.title.trim(), this.content.trim())
            this.controller.close()
          })
      }.width('100%')
    }
    .padding(22).backgroundColor($r('app.color.card_bg')).borderRadius(20)
  }
}

// 🌟 提交作业弹窗（学生）：支持 文字 / 照片 / 视频 / 录音 四种格式
@CustomDialog
struct SubmitDialog {
  controller: CustomDialogController
  onConfirm: (type: string, text: string, attachment: string) => void = () => {}
  @State type: string = 'text'
  @State text: string = ''
  @State attachCount: number = 0
  @State recording: boolean = false

  attachLabel(): string {
    if (this.type === 'photo') {
      return '添加照片'
    }
    if (this.type === 'video') {
      return '添加视频'
    }
    return '添加录音'
  }

  build() {
    Column({ space: 14 }) {
      Text('提交作业').fontSize(18).fontWeight(FontWeight.Bold)

      // 提交格式选择
      Row({ space: 8 }) {
        ForEach(['text', 'photo', 'video', 'audio'], (t: string) => {
          Text(subTypeName(t))
            .fontSize(13)
            .fontColor(this.type === t ? Color.White : $r('app.color.text_sub'))
            .padding({ top: 7, bottom: 7 })
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.type === t ? $r('app.color.primary') : $r('app.color.field_bg'))
            .borderRadius(14)
            .onClick(() => {
              this.type = t
              this.attachCount = 0
              this.recording = false
            })
        }, (t: string) => `${t}_${this.type === t ? 1 : 0}`)
      }.width('100%')

      TextArea({ text: this.text, placeholder: this.type === 'text' ? '请输入作业内容…' : '补充说明（可选）…' })
        .height(90).fontSize(14).backgroundColor($r('app.color.field_bg')).borderRadius(12)
        .padding(12)
        .onChange((v: string) => {
          this.text = v
        })

      // 附件区（演示环境：记录附件类型与数量）
      if (this.type !== 'text') {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(16).fontColor([$r('app.color.primary')])
          Text(this.attachCount === 0 ? this.attachLabel() : `已添加 ${subTypeName(this.type)}×${this.attachCount}`)
            .fontSize(13).fontColor($r('app.color.primary'))
          if (this.recording) {
            Text('录音中…再点一次结束').fontSize(11).fontColor($r('app.color.text_hint'))
          }
        }
        .padding({ left: 12, right: 12, top: 9, bottom: 9 })
        .borderRadius(12)
        .border({ width: 1, color: $r('app.color.primary'), style: BorderStyle.Dashed })
        .onClick(() => {
          if (this.type === 'audio') {
            this.recording = !this.recording
            if (!this.recording) {
              this.attachCount = 1
              promptAction.showToast({ message: '录音已保存（15″）' })
            }
          } else {
            this.attachCount += 1
          }
        })
      }

      Row({ space: 12 }) {
        Text('取消').fontSize(15).fontColor($r('app.color.text_sub'))
          .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 10, bottom: 10 })
          .onClick(() => this.controller.close())
        Text('提交').fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
          .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 10, bottom: 10 })
          .backgroundColor($r('app.color.primary')).borderRadius(20)
          .onClick(() => {
            if (this.type === 'text' && this.text.trim() === '') {
              promptAction.showToast({ message: '请输入作业内容' })
              return
            }
            if (this.type !== 'text' && this.attachCount === 0) {
              promptAction.showToast({ message: `请添加${subTypeName(this.type)}附件` })
              return
            }
            let attachment = this.attachCount === 0 ? '' : `${subTypeName(this.type)}×${this.attachCount}`
            this.onConfirm(this.type, this.text.trim(), attachment)
            this.controller.close()
          })
      }.width('100%')
    }
    .padding(22).backgroundColor($r('app.color.card_bg')).borderRadius(20)
  }
}

// 🌟 批注详情弹窗：展示分数、教师批注与本次提交内容
@CustomDialog
struct GradeDialog {
  controller: CustomDialogController
  hwTitle: string = ''
  teacher: string = ''
  student: string = ''
  score: number = -1
  annotation: string = ''
  submitted: string = ''
  attachment: string = ''
  time: string = ''

  build() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        Text('作业批注')
          .fontSize(11).fontColor(Color.White)
          .backgroundColor('#E8A33E')
          .padding({ left: 8, right: 8, top: 3, bottom: 3 }).borderRadius(8)
        Blank()
        Text(this.time).fontSize(12).fontColor($r('app.color.text_hint'))
      }.width('100%')

      Text(this.hwTitle).fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        .width('100%')

      Row({ space: 10 }) {
        Column({ space: 2 }) {
          Text(`${this.score}`).fontSize(30).fontWeight(FontWeight.Bold).fontColor('#3F7EF6')
          Text('得分').fontSize(11).fontColor($r('app.color.text_hint'))
        }
        Divider().vertical(true).height(40).color($r('app.color.divider_color'))
        Column({ space: 3 }) {
          Text(`${this.teacher} 批阅`).fontSize(12).fontColor($r('app.color.text_sub'))
          Text(`提交人：${this.student}`).fontSize(12).fontColor($r('app.color.text_sub'))
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }
      .width('100%').padding(12)
      .backgroundColor($r('app.color.field_bg')).borderRadius(12)
      .alignItems(VerticalAlign.Center)

      Column({ space: 6 }) {
        Text('教师批注').fontSize(12).fontColor($r('app.color.text_hint'))
        Scroll() {
          Text(this.annotation)
            .fontSize(14).lineHeight(23).fontColor($r('app.color.text_main')).width('100%')
        }
        .constraintSize({ maxHeight: 150 }).scrollBar(BarState.Off).align(Alignment.TopStart)
      }.alignItems(HorizontalAlign.Start).width('100%')

      Column({ space: 6 }) {
        Text('我的提交').fontSize(12).fontColor($r('app.color.text_hint'))
        Text(this.submitted).fontSize(13).lineHeight(21).fontColor($r('app.color.text_sub')).width('100%')
        if (this.attachment !== '') {
          Text(`附件：${this.attachment}`).fontSize(11).fontColor($r('app.color.text_hint')).width('100%')
        }
      }.alignItems(HorizontalAlign.Start).width('100%')

      Button('知道了')
        .width('100%').height(42)
        .onClick(() => this.controller.close())
    }
    .width('86%')
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(20)
    .alignItems(HorizontalAlign.Start)
  }
}

// ==================== 作业页 ====================
// 老师：布置作业 / 查看每份作业的提交 / 查看每个学生的学习进度
// 学生：查看作业并提交（文字 / 照片 / 视频 / 录音）
@Entry
@Component
struct HomeworkPage {
  @StorageLink('hwList') hwList: Homework[] = []
  @StorageLink('hwSubs') hwSubs: HomeworkSubmission[] = []
  @StorageLink('nickname') nickname: string = '张同学'
  @StorageLink('userRole') userRole: string = 'student'
  @StorageLink('courseProgress') courseProgress: Record<string, number> = {}
  @StorageLink('wordKnown') wordKnown: string[] = []
  // 🌟 学习日志按学科/语言分账，本页只统计「计算机基础」课程的数据
  @StorageLink('studyLogBySubject') studyLogBySubject: Record<string, Record<string, number>> = {}
  // 🌟 监听网络状态：恢复联网后自动同步离线保存的作业草稿
  @StorageLink('networkOnline') @Watch('onNetworkChange') networkOnline: boolean = true
  @State tab: number = 0 // 老师端：0 作业列表 1 学生进度
  @State expandedId: string = ''

  assignDialog: CustomDialogController = new CustomDialogController({
    builder: AssignDialog({
      onConfirm: (title: string, content: string) => this.doAssign(title, content)
    }),
    customStyle: true
  })

  submitDialog: CustomDialogController = new CustomDialogController({
    builder: SubmitDialog({
      onConfirm: (type: string, text: string, attachment: string) => this.doSubmit(type, text, attachment)
    }),
    customStyle: true
  })

  @State pendingHwId: string = ''

  gradeDialog: CustomDialogController = new CustomDialogController({
    builder: GradeDialog({}),
    customStyle: true
  })

  aboutToAppear(): void {
    // 🌟 内置一份已批阅作业，保证消息「点击查看批注」有数据可看
    //    学生看到自己的作答，教师 / 助教看到示例学生「李同学」的提交
    ensureGradedHomework(this.isStaff() ? '李同学' : this.nickname)
    let params = router.getParams() as Record<string, string>
    if (params && params['tab'] === 'progress') {
      this.tab = 1
    }
    // 🌟 老师查看学生进度 → 解锁「洞察学情」成就
    if (this.isStaff() && this.tab === 1) {
      AppStorage.setOrCreate('t_viewedProgress', true)
    }
    // 🌟 从消息「查看批注」进入：直接弹出对应作业的批注详情
    let hwId = params ? (params['hwId'] ?? params['taskId'] ?? '') : ''
    if (hwId !== '' && !this.isStaff()) {
      setTimeout(() => {
        this.openAnnotation(hwId)
      }, 150)
    }
    // 🌟 网络恢复后自动同步离线保存的作业草稿（冲突时弹窗让用户选择）
    this.syncOfflineDrafts()
  }

  // 🌟 打开批注详情：学生看自己的提交，教师 / 助教可看任意提交
  openAnnotation(hwId: string): void {
    // 直接从 AppStorage 取最新数据，避免弹窗早于 @StorageLink 刷新时取不到批注
    let subs = AppStorage.get<HomeworkSubmission[]>('hwSubs')
    if (subs === undefined) {
      subs = this.hwSubs
    }
    let sub = mySub(hwId, this.nickname, subs)
    if (sub === undefined) {
      promptAction.showToast({ message: '暂无可查看的批注' })
      return
    }
    let hws = AppStorage.get<Homework[]>('hwList')
    if (hws === undefined) {
      hws = this.hwList
    }
    let hw = hws.find((h: Homework) => h.id === hwId)
    this.gradeDialog = new CustomDialogController({
      builder: GradeDialog({
        hwTitle: hw !== undefined ? hw.title : '作业批注',
        teacher: hw !== undefined ? hw.teacher : '任课教师',
        student: sub.student,
        score: sub.score,
        annotation: sub.annotation,
        submitted: sub.text,
        attachment: sub.attachment,
        time: fmtTime(sub.time)
      }),
      autoCancel: true,
      customStyle: true
    })
    this.gradeDialog.open()
  }

  // 🌟 当前学生的批阅结果（未批阅返回 undefined）
  gradedSub(hwId: string): HomeworkSubmission | undefined {
    let sub = mySub(hwId, this.nickname, this.hwSubs)
    if (sub !== undefined && sub.score >= 0) {
      return sub
    }
    return undefined
  }

  gradedText(hwId: string): string {
    let sub = this.gradedSub(hwId)
    return sub !== undefined ? `已批阅 ${sub.score} 分` : ''
  }

  // 🌟 网络恢复自动同步：弱网期间保存的草稿在联网瞬间自动提交
  onNetworkChange(): void {
    if (this.networkOnline) {
      this.syncOfflineDrafts()
    }
  }

  syncOfflineDrafts(): void {
    if (!NetworkState.online()) {
      return
    }
    let drafts = OfflineDraftStore.list().filter((d: OfflineDraft) => d.key.indexOf('hw_') === 0)
    if (drafts.length === 0) {
      return
    }
    drafts.forEach((d: OfflineDraft) => {
      let exists = this.hwSubs.find((s: HomeworkSubmission) =>
      s.homeworkId === d.key && s.student === this.nickname)
      if (exists !== undefined && exists.time > d.savedAt) {
        AlertDialog.show({
          title: '版本冲突',
          message: '网络恢复后发现该作业已有更新的提交，请选择保留哪一版。',
          autoCancel: false,
          alignment: DialogAlignment.Center,
          primaryButton: {
            value: '保留现有提交',
            action: () => OfflineDraftStore.remove(d.key)
          },
          secondaryButton: {
            value: '使用本地草稿',
            fontColor: '#3F7EF6',
            action: () => this.applyDraft(d)
          }
        })
      } else {
        this.applyDraft(d)
      }
    })
  }

  applyDraft(d: OfflineDraft): void {
    try {
      let obj = JSON.parse(d.payload) as Record<string, string>
      this.pendingHwId = d.key
      this.doSubmit(obj['type'], obj['text'], obj['attachment'], true)
    } catch (e) {
      OfflineDraftStore.remove(d.key)
    }
  }

  doAssign(title: string, content: string): void {
    let h = new Homework()
    h.id = `hw_${Date.now()}`
    h.title = title
    h.content = content
    h.teacher = this.nickname
    h.time = Date.now()
    this.hwList = [h].concat(this.hwList)
    promptAction.showToast({ message: '作业已发布' })
  }

  doSubmit(type: string, text: string, attachment: string, fromSync: boolean = false): void {
    // 🌟 弱网离线：表单暂存本机，网络恢复后自动同步
    if (!fromSync && !NetworkState.online()) {
      OfflineDraftStore.save(this.pendingHwId,
        JSON.stringify({ type: type, text: text, attachment: attachment }), this.hwSubs.length)
      promptAction.showToast({ message: '当前为弱网离线，作业已保存到本机，联网后自动同步' })
      return
    }
    // 同一作业重复提交 → 覆盖旧提交
    let rest = this.hwSubs.filter((s: HomeworkSubmission) =>
      !(s.homeworkId === this.pendingHwId && s.student === this.nickname))
    let sub = new HomeworkSubmission()
    sub.id = `sub_${Date.now()}`
    sub.homeworkId = this.pendingHwId
    sub.student = this.nickname
    sub.type = type
    sub.text = text
    sub.attachment = attachment
    sub.time = Date.now()
    this.hwSubs = rest.concat([sub])
    // 提交成功后清理对应离线草稿
    OfflineDraftStore.remove(this.pendingHwId)
    if (fromSync) {
      promptAction.showToast({ message: '网络已恢复，离线作业已自动同步' })
    } else {
      promptAction.showToast({ message: '作业已提交' })
    }
  }

  myLessons(): number {
    let prefix = `${this.courseScope()}_`
    let total = 0
    Object.keys(this.courseProgress).forEach((k: string) => {
      if (k.startsWith(prefix)) {
        total += this.courseProgress[k]
      }
    })
    return total
  }

  myMinutes(): number {
    let log = this.studyLogBySubject[this.courseScope()]
    if (log === undefined) {
      return 0
    }
    let total = 0
    Object.keys(log).forEach((k: string) => {
      total += log[k]
    })
    return total
  }

  // 🌟 本页所属课程：课程页的班级互动固定为「计算机基础」
  courseScope(): string {
    return 'csbasic'
  }

  // 🌟 教师与助教共用批阅视图；布置作业仅主讲教师
  isStaff(): boolean {
    return Permission.isTeacher() || Permission.isAssistant()
  }

  // 学生进度列表：🌟 教师 / 助教只能看到自己授课（或被分配）课程内的学生数据
  roster(): StudentProgress[] {
    if (this.isStaff()) {
      return Permission.visibleRoster('csbasic')
    }
    let me = new StudentProgress(this.nickname, this.myLessons(),
      this.wordKnown.filter((k: string) => k.startsWith(`${this.courseScope()}_`)).length, this.myMinutes(), 0)
    return [me].concat(mockStudentProgress())
  }

  @Builder
  tabBtn(idx: number, label: string) {
    Text(label)
      .fontSize(13).fontWeight(this.tab === idx ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.tab === idx ? Color.White : $r('app.color.text_sub'))
      .padding({ top: 7, bottom: 7 }).layoutWeight(1).textAlign(TextAlign.Center)
      .backgroundColor(this.tab === idx ? $r('app.color.primary') : $r('app.color.card_bg'))
      .borderRadius(14)
      .onClick(() => {
        this.tab = idx
        if (idx === 1) {
          AppStorage.setOrCreate('t_viewedProgress', true)
        }
      })
  }

  @Builder
  hwCard(h: Homework) {
    Column() {
      Row({ space: 8 }) {
        Column({ space: 4 }) {
          Text(h.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
          if (h.content !== '') {
            Text(h.content).fontSize(12).fontColor($r('app.color.text_sub'))
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          Text(`${h.teacher} · ${fmtTime(h.time)}`).fontSize(10).fontColor($r('app.color.text_hint'))
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)

        if (this.isStaff()) {
          Text(`${subsOf(h.id, this.hwSubs).length} 份提交`)
            .fontSize(11).fontColor($r('app.color.text_sub'))
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(14)
            .rotate({ angle: this.expandedId === h.id ? 90 : 0 })
            .fontColor([$r('app.color.text_hint')])
        } else {
          if (this.gradedSub(h.id) !== undefined) {
            Text(this.gradedText(h.id))
              .fontSize(11).fontColor('#E8A33E')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor('#FEF3E2').borderRadius(10)
          } else if (mySub(h.id, this.nickname, this.hwSubs) !== undefined) {
            Text('已提交').fontSize(11).fontColor('#55C873')
          } else {
            Text('提交作业')
              .fontSize(11).fontColor(Color.White)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor($r('app.color.primary')).borderRadius(12)
          }
        }
      }.width('100%').alignItems(VerticalAlign.Center)
      .onClick(() => {
        if (this.isStaff()) {
          this.expandedId = this.expandedId === h.id ? '' : h.id
        } else if (this.gradedSub(h.id) !== undefined) {
          this.openAnnotation(h.id)
        } else {
          this.pendingHwId = h.id
          this.submitDialog = new CustomDialogController({
            builder: SubmitDialog({
              onConfirm: (type: string, text: string, attachment: string) => this.doSubmit(type, text, attachment)
            }),
            customStyle: true
          })
          this.submitDialog.open()
        }
      })

      // 🌟 学生：已批阅时提供批注入口，正文和分数一目了然
      if (!this.isStaff() && this.gradedSub(h.id) !== undefined) {
        Row({ space: 4 }) {
          Text('查看老师批注').fontSize(12).fontColor($r('app.color.primary'))
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([$r('app.color.primary')])
          Blank()
          Text('点击查看').fontSize(10).fontColor($r('app.color.text_hint'))
        }
        .width('100%')
        .margin({ top: 8 })
        .padding({ top: 8 })
        .border({ width: { top: 1 }, color: $r('app.color.divider_color') })
        .onClick(() => this.openAnnotation(h.id))
      }

      // 老师展开：查看每份提交
      if (this.isStaff() && this.expandedId === h.id) {
        Column({ space: 8 }) {
          ForEach(subsOf(h.id, this.hwSubs), (s: HomeworkSubmission) => {
            Row({ space: 8 }) {
              Text(subTypeName(s.type))
                .fontSize(10).fontColor(Color.White)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor('#8B5CF6').borderRadius(6)
              Column({ space: 2 }) {
                Text(s.student).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                if (s.text !== '') {
                  Text(s.text).fontSize(11).fontColor($r('app.color.text_sub'))
                    .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                if (s.attachment !== '') {
                  Text(`附件：${s.attachment}`).fontSize(10).fontColor($r('app.color.text_hint'))
                }
                // 🌟 教师 / 助教展开时可直接看到批阅分数与批注
                if (s.score >= 0) {
                  Text(`已批阅 ${s.score} 分`).fontSize(10).fontColor('#E8A33E')
                  if (s.annotation !== '') {
                    Text(`批注：${s.annotation}`).fontSize(10).fontColor($r('app.color.text_sub'))
                      .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                }
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text(fmtTime(s.time)).fontSize(9).fontColor($r('app.color.text_hint'))
            }.width('100%')
          }, (s: HomeworkSubmission) => s.id)
          if (subsOf(h.id, this.hwSubs).length === 0) {
            Text('还没有学生提交').fontSize(11).fontColor($r('app.color.text_hint'))
              .width('100%').textAlign(TextAlign.Center)
          }
        }
        .width('100%').padding(10)
        .backgroundColor($r('app.color.field_bg')).borderRadius(10)
        .margin({ top: 10 })
      }
    }
    .width('100%').padding(14)
    .backgroundColor($r('app.color.card_bg')).borderRadius(14)
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.03)', offsetY: 3 })
  }

  @Builder
  studentRow(s: StudentProgress) {
    Row({ space: 10 }) {
      Text(s.name.substring(0, 1))
        .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .width(36).height(36).borderRadius(18).textAlign(TextAlign.Center)
        .backgroundColor('#4C8BF5')
      Column({ space: 3 }) {
        Text(s.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
        Text(`课时 ${s.lessons} · 单词 ${s.words} · 学习 ${s.minutes} 分`)
          .fontSize(11).fontColor($r('app.color.text_sub'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }
    .width('100%').padding(12)
    .backgroundColor($r('app.color.card_bg')).borderRadius(14)
  }

  build() {
    Column() {
      // 顶部栏
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20).fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Text(this.isStaff() ? '作业管理' : '我的作业')
          .fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          .layoutWeight(1)
        if (Permission.isTeacher()) {
          Text('+ 布置作业')
            .fontSize(12).fontWeight(FontWeight.Medium).fontColor(Color.White)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor($r('app.color.primary')).borderRadius(13)
            .onClick(() => this.assignDialog.open())
        }
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.card_bg'))

      // 🌟 学生提交作业属于表单编辑区：弱网时提示离线保存
      if (!this.isStaff()) {
        Row() {
          OfflineBar({ text: '弱网离线：提交的作业会先保存在本机，联网后自动同步；如遇冲突会弹窗确认' })
        }
        .width('90%')
        .margin({ top: 10 })
      }

      // 老师端 Tab：作业列表 / 学生进度
      if (this.isStaff()) {
        Row({ space: 8 }) {
          this.tabBtn(0, '作业列表')
          this.tabBtn(1, '学生进度')
        }
        .width('90%').margin({ top: 12 })
      }

      Scroll() {
        Column({ space: 12 }) {
          if (this.isStaff() && this.tab === 1) {
            // ===== 学生进度 =====
            if (this.roster().length === 0) {
              EmptyState({
                icon: $r('sys.symbol.lock'),
                title: '暂无可查看的学生数据',
                desc: '教师仅能查看自己授课课程内的学生数据，助教需由主讲教师分配课程后才能查看'
              })
            } else {
              ForEach(this.roster(), (s: StudentProgress) => {
                this.studentRow(s)
              }, (s: StudentProgress) => s.name)
            }
          } else {
            // ===== 作业列表 =====
            ForEach(this.hwList, (h: Homework) => {
              this.hwCard(h)
            }, (h: Homework) => `${h.id}_${subsOf(h.id, this.hwSubs).length}`)
            if (this.hwList.length === 0) {
              Text(this.isStaff() ? '还没有布置作业，点右上角「+ 布置作业」' : '老师还没有布置作业')
                .fontSize(13).fontColor($r('app.color.text_hint'))
                .width('100%').textAlign(TextAlign.Center).margin({ top: 40 })
            }
          }
        }
        .width('90%').padding({ top: 12, bottom: 40 })
      }
      .layoutWeight(1).align(Alignment.Top).scrollBar(BarState.Off)
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
