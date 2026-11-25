import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import { GroupMember, GroupMsg } from '../../model/HomeworkModel'
import {
  ChatGroup,
  GroupNotice,
  GroupFile,
  GroupReport,
  MAIN_GROUP_ID,
  noticeHtml,
  markNoticeRead,
  noticeRead,
  setMuteMode,
  clearLocalMsgs,
  archiveOf,
  setMemberRole,
  removeMember,
  transferOwner,
  dissolveGroup,
  quitCourse,
  isGroupOwner,
  canPublishNotice,
  canExportLedger,
  canGradeHomework,
  canEditCourseBase,
  canEditPointRule,
  canDeleteCourse,
  roleLabel,
  roleColor,
  currentRole,
  muteLabel,
  saveNotice,
  notifyGroup
} from '../../model/GroupModel'

// ==================== 班级群详情面板 ====================
@Entry
@Component
struct GroupInfoPage {
  @StorageLink('chatGroups') groups: ChatGroup[] = []
  @StorageLink('groupMembersMap') memberMap: Record<string, GroupMember[]> = {}
  @StorageLink('groupNotices') noticeList: GroupNotice[] = []
  @StorageLink('groupFiles') fileList: GroupFile[] = []
  @StorageLink('groupReports') reportList: GroupReport[] = []
  @StorageLink('groupMuteMap') muteMap: Record<string, string> = {}
  @StorageLink('groupUnreadMap') unreadMap: Record<string, number> = {}
  @StorageLink('classGroupMsgs') mainMsgs: GroupMsg[] = []
  @StorageLink('userRole') userRole: string = 'student'
  @StorageLink('nickname') nickname: string = '张同学'
  @StorageLink('assistantCanCreate') allowAssistantCreate: boolean = false
  @StorageLink('courseQuit') courseQuit: boolean = false
  @State groupId: string = MAIN_GROUP_ID
  @State memberSearch: string = ''
  @State showMembers: boolean = true
  @State showNotices: boolean = true
  @State transferMode: boolean = false

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, string>
    if (params !== undefined && params['groupId'] !== undefined && params['groupId'] !== '') {
      this.groupId = params['groupId']
    }
  }

  group(): ChatGroup | undefined {
    let hit = this.groups.filter((g: ChatGroup) => g.id === this.groupId)
    return hit.length > 0 ? hit[0] : undefined
  }

  members(): GroupMember[] {
    let list = this.memberMap[this.groupId]
    return list === undefined ? [] : list.filter((m: GroupMember) => !m.removed)
  }

  filteredMembers(): GroupMember[] {
    let key = this.memberSearch.trim()
    if (key === '') {
      return this.members()
    }
    return this.members().filter((m: GroupMember) => m.name.indexOf(key) >= 0)
  }

  notices(): GroupNotice[] {
    return this.noticeList.filter((n: GroupNotice) => n.groupId === this.groupId)
      .sort((a: GroupNotice, b: GroupNotice) => {
        if (a.pinned !== b.pinned) {
          return a.pinned ? -1 : 1
        }
        return b.updatedAt - a.updatedAt
      })
  }

  files(): GroupFile[] {
    return this.fileList.filter((f: GroupFile) => f.groupId === this.groupId)
  }

  reports(): GroupReport[] {
    return this.reportList.filter((r: GroupReport) => r.groupId === this.groupId)
  }

  muted(): boolean {
    let m = this.muteMap[this.groupId]
    return m !== undefined && m !== 'off'
  }

  mode(): string {
    let m = this.muteMap[this.groupId]
    return m === undefined ? 'off' : m
  }

  ownerFlag(): boolean {
    let g = this.group()
    return g === undefined ? false : isGroupOwner(g)
  }

  noticeHeight(content: string): number {
    let lines = content.split('\n').length
    return Math.min(160, Math.max(40, lines * 20 + 8))
  }

  setMode(mode: string): void {
    setMuteMode(this.groupId, mode)
    let map: Record<string, string> = {}
    Object.keys(this.muteMap).forEach((k: string) => {
      map[k] = this.muteMap[k]
    })
    map[this.groupId] = mode
    this.muteMap = map
    promptAction.showToast({ message: mode === 'off' ? '已关闭免打扰' : mode === 'block' ? '已完全屏蔽本群' : '已开启免打扰（保留红点）' })
  }

  openMemberActions(m: GroupMember): void {
    let g = this.group()
    if (g === undefined) {
      return
    }
    if (!isGroupOwner(g)) {
      promptAction.showToast({ message: '仅群主可管理成员' })
      return
    }
    if (m.name === g.ownerName) {
      promptAction.showToast({ message: '群主不能被移除或降级' })
      return
    }
    if (m.role === 'teacher') {
      promptAction.showToast({ message: '授课教师身份由课程决定，无法在此修改' })
      return
    }
    let toAssistant = m.role !== 'assistant'
    AlertDialog.show({
      title: m.name,
      message: `当前身份：${roleLabel(m.role)}\n${
        toAssistant ? '设为助教后，可发布公告、导出签到台账、批阅作业。' : '取消助教后恢复为普通学生。'}`,
      primaryButton: {
        value: toAssistant ? '设为助教' : '取消助教',
        action: () => {
          setMemberRole(this.groupId, m.name, toAssistant ? 'assistant' : 'student')
          promptAction.showToast({ message: toAssistant ? '已设为助教' : '已取消助教' })
        }
      },
      secondaryButton: {
        value: '移出群聊',
        fontColor: '#EF4444',
        action: () => {
          AlertDialog.show({
            title: '移出成员',
            message: `确认将 ${m.name} 移出本群？`,
            primaryButton: { value: '取消', action: () => {} },
            secondaryButton: {
              value: '移出', fontColor: '#EF4444', action: () => {
                removeMember(this.groupId, m.name)
                promptAction.showToast({ message: `已将 ${m.name} 移出群聊` })
              }
            }
          })
        }
      }
    })
  }

  clearLocal(): void {
    let archived = archiveOf(this.groupId).length
    AlertDialog.show({
      title: '清空本地聊天记录',
      message: `将删除本机聊天缓存 ${this.msgsCount()} 条。\n云端归档（${archived} 条，本地模拟）会保留，可在「聊天记录检索」中继续查找。`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '清空', fontColor: '#EF4444', action: () => {
          clearLocalMsgs(this.groupId)
          promptAction.showToast({ message: '本地聊天记录已清空，云端归档保留' })
        }
      }
    })
  }

  msgsCount(): number {
    if (this.groupId === MAIN_GROUP_ID) {
      return this.mainMsgs.length
    }
    let map = AppStorage.get<Record<string, GroupMsg[]>>('groupMsgsMap') ?? {}
    let list = map[this.groupId]
    return list === undefined ? 0 : list.length
  }

  quit(): void {
    // 🌟 退出课程需二次确认
    AlertDialog.show({
      title: '退出课程',
      message: '退出后将被移出班级群，并收回课程全部访问权限。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '继续', fontColor: '#EF4444', action: () => {
          AlertDialog.show({
            title: '再次确认',
            message: '确认退出「数据结构与算法」？退出后无法查看课程与班级群（演示环境可恢复）。',
            primaryButton: { value: '取消', action: () => {} },
            secondaryButton: {
              value: '确认退出', fontColor: '#EF4444', action: () => {
                quitCourse()
                this.courseQuit = true
                promptAction.showToast({ message: '已退出课程，访问权限已收回' })
                router.replaceUrl({ url: 'pages/course/GroupListPage' })
              }
            }
          })
        }
      }
    })
  }

  disslove(): void {
    AlertDialog.show({
      title: '解散群聊',
      message: '解散后成员将无法继续在本群发言，聊天归档仍保留（本地模拟）。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '解散', fontColor: '#EF4444', action: () => {
          dissolveGroup(this.groupId)
          promptAction.showToast({ message: '群聊已解散' })
          router.replaceUrl({ url: 'pages/course/GroupListPage' })
        }
      }
    })
  }

  transferTo(name: string): void {
    AlertDialog.show({
      title: '移交群主',
      message: `确认将群主移交给 ${name}？移交后你将失去群主管理权限。`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '确认移交', fontColor: '#3F7EF6', action: () => {
          transferOwner(this.groupId, name)
          this.transferMode = false
          promptAction.showToast({ message: `群主已移交给 ${name}` })
        }
      }
    })
  }

  @Builder
  sectionTitle(title: string, tip: string) {
    Row() {
      Text(title).fontSize(12).fontColor($r('app.color.text_hint'))
      Blank()
      if (tip !== '') {
        Text(tip).fontSize(10).fontColor($r('app.color.text_hint'))
      }
    }.width('90%').margin({ top: 16, bottom: 6 }).padding({ left: 4 })
  }

  @Builder
  actionRow(icon: string, title: string, value: string, danger: boolean, onTap: () => void) {
    Row({ space: 10 }) {
      Text(icon).fontSize(18).width(26).textAlign(TextAlign.Center)
      Text(title)
        .fontSize(15)
        .fontColor(danger ? '#EF4444' : $r('app.color.text_main'))
        .layoutWeight(1)
      if (value !== '') {
        Text(value).fontSize(13).fontColor($r('app.color.text_sub'))
      }
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14).fontColor([$r('app.color.text_sub')])
    }
    .width('100%').height(52).padding({ left: 16, right: 16 })
    .onClick(() => onTap())
  }

  @Builder
  memberRow(m: GroupMember) {
    Row({ space: 10 }) {
      Text(m.name.substring(0, 1))
        .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .width(36).height(36).borderRadius(18).textAlign(TextAlign.Center)
        .backgroundColor(roleColor(m.role))
      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text(m.name).fontSize(14).fontColor($r('app.color.text_main'))
          if (this.group() !== undefined && m.name === (this.group() as ChatGroup).ownerName) {
            Text('群主')
              .fontSize(9).fontColor(Color.White)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .backgroundColor('#E8A33E').borderRadius(4)
          } else if (m.role === 'assistant') {
            Text('助教')
              .fontSize(9).fontColor(Color.White)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .backgroundColor('#8B5CF6').borderRadius(4)
          }
        }
        Text(roleLabel(m.role)).fontSize(10).fontColor($r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (this.ownerFlag() && m.name !== (this.group() as ChatGroup).ownerName) {
        Text('管理').fontSize(11).fontColor($r('app.color.primary'))
      }
    }
    .width('100%').padding({ top: 8, bottom: 8, left: 12, right: 12 })
    .onClick(() => this.openMemberActions(m))
  }

  @Builder
  noticeCard(n: GroupNotice) {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        if (n.pinned) {
          Text('📌 置顶')
            .fontSize(9).fontColor('#E8A33E')
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .backgroundColor('#E8A33E1A').borderRadius(4)
        }
        Text(n.title).fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(noticeRead(n) ? '已读' : '未读')
          .fontSize(9)
          .fontColor(noticeRead(n) ? '#22C55E' : '#F59E0B')
          .padding({ left: 5, right: 5, top: 1, bottom: 1 })
          .backgroundColor(noticeRead(n) ? '#22C55E1A' : '#F59E0B1A').borderRadius(4)
      }.width('100%')

      RichText(noticeHtml(n.content))
        .width('100%')
        .height(this.noticeHeight(n.content))

      if (n.attachmentName !== '') {
        Row({ space: 6 }) {
          Text('📎').fontSize(12)
          Text(n.attachmentName).fontSize(11).fontColor($r('app.color.primary')).layoutWeight(1)
          Text('附件').fontSize(9).fontColor($r('app.color.text_hint'))
        }
        .width('100%').padding({ left: 8, right: 8, top: 5, bottom: 5 })
        .backgroundColor($r('app.color.field_bg')).borderRadius(8)
      }

      Row({ space: 10 }) {
        Text(`${n.author} · ${new Date(n.updatedAt).getMonth() + 1}月${new Date(n.updatedAt).getDate()}日 · 已读 ${n.readBy.length}/${this.members().length}`)
          .fontSize(10).fontColor($r('app.color.text_hint')).layoutWeight(1)
        if (!noticeRead(n)) {
          Text('标记已读')
            .fontSize(11).fontColor($r('app.color.primary'))
            .onClick(() => {
              markNoticeRead(n)
              this.noticeList = this.noticeList.slice()
              promptAction.showToast({ message: '已标记为已读' })
            })
        }
        if (canPublishNotice()) {
          Text(n.pinned ? '取消置顶' : '置顶')
            .fontSize(11).fontColor('#E8A33E')
            .onClick(() => {
              n.pinned = !n.pinned
              n.updatedAt = Date.now()
              saveNotice(n)
              notifyGroup(this.groupId, `群公告「${n.title}」${n.pinned ? '已置顶' : '已取消置顶'}。`, this.nickname)
              promptAction.showToast({ message: n.pinned ? '公告已置顶' : '已取消置顶' })
            })
          Text('编辑')
            .fontSize(11).fontColor($r('app.color.primary'))
            .onClick(() => router.pushUrl({
              url: 'pages/course/NoticeEditPage',
              params: { groupId: this.groupId, noticeId: n.id }
            }))
        }
      }.width('100%')
    }
    .width('90%').padding(14).margin({ bottom: 10 })
    .backgroundColor($r('app.color.card_bg')).borderRadius(16)
  }

  @Builder
  permissionRow(label: string, ok: boolean) {
    Row({ space: 8 }) {
      Text(ok ? '✓' : '✕')
        .fontSize(11).fontWeight(FontWeight.Bold)
        .fontColor(ok ? '#22C55E' : '#B0B5C0')
      Text(label).fontSize(12).fontColor(ok ? $r('app.color.text_body') : $r('app.color.text_hint'))
        .layoutWeight(1)
    }.width('100%').height(28)
  }

  build() {
    Column() {
      // 顶部栏
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20).fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Text('群详情').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          .layoutWeight(1)
        Text(roleLabel(currentRole()))
          .fontSize(10).fontColor(roleColor(currentRole()))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor($r('app.color.field_bg')).borderRadius(8)
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.card_bg'))

      Scroll() {
        Column() {
          // ===== 群信息 =====
          Row({ space: 12 }) {
            Text('班').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White)
              .width(56).height(56).borderRadius(14).textAlign(TextAlign.Center)
              .backgroundColor(this.group() !== undefined && (this.group() as ChatGroup).isMain ? '#4C8BF5' : '#8B5CF6')
            Column({ space: 4 }) {
              Text(this.group() === undefined ? '班级群' : (this.group() as ChatGroup).name)
                .fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(`课程：${this.group() === undefined ? '—' : (this.group() as ChatGroup).courseName}`)
                .fontSize(11).fontColor($r('app.color.text_sub'))
              Text(`授课教师：${this.group() === undefined ? '—' : (this.group() as ChatGroup).teacherName} · 群主 ${this.group() === undefined ? '—' : (this.group() as ChatGroup).ownerName}`)
                .fontSize(11).fontColor($r('app.color.text_hint'))
              Text(`${this.members().length} 人 · ${this.group() !== undefined && (this.group() as ChatGroup).isMain ? '主班级群' : '子分组群'}`)
                .fontSize(10).fontColor($r('app.color.text_hint'))
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }
          .width('90%').padding(16).margin({ top: 12 })
          .backgroundColor($r('app.color.card_bg')).borderRadius(16)

          Text('无后端：云端存储、推送、审核均为本地模拟，页面已明确标注。')
            .fontSize(9).fontColor($r('app.color.text_hint'))
            .width('90%').padding({ left: 4, top: 6 })

          // ===== 群成员 =====
          Row() {
            Text('全部群成员').fontSize(12).fontColor($r('app.color.text_hint'))
            Blank()
            Text(`${this.members().length} 人`).fontSize(10).fontColor($r('app.color.text_hint'))
          }.width('90%').margin({ top: 16, bottom: 6 }).padding({ left: 4 })

          Column() {
            Row() {
              Text('成员列表').fontSize(15).fontColor($r('app.color.text_main')).layoutWeight(1)
              Text(this.showMembers ? '收起' : '展开')
                .fontSize(12).fontColor($r('app.color.primary'))
                .onClick(() => {
                  this.showMembers = !this.showMembers
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })

            if (this.showMembers) {
              Column({ space: 8 }) {
                TextInput({ placeholder: '搜索群成员', text: this.memberSearch })
                  .height(36).fontSize(13).backgroundColor($r('app.color.field_bg')).borderRadius(18)
                  .padding({ left: 12, right: 12 })
                  .onChange((v: string) => {
                    this.memberSearch = v
                  })
                ForEach(this.filteredMembers(), (m: GroupMember) => {
                  this.memberRow(m)
                }, (m: GroupMember) => m.id)
                if (this.filteredMembers().length === 0) {
                  Text('没有匹配的成员').fontSize(12).fontColor($r('app.color.text_hint'))
                    .width('100%').textAlign(TextAlign.Center).padding(12)
                }
              }
              .width('100%').padding({ left: 8, right: 8, bottom: 10 })
            }
          }
          .width('90%').backgroundColor($r('app.color.card_bg')).borderRadius(16)

          // ===== 群公告 =====
          Row() {
            Text('群公告').fontSize(12).fontColor($r('app.color.text_hint'))
            Blank()
            Text(`${this.notices().length} 条 · 支持富文本与附件`)
              .fontSize(10).fontColor($r('app.color.text_hint'))
          }.width('90%').margin({ top: 16, bottom: 6 }).padding({ left: 4 })

          Column() {
            Row() {
              Text('公告列表').fontSize(15).fontColor($r('app.color.text_main')).layoutWeight(1)
              if (canPublishNotice()) {
                Text('＋ 发布公告')
                  .fontSize(12).fontColor($r('app.color.primary'))
                  .onClick(() => router.pushUrl({
                    url: 'pages/course/NoticeEditPage',
                    params: { groupId: this.groupId }
                  }))
              }
              Text(this.showNotices ? '收起' : '展开')
                .fontSize(12).fontColor($r('app.color.text_sub'))
                .margin({ left: 12 })
                .onClick(() => {
                  this.showNotices = !this.showNotices
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })

            if (this.showNotices) {
              if (this.notices().length === 0) {
                Text('暂无群公告').fontSize(12).fontColor($r('app.color.text_hint'))
                  .width('100%').textAlign(TextAlign.Center).padding(16)
              } else {
                Column() {
                  ForEach(this.notices(), (n: GroupNotice) => {
                    this.noticeCard(n)
                  }, (n: GroupNotice) => `${n.id}_${n.pinned}_${n.updatedAt}`)
                }.width('100%').padding({ left: '5%' })
              }
            }
          }
          .width('90%').backgroundColor($r('app.color.card_bg')).borderRadius(16).padding({ bottom: 4 })

          // ===== 消息与通知 =====
          this.sectionTitle('消息与通知', '本地模拟')
          Column() {
            Row() {
              Column({ space: 2 }) {
                Text('🔕 消息免打扰').fontSize(15).fontColor($r('app.color.text_main'))
                Text(muteLabel(this.groupId)).fontSize(10).fontColor($r('app.color.text_hint'))
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.muted() })
                .selectedColor('#3F7EF6')
                .onChange((v: boolean) => {
                  this.setMode(v ? 'reddot' : 'off')
                })
            }.width('100%').height(56).padding({ left: 16, right: 16 })

            if (this.muted()) {
              Row({ space: 8 }) {
                Text('关推送保留红点')
                  .fontSize(11)
                  .fontColor(this.mode() === 'reddot' ? Color.White : $r('app.color.text_sub'))
                  .backgroundColor(this.mode() === 'reddot' ? '#3F7EF6' : $r('app.color.field_bg'))
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 }).borderRadius(12)
                  .onClick(() => this.setMode('reddot'))
                Text('全部屏蔽')
                  .fontSize(11)
                  .fontColor(this.mode() === 'block' ? Color.White : $r('app.color.text_sub'))
                  .backgroundColor(this.mode() === 'block' ? '#EF4444' : $r('app.color.field_bg'))
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 }).borderRadius(12)
                  .onClick(() => this.setMode('block'))
                Blank()
              }.width('100%').padding({ left: 16, right: 16, bottom: 10 })
            }

            Divider().color($r('app.color.divider_color')).margin({ left: 16, right: 16 })
            this.actionRow('📱', '多端同步状态',
              (this.unreadMap[this.groupId] !== undefined && this.unreadMap[this.groupId] > 0)
                ? `未读 ${this.unreadMap[this.groupId]} 条`
                : '已同步',
              false, (): void => {
                promptAction.showToast({ message: '消息已在本地模拟同步到其他端（未接入真实长连接）' })
              })
            Divider().color($r('app.color.divider_color')).margin({ left: 16, right: 16 })
            this.actionRow('🗂️', '历史文件归档', `${this.files().length} 个`, false, (): void => {
              router.pushUrl({ url: 'pages/course/GroupFilesPage', params: { groupId: this.groupId } })
            })
            Divider().color($r('app.color.divider_color')).margin({ left: 16, right: 16 })
            this.actionRow('🔍', '聊天记录检索', '云端归档', false, (): void => {
              router.pushUrl({ url: 'pages/course/ChatSearchPage', params: { groupId: this.groupId } })
            })
            Divider().color($r('app.color.divider_color')).margin({ left: 16, right: 16 })
            this.actionRow('🧹', '清空本地聊天记录', '云端保留', false, (): void => this.clearLocal())
            Divider().color($r('app.color.divider_color')).margin({ left: 16, right: 16 })
            this.actionRow('⚠️', '举报群聊内容', `${this.reports().length} 条记录`, false, (): void => {
              router.pushUrl({ url: 'pages/course/ReportPage', params: { groupId: this.groupId } })
            })
          }
          .width('90%').backgroundColor($r('app.color.card_bg')).borderRadius(16)

          // ===== 教学与权限 =====
          this.sectionTitle('教学与权限', roleLabel(currentRole()))
          Column() {
            if (this.userRole === 'teacher' || this.userRole === 'assistant') {
              this.actionRow('✅', '导出签到台账', 'CSV', false, (): void => {
                router.pushUrl({ url: 'pages/study/TaskPage' })
              })
              Divider().color($r('app.color.divider_color')).margin({ left: 52, right: 16 })
              this.actionRow('📝', '批阅作业', '', false, (): void => {
                router.pushUrl({ url: 'pages/course/HomeworkPage', params: { tab: 'list' } })
              })
              Divider().color($r('app.color.divider_color')).margin({ left: 52, right: 16 })
            }
            Column({ space: 2 }) {
              this.permissionRow('发布公告 / 附件', canPublishNotice())
              this.permissionRow('导出签到台账', canExportLedger())
              this.permissionRow('批阅作业', canGradeHomework())
              this.permissionRow('修改课程基础配置', canEditCourseBase())
              this.permissionRow('调整学分规则', canEditPointRule())
              this.permissionRow('删除课程', canDeleteCourse())
            }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 10 })

            if (this.userRole === 'assistant') {
              Text('助教不能修改课程基础配置、调整学分规则或删除课程。')
                .fontSize(10).fontColor($r('app.color.text_hint'))
                .width('100%').padding({ left: 16, right: 16, bottom: 10 })
            } else if (this.userRole === 'student') {
              Text('学生仅可发送消息与查看群资源，无公告与教学管理权限。')
                .fontSize(10).fontColor($r('app.color.text_hint'))
                .width('100%').padding({ left: 16, right: 16, bottom: 10 })
            }

            if (this.userRole === 'teacher') {
              Divider().color($r('app.color.divider_color')).margin({ left: 16, right: 16 })
              Row() {
                Column({ space: 2 }) {
                  Text('助教建群权限').fontSize(15).fontColor($r('app.color.text_main'))
                  Text('开启后助教可新建子分组群').fontSize(10).fontColor($r('app.color.text_hint'))
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.allowAssistantCreate })
                  .selectedColor('#3F7EF6')
                  .onChange((v: boolean) => {
                    this.allowAssistantCreate = v
                    promptAction.showToast({ message: v ? '已允许助教建群' : '已关闭助教建群权限' })
                  })
              }.width('100%').height(58).padding({ left: 16, right: 16 })
            }
          }
          .width('90%').backgroundColor($r('app.color.card_bg')).borderRadius(16)

          // ===== 群管理（群主） =====
          if (this.ownerFlag()) {
            this.sectionTitle('群管理', '仅群主')
            Column() {
              this.actionRow('👑', '移交群主', '', false, (): void => {
                this.transferMode = !this.transferMode
              })
              if (this.transferMode) {
                Column({ space: 2 }) {
                  Text('选择新的群主').fontSize(11).fontColor($r('app.color.text_hint'))
                    .width('100%').padding({ left: 16, top: 6, bottom: 4 })
                  ForEach(this.members().filter((m: GroupMember) =>
                  m.name !== (this.group() as ChatGroup).ownerName), (m: GroupMember) => {
                    Row({ space: 10 }) {
                      Text(m.name.substring(0, 1))
                        .fontSize(11).fontColor(Color.White)
                        .width(26).height(26).borderRadius(13).textAlign(TextAlign.Center)
                        .backgroundColor(roleColor(m.role))
                      Text(m.name).fontSize(13).fontColor($r('app.color.text_main')).layoutWeight(1)
                      Text(roleLabel(m.role)).fontSize(10).fontColor($r('app.color.text_hint'))
                    }
                    .width('100%').height(44).padding({ left: 16, right: 16 })
                    .onClick(() => this.transferTo(m.name))
                  }, (m: GroupMember) => `t_${m.id}`)
                }.width('100%').padding({ bottom: 8 })
              }
              Divider().color($r('app.color.divider_color')).margin({ left: 52, right: 16 })
              this.actionRow('💥', '解散群聊', '不可恢复', true, (): void => this.disslove())
            }
            .width('90%').backgroundColor($r('app.color.card_bg')).borderRadius(16)
          }

          // ===== 退出课程 =====
          this.sectionTitle('课程操作', '')
          if (this.userRole === 'teacher') {
            Column({ space: 8 }) {
              Text('主讲教师不能退出自己的课程')
                .fontSize(12).fontColor($r('app.color.text_sub')).width('100%').textAlign(TextAlign.Center)
              Text('退出课程')
                .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
                .width('100%').height(46).textAlign(TextAlign.Center)
                .backgroundColor('#EF4444').borderRadius(23).opacity(0.45)
                .onClick(() => {
                  promptAction.showToast({ message: '主讲教师不能退出自己的课程，可移交群主或解散群聊' })
                })
              Text('可先将群主移交给其他成员，或直接解散群聊。')
                .fontSize(10).fontColor($r('app.color.text_hint')).width('100%').textAlign(TextAlign.Center)
            }.width('90%').padding(12).margin({ bottom: 40 })
          } else {
            Column({ space: 8 }) {
              Text('退出课程')
                .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
                .width('100%').height(46).textAlign(TextAlign.Center)
                .backgroundColor('#EF4444').borderRadius(23)
                .onClick(() => this.quit())
              Text('退出后将移出班级群并收回课程全部访问权限（需二次确认）。')
                .fontSize(10).fontColor($r('app.color.text_hint')).width('100%').textAlign(TextAlign.Center)
            }.width('90%').margin({ bottom: 40 })
          }
        }
        .width('100%')
      }
      .layoutWeight(1).align(Alignment.Top).scrollBar(BarState.Off)
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
