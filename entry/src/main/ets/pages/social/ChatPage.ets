import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { ChatMessage, userLevel, levelColor } from '../../model/DataModel';
import { ChatColors, resolveChatColors } from '../../model/ChatTheme';
import { expLevelOf, onChatMessage } from '../../model/GrowthModel';

// 🌟 聊天背景透明度调节弹窗：滑杆实时生效，写入 AppStorage 持久化（点缀色随聊天主题）
@CustomDialog
struct ChatBgDialog {
  controller: CustomDialogController
  @StorageLink('chatBgOpacity') op: number = 100
  @StorageLink('chatTheme') chatTheme: string = 'default'
  @StorageLink('colorModeSetting') colorModeSetting: number = 0

  accent(): string {
    return resolveChatColors(this.chatTheme, this.colorModeSetting === 1).accent
  }

  build() {
    Column({ space: 16 }) {
      Text('聊天背景').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      Row() {
        Text('透明度').fontSize(14).fontColor($r('app.color.text_label'))
        Blank()
        Text(`${this.op}%`).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.accent())
      }.width('100%')
      Slider({ value: this.op, min: 10, max: 100, step: 5, style: SliderStyle.OutSet })
        .selectedColor(this.accent())
        .trackColor($r('app.color.divider_color'))
        .onChange((value: number) => {
          this.op = Math.round(value)
        })
      Row({ space: 12 }) {
        Text('恢复默认')
          .fontSize(14).fontColor($r('app.color.text_label'))
          .layoutWeight(1).textAlign(TextAlign.Center)
          .padding({ top: 10, bottom: 10 })
          .backgroundColor($r('app.color.field_bg'))
          .borderRadius(20)
          .onClick(() => {
            this.op = 100
          })
        Text('完成')
          .fontSize(14).fontColor(Color.White)
          .layoutWeight(1).textAlign(TextAlign.Center)
          .padding({ top: 10, bottom: 10 })
          .backgroundColor(this.accent())
          .borderRadius(20)
          .onClick(() => {
            this.controller.close()
          })
      }.width('100%')
    }
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
  }
}

@Entry
@Component
struct ChatPage {
  // 接收从路由传过来的联系人名字
  @State contactName: string = '聊天'
  // 🌟 当前用户昵称（等级徽章按昵称计算）
  @StorageLink('nickname') nickname: string = ''

  // 🌟 聊天记录按联系人持久化：key = 联系人名，重启应用不丢失
  @StorageLink('chatMap') chatMap: Record<string, ChatMessage[]> = {}

  // 🌟 聊天背景透明度（可自行调节，持久化）
  @StorageLink('chatBgOpacity') chatBgOpacity: number = 100
  // 🌟 深浅色模式：0 浅色 / 1 深色，聊天列表动态底色按模式取基色
  @StorageLink('colorModeSetting') colorModeSetting: number = 0
  // 🌟 聊天主题（我的页面可选择，与深浅色模式联动）
  @StorageLink('chatTheme') chatTheme: string = 'default'

  // 🌟 当前主题 + 模式解析出的颜色集合
  cc(): ChatColors {
    return resolveChatColors(this.chatTheme, this.colorModeSetting === 1)
  }

  // 🌟 用户等级徽章：统一经验等级（自己）+ 成员等级（其他用户），颜色随等级递进
  @Builder
  lvBadge(name: string, size: number) {
    Text(`LV${this.lvOf(name)}`)
      .fontSize(size).fontWeight(FontWeight.Bold).fontColor(Color.White)
      .backgroundColor(levelColor(this.lvOf(name)))
      .borderRadius(3)
      .padding({ left: 3, right: 3, top: 1, bottom: 1 })
  }

  // 🌟 自己的等级用经验等级（与我的页/课程页一致），其他成员仍按昵称展示
  lvOf(name: string): number {
    if (name === this.myNickname) {
      return expLevelOf(this.userExp)
    }
    return userLevel(name)
  }

  // 🌟 聊天头像：右下角叠加等级徽章
  @Builder
  avatarWithLv(text: string, name: string, bg: string) {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Row() {
        Text(text).fontColor(Color.White).fontSize(14).fontWeight(FontWeight.Bold)
      }
      .width(36).height(36).backgroundColor(bg).borderRadius(18)
      .justifyContent(FlexAlign.Center)
      this.lvBadge(name, 8)
    }
  }

  bgDialogController: CustomDialogController = new CustomDialogController({
    builder: ChatBgDialog({}),
    customStyle: true
  })

  @State messageList: ChatMessage[] = []
  @State inputText: string = ''
  // 🌟 成长体系：自己昵称 + 经验值（等级徽章统一口径）
  @StorageLink('nickname') myNickname: string = ''
  @StorageLink('userExp') userExp: number = 0
  private scroller: Scroller = new Scroller()
  private isAlive: boolean = true

  // 🌟 聊天动态化：正在输入、逐字显示、气泡入场、送达/已读
  @State typing: boolean = false
  @State dotPhase: number = 0
  @State enterId: string = ''
  @State enterAlpha: number = 1
  @State peerRead: boolean = false
  @State showEmoji: boolean = false
  private typingTimer: number = -1
  private typeTimer: number = -1
  // 🌟 快捷短语 / 表情入口（不改变原有聊天结构，仅在输入区上方补充）
  private quickPhrases: string[] = ['好的，谢谢老师', '我马上看一下', '这个知识点没太听懂', '今天的作业是什么？', '收到，已提交']
  private emojis: string[] = ['😀', '😂', '🥰', '👍', '🎉', '😭', '🤔', '🔥', '🌹', '☕']

  aboutToAppear() {
    // 获取路由参数
    let params = router.getParams() as Record<string, string>
    if (params && params['name']) {
      this.contactName = params['name']
    }

    // 恢复历史记录；没有历史时给一条欢迎语
    let history = this.chatMap[this.contactName]
    if (history && history.length > 0) {
      this.messageList = history
    } else {
      this.messageList = [new ChatMessage(Date.now().toString(), `你好，我是${this.contactName}，找我有什么事吗？`, false)]
      this.saveChat()
    }
  }

  aboutToDisappear() {
    this.isAlive = false
    if (this.typingTimer !== -1) {
      clearTimeout(this.typingTimer)
      this.typingTimer = -1
    }
    if (this.typeTimer !== -1) {
      clearTimeout(this.typeTimer)
      this.typeTimer = -1
    }
  }

  // 🌟 时间分组：首条或与上一条间隔 ≥5 分钟才显示时间
  minutesOf(t: string): number {
    let parts = t.split(':')
    if (parts.length < 2) {
      return 0
    }
    return parseInt(parts[0]) * 60 + parseInt(parts[1])
  }

  showTime(index: number): boolean {
    if (index <= 0) {
      return true
    }
    let diff = this.minutesOf(this.messageList[index].time) - this.minutesOf(this.messageList[index - 1].time)
    return diff >= 5 || diff < 0
  }

  // 🌟 只有我发出的最新一条展示「已送达 / 已读」
  isLastMine(msg: ChatMessage): boolean {
    for (let i = this.messageList.length - 1; i >= 0; i--) {
      if (this.messageList[i].isMe) {
        return this.messageList[i].id === msg.id
      }
    }
    return false
  }

  hasAny(text: string, keys: string[]): boolean {
    for (let i = 0; i < keys.length; i++) {
      if (text.indexOf(keys[i]) >= 0) {
        return true
      }
    }
    return false
  }

  // 🌟 按场景挑选回复语，避免永远是同一句
  replyFor(text: string): string {
    if (this.hasAny(text, ['你好', '您好', '在吗', '在么', 'hi', 'hello'])) {
      return `在的，我是${this.contactName}～有什么想聊的？`
    }
    if (this.hasAny(text, ['作业', '提交'])) {
      return '作业我看到了，第 3 题步骤可以再写细一点，其他地方都没问题。'
    }
    if (this.hasAny(text, ['考试', '成绩', '分数', '排名'])) {
      return '这次测验整体不错，错题集中在函数单调性，晚点我把解析发你。'
    }
    if (this.hasAny(text, ['课程', '知识点', '没听懂', '不会', '不懂'])) {
      return '别急，这个点我录过一小段讲解，先看例题再回头看概念会顺很多。'
    }
    if (this.hasAny(text, ['打卡', '签到'])) {
      return '今天的打卡已经记录啦，坚持得不错，继续保持～'
    }
    if (this.hasAny(text, ['谢谢', '感谢', 'thx'])) {
      return '不客气，有问题随时找我。'
    }
    if (this.hasAny(text, ['再见', '拜拜', '晚安'])) {
      return '好的，早点休息，明天见～'
    }
    if (this.hasAny(text, ['?', '？', '怎么', '为什么', '如何'])) {
      return '这个问题挺有意思，可以分两步看：先找出已知条件，再套用对应公式试试。'
    }
    let pool: string[] = [
      `收到，我是${this.contactName}，稍后详细回复你。`,
      '嗯嗯，我刚好也在看这块内容。',
      '这个想法不错，我们可以一起理一理。',
      '我先把重点记下来，等会儿同步给你。',
      '听起来可行，要不要先从最小的一步开始？'
    ]
    return pool[Math.floor(Math.random() * pool.length)]
  }

  // 🌟 「正在输入」小圆点呼吸动画
  startDotAnim() {
    this.dotPhase = 0
    let tick = () => {
      if (!this.isAlive || !this.typing) {
        return
      }
      this.dotPhase = (this.dotPhase + 1) % 3
      this.typingTimer = setTimeout(tick, 320)
    }
    this.typingTimer = setTimeout(tick, 320)
  }

  stopDotAnim() {
    if (this.typingTimer !== -1) {
      clearTimeout(this.typingTimer)
      this.typingTimer = -1
    }
  }

  // 🌟 新气泡入场：淡入 + 轻微上移
  animateEnter(id: string) {
    this.enterId = id
    this.enterAlpha = 0
    animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
      this.enterAlpha = 1
    })
  }

  // 🌟 对方消息逐字打出，结束后再持久化
  typeIncoming(id: string, full: string) {
    let step = 0
    let tick = () => {
      if (!this.isAlive) {
        return
      }
      step += 2
      let list: ChatMessage[] = this.messageList.slice()
      let idx = list.findIndex((m: ChatMessage) => m.id === id)
      if (idx < 0) {
        return
      }
      list[idx].content = full.substring(0, step)
      this.messageList = list
      if (step < full.length) {
        this.typeTimer = setTimeout(tick, 26)
      } else {
        this.saveChat()
        this.scrollToBottom()
      }
    }
    tick()
  }

  saveChat() {
    // 记录对象属性赋值即可同步到 AppStorage 并持久化
    this.chatMap[this.contactName] = this.messageList
  }

  sendMessage() {
    if (this.inputText.trim() === '') {
      promptAction.showToast({ message: '内容不能为空' })
      return
    }
    let text = this.inputText.trim()

    // 1. 添加自己的消息（带入场动画）
    let myMsg = new ChatMessage(Date.now().toString(), text, true)
    this.messageList = [...this.messageList, myMsg]
    this.inputText = ''
    this.showEmoji = false
    this.peerRead = false
    this.animateEnter(myMsg.id)
    // 🌟 聊天成长奖励：每条消息 +1 经验 +1 硬币（每日有上限，防刷）
    onChatMessage()
    this.saveChat()
    this.scrollToBottom()

    // 2. 对方先「正在输入」，延迟后按场景回复并逐字打出
    this.typing = true
    this.startDotAnim()
    let delay = 700 + Math.floor(Math.random() * 900)
    setTimeout(() => {
      if (!this.isAlive) {
        return
      }
      this.typing = false
      this.stopDotAnim()
      let replyMsg = new ChatMessage(Date.now().toString(), '', false)
      this.messageList = [...this.messageList, replyMsg]
      this.peerRead = true
      this.scrollToBottom()
      this.typeIncoming(replyMsg.id, this.replyFor(text))
    }, delay)
  }

  scrollToBottom() {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom)
    }, 100)
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor([$r('app.color.text_main')])
          .onClick(() => {
            router.back()
          })
        // 🌟 联系人等级徽章
        Row({ space: 6 }) {
          Text(this.contactName)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_main'))
          this.lvBadge(this.contactName, 10)
        }.margin({ left: 16 })
        Blank()
        // 🌟 调节聊天背景透明度
        SymbolGlyph($r('sys.symbol.paintpalette'))
          .fontSize(22)
          .fontColor([$r('app.color.text_main')])
          .onClick(() => {
            this.bgDialogController.open()
          })
      }
      .width('100%')
      .height(60)
      .padding({ left: 16, right: 16 })
      // 🌟 顶栏随主题变化
      .backgroundColor(this.cc().barBg)
      .border({ width: { bottom: 1 }, color: $r('app.color.divider_color') })

      // 聊天记录列表
      List({ space: 16, scroller: this.scroller }) {
        ForEach(this.messageList, (msg: ChatMessage, index: number) => {
          ListItem() {
            Column() {
              // 🌟 时间分组：只在首条或间隔 ≥5 分钟时展示
              if (this.showTime(index)) {
                Text(msg.time)
                  .fontSize(11)
                  .fontColor(this.cc().timeColor)
                  .margin({ bottom: 4 })
                  .alignSelf(ItemAlign.Center)
              }

              Row() {
                if (msg.isMe) {
                  Blank()
                  Column({ space: 4 }) {
                    // 🌟 我的气泡：随聊天主题变化（颜色 / 字重 / 衬线 / 圆角）
                    Text(msg.content)
                      .fontSize(15)
                      .fontColor(this.cc().myText)
                      .fontWeight(this.cc().fontWeight)
                      .fontFamily(this.cc().serif ? 'serif' : 'HarmonyOS Sans')
                      .backgroundColor(this.cc().myBubble)
                      .border({ width: 1, color: this.cc().bubbleBorder })
                      .padding(12)
                      .borderRadius({ topLeft: this.cc().radius, topRight: 4, bottomLeft: this.cc().radius, bottomRight: this.cc().radius })
                    if (this.isLastMine(msg)) {
                      Text(this.peerRead ? '已读' : '已送达')
                        .fontSize(10)
                        .fontColor(this.cc().timeColor)
                    }
                  }.alignItems(HorizontalAlign.End)

                  // 🌟 我的头像（右下角带等级徽章）
                  Row() {
                    this.avatarWithLv('我', this.nickname, this.cc().accent)
                  }.margin({ left: 8 })
                } else {
                  // 🌟 对方头像（右下角带等级徽章）
                  Row() {
                    this.avatarWithLv(this.contactName.charAt(0), this.contactName, this.cc().accent)
                  }.margin({ right: 8 })

                  // 🌟 对方气泡：随聊天主题变化
                  Text(msg.content)
                    .fontSize(15)
                    .fontColor(this.cc().otherText)
                    .fontWeight(this.cc().fontWeight)
                    .fontFamily(this.cc().serif ? 'serif' : 'HarmonyOS Sans')
                    .backgroundColor(this.cc().otherBubble)
                    .border({ width: 1, color: this.cc().bubbleBorder })
                    .padding(12)
                    .borderRadius({ topLeft: 4, topRight: this.cc().radius, bottomLeft: this.cc().radius, bottomRight: this.cc().radius })
                  Blank()
                }
              }
              .width('100%')
            }
            .padding({ left: 16, right: 16 })
          }
          // 🌟 气泡入场：新消息淡入 + 轻微上移
          .opacity(msg.id === this.enterId ? this.enterAlpha : 1)
          .translate({ y: msg.id === this.enterId ? (1 - this.enterAlpha) * 10 : 0 })
        }, (msg: ChatMessage) => msg.id)

        // 🌟 对方「正在输入」提示（三点呼吸）
        if (this.typing) {
          ListItem() {
            Row({ space: 8 }) {
              Row() {
                this.avatarWithLv(this.contactName.charAt(0), this.contactName, this.cc().accent)
              }.margin({ right: 8 })
              Row({ space: 4 }) {
                Text('对方正在输入').fontSize(11).fontColor(this.cc().timeColor)
                Text('●').fontSize(6).fontColor(this.cc().timeColor).opacity(this.dotPhase === 0 ? 1 : 0.25)
                Text('●').fontSize(6).fontColor(this.cc().timeColor).opacity(this.dotPhase === 1 ? 1 : 0.25)
                Text('●').fontSize(6).fontColor(this.cc().timeColor).opacity(this.dotPhase === 2 ? 1 : 0.25)
              }
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .backgroundColor(this.cc().otherBubble)
              .borderRadius(this.cc().radius)
              Blank()
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .transition(TransitionEffect.OPACITY)
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
      // 🌟 背景透明度可调：越小越透明，底层主题渐变会透出来（基色随主题 + 深浅色变化）
      .backgroundColor(`rgba(${this.cc().listBase}, ${this.chatBgOpacity / 100})`)
      .padding({ top: 16, bottom: 16 })

      // 🌟 快捷短语：点一下填入输入框
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.quickPhrases, (p: string) => {
            Text(p)
              .fontSize(12)
              .fontColor(this.cc().otherText)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(this.cc().otherBubble)
              .borderRadius(14)
              .onClick(() => {
                this.inputText = p
              })
          }, (p: string) => p)
        }.padding({ left: 16, right: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding({ top: 8, bottom: 4 })

      // 🌟 表情入口：点击插入到输入框
      if (this.showEmoji) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.emojis, (e: string) => {
            Text(e)
              .fontSize(22)
              .margin(6)
              .onClick(() => {
                this.inputText = this.inputText + e
              })
          }, (e: string) => e)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }

      // 底部输入框
      Row({ space: 8 }) {
        Text(this.showEmoji ? '⌨️' : '😊')
          .fontSize(20)
          .onClick(() => {
            this.showEmoji = !this.showEmoji
          })
        TextInput({ text: this.inputText, placeholder: '输入消息...' })
          .layoutWeight(1).height(44).backgroundColor(this.cc().inputBg).borderRadius(22)
          .onChange((value: string) => { this.inputText = value })
          .onSubmit(() => { this.sendMessage() })

        Button('发送')
          .height(44)
          .backgroundColor(this.inputText.trim() === '' ? $r('app.color.btn_cancel') : this.cc().accent)
          .fontColor(Color.White).borderRadius(22)
          .enabled(this.inputText.trim() !== '')
          .onClick(() => { this.sendMessage() })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      // 🌟 输入栏随主题变化
      .backgroundColor(this.cc().barBg)
      .padding({ bottom: px2vp(16) })
    }
    .width('100%')
    .height('100%')
    // 🌟 底层主题渐变：随聊天主题 + 深浅色模式切换，透明度调低时会透出来
    .linearGradient({ angle: 180, colors: [[this.cc().gradTop, 0], [this.cc().gradBottom, 1]] })
  }
}
