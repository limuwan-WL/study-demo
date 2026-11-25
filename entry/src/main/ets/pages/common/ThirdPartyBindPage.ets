import router from '@ohos.router'
import { Feedback } from '../../utils/Feedback'

class ThirdPartyItem {
  key: string = ''
  name: string = ''
  tag: string = ''
  color: string = ''
  desc: string = ''

  constructor(key: string, name: string, tag: string, color: string, desc: string) {
    this.key = key
    this.name = name
    this.tag = tag
    this.color = color
    this.desc = desc
  }
}

const PROVIDERS: ThirdPartyItem[] = [
  new ThirdPartyItem('wechat', '微信', '微', '#22C55E', '绑定后可快捷登录并接收课程提醒'),
  new ThirdPartyItem('qq', 'QQ', 'Q', '#3B82F6', '绑定后可快捷登录'),
  new ThirdPartyItem('apple', 'Apple ID', 'A', '#111827', '绑定后可在 Apple 设备间同步登录态'),
  new ThirdPartyItem('huawei', '华为账号', 'H', '#EF4444', '绑定后可跨设备同步学习数据')
]

// ==================== 绑定第三方账号 ====================
// 🌟 本地模拟绑定：只记录绑定状态，不发起真实第三方授权
@Entry
@Component
export struct ThirdPartyBindPage {
  @StorageLink('thirdPartyBinds') binds: string[] = []

  isBound(key: string): boolean {
    return this.binds.indexOf(key) >= 0
  }

  toggle(item: ThirdPartyItem): void {
    if (this.isBound(item.key)) {
      Feedback.confirm('解除绑定', `确定解除「${item.name}」绑定吗？解除后仍可使用账号密码登录。`, () => {
        this.binds = this.binds.filter((k: string) => k !== item.key)
        Feedback.success(`已解除${item.name}绑定`)
      }, '解除绑定', true)
      return
    }
    this.binds = this.binds.concat([item.key])
    Feedback.success(`已绑定${item.name}（本地模拟，未跳转第三方）`)
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(22)
          .fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Text('第三方账号').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      }
      .width('92%')
      .padding({ top: 16, bottom: 12 })

      Column({ space: 10 }) {
        ForEach(PROVIDERS, (item: ThirdPartyItem) => {
          Row({ space: 12 }) {
            Text(item.tag)
              .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
              .width(42).height(42).borderRadius(21)
              .backgroundColor(item.color).textAlign(TextAlign.Center)
            Column({ space: 3 }) {
              Text(item.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
              Text(item.desc).fontSize(11).fontColor($r('app.color.text_hint'))
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text(this.isBound(item.key) ? '解除绑定' : '去绑定')
              .fontSize(12)
              .fontColor(this.isBound(item.key) ? $r('app.color.text_sub') : $r('app.color.primary'))
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor(this.isBound(item.key) ? $r('app.color.field_bg') : $r('app.color.primary_weak'))
              .borderRadius(12)
              .onClick(() => this.toggle(item))
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(14)
        }, (item: ThirdPartyItem) => item.key)
      }
      .width('92%')

      Text('说明：当前工程无真实后端，绑定仅为本地状态模拟，不会跳转第三方授权页，也不会上传任何账号信息。')
        .fontSize(11).fontColor($r('app.color.text_hint'))
        .width('92%').padding({ top: 14 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
