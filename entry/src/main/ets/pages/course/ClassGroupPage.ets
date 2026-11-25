import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { picker } from '@kit.CoreFileKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { GroupMsg, GroupMember, fmtTime } from '../../model/HomeworkModel'
import { Guard } from '../../utils/Guard'
import { TaskItem, SigninEntry, effectiveStatus, awardPoints } from '../../model/InteractionModel'
import {
  ChatGroup,
  MAIN_GROUP_ID,
  RECALL_WINDOW_MS,
  saveMsgs,
  archiveAppend,
  archiveFromMsg,
  clearUnread,
  roleLabel,
  roleColor
} from '../../model/GroupModel'

// 🌟 常用表情
const EMOJIS: string[] = [
  '😀', '😁', '😂', '🤣', '😊', '😍', '😘', '😎',
  '🤔', '😅', '😭', '😡', '👍', '👏', '🙏', '💪',
  '🎉', '❤️', '🔥', '⭐', '📚', '✏️', '✅', '🌞'
]

// 🌟 表情包（大尺寸贴纸，本地模拟）
const STICKERS: string[] = [
  '😂', '🤣', '🥰', '😭', '😡', '👍', '👏', '🙏',
  '🎉', '❤️', '🔥', '💯', '🐶', '🐱', '🌻', '🍀'
]

function sizeText(n: number): string {
  if (n >= 1048576) {
    return `${(n / 1048576).toFixed(1)}MB`
  }
  if (n >= 1024) {
    return `${Math.round(n / 1024)}KB`
  }
  return `${n}B`
}

// 🌟 班级群快捷签到：验证码弹窗（无需跳转签到页）
@CustomDialog
struct QuickCodeDialog {
  controller: CustomDialogController
  taskTitle: string = ''
  onClose: () => void = () => {}
  onSubmit: (code: string) => void = () => {}
  @State code: string = ''

  aboutToDisappear(): void {
    this.onClose()
  }

  build() {
    Column({ space: 14 }) {
      Text('快捷签到').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      Text(this.taskTitle).fontSize(12).fontColor($r('app.color.text_hint')).width('100%')
      TextInput({ text: this.code, placeholder: '请输入教师公布的验证码' })
        .fontSize(16).height(44).backgroundColor($r('app.color.field_bg')).borderRadius(10)
        .onChange((v: string) => this.code = v)
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).backgroundColor($r('app.color.btn_cancel'))
          .onClick(() => this.controller.close())
        Button('签到').layoutWeight(1).onClick(() => {
          this.onSubmit(this.code)
          this.controller.close()
        })
      }.width('100%')
    }.padding(20).backgroundColor($r('app.color.card_bg')).borderRadius(16)
  }
}

// ==================== 班级群聊（师生共用） ====================
@Entry
@Component
struct ClassGroupPage {
  @StorageLink('classGroupMsgs') mainMsgs: GroupMsg[] = []
  @StorageLink('groupMsgsMap') msgMap: Record<string, GroupMsg[]> = {}
  @StorageLink('chatGroups') groups: ChatGroup[] = []
  @StorageLink('groupMembersMap') memberMap: Record<string, GroupMember[]> = {}
  @StorageLink('groupMuteMap') muteMap: Record<string, string> = {}
  @StorageLink('groupUnreadMap') unreadMap: Record<string, number> = {}
  @StorageLink('userRole') userRole: string = 'student'
  @StorageLink('nickname') nickname: string = '张同学'
  @StorageLink('classGroupNick') groupNick: string = ''
  @StorageLink('classGroupSeeded') seeded: boolean = false
  @StorageLink('courseQuit') courseQuit: boolean = false
  // 🌟 班级群快捷签到：直接读取当前课程签到任务
  @StorageLink('interactionTasks') tasks: TaskItem[] = []
  @State quickCodeOpen: boolean = false
  quickCodeController: CustomDialogController = new CustomDialogController({
    builder: QuickCodeDialog({}),
    customStyle: true
  })
  @State groupId: string = MAIN_GROUP_ID
  @State input: string = ''
  @State showEmoji: boolean = false
  @State showSticker: boolean = false
  @State showMention: boolean = false
  @State pendingMentions: string[] = []
  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    // 🌟 未加入课程的学生 / 未被分配的助教无法访问班级群
    if (!Guard.course('csbasic')) {
      router.back()
      return
    }
    let params = router.getParams() as Record<string, string>
    if (params !== undefined && params['groupId'] !== undefined && params['groupId'] !== '') {
      this.groupId = params['groupId']
    }
    clearUnread(this.groupId)
    // 🌟 仅主群首次进入补两条欢迎消息，清空记录后不再重复出现
    if (!this.seeded && this.groupId === MAIN_GROUP_ID && !this.courseQuit) {
      this.seeded = true
      if (this.msgs().length === 0) {
        let now = Date.now()
        let a = new GroupMsg()
        a.id = 'seed_1'
        a.name = '张老师'
        a.role = 'teacher'
        a.text = '欢迎同学们加入班级群，学习问题可以随时在这里讨论～'
        a.time = now - 3600000
        let b = new GroupMsg()
        b.id = 'seed_2'
        b.name = '王小明'
        b.role = 'student'
        b.text = '老师好！同学们好！'
        b.time = now - 1800000
        this.saveMsgsLocal([a, b])
      }
    }
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom)
    }, 120)
  }

  group(): ChatGroup | undefined {
    let hit = this.groups.filter((g: ChatGroup) => g.id === this.groupId)
    return hit.length > 0 ? hit[0] : undefined
  }

  members(): GroupMember[] {
    let list = this.memberMap[this.groupId]
    return list === undefined ? [] : list.filter((m: GroupMember) => !m.removed)
  }

  msgs(): GroupMsg[] {
    if (this.groupId === MAIN_GROUP_ID) {
      return this.mainMsgs
    }
    let list = this.msgMap[this.groupId]
    return list === undefined ? [] : list
  }

  saveMsgsLocal(list: GroupMsg[]): void {
    if (this.groupId === MAIN_GROUP_ID) {
      this.mainMsgs = list
    } else {
      let map: Record<string, GroupMsg[]> = {}
      Object.keys(this.msgMap).forEach((k: string) => {
        map[k] = this.msgMap[k]
      })
      map[this.groupId] = list
      this.msgMap = map
    }
    saveMsgs(this.groupId, list)
  }

  myName(): string {
    return this.groupNick !== '' ? this.groupNick : this.nickname
  }

  muteMode(): string {
    let mode = this.muteMap[this.groupId]
    return mode === undefined ? 'off' : mode
  }

  groupTitle(): string {
    let g = this.group()
    return g === undefined ? '班级群' : g.name
  }

  groupSubtitle(): string {
    let g = this.group()
    if (g === undefined) {
      return ''
    }
    return `${g.courseName} · 群主 ${g.ownerName} · ${this.members().length} 人`
  }

  // ==================== 班级群快捷签到 ====================
  activeSignin(): TaskItem | undefined {
    let now = Date.now()
    let list = this.tasks.filter((t: TaskItem) =>
      t.type === 'signin' && t.status === 'ongoing' && effectiveStatus(t, now) === 'ongoing')
    return list.length > 0 ? list[0] : undefined
  }

  mySigninEntry(t: TaskItem): SigninEntry | undefined {
    let hit = t.signinEntries.filter((e: SigninEntry) => e.student === this.nickname)
    return hit.length > 0 ? hit[0] : undefined
  }

  mySigned(t: TaskItem): boolean {
    let e = this.mySigninEntry(t)
    return e !== undefined && (e.status === 'signed' || e.status === 'makeup')
  }

  quickSigninStatus(t: TaskItem): string {
    if (this.mySigned(t)) {
      return '已签到'
    }
    if (t.signinMode === 'location') {
      return '位置签到 · 点击即可完成'
    }
    if (t.signinMode === 'code') {
      return t.code === '' ? '教师尚未生成验证码' : '验证码签到'
    }
    return '图案签到（需在签到页绘制）'
  }

  quickSignin(t: TaskItem) {
    if (effectiveStatus(t, Date.now()) !== 'ongoing') {
      promptAction.showToast({ message: '签到已结束，无法继续签到' })
      return
    }
    if (this.mySigned(t)) {
      promptAction.showToast({ message: '你已签到，无需重复签到' })
      return
    }
    if (t.signinMode === 'location') {
      this.doQuickSignin(t, '班级群快捷签到')
      return
    }
    if (t.signinMode === 'code') {
      if (t.code === '') {
        promptAction.showToast({ message: '教师尚未生成验证码，请稍后再试' })
        return
      }
      if (this.quickCodeOpen) {
        return
      }
      this.quickCodeOpen = true
      this.quickCodeController = new CustomDialogController({
        builder: QuickCodeDialog({
          taskTitle: t.title,
          onClose: () => {
            this.quickCodeOpen = false
          },
          onSubmit: (code: string) => {
            this.submitQuickCode(t, code)
          }
        }),
        autoCancel: true,
        customStyle: true
      })
      this.quickCodeController.open()
      return
    }
    // 图案签到需要绘制轨迹，班级群内仅提供入口，跳转签到任务页完成（限制：无法在群内直接绘制）
    promptAction.showToast({ message: '图案签到需绘制轨迹，正在前往签到页…' })
    router.pushUrl({ url: 'pages/study/SigninPage', params: { taskId: t.id } })
  }

  submitQuickCode(t: TaskItem, code: string) {
    if (t.codeExpireAt > 0 && Date.now() > t.codeExpireAt) {
      promptAction.showToast({ message: '验证码已过期，请让教师刷新后再签到' })
      return
    }
    if (code.trim() !== t.code) {
      promptAction.showToast({ message: '验证码错误，请核对教师公布的验证码' })
      return
    }
    this.doQuickSignin(t, '班级群验证码签到')
  }

  doQuickSignin(t: TaskItem, method: string) {
    let e = this.mySigninEntry(t)
    e = e === undefined ? new SigninEntry(this.nickname) : e
    e.status = 'signed'
    e.time = Date.now()
    e.method = method
    e.note = ''
    if (t.signinEntries.filter((x: SigninEntry) => x.student === this.nickname).length === 0) {
      t.signinEntries = t.signinEntries.concat([e])
    }
    this.tasks = this.tasks.slice()
    let gain = awardPoints('signin', this.nickname)
    promptAction.showToast({ message: gain > 0 ? `签到成功，获得 ${gain} 学分` : '签到成功' })
  }

  appendMsg(kind: string, text: string, media: string): void {
    let m = new GroupMsg()
    m.id = `m_${Date.now()}_${Math.floor(Math.random() * 1000)}`
    m.name = this.myName()
    m.role = this.userRole
    m.text = text
    m.time = Date.now()
    m.kind = kind
    m.media = media
    if (this.pendingMentions.length > 0) {
      m.mentions = this.pendingMentions.slice()
    }
    this.saveMsgsLocal(this.msgs().concat([m]))
    // 🌟 同步写入云端归档（本地模拟），清空本地记录不影响归档
    archiveAppend(this.groupId, m)
    if (kind === 'image' || kind === 'video') {
      archiveFromMsg(this.groupId, m)
    }
    this.pendingMentions = []
    this.scroller.scrollEdge(Edge.Bottom)
  }

  send(): void {
    let t = this.input.trim()
    if (t === '') {
      return
    }
    this.appendMsg('text', t, '')
    this.input = ''
    this.showEmoji = false
    this.showSticker = false
  }

  sendSticker(s: string): void {
    this.appendMsg('sticker', s, '')
    this.showSticker = false
  }

  // 🌟 仅自己 2 分钟内可撤回
  canRecall(m: GroupMsg): boolean {
    return !m.recalled && m.name === this.myName() && Date.now() - m.time <= RECALL_WINDOW_MS
  }

  recallMsg(m: GroupMsg): void {
    if (Date.now() - m.time > RECALL_WINDOW_MS) {
      promptAction.showToast({ message: '已超过 2 分钟撤回时限' })
      return
    }
    AlertDialog.show({
      title: '撤回消息',
      message: '确认撤回这条消息？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '撤回', fontColor: '#EF4444', action: () => {
          m.recalled = true
          this.saveMsgsLocal(this.msgs().slice())
          promptAction.showToast({ message: '已撤回' })
        }
      }
    })
  }

  // 🌟 选择图片 / 视频（系统相册），自动归档到群文件
  pickMedia(kind: string): void {
    try {
      let photoPicker = new photoAccessHelper.PhotoViewPicker()
      let opt = new photoAccessHelper.PhotoSelectOptions()
      opt.MIMEType = kind === 'video'
        ? photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE
        : photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      opt.maxSelectNumber = 1
      photoPicker.select(opt).then((res: photoAccessHelper.PhotoSelectResult) => {
        if (res.photoUris.length > 0) {
          this.appendMsg(kind, '', res.photoUris[0])
        }
      }).catch((err: BusinessError) => {
        promptAction.showToast({ message: '未选择文件' })
      })
    } catch (e) {
      promptAction.showToast({ message: '当前设备不支持选择文件' })
    }
  }

  // 🌟 选择任意文件发送，并自动归档
  async pickFile(): Promise<void> {
    try {
      let context = getContext(this) as common.UIAbilityContext
      let documentPicker = new picker.DocumentViewPicker(context)
      let options = new picker.DocumentSelectOptions()
      options.maxSelectNumber = 1
      let uris = await documentPicker.select(options)
      if (uris === undefined || uris.length === 0) {
        return
      }
      let uri = uris[0]
      let name = uri
      let slash = name.lastIndexOf('/')
      if (slash >= 0) {
        name = name.substring(slash + 1)
      }
      try {
        name = decodeURIComponent(name)
      } catch (e) {
        // 文件名解码失败时保留原样
      }
      let size = '—'
      try {
        let stat = fs.statSync(uri)
        size = sizeText(stat.size)
      } catch (e) {
        // 无法读取大小时保持占位
      }
      let m = new GroupMsg()
      m.id = `m_${Date.now()}_${Math.floor(Math.random() * 1000)}`
      m.name = this.myName()
      m.role = this.userRole
      m.time = Date.now()
      m.kind = 'file'
      m.fileName = name
      m.fileSize = size
      m.fileUri = uri
      if (this.pendingMentions.length > 0) {
        m.mentions = this.pendingMentions.slice()
      }
      this.saveMsgsLocal(this.msgs().concat([m]))
      archiveAppend(this.groupId, m)
      archiveFromMsg(this.groupId, m)
      this.pendingMentions = []
      promptAction.showToast({ message: '文件已发送并归档' })
      this.scroller.scrollEdge(Edge.Bottom)
    } catch (e) {
      promptAction.showToast({ message: '未选择文件' })
    }
  }

  addMention(name: string): void {
    if (this.pendingMentions.indexOf(name) < 0) {
      this.pendingMentions = this.pendingMentions.concat([name])
    }
    this.input += `@${name} `
    this.showMention = false
  }

  @Builder
  roleBadge(role: string) {
    Text(roleLabel(role))
      .fontSize(9).fontColor(Color.White)
      .padding({ left: 4, right: 4, top: 1, bottom: 1 })
      .backgroundColor(roleColor(role)).borderRadius(4)
  }

  @Builder
  fileBubble(m: GroupMsg, mine: boolean) {
    Row({ space: 10 }) {
      Text('📄').fontSize(22)
      Column({ space: 3 }) {
        Text(m.fileName === '' ? '未命名文件' : m.fileName)
          .fontSize(13).fontColor(mine ? Color.White : $r('app.color.text_main'))
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${m.fileSize === '' ? '—' : m.fileSize} · 已归档`)
          .fontSize(10).fontColor(mine ? '#EAF1FE' : $r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('下载')
        .fontSize(10).fontColor(mine ? Color.White : $r('app.color.primary'))
    }
    .width(220).padding(10)
    .backgroundColor(mine ? $r('app.color.primary') : $r('app.color.card_bg'))
    .borderRadius(12)
    .onClick(() => promptAction.showToast({ message: '演示环境未接入云端，暂不支持真实下载' }))
  }

  @Builder
  bubble(m: GroupMsg, mine: boolean) {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        if (!mine) {
          Text(m.name).fontSize(11).fontColor($r('app.color.text_sub'))
          if (m.role === 'teacher') {
            this.roleBadge('teacher')
          } else if (m.role === 'assistant') {
            this.roleBadge('assistant')
          }
        }
        Text(fmtTime(m.time)).fontSize(9).fontColor($r('app.color.text_hint'))
      }

      if (m.recalled) {
        Text(`${mine ? '我' : m.name}撤回了一条消息`)
          .fontSize(12).fontColor($r('app.color.text_hint')).fontStyle(FontStyle.Italic)
          .padding(6)
      } else if (m.kind === 'image') {
        Image(m.media)
          .width(160).constraintSize({ maxHeight: 220 })
          .borderRadius(12)
          .objectFit(ImageFit.Cover)
      } else if (m.kind === 'video') {
        Stack() {
          Text('🎬').fontSize(28)
        }
        .width(160).height(100)
        .backgroundColor('#1F2A3A')
        .borderRadius(12)
        .onClick(() => promptAction.showToast({ message: '演示环境暂不播放视频' }))
      } else if (m.kind === 'file') {
        this.fileBubble(m, mine)
      } else if (m.kind === 'sticker') {
        Text(m.text).fontSize(44).padding(2)
      } else {
        Text(m.text)
          .fontSize(14)
          .fontColor(mine ? Color.White : $r('app.color.text_main'))
          .padding(10)
          .backgroundColor(mine ? $r('app.color.primary') : $r('app.color.card_bg'))
          .borderRadius(mine
            ? { topLeft: 14, topRight: 4, bottomLeft: 14, bottomRight: 14 }
            : { topLeft: 4, topRight: 14, bottomLeft: 14, bottomRight: 14 })
      }

      if (!m.recalled && m.mentions !== undefined && m.mentions.length > 0) {
        Text(`@ ${m.mentions.join('、')}`)
          .fontSize(10).fontColor('#3F7EF6')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor('#3F7EF61A').borderRadius(6)
      }

      if (this.canRecall(m)) {
        Text('撤回')
          .fontSize(11).fontColor('#3F7EF6')
          .onClick(() => this.recallMsg(m))
      }
    }
    .alignItems(mine ? HorizontalAlign.End : HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  msgRow(m: GroupMsg) {
    if (m.kind === 'system') {
      Row() {
        Text(m.text)
          .fontSize(11).fontColor($r('app.color.text_hint'))
          .textAlign(TextAlign.Center).lineHeight(17)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.field_bg')).borderRadius(8)
      }
      .width('100%').justifyContent(FlexAlign.Center)
    } else if (m.name === this.myName()) {
      Row() {
        Blank()
        this.bubble(m, true)
      }.width('100%')
    } else {
      Row() {
        this.bubble(m, false)
        Blank()
      }.width('100%')
    }
  }

  @Builder
  emojiPanel() {
    Column() {
      Grid() {
        ForEach(EMOJIS, (e: string) => {
          GridItem() {
            Text(e).fontSize(24).textAlign(TextAlign.Center)
              .width('100%').height(44)
              .onClick(() => {
                this.input += e
              })
          }
        }, (e: string) => e)
      }
      .columnsTemplate('repeat(8, 1fr)')
      .rowsGap(4)
      .height(140)
      .margin({ top: 8 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, bottom: 6 })
    .backgroundColor($r('app.color.card_bg'))
  }

  @Builder
  stickerPanel() {
    Column() {
      Grid() {
        ForEach(STICKERS, (s: string) => {
          GridItem() {
            Text(s).fontSize(34).textAlign(TextAlign.Center)
              .width('100%').height(56)
              .onClick(() => this.sendSticker(s))
          }
        }, (s: string) => s)
      }
      .columnsTemplate('repeat(8, 1fr)')
      .rowsGap(4)
      .height(128)
      .margin({ top: 8 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, bottom: 6 })
    .backgroundColor($r('app.color.card_bg'))
  }

  @Builder
  mentionPanel() {
    Column({ space: 6 }) {
      Text('选择要 @ 的成员').fontSize(11).fontColor($r('app.color.text_hint'))
        .width('100%').padding({ left: 4 })
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.members().filter((m: GroupMember) => m.name !== this.myName()), (m: GroupMember) => {
            Row({ space: 4 }) {
              Text(m.name.substring(0, 1))
                .fontSize(10).fontColor(Color.White)
                .width(18).height(18).borderRadius(9).textAlign(TextAlign.Center)
                .backgroundColor(roleColor(m.role))
              Text(m.name).fontSize(12).fontColor($r('app.color.text_main'))
            }
            .padding({ left: 8, right: 10, top: 5, bottom: 5 })
            .backgroundColor($r('app.color.field_bg')).borderRadius(14)
            .onClick(() => this.addMention(m.name))
          }, (m: GroupMember) => m.id)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%').padding({ left: 12, right: 12, bottom: 8 })
    .backgroundColor($r('app.color.card_bg'))
  }

  @Builder
  quickEntry(icon: string, label: string, url: string) {
    Column({ space: 2 }) {
      Text(icon).fontSize(16)
      Text(label).fontSize(10).fontColor($r('app.color.text_sub'))
    }
    .layoutWeight(1).padding({ top: 5, bottom: 5 })
    .backgroundColor($r('app.color.field_bg')).borderRadius(10)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => router.pushUrl({ url: url }))
  }

  @Builder
  blockedView() {
    Column({ space: 12 }) {
      Text('🚫').fontSize(42)
      Text('你已退出该课程').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      Text('已移出班级群，课程访问权限已收回。')
        .fontSize(12).fontColor($r('app.color.text_sub'))
      Text('返回')
        .fontSize(13).fontColor(Color.White)
        .padding({ left: 20, right: 20, top: 9, bottom: 9 })
        .backgroundColor($r('app.color.primary')).borderRadius(18)
        .onClick(() => router.back())
    }
    .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      // 顶部栏：返回 + 群名 + 群信息 + 右上角设置
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20).fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Column({ space: 2 }) {
          Row({ space: 6 }) {
            Text(this.groupTitle()).fontSize(16).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_main'))
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.group() !== undefined && (this.group() as ChatGroup).isMain) {
              Text('主群')
                .fontSize(9).fontColor('#3F7EF6')
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                .backgroundColor('#3F7EF61A').borderRadius(4)
            }
          }
          Text(this.groupSubtitle()).fontSize(10).fontColor($r('app.color.text_hint'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)

        // 免打扰状态
        if (this.muteMode() !== 'off') {
          Text(this.muteMode() === 'block' ? '🚫' : '🔕').fontSize(14)
        }
        Text('⋯')
          .fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          .padding({ left: 8, right: 8 })
          .onClick(() => router.pushUrl({
            url: 'pages/course/GroupInfoPage',
            params: { groupId: this.groupId }
          }))
      }
      .width('100%').padding({ left: 16, right: 12, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.card_bg'))

      if (this.courseQuit) {
        this.blockedView()
      } else if (this.group() !== undefined && (this.group() as ChatGroup).dissolved) {
        Column({ space: 12 }) {
          Text('该群聊已被群主解散').fontSize(14).fontColor($r('app.color.text_sub'))
          Text('返回群列表')
            .fontSize(13).fontColor(Color.White)
            .padding({ left: 18, right: 18, top: 8, bottom: 8 })
            .backgroundColor($r('app.color.primary')).borderRadius(16)
            .onClick(() => router.back())
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        if (this.muteMode() !== 'off') {
          Row({ space: 6 }) {
            Text(this.muteMode() === 'block' ? '🚫' : '🔕').fontSize(11)
            Text(this.muteMode() === 'block'
              ? '本群已完全屏蔽：不接收任何提醒（本地模拟）'
              : '免打扰：关闭推送，保留未读红点（本地模拟）')
              .fontSize(10).fontColor($r('app.color.text_hint'))
          }
          .width('100%').padding({ left: 16, right: 16, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.primary_weak'))
        }

        // 🌟 快捷签到入口：无需跳转课程/签到页，班级群内直接完成（位置/验证码）
        if (this.userRole === 'student' && this.activeSignin() !== undefined) {
          Row({ space: 10 }) {
            Column({ space: 3 }) {
              Text('快捷签到').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              Text(`${(this.activeSignin() as TaskItem).title} · ${this.quickSigninStatus(this.activeSignin() as TaskItem)}`)
                .fontSize(11).fontColor($r('app.color.text_sub'))
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Button(this.mySigned(this.activeSignin() as TaskItem) ? '已签到' : '立即签到')
              .fontSize(13).height(34).padding({ left: 14, right: 14 })
              .backgroundColor(this.mySigned(this.activeSignin() as TaskItem) ? $r('app.color.field_bg') : $r('app.color.primary'))
              .fontColor(this.mySigned(this.activeSignin() as TaskItem) ? $r('app.color.text_hint') : Color.White)
              .enabled(!this.mySigned(this.activeSignin() as TaskItem))
              .onClick(() => this.quickSignin(this.activeSignin() as TaskItem))
          }
          .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.card_bg'))
        }

        // 消息列表
        List({ scroller: this.scroller, space: 14 }) {
          ForEach(this.msgs(), (m: GroupMsg) => {
            ListItem() {
              this.msgRow(m)
            }
          }, (m: GroupMsg) => m.id)
        }
        .width('100%').layoutWeight(1)
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })

        // 授课教师 / 助教快捷发起教学互动任务（学生不可见）
        if (this.userRole === 'teacher' || this.userRole === 'assistant') {
          Row({ space: 6 }) {
            this.quickEntry('✅', '签到', 'pages/study/SigninPage')
            this.quickEntry('📝', '练习', 'pages/study/PracticePage')
            this.quickEntry('📋', '问卷', 'pages/study/SurveyPage')
            this.quickEntry('🎲', '抽选', 'pages/study/RandomPickPage')
            this.quickEntry('🗂️', '台账', 'pages/study/TaskPage')
          }
          .width('100%').padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.card_bg'))
        }

        if (this.showEmoji) {
          this.emojiPanel()
        }
        if (this.showSticker) {
          this.stickerPanel()
        }
        if (this.showMention) {
          this.mentionPanel()
        }

        // 底部工具栏：表情 / 表情包 / 图片 / 视频 / 文件 / @ / 输入 / 发送
        Column({ space: 6 }) {
          if (this.pendingMentions.length > 0) {
            Row({ space: 6 }) {
              Text(`将提醒：${this.pendingMentions.join('、')}`)
                .fontSize(10).fontColor('#3F7EF6').layoutWeight(1)
              Text('清除')
                .fontSize(10).fontColor($r('app.color.text_hint'))
                .onClick(() => {
                  this.pendingMentions = []
                })
            }.width('100%').padding({ left: 4, right: 4 })
          }
          Row({ space: 4 }) {
            Text('😊').fontSize(19)
              .padding(3)
              .onClick(() => {
                this.showEmoji = !this.showEmoji
                this.showSticker = false
                this.showMention = false
              })
            Text('🎁').fontSize(19).padding(3)
              .onClick(() => {
                this.showSticker = !this.showSticker
                this.showEmoji = false
                this.showMention = false
              })
            Text('🖼️').fontSize(19).padding(3)
              .onClick(() => this.pickMedia('image'))
            Text('🎬').fontSize(19).padding(3)
              .onClick(() => this.pickMedia('video'))
            Text('📎').fontSize(18).padding(3)
              .onClick(() => this.pickFile())
            Text('@').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#3F7EF6')
              .padding({ left: 5, right: 5 })
              .onClick(() => {
                this.showMention = !this.showMention
                this.showEmoji = false
                this.showSticker = false
              })
          }.width('100%')

          Row({ space: 8 }) {
            TextInput({ text: this.input, placeholder: '说点什么…' })
              .fontSize(14).height(40).layoutWeight(1)
              .backgroundColor($r('app.color.field_bg')).borderRadius(20)
              .padding({ left: 16, right: 16 })
              .onChange((v: string) => {
                this.input = v
              })
              .onSubmit(() => this.send())
            Text('发送')
              .fontSize(13).fontWeight(FontWeight.Medium).fontColor(Color.White)
              .padding({ left: 14, right: 14, top: 9, bottom: 9 })
              .backgroundColor($r('app.color.primary')).borderRadius(20)
              .onClick(() => this.send())
          }.width('100%')
        }
        .width('100%').padding({ left: 12, right: 12, top: 6, bottom: 10 })
        .backgroundColor($r('app.color.card_bg'))
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
