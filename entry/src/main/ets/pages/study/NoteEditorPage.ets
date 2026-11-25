import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { camera, cameraPicker } from '@kit.CameraKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import {
  NoteItem,
  NotebookItem,
  NoteLink,
  formatTime,
  normalizeNotebooks,
  visibilityLabel,
  NOTEBOOK_DEFAULT_ID
} from '../../model/DataModel'
import { NoteTextDialog, NoteLinkDialog } from '../../components/NoteDialogs'
import { OfflineBar } from '../../components/StatusViews'
import { UploadPolicy } from '../../utils/UploadPolicy'
import { Permission } from '../../model/PermissionModel'
import { subjectById } from '../../model/SubjectModel'

// 🌟 课程可见笔记的绑定目标
class CourseOption {
  id: string = ''
  name: string = ''

  constructor(id: string, name: string) {
    this.id = id
    this.name = name
  }
}

@Entry
@Component
struct NoteEditorPage {
  @StorageLink('noteList') noteList: NoteItem[] = []
  @StorageLink('notebookList') notebookList: NotebookItem[] = []

  noteId: string = ''
  isNew: boolean = true
  missing: boolean = false

  @State title: string = ''
  @State content: string = ''
  @State tags: string[] = []
  @State images: string[] = []
  @State links: NoteLink[] = []
  @State notebookId: string = NOTEBOOK_DEFAULT_ID
  @State noteVisibility: string = 'private'
  // 🌟 课程可见时绑定的具体课程
  @State noteCourseId: string = ''
  // 🌟 课程引用：课件名称 / 视频时间节点
  @State refTitle: string = ''
  @State refTime: string = ''
  @State saveState: string = ''
  @State previewUri: string = ''
  private dirty: boolean = false
  private saveTimer: number = -1
  private dialogOpen: boolean = false

  tagController: CustomDialogController = new CustomDialogController({ builder: NoteTextDialog({}), customStyle: true })
  linkController: CustomDialogController = new CustomDialogController({ builder: NoteLinkDialog({}), customStyle: true })

  aboutToAppear() {
    let params = router.getParams() as Record<string, string>
    let id = params && params['id'] ? params['id'] : ''
    let notebook = params && params['notebookId'] ? params['notebookId'] : NOTEBOOK_DEFAULT_ID

    if (this.notebookList.length === 0) {
      this.notebookList = normalizeNotebooks([])
    }

    if (id === '') {
      this.isNew = true
      this.notebookId = notebook
      this.saveState = '新建笔记，输入后自动保存'
      return
    }

    let note = this.noteList.find((n: NoteItem) => n.id === id)
    if (note === undefined) {
      this.missing = true
      this.saveState = '笔记不存在或已被删除'
      return
    }
    this.isNew = false
    this.noteId = note.id
    this.title = note.title
    this.content = note.content
    this.tags = note.tags.slice()
    this.images = note.images.slice()
    this.links = note.links.slice()
    this.notebookId = note.notebookId
    this.noteVisibility = note.visibility
    this.noteCourseId = note.courseId === undefined ? '' : note.courseId
    this.refTitle = note.refTitle === undefined ? '' : note.refTitle
    this.refTime = note.refTime === undefined ? '' : note.refTime
    this.saveState = `上次保存 ${formatTime(new Date(note.updatedAt))}`
  }

  aboutToDisappear() {
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer)
      this.saveTimer = -1
    }
    if (this.dirty || this.isNew) {
      this.saveNow(true)
    }
  }

  hasDraft(): boolean {
    return this.title.trim() !== '' || this.content.trim() !== '' ||
      this.images.length > 0 || this.tags.length > 0 || this.links.length > 0 ||
      this.refTitle.trim() !== '' || this.refTime.trim() !== ''
  }

  markDirty() {
    if (this.missing) {
      return
    }
    this.dirty = true
    this.saveState = '正在编辑…'
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer)
    }
    // 实时自动保存：停止输入 600ms 后落盘
    this.saveTimer = setTimeout(() => {
      this.saveNow(true)
    }, 600)
  }

  saveNow(silent: boolean) {
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer)
      this.saveTimer = -1
    }
    if (this.missing) {
      return
    }
    if (!this.dirty && !this.isNew) {
      return
    }
    if (this.isNew && !this.hasDraft()) {
      return
    }

    let now = Date.now()
    let finalTitle = this.title.trim()
    if (finalTitle === '') {
      if (this.content.trim() === '') {
        finalTitle = '图片笔记'
      } else {
        finalTitle = this.content.trim().substring(0, 20)
      }
    }

    // 🌟 课程可见但未手动选择课程时，默认绑定第一门可访问课程
    if (this.noteVisibility === 'course' && this.noteCourseId === '') {
      let opts = this.courseOptions()
      if (opts.length > 0) {
        this.noteCourseId = opts[0].id
      }
    }

    if (this.isNew) {
      let note = new NoteItem(finalTitle, this.content)
      note.notebookId = this.notebookId
      note.tags = this.tags.slice()
      note.images = this.images.slice()
      note.links = this.links.slice()
      note.visibility = this.noteVisibility
      note.courseId = this.noteCourseId
      note.refTitle = this.refTitle.trim()
      note.refTime = this.refTime.trim()
      note.updatedAt = now
      note.version = 1
      note.baseVersion = 0
      note.syncState = 'pending'
      this.noteList = [note].concat(this.noteList)
      this.noteId = note.id
      this.isNew = false
    } else {
      let exists = this.noteList.some((n: NoteItem) => n.id === this.noteId)
      if (!exists) {
        this.missing = true
        this.saveState = '笔记已被删除，无法保存'
        return
      }
      this.noteList = this.noteList.map((n: NoteItem) => {
        if (n.id === this.noteId) {
          n.title = finalTitle
          n.content = this.content
          n.notebookId = this.notebookId
          n.tags = this.tags.slice()
          n.images = this.images.slice()
          n.links = this.links.slice()
          n.visibility = this.noteVisibility
          n.courseId = this.noteCourseId
          n.refTitle = this.refTitle.trim()
          n.refTime = this.refTime.trim()
          n.updatedAt = now
          n.version += 1
          n.syncState = 'pending'
        }
        return n
      })
    }

    this.title = finalTitle
    this.dirty = false
    this.saveState = `已自动保存 ${formatTime(new Date(now))}`
    if (!silent) {
      promptAction.showToast({ message: '已保存' })
    }
  }

  goBack() {
    this.saveNow(true)
    router.back()
  }

  // ==================== 图片 ====================
  async addFromGallery() {
    try {
      let options = new photoAccessHelper.PhotoSelectOptions()
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      options.maxSelectNumber = 9
      let result = await new photoAccessHelper.PhotoViewPicker().select(options)
      if (result.photoUris.length === 0) {
        return
      }
      let ctx = getContext(this) as common.UIAbilityContext
      let next = this.images.slice()
      let base = Date.now()
      let skipped: string[] = []
      // 🌟 统一上传策略：大小上限 → 自动压缩 → 内容审核，违规图片直接拦截
      for (let index = 0; index < result.photoUris.length; index++) {
        let dest = `${ctx.filesDir}/note_${base}_${index}.jpg`
        let up = await UploadPolicy.prepareImage(result.photoUris[index], dest, `笔记图片_${base}_${index}.jpg`)
        if (up.ok) {
          next.push(up.uri)
        } else {
          try {
            fs.unlinkSync(dest)
          } catch (e) {
            // 未落盘时无需清理
          }
          skipped.push(up.reason)
        }
      }
      if (next.length !== this.images.length) {
        this.images = next
        this.markDirty()
      }
      if (skipped.length > 0) {
        promptAction.showToast({ message: `已拦截 ${skipped.length} 张图片：${skipped[0]}` })
      }
    } catch (err) {
      promptAction.showToast({ message: '未能读取所选图片，请重试' })
    }
  }

  async takePhoto() {
    try {
      let ctx = getContext(this) as common.UIAbilityContext
      let profile = new cameraPicker.PickerProfile()
      profile.cameraPosition = camera.CameraPosition.CAMERA_POSITION_BACK
      let result = await cameraPicker.pick(ctx, [cameraPicker.PickerMediaType.PHOTO], profile)
      if (result.resultCode !== 0 || result.resultUri === undefined || result.resultUri === '') {
        return
      }
      let dest = `${ctx.filesDir}/note_cam_${Date.now()}.jpg`
      // 🌟 拍照同样走统一上传策略：压缩 + 审核
      let up = await UploadPolicy.prepareImage(result.resultUri, dest, `笔记拍照_${Date.now()}.jpg`)
      if (!up.ok) {
        promptAction.showToast({ message: `图片未保存：${up.reason}` })
        return
      }
      let next = this.images.slice()
      next.push(up.uri)
      this.images = next
      this.markDirty()
    } catch (err) {
      promptAction.showToast({ message: '无法打开相机，请重试' })
    }
  }

  removeImage(index: number) {
    let next = this.images.slice()
    next.splice(index, 1)
    this.images = next
    this.markDirty()
  }

  // ==================== 标签 / 链接 ====================
  openTagDialog() {
    if (this.dialogOpen) {
      return
    }
    this.dialogOpen = true
    this.tagController = new CustomDialogController({
      builder: NoteTextDialog({
        title: '添加标签',
        placeholder: '如：期末复习',
        confirmLabel: '添加',
        maxLength: 12,
        onClose: () => {
          this.dialogOpen = false
        },
        onConfirm: (v: string) => {
          if (this.tags.indexOf(v) >= 0) {
            promptAction.showToast({ message: '标签已存在' })
            return
          }
          let next = this.tags.slice()
          next.push(v)
          this.tags = next
          this.markDirty()
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.tagController.open()
  }

  removeTag(index: number) {
    let next = this.tags.slice()
    next.splice(index, 1)
    this.tags = next
    this.markDirty()
  }

  openLinkDialog() {
    if (this.dialogOpen) {
      return
    }
    this.dialogOpen = true
    this.linkController = new CustomDialogController({
      builder: NoteLinkDialog({
        onClose: () => {
          this.dialogOpen = false
        },
        onConfirm: (title: string, url: string) => {
          let next = this.links.slice()
          next.push(new NoteLink(title, url))
          this.links = next
          this.markDirty()
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.linkController.open()
  }

  removeLink(index: number) {
    let next = this.links.slice()
    next.splice(index, 1)
    this.links = next
    this.markDirty()
  }

  books(): NotebookItem[] {
    return this.notebookList.slice().sort((a: NotebookItem, b: NotebookItem) => a.order - b.order)
  }

  // ==================== UI ====================
  @Builder
  header() {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([$r('app.color.text_main')])
      }
      .width(40).height(48)
      .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
      .onClick(() => this.goBack())
      Text(this.isNew ? '新建笔记' : '编辑笔记').fontSize(20).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_main')).margin({ left: 4 })
      Blank()
      Text(this.saveState).fontSize(11).fontColor($r('app.color.text_hint'))
      Text('完成').fontSize(14).fontColor($r('app.color.primary'))
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .onClick(() => this.goBack())
    }.width('100%').height(60).padding({ left: 8 })
  }

  @Builder
  bookChip(book: NotebookItem) {
    Text(book.name)
      .fontSize(12)
      .fontColor(this.notebookId === book.id ? Color.White : $r('app.color.text_sub'))
      .backgroundColor(this.notebookId === book.id ? $r('app.color.primary') : $r('app.color.field_bg'))
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .borderRadius(14)
      .onClick(() => {
        this.notebookId = book.id
        this.markDirty()
      })
  }

  // 🌟 可绑定的课程：取自当前用户的选课 / 授课 / 助教课程
  courseOptions(): CourseOption[] {
    let ids = Permission.myCourseIds()
    let list: CourseOption[] = []
    ids.forEach((id: string) => {
      list.push(new CourseOption(id, subjectById(id).name))
    })
    // 历史笔记绑定的课程可能已不在可选范围，仍保留展示以免静默丢失
    if (this.noteCourseId !== '' && ids.indexOf(this.noteCourseId) < 0) {
      list.push(new CourseOption(this.noteCourseId, subjectById(this.noteCourseId).name))
    }
    return list
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
        // 🌟 切到课程可见时默认选中第一门可绑定课程
        if (value === 'course' && this.noteCourseId === '') {
          let opts = this.courseOptions()
          if (opts.length > 0) {
            this.noteCourseId = opts[0].id
          }
        }
        this.markDirty()
      })
  }

  @Builder
  addTile(label: string, action: () => void) {
    Column({ space: 2 }) {
      Text('＋').fontSize(20).fontColor($r('app.color.primary'))
      Text(label).fontSize(10).fontColor($r('app.color.text_sub'))
    }
    .width(84).height(84).borderRadius(10)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.field_bg'))
    .border({ width: 1, color: $r('app.color.divider_color'), style: BorderStyle.Dashed })
    .onClick(() => action())
  }

  build() {
    Stack() {
      Column() {
        this.header()

        // 🌟 笔记属于编辑区：弱网时提示离线保存，联网后自动同步，冲突时弹窗
        Row() {
          OfflineBar({ text: '弱网离线：笔记已保存在本机，联网后自动同步；若与他人版本冲突会弹窗确认' })
        }
        .width('92%')
        .margin({ bottom: 8 })

        if (this.missing) {
          Column({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.inbox')).fontSize(40).fontColor([$r('app.color.text_hint')])
            Text('笔记不存在或已被删除').fontSize(14).fontColor($r('app.color.text_sub'))
          }.width('100%').padding({ top: 120 })
        } else {
          Scroll() {
            Column({ space: 14 }) {
              TextInput({ text: this.title, placeholder: '笔记标题' })
                .fontSize(20).fontWeight(FontWeight.Bold)
                .backgroundColor(Color.Transparent)
                .padding({ left: 0 })
                .placeholderColor($r('app.color.text_hint'))
                .onChange((v: string) => {
                  this.title = v
                  this.markDirty()
                })

              // 所属笔记本
              Column({ space: 6 }) {
                Text('所属笔记本').fontSize(11).fontColor($r('app.color.text_hint')).width('100%')
                Scroll() {
                  Row({ space: 8 }) {
                    ForEach(this.books(), (book: NotebookItem) => {
                      this.bookChip(book)
                    }, (book: NotebookItem) => `${book.id}_${book.name}`)
                  }.padding({ left: 2, right: 2 })
                }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%').height(36)
              }.width('100%').alignItems(HorizontalAlign.Start)

              // 正文
              TextArea({ text: this.content, placeholder: '开始记录…支持在下方添加图片与链接' })
                .fontSize(15).lineHeight(24)
                .width('100%').height(220)
                .backgroundColor($r('app.color.card_bg'))
                .borderRadius(12)
                .onChange((v: string) => {
                  this.content = v
                  this.markDirty()
                })

              // 图片
              Column({ space: 8 }) {
                Row() {
                  Text('图片').fontSize(12).fontColor($r('app.color.text_sub')).layoutWeight(1)
                  Text(`${this.images.length} 张`).fontSize(11).fontColor($r('app.color.text_hint'))
                }.width('100%')
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.images, (uri: string, index: number) => {
                    Stack({ alignContent: Alignment.TopEnd }) {
                      Image('file://' + uri)
                        .width(84).height(84).borderRadius(10)
                        .objectFit(ImageFit.Cover)
                        .backgroundColor($r('app.color.field_bg'))
                        .onClick(() => this.previewUri = uri)
                      Text('✕')
                        .fontSize(10).fontColor(Color.White)
                        .width(18).height(18).borderRadius(9)
                        .textAlign(TextAlign.Center)
                        .backgroundColor('rgba(0,0,0,0.55)')
                        .margin(4)
                        .onClick(() => this.removeImage(index))
                    }.width(84).height(84).margin({ right: 8, bottom: 8 })
                  }, (uri: string, index: number) => `${index}_${uri}`)
                  Row() {
                    this.addTile('相册', () => {
                      this.addFromGallery()
                    })
                  }.margin({ right: 8, bottom: 8 })
                  Row() {
                    this.addTile('拍照', () => {
                      this.takePhoto()
                    })
                  }.margin({ right: 8, bottom: 8 })
                }.width('100%')
              }.width('100%').alignItems(HorizontalAlign.Start)

              // 链接
              Column({ space: 8 }) {
                Row() {
                  Text('链接').fontSize(12).fontColor($r('app.color.text_sub')).layoutWeight(1)
                  Text('＋ 插入链接').fontSize(12).fontColor($r('app.color.primary'))
                    .onClick(() => this.openLinkDialog())
                }.width('100%')
                if (this.links.length > 0) {
                  Column({ space: 6 }) {
                    ForEach(this.links, (link: NoteLink, index: number) => {
                      Row({ space: 8 }) {
                        Text('🔗').fontSize(12)
                        Column({ space: 2 }) {
                          Text(link.title).fontSize(13).fontColor($r('app.color.primary'))
                            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                          Text(link.url).fontSize(10).fontColor($r('app.color.text_hint'))
                            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                        Text('✕').fontSize(12).fontColor($r('app.color.text_hint'))
                          .padding(6)
                          .onClick(() => this.removeLink(index))
                      }
                      .width('100%').padding(10)
                      .backgroundColor($r('app.color.card_bg')).borderRadius(10)
                    }, (link: NoteLink, index: number) => link.id)
                  }.width('100%')
                } else {
                  Text('可插入课程资料、参考资料等网址').fontSize(11).fontColor($r('app.color.text_hint')).width('100%')
                }
              }.width('100%').alignItems(HorizontalAlign.Start)

              // 标签
              Column({ space: 8 }) {
                Row() {
                  Text('标签').fontSize(12).fontColor($r('app.color.text_sub')).layoutWeight(1)
                  Text('＋ 添加标签').fontSize(12).fontColor($r('app.color.primary'))
                    .onClick(() => this.openTagDialog())
                }.width('100%')
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.tags, (tag: string, index: number) => {
                    Row({ space: 4 }) {
                      Text(`#${tag}`).fontSize(12).fontColor($r('app.color.primary'))
                      Text('✕').fontSize(10).fontColor($r('app.color.text_hint'))
                    }
                    .padding({ left: 10, right: 8, top: 5, bottom: 5 })
                    .backgroundColor($r('app.color.primary_weak')).borderRadius(12)
                    .margin({ right: 8, bottom: 8 })
                    .onClick(() => this.removeTag(index))
                  }, (tag: string) => tag)
                }.width('100%')
              }.width('100%').alignItems(HorizontalAlign.Start)

              // 🌟 课程引用：课件 / 视频时间节点（便于回溯课程内容）
              Column({ space: 8 }) {
                Row() {
                  Text('课程引用').fontSize(12).fontColor($r('app.color.text_sub')).layoutWeight(1)
                  if (this.refTitle !== '' || this.refTime !== '') {
                    Text('清除').fontSize(12).fontColor($r('app.color.text_hint'))
                      .onClick(() => {
                        this.refTitle = ''
                        this.refTime = ''
                        this.markDirty()
                      })
                  }
                }.width('100%')
                TextInput({ text: this.refTitle, placeholder: '引用课件名称，如：第3章 排序算法.pdf' })
                  .fontSize(13).height(38).backgroundColor($r('app.color.field_bg')).borderRadius(8)
                  .onChange((v: string) => {
                    this.refTitle = v
                    this.markDirty()
                  })
                TextInput({ text: this.refTime, placeholder: '课程视频时间节点，如：12:35' })
                  .fontSize(13).height(38).backgroundColor($r('app.color.field_bg')).borderRadius(8)
                  .onChange((v: string) => {
                    this.refTime = v
                    this.markDirty()
                  })
              }.width('100%').alignItems(HorizontalAlign.Start)

              // 可见范围
              Column({ space: 8 }) {
                Text('可见范围').fontSize(12).fontColor($r('app.color.text_sub')).width('100%')
                Flex({ wrap: FlexWrap.Wrap }) {
                  Row() { this.visChip('private', '私有') }.margin({ right: 8, bottom: 8 })
                  Row() { this.visChip('course', '仅课程内可见') }.margin({ right: 8, bottom: 8 })
                  Row() { this.visChip('public', '公开') }.margin({ right: 8, bottom: 8 })
                }.width('100%')
                // 🌟 课程可见必须绑定具体课程，避免「同课程可见」退化为「任意课程可见」
                if (this.noteVisibility === 'course') {
                  Column({ space: 6 }) {
                    Text('绑定课程').fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
                    Flex({ wrap: FlexWrap.Wrap }) {
                      ForEach(this.courseOptions(), (c: CourseOption) => {
                        Text(c.name)
                          .fontSize(11)
                          .fontColor(this.noteCourseId === c.id ? Color.White : $r('app.color.text_sub'))
                          .backgroundColor(this.noteCourseId === c.id ? $r('app.color.primary') : $r('app.color.field_bg'))
                          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                          .borderRadius(12)
                          .margin({ right: 6, bottom: 6 })
                          .onClick(() => {
                            this.noteCourseId = c.id
                            this.markDirty()
                          })
                      }, (c: CourseOption) => c.id)
                    }.width('100%')
                    if (this.courseOptions().length === 0) {
                      Text('暂无可绑定的课程，请先加入或创建课程')
                        .fontSize(10).fontColor('#EF4444').width('100%')
                    }
                  }.width('100%').alignItems(HorizontalAlign.Start)
                }
                Text(`当前：${visibilityLabel(this.noteVisibility)} · 默认私有，可在分享时生成链接`)
                  .fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
              }.width('100%').alignItems(HorizontalAlign.Start)

              Text('内容实时自动保存；删除的笔记会在回收站保留 30 天')
                .fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
                .textAlign(TextAlign.Center).margin({ top: 8 })
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

      if (this.previewUri !== '') {
        Column() {
          Image('file://' + this.previewUri)
            .width('100%').height('85%').objectFit(ImageFit.Contain)
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
