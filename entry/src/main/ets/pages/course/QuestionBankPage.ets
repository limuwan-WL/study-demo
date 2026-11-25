import router from '@ohos.router'
import { Action, Permission } from '../../model/PermissionModel'
import {
  BankQuestion, QuestionBankStore, QuestionType, questionTypeLabel
} from '../../model/QuestionBankModel'
import { Feedback } from '../../utils/Feedback'
import { Guard } from '../../utils/Guard'
import { EmptyState } from '../../components/StatusViews'

@CustomDialog
struct AddQuestionDialog {
  controller: CustomDialogController
  @State qType: QuestionType = 'single'
  @State subject: string = ''
  @State stem: string = ''
  @State answer: string = ''
  onSave: (type: QuestionType, subject: string, stem: string, answer: string) => string =
    (type: QuestionType, subject: string, stem: string, answer: string): string => ''

  @Builder
  typeChip(t: QuestionType) {
    Text(questionTypeLabel(t))
      .fontSize(12)
      .fontColor(this.qType === t ? Color.White : $r('app.color.text_sub'))
      .backgroundColor(this.qType === t ? $r('app.color.primary') : $r('app.color.field_bg'))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(12)
      .onClick(() => {
        this.qType = t
      })
  }

  build() {
    Column({ space: 12 }) {
      Text('新增题目').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      Row({ space: 8 }) {
        this.typeChip('single')
        this.typeChip('blank')
        this.typeChip('short')
      }.width('100%')
      TextInput({ text: this.subject, placeholder: '所属课程 / 学科，例如：计算机基础' })
        .height(42).fontSize(13).backgroundColor($r('app.color.field_bg')).borderRadius(10)
        .onChange((v: string) => {
          this.subject = v
        })
      TextArea({ text: this.stem, placeholder: '输入题干' })
        .height(70).fontSize(13).backgroundColor($r('app.color.field_bg')).borderRadius(10)
        .onChange((v: string) => {
          this.stem = v
        })
      TextArea({ text: this.answer, placeholder: '输入参考答案 / 解析' })
        .height(60).fontSize(13).backgroundColor($r('app.color.field_bg')).borderRadius(10)
        .onChange((v: string) => {
          this.answer = v
        })
      Row({ space: 10 }) {
        Text('取消').fontSize(14).fontColor($r('app.color.text_sub'))
          .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 10, bottom: 10 })
          .onClick(() => this.controller.close())
        Text('保存').fontSize(14).fontWeight(FontWeight.Medium).fontColor(Color.White)
          .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 10, bottom: 10 })
          .backgroundColor($r('app.color.primary')).borderRadius(20)
          .onClick(() => {
            let err = this.onSave(this.qType, this.subject.trim(), this.stem.trim(), this.answer.trim())
            if (err !== '') {
              Feedback.fail('新增题目', err)
              return
            }
            this.controller.close()
          })
      }.width('100%')
    }
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
  }
}

// ==================== 我的题库（教师） ====================
// 🌟 教师可增删题目；助教只读；学生无权限访问
@Entry
@Component
export struct QuestionBankPage {
  @StorageLink('questionBank') questions: BankQuestion[] = []
  @State filter: string = 'all'
  addController: CustomDialogController = new CustomDialogController({
    builder: AddQuestionDialog({}),
    customStyle: true
  })

  aboutToAppear(): void {
    // 🌟 页面级角色隔离：题库属于教师侧功能，学生与未授权助教不可进入
    if (!Permission.hasAction(Action.QUESTION_EDIT)) {
      Feedback.fail('进入题库管理', Permission.deniedReason(Action.QUESTION_EDIT))
      router.back()
      return
    }
    QuestionBankStore.ensureSeed()
    this.questions = QuestionBankStore.list().slice()
  }

  refresh(): void {
    this.questions = QuestionBankStore.list().slice()
  }

  filtered(): BankQuestion[] {
    if (this.filter === 'all') {
      return this.questions
    }
    return this.questions.filter((q: BankQuestion) => q.type === this.filter)
  }

  openAdd(): void {
    if (!Guard.action(Action.QUESTION_EDIT, '维护题库')) {
      return
    }
    this.addController = new CustomDialogController({
      builder: AddQuestionDialog({
        onSave: (type: QuestionType, subject: string, stem: string, answer: string): string => {
          if (subject === '') {
            return '请填写所属课程或学科'
          }
          if (stem === '') {
            return '题干不能为空'
          }
          if (answer === '') {
            return '请填写参考答案'
          }
          QuestionBankStore.add(new BankQuestion(type, subject, stem, answer))
          this.refresh()
          Feedback.success('题目已保存到我的题库')
          return ''
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.addController.open()
  }

  remove(q: BankQuestion): void {
    if (!Guard.action(Action.QUESTION_EDIT, '删除题目')) {
      return
    }
    Feedback.confirm('删除题目', '确定删除这道题吗？删除后不可恢复。', () => {
      if (QuestionBankStore.remove(q.id)) {
        this.refresh()
        Feedback.success('题目已删除')
      } else {
        Feedback.fail('删除题目', '未找到该题目')
      }
    }, '删除', true)
  }

  @Builder
  chip(key: string, label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.filter === key ? Color.White : $r('app.color.text_sub'))
      .backgroundColor(this.filter === key ? $r('app.color.primary') : $r('app.color.field_bg'))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(12)
      .onClick(() => {
        this.filter = key
      })
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(22)
          .fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Text('我的题库').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        if (Permission.hasAction(Action.QUESTION_EDIT)) {
          Text('+ 新增').fontSize(13).fontColor($r('app.color.primary'))
            .onClick(() => this.openAdd())
        }
      }
      .width('92%')
      .padding({ top: 16, bottom: 10 })

      if (!Permission.isTeacher() && !Permission.isAssistant()) {
        EmptyState({
          icon: $r('sys.symbol.lock'),
          title: '无权访问题库',
          desc: `${Permission.roleLabel()}身份无法查看课程题库，题库由授课教师维护`,
          actionLabel: '返回',
          onAction: () => router.back()
        })
      } else {
        if (Permission.isAssistant()) {
          Text('助教可查看题库，但不可新增或删除；如需调整请联系授课教师')
            .fontSize(11).fontColor('#B45309')
            .width('92%').padding(10)
            .backgroundColor('#FEF3C7').borderRadius(10)
            .margin({ bottom: 8 })
        }

        Row({ space: 8 }) {
          this.chip('all', '全部')
          this.chip('single', '单选题')
          this.chip('blank', '填空题')
          this.chip('short', '简答题')
        }
        .width('92%')
        .margin({ bottom: 8 })

        if (this.filtered().length === 0) {
          EmptyState({
            icon: $r('sys.symbol.inbox'),
            title: '题库还是空的',
            desc: '把课堂练习、随堂测的题目沉淀到题库，后续可直接组卷',
            actionLabel: Permission.hasAction(Action.QUESTION_EDIT) ? '新增第一道题' : '',
            onAction: () => this.openAdd()
          })
        } else {
          List({ space: 8 }) {
            ForEach(this.filtered(), (q: BankQuestion) => {
              ListItem() {
                Column({ space: 7 }) {
                  Row({ space: 6 }) {
                    Text(questionTypeLabel(q.type)).fontSize(9).fontColor(Color.White)
                      .backgroundColor('#8B5CF6')
                      .padding({ left: 5, right: 5, top: 1, bottom: 1 }).borderRadius(4)
                    Text(q.subject).fontSize(10).fontColor($r('app.color.primary'))
                    Blank()
                    if (Permission.hasAction(Action.QUESTION_EDIT)) {
                      Text('删除').fontSize(11).fontColor($r('app.color.danger'))
                        .onClick(() => this.remove(q))
                    }
                  }.width('100%')
                  Text(q.stem).fontSize(13).fontColor($r('app.color.text_main')).width('100%')
                  Text(`答案：${q.answer}`).fontSize(11).fontColor($r('app.color.text_sub'))
                    .width('100%')
                    .padding(8).backgroundColor($r('app.color.field_bg')).borderRadius(8)
                }
                .width('100%')
                .padding(14)
                .backgroundColor($r('app.color.card_bg'))
                .borderRadius(14)
              }
            }, (q: BankQuestion) => q.id)
          }
          .width('92%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .padding({ bottom: 20 })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
