import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { MessageItem, ChatMessage, PostItem, userLevel, levelColor } from '../../model/DataModel';
import {
  MESSAGE_CATEGORIES, MessageCategory, MessageCenter, categoryOf, categoryLabel
} from '../../model/MessageCenterModel';
import { Permission } from '../../model/PermissionModel';
import { EmptyState } from '../../components/StatusViews';

// 🌟 添加好友弹窗：输入名字或点推荐头像，添加后进入好友列表并收到打招呼消息
@CustomDialog
struct AddFriendDialog {
  controller: CustomDialogController
  // 返回 true 表示添加成功（弹窗关闭），false 表示校验失败（弹窗保持打开）
  onAdd: (name: string) => boolean = () => false
  @State inputName: string = ''
  @StorageLink('friendList') friendList: string[] = []
  @StorageLink('postList') postList: PostItem[] = []
  @StorageLink('nickname') nickname: string = '张同学'

  // 🌟 好友推荐：社区里出现过的作者，排除自己和已是好友的人
  suggested(): string[] {
    let names: string[] = []
    this.postList.forEach((p: PostItem) => {
      if (p.author !== this.nickname && this.friendList.indexOf(p.author) < 0 && names.indexOf(p.author) < 0) {
        names.push(p.author)
      }
    })
    return names.slice(0, 6)
  }

  pick(name: string) {
    this.inputName = name
  }

  submit() {
    if (this.onAdd(this.inputName.trim())) {
      this.controller.close()
    }
  }

  build() {
    Column({ space: 16 }) {
      Text('添加好友').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      TextInput({ placeholder: '输入好友名字', text: this.inputName })
        .height(44)
        .backgroundColor($r('app.color.field_bg'))
        .placeholderColor($r('app.color.text_hint'))
        .fontColor($r('app.color.text_main'))
        .borderRadius(12)
        .onChange((v: string) => {
          this.inputName = v
        })
      if (this.suggested().length > 0) {
        Column({ space: 8 }) {
          Text('好友推荐').fontSize(12).fontColor($r('app.color.text_hint'))
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.suggested(), (name: string) => {
              Row({ space: 6 }) {
                Text(name.slice(0, 1))
                  .fontSize(12).fontWeight(FontWeight.Bold).fontColor(Color.White)
                  .width(22).height(22).backgroundColor('#3F7EF6')
                  .borderRadius(11).textAlign(TextAlign.Center)
                Text(name).fontSize(12).fontColor($r('app.color.text_main'))
              }
              .padding({ left: 8, right: 10, top: 4, bottom: 4 })
              .backgroundColor($r('app.color.field_bg'))
              .borderRadius(14)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => this.pick(name))
            }, (name: string) => name)
          }
        }.alignItems(HorizontalAlign.Start).width('100%')
      }
      Row({ space: 12 }) {
        Text('取消')
          .fontSize(14).fontColor($r('app.color.text_label'))
          .layoutWeight(1).textAlign(TextAlign.Center)
          .padding({ top: 10, bottom: 10 })
          .backgroundColor($r('app.color.field_bg'))
          .borderRadius(20)
          .onClick(() => this.controller.close())
        Text('添加')
          .fontSize(14).fontColor(Color.White)
          .layoutWeight(1).textAlign(TextAlign.Center)
          .padding({ top: 10, bottom: 10 })
          .backgroundColor($r('app.color.primary'))
          .borderRadius(20)
          .onClick(() => this.submit())
      }.width('100%')
    }
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
  }
}

// ==================== 消息详情（合并后的消息 Tab 内置详情） ====================
// 🌟 修复「消息点不进去 / 内容为空」：任何消息（系统 / 上课 / 签到 / 作业 / 充值 / 举报 / 互动）
//    点击后都先打开详情，完整展示正文；有目标页面的再提供「前往」按钮。
@CustomDialog
struct MessageDetailDialog {
  controller: CustomDialogController
  category: string = ''
  color: string = '#3F7EF6'
  sender: string = ''
  time: string = ''
  content: string = ''
  actionLabel: string = ''
  onClose: () => void = () => {}
  onAction: () => void = () => {}

  aboutToDisappear(): void {
    this.onClose()
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        Text(this.category)
          .fontSize(11).fontWeight(FontWeight.Medium).fontColor(Color.White)
          .backgroundColor(this.color)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .borderRadius(8)
        Blank()
        Text(this.time).fontSize(12).fontColor($r('app.color.text_hint'))
      }.width('100%')

      Text(this.sender).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        .width('100%')

      Divider().color($r('app.color.divider_color'))

      Scroll() {
        Text(this.content)
          .fontSize(14).lineHeight(24).fontColor($r('app.color.text_body'))
          .width('100%')
      }
      .constraintSize({ maxHeight: 260 })
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)

      Row({ space: 10 }) {
        Button('关闭')
          .layoutWeight(1).height(42)
          .backgroundColor($r('app.color.field_bg'))
          .fontColor($r('app.color.text_label'))
          .onClick(() => this.controller.close())
        if (this.actionLabel !== '') {
          Button(this.actionLabel)
            .layoutWeight(1).height(42)
            .onClick(() => {
              this.controller.close()
              this.onAction()
            })
        }
      }.width('100%')
    }
    .width('86%')
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(20)
    .alignItems(HorizontalAlign.Start)
  }
}

// ==================== 消息 Tab（已合并「消息中心」） ====================
// 🌟 系统通知 / 上课提醒 / 签到提醒 / 作业批阅 / 充值订单 / 举报反馈 + 好友互动消息
//    统一收纳在这里；「我的 → 消息中心」与「通知中心」入口已下线。
@Component
export struct MessagePage {
  @StorageLink('messageList') msgList: MessageItem[] = []
  // 🌟 好友列表：登录后在消息页添加，持久化保存
  @StorageLink('friendList') friendList: string[] = []
  @StorageLink('chatMap') chatMap: Record<string, ChatMessage[]> = {}
  @StorageLink('nickname') nickname: string = '张同学'
  @StorageLink('isLogged') isLogged: boolean = false
  @State msgFilter: string = 'all'
  @State detailCategory: string = ''
  @State detailColor: string = '#3F7EF6'
  @State detailSender: string = ''
  @State detailTime: string = ''
  @State detailContent: string = ''
  @State detailRoute: string = ''
  @State detailTaskId: string = ''
  @State detailPostId: string = ''

  detailController: CustomDialogController = new CustomDialogController({
    builder: MessageDetailDialog({}),
    customStyle: true
  })

  addDialogController: CustomDialogController = new CustomDialogController({
    builder: AddFriendDialog({
      onAdd: (name: string): boolean => {
        return this.addFriend(name)
      }
    }),
    customStyle: true
  })

  aboutToAppear(): void {
    // 🌟 兜底：进入消息页时对齐当前身份的消息账本并补齐种子，
    //    避免教师/助教登录后消息列表为空（历史「消息无法查看」根因之一）
    MessageCenter.activateScope()
    MessageCenter.ensureSeed()
    this.msgList = MessageCenter.list().slice()
  }

  unreadCount(): number {
    return this.msgList.filter((m: MessageItem) => !m.isRead).length
  }

  unreadOf(key: string): number {
    return this.msgList.filter((m: MessageItem) => !m.isRead && MessageCenter.match(m.type, key)).length
  }

  filteredMsgs(): MessageItem[] {
    if (this.msgFilter === 'all') {
      return this.msgList
    }
    return this.msgList.filter((m: MessageItem) => MessageCenter.match(m.type, this.msgFilter))
  }

  // 🌟 会话列表：好友优先，再补上群聊类通知里出现过的联系人（排除系统与通知发送者）
  contacts(): string[] {
    let names: string[] = []
    this.friendList.forEach((f: string) => {
      if (names.indexOf(f) < 0) {
        names.push(f)
      }
    })
    this.msgList.forEach((m: MessageItem) => {
      if (m.type === 'comment' && m.postId === '' && names.indexOf(m.sender) < 0) {
        names.push(m.sender)
      }
    })
    return names
  }

  // 🌟 添加好友：校验后写入好友列表，并收到对方一条打招呼消息；返回是否成功
  addFriend(name: string): boolean {
    if (name === '') {
      promptAction.showToast({ message: '请输入好友名字' })
      return false
    }
    if (name === this.nickname) {
      promptAction.showToast({ message: '不能添加自己为好友' })
      return false
    }
    if (this.friendList.indexOf(name) >= 0) {
      promptAction.showToast({ message: '已经是好友了' })
      return false
    }
    this.friendList = [name, ...this.friendList]
    // 对方自动发来一条打招呼消息，立刻可以开始聊天
    let greet = new ChatMessage(`friend_${Date.now()}`, `我们已经成为好友啦，快聊两句吧！`, false)
    let newMap: Record<string, ChatMessage[]> = {}
    Object.keys(this.chatMap).forEach((k: string) => {
      newMap[k] = this.chatMap[k]
    })
    newMap[name] = [greet, ...(this.chatMap[name] ?? [])]
    this.chatMap = newMap
    promptAction.showToast({ message: `已添加好友：${name}` })
    return true
  }

  // 🌟 一键全部已读：写回当前身份消息账本，红点立即清零
  markAllRead() {
    MessageCenter.markAllRead()
    this.msgList = MessageCenter.list().slice()
    promptAction.showToast({ message: '已全部标记为已读' })
  }

  // 🌟 点击消息：先标记已读，再打开详情（所有消息都能看到完整内容）
  openMsg(item: MessageItem) {
    MessageCenter.markRead(item.id)
    this.msgList = MessageCenter.list().slice()

    this.detailCategory = categoryLabel(item.type)
    this.detailColor = categoryOf(item.type).color
    this.detailSender = item.sender
    this.detailTime = item.time
    this.detailContent = item.content
    this.detailRoute = item.route ?? ''
    this.detailTaskId = item.taskId ?? ''
    this.detailPostId = item.postId
    this.detailController = new CustomDialogController({
      builder: MessageDetailDialog({
        category: this.detailCategory,
        color: this.detailColor,
        sender: this.detailSender,
        time: this.detailTime,
        content: this.detailContent,
        actionLabel: this.actionLabel(item),
        onClose: () => {
        },
        onAction: () => {
          this.gotoTarget()
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.detailController.open()
  }

  actionLabel(item: MessageItem): string {
    if ((item.route ?? '') !== '') {
      return '前往查看'
    }
    if (item.postId !== '') {
      return '查看相关帖子'
    }
    return ''
  }

  gotoTarget() {
    if (this.detailRoute !== '') {
      if (this.detailTaskId !== '') {
        router.pushUrl({ url: this.detailRoute, params: { taskId: this.detailTaskId } })
      } else {
        router.pushUrl({ url: this.detailRoute })
      }
      return
    }
    if (this.detailPostId !== '') {
      router.pushUrl({ url: 'pages/social/PostDetailPage', params: { postId: this.detailPostId } })
    }
  }

  // 🌟 点击会话：进入聊天页，同时把该联系人的未读消息标记为已读
  openChat(name: string) {
    let list = this.msgList.map((m: MessageItem) => {
      if (m.sender === name) {
        m.isRead = true
      }
      return m
    })
    MessageCenter.save(list)
    this.msgList = MessageCenter.list().slice()
    router.pushUrl({ url: 'pages/social/ChatPage', params: { name: name } })
  }

  // 🌟 会话入口：头像 + 名字，点击进入聊天
  @Builder
  contactItem(name: string) {
    Column({ space: 6 }) {
      Row() {
        Text(name.slice(0, 1))
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .width(48).height(48).backgroundColor('#3F7EF6')
          .borderRadius(24).textAlign(TextAlign.Center)
      }
      Text(name).fontSize(11).fontColor($r('app.color.text_sub'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(56).textAlign(TextAlign.Center)
    }
    .onClick(() => this.openChat(name))
  }

  // 🌟 分类筛选：全部 + 消息中心六类 + 互动消息
  @Builder
  filterChip(key: string, label: string) {
    Row({ space: 4 }) {
      Text(label)
        .fontSize(13)
        .fontWeight(this.msgFilter === key ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.msgFilter === key ? $r('app.color.primary') : $r('app.color.text_sub'))
      if (this.unreadOf(key) > 0) {
        Text(`${this.unreadOf(key)}`)
          .fontSize(9).fontColor(Color.White)
          .backgroundColor('#EF4444')
          .padding({ left: 4, right: 4, top: 1, bottom: 1 })
          .borderRadius(7)
      }
    }
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .backgroundColor(this.msgFilter === key ? $r('app.color.primary_weak') : $r('app.color.field_bg'))
    .borderRadius(14)
    .border({ width: 1, color: this.msgFilter === key ? $r('app.color.primary') : Color.Transparent })
    .onClick(() => {
      this.msgFilter = key
    })
  }

  // 🌟 消息行：分类标识 + 发送者 + 完整正文摘要 + 未读红点 + 时间
  @Builder
  msgRow(item: MessageItem) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Text(categoryOf(item.type).label.slice(0, 1))
          .width(44).height(44).borderRadius(14)
          .backgroundColor(categoryOf(item.type).color)
          .fontColor(Color.White).fontSize(16).fontWeight(FontWeight.Bold)
          .textAlign(TextAlign.Center)
        if (!item.isRead) {
          Row().width(9).height(9).borderRadius(5)
            .backgroundColor('#EF4444')
            .border({ width: 1.5, color: $r('app.color.card_bg') })
            .offset({ x: 3, y: -3 })
        }
      }

      Column({ space: 6 }) {
        Row({ space: 6 }) {
          Text(item.sender)
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: '52%' })
          // 仅互动消息展示发送者等级，系统 / 教学通知不展示
          if (item.type === 'like' || item.type === 'comment') {
            Text(`LV${userLevel(item.sender)}`)
              .fontSize(9).fontWeight(FontWeight.Bold).fontColor(Color.White)
              .backgroundColor(levelColor(userLevel(item.sender)))
              .borderRadius(3)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
          }
          Text(categoryLabel(item.type))
            .fontSize(9).fontColor(Color.White)
            .backgroundColor(categoryOf(item.type).color)
            .padding({ left: 5, right: 5, top: 1, bottom: 1 }).borderRadius(5)
        }.width('100%')

        Row({ space: 8 }) {
          Text(item.content).fontSize(13).fontColor($r('app.color.text_sub'))
            .layoutWeight(1)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(item.time).fontSize(11).fontColor($r('app.color.text_hint'))
        }.width('100%').alignItems(VerticalAlign.Top)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.text_hint')])
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .onClick(() => this.openMsg(item))
  }

  build() {
    Column() {
      // 顶部标题：消息中心已合并，这里只保留一个「全部已读」和「添加好友」
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text('消息')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_main'))
          Text(`${Permission.roleLabel()} · 通知与互动统一收纳`)
            .fontSize(11).fontColor($r('app.color.text_hint'))
        }.alignItems(HorizontalAlign.Start)

        Blank()

        if (this.isLogged) {
          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.person_filled_badge_plus')).fontSize(16)
              .fontColor([$r('app.color.primary')])
            Text('添加好友').fontSize(13).fontColor($r('app.color.primary'))
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.primary_weak'))
          .borderRadius(14)
          .onClick(() => {
            this.addDialogController.open()
          })
        }
      }
      .width('90%')
      .padding({ top: 24, bottom: 12 })

      // 未读汇总卡
      Row({ space: 12 }) {
        Column({ space: 2 }) {
          Text(`${this.unreadCount()}`).fontSize(26).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
          Text('条未读').fontSize(11).fontColor($r('app.color.text_hint'))
        }
        .alignItems(HorizontalAlign.Start)

        Divider().vertical(true).height(36).color('rgba(63,126,246,0.18)')

        Column({ space: 4 }) {
          Text(this.unreadCount() > 0 ? '系统通知、学习提醒与互动消息都在这里' : '消息已全部读完，保持关注不错过提醒')
            .fontSize(12).fontColor($r('app.color.text_sub'))
          Text('系统通知与学习提醒已统一收纳到本页')
            .fontSize(10).fontColor($r('app.color.text_hint'))
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)

        if (this.unreadCount() > 0) {
          Text('全部已读')
            .fontSize(12).fontWeight(FontWeight.Medium).fontColor(Color.White)
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .backgroundColor($r('app.color.primary'))
            .borderRadius(16)
            .onClick(() => this.markAllRead())
        }
      }
      .width('90%')
      .padding(14)
      .backgroundColor($r('app.color.primary_weak'))
      .borderRadius(16)
      .margin({ bottom: 12 })

      // 分类筛选
      Scroll() {
        Row({ space: 8 }) {
          this.filterChip('all', '全部')
          ForEach(MESSAGE_CATEGORIES, (c: MessageCategory) => {
            this.filterChip(c.key, c.label)
          }, (c: MessageCategory) => c.key)
        }.padding({ left: 16, right: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .margin({ bottom: 10 })

      // 🌟 会话区：点击联系人直接进入聊天页
      if (this.contacts().length > 0) {
        Row() {
          Text('会话').fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_sub'))
          Blank()
          Text('点联系人开始聊天').fontSize(11).fontColor($r('app.color.text_hint'))
        }
        .width('90%')
        .padding({ bottom: 8 })

        Row({ space: 14 }) {
          ForEach(this.contacts(), (name: string) => {
            this.contactItem(name)
          }, (name: string) => name)
        }
        .width('90%')
        .padding({ bottom: 10 })
      }

      if (this.filteredMsgs().length === 0) {
        EmptyState({
          icon: $r('sys.symbol.inbox'),
          title: '暂无消息',
          desc: '系统通知、上课与签到提醒、作业批阅结果都会收纳在这里',
          actionLabel: this.isLogged ? '添加好友' : '',
          onAction: () => {
            this.addDialogController.open()
          }
        })
      } else {
        List({ space: 10 }) {
          // 🌟 key 带上 isRead：已读状态变化后该行会重建，红点立即消失
          ForEach(this.filteredMsgs(), (item: MessageItem) => {
            ListItem() {
              this.msgRow(item)
            }
          }, (item: MessageItem) => `${item.id}_${item.isRead}`)
        }
        .width('90%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .padding({ bottom: 20 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
