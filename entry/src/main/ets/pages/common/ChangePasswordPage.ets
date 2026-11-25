import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import { ThemeColor } from '../../utils/ThemeColor'

// 🌟 密码输入过滤：与登录页保持一致，只允许字母/数字/下划线
const PASSWORD_FILTER: string = '[A-Za-z0-9_]'

@Entry
@Component
export struct ChangePasswordPage {
  @StorageLink('isLogged') isLogged: boolean = false
  @StorageLink('regAccount') regAccount: string = ''
  @StorageLink('regPassword') regPassword: string = ''
  @State oldPassword: string = ''
  @State newPassword: string = ''
  @State confirmPassword: string = ''
  @State errorMsg: string = ''

  aboutToAppear() {
    ThemeColor.isDark = AppStorage.get<boolean>('isDark') ?? false
  }

  // 密码强度：0 弱 / 1 中 / 2 强 / -1 未输入
  strengthOf(pwd: string): number {
    if (pwd.length === 0) {
      return -1
    }
    let hasLetter: boolean = new RegExp('[A-Za-z]').test(pwd)
    let hasDigit: boolean = new RegExp('[0-9]').test(pwd)
    if (pwd.length < 8 || !hasLetter || !hasDigit) {
      return 0
    }
    return pwd.length >= 12 ? 2 : 1
  }

  strengthLabel(): string {
    let s = this.strengthOf(this.newPassword)
    if (s < 0) {
      return '请输入新密码'
    }
    return s === 0 ? '强度：弱' : s === 1 ? '强度：中' : '强度：强'
  }

  strengthColor(): string {
    let s = this.strengthOf(this.newPassword)
    if (s <= 0) {
      return ThemeColor.get('danger')
    }
    return s === 1 ? ThemeColor.get('warning') : ThemeColor.get('success')
  }

  barFilled(index: number): boolean {
    return index <= this.strengthOf(this.newPassword)
  }

  // 逐项校验，返回错误提示（空串表示通过）
  validate(): string {
    let oldPwd = this.oldPassword
    let newPwd = this.newPassword
    let confirm = this.confirmPassword
    if (oldPwd === '') {
      return '请输入旧密码'
    }
    if (oldPwd !== this.regPassword) {
      return '旧密码不正确'
    }
    if (newPwd === '') {
      return '请输入新密码'
    }
    if (newPwd.length < 8 || newPwd.length > 20) {
      return '新密码长度需为 8-20 位'
    }
    if (!new RegExp('^[A-Za-z0-9_]+$').test(newPwd)) {
      return '新密码仅可包含字母、数字、下划线'
    }
    if (newPwd === oldPwd) {
      return '新密码不能与旧密码相同'
    }
    if (this.strengthOf(newPwd) === 0) {
      return '密码强度不足，请同时包含字母和数字'
    }
    if (confirm === '') {
      return '请再次输入新密码'
    }
    if (confirm !== newPwd) {
      return '两次输入的新密码不一致'
    }
    return ''
  }

  submit() {
    if (!this.isLogged) {
      promptAction.showToast({ message: '请先登录后再修改密码' })
      return
    }
    if (this.regPassword === '') {
      promptAction.showToast({ message: '当前账号尚未设置本地密码' })
      return
    }
    let err = this.validate()
    this.errorMsg = err
    if (err !== '') {
      promptAction.showToast({ message: err })
      return
    }
    // 🌟 修改成功：直接更新注册密码，PersistentStorage 已持久化该字段，重启不丢失
    this.regPassword = this.newPassword
    promptAction.showToast({ message: '密码修改成功' })
    router.back()
  }

  @Builder
  header() {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(24)
        .fontColor([ThemeColor.get('text_main')])
        .onClick(() => router.back())
      Text('修改密码').fontSize(20).fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get('text_main')).margin({ left: 12 })
    }
    .width('100%').height(56).padding({ left: 16 })
  }

  @Builder
  passwordField(label: string, placeholder: string, value: string, onChange: (v: string) => void) {
    Column({ space: 8 }) {
      Text(label).fontSize(12).fontColor(ThemeColor.get('text_sub')).width('100%')
      TextInput({ text: value, placeholder: placeholder })
        .type(InputType.Password)
        .height(46).width('100%').fontSize(15)
        .backgroundColor(ThemeColor.get('field_bg'))
        .borderRadius(10)
        .inputFilter(PASSWORD_FILTER)
        .onChange((v: string) => onChange(v))
    }.width('100%')
  }

  @Builder
  strengthBar() {
    Column({ space: 6 }) {
      // 🌟 直接写三段进度条（不用 ForEach：key 固定时 ForEach 不会因强度变化重建子组件）
      Row({ space: 6 }) {
        Row()
          .height(4).layoutWeight(1).borderRadius(2)
          .backgroundColor(this.barFilled(0) ? this.strengthColor() : ThemeColor.get('field_bg'))
        Row()
          .height(4).layoutWeight(1).borderRadius(2)
          .backgroundColor(this.barFilled(1) ? this.strengthColor() : ThemeColor.get('field_bg'))
        Row()
          .height(4).layoutWeight(1).borderRadius(2)
          .backgroundColor(this.barFilled(2) ? this.strengthColor() : ThemeColor.get('field_bg'))
      }.width('100%')
      Text(this.strengthLabel()).fontSize(11).fontColor(this.strengthColor())
    }.width('100%')
  }

  build() {
    Column() {
      this.header()

      Scroll() {
        Column({ space: 14 }) {
          // 当前账号
          Row() {
            Text('当前账号').fontSize(13).fontColor(ThemeColor.get('text_sub')).layoutWeight(1)
            Text(this.regAccount === '' ? '未登录' : this.regAccount)
              .fontSize(13).fontColor(ThemeColor.get('text_main')).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%').padding(14)
          .backgroundColor(ThemeColor.get('card_bg')).borderRadius(12)

          if (this.regPassword === '') {
            Row({ space: 8 }) {
              Text('!').fontSize(12).fontWeight(FontWeight.Bold).fontColor(Color.White)
                .width(18).height(18).borderRadius(9)
                .backgroundColor(ThemeColor.get('warning')).textAlign(TextAlign.Center)
              Text('当前账号尚未设置本地密码，请先在登录页完成注册')
                .fontSize(12).fontColor(ThemeColor.get('text_sub')).layoutWeight(1)
            }
            .width('100%').padding(12)
            .backgroundColor(ThemeColor.get('card_bg')).borderRadius(12)
          }

          // 输入区
          Column({ space: 16 }) {
            this.passwordField('旧密码', '请输入当前登录密码', this.oldPassword, (v: string): void => {
              this.oldPassword = v
              this.errorMsg = ''
            })
            this.passwordField('新密码', '8-20 位，需包含字母和数字', this.newPassword, (v: string): void => {
              this.newPassword = v
              this.errorMsg = ''
            })
            this.strengthBar()
            this.passwordField('确认新密码', '请再次输入新密码', this.confirmPassword, (v: string): void => {
              this.confirmPassword = v
              this.errorMsg = ''
            })
          }
          .width('100%').padding(16)
          .backgroundColor(ThemeColor.get('card_bg')).borderRadius(14)

          if (this.errorMsg !== '') {
            Text(this.errorMsg).fontSize(12).fontColor(ThemeColor.get('danger'))
              .width('100%').padding({ left: 4 })
          }

          Button('确认修改')
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
            .width('100%').height(46).borderRadius(23)
            .backgroundColor(ThemeColor.get('primary'))
            .onClick(() => this.submit())

          Text('密码修改后立即生效，请使用新密码重新登录其他设备')
            .fontSize(11).fontColor(ThemeColor.get('text_hint'))
            .width('100%').textAlign(TextAlign.Center)
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
