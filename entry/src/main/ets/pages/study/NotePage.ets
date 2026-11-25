import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import {
  NoteItem,
  NotebookItem,
  formatStamp,
  sortNotes,
  noteSummaryText,
  normalizeNotebooks,
  visibilityLabel,
  noteRefText,
  NOTEBOOK_DEFAULT_ID
} from '../../model/DataModel'
import { NoteSync, NoteConflict } from '../../utils/NoteSync'
import { Permission } from '../../model/PermissionModel'
import { NoteShare } from '../../utils/NoteShare'
import { MAIN_GROUP_ID, saveMsgs, archiveAppend } from '../../model/GroupModel'
import { GroupMsg } from '../../model/HomeworkModel'
import { NoteTextDialog, NoteConfirmDialog, NoteMoveDialog, NoteShareDialog } from '../../components/NoteDialogs'

// 搜索高亮片段
class TextSeg {
  text: string = ''
  hit: boolean = false

  constructor(text: string, hit: boolean) {
    this.text = text
    this.hit = hit
  }
}

@Entry
@Component
struct NotePage {
  @StorageLink('noteList') noteList: NoteItem[] = []
  @StorageLink('notebookList') notebookList: NotebookItem[] = []
  @StorageLink('noteOffline') noteOffline: boolean = false

  @State searchText: string = ''
  @State trashView: boolean = false
  @State sortBy: string = 'update'
  @State selectedBook: string = 'all'
  @State showBookManager: boolean = false
  @State syncBusy: boolean = false
  @State lastSync: string = ''
  @State conflicts: NoteConflict[] = []
  @State dragName: string = ''
  private dialogOpen: boolean = false
  private syncTimer: number = -1

  inputController: CustomDialogController = new CustomDialogController({ builder: NoteTextDialog({}), customStyle: true })
  confirmController: CustomDialogController = new CustomDialogController({ builder: NoteConfirmDialog({}), customStyle: true })
  moveController: CustomDialogController = new CustomDialogController({ builder: NoteMoveDialog({}), customStyle: true })
  shareController: CustomDialogController = new CustomDialogController({ builder: NoteShareDialog({}), customStyle: true })

  aboutToAppear() {
    // 自愈：默认笔记本必须始终存在（「清空本地数据」后也能恢复）
    if (this.notebookList.length === 0 || !this.notebookList.some((b: NotebookItem) => b.isDefault)) {
      this.notebookList = normalizeNotebooks(this.notebookList)
    }
    this.lastSync = NoteSync.cloudTime(this.account())
    this.purgeExpired()
    // 联网时进入页面自动同步（模拟网络延迟，便于看到同步过程）
    if (!this.noteOffline) {
      this.syncTimer = setTimeout(() => {
        this.syncNow(true)
      }, 600)
    }
  }

  aboutToDisappear() {
    if (this.syncTimer !== -1) {
      clearTimeout(this.syncTimer)
    }
  }

  onPageShow() {
    // 从编辑页 / 详情页返回时，若存在未同步修改则自动同步
    if (!this.noteOffline && this.pendingCount() > 0) {
      this.syncNow(true)
    }
  }

  account(): string {
    return AppStorage.get<string>('regAccount') ?? ''
  }

  books(): NotebookItem[] {
    return this.notebookList.slice().sort((a: NotebookItem, b: NotebookItem) => a.order - b.order)
  }

  bookName(id: string): string {
    let book = this.notebookList.find((b: NotebookItem) => b.id === id)
    return book === undefined ? '默认笔记本' : book.name
  }

  activeNotes(): NoteItem[] {
    // 🌟 笔记可见性统一走权限模型：私有仅自己可见；课程可见需已加入课程；公开所有可见
    return Permission.visibleNotes(this.noteList.filter((n: NoteItem) => !n.isDeleted))
  }

  trashNotes(): NoteItem[] {
    return this.noteList.filter((n: NoteItem) => n.isDeleted)
  }

  bookCount(id: string): number {
    if (id === 'all') {
      return this.activeNotes().length
    }
    return this.activeNotes().filter((n: NoteItem) => n.notebookId === id).length
  }

  pendingCount(): number {
    return this.noteList.filter((n: NoteItem) => n.syncState === 'pending' || n.syncState === 'conflict').length
  }

  // 全文检索：标题 / 正文 / 标签，模糊匹配（忽略大小写）
  visibleNotes(): NoteItem[] {
    let kw = this.searchText.trim().toLowerCase()
    let list = this.activeNotes()
    if (this.selectedBook !== 'all') {
      list = list.filter((n: NoteItem) => n.notebookId === this.selectedBook)
    }
    if (kw !== '') {
      list = list.filter((n: NoteItem) => {
        let inTitle = n.title.toLowerCase().indexOf(kw) >= 0
        let inBody = n.content.toLowerCase().indexOf(kw) >= 0
        let inTag = n.tags.some((t: string) => t.toLowerCase().indexOf(kw) >= 0)
        return inTitle || inBody || inTag
      })
    }
    return sortNotes(list, this.sortBy)
  }

  splitHighlight(text: string, keyword: string): TextSeg[] {
    let segs: TextSeg[] = []
    let key = keyword.trim()
    if (key === '' || text === '') {
      segs.push(new TextSeg(text, false))
      return segs
    }
    let lower = text.toLowerCase()
    let target = key.toLowerCase()
    let start = 0
    let idx = lower.indexOf(target, start)
    while (idx >= 0) {
      if (idx > start) {
        segs.push(new TextSeg(text.substring(start, idx), false))
      }
      segs.push(new TextSeg(text.substring(idx, idx + target.length), true))
      start = idx + target.length
      idx = lower.indexOf(target, start)
    }
    if (start < text.length) {
      segs.push(new TextSeg(text.substring(start), false))
    }
    return segs
  }

  // 搜索时截取关键词附近的正文，命中更直观
  excerpt(n: NoteItem): string {
    let full = noteSummaryText(n)
    let kw = this.searchText.trim()
    if (kw === '' || full.length <= 64) {
      return full
    }
    let idx = full.toLowerCase().indexOf(kw.toLowerCase())
    if (idx <= 24) {
      return full.substring(0, 64)
    }
    return '…' + full.substring(idx - 16, Math.min(full.length, idx - 16 + 64))
  }

  daysLeft(deletedAt: number): number {
    return Math.max(0, 30 - Math.floor((Date.now() - deletedAt) / 86400000))
  }

  // 超过 30 天的回收站笔记自动清理（含云端快照）
  purgeExpired() {
    let now = Date.now()
    let expired = this.noteList.filter((n: NoteItem) =>
      n.isDeleted && n.deletedAt > 0 && now - n.deletedAt > 30 * 86400000)
    if (expired.length === 0) {
      return
    }
    expired.forEach((n: NoteItem) => NoteSync.purge(this.account(), n.id))
    this.noteList = this.noteList.filter((n: NoteItem) =>
      !(n.isDeleted && n.deletedAt > 0 && now - n.deletedAt > 30 * 86400000))
  }

  // ==================== 弹窗 ====================
  openInput(title: string, placeholder: string, value: string, confirmLabel: string, cb: (v: string) => void) {
    if (this.dialogOpen) {
      return
    }
    this.dialogOpen = true
    this.inputController = new CustomDialogController({
      builder: NoteTextDialog({
        title: title,
        placeholder: placeholder,
        value: value,
        confirmLabel: confirmLabel,
        onClose: () => {
          this.dialogOpen = false
        },
        onConfirm: (v: string) => {
          cb(v)
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.inputController.open()
  }

  openConfirm(title: string, message: string, confirmLabel: string, cb: () => void) {
    if (this.dialogOpen) {
      return
    }
    this.dialogOpen = true
    this.confirmController = new CustomDialogController({
      builder: NoteConfirmDialog({
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        danger: true,
        onClose: () => {
          this.dialogOpen = false
        },
        onConfirm: () => cb()
      }),
      autoCancel: true,
      customStyle: true
    })
    this.confirmController.open()
  }

  openMove(item: NoteItem) {
    if (this.dialogOpen) {
      return
    }
    this.dialogOpen = true
    this.moveController = new CustomDialogController({
      builder: NoteMoveDialog({
        notebooks: this.books(),
        currentId: item.notebookId,
        onClose: () => {
          this.dialogOpen = false
        },
        onPick: (id: string) => {
          this.moveTo(item.id, id)
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.moveController.open()
  }

  openShare(item: NoteItem) {
    if (this.dialogOpen) {
      return
    }
    this.dialogOpen = true
    this.shareController = new CustomDialogController({
      builder: NoteShareDialog({
        noteTitle: item.title,
        link: NoteShare.link(item),
        noteVisibility: item.visibility,
        onClose: () => {
          this.dialogOpen = false
        },
        onVisibility: (v: string) => {
          this.setVisibility(item.id, v)
        },
        onCopy: () => {
          NoteShare.copy(NoteShare.link(item)).then((ok: boolean) => {
            promptAction.showToast({ message: ok ? '分享链接已复制' : '复制失败，请重试' })
          })
        },
        onToGroup: () => {
          this.shareToClassGroup(item)
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.shareController.open()
  }

  // 🌟 分享笔记到班级群：未加入课程不可分享；私密笔记自动升级为「仅课程内可见」
  shareToClassGroup(item: NoteItem) {
    if (!Permission.isEnrolled('csbasic')) {
      promptAction.showToast({ message: '仅已加入该课程的同学可分享到班级群，请先在「我的课程」加入' })
      return
    }
    if (item.visibility === 'private') {
      this.noteList = this.noteList.map((n: NoteItem) => {
        if (n.id === item.id) {
          n.visibility = 'course'
          // 🌟 分享目标是班级群所属课程，绑定 csbasic 保证课程成员校验准确
          if (n.courseId === undefined || n.courseId === '') {
            n.courseId = 'csbasic'
          }
        }
        return n
      })
    }
    let role = AppStorage.get<string>('userRole') ?? 'student'
    let name = AppStorage.get<string>('nickname') ?? '我'
    let ref = noteRefText(item)
    let body = noteSummaryText(item)
    let msg = new GroupMsg()
    msg.id = `gm_note_${Date.now()}`
    msg.name = name
    msg.role = role === 'teacher' ? 'teacher' : (role === 'assistant' ? 'assistant' : 'student')
    msg.text = `📝 笔记分享：「${item.title}」\n${body}${ref === '' ? '' : `\n引用：${ref}`}`
    msg.time = Date.now()
    msg.kind = 'text'
    let list = AppStorage.get<GroupMsg[]>('classGroupMsgs') ?? []
    saveMsgs(MAIN_GROUP_ID, list.concat([msg]))
    archiveAppend(MAIN_GROUP_ID, msg)
    promptAction.showToast({ message: '已分享到班级群' })
  }

  // ==================== 笔记本操作 ====================
  addBook() {
    this.openInput('新建笔记本', '请输入笔记本名称', '', '创建', (name: string) => {
      let book = new NotebookItem(name, this.notebookList.length, false)
      this.notebookList = this.notebookList.concat([book])
      this.selectedBook = book.id
      promptAction.showToast({ message: '已创建笔记本' })
    })
  }

  renameBook(book: NotebookItem) {
    this.openInput('重命名笔记本', '请输入新的名称', book.name, '保存', (name: string) => {
      this.notebookList = this.notebookList.map((b: NotebookItem) => {
        if (b.id === book.id) {
          b.name = name
        }
        return b
      }).sort((a: NotebookItem, b: NotebookItem) => a.order - b.order)
      promptAction.showToast({ message: '已重命名' })
    })
  }

  deleteBook(book: NotebookItem) {
    if (book.isDefault) {
      promptAction.showToast({ message: '默认笔记本不可删除' })
      return
    }
    let count = this.bookCount(book.id)
    this.openConfirm('删除笔记本', `「${book.name}」内的 ${count} 条笔记会移动到默认笔记本，笔记本本身删除后不可恢复。`, '删除', () => {
      this.noteList = this.noteList.map((n: NoteItem) => {
        if (n.notebookId === book.id) {
          n.notebookId = NOTEBOOK_DEFAULT_ID
          n.version += 1
          n.syncState = 'pending'
        }
        return n
      })
      this.notebookList = this.notebookList.filter((b: NotebookItem) => b.id !== book.id)
      if (this.selectedBook === book.id) {
        this.selectedBook = 'all'
      }
      promptAction.showToast({ message: '笔记本已删除' })
    })
  }

  moveBook(itemIndex: number, insertIndex: number) {
    let books = this.books()
    if (itemIndex < 0 || itemIndex >= books.length) {
      return
    }
    let moved = books[itemIndex]
    books.splice(itemIndex, 1)
    let target = insertIndex
    if (target < 0) {
      target = 0
    }
    if (target > books.length) {
      target = books.length
    }
    books.splice(target, 0, moved)
    books.forEach((b: NotebookItem, i: number) => b.order = i)
    this.notebookList = books
  }

  // ==================== 笔记操作 ====================
  openDetail(id: string) {
    router.pushUrl({ url: 'pages/study/NoteDetailPage', params: { id: id } })
  }

  openEditor(id: string) {
    let notebookId = this.selectedBook === 'all' ? NOTEBOOK_DEFAULT_ID : this.selectedBook
    router.pushUrl({
      url: 'pages/study/NoteEditorPage',
      params: { id: id, notebookId: notebookId }
    })
  }

  togglePin(id: string) {
    this.noteList = this.noteList.map((n: NoteItem) => {
      if (n.id === id) {
        n.pinned = !n.pinned
        n.version += 1
        n.syncState = 'pending'
      }
      return n
    })
    promptAction.showToast({ message: '操作成功' })
  }

  moveTo(id: string, notebookId: string) {
    this.noteList = this.noteList.map((n: NoteItem) => {
      if (n.id === id) {
        n.notebookId = notebookId
        n.version += 1
        n.syncState = 'pending'
      }
      return n
    })
    promptAction.showToast({ message: `已移动到「${this.bookName(notebookId)}」` })
  }

  setVisibility(id: string, visibility: string) {
    this.noteList = this.noteList.map((n: NoteItem) => {
      if (n.id === id) {
        n.visibility = visibility
        n.version += 1
        n.syncState = 'pending'
      }
      return n
    })
    promptAction.showToast({ message: `已设为${visibilityLabel(visibility)}` })
  }

  handleDelete(id: string) {
    this.noteList = this.noteList.map((n: NoteItem) => {
      if (n.id === id) {
        n.isDeleted = true
        n.deletedAt = Date.now()
        n.pinned = false
        n.version += 1
        n.syncState = 'pending'
      }
      return n
    })
    promptAction.showToast({ message: '已移入回收站，保留 30 天' })
  }

  restoreNote(id: string) {
    this.noteList = this.noteList.map((n: NoteItem) => {
      if (n.id === id) {
        n.isDeleted = false
        n.deletedAt = 0
        n.version += 1
        n.syncState = 'pending'
      }
      return n
    })
    promptAction.showToast({ message: '已恢复' })
  }

  deleteForever(item: NoteItem) {
    this.openConfirm('永久删除', `「${item.title}」将被永久删除，无法恢复。`, '永久删除', () => {
      this.noteList = this.noteList.filter((n: NoteItem) => n.id !== item.id)
      NoteSync.purge(this.account(), item.id)
      promptAction.showToast({ message: '已永久删除' })
    })
  }

  emptyTrash() {
    let trash = this.trashNotes()
    if (trash.length === 0) {
      promptAction.showToast({ message: '回收站已空' })
      return
    }
    this.openConfirm('清空回收站', `回收站内 ${trash.length} 条笔记将被永久删除，无法恢复。`, '清空', () => {
      trash.forEach((n: NoteItem) => NoteSync.purge(this.account(), n.id))
      this.noteList = this.noteList.filter((n: NoteItem) => !n.isDeleted)
      promptAction.showToast({ message: '回收站已清空' })
    })
  }

  // ==================== 同步 ====================
  toggleOffline() {
    this.noteOffline = !this.noteOffline
    if (this.noteOffline) {
      promptAction.showToast({ message: '已切换为离线模式，编辑会在联网后自动同步' })
    } else {
      promptAction.showToast({ message: '已联网，正在自动同步' })
      this.syncNow(true)
    }
  }

  syncNow(silent: boolean) {
    if (this.syncBusy) {
      return
    }
    if (this.noteOffline) {
      if (!silent) {
        promptAction.showToast({ message: '当前为离线模式，请先联网' })
      }
      return
    }
    this.syncBusy = true
    // 模拟网络往返
    setTimeout(() => {
      let res = NoteSync.sync(this.account(), this.noteList)
      this.noteList = res.notes
      this.lastSync = res.time
      this.syncBusy = false
      this.conflicts = res.conflicts
      if (res.conflicts.length > 0) {
        promptAction.showToast({ message: `发现 ${res.conflicts.length} 条版本冲突` })
      } else if (!silent) {
        promptAction.showToast({ message: `同步完成：上传 ${res.uploaded} 条，下载 ${res.downloaded} 条` })
      }
    }, 500)
  }

  // 演示：制造一次「本地未同步修改 + 云端被另一台设备修改」的版本冲突
  simulateConflict() {
    let active = this.activeNotes()
    if (active.length === 0) {
      promptAction.showToast({ message: '暂无笔记可演示' })
      return
    }
    let target = active[0]
    this.noteList = this.noteList.map((n: NoteItem) => {
      if (n.id === target.id) {
        n.version += 1
        n.syncState = 'pending'
      }
      return n
    })
    NoteSync.simulateRemoteEdit(this.account(), target)
    promptAction.showToast({ message: '已模拟云端改动，开始同步' })
    this.syncNow(false)
  }

  resolveConflict(conf: NoteConflict, useCloud: boolean) {
    if (useCloud) {
      this.noteList = NoteSync.resolveWithCloud(this.noteList, conf.cloud)
    } else {
      this.noteList = NoteSync.resolveWithLocal(this.noteList, conf.local.id, conf.cloud.version)
    }
    this.conflicts = this.conflicts.filter((c: NoteConflict) => c.local.id !== conf.local.id)
    if (this.conflicts.length === 0) {
      promptAction.showToast({ message: '冲突已解决，正在重新同步' })
      this.syncNow(true)
    }
  }

  // ==================== UI ====================
  @Builder
  highlightText(text: string, size: number, color: ResourceColor, weight: FontWeight, lines: number) {
    Text() {
      ForEach(this.splitHighlight(text, this.searchText), (seg: TextSeg, index: number) => {
        Span(seg.text)
          .fontSize(size)
          .fontColor(seg.hit ? $r('app.color.primary') : color)
          .fontWeight(seg.hit ? FontWeight.Bold : weight)
      }, (seg: TextSeg, index: number) => `${index}_${seg.hit}_${seg.text}`)
    }
    .width('100%')
    .maxLines(lines)
    .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  highlightTitle(text: string) {
    Text() {
      ForEach(this.splitHighlight(text, this.searchText), (seg: TextSeg, index: number) => {
        Span(seg.text)
          .fontSize(16)
          .fontColor(seg.hit ? $r('app.color.primary') : $r('app.color.text_main'))
          .fontWeight(seg.hit ? FontWeight.Bold : FontWeight.Medium)
      }, (seg: TextSeg, index: number) => `${index}_${seg.hit}_${seg.text}`)
    }
    .layoutWeight(1)
    .maxLines(1)
    .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  emptyTip(msg: string, sub: string) {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.inbox')).fontSize(40).fontColor([$r('app.color.text_hint')])
      Text(msg).fontSize(14).fontColor($r('app.color.text_sub'))
      if (sub !== '') {
        Text(sub).fontSize(12).fontColor($r('app.color.text_hint'))
      }
    }.width('100%').padding({ top: 80 })
  }

  @Builder
  noteCard(item: NoteItem) {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        if (item.pinned) {
          Text('置顶')
            .fontSize(10).fontColor(Color.White)
            .backgroundColor('#F59E0B')
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .borderRadius(4)
        }
        this.highlightTitle(item.title === '' ? '无标题笔记' : item.title)
        Text(formatStamp(item.updatedAt)).fontSize(11).fontColor($r('app.color.text_hint'))
      }.width('100%')

      this.highlightText(this.excerpt(item), 13, $r('app.color.text_sub'), FontWeight.Normal, 2)

      Row({ space: 6 }) {
        Text(this.bookName(item.notebookId))
          .fontSize(10).fontColor($r('app.color.primary'))
          .backgroundColor($r('app.color.primary_weak'))
          .padding({ left: 6, right: 6, top: 2, bottom: 2 }).borderRadius(4)
        ForEach(item.tags.slice(0, 3), (tag: string) => {
          Text(`#${tag}`)
            .fontSize(10).fontColor($r('app.color.text_sub'))
            .backgroundColor($r('app.color.field_bg'))
            .padding({ left: 6, right: 6, top: 2, bottom: 2 }).borderRadius(4)
        }, (tag: string) => `${item.id}_${tag}`)
        if (item.images.length > 0) {
          Text(`图${item.images.length}`).fontSize(10).fontColor($r('app.color.text_hint'))
        }
        if (item.syncState === 'pending') {
          Text('待同步').fontSize(10).fontColor('#F59E0B')
        } else if (item.syncState === 'conflict') {
          Text('冲突').fontSize(10).fontColor('#EF4444')
        }
        Blank()
        if (item.visibility !== 'private') {
          Text(visibilityLabel(item.visibility)).fontSize(10).fontColor($r('app.color.success'))
        }
      }.width('100%')
    }
    .width('100%').padding(14)
    .backgroundColor($r('app.color.card_bg')).borderRadius(12)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => this.openDetail(item.id))
  }

  @Builder
  swipeButton(label: string, color: string, action: () => void) {
    Column({ space: 2 }) {
      Text(label).fontSize(11).fontColor(Color.White)
    }
    .width(56).height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(color)
    .onClick(() => action())
  }

  @Builder
  swipeActions(item: NoteItem) {
    Row() {
      this.swipeButton(item.pinned ? '取消置顶' : '置顶', '#F59E0B', () => {
        this.togglePin(item.id)
      })
      this.swipeButton('移动', '#3F7EF6', () => {
        this.openMove(item)
      })
      this.swipeButton('分享', '#10B981', () => {
        this.openShare(item)
      })
      this.swipeButton('删除', '#EF4444', () => {
        this.handleDelete(item.id)
      })
    }.height('100%')
  }

  @Builder
  trashCard(item: NoteItem) {
    Row() {
      Column({ space: 4 }) {
        Text(item.title).fontSize(15).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_main')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`删除于 ${formatStamp(item.deletedAt)}`).fontSize(11).fontColor($r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)

      Text(`剩余${this.daysLeft(item.deletedAt)}天`).fontSize(11).fontColor('#EF4444').fontWeight(FontWeight.Bold)

      Button('恢复').fontSize(12).height(30).backgroundColor($r('app.color.btn_gray')).margin({ left: 10 })
        .onClick(() => this.restoreNote(item.id))
      Button('永久删除').fontSize(12).height(30).backgroundColor('#EF4444')
        .onClick(() => this.deleteForever(item))
    }
    .width('100%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(8)
  }

  @Builder
  bookChip(id: string, name: string) {
    Text(`${name} ${this.bookCount(id)}`)
      .fontSize(13)
      .fontColor(this.selectedBook === id ? Color.White : $r('app.color.text_sub'))
      .backgroundColor(this.selectedBook === id ? $r('app.color.primary') : $r('app.color.card_bg'))
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .borderRadius(18)
      .onClick(() => {
        this.selectedBook = id
        this.trashView = false
      })
  }

  @Builder
  sortChip(label: string, value: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.sortBy === value ? $r('app.color.primary') : $r('app.color.text_hint'))
      .fontWeight(this.sortBy === value ? FontWeight.Medium : FontWeight.Normal)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(8)
      .backgroundColor(this.sortBy === value ? $r('app.color.primary_weak') : Color.Transparent)
      .onClick(() => this.sortBy = value)
  }

  @Builder
  header() {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([$r('app.color.text_main')])
      }
      .width(40).height(48)
      .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
      .onClick(() => router.back())
      Text('我的笔记').fontSize(20).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_main')).margin({ left: 4 })
      Blank()
      Text(this.trashView ? '返回笔记' : '回收站')
        .fontSize(13).fontColor($r('app.color.primary'))
        .padding({ left: 8, right: 8, top: 6, bottom: 6 })
        .onClick(() => {
          this.trashView = !this.trashView
          this.showBookManager = false
        })
      Row() {
        SymbolGlyph($r('sys.symbol.plus')).fontSize(18).fontColor([Color.White])
      }
      .width(34).height(34).borderRadius(17).backgroundColor('#3F7EF6')
      .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
      .margin({ left: 4, right: 4 })
      .onClick(() => this.openEditor(''))
    }
    .width('100%').height(60).padding({ left: 8, right: 12 })
  }

  @Builder
  syncBanner() {
    Row({ space: 8 }) {
      Text('☁').fontSize(16)
      Column({ space: 2 }) {
        Text(NoteSync.LABEL).fontSize(11).fontColor($r('app.color.text_main'))
        Text(this.noteOffline ? '离线模式：编辑暂存本机，联网后自动同步'
          : (this.lastSync === '' ? '尚未同步' : `上次同步 ${this.lastSync}`))
          .fontSize(10).fontColor($r('app.color.text_hint'))
        if (!this.noteOffline) {
          Text('演示：模拟另一台设备修改（触发版本冲突）')
            .fontSize(10).fontColor($r('app.color.primary'))
            .onClick(() => this.simulateConflict())
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)

      if (this.pendingCount() > 0) {
        Text(`${this.pendingCount()} 条待同步`).fontSize(10).fontColor('#F59E0B')
      }
      Text(this.noteOffline ? '离线' : (this.syncBusy ? '同步中' : '在线'))
        .fontSize(11)
        .fontColor(this.noteOffline ? $r('app.color.text_sub') : $r('app.color.success'))
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor($r('app.color.field_bg')).borderRadius(10)
        .onClick(() => this.toggleOffline())
      if (!this.noteOffline) {
        Text('立即同步').fontSize(11).fontColor($r('app.color.primary'))
          .onClick(() => this.syncNow(false))
      }
    }
    .width('92%').padding(10)
    .backgroundColor($r('app.color.card_bg')).borderRadius(10)
  }

  @Builder
  bookManagerOverlay() {
    Column() {
      Blank()
      Column({ space: 12 }) {
        Row() {
          Text('笔记本管理').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).layoutWeight(1)
          Text('完成').fontSize(14).fontColor($r('app.color.primary'))
            .onClick(() => this.showBookManager = false)
        }.width('100%')

        Text('长按拖动可调整顺序，默认笔记本不可删除').fontSize(11).fontColor($r('app.color.text_hint')).width('100%')

        List({ space: 8 }) {
          ForEach(this.books(), (book: NotebookItem) => {
            ListItem() {
              Row({ space: 10 }) {
                Text('≡').fontSize(18).fontColor($r('app.color.text_hint'))
                Column({ space: 2 }) {
                  Text(book.name).fontSize(15).fontColor($r('app.color.text_main'))
                  if (book.isDefault) {
                    Text('默认').fontSize(10).fontColor($r('app.color.text_hint'))
                  }
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text(`${this.bookCount(book.id)} 条`).fontSize(11).fontColor($r('app.color.text_hint'))
                Text('重命名').fontSize(12).fontColor($r('app.color.primary'))
                  .padding({ left: 6, right: 6, top: 4, bottom: 4 })
                  .onClick(() => this.renameBook(book))
                if (!book.isDefault) {
                  Text('删除').fontSize(12).fontColor('#EF4444')
                    .padding({ left: 6, right: 6, top: 4, bottom: 4 })
                    .onClick(() => this.deleteBook(book))
                }
              }
              .width('100%').padding(12)
              .backgroundColor($r('app.color.field_bg')).borderRadius(10)
            }
          }, (book: NotebookItem) => `${book.id}_${book.order}_${book.name}`)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .editMode(true)
        .onItemDragStart((event: ItemDragInfo, itemIndex: number) => {
          let books = this.books()
          this.dragName = itemIndex >= 0 && itemIndex < books.length ? books[itemIndex].name : ''
          return this.dragPreviewCard()
        })
        .onItemDrop((event: ItemDragInfo, itemIndex: number, insertIndex: number, isSuccess: boolean) => {
          if (isSuccess && itemIndex !== insertIndex) {
            this.moveBook(itemIndex, insertIndex)
          }
        })

        Button('+ 新建笔记本').width('100%').height(42)
          .backgroundColor($r('app.color.primary')).fontColor(Color.White)
          .onClick(() => this.addBook())
      }
      .width('100%').height('62%')
      .padding(20)
      .backgroundColor($r('app.color.page_bg'))
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%').height('100%')
    .backgroundColor('rgba(0,0,0,0.45)')
    .onClick(() => this.showBookManager = false)
  }

  @Builder
  dragPreviewCard() {
    Text(this.dragName)
      .fontSize(14).fontColor(Color.White)
      .padding({ left: 20, right: 20, top: 10, bottom: 10 })
      .backgroundColor('#3F7EF6').borderRadius(10)
  }

  @Builder
  conflictOverlay() {
    Column() {
      Blank()
      Column({ space: 12 }) {
        Row() {
          Text('版本冲突').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).layoutWeight(1)
          Text(`${this.conflicts.length} 条`).fontSize(11).fontColor('#EF4444')
        }.width('100%')
        Text('本地与云端都修改了同一篇笔记，请选择要保留的版本')
          .fontSize(11).fontColor($r('app.color.text_hint')).width('100%')

        List({ space: 10 }) {
          ForEach(this.conflicts, (conf: NoteConflict) => {
            ListItem() {
              Column({ space: 8 }) {
                Text(conf.local.title === '' ? '无标题笔记' : conf.local.title)
                  .fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')

                Row() {
                  Column({ space: 2 }) {
                    Text('本地版本').fontSize(11).fontColor($r('app.color.text_sub'))
                    Text(`修改于 ${formatStamp(conf.local.updatedAt)}`).fontSize(10).fontColor($r('app.color.text_hint'))
                    Text(conf.local.content === '' ? '（无正文）' : conf.local.content)
                      .fontSize(11).fontColor($r('app.color.text_body')).maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)

                  Column({ space: 2 }) {
                    Text('云端版本').fontSize(11).fontColor($r('app.color.text_sub'))
                    Text(`修改于 ${formatStamp(conf.cloud.updatedAt)}`).fontSize(10).fontColor($r('app.color.text_hint'))
                    Text(conf.cloud.content === '' ? '（无正文）' : conf.cloud.content)
                      .fontSize(11).fontColor($r('app.color.text_body')).maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                }.width('100%')

                Row({ space: 8 }) {
                  Button('保留本地').layoutWeight(1).height(34).fontSize(12)
                    .backgroundColor('#3F7EF6').onClick(() => this.resolveConflict(conf, false))
                  Button('保留云端').layoutWeight(1).height(34).fontSize(12)
                    .backgroundColor($r('app.color.btn_gray')).onClick(() => this.resolveConflict(conf, true))
                }.width('100%')
              }
              .width('100%').padding(12)
              .backgroundColor($r('app.color.field_bg')).borderRadius(10)
              .alignItems(HorizontalAlign.Start)
            }
          }, (conf: NoteConflict) => conf.local.id)
        }
        .width('100%').layoutWeight(1).scrollBar(BarState.Off)
        Text(NoteSync.LABEL).fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
      }
      .width('100%').height('64%')
      .padding(20)
      .backgroundColor($r('app.color.page_bg'))
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%').height('100%')
    .backgroundColor('rgba(0,0,0,0.45)')
  }

  @Builder
  notesView() {
    Column() {
      Search({ value: this.searchText, placeholder: '搜索标题 / 正文 / 标签' })
        .width('92%').height(40).backgroundColor($r('app.color.card_bg'))
        .placeholderColor($r('app.color.text_sub')).placeholderFont({ size: 14 }).textFont({ size: 14 })
        .margin({ top: 4, bottom: 10 })
        .onChange((v: string) => this.searchText = v)

      this.syncBanner()

      // 笔记本分类横向滚动
      List({ space: 8 }) {
        ListItem() {
          this.bookChip('all', '全部')
        }
        ForEach(this.books(), (book: NotebookItem) => {
          ListItem() {
            this.bookChip(book.id, book.name)
          }
        }, (book: NotebookItem) => `${book.id}_${book.order}_${book.name}`)
        ListItem() {
          Text('管理')
            .fontSize(13).fontColor($r('app.color.text_sub'))
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor($r('app.color.card_bg')).borderRadius(18)
            .onClick(() => this.showBookManager = true)
        }
      }
      .listDirection(Axis.Horizontal)
      .alignListItem(ListItemAlign.Center)
      .scrollBar(BarState.Off)
      .width('92%').height(40)
      .margin({ top: 10, bottom: 4 })

      Row({ space: 4 }) {
        Text(`共 ${this.visibleNotes().length} 条`).fontSize(12).fontColor($r('app.color.text_hint')).layoutWeight(1)
        this.sortChip('按创建时间', 'create')
        this.sortChip('按修改时间', 'update')
      }.width('92%').margin({ bottom: 8 })

      List({ space: 10 }) {
        ForEach(this.visibleNotes(), (item: NoteItem) => {
          ListItem() {
            this.noteCard(item)
          }
          .swipeAction({ end: { builder: () => { this.swipeActions(item) } } })
        }, (item: NoteItem) => `${item.id}_${item.version}_${item.pinned}_${item.notebookId}_${item.title}`)
        if (this.visibleNotes().length === 0) {
          ListItem() {
            if (this.searchText.trim() !== '') {
              this.emptyTip('没有找到相关笔记', '换个关键词试试')
            } else {
              this.emptyTip('点击右上方添加笔记', '支持图文、标签与分享')
            }
          }
        }
      }
      .width('92%').layoutWeight(1).scrollBar(BarState.Off)
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  trashViewContent() {
    Column() {
      Row() {
        Text('删除的笔记保留 30 天，到期自动清理').fontSize(12).fontColor($r('app.color.text_hint'))
        Blank()
        Text('清空回收站').fontSize(13).fontColor('#EF4444').onClick(() => this.emptyTrash())
      }.width('92%').padding({ top: 6, bottom: 10 })

      List({ space: 10 }) {
        ForEach(this.trashNotes(), (item: NoteItem) => {
          ListItem() {
            this.trashCard(item)
          }
        }, (item: NoteItem) => `${item.id}_${item.deletedAt}`)
        if (this.trashNotes().length === 0) {
          ListItem() {
            this.emptyTip('回收站为空', '删除的笔记会在这里保留 30 天')
          }
        }
      }.width('92%').layoutWeight(1).scrollBar(BarState.Off)
    }.layoutWeight(1).width('100%')
  }

  build() {
    Stack() {
      Column() {
        this.header()
        if (this.trashView) {
          this.trashViewContent()
        } else {
          this.notesView()
        }
      }
      .width('100%').height('100%')
      .backgroundColor($r('app.color.page_bg'))

      if (this.showBookManager) {
        this.bookManagerOverlay()
      }
      if (this.conflicts.length > 0) {
        this.conflictOverlay()
      }
    }
    .width('100%').height('100%')
  }
}
