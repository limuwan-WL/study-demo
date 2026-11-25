import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { MessageCenter } from '../../model/MessageCenterModel';

// 🌟 输入阶段过滤：账号只允许汉字/数字，密码只允许字母/数字/下划线
const ACCOUNT_FILTER: string = '[0-9\\u4e00-\\u9fa5]'
const PASSWORD_FILTER: string = '[A-Za-z0-9_]'

// 🌟 启动登录/注册页：未登录时应用首页即是它；身份验证完成前不提供任何跳过入口
@Entry
@Component
struct LoginPage {
  @StorageLink('isLogged') isLogged: boolean = false
  @StorageLink('regAccount') regAccount: string = ''
  @StorageLink('regPassword') regPassword: string = ''
  // 🌟 记住我：勾选时下次自动填充账号密码，一键快速登录（状态持久化）
  @StorageLink('rememberMe') rememberMe: boolean = true
  // 🌟 用户身份：student 学生 / teacher 老师 / assistant 助教（全局持久化，各页面按角色差异化展示）
  @StorageLink('userRole') userRole: string = 'student'
  // 🌟 注册时与账号绑定的身份，登录时按绑定身份进入，避免串角色
  @StorageLink('regRole') regRole: string = ''
  @StorageLink('nickname') nickname: string = '张同学'
  @State mode: string = 'login' // login / register
  @State inputAccount: string = ''
  @State inputPassword: string = ''

  aboutToAppear() {
    // 🌟 记住我：已注册且勾选时自动填充，实现快速登录
    if (this.rememberMe && this.regAccount !== '') {
      this.inputAccount = this.regAccount
      this.inputPassword = this.regPassword
    }
  }

  // 🌟 输入框内容与保存的凭据一致 → 按钮变为「一键登录」
  isQuickLogin(): boolean {
    return this.rememberMe && this.mode === 'login' && this.regAccount !== ''
      && this.inputAccount.trim() === this.regAccount && this.inputPassword.trim() === this.regPassword
  }

  // 🌟 账号规则：只能是中文汉字姓名，或 11 位手机号
  isValidAccount(acc: string): boolean {
    let chinese = new RegExp('^[\\u4e00-\\u9fa5]{1,20}$')
    let phone = new RegExp('^1[3-9][0-9]{9}$')
    return chinese.test(acc) || phone.test(acc)
  }

  // 🌟 密码规则：至少 8 位，只能由字母、数字、下划线组成
  isValidPassword(pwd: string): boolean {
    let rule = new RegExp('^[A-Za-z0-9_]{8,}$')
    return rule.test(pwd)
  }

  // 🌟 身份验证未完成前不允许离开：返回键 / 侧滑只给提示，不落到主界面
  onBackPress(): boolean {
    promptAction.showToast({ message: '请先完成登录或注册后进入' })
    return true
  }

  // 🌟 登录/注册成功后：页面栈只有本页（启动登录页场景）→ 替换进主页；从其他页面进来 → 返回原页
  // 注意：getLength() 返回 string（栈内页面数）；不能用 getState().index 判断，栈底页时它可能不为 0，会误走 back() 退回桌面
  enterMain() {
    if (!this.isLogged) {
      return
    }
    if (parseInt(router.getLength()) > 1) {
      router.back()
    } else {
      router.replaceUrl({ url: 'pages/Index' })
    }
  }

  // 注册：本机只保存一个账号（演示用），成功后自动登录并进入主页
  register() {
    let acc = this.inputAccount.trim()
    let pwd = this.inputPassword.trim()
    if (acc === '' || pwd === '') {
      promptAction.showToast({ message: '账号和密码不能为空' })
      return
    }
    if (!this.isValidAccount(acc)) {
      promptAction.showToast({ message: '账号仅支持中文姓名或 11 位手机号' })
      return
    }
    if (!this.isValidPassword(pwd)) {
      promptAction.showToast({ message: '密码至少 8 位，仅可包含字母、数字、下划线' })
      return
    }
    if (this.regAccount !== '') {
      promptAction.showToast({ message: `本机已注册过 ${this.regAccount}，请直接登录` })
      return
    }
    this.regAccount = acc
    this.regPassword = pwd
    this.regRole = this.userRole
    // 🌟 登录名即昵称：注册成功后昵称直接使用注册账号，并随昵称一起持久化
    this.nickname = acc
    this.isLogged = true
    // 🌟 进入当前身份的消息作用域：教师/学生各自一份，互不可见
    MessageCenter.activateScope()
    MessageCenter.ensureSeed()
    promptAction.showToast({ message: `注册成功，已以${this.roleLabel(this.userRole)}身份登录` })
    this.enterMain()
  }

  roleLabel(r: string): string {
    if (r === 'teacher') {
      return '老师'
    }
    if (r === 'assistant') {
      return '助教'
    }
    return '学生'
  }

  login() {
    let acc = this.inputAccount.trim()
    let pwd = this.inputPassword.trim()
    if (acc === '' || pwd === '') {
      promptAction.showToast({ message: '账号和密码不能为空' })
      return
    }
    if (!this.isValidAccount(acc)) {
      promptAction.showToast({ message: '账号仅支持中文姓名或 11 位手机号' })
      return
    }
    if (!this.isValidPassword(pwd)) {
      promptAction.showToast({ message: '密码至少 8 位，仅可包含字母、数字、下划线' })
      return
    }
    if (this.regAccount === '' || acc !== this.regAccount || pwd !== this.regPassword) {
      promptAction.showToast({ message: '账号不存在或密码错误' })
      return
    }
    // 🌟 一个账号只绑定一种身份：选错身份不允许登录，避免同一账号师生身份混用
    if (this.regRole !== '' && this.userRole !== this.regRole) {
      promptAction.showToast({
        message: `该账号为${this.roleLabel(this.regRole)}身份，请切换对应身份后登录`
      })
      return
    }
    // 🌟 按注册时绑定的身份进入，未绑定过则按当前选择
    this.userRole = this.regRole === '' ? this.userRole : this.regRole
    // 🌟 登录名即昵称：登录后用已注册账号作为昵称（历史数据兜底到本次输入账号）
    this.nickname = this.regAccount !== '' ? this.regAccount : acc
    this.isLogged = true
    // 🌟 进入当前身份的消息作用域：教师/学生各自一份，互不可见
    MessageCenter.activateScope()
    MessageCenter.ensureSeed()
    promptAction.showToast({ message: '登录成功' })
    this.enterMain()
  }

  // 登录 / 注册 顶部 Tab（带下划线指示条）
  @Builder
  modeTab(key: string, label: string) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(17)
        .fontWeight(this.mode === key ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.mode === key ? $r('app.color.primary') : $r('app.color.text_sub'))
      Text('')
        .width(28).height(4).borderRadius(2)
        .backgroundColor(this.mode === key ? $r('app.color.primary') : Color.Transparent)
    }
    .onClick(() => {
      this.mode = key
    })
  }

  // 身份选择胶囊（学生 / 老师）
  @Builder
  roleTab(key: string, label: string) {
    Text(label)
      .fontSize(14)
      .fontWeight(this.userRole === key ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.userRole === key ? $r('app.color.primary') : $r('app.color.text_sub'))
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .padding({ top: 9, bottom: 9 })
      .backgroundColor(this.userRole === key ? $r('app.color.primary_weak') : $r('app.color.field_bg'))
      .borderRadius(12)
      .border({ width: 1, color: this.userRole === key ? $r('app.color.primary') : Color.Transparent })
      .onClick(() => {
        this.userRole = key
      })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 蓝色渐变背景
      Column()
        .width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [['#4C8BF5', 0], ['#3F7EF6', 0.55], ['#2E63D9', 1]] })

      Column() {
        // 顶部：不再提供「跳过」入口，仅提示需完成身份验证
        Row() {
          Blank()
          Text('登录后即可使用全部功能')
            .fontSize(12).fontColor('rgba(255,255,255,0.75)')
        }
        .width('100%').padding({ left: 24, right: 24, top: 16 })

        // 品牌区
        Column({ space: 12 }) {
          Text('🎓')
            .fontSize(38)
            .width(76).height(76)
            .textAlign(TextAlign.Center)
            .backgroundColor('rgba(255,255,255,0.25)')
            .borderRadius(24)
          Text('校园小助手').fontSize(26).fontWeight(FontWeight.Bold).fontColor(Color.White)
          Text('记录学习与生活的好帮手').fontSize(13).fontColor('rgba(255,255,255,0.78)')
        }
        .width('100%')
        .margin({ top: 28 })

        Blank()

        // 登录/注册卡片
        Column({ space: 16 }) {
          Row({ space: 36 }) {
            this.modeTab('login', '登录')
            this.modeTab('register', '注册')
          }.justifyContent(FlexAlign.Center).width('100%')

          // 🌟 身份选择：学生 / 老师 / 助教，进入后页面内容按角色差异化
          Row({ space: 10 }) {
            this.roleTab('student', '🎓 学生')
            this.roleTab('teacher', '👨‍🏫 老师')
            this.roleTab('assistant', '🧑‍💼 助教')
          }.width('100%')

          Row({ space: 10 }) {
            SymbolGlyph($r('sys.symbol.person')).fontSize(18).fontColor([$r('app.color.text_hint')])
            TextInput({ text: this.inputAccount, placeholder: '中文姓名或手机号' })
              .backgroundColor(Color.Transparent).height(44).fontSize(15)
              .inputFilter(ACCOUNT_FILTER)
              .onChange((v: string) => this.inputAccount = v).layoutWeight(1)
          }
          .width('100%').height(50).padding({ left: 14, right: 14 })
          .backgroundColor($r('app.color.field_bg')).borderRadius(14)

          Row({ space: 10 }) {
            SymbolGlyph($r('sys.symbol.lock')).fontSize(18).fontColor([$r('app.color.text_hint')])
            TextInput({ text: this.inputPassword, placeholder: '至少 8 位字母/数字/下划线' }).type(InputType.Password)
              .backgroundColor(Color.Transparent).height(44).fontSize(15)
              .inputFilter(PASSWORD_FILTER)
              .onChange((v: string) => this.inputPassword = v).layoutWeight(1)
          }
          .width('100%').height(50).padding({ left: 14, right: 14 })
          .backgroundColor($r('app.color.field_bg')).borderRadius(14)

          // 🌟 记住我单选框：勾选后注册/登录的账号密码会被记住，下次自动填充快速登录
          Row({ space: 8 }) {
            SymbolGlyph(this.rememberMe ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
              .fontSize(18)
              .fontColor([this.rememberMe ? '#3F7EF6' : '#B0B5C0'])
            Text('记住我，下次快速登录').fontSize(13).fontColor($r('app.color.text_label'))
          }
          .onClick(() => {
            this.rememberMe = !this.rememberMe
          })
          .margin({ top: -4 })

          Text(this.mode === 'login' ? (this.isQuickLogin() ? '一键登录' : '登  录') : '注  册')
            .fontSize(16).fontWeight(FontWeight.Medium).fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .width('100%').height(48).borderRadius(24)
            .linearGradient({ angle: 90, colors: [['#4C8BF5', 0], ['#3F7EF6', 1]] })
            .shadow({ radius: 10, color: 'rgba(63,126,246,0.4)', offsetY: 5 })
            .margin({ top: 4 })
            .onClick(() => {
              if (this.mode === 'login') {
                this.login()
              } else {
                this.register()
              }
            })

          Text('本机注册一个账号即可使用，数据保存在本地')
            .fontSize(11).fontColor($r('app.color.text_hint'))
        }
        .width('88%')
        .padding(24)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(24)
        .margin({ bottom: 56 })
        .shadow({ radius: 24, color: 'rgba(23,58,120,0.28)', offsetY: 10 })
      }
      .width('100%').height('100%')
    }
    .width('100%').height('100%')
  }
}
