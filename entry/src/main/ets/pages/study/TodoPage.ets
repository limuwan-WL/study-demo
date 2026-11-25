import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { TodoItem, formatDate, getTodayStr } from '../../model/DataModel';
import { CourseItem } from '../../model/TimetableModel';
import { TaskItem, SigninEntry, effectiveStatus, fmtDateTime, remainText } from '../../model/InteractionModel';

const PRIORITY_COLOR: Record<string, string> = { '高': '#EF4444', '中': '#E8A33E', '低': '#55C873' };

// 🌟 自动汇总条目：课程 / 签到 / 练习，直接来自本地数据，不额外写入待办表
// 🌟 路由参数必须显式声明类型（ArkTS 不允许 Record 对象字面量）
class AutoTodoParams {
  taskId: string = ''

  constructor(taskId: string) {
    this.taskId = taskId
  }
}

class AutoTodo {
  id: string = ''
  icon: string = ''
  title: string = ''
  desc: string = ''
  route: string = ''
  params: AutoTodoParams = new AutoTodoParams('')

  constructor(id: string, icon: string, title: string, desc: string, route: string) {
    this.id = id
    this.icon = icon
    this.title = title
    this.desc = desc
    this.route = route
  }
}

@CustomDialog
struct TodoDialog {
  controller: CustomDialogController
  @State inputText: string = ''
  @State dueDate: string = ''
  @State priority: string = '中'
  @State category: string = ''
  isAdd: boolean = true
  onClose: () => void = () => {}
  onConfirm: (content: string, dueDate: string, priority: string, category: string) => void = () => {}

  aboutToDisappear(): void {
    this.onClose()
  }

  pickDate() {
    DatePickerDialog.show({
      start: new Date(2000, 0, 1),
      end: new Date(2100, 0, 1),
      selected: this.dueDate === '' ? new Date() : new Date(this.dueDate),
      onDateAccept: (value: Date) => {
        this.dueDate = formatDate(value)
      }
    })
  }

  build() {
    Column({ space: 14 }) {
      Text(this.isAdd ? '添加待办' : '修改待办').fontSize(18).fontWeight(FontWeight.Bold)

      TextInput({ text: this.inputText, placeholder: '请输入待办内容' })
        .onChange((v: string) => this.inputText = v).backgroundColor($r('app.color.field_bg'))

      Row() {
        Text('截止时间').fontSize(14).fontColor($r('app.color.text_label')).width(70)
        Text(this.dueDate === '' ? '点击选择' : this.dueDate)
          .fontSize(14)
          .fontColor(this.dueDate === '' ? $r('app.color.text_hint') : '#3F7EF6')
          .onClick(() => this.pickDate())
        if (this.dueDate !== '') {
          Text('清除').fontSize(13).fontColor('#EF4444').margin({ left: 12 }).onClick(() => this.dueDate = '')
        }
      }.width('100%')

      Row() {
        Text('优先级').fontSize(14).fontColor($r('app.color.text_label')).width(70)
        Row({ space: 8 }) {
          ForEach(['高', '中', '低'], (p: string) => {
            Text(p)
              .fontSize(13)
              .fontColor(this.priority === p ? Color.White : $r('app.color.text_label'))
              .backgroundColor(this.priority === p ? PRIORITY_COLOR[p] : $r('app.color.field_bg'))
              .padding({ left: 14, right: 14, top: 5, bottom: 5 })
              .borderRadius(14)
              .onClick(() => this.priority = p)
          }, (p: string) => p)
        }
      }.width('100%')

      Row() {
        Text('分类标签').fontSize(14).fontColor($r('app.color.text_label')).width(70)
        TextInput({ text: this.category, placeholder: '如：学习 / 生活' })
          .onChange((v: string) => this.category = v)
          .backgroundColor($r('app.color.field_bg')).layoutWeight(1).height(40)
      }.width('100%')

      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).backgroundColor($r('app.color.btn_cancel')).onClick(() => this.controller.close())
        Button('确定').layoutWeight(1).onClick(() => {
          if (this.inputText.trim() === '') {
            promptAction.showToast({ message: '内容不能为空' })
            return
          }
          this.onConfirm(this.inputText.trim(), this.dueDate, this.priority, this.category.trim())
          this.controller.close()
        })
      }.width('100%').margin({ top: 6 })
    }
    .padding(20).backgroundColor($r('app.color.card_bg')).borderRadius(16)
  }
}

@Entry
@Component
struct TodoPage {
  @StorageLink('todoList') todoList: TodoItem[] = []
  // 🌟 自动汇总数据源：课程表 / 互动任务 / 当前身份
  @StorageLink('courseTable') courseTable: CourseItem[] = []
  @StorageLink('interactionTasks') tasks: TaskItem[] = []
  @StorageLink('userRole') userRole: string = 'student'
  @StorageLink('nickname') nickname: string = '张同学'
  @State filterType: string = '全部'
  @State dialogVisible: boolean = false
  dialogController: CustomDialogController = new CustomDialogController({
    builder: TodoDialog({}),
    customStyle: true
  })

  // 🌟 同一时刻只允许一个弹窗：连续点击新增按钮不会叠出多个弹窗
  openDialog(isAdd: boolean, item?: TodoItem) {
    if (this.dialogVisible) {
      return
    }
    // 🌟 已完成的待办不允许修改，弹出提示
    if (item && item.isDone) {
      promptAction.showToast({ message: '已完成，无法修改' })
      return
    }
    this.dialogVisible = true
    this.dialogController = new CustomDialogController({
      builder: TodoDialog({
        isAdd: isAdd,
        inputText: item ? item.content : '',
        dueDate: item ? item.dueDate : '',
        priority: item ? item.priority : '中',
        category: item ? item.category : '',
        onClose: () => {
          this.dialogVisible = false
        },
        onConfirm: (c: string, d: string, p: string, cat: string) => {
          this.handleConfirm(c, d, p, cat, item ? item.id : '')
        }
      }),
      autoCancel: true, // 点击遮罩层可关闭
      customStyle: true
    })
    this.dialogController.open()
  }

  handleConfirm(content: string, dueDate: string, priority: string, category: string, editId: string) {
    if (editId === '') {
      let item = new TodoItem(content, dueDate, priority, category)
      this.todoList = [item, ...this.todoList]
      promptAction.showToast({ message: '新增成功' })
    } else {
      this.todoList = this.todoList.map((t: TodoItem) => {
        if (t.id === editId) {
          t.content = content
          t.dueDate = dueDate
          t.priority = priority
          t.category = category
        }
        return t
      })
      promptAction.showToast({ message: '修改成功' })
    }
  }

  // 🌟 以勾选控件的当前值写入（不要取反），并重建对象，保证 @StorageLink 能感知变化
  setDone(id: string, done: boolean) {
    let list: TodoItem[] = []
    this.todoList.forEach((t: TodoItem) => {
      if (t.id === id) {
        let n = new TodoItem(t.content, t.dueDate, t.priority, t.category)
        n.id = t.id
        n.isDone = done
        list.push(n)
      } else {
        list.push(t)
      }
    })
    this.todoList = list
  }

  handleDelete(id: string) {
    this.todoList = this.todoList.filter((t: TodoItem) => t.id !== id)
    promptAction.showToast({ message: '删除成功' })
  }

  // 🌟 未完成在上，已完成沉底；组内按重要程度 高 > 中 > 低 排序
  getVisibleList(): TodoItem[] {
    const priorityOrder: Record<string, number> = { '高': 0, '中': 1, '低': 2 }
    const byPriority = (a: TodoItem, b: TodoItem) => priorityOrder[a.priority] - priorityOrder[b.priority]
    let unDone = this.todoList.filter((t: TodoItem) => !t.isDone).sort(byPriority)
    let done = this.todoList.filter((t: TodoItem) => t.isDone).sort(byPriority)
    if (this.filterType === '未完成') {
      return unDone
    }
    if (this.filterType === '已完成') {
      return done
    }
    return [...unDone, ...done]
  }

  isOverdue(item: TodoItem): boolean {
    return item.dueDate !== '' && !item.isDone && item.dueDate < getTodayStr()
  }

  // ==================== 自动汇总 ====================
  todayWeekday(): number {
    let d = new Date().getDay()
    return d === 0 ? 7 : d
  }

  isStaff(): boolean {
    return this.userRole === 'teacher' || this.userRole === 'assistant' || this.userRole === 'admin'
  }

  mySigninDone(t: TaskItem): boolean {
    return t.signinEntries.some((e: SigninEntry) =>
      e.student === this.nickname && (e.status === 'signed' || e.status === 'makeup'))
  }

  autoTodos(): AutoTodo[] {
    let now = Date.now()
    let list: AutoTodo[] = []
    // 今日课程（学生/助教）
    if (!this.isStaff()) {
      this.courseTable.filter((c: CourseItem) => c.dayOfWeek === this.todayWeekday())
        .sort((a: CourseItem, b: CourseItem) => a.startTime < b.startTime ? -1 : 1)
        .forEach((c: CourseItem) => {
          let item = new AutoTodo(`course_${c.id}`, '📚', `今日课程：${c.name}`,
            `${c.startTime}-${c.endTime} · ${c.location === '' ? '地点待定' : c.location}`,
            'pages/study/CourseTablePage')
          list.push(item)
        })
      // 进行中的签到（未签到）
      this.tasks.filter((t: TaskItem) => t.type === 'signin' && effectiveStatus(t, now) === 'ongoing')
        .forEach((t: TaskItem) => {
          if (this.mySigninDone(t)) {
            return
          }
          let item = new AutoTodo(`signin_${t.id}`, '✅', `待签到：${t.title}`,
            `截止 ${fmtDateTime(t.endAt)}`, 'pages/study/SigninPage')
          item.params = new AutoTodoParams(t.id)
          list.push(item)
        })
    }
    // 进行中的随堂练习（所有身份）
    this.tasks.filter((t: TaskItem) => t.type === 'practice' && effectiveStatus(t, now) === 'ongoing')
      .forEach((t: TaskItem) => {
        let item = new AutoTodo(`practice_${t.id}`, '📝', `待完成练习：${t.title}`,
          `${t.questions.length} 题 · 剩余 ${remainText(t.endAt, now)}`, 'pages/study/PracticePage')
        item.params = new AutoTodoParams(t.id)
        list.push(item)
      })
    return list
  }

  @Builder
  autoCard() {
    Column({ space: 8 }) {
      Row() {
        Text('自动汇总').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Text(`${this.autoTodos().length} 项`).fontSize(11).fontColor($r('app.color.primary'))
      }.width('100%')
      if (this.autoTodos().length === 0) {
        Text('今日暂无课程、签到或练习安排').fontSize(12).fontColor($r('app.color.text_hint'))
          .width('100%').padding({ top: 4, bottom: 4 })
      } else {
        ForEach(this.autoTodos(), (a: AutoTodo) => {
          Row({ space: 10 }) {
            Text(a.icon).fontSize(16)
            Column({ space: 2 }) {
              Text(a.title).fontSize(13).fontColor($r('app.color.text_main')).maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(a.desc).fontSize(11).fontColor($r('app.color.text_hint')).maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('去处理').fontSize(11).fontColor($r('app.color.primary'))
          }
          .width('100%').padding(10).backgroundColor($r('app.color.field_bg')).borderRadius(8)
          .onClick(() => {
            router.pushUrl({ url: a.route, params: a.params })
          })
        }, (a: AutoTodo) => a.id)
      }
    }
    .width('90%').padding(12).margin({ bottom: 10 })
    .backgroundColor($r('app.color.card_bg')).borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  emptyTip(msg: string) {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.inbox')).fontSize(40).fontColor([$r('app.color.text_hint')])
      Text(msg).fontSize(14).fontColor($r('app.color.text_sub'))
    }.width('100%').padding({ top: 80 })
  }

  @Builder
  itemCard(item: TodoItem) {
    Row() {
      Checkbox().select(item.isDone).onChange((v: boolean) => this.setDone(item.id, v))
      Column({ space: 6 }) {
        Text(item.content)
          .fontSize(16)
          .fontColor(item.isDone ? $r('app.color.text_hint') : $r('app.color.text_main'))
          .decoration({ type: item.isDone ? TextDecorationType.LineThrough : TextDecorationType.None })
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 6 }) {
          Text(item.priority)
            .fontSize(11).fontColor(Color.White)
            .backgroundColor(item.isDone ? $r('app.color.btn_cancel') : PRIORITY_COLOR[item.priority])
            .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(10)
          if (item.category !== '') {
            Text(item.category)
              .fontSize(11).fontColor($r('app.color.text_sub')).backgroundColor($r('app.color.field_bg'))
              .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(10)
          }
          if (item.dueDate !== '') {
            Text(`截止 ${item.dueDate}`)
              .fontSize(11)
              .fontColor(this.isOverdue(item) ? '#EF4444' : $r('app.color.text_sub'))
          }
          if (this.isOverdue(item)) {
            Text('已逾期').fontSize(11).fontColor('#EF4444')
          }
        }.width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 10 })

      Button('修改').fontSize(12).height(30).backgroundColor($r('app.color.btn_gray')).margin({ right: 10 })
        .onClick(() => this.openDialog(false, item))
      Button('删除').fontSize(12).height(30).backgroundColor('#EF4444')
        .onClick(() => this.handleDelete(item.id))
    }
    .width('100%').padding(16).backgroundColor($r('app.color.card_bg')).borderRadius(8)
  }

  build() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([$r('app.color.text_main')]).onClick(() => router.back())
        Text('待办事项').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 16 })
        Blank()
        // 🌟 新增按钮缩小为加号，放在右上角
        Row() {
          SymbolGlyph($r('sys.symbol.plus')).fontSize(18).fontColor([Color.White])
        }
        .width(34).height(34).borderRadius(17).backgroundColor('#3F7EF6')
        .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
        .margin({ right: 16 })
        .onClick(() => this.openDialog(true))
      }.width('100%').height(60).padding({ left: 16 }).margin({ bottom: 10 })

      // 自动汇总：课程 / 签到 / 练习
      this.autoCard()

      // 状态筛选：全部 / 未完成 / 已完成
      Row({ space: 8 }) {
        ForEach(['全部', '未完成', '已完成'], (f: string) => {
          Text(f)
            .fontSize(14)
            .fontColor(this.filterType === f ? Color.White : $r('app.color.text_label'))
            .backgroundColor(this.filterType === f ? '#3F7EF6' : $r('app.color.card_bg'))
            .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            .borderRadius(16)
            .onClick(() => this.filterType = f)
        }, (f: string) => f)
        Blank()
        Text(`${this.todoList.filter((t: TodoItem) => !t.isDone).length} 项未完成`)
          .fontSize(12).fontColor($r('app.color.text_sub'))
      }
      .width('90%').margin({ bottom: 12 })

      List({ space: 10 }) {
        ForEach(this.getVisibleList(), (item: TodoItem) => {
          ListItem() {
            this.itemCard(item)
          }
        }, (item: TodoItem) => `${item.id}_${item.isDone}_${item.content}_${item.dueDate}_${item.priority}_${item.category}`)
        if (this.getVisibleList().length === 0) {
          ListItem() {
            this.emptyTip(this.todoList.length === 0 ? '还没有待办，点击右上角 + 新增吧' : '该筛选下暂无待办')
          }
        }
      }.width('90%').layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }
}
