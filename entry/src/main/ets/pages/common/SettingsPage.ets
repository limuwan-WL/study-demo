import { promptAction } from '@kit.ArkUI'
import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import router from '@ohos.router'
import { ThemeColor } from '../../utils/ThemeColor'
import { Feedback } from '../../utils/Feedback'
import { formatSize } from '../../model/ResourceModel'

type SkinMode = 'light' | 'dark' | 'system'

@Entry
@Component
export struct SettingsPage {
  @StorageLink('isDark') isDark: boolean = false
  @StorageLink('skinMode') skinMode: string = 'light'
  @StorageLink('isLogged') isLogged: boolean = false
  @StorageLink('regAccount') regAccount: string = ''
  @StorageLink('boundPhone') boundPhone: string = ''
  // 🌟 推送分项开关：持久化，消息中心按类型分别生效
  @StorageLink('pushEnabled') pushEnabled: boolean = true
  @StorageLink('pushClass') pushClass: boolean = true
  @StorageLink('pushSignin') pushSignin: boolean = true
  @StorageLink('pushHomework') pushHomework: boolean = true
  @StorageLink('pushRecharge') pushRecharge: boolean = true
  @StorageLink('pushReport') pushReport: boolean = true
  @StorageLink('networkOnline') networkOnline: boolean = true
  @State cacheSize: string = '0 KB'

  aboutToAppear() {
    ThemeColor.isDark = this.isDark
    if (AppStorage.get<number>('colorModeSetting') === 1) {
      this.skinMode = 'dark'
    }
    this.cacheSize = this.dirSize((getContext(this) as common.UIAbilityContext).cacheDir)
  }

  // 🌟 真实计算缓存目录大小，清理时删除缓存文件（不动用户资料与笔记）
  dirSize(dir: string): string {
    let total = 0
    try {
      let names = fs.listFileSync(dir)
      names.forEach((n: string) => {
        try {
          total += fs.statSync(`${dir}/${n}`).size
        } catch (e) {
          // 跳过无法读取的条目
        }
      })
    } catch (e) {
      return '0 KB'
    }
    return formatSize(total)
  }

  clearCache() {
    Feedback.confirm('清理缓存', `将清除 ${this.cacheSize} 缓存数据，不影响笔记、资料与已上传资源。`, () => {
      let dir = (getContext(this) as common.UIAbilityContext).cacheDir
      try {
        fs.listFileSync(dir).forEach((n: string) => {
          try {
            fs.unlinkSync(`${dir}/${n}`)
          } catch (e) {
            // 单个文件删除失败不阻断
          }
        })
      } catch (e) {
        // 目录不可读时直接返回
      }
      this.cacheSize = this.dirSize(dir)
      Feedback.success('缓存已清理')
    }, '清理')
  }

  phoneLabel(): string {
    let phone = this.boundPhone
    if (phone === '') {
      phone = new RegExp('^1[3-9][0-9]{9}$').test(this.regAccount) ? this.regAccount : ''
    }
    if (phone === '') {
      return '未绑定'
    }
    return `${phone.slice(0, 3)}****${phone.slice(7)}`
  }

  openAccountPage(url: string) {
    if (!this.isLogged) {
      promptAction.showToast({ message: '请先登录后再操作' })
      return
    }
    router.pushUrl({ url: url })
  }

  // 🌟 主题切换：同步 AppStorage、ThemeColor 与应用级 colorMode，全局生效
  switchSkin(mode: SkinMode) {
    this.skinMode = mode
    if (mode === 'light') {
      this.isDark = false
    } else if (mode === 'dark') {
      this.isDark = true
    } else {
      this.isDark = this.getSystemDarkMode()
    }
    ThemeColor.isDark = this.isDark
    AppStorage.setOrCreate<number>('colorModeSetting', mode === 'dark' ? 1 : mode === 'light' ? 0 : -1)
    let app = (getContext(this) as common.UIAbilityContext).getApplicationContext()
    if (mode === 'dark') {
      app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
    } else if (mode === 'light') {
      app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
    } else {
      app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
    }
    const label = mode === 'light' ? '浅色' : mode === 'dark' ? '深色' : '跟随系统'
    promptAction.showToast({ message: `已切换至${label}模式` })
  }

  getSystemDarkMode(): boolean {
    try {
      let cfg = (getContext(this) as common.UIAbilityContext).resourceManager.getConfigurationSync()
      return (cfg.colorMode as number) === (ConfigurationConstant.ColorMode.COLOR_MODE_DARK as number)
    } catch (e) {
      return this.isDark
    }
  }

  @Builder
  skinChip(mode: SkinMode, label: string) {
    Text(label)
      .fontSize(13)
      .fontWeight(this.skinMode === mode ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.skinMode === mode ? Color.White : ThemeColor.get('text_sub'))
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .padding({ top: 10, bottom: 10 })
      .borderRadius(10)
      .backgroundColor(this.skinMode === mode ? ThemeColor.get('primary') : ThemeColor.get('field_bg'))
      .onClick(() => this.switchSkin(mode))
  }

  @Builder
  toggleRow(label: string, val: boolean, onToggle: (v: boolean) => void) {
    Row() {
      Text(label).fontSize(14).fontColor(ThemeColor.get('text_main')).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: val })
        .selectedColor(ThemeColor.get('primary'))
        .onChange((v: boolean) => onToggle(v))
    }.width('100%').padding({ left: 4, right: 4, top: 5, bottom: 5 })
  }

  @Builder
  arrowRow(label: string, value: string, onTap: () => void) {
    Row() {
      Text(label).fontSize(14).fontColor(ThemeColor.get('text_main')).layoutWeight(1)
      if (value) {
        Text(value).fontSize(12).fontColor(ThemeColor.get('text_sub'))
      }
      Text('›').fontSize(16).fontColor(ThemeColor.get('text_hint')).margin({ left: 6 })
    }
    .width('100%').padding({ left: 4, right: 4, top: 12, bottom: 12 })
    .onClick(() => onTap())
  }

  @Builder
  divider() {
    Divider().color(ThemeColor.get('divider')).margin({ left: 4, right: 4 })
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(22)
          .fontColor([ThemeColor.get('text_main')])
          .onClick(() => router.back())
        Text('设置').fontSize(20).fontWeight(FontWeight.Bold).fontColor(ThemeColor.get('text_main'))
      }
      .width('92%').padding({ top: 16, bottom: 10 })

      Scroll() {
        Column({ space: 16 }) {
          // 主题皮肤
          Column({ space: 10 }) {
            Text('主题皮肤').fontSize(12).fontColor(ThemeColor.get('text_hint')).width('100%')
            Row({ space: 8 }) {
              this.skinChip('light', '浅色')
              this.skinChip('dark', '深色')
              this.skinChip('system', '跟随系统')
            }.width('100%')
          }
          .width('92%').padding(14).backgroundColor(ThemeColor.get('card_bg')).borderRadius(14)

          // 消息与提醒（消息中心已合并到底部「消息」Tab，不再单独提供入口）
          Column({ space: 0 }) {
            Text('消息与提醒').fontSize(12).fontColor(ThemeColor.get('text_hint')).width('100%')
              .padding({ left: 4, bottom: 6 })
            this.toggleRow('推送通知', this.pushEnabled, (v: boolean): void => {
              this.pushEnabled = v
              Feedback.success(v ? '推送通知已开启' : '推送通知已关闭')
            })
            if (this.pushEnabled) {
              this.divider()
              this.toggleRow('上课提醒', this.pushClass, (v: boolean): void => {
                this.pushClass = v
                Feedback.success(v ? '已开启上课提醒' : '已关闭上课提醒')
              })
              this.divider()
              this.toggleRow('签到提醒', this.pushSignin, (v: boolean): void => {
                this.pushSignin = v
                Feedback.success(v ? '已开启签到提醒' : '已关闭签到提醒')
              })
              this.divider()
              this.toggleRow('作业批阅通知', this.pushHomework, (v: boolean): void => {
                this.pushHomework = v
                Feedback.success(v ? '已开启作业批阅通知' : '已关闭作业批阅通知')
              })
              this.divider()
              this.toggleRow('充值订单通知', this.pushRecharge, (v: boolean): void => {
                this.pushRecharge = v
                Feedback.success(v ? '已开启充值订单通知' : '已关闭充值订单通知')
              })
              this.divider()
              this.toggleRow('举报反馈通知', this.pushReport, (v: boolean): void => {
                this.pushReport = v
                Feedback.success(v ? '已开启举报反馈通知' : '已关闭举报反馈通知')
              })
            }
            this.divider()
            this.toggleRow('模拟弱网离线', !this.networkOnline, (v: boolean): void => {
              this.networkOnline = !v
              Feedback.info(v ? '已切换为弱网离线：笔记与表单将本地暂存' : '网络已恢复：待同步内容将自动上传')
            })
          }.width('92%').padding(14).backgroundColor(ThemeColor.get('card_bg')).borderRadius(14)

          // 存储
          Column({ space: 0 }) {
            Text('存储').fontSize(12).fontColor(ThemeColor.get('text_hint')).width('100%')
              .padding({ left: 4, bottom: 6 })
            this.arrowRow('清理缓存', this.cacheSize, (): void => this.clearCache())
            this.divider()
            this.arrowRow('资源与上传安全', '', (): void => {
              router.pushUrl({ url: 'pages/common/StorageAuditPage' })
            })
          }.width('92%').padding(14).backgroundColor(ThemeColor.get('card_bg')).borderRadius(14)

          // 账号与安全
          Column({ space: 0 }) {
            Text('账号与安全').fontSize(12).fontColor(ThemeColor.get('text_hint')).width('100%')
              .padding({ left: 4, bottom: 6 })
            this.arrowRow('修改登录密码', '', (): void => this.openAccountPage('pages/common/ChangePasswordPage'))
            this.divider()
            this.arrowRow('绑定手机号', this.phoneLabel(), (): void => this.openAccountPage('pages/common/ChangePhonePage'))
            this.divider()
            this.arrowRow('绑定第三方账号', '', (): void => this.openAccountPage('pages/common/ThirdPartyBindPage'))
            this.divider()
            this.arrowRow('隐私设置', '', (): void => this.openAccountPage('pages/common/PrivacySettingsPage'))
            this.divider()
            this.arrowRow('个人资料', '', (): void => this.openAccountPage('pages/common/ProfilePage'))
          }.width('92%').padding(14).backgroundColor(ThemeColor.get('card_bg')).borderRadius(14)

          // 关于与帮助
          Column({ space: 0 }) {
            this.arrowRow('关于我们', 'v1.0.0', (): void => {
              router.pushUrl({ url: 'pages/common/AboutPage' })
            })
            this.divider()
            this.arrowRow('客服反馈', '', (): void => {
              router.pushUrl({ url: 'pages/common/FeedbackPage' })
            })
          }.width('92%').padding(14).backgroundColor(ThemeColor.get('card_bg')).borderRadius(14)
        }.width('100%').padding({ bottom: 30 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(ThemeColor.get('page_bg'))
  }
}
