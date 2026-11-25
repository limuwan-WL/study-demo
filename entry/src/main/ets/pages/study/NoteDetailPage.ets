import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import {
  NoteItem,
  NotebookItem,
  NoteLink,
  formatStamp,
  visibilityLabel,
  noteRefText
} from '../../model/DataModel'
import { NoteShare } from '../../utils/NoteShare'
import { NoteShareDialog } from '../../components/NoteDialogs'
import { Permission } from '../../model/PermissionModel'

@Entry
@Component
struct NoteDetailPage {
  @StorageLink('noteList') noteList: NoteItem[] = []
  @StorageLink('notebookList') notebookList: NotebookItem[] = []
  noteId: string = ''
  @State previewUri: string = ''
  private dialogOpen: boolean = false
  shareController: CustomDialogController = new CustomDialogController({
    builder: NoteShareDialog({}),
    customStyle: true
  })

  aboutToAppear() {
    let params = router.getParams() as Record<string, string>
    if (params && params['id']) {
      this.noteId = params['id']
    }
  }

  // 🌟 从编辑器返回时强制刷新：编辑器可能只替换了数组内元素，直接读缓存会显示旧的可见范围
  onPageShow(): void {
    this.noteList = this.noteList.slice()
  }

  getNote(): NoteItem | undefined {
    return this.noteList.find((n: NoteItem) => n.id === this.noteId)
  }

  bookName(id: string): string {
    let book = this.notebookList.find((b: NotebookItem) => b.id === id)
    return book === undefined ? '默认笔记本' : book.name
  }

  refText(): string {
    let note = this.getNote()
    return note === undefined ? '' : noteRefText(note)
  }

  openEditor() {
    router.pushUrl({ url: 'pages/study/NoteEditorPage', params: { id: this.noteId } })
  }

  openShare() {
    let note = this.getNote()
    if (note === undefined || this.dialogOpen) {
      return
    }
    this.dialogOpen = true
    let target: NoteItem = note
    this.shareController = new CustomDialogController({
      builder: NoteShareDialog({
        noteTitle: target.title,
        link: NoteShare.link(target),
        noteVisibility: target.visibility,
        onClose: () => {
          this.dialogOpen = false
        },
        onVisibility: (v: string) => {
          this.setVisibility(v)
        },
        onCopy: () => {
          NoteShare.copy(NoteShare.link(target)).then((ok: boolean) => {
            promptAction.showToast({ message: ok ? '分享链接已复制' : '复制失败，请重试' })
          })
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.shareController.open()
  }

  setVisibility(v: string) {
    this.noteList = this.noteList.map((n: NoteItem) => {
      if (n.id === this.noteId) {
        n.visibility = v
        // 🌟 设为课程可见时补绑具体课程，避免历史笔记仍走「任意课程可见」旧规则
        if (v === 'course' && (n.courseId === undefined || n.courseId === '')) {
          let ids = Permission.myCourseIds()
          n.courseId = ids.length > 0 ? ids[0] : ''
        }
        n.version += 1
        n.syncState = 'pending'
      }
      return n
    })
    promptAction.showToast({ message: `已设为${visibilityLabel(v)}` })
  }

  handleDelete() {
    this.noteList = this.noteList.map((n: NoteItem) => {
      if (n.id === this.noteId) {
        n.isDeleted = true
        n.deletedAt = Date.now()
        n.pinned = false
        n.version += 1
        n.syncState = 'pending'
      }
      return n
    })
    promptAction.showToast({ message: '已移入回收站，保留 30 天' })
    router.back()
  }

  openLink(link: NoteLink) {
    router.pushUrl({ url: 'pages/common/WebViewPage', params: { url: link.url, title: link.title } })
  }

  @Builder
  emptyTip(msg: string) {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.inbox')).fontSize(40).fontColor([$r('app.color.text_hint')])
      Text(msg).fontSize(14).fontColor($r('app.color.text_sub'))
    }.width('100%').padding({ top: 120 })
  }

  @Builder
  header() {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([$r('app.color.text_main')])
        .onClick(() => router.back())
      Text('笔记详情').fontSize(20).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_main')).margin({ left: 12 })
      Blank()
      if (this.getNote() !== undefined) {
        Text('分享').fontSize(14).fontColor($r('app.color.primary'))
          .padding({ left: 10, right: 14, top: 8, bottom: 8 })
          .onClick(() => this.openShare())
      }
    }.width('100%').height(60).padding({ left: 16 })
  }

  @Builder
  infoChip(label: string, color: ResourceColor, bg: ResourceColor) {
    Text(label)
      .fontSize(10).fontColor(color).backgroundColor(bg)
      .padding({ left: 7, right: 7, top: 2, bottom: 2 }).borderRadius(5)
  }

  build() {
    Stack() {
      Column() {
        this.header()

        if (this.getNote() === undefined) {
          this.emptyTip('笔记不存在或已被删除')
        } else {
          Scroll() {
            Column({ space: 14 }) {
              Column({ space: 10 }) {
                Text(this.getNote()!.title === '' ? '无标题笔记' : this.getNote()!.title)
                  .fontSize(21).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
                  .width('100%')

                Row({ space: 6 }) {
                  this.infoChip(this.bookName(this.getNote()!.notebookId), $r('app.color.primary'), $r('app.color.primary_weak'))
                  this.infoChip(visibilityLabel(this.getNote()!.visibility), $r('app.color.success'), $r('app.color.field_bg'))
                  Blank()
                  Text(this.getNote()!.syncState === 'pending' ? '待同步'
                    : (this.getNote()!.syncState === 'conflict' ? '版本冲突' : '已同步'))
                    .fontSize(10).fontColor($r('app.color.text_hint'))
                }.width('100%')

                Text(`创建于 ${formatStamp(this.getNote()!.createTime)} · 修改于 ${formatStamp(this.getNote()!.updatedAt)}`)
                  .fontSize(11).fontColor($r('app.color.text_hint')).width('100%')

                if (this.getNote()!.tags.length > 0) {
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(this.getNote()!.tags, (tag: string) => {
                      Text(`#${tag}`)
                        .fontSize(11).fontColor($r('app.color.text_sub'))
                        .backgroundColor($r('app.color.field_bg'))
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .borderRadius(6).margin({ right: 6, bottom: 6 })
                    }, (tag: string) => tag)
                  }.width('100%')
                }

                // 🌟 课程引用：课件 / 视频时间节点
                if (this.refText() !== '') {
                  Row({ space: 6 }) {
                    Text('📎').fontSize(12)
                    Text(this.refText())
                      .fontSize(12).fontColor($r('app.color.primary'))
                      .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .width('100%').padding(10)
                  .backgroundColor($r('app.color.primary_weak')).borderRadius(8)
                }

                Divider().color($r('app.color.divider_color'))

                Text(this.getNote()!.content === '' ? '（无正文）' : this.getNote()!.content)
                  .fontSize(15).fontColor($r('app.color.text_body')).lineHeight(24).width('100%')

                // 图片：点击放大查看
                if (this.getNote()!.images.length > 0) {
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(this.getNote()!.images, (uri: string, index: number) => {
                      Image('file://' + uri)
                        .width(96).height(96).borderRadius(10)
                        .objectFit(ImageFit.Cover)
                        .backgroundColor($r('app.color.field_bg'))
                        .margin({ right: 8, bottom: 8 })
                        .onClick(() => this.previewUri = uri)
                    }, (uri: string, index: number) => `${this.noteId}_${index}`)
                  }.width('100%')
                }

                // 正文内链接
                if (this.getNote()!.links.length > 0) {
                  Column({ space: 6 }) {
                    ForEach(this.getNote()!.links, (link: NoteLink) => {
                      Row({ space: 8 }) {
                        Text('🔗').fontSize(12)
                        Column({ space: 2 }) {
                          Text(link.title).fontSize(13).fontColor($r('app.color.primary'))
                            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                          Text(link.url).fontSize(10).fontColor($r('app.color.text_hint'))
                            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([$r('app.color.text_hint')])
                      }
                      .width('100%').padding(10)
                      .backgroundColor($r('app.color.field_bg')).borderRadius(10)
                      .onClick(() => this.openLink(link))
                    }, (link: NoteLink) => link.id)
                  }.width('100%')
                }
              }
              .width('100%').padding(20)
              .backgroundColor($r('app.color.card_bg')).borderRadius(16)
              .alignItems(HorizontalAlign.Start)

              Row({ space: 12 }) {
                Button('编辑').layoutWeight(1).height(44).backgroundColor('#3F7EF6')
                  .onClick(() => this.openEditor())
                Button('删除').layoutWeight(1).height(44).backgroundColor('#EF4444')
                  .onClick(() => this.handleDelete())
              }.width('100%').margin({ top: 4 })
            }
            .width('92%').padding({ top: 6, bottom: 30 })
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1).scrollBar(BarState.Off)
          .align(Alignment.Top)
        }
      }
      .width('100%').height('100%')
      .backgroundColor($r('app.color.page_bg'))

      // 图片全屏预览
      if (this.previewUri !== '') {
        Column() {
          Image('file://' + this.previewUri)
            .width('100%').height('85%')
            .objectFit(ImageFit.Contain)
          Text('点击任意处关闭').fontSize(12).fontColor(Color.White).margin({ top: 12 })
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.92)')
        .onClick(() => this.previewUri = '')
      }
    }
    .width('100%').height('100%')
  }
}
