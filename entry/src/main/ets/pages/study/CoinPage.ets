import { promptAction } from '@kit.ArkUI'
import router from '@ohos.router'
import { CoinRecord, CoinOrder, NoteItem, PostItem } from '../../model/DataModel'
import { MessageCenter } from '../../model/MessageCenterModel'
import { Permission } from '../../model/PermissionModel'
import { EmptyState } from '../../components/StatusViews'

const RECHARGE_PACKS: number[] = [10, 30, 50, 100, 200, 500]
const CHANNELS: string[] = ['微信', '支付宝', '银行卡']

@Entry
@Component
export struct CoinPage {
  @StorageLink('coins') coins: number = 0
  // 🌟 免费金币：优质内容发布任务（公开笔记 / 社区帖子），每日可领取一次
  @StorageLink('noteList') noteList: NoteItem[] = []
  @StorageLink('postList') postList: PostItem[] = []
  @StorageLink('coinFreeClaims') claims: Record<string, string> = {}
  @StorageLink('coinRecords') coinRecords: CoinRecord[] = []
  @StorageLink('coinOrders') coinOrders: CoinOrder[] = []
  @State channel: string = '微信'
  @State selectedPack: number = 10
  @StorageLink('coinLiked') liked: boolean = false
  @State tipAmount: number = 1
  @State paying: boolean = false
  // 🌟 开票表单：invoiceFor 为正在填写的订单 id，空串表示收起
  @State invoiceFor: string = ''
  @State invoiceTitle: string = ''
  @State invoiceTaxNo: string = ''

  aboutToAppear() {
    // 🌟 页面级角色隔离：金币体系仅学生使用，教师 / 助教误入时退回
    if (!Permission.isStudent()) {
      promptAction.showToast({ message: '金币体系仅对学生开放，教师与助教无需使用' })
      router.back()
      return
    }
    // 种子数据：仅首次进入（无任何收支记录且余额不足）时写入，避免覆盖已充值/已消费的余额
    if (this.coinRecords.length === 0) {
      // 🌟 收支明细与余额对得上：1000（充值）+ 120（新人礼包）= 1120
      this.coinRecords = [
        new CoinRecord('recharge', 1000, '微信充值 100 元'),
        new CoinRecord('task', 120, '新人金币礼包')
      ]
      if (this.coins < 1120) {
        this.coins = 1120
      }
      if (this.coinOrders.length === 0) {
        this.coinOrders = [new CoinOrder('微信', 100, 1000)]
      }
    }
  }

  // 🌟 充值先弹确认框，确认后才进入支付流程，不再「点一下就成功」
  confirmRecharge(): void {
    const gain = this.selectedPack * 10
    promptAction.showDialog({
      title: '确认支付',
      message: `支付方式：${this.channel}\n充值金额：¥${this.selectedPack}\n到账金币：${gain} 金币`,
      buttons: [
        { text: '取消', color: '#6B7280' },
        { text: '确认支付', color: '#3F7EF6' }
      ]
    }).then((res: promptAction.ShowDialogSuccessResponse) => {
      if (res.index === 1) {
        this.payNow()
      }
    })
  }

  // 🌟 模拟支付处理耗时，避免「点击立即到账」的假感；期间按钮置为处理中
  payNow(): void {
    if (this.paying) {
      return
    }
    this.paying = true
    const channel = this.channel
    const pack = this.selectedPack
    const gain = pack * 10
    setTimeout(() => {
      this.coins += gain
      this.coinRecords = [new CoinRecord('recharge', gain, `${channel}充值 ${pack} 元`)].concat(this.coinRecords)
      this.coinOrders = [new CoinOrder(channel, pack, gain)].concat(this.coinOrders)
      // 🌟 充值成功后写入消息中心「充值订单」分类（受推送开关控制）
      MessageCenter.pushIfEnabled('recharge', '充值订单',
        `${channel}充值 ${pack} 元已到账，获得 ${gain} 金币，当前余额 ${this.coins}`)
      this.paying = false
      promptAction.showToast({ message: `支付成功，${gain} 金币已到账` })
    }, 700)
  }

  invoiceStateLabel(s: string): string {
    if (s === 'applied') {
      return '开票申请已提交'
    }
    if (s === 'issued') {
      return '已开具'
    }
    return '申请开票'
  }

  openInvoice(o: CoinOrder): void {
    this.invoiceFor = o.id
    this.invoiceTitle = o.invoiceTitle
    this.invoiceTaxNo = o.invoiceTaxNo
  }

  // 🌟 提交开票申请：本地模拟，状态落库并写入消息中心
  submitInvoice(o: CoinOrder): void {
    if (this.invoiceTitle.trim() === '') {
      promptAction.showToast({ message: '请填写发票抬头' })
      return
    }
    this.coinOrders = this.coinOrders.map((it: CoinOrder) => {
      if (it.id === o.id) {
        it.invoiceState = 'applied'
        it.invoiceTitle = this.invoiceTitle.trim()
        it.invoiceTaxNo = this.invoiceTaxNo.trim()
      }
      return it
    })
    MessageCenter.pushIfEnabled('recharge', '开票申请',
      `订单 ${o.orderNo}（${o.amountYuan} 元）开票申请已提交，抬头「${this.invoiceTitle.trim()}」，电子发票将发送到绑定邮箱`)
    this.invoiceFor = ''
    promptAction.showToast({ message: '开票申请已提交' })
  }

  like() {
    this.liked = true
    promptAction.showToast({ message: '点赞成功（免费）' })
  }

  tip() {
    if (this.tipAmount < 1) { this.tipAmount = 1 }
    if (this.tipAmount > this.coins) {
      promptAction.showToast({ message: '金币余额不足' })
      return
    }
    this.coins -= this.tipAmount
    this.coinRecords = [new CoinRecord('tip', -this.tipAmount, `投币赞赏 ${this.tipAmount} 金币`)].concat(this.coinRecords)
    promptAction.showToast({ message: `投币 ${this.tipAmount} 金币成功` })
  }

  // ==================== 免费赚金币 ====================
  todayStr(): string {
    let d = new Date()
    let m = d.getMonth() + 1
    let day = d.getDate()
    return `${d.getFullYear()}-${m < 10 ? '0' + m : m}-${day < 10 ? '0' + day : day}`
  }

  publicNoteCount(): number {
    return this.noteList.filter((n: NoteItem) => !n.isDeleted && n.visibility === 'public').length
  }

  claimedToday(id: string): boolean {
    return this.claims[id] === this.todayStr()
  }

  claimFree(id: string, title: string, reward: number) {
    if (this.claimedToday(id)) {
      promptAction.showToast({ message: '这项奖励今日已领取，明天再来' })
      return
    }
    if (id === 'note' && this.publicNoteCount() === 0) {
      promptAction.showToast({ message: '还没有公开笔记：先在笔记中把一篇设为「公开」' })
      return
    }
    if (id === 'post' && this.postList.length === 0) {
      promptAction.showToast({ message: '还没有发布过内容：先去社区发布一条帖子' })
      return
    }
    this.coins += reward
    this.coinRecords = [new CoinRecord('task', reward, `完成任务：${title}`)].concat(this.coinRecords)
    let next: Record<string, string> = {}
    Object.keys(this.claims).forEach((k: string) => {
      next[k] = this.claims[k]
    })
    next[id] = this.todayStr()
    this.claims = next
    MessageCenter.pushIfEnabled('system', '金币奖励', `完成任务「${title}」，获得 ${reward} 金币，当前余额 ${this.coins}`)
    promptAction.showToast({ message: `领取成功，+${reward} 金币` })
  }

  @Builder
  freeTaskRow(id: string, title: string, desc: string, reward: number, ready: boolean) {
    Row({ space: 10 }) {
      Column({ space: 3 }) {
        Text(title).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
        Text(desc).fontSize(11).fontColor($r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Column({ space: 4 }) {
        Text(`+${reward} 金币`).fontSize(11).fontColor('#F59E0B')
        Button(this.claimedToday(id) ? '已领取' : (ready ? '领取' : '去完成'))
          .fontSize(12).height(30).padding({ left: 12, right: 12 })
          .backgroundColor(this.claimedToday(id) ? $r('app.color.field_bg') : (ready ? '#F59E0B' : $r('app.color.primary_weak')))
          .fontColor(this.claimedToday(id) ? $r('app.color.text_hint') : (ready ? Color.White : $r('app.color.primary')))
          .onClick(() => this.claimFree(id, title, reward))
      }
    }
    .width('100%').padding(10)
    .backgroundColor($r('app.color.field_bg')).borderRadius(10)
  }

  // 🌟 充值订单：展示订单号 / 金额 / 时间，未开票的订单可填写抬头申请开票
  @Builder
  orderRow(o: CoinOrder) {
    Column({ space: 8 }) {
      Row() {
        Column({ space: 3 }) {
          Text(`${o.channel}充值 ¥${o.amountYuan}`).fontSize(13).fontColor($r('app.color.text_main'))
          Text(`订单号 ${o.orderNo}`).fontSize(10).fontColor($r('app.color.text_hint'))
          Text(new Date(o.time).toLocaleString('zh-CN')).fontSize(10).fontColor($r('app.color.text_hint'))
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Column({ space: 4 }) {
          Text(`+${o.coins} 金币`).fontSize(13).fontWeight(FontWeight.Bold).fontColor('#F59E0B')
          if (o.invoiceState === 'none') {
            Button('申请开票')
              .fontSize(11).height(26).padding({ left: 10, right: 10 })
              .backgroundColor($r('app.color.primary_weak')).fontColor($r('app.color.primary'))
              .onClick(() => this.openInvoice(o))
          } else {
            Text(this.invoiceStateLabel(o.invoiceState))
              .fontSize(10).fontColor('#10B981')
          }
        }.alignItems(HorizontalAlign.End)
      }.width('100%')

      if (this.invoiceFor === o.id) {
        Column({ space: 8 }) {
          TextInput({ text: this.invoiceTitle, placeholder: '发票抬头（个人姓名或公司名称）' })
            .fontSize(12).height(36)
            .backgroundColor($r('app.color.page_bg')).borderRadius(8)
            .onChange((v: string) => {
              this.invoiceTitle = v
            })
          TextInput({ text: this.invoiceTaxNo, placeholder: '税号（个人抬头可不填）' })
            .fontSize(12).height(36)
            .backgroundColor($r('app.color.page_bg')).borderRadius(8)
            .onChange((v: string) => {
              this.invoiceTaxNo = v
            })
          Row({ space: 8 }) {
            Button('取消')
              .fontSize(12).height(32).layoutWeight(1)
              .backgroundColor($r('app.color.field_bg')).fontColor($r('app.color.text_main'))
              .onClick(() => {
                this.invoiceFor = ''
              })
            Button('提交申请')
              .fontSize(12).height(32).layoutWeight(1).backgroundColor('#3F7EF6')
              .onClick(() => this.submitInvoice(o))
          }.width('100%')
        }
        .width('100%').padding(10)
        .backgroundColor($r('app.color.page_bg')).borderRadius(8)
      }
    }
    .width('100%').padding(12)
    .backgroundColor($r('app.color.card_bg')).borderRadius(8)
  }

  @Builder
  recordItem(r: CoinRecord) {
    Row() {
      Column({ space: 2 }) {
        Text(r.desc).fontSize(13).fontColor($r('app.color.text_main'))
        Text(new Date(r.time).toLocaleString('zh-CN')).fontSize(11).fontColor($r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text(`${r.amount > 0 ? '+' : ''}${r.amount}`)
        .fontSize(15).fontWeight(FontWeight.Bold)
        .fontColor(r.amount > 0 ? '#10B981' : '#EF4444')
    }
    .width('100%').padding(12).backgroundColor($r('app.color.card_bg')).borderRadius(8)
  }

  build() {
    Column() {
      // 顶部余额
      Column() {
        Text('金币余额').fontSize(13).fontColor('#94A3B8')
        Text(`${this.coins}`).fontSize(40).fontWeight(FontWeight.Bold).fontColor('#FBBF24')
        Text('1元 = 10金币 · 仅用于点赞投币，不可购买课程').fontSize(11).fontColor('#94A3B8')
      }.width('100%').padding(30).alignItems(HorizontalAlign.Center)
        .linearGradient({ angle: 135, colors: [['#1E293B', 0], ['#334155', 1]] })

      Scroll() {
        Column({ space: 16 }) {
          // 充值
          Column({ space: 12 }) {
            Text('充值').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
            Text('支付方式').fontSize(12).fontColor($r('app.color.text_sub'))
            Row({ space: 8 }) {
              ForEach(CHANNELS, (c: string) => {
                Text(c)
                  .fontSize(13)
                  .fontColor(this.channel === c ? Color.White : $r('app.color.text_main'))
                  .backgroundColor(this.channel === c ? '#3F7EF6' : $r('app.color.field_bg'))
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .borderRadius(14)
                  .onClick(() => { this.channel = c })
              }, (c: string) => c)
            }
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(RECHARGE_PACKS, (p: number) => {
                Column({ space: 2 }) {
                  Text(`${p * 10} 金币`).fontSize(15).fontWeight(FontWeight.Bold).fontColor('#FBBF24')
                  Text(`¥${p}`).fontSize(11).fontColor($r('app.color.text_sub'))
                }
                .width('30%').aspectRatio(2).margin(4)
                .backgroundColor(this.selectedPack === p ? '#EBF2FF' : $r('app.color.field_bg'))
                .borderRadius(10)
                .border({ width: this.selectedPack === p ? 1.5 : 0, color: '#3F7EF6' })
                .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                .onClick(() => { this.selectedPack = p })
              }, (p: number) => p.toString())
            }.width('100%')
            Button(this.paying ? '支付处理中…' : `立即支付 ¥${this.selectedPack}`)
              .width('100%').height(44).backgroundColor('#3F7EF6')
              .enabled(!this.paying)
              .opacity(this.paying ? 0.7 : 1)
              .onClick(() => this.confirmRecharge())
          }
          .width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(12)

          // 点赞投币
          Column({ space: 12 }) {
            Row() {
              Text('点赞与投币').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              Blank()
              Text('金币仅用于互动').fontSize(10).fontColor($r('app.color.text_hint'))
            }.width('100%')
            Button(this.liked ? '已点赞' : '👍 点赞')
              .width('100%').height(40)
              .backgroundColor(this.liked ? $r('app.color.field_bg') : '#3F7EF6')
              .fontColor(this.liked ? $r('app.color.text_hint') : Color.White)
              .enabled(!this.liked)
              .onClick(() => this.like())
            Row({ space: 8 }) {
              Text('投币数量').fontSize(13).fontColor($r('app.color.text_sub'))
              Button('-')
                .type(ButtonType.Normal)
                .width(32).height(32).borderRadius(8)
                .backgroundColor($r('app.color.field_bg'))
                .fontColor($r('app.color.text_main')).fontSize(16)
                .onClick(() => { if (this.tipAmount > 1) { this.tipAmount-- } })
              Text(`${this.tipAmount}`)
                .width(36).textAlign(TextAlign.Center)
                .fontSize(14).fontColor($r('app.color.text_main'))
              Button('+')
                .type(ButtonType.Normal)
                .width(32).height(32).borderRadius(8)
                .backgroundColor($r('app.color.field_bg'))
                .fontColor($r('app.color.text_main')).fontSize(16)
                .onClick(() => { if (this.tipAmount < 999) { this.tipAmount++ } })
              Blank()
              Button(`投 ${this.tipAmount} 金币`)
                .height(36).padding({ left: 14, right: 14 }).fontSize(13)
                .backgroundColor('#F59E0B')
                .onClick(() => this.tip())
            }.width('100%').alignItems(VerticalAlign.Center)
          }
          .width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(12)

          // 免费赚金币：优质内容发布任务
          Column({ space: 8 }) {
            Row() {
              Text('免费赚金币').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              Blank()
              Text('每日可领').fontSize(10).fontColor('#F59E0B')
            }.width('100%')
            this.freeTaskRow('note', '发布公开笔记', `当前公开笔记 ${this.publicNoteCount()} 篇 · 奖励 10 金币`, 10,
              this.publicNoteCount() > 0)
            this.freeTaskRow('post', '发布社区优质内容', `已发布 ${this.postList.length} 条 · 奖励 15 金币`, 15,
              this.postList.length > 0)
            Text('任务为本地演示规则：满足条件即可领取，每日每项限一次')
              .fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
          }
          .width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(12)

          // 充值订单与开票
          Column({ space: 8 }) {
            Row() {
              Text('充值订单').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              Blank()
              Text('可申请电子发票').fontSize(10).fontColor($r('app.color.text_hint'))
            }.width('100%')
            if (this.coinOrders.length === 0) {
              EmptyState({
                icon: $r('sys.symbol.star_fill'),
                title: '暂无充值订单',
                desc: '充值成功后会在这里生成订单号，可申请开具发票'
              })
            } else {
              ForEach(this.coinOrders, (o: CoinOrder) => {
                this.orderRow(o)
              }, (o: CoinOrder) => o.id)
            }
            Text('订单与开票为本地演示：提交后状态置为「已申请」，不会生成真实发票。')
              .fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
          }
          .width('92%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(12)

          // 收支明细
          Column({ space: 8 }) {
            Text('收支明细').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
            ForEach(this.coinRecords, (r: CoinRecord) => {
              this.recordItem(r)
            }, (r: CoinRecord) => r.id)
            if (this.coinRecords.length === 0) {
              EmptyState({
                icon: $r('sys.symbol.star_fill'),
                title: '暂无收支记录',
                desc: '充值、投币打赏等金币变动会按时间记录在这里'
              })
            }
          }.width('92%')
        }.width('100%').padding({ top: 16, bottom: 30 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }
}
