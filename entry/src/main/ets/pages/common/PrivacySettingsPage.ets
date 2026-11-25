import router from '@ohos.router'
import { Feedback } from '../../utils/Feedback'

// ==================== 隐私设置 ====================
// 🌟 控制个人主页、笔记、关注列表与课程学习数据的可见范围
@Entry
@Component
export struct PrivacySettingsPage {
  @StorageLink('privacyShowProfile') showProfile: boolean = true
  @StorageLink('privacyShowNotes') showNotes: boolean = true
  @StorageLink('privacyShowFollow') showFollow: boolean = false
  @StorageLink('privacyAnonymous') anonymous: boolean = false
  @StorageLink('privacyCourseData') courseData: boolean = true

  @Builder
  toggleRow(title: string, desc: string, value: boolean, onChange: (v: boolean) => void) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(title).fontSize(14).fontColor($r('app.color.text_main'))
        Text(desc).fontSize(10).fontColor($r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor($r('app.color.primary'))
        .onChange((v: boolean) => onChange(v))
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 11, bottom: 11 })
  }

  @Builder
  divider() {
    Divider().color($r('app.color.divider_color')).margin({ left: 14, right: 14 })
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(22)
          .fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Text('隐私设置').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      }
      .width('92%')
      .padding({ top: 16, bottom: 12 })

      Scroll() {
        Column({ space: 14 }) {
          Column() {
            this.toggleRow('公开个人主页', '允许其他用户查看昵称、简介与身份标签', this.showProfile, (v: boolean) => {
              this.showProfile = v
              Feedback.success(v ? '个人主页已公开' : '个人主页已隐藏')
            })
            this.divider()
            this.toggleRow('公开我的笔记', '关闭后仅自己可见，即使笔记设为公开', this.showNotes, (v: boolean) => {
              this.showNotes = v
              Feedback.success(v ? '公开笔记已允许展示' : '公开笔记已隐藏')
            })
            this.divider()
            this.toggleRow('公开关注列表', '允许其他用户查看你关注的人', this.showFollow, (v: boolean) => {
              this.showFollow = v
              Feedback.success(v ? '关注列表已公开' : '关注列表已隐藏')
            })
          }
          .width('100%')
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(18)

          Column() {
            this.toggleRow('匿名参与互动', '签到、问卷、抽选中隐藏真实姓名', this.anonymous, (v: boolean) => {
              this.anonymous = v
              Feedback.success(v ? '已开启匿名互动' : '已关闭匿名互动')
            })
            this.divider()
            this.toggleRow('课程内展示学习数据', '关闭后教师名册中不展示你的课时与打卡数据', this.courseData, (v: boolean) => {
              this.courseData = v
              Feedback.success(v ? '课程内数据已展示' : '课程内数据已隐藏')
            })
          }
          .width('100%')
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(18)

          Text('隐私设置仅影响本机演示数据，当前工程未接入真实服务端。')
            .fontSize(10).fontColor($r('app.color.text_hint'))
            .width('100%').padding({ left: 4 })
        }
        .width('92%')
        .padding({ bottom: 30 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
