// 🌟 互动任务通用弹窗：日期 + 时间选择（定时发布 / 练习起止时间）
@CustomDialog
export struct DateTimeDialog {
  controller: CustomDialogController
  title: string = '选择时间'
  initial: number = 0
  onConfirm: (ts: number) => void = () => {}
  @State picked: Date = new Date()

  aboutToAppear(): void {
    this.picked = new Date(this.initial > 0 ? this.initial : Date.now() + 30 * 60000)
  }

  build() {
    Column({ space: 10 }) {
      Text(this.title).fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      DatePicker({
        start: new Date(2024, 0, 1),
        end: new Date(2031, 11, 31),
        selected: this.picked
      })
        .onChange((v: DatePickerResult) => {
          let d = new Date(this.picked.getTime())
          let y = v.year === undefined ? d.getFullYear() : v.year
          let m = v.month === undefined ? d.getMonth() : v.month
          let day = v.day === undefined ? d.getDate() : v.day
          d.setFullYear(y, m, day)
          this.picked = d
        })
      TimePicker({ selected: this.picked })
        .onChange((v: TimePickerResult) => {
          let d = new Date(this.picked.getTime())
          let h = v.hour === undefined ? d.getHours() : v.hour
          let mi = v.minute === undefined ? d.getMinutes() : v.minute
          d.setHours(h, mi, 0, 0)
          this.picked = d
        })
        .height(140)
      Row({ space: 12 }) {
        Text('取消')
          .fontSize(15).fontColor($r('app.color.text_sub'))
          .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 10, bottom: 10 })
          .onClick(() => this.controller.close())
        Text('确定')
          .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
          .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 10, bottom: 10 })
          .backgroundColor($r('app.color.primary')).borderRadius(20)
          .onClick(() => {
            this.onConfirm(this.picked.getTime())
            this.controller.close()
          })
      }.width('100%').margin({ top: 6 })
    }
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(20)
  }
}
