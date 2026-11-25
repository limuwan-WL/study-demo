import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import { ThemeColor } from '../../utils/ThemeColor'

// 🌟 验证码有效期：5 分钟；重发间隔：60 秒
const CODE_TTL: number = 5 * 60 * 1000
const RESEND_SECONDS: number = 60

@Entry
@Component
export struct ChangePhonePage {
  @StorageLink('isLogged') isLogged: boolean = false
  @StorageLink('regAccount') regAccount: string = ''
  @StorageLink('boundPhone') boundPhone: string = ''
  @State inputPhone: string = ''
  @State inputCode: string = ''
  @State countdown: number = 0
  @State codeHint: string = ''
  @State errorMsg: string = ''
  // 本地模拟验证码（不发起真实短信请求）
  private mockCode: string = ''
  private codeExpireAt: number = 0
  private timerId: number = -1

  aboutToAppear() {
    ThemeColor.isDark = AppStorage.get<boolean>('isDark') ?? false
  }

  aboutToDisappear() {
    this.stopTimer()
  }

  stopTimer() {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  isValidPhone(phone: string): boolean {
    return new RegExp('^1[3-9][0-9]{9}$').test(phone)
  }

  // 当前绑定号码：优先取绑定字段，未绑定过时回退到手机号形式的登录账号
  currentPhone(): string {
    if (this.boundPhone !== '') {
      return this.boundPhone
    }
    return this.isValidPhone(this.regAccount) ? this.regAccount : ''
  }

  maskPhone(phone: string): string {
    if (phone.length !== 11) {
      return phone
    }
    return `${phone.slice(0, 3)}****${phone.slice(7)}`
  }

  currentPhoneText(): string {
    let p = this.currentPhone()
    return p === '' ? '未绑定手机号' : this.maskPhone(p)
  }

  sendCode() {
    if (!this.isLogged) {
      promptAction.showToast({ message: '请先登录后再修改手机号' })
      return
    }
    if (this.countdown > 0) {
      return
    }
    if (!this.isValidPhone(this.inputPhone)) {
      this.errorMsg = '请输入正确的 11 位手机号'
      promptAction.showToast({ message: this.errorMsg })
      return
    }
    if (this.inputPhone === this.currentPhone()) {
      this.errorMsg = '新手机号不能与当前手机号相同'
      promptAction.showToast({ message: this.errorMsg })
      return
    }
    this.errorMsg = ''
    // 🌟 本地模拟验证码：随机 6 位数字，仅用于演示，不会真实发送短信
    this.mockCode = `${Math.floor(100000 + Math.random() * 900000)}`
    this.codeExpireAt = Date.now() + CODE_TTL
    this.codeHint = `模拟验证码：${this.mockCode}（本地生成，未真实发送短信，5 分钟内有效）`
    this.countdown = RESEND_SECONDS
    this.stopTimer()
    this.timerId = setInterval(() => {
      if (this.countdown <= 1) {
        this.countdown = 0
        this.stopTimer()
      } else {
        this.countdown -= 1
      }
    }, 1000)
    promptAction.showToast({ message: '验证码已生成，请查看页面提示' })
  }

  submit() {
    if (!this.isLogged) {
      promptAction.showToast({ message: '请先登录后再修改手机号' })
      return
    }
    if (!this.isValidPhone(this.inputPhone)) {
      this.errorMsg = '请输入正确的 11 位手机号'
      promptAction.showToast({ message: this.errorMsg })
      return
    }
    if (this.inputPhone === this.currentPhone()) {
      this.errorMsg = '新手机号不能与当前手机号相同'
      promptAction.showToast({ message: this.errorMsg })
      return
    }
    if (this.mockCode === '') {
      this.errorMsg = '请先获取验证码'
      promptAction.showToast({ message: this.errorMsg })
      return
    }
    if (Date.now() > this.codeExpireAt) {
      this.errorMsg = '验证码已过期，请重新获取'
      promptAction.showToast({ message: this.errorMsg })
      return
    }
    if (this.inputCode === '') {
      this.errorMsg = '请输入验证码'
      promptAction.showToast({ message: this.errorMsg })
      return
    }
    if (this.inputCode !== this.mockCode) {
      this.errorMsg = '验证码不正确'
      promptAction.showToast({ message: this.errorMsg })
      return
    }
    this.errorMsg = ''
    this.stopTimer()
    // 🌟 更新绑定号码：@StorageLink 已持久化到 PersistentStorage
    this.boundPhone = this.inputPhone
    promptAction.showToast({ message: '手机号修改成功' })
    router.back()
  }

  @Builder
  header() {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(24)
        .fontColor([ThemeColor.get('text_main')])
        .onClick(() => router.back())
      Text('修改手机号').fontSize(20).fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get('text_main')).margin({ left: 12 })
    }
    .width('100%').height(56).padding({ left: 16 })
  }

  build() {
    Column() {
      this.header()

      Scroll() {
        Column({ space: 14 }) {
          // 当前绑定号码
          Row() {
            Column({ space: 4 }) {
              Text('当前绑定手机号').fontSize(12).fontColor(ThemeColor.get('text_sub'))
              Text(this.currentPhoneText()).fontSize(18).fontWeight(FontWeight.Bold)
                .fontColor(ThemeColor.get('text_main'))
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('已绑定')
              .fontSize(11).fontColor(ThemeColor.get('success'))
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .borderRadius(10)
              .backgroundColor(ThemeColor.get('primary_weak'))
              .visibility(this.currentPhone() === '' ? Visibility.None : Visibility.Visible)
          }
          .width('100%').padding(16)
          .backgroundColor(ThemeColor.get('card_bg')).borderRadius(12)

          // 新号码 + 验证码
          Column({ space: 14 }) {
            Column({ space: 8 }) {
              Text('新手机号').fontSize(12).fontColor(ThemeColor.get('text_sub')).width('100%')
              TextInput({ text: this.inputPhone, placeholder: '请输入 11 位手机号' })
                .type(InputType.PhoneNumber)
                .maxLength(11)
                .inputFilter('[0-9]')
                .height(46).width('100%').fontSize(15)
                .backgroundColor(ThemeColor.get('field_bg')).borderRadius(10)
                .onChange((v: string) => {
                  this.inputPhone = v
                  this.errorMsg = ''
                  // 号码变了，之前生成的验证码作废
                  if (this.mockCode !== '') {
                    this.mockCode = ''
                    this.codeExpireAt = 0
                    this.codeHint = ''
                    this.inputCode = ''
                    this.countdown = 0
                    this.stopTimer()
                  }
                })
            }.width('100%')

            Row({ space: 10 }) {
              TextInput({ text: this.inputCode, placeholder: '请输入 6 位验证码' })
                .type(InputType.Number)
                .maxLength(6)
                .inputFilter('[0-9]')
                .height(46).layoutWeight(1).fontSize(15)
                .backgroundColor(ThemeColor.get('field_bg')).borderRadius(10)
                .onChange((v: string) => {
                  this.inputCode = v
                  this.errorMsg = ''
                })
              Text(this.countdown > 0 ? `${this.countdown}s 后重发` : '获取验证码')
                .fontSize(13)
                .fontColor(this.countdown > 0 ? ThemeColor.get('text_hint') : ThemeColor.get('primary'))
                .textAlign(TextAlign.Center)
                .width(112).height(46).borderRadius(10)
                .backgroundColor(ThemeColor.get('primary_weak'))
                .onClick(() => this.sendCode())
            }.width('100%')
          }
          .width('100%').padding(16)
          .backgroundColor(ThemeColor.get('card_bg')).borderRadius(14)

          if (this.codeHint !== '') {
            Row({ space: 8 }) {
              Text('i').fontSize(11).fontWeight(FontWeight.Bold).fontColor(Color.White)
                .width(18).height(18).borderRadius(9)
                .backgroundColor(ThemeColor.get('primary')).textAlign(TextAlign.Center)
              Text(this.codeHint).fontSize(12).fontColor(ThemeColor.get('text_sub')).layoutWeight(1)
            }
            .width('100%').padding(12)
            .backgroundColor(ThemeColor.get('card_bg')).borderRadius(12)
          }

          if (this.errorMsg !== '') {
            Text(this.errorMsg).fontSize(12).fontColor(ThemeColor.get('danger'))
              .width('100%').padding({ left: 4 })
          }

          Button('确认修改')
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
            .width('100%').height(46).borderRadius(23)
            .backgroundColor(ThemeColor.get('primary'))
            .onClick(() => this.submit())

          Text('当前为本地模拟验证码，不会真实发送短信；绑定结果仅保存在本机')
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
