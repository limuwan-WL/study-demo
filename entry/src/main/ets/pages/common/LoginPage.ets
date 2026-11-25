import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { MessageCenter } from '../../model/MessageCenterModel';
import { AccountStore, AuthResult } from '../../model/AccountStore';

// 🌟 输入阶段过滤：学号/教工号只允许字母和数字，密码只允许字母/数字/下划线
const ACCOUNT_FILTER: string = '[A-Za-z0-9]'
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
  @State submitting: boolean = false

  aboutToAppear() {
    // 🌟 账号数据库初始化（幂等）：学号 / 教工号与密码哈希保存在本地 SQLite 表 user_account
    AccountStore.init(getContext(this) as common.UIAbilityContext)
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

  // 🌟 账号规则：学生为学号（6-20 位数字），教师/助教为教工号（4-20 位字母或数字）
  isValidAccount(acc: string): boolean {
    if (this.userRole === 'student') {
      return new RegExp('^[0-9]{6,20}$').test(acc)
    }
    return new RegExp('^[A-Za-z0-9]{4,20}$').test(acc)
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

  // 注册：学号 / 教工号写入本地数据库表 user_account，成功后自动登录并进入主页
  async register(): Promise<void> {
    if (this.submitting) {
      return
    }
    let acc = this.inputAccount.trim()
    let pwd = this.inputPassword.trim()
    if (acc === '' || pwd === '') {
      promptAction.showToast({ message: '学号/教工号和密码不能为空' })
      return
    }
    if (!this.isValidAccount(acc)) {
      promptAction.showToast({
        message: this.userRole === 'student' ? '学号为 6-20 位数字' : '教工号为 4-20 位字母或数字'
      })
      return
    }
    if (!this.isValidPassword(pwd)) {
      promptAction.showToast({ message: '密码至少 8 位，仅可包含字母、数字、下划线' })
      return
    }
    this.submitting = true
    let res: AuthResult = await AccountStore.register(acc, pwd, this.userRole, acc)
    this.submitting = false
    if (!res.ok) {
      promptAction.showToast({ message: res.message })
      return
    }
    // 🌟 登录名即学号/教工号：注册成功后作为昵称，并保持全局状态同步
    this.regAccount = acc
    this.regPassword = pwd
    this.regRole = this.userRole
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

  async login(): Promise<void> {
    if (this.submitting) {
      return
    }
    let acc = this.inputAccount.trim()
    let pwd = this.inputPassword.trim()
    if (acc === '' || pwd === '') {
      promptAction.showToast({ message: '学号/教工号和密码不能为空' })
      return
    }
    if (!this.isValidAccount(acc)) {
      promptAction.showToast({
        message: this.userRole === 'student' ? '学号为 6-20 位数字' : '教工号为 4-20 位字母或数字'
      })
      return
    }
    if (!this.isValidPassword(pwd)) {
      promptAction.showToast({ message: '密码至少 8 位，仅可包含字母、数字、下划线' })
      return
    }
    this.submitting = true
    let res: AuthResult = await AccountStore.login(acc, pwd)
    // 🌟 老版本单账号数据迁移：库里没有但与本机记住的账号密码一致时，补登记后继续登录
    if (!res.ok && res.code === 'not_found' && this.regAccount === acc && this.regPassword === pwd) {
      res = await AccountStore.register(acc, pwd, this.regRole === '' ? this.userRole : this.regRole, acc)
    }
    this.submitting = false
    if (!res.ok) {
      promptAction.showToast({ message: res.message })
      return
    }
    // 🌟 一个账号只绑定一种身份：选错身份不允许登录，避免同一账号师生身份混用
    if (res.account !== null && res.account.role !== this.userRole) {
      promptAction.showToast({
        message: `该账号为${this.roleLabel(res.account.role)}身份，请切换对应身份后登录`
      })
      return
    }
    // 🌟 按数据库中绑定的身份进入
    let role: string = res.account !== null ? res.account.role : this.userRole
    this.userRole = role
    this.regAccount = acc
    this.regPassword = pwd
    this.regRole = role
    // 🌟 登录名即昵称：昵称优先取库里的昵称，历史数据兜底到本次输入账号
    let nick: string = res.account !== null ? res.account.nickname : ''
    this.nickname = nick !== '' ? nick : acc
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
            TextInput({ text: this.inputAccount, placeholder: '学号 / 教工号' })
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

          Text('学号 / 教工号保存在本地数据库，可注册多个账号')
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
