import router from '@ohos.router'
import { ThemeColor } from '../../utils/ThemeColor'

class PolicySection {
  title: string = ''
  body: string = ''

  constructor(title: string, body: string) {
    this.title = title
    this.body = body
  }
}

const AGREEMENT_SECTIONS: PolicySection[] = [
  new PolicySection('一、服务说明',
    '校园小助手为本机离线学习工具，提供待办、日程、笔记、收藏、社区与课程练习等功能。当前版本的数据均保存在本机，不涉及云端同步。'),
  new PolicySection('二、账号与安全',
    '你应妥善保管本机注册的账号与密码，不得将账号转借他人使用。修改密码后请牢记新密码，因个人保管不当造成的本地数据丢失由使用者自行承担。'),
  new PolicySection('三、使用规范',
    '使用社区、反馈等功能时，不得发布违法违规、侵犯他人权益或含有恶意代码的内容。对于违反规范的内容，我们有权在本机记录中予以删除。'),
  new PolicySection('四、内容与知识产权',
    '应用内的课程、题库与界面设计仅供学习交流使用。未经许可，不得用于商业用途或进行二次分发。'),
  new PolicySection('五、免责声明',
    '本应用为演示性质的学习工具，不构成任何形式的学业承诺。因设备故障、误操作导致的数据丢失，我们会尽力协助但不承担赔偿责任。'),
  new PolicySection('六、协议更新',
    '我们可能根据功能调整更新本协议。协议更新后，你继续使用本应用即视为接受更新后的内容。')
]

const PRIVACY_SECTIONS: PolicySection[] = [
  new PolicySection('一、我们收集的信息',
    '本应用仅在你主动填写时保存账号、昵称、头像、绑定手机号、反馈内容等本地数据。手机号验证为本地模拟，不会真实发送短信。'),
  new PolicySection('二、信息的使用',
    '上述信息仅用于在本机展示账号状态、恢复学习进度与查看反馈记录，不会用于广告推送或提供给任何第三方。'),
  new PolicySection('三、信息的存储',
    '所有数据通过应用本地存储能力保存在设备内。卸载应用或清空本地数据后，相关内容将被删除且无法恢复。'),
  new PolicySection('四、相册权限',
    '当你选择头像或反馈截图时，应用会读取你主动选中的图片，并复制到应用沙箱内使用。应用不会扫描或上传相册中的其他图片。'),
  new PolicySection('五、你的权利',
    '你可以随时在「个人资料」页（或「我的」页名片）修改昵称、头像，或在设置页修改密码与手机号；也可以通过「清空本地数据」一次性删除全部本地记录。'),
  new PolicySection('六、联系我们',
    '如对隐私保护有任何疑问，可通过设置页的「客服反馈」提交，或发送邮件至 support@campus-assistant.cn。')
]

@Entry
@Component
export struct PolicyPage {
  @State pageType: string = 'agreement'

  aboutToAppear() {
    ThemeColor.isDark = AppStorage.get<boolean>('isDark') ?? false
    let params = router.getParams() as Record<string, string>
    if (params && params['type']) {
      this.pageType = params['type']
    }
  }

  pageTitle(): string {
    return this.pageType === 'privacy' ? '隐私政策' : '用户协议'
  }

  sections(): PolicySection[] {
    return this.pageType === 'privacy' ? PRIVACY_SECTIONS : AGREEMENT_SECTIONS
  }

  @Builder
  header() {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(24)
        .fontColor([ThemeColor.get('text_main')])
        .onClick(() => router.back())
      Text(this.pageTitle()).fontSize(20).fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get('text_main')).margin({ left: 12 })
    }
    .width('100%').height(56).padding({ left: 16 })
  }

  build() {
    Column() {
      this.header()

      Scroll() {
        Column({ space: 14 }) {
          Text('更新日期：2026 年 11 月 18 日')
            .fontSize(11).fontColor(ThemeColor.get('text_hint')).width('100%')

          ForEach(this.sections(), (s: PolicySection) => {
            Column({ space: 6 }) {
              Text(s.title).fontSize(14).fontWeight(FontWeight.Bold)
                .fontColor(ThemeColor.get('text_main')).width('100%')
              Text(s.body).fontSize(13).lineHeight(21)
                .fontColor(ThemeColor.get('text_sub')).width('100%')
            }
            .width('100%').padding(16)
            .backgroundColor(ThemeColor.get('card_bg')).borderRadius(14)
            .alignItems(HorizontalAlign.Start)
          }, (s: PolicySection) => s.title)

          Text('如对以上内容有疑问，可在「客服反馈」中联系我们')
            .fontSize(11).fontColor(ThemeColor.get('text_hint'))
            .width('100%').textAlign(TextAlign.Center).margin({ top: 4 })
        }
        .width('92%').padding({ top: 8, bottom: 30 })
      }
      .layoutWeight(1).scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%').height('100%')
    .backgroundColor(ThemeColor.get('page_bg'))
  }
}
