import { promptAction } from '@kit.ArkUI'
import { NotebookItem } from '../model/DataModel'

// ==================== 通用输入弹窗（新建 / 重命名笔记本、标签等） ====================
@CustomDialog
export struct NoteTextDialog {
  controller: CustomDialogController
  title: string = ''
  placeholder: string = ''
  confirmLabel: string = '确定'
  maxLength: number = 20
  @State value: string = ''
  onClose: () => void = () => {}
  onConfirm: (v: string) => void = () => {}

  aboutToDisappear(): void {
    this.onClose()
  }

  build() {
    Column({ space: 14 }) {
      Text(this.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      TextInput({ text: this.value, placeholder: this.placeholder })
        .onChange((v: string) => this.value = v)
        .backgroundColor($r('app.color.field_bg'))
        .maxLength(this.maxLength)
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).backgroundColor($r('app.color.btn_cancel'))
          .onClick(() => this.controller.close())
        Button(this.confirmLabel).layoutWeight(1).onClick(() => {
          let v = this.value.trim()
          if (v === '') {
            promptAction.showToast({ message: '内容不能为空' })
            return
          }
          this.onConfirm(v)
          this.controller.close()
        })
      }.width('100%')
    }.padding(20).backgroundColor($r('app.color.card_bg')).borderRadius(16)
  }
}

// ==================== 插入链接弹窗 ====================
@CustomDialog
export struct NoteLinkDialog {
  controller: CustomDialogController
  @State linkTitle: string = ''
  @State linkUrl: string = ''
  onClose: () => void = () => {}
  onConfirm: (title: string, url: string) => void = () => {}

  aboutToDisappear(): void {
    this.onClose()
  }

  build() {
    Column({ space: 14 }) {
      Text('插入链接').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      TextInput({ text: this.linkTitle, placeholder: '链接标题（选填）' })
        .onChange((v: string) => this.linkTitle = v)
        .backgroundColor($r('app.color.field_bg'))
      TextInput({ text: this.linkUrl, placeholder: 'https://...' })
        .onChange((v: string) => this.linkUrl = v)
        .backgroundColor($r('app.color.field_bg'))
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).backgroundColor($r('app.color.btn_cancel'))
          .onClick(() => this.controller.close())
        Button('插入').layoutWeight(1).onClick(() => {
          let url = this.linkUrl.trim()
          if (url === '') {
            promptAction.showToast({ message: '请输入链接地址' })
            return
          }
          if (url.indexOf('http://') !== 0 && url.indexOf('https://') !== 0) {
            url = 'https://' + url
          }
          let title = this.linkTitle.trim() === '' ? url : this.linkTitle.trim()
          this.onConfirm(title, url)
          this.controller.close()
        })
      }.width('100%')
    }.padding(20).backgroundColor($r('app.color.card_bg')).borderRadius(16)
  }
}

// ==================== 二次确认弹窗（删除 / 永久删除 / 清空） ====================
@CustomDialog
export struct NoteConfirmDialog {
  controller: CustomDialogController
  title: string = '确认操作'
  message: string = ''
  confirmLabel: string = '确定'
  danger: boolean = true
  onClose: () => void = () => {}
  onConfirm: () => void = () => {}

  aboutToDisappear(): void {
    this.onClose()
  }

  build() {
    Column({ space: 14 }) {
      Text(this.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      Text(this.message).fontSize(14).fontColor($r('app.color.text_sub'))
        .width('100%').textAlign(TextAlign.Center)
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).backgroundColor($r('app.color.btn_cancel'))
          .onClick(() => this.controller.close())
        Button(this.confirmLabel).layoutWeight(1)
          .backgroundColor(this.danger ? '#EF4444' : '#3F7EF6')
          .onClick(() => {
            this.onConfirm()
            this.controller.close()
          })
      }.width('100%').margin({ top: 6 })
    }.padding(20).backgroundColor($r('app.color.card_bg')).borderRadius(16)
  }
}

// ==================== 移动笔记到其他笔记本 ====================
@CustomDialog
export struct NoteMoveDialog {
  controller: CustomDialogController
  notebooks: NotebookItem[] = []
  currentId: string = ''
  onClose: () => void = () => {}
  onPick: (id: string) => void = () => {}

  aboutToDisappear(): void {
    this.onClose()
  }

  build() {
    Column({ space: 10 }) {
      Text('移动到笔记本').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        .width('100%')
      List({ space: 6 }) {
        ForEach(this.notebooks, (b: NotebookItem) => {
          ListItem() {
            Row() {
              Text(b.name).fontSize(15).fontColor($r('app.color.text_main')).layoutWeight(1)
              if (b.id === this.currentId) {
                Text('当前').fontSize(11).fontColor($r('app.color.primary'))
              }
            }
            .width('100%').padding(12)
            .backgroundColor(b.id === this.currentId ? $r('app.color.primary_weak') : $r('app.color.field_bg'))
            .borderRadius(10)
            .onClick(() => {
              this.onPick(b.id)
              this.controller.close()
            })
          }
        }, (b: NotebookItem) => b.id)
      }.width('100%').height(240).scrollBar(BarState.Off)
      Button('取消').width('100%').backgroundColor($r('app.color.btn_cancel'))
        .onClick(() => this.controller.close())
    }.padding(20).backgroundColor($r('app.color.card_bg')).borderRadius(16)
  }
}

// ==================== 分享笔记：权限 + 分享链接 ====================
@CustomDialog
export struct NoteShareDialog {
  controller: CustomDialogController
  noteTitle: string = ''
  link: string = ''
  @State noteVisibility: string = 'private'
  onClose: () => void = () => {}
  onVisibility: (v: string) => void = () => {}
  onCopy: () => void = () => {}
  onToGroup: () => void = () => {}

  aboutToDisappear(): void {
    this.onClose()
  }

  @Builder
  visChip(value: string, label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.noteVisibility === value ? Color.White : $r('app.color.text_sub'))
      .backgroundColor(this.noteVisibility === value ? $r('app.color.primary') : $r('app.color.field_bg'))
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .borderRadius(14)
      .onClick(() => {
        this.noteVisibility = value
        this.onVisibility(value)
      })
  }

  build() {
    Column({ space: 14 }) {
      Text('分享笔记').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      Text(this.noteTitle).fontSize(13).fontColor($r('app.color.text_sub'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')

      Column({ space: 8 }) {
        Text('可见范围').fontSize(12).fontColor($r('app.color.text_sub')).width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          Row() { this.visChip('private', '私有') }.margin({ right: 8, bottom: 8 })
          Row() { this.visChip('course', '仅课程内可见') }.margin({ right: 8, bottom: 8 })
          Row() { this.visChip('public', '公开') }.margin({ right: 8, bottom: 8 })
        }.width('100%')
      }.width('100%')

      Column({ space: 6 }) {
        Text('分享链接').fontSize(12).fontColor($r('app.color.text_sub')).width('100%')
        Text(this.link).fontSize(12).fontColor($r('app.color.primary'))
          .width('100%').padding(10).backgroundColor($r('app.color.field_bg')).borderRadius(8)
        Text('本地模拟生成，无真实后端，链接用于演示分享流程')
          .fontSize(11).fontColor($r('app.color.text_hint')).width('100%')
      }.width('100%')

      Row({ space: 10 }) {
        Button('关闭').layoutWeight(1).backgroundColor($r('app.color.btn_cancel'))
          .onClick(() => this.controller.close())
        Button('复制链接').layoutWeight(1).onClick(() => {
          this.onCopy()
          this.controller.close()
        })
      }.width('100%')
      Button('分享到班级群')
        .width('100%')
        .backgroundColor($r('app.color.primary_weak'))
        .fontColor($r('app.color.primary'))
        .onClick(() => {
          this.onToGroup()
          this.controller.close()
        })
    }.padding(20).backgroundColor($r('app.color.card_bg')).borderRadius(16)
  }
}
