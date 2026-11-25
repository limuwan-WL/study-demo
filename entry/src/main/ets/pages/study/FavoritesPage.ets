import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { FavItem } from '../../model/DataModel';

// 🌟 该弹窗仅用于手动录入网址收藏（帖子由发现页收藏自动加入）
@CustomDialog
struct FavDialog {
  controller: CustomDialogController
  @State inputTitle: string = ''
  @State inputUrl: string = ''
  isAdd: boolean = true
  onClose: () => void = () => {}
  onConfirm: (title: string, url: string) => void = () => {}

  aboutToDisappear(): void {
    this.onClose()
  }

  build() {
    Column({ space: 16 }) {
      Text(this.isAdd ? '添加网址收藏' : '修改网址收藏').fontSize(18).fontWeight(FontWeight.Bold)
      TextInput({ text: this.inputTitle, placeholder: '标题' })
        .onChange((v: string) => this.inputTitle = v).backgroundColor($r('app.color.field_bg'))
      TextInput({ text: this.inputUrl, placeholder: '网址，如：https://...' })
        .onChange((v: string) => this.inputUrl = v).backgroundColor($r('app.color.field_bg'))
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).backgroundColor($r('app.color.btn_cancel')).onClick(() => this.controller.close())
        Button('确定').layoutWeight(1).onClick(() => {
          if (this.inputTitle.trim() === '' || this.inputUrl.trim() === '') {
            promptAction.showToast({ message: '标题和网址不能为空' })
            return
          }
          this.onConfirm(this.inputTitle.trim(), this.inputUrl.trim())
          this.controller.close()
        })
      }.width('100%')
    }.padding(20).backgroundColor($r('app.color.card_bg')).borderRadius(16)
  }
}

@Entry
@Component
struct FavoritesPage {
  @StorageLink('favList') favList: FavItem[] = []
  @State dialogVisible: boolean = false
  dialogController: CustomDialogController = new CustomDialogController({
    builder: FavDialog({}),
    customStyle: true
  })

  openDialog(isAdd: boolean, item?: FavItem) {
    if (this.dialogVisible) {
      return
    }
    this.dialogVisible = true
    this.dialogController = new CustomDialogController({
      builder: FavDialog({
        isAdd: isAdd,
        inputTitle: item ? item.title : '',
        inputUrl: item ? item.url : '',
        onClose: () => {
          this.dialogVisible = false
        },
        onConfirm: (t: string, u: string) => {
          this.handleConfirm(t, u, item ? item.id : '')
        }
      }),
      autoCancel: true, // 点击遮罩层可关闭
      customStyle: true
    })
    this.dialogController.open()
  }

  handleConfirm(title: string, url: string, editId: string) {
    if (editId === '') {
      let item = new FavItem(title, url, 'link')
      this.favList = [item, ...this.favList]
      promptAction.showToast({ message: '新增成功' })
    } else {
      this.favList = this.favList.map((f: FavItem) => {
        if (f.id === editId) {
          f.title = title
          f.url = url
        }
        return f
      })
      promptAction.showToast({ message: '修改成功' })
    }
  }

  handleDelete(id: string) {
    this.favList = this.favList.filter((f: FavItem) => f.id !== id)
    promptAction.showToast({ message: '删除成功' })
  }

  // 🌟 网址收藏 → 应用内网页；帖子收藏 → 帖子详情
  openItem(item: FavItem) {
    if (item.type === 'post') {
      router.pushUrl({ url: 'pages/social/PostDetailPage', params: { postId: item.postId } })
    } else if (item.url !== '') {
      // 🌟 带上收藏项标题，网页页顶部按收藏项标题显示（不传则回退站点名）
      router.pushUrl({ url: 'pages/common/WebViewPage', params: { url: item.url, title: item.title } })
    } else {
      promptAction.showToast({ message: '该收藏没有链接' })
    }
  }

  @Builder
  emptyTip(msg: string) {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.inbox')).fontSize(40).fontColor([$r('app.color.text_hint')])
      Text(msg).fontSize(14).fontColor($r('app.color.text_sub'))
    }.width('100%').padding({ top: 80 })
  }

  @Builder
  itemCard(item: FavItem) {
    Row() {
      Column({ space: 6 }) {
        Row({ space: 6 }) {
          // 来源标签：网址 / 帖子
          Text(item.type === 'post' ? '帖子' : '网址')
            .fontSize(10).fontColor(Color.White)
            .backgroundColor(item.type === 'post' ? '#8B5CF6' : '#3F7EF6')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 }).borderRadius(6)
          Text(item.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
            .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.width('100%')
        if (item.type === 'link' && item.url !== '') {
          Text(item.url).fontSize(12).fontColor('#3F7EF6').width('100%')
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (item.type === 'post') {
          Text('来自发现页，点击查看帖子详情').fontSize(12).fontColor($r('app.color.text_hint')).width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)
      .onClick(() => this.openItem(item))

      if (item.type === 'link') {
        Button('修改').fontSize(12).height(30).backgroundColor($r('app.color.btn_gray')).margin({ right: 10 })
          .onClick(() => this.openDialog(false, item))
      }
      Button('删除').fontSize(12).height(30).backgroundColor('#EF4444')
        .onClick(() => this.handleDelete(item.id))
    }
    .width('100%').padding(16).backgroundColor($r('app.color.card_bg')).borderRadius(8)
  }

  build() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([$r('app.color.text_main')]).onClick(() => router.back())
        Text('我的收藏夹').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 16 })
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

      List({ space: 10 }) {
        ForEach(this.favList, (item: FavItem) => {
          ListItem() {
            this.itemCard(item)
          }
        }, (item: FavItem) => `${item.id}_${item.title}_${item.url}`)
        if (this.favList.length === 0) {
          ListItem() {
            this.emptyTip('暂无收藏，可在发现页收藏帖子或手动添加网址')
          }
        }
      }.width('90%').layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }
}
