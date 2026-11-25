import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { ScheduleItem, formatDate, formatTime, parseDateTime, sortSchedule, getTodayStr } from '../../model/DataModel';

@CustomDialog
struct ScheduleDialog {
  controller: CustomDialogController
  @State inputText: string = ''
  @State selectedDate: Date = new Date()
  @State selectedTime: Date = new Date()
  isAdd: boolean = true
  originalDate: string = '' // 编辑时的原日期，用于跳过“过去时间”校验
  originalTime: string = ''
  onClose: () => void = () => {}
  onConfirm: (content: string, date: string, time: string) => void = () => {}

  aboutToDisappear(): void {
    this.onClose()
  }

  build() {
    Column({ space: 12 }) {
      Text(this.isAdd ? '添加日程' : '修改日程').fontSize(18).fontWeight(FontWeight.Bold)
      TextInput({ text: this.inputText, placeholder: '日程内容' })
        .onChange((v: string) => this.inputText = v).backgroundColor($r('app.color.field_bg'))
      Row() {
        Text('日期：').fontSize(14).width(40)
        DatePicker({ selected: this.selectedDate })
          .onDateChange((v: Date) => {
            let d = new Date(); d.setFullYear(v.getFullYear(), v.getMonth(), v.getDate()); this.selectedDate = d
          }).layoutWeight(1).height(100).backgroundColor($r('app.color.field_bg')).borderRadius(8)
      }.width('100%')
      Row() {
        Text('时间：').fontSize(14).width(40)
        TimePicker({ selected: this.selectedTime }).useMilitaryTime(true)
          .onChange((v: TimePickerResult) => {
            let d = new Date(); d.setHours(v.hour, v.minute); this.selectedTime = d
          }).layoutWeight(1).height(100).backgroundColor($r('app.color.field_bg')).borderRadius(8)
      }.width('100%')
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).backgroundColor($r('app.color.btn_cancel')).onClick(() => this.controller.close())
        Button('确定').layoutWeight(1).onClick(() => {
          if (this.inputText.trim() === '') {
            promptAction.showToast({ message: '内容不能为空' })
            return
          }
          let dateStr = formatDate(this.selectedDate)
          let timeStr = formatTime(this.selectedTime)
          let sel = parseDateTime(dateStr, timeStr)
          let isOriginal = dateStr === this.originalDate && timeStr === this.originalTime
          // 🌟 校验：不能选择已经过去的时间（编辑时保持原时间除外）
          if (!isOriginal && sel.getTime() < Date.now()) {
            promptAction.showToast({ message: '不能选择已经过去的时间' })
            return
          }
          this.onConfirm(this.inputText.trim(), dateStr, timeStr)
          this.controller.close()
        })
      }.width('100%').margin({ top: 10 })
    }.padding(20).backgroundColor($r('app.color.card_bg')).borderRadius(16)
  }
}

@Entry
@Component
struct SchedulePage {
  @StorageLink('scheduleList') scheduleList: ScheduleItem[] = []
  @State dialogVisible: boolean = false
  @State weekView: boolean = false
  dialogController: CustomDialogController = new CustomDialogController({
    builder: ScheduleDialog({}),
    customStyle: true
  })

  openDialog(isAdd: boolean, item?: ScheduleItem) {
    if (this.dialogVisible) {
      return
    }
    this.dialogVisible = true
    let dObj = item ? parseDateTime(item.date, item.time) : new Date()
    this.dialogController = new CustomDialogController({
      builder: ScheduleDialog({
        isAdd: isAdd,
        inputText: item ? item.content : '',
        selectedDate: dObj,
        selectedTime: dObj,
        originalDate: item ? item.date : '',
        originalTime: item ? item.time : '',
        onClose: () => {
          this.dialogVisible = false
        },
        onConfirm: (c: string, d: string, t: string) => {
          this.handleConfirm(c, d, t, item ? item.id : '')
        }
      }),
      autoCancel: true, // 点击遮罩层可关闭
      customStyle: true
    })
    this.dialogController.open()
  }

  handleConfirm(content: string, date: string, time: string, editId: string) {
    if (editId === '') {
      let item = new ScheduleItem(content, date, time)
      this.scheduleList = [item, ...this.scheduleList]
      promptAction.showToast({ message: '新增成功' })
    } else {
      this.scheduleList = this.scheduleList.map((s: ScheduleItem) => {
        if (s.id === editId) {
          s.content = content
          s.date = date
          s.time = time
        }
        return s
      })
      promptAction.showToast({ message: '修改成功' })
    }
  }

  handleDelete(id: string) {
    this.scheduleList = this.scheduleList.filter((s: ScheduleItem) => s.id !== id)
    promptAction.showToast({ message: '删除成功' })
  }

  // 🌟 三个分组：今日（未过期）、后续、已过期，组内按时间由近到远排序
  getTodayList(): ScheduleItem[] {
    let today = getTodayStr()
    let now = Date.now()
    return sortSchedule(this.scheduleList.filter((s: ScheduleItem) => {
      return s.date === today && parseDateTime(s.date, s.time).getTime() >= now
    }))
  }

  getUpcomingList(): ScheduleItem[] {
    let today = getTodayStr()
    return sortSchedule(this.scheduleList.filter((s: ScheduleItem) => s.date > today))
  }

  getExpiredList(): ScheduleItem[] {
    let now = Date.now()
    return sortSchedule(this.scheduleList.filter((s: ScheduleItem) => {
      return parseDateTime(s.date, s.time).getTime() < now
    }))
  }

  // 本周7天日期（周一~周日）
  weekDates(): string[] {
    let days: string[] = []
    let now = new Date()
    let day = now.getDay() // 0=周日
    let monday = new Date(now)
    monday.setDate(now.getDate() - (day === 0 ? 6 : day - 1))
    for (let i = 0; i < 7; i++) {
      let d = new Date(monday)
      d.setDate(monday.getDate() + i)
      days.push(formatDate(d))
    }
    return days
  }

  weekDayName(idx: number): string {
    return ['一', '二', '三', '四', '五', '六', '日'][idx]
  }

  itemsOnDate(date: string): ScheduleItem[] {
    return sortSchedule(this.scheduleList.filter((s: ScheduleItem) => s.date === date))
  }

  @Builder
  sectionHeader(title: string, count: number) {
    Text(`${title} (${count})`)
      .fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_sub'))
      .width('100%').margin({ top: 4 })
  }

  @Builder
  emptyTip(msg: string) {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.inbox')).fontSize(40).fontColor([$r('app.color.text_hint')])
      Text(msg).fontSize(14).fontColor($r('app.color.text_sub'))
    }.width('100%').padding({ top: 80 })
  }

  @Builder
  itemCard(item: ScheduleItem, expired: boolean) {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Column() {
          Text(item.date.slice(5)).fontSize(12).fontColor(Color.White)
          Text(item.time).fontSize(14).fontColor(Color.White).fontWeight(FontWeight.Bold)
        }
        .backgroundColor(expired ? $r('app.color.btn_cancel') : '#3F7EF6')
        .padding(8).borderRadius(8)

        Column({ space: 4 }) {
          Text(item.content)
            .fontSize(16)
            .fontColor(expired ? $r('app.color.text_hint') : $r('app.color.text_main'))
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (expired) {
            Text('已过期').fontSize(11).fontColor($r('app.color.text_hint'))
          }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      // 操作按钮单独一行，避免挤压正文导致内容显示不全
      Row({ space: 10 }) {
        Blank()
        Text('修改')
          .fontSize(12).fontColor(Color.White)
          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
          .backgroundColor($r('app.color.btn_gray')).borderRadius(12)
          .onClick(() => this.openDialog(false, item))
        Text('删除')
          .fontSize(12).fontColor(Color.White)
          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
          .backgroundColor('#EF4444').borderRadius(12)
          .onClick(() => this.handleDelete(item.id))
      }.width('100%')
    }
    .width('100%').padding(16).backgroundColor($r('app.color.card_bg')).borderRadius(8)
    .opacity(expired ? 0.75 : 1)
  }

  build() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([$r('app.color.text_main')]).onClick(() => router.back())
        Text('日程安排').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 16 })
        Blank()
        // 本周/列表视图切换
        Text(this.weekView ? '列表' : '本周')
          .fontSize(14).fontColor($r('app.color.primary'))
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
          .backgroundColor('#EBF2FF')
          .borderRadius(12)
          .margin({ right: 10 })
          .onClick(() => { this.weekView = !this.weekView })
        // 🌟 新增按钮缩小为加号，放在右上角
        Row() {
          SymbolGlyph($r('sys.symbol.plus')).fontSize(18).fontColor([Color.White])
        }
        .width(34).height(34).borderRadius(17).backgroundColor('#3F7EF6')
        .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
        .margin({ right: 16 })
        .onClick(() => this.openDialog(true))
      }.width('100%').height(60).padding({ left: 16 }).margin({ bottom: 10 })

      if (this.weekView) {
        // 🌟 本周视图：按天纵向分组，日程占满整行宽度，避免 7 列窄格把内容截断
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.weekDates(), (date: string, idx: number) => {
              Column({ space: 8 }) {
                Row({ space: 8 }) {
                  Text(`周${this.weekDayName(idx)}`)
                    .fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
                  Text(date.slice(5)).fontSize(12).fontColor($r('app.color.text_hint'))
                  if (date === getTodayStr()) {
                    Text('今天')
                      .fontSize(9).fontColor(Color.White)
                      .backgroundColor($r('app.color.primary'))
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 }).borderRadius(6)
                  }
                  Blank()
                  Text(`${this.itemsOnDate(date).length} 项`)
                    .fontSize(11).fontColor($r('app.color.text_hint'))
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                if (this.itemsOnDate(date).length === 0) {
                  Text('暂无安排').fontSize(12).fontColor($r('app.color.text_hint')).width('100%')
                } else {
                  ForEach(this.itemsOnDate(date), (item: ScheduleItem) => {
                    Row({ space: 8 }) {
                      Text(item.time)
                        .fontSize(11).fontWeight(FontWeight.Medium).fontColor(Color.White)
                        .width(46).textAlign(TextAlign.Center)
                        .padding({ top: 4, bottom: 4 })
                        .backgroundColor($r('app.color.primary')).borderRadius(6)
                      Text(item.content)
                        .fontSize(13).fontColor($r('app.color.text_main'))
                        .layoutWeight(1)
                        .maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis })
                      SymbolGlyph($r('sys.symbol.chevron_right'))
                        .fontSize(14).fontColor([$r('app.color.text_hint')])
                    }
                    .width('100%')
                    .padding(8)
                    .backgroundColor($r('app.color.field_bg'))
                    .borderRadius(8)
                    .alignItems(VerticalAlign.Center)
                    .onClick(() => this.openDialog(false, item))
                  }, (item: ScheduleItem) => item.id)
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(12)
              .alignItems(HorizontalAlign.Start)
            }, (date: string) => date)
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      } else {
      List({ space: 10 }) {
        if (this.getTodayList().length > 0) {
          ListItem() {
            this.sectionHeader('今日日程', this.getTodayList().length)
          }
          ForEach(this.getTodayList(), (item: ScheduleItem) => {
            ListItem() {
              this.itemCard(item, false)
            }
          }, (item: ScheduleItem) => `${item.id}_${item.content}_${item.date}_${item.time}`)
        }
        if (this.getUpcomingList().length > 0) {
          ListItem() {
            this.sectionHeader('后续日程', this.getUpcomingList().length)
          }
          ForEach(this.getUpcomingList(), (item: ScheduleItem) => {
            ListItem() {
              this.itemCard(item, false)
            }
          }, (item: ScheduleItem) => `${item.id}_${item.content}_${item.date}_${item.time}`)
        }
        if (this.getExpiredList().length > 0) {
          ListItem() {
            this.sectionHeader('已过期', this.getExpiredList().length)
          }
          ForEach(this.getExpiredList(), (item: ScheduleItem) => {
            ListItem() {
              this.itemCard(item, true)
            }
          }, (item: ScheduleItem) => `${item.id}_${item.content}_${item.date}_${item.time}`)
        }
        if (this.scheduleList.length === 0) {
          ListItem() {
            this.emptyTip('暂无日程安排，点击右上角 + 新增吧')
          }
        }
      }.width('90%').layoutWeight(1).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }
}
