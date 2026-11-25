import router from '@ohos.router'
import { ThemeColor } from '../../utils/ThemeColor'

const APP_VERSION: string = 'v1.0.0'

@Entry
@Component
export struct AboutPage {
  aboutToAppear() {
    ThemeColor.isDark = AppStorage.get<boolean>('isDark') ?? false
  }

  openPolicy(type: string) {
    router.pushUrl({ url: 'pages/common/PolicyPage', params: { type: type } })
  }

  @Builder
  header() {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(24)
        .fontColor([ThemeColor.get('text_main')])
        .onClick(() => router.back())
      Text('关于我们').fontSize(20).fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get('text_main')).margin({ left: 12 })
    }
    .width('100%').height(56).padding({ left: 16 })
  }

  @Builder
  linkRow(label: string, onTap: () => void) {
    Row() {
      Text(label).fontSize(14).fontColor(ThemeColor.get('text_main')).layoutWeight(1)
      Text('›').fontSize(16).fontColor(ThemeColor.get('text_hint'))
    }
    .width('100%').padding({ left: 4, right: 4, top: 13, bottom: 13 })
    .onClick(() => onTap())
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(13).fontColor(ThemeColor.get('text_sub'))
      Blank()
      Text(value).fontSize(13).fontColor(ThemeColor.get('text_main'))
    }
    .width('100%').padding({ left: 4, right: 4, top: 11, bottom: 11 })
  }

  build() {
    Column() {
      this.header()

      Scroll() {
        Column({ space: 14 }) {
          // 应用标识
          Column({ space: 8 }) {
            Text('🎓')
              .fontSize(40)
              .width(84).height(84)
              .textAlign(TextAlign.Center)
              .linearGradient({ angle: 135, colors: [['#4C8BF5', 0], ['#3F7EF6', 1]] })
              .borderRadius(24)
            Text('校园小助手').fontSize(20).fontWeight(FontWeight.Bold)
              .fontColor(ThemeColor.get('text_main')).margin({ top: 4 })
            Text(APP_VERSION).fontSize(12).fontColor(ThemeColor.get('text_sub'))
          }
          .width('100%').padding({ top: 18, bottom: 18 })
          .backgroundColor(ThemeColor.get('card_bg')).borderRadius(16)

          // 应用介绍
          Column({ space: 8 }) {
            Text('应用介绍').fontSize(13).fontWeight(FontWeight.Bold)
              .fontColor(ThemeColor.get('text_main')).width('100%')
            Text('校园小助手是一款面向学生与老师的校园学习应用：待办、日程、笔记、收藏、社区、课程练习一站式管理，帮助你记录学习与生活的每一步。')
              .fontSize(13).lineHeight(21).fontColor(ThemeColor.get('text_sub'))
              .width('100%')
          }
          .width('100%').padding(16)
          .backgroundColor(ThemeColor.get('card_bg')).borderRadius(14)
          .alignItems(HorizontalAlign.Start)

          // 协议入口
          Column({ space: 0 }) {
            this.linkRow('用户协议', (): void => this.openPolicy('agreement'))
            Divider().color(ThemeColor.get('divider')).margin({ left: 4, right: 4 })
            this.linkRow('隐私政策', (): void => this.openPolicy('privacy'))
          }
          .width('100%').padding({ left: 14, right: 14, top: 4, bottom: 4 })
          .backgroundColor(ThemeColor.get('card_bg')).borderRadius(14)

          // 团队与联系方式
          Column({ space: 0 }) {
            Text('团队与联系').fontSize(12).fontColor(ThemeColor.get('text_hint'))
              .width('100%').padding({ left: 4, bottom: 4 })
            this.infoRow('开发团队', '校园小助手团队')
            Divider().color(ThemeColor.get('divider')).margin({ left: 4, right: 4 })
            this.infoRow('联系邮箱', 'support@campus-assistant.cn')
            Divider().color(ThemeColor.get('divider')).margin({ left: 4, right: 4 })
            this.infoRow('反馈渠道', '设置 · 客服反馈')
            Divider().color(ThemeColor.get('divider')).margin({ left: 4, right: 4 })
            this.infoRow('服务时间', '工作日 9:00-18:00')
          }
          .width('100%').padding(14)
          .backgroundColor(ThemeColor.get('card_bg')).borderRadius(14)

          Text(`© 2026 校园小助手团队 · ${APP_VERSION}`)
            .fontSize(11).fontColor(ThemeColor.get('text_hint'))
            .width('100%').textAlign(TextAlign.Center).margin({ top: 6 })
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
