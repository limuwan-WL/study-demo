import { promptAction } from '@kit.ArkUI';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import router from '@ohos.router';
import { TodoItem, ScheduleItem, NoteItem, FavItem } from '../../model/DataModel';
import { CHAT_THEMES, ChatThemeStyle, chatThemeByKey } from '../../model/ChatTheme';
import { LANGUAGES, LangOption, LEVEL_NAMES, LEVEL_COLORS } from '../../model/CourseModel';
import { expLevelOf } from '../../model/GrowthModel';
import { Permission } from '../../model/PermissionModel';
import { AvatarOption, AVATAR_LIST, findAvatar } from '../../model/AvatarModel';
import { UploadPolicy } from '../../utils/UploadPolicy';

@CustomDialog
struct NicknameDialog {
  controller: CustomDialogController
  @State inputText: string = ''
  onClose: () => void = () => {}
  onConfirm: (text: string) => void = () => {}

  aboutToDisappear(): void {
    this.onClose()
  }

  build() {
    Column({ space: 16 }) {
      Text('修改昵称').fontSize(18).fontWeight(FontWeight.Bold)
      TextInput({ text: this.inputText, placeholder: '请输入新昵称' })
        .onChange((v: string) => this.inputText = v).backgroundColor($r('app.color.field_bg'))
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).backgroundColor($r('app.color.btn_cancel')).onClick(() => this.controller.close())
        Button('保存').layoutWeight(1).onClick(() => {
          if (this.inputText.trim() === '') {
            promptAction.showToast({ message: '昵称不能为空' })
            return
          }
          this.onConfirm(this.inputText.trim())
          this.controller.close()
        })
      }.width('100%')
    }.padding(20).backgroundColor($r('app.color.card_bg')).borderRadius(16)
  }
}

// 🌟 预置头像已抽到 model/AvatarModel，个人资料页与我的页共用同一份配置

// 🌟 头像选择弹窗：预置符号头像，点击即更换并持久化
@CustomDialog
struct AvatarDialog {
  controller: CustomDialogController
  @State current: string = ''
  onClose: () => void = () => {}
  onPick: (key: string) => void = () => {}
  onAlbum: () => void = () => {}

  aboutToDisappear(): void {
    this.onClose()
  }

  build() {
    Column({ space: 16 }) {
      Text('选择头像').fontSize(18).fontWeight(FontWeight.Bold)
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(AVATAR_LIST, (opt: AvatarOption) => {
          Row() {
            SymbolGlyph(opt.icon).fontSize(26).fontColor([Color.White])
          }
          .width(56).height(56)
          .backgroundColor(opt.color)
          .borderRadius(28)
          .border({ width: 3, color: this.current === opt.key ? '#3F7EF6' : Color.Transparent })
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .margin(6)
          .onClick(() => {
            this.onPick(opt.key)
            this.controller.close()
          })
        }, (opt: AvatarOption) => opt.key)
      }.width('100%')
      // 🌟 自定义头像：从系统相册选择图片
      Row({ space: 6 }) {
        Text('📷').fontSize(16)
        Text('从相册选择').fontSize(14).fontColor($r('app.color.primary'))
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 10, bottom: 10 })
      .backgroundColor($r('app.color.field_bg'))
      .borderRadius(18)
      .onClick(() => {
        this.onAlbum()
        this.controller.close()
      })
    }.padding(20).backgroundColor($r('app.color.card_bg')).borderRadius(16)
  }
}

// 🌟 聊天主题选择弹窗：每个主题带迷你气泡预览，点击即切换（浅色预览，实际随深浅色模式联动）
// 注意：选择通过 onPick 回调传回主页面写入状态——@CustomDialog 内直接写 @StorageLink 不会同步回 AppStorage
@CustomDialog
struct ThemeDialog {
  controller: CustomDialogController
  @State cur: string = 'default'
  onClose: () => void = () => {}
  onPick: (key: string) => void = () => {}

  aboutToAppear(): void {
    const saved = AppStorage.get<string>('chatTheme')
    this.cur = saved !== undefined ? saved : 'default'
  }

  aboutToDisappear(): void {
    this.onClose()
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text('聊天主题').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          .margin({ bottom: 4 })
        ForEach(CHAT_THEMES, (t: ChatThemeStyle) => {
          Row({ space: 12 }) {
            // 迷你聊天预览
            Column({ space: 6 }) {
              Row() {
                Text('你好！').fontSize(9).fontColor(t.otherTextLight)
                  .backgroundColor(t.otherBubbleLight)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .borderRadius(8)
              }.width('100%').justifyContent(FlexAlign.Start)
              Row() {
                Text('嗨～').fontSize(9).fontColor(t.myTextLight)
                  .backgroundColor(t.myBubbleLight)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .borderRadius(8)
              }.width('100%').justifyContent(FlexAlign.End)
            }
            .width(96)
            .padding(8)
            .backgroundColor(t.gradBottomLight)
            .borderRadius(10)

            Column({ space: 4 }) {
              Text(t.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
              Text(t.desc).fontSize(11).fontColor($r('app.color.text_hint'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            if (this.cur === t.key) {
              SymbolGlyph($r('sys.symbol.checkmark_circle')).fontSize(18).fontColor([$r('app.color.primary')])
            }
          }
          .width('100%')
          .padding(12)
          .backgroundColor($r('app.color.field_bg'))
          .borderRadius(14)
          .border({ width: this.cur === t.key ? 1.5 : 0, color: $r('app.color.primary') })
          .onClick(() => {
            this.cur = t.key
            this.onPick(t.key)
            promptAction.showToast({ message: `已切换主题：${t.name}` })
            this.controller.close()
          })
        }, (t: ChatThemeStyle) => `${t.key}_${this.cur === t.key ? 1 : 0}`)
      }
      .padding(20)
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(16)
    }
    .width(320)
    .constraintSize({ maxHeight: 520 })
    .scrollBar(BarState.Off)
  }
}

// 🌟 学习语言选择弹窗：韩语 / 英语 / 日语 / 汉语，切换后课程页内容实时联动（课程页与我的页共用）
@CustomDialog
export struct LanguageDialog {
  controller: CustomDialogController
  @State cur: string = 'en'
  onClose: () => void = () => {}
  onPick: (key: string) => void = () => {}

  aboutToAppear(): void {
    const saved = AppStorage.get<string>('languageSetting')
    this.cur = saved !== undefined ? saved : 'en'
  }

  aboutToDisappear(): void {
    this.onClose()
  }

  build() {
    Column({ space: 12 }) {
      Text('学习语言').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        .margin({ bottom: 4 })
      ForEach(LANGUAGES, (l: LangOption) => {
        Row({ space: 12 }) {
          Text(l.tag)
            .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .width(44).height(44).borderRadius(22)
            .backgroundColor(l.color)
            .textAlign(TextAlign.Center)
          Column({ space: 3 }) {
            Text(l.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
            Text(l.sample).fontSize(12).fontColor($r('app.color.text_hint'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          if (this.cur === l.key) {
            SymbolGlyph($r('sys.symbol.checkmark_circle')).fontSize(18).fontColor([$r('app.color.primary')])
          }
        }
        .width('100%')
        .padding(12)
        .backgroundColor($r('app.color.field_bg'))
        .borderRadius(14)
        .border({ width: this.cur === l.key ? 1.5 : 0, color: $r('app.color.primary') })
        .onClick(() => {
          this.cur = l.key
          this.onPick(l.key)
          promptAction.showToast({ message: `已切换学习语言：${l.name}` })
          this.controller.close()
        })
      }, (l: LangOption) => `${l.key}_${this.cur === l.key ? 1 : 0}`)
    }
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
  }
}

@Component
export struct MinePage {
  // 🌟 注册登录（本地模拟）：账号密码持久化，重启不丢失
  @StorageLink('isLogged') isLogged: boolean = false
  @StorageLink('regAccount') regAccount: string = ''
  @StorageLink('avatarEmoji') avatarEmoji: string = ''
  // 🌟 自定义头像：相册图片拷贝到沙箱后的本地路径（持久化，优先于符号头像）
  @StorageLink('avatarUri') avatarUri: string = ''
  // 深浅色模式：0 浅色 / 1 深色
  @StorageLink('colorModeSetting') colorModeSetting: number = 0
  // 🌟 聊天主题
  @StorageLink('chatTheme') chatTheme: string = 'default'
  @State themeDialogVisible: boolean = false
  themeDialogController: CustomDialogController = new CustomDialogController({
    builder: ThemeDialog({}),
    customStyle: true
  })

  // 🌟 成长体系：等级统一由经验值驱动（每日登录/聊天/课程/练习/打卡获得）
  @StorageLink('userExp') userExp: number = 0
  // 🌟 硬币余额：随成长事件获得，用于购买学科课程
  @StorageLink('coins') coins: number = 0

  // 🌟 昵称兜底：登录名取不到时用通用称谓，避免出现空白
  displayName(): string {
    return this.nickname !== '' ? this.nickname : '学习者'
  }

  expLv(): number {
    return expLevelOf(this.userExp)
  }

  idLabel(): string {
    return this.studentId !== '' ? this.studentId : (Permission.isStudent() ? '未填写学号' : '未填写工号')
  }

  bioLabel(): string {
    return this.userBio !== '' ? this.userBio : '点击完善个人资料'
  }

  openThemeDialog() {
    if (this.themeDialogVisible) {
      return
    }
    this.themeDialogVisible = true
    this.themeDialogController = new CustomDialogController({
      builder: ThemeDialog({
        onClose: () => {
          this.themeDialogVisible = false
        },
        onPick: (key: string) => {
          this.chatTheme = key
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.themeDialogController.open()
  }
  @StorageLink('nickname') nickname: string = '张同学'
  // 🌟 用户身份：学生 / 老师 / 助教 / 管理员（登录页选择，页面按角色隔离入口）
  @StorageLink('userRole') userRole: string = 'student'
  // 🌟 个人资料：学号（教师为工号）与个人简介
  @StorageLink('studentId') studentId: string = ''
  @StorageLink('userBio') userBio: string = ''
  // 🌟 消息已合并到底部「消息」Tab，本页不再展示消息中心入口与未读数
  @StorageLink('todoList') todoList: TodoItem[] = []
  @StorageLink('scheduleList') scheduleList: ScheduleItem[] = []
  @StorageLink('noteList') noteList: NoteItem[] = []
  @StorageLink('favList') favList: FavItem[] = []

  @State dialogVisible: boolean = false
  dialogController: CustomDialogController = new CustomDialogController({
    builder: NicknameDialog({}),
    customStyle: true
  })

  openNickDialog() {
    if (this.dialogVisible) {
      return
    }
    this.dialogVisible = true
    this.dialogController = new CustomDialogController({
      builder: NicknameDialog({
        inputText: this.nickname,
        onClose: () => {
          this.dialogVisible = false
        },
        onConfirm: (t: string) => {
          this.nickname = t
          promptAction.showToast({ message: '昵称已更新' })
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.dialogController.open()
  }

  // 🌟 当前头像的名称（用于设置行展示；未设置或旧数据无效时显示空）
  avatarName(): string {
    let opt = findAvatar(this.avatarEmoji)
    return opt === undefined ? '' : opt.key
  }

  openAvatarDialog() {
    if (this.dialogVisible) {
      return
    }
    this.dialogVisible = true
    this.dialogController = new CustomDialogController({
      builder: AvatarDialog({
        current: this.avatarEmoji,
        onClose: () => {
          this.dialogVisible = false
        },
        onPick: (e: string) => {
          this.avatarEmoji = e
          this.avatarUri = ''
          promptAction.showToast({ message: '头像已更新' })
        },
        onAlbum: () => {
          // 等弹窗关闭动画结束后再拉起系统相册
          setTimeout(() => {
            this.pickAvatarFromAlbum()
          }, 200)
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.dialogController.open()
  }

  // 🌟 从系统相册选择头像：拷到应用沙箱，避免选择器临时 URI 失效
  async pickAvatarFromAlbum() {
    try {
      let options = new photoAccessHelper.PhotoSelectOptions()
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      options.maxSelectNumber = 1
      let result = await new photoAccessHelper.PhotoViewPicker().select(options)
      if (result.photoUris.length === 0) {
        return
      }
      let ctx = getContext(this) as common.UIAbilityContext
      let dest = `${ctx.filesDir}/avatar_${Date.now()}.jpg`
      // 🌟 头像同样走统一上传策略：大小上限 + 自动压缩 + 内容审核
      let up = await UploadPolicy.prepareImage(result.photoUris[0], dest, `头像_${Date.now()}.jpg`)
      if (!up.ok) {
        promptAction.showToast({ message: `头像未更新：${up.reason}` })
        return
      }
      let old = this.avatarUri
      this.avatarUri = up.uri
      if (old !== '' && old.indexOf(ctx.filesDir) === 0) {
        try {
          fs.unlinkSync(old)
        } catch (e) {
          // 旧头像文件删除失败不影响新头像使用
        }
      }
      promptAction.showToast({ message: '头像已更新' })
    } catch (err) {
      promptAction.showToast({ message: '未能读取所选图片，请重试' })
    }
  }

  logout() {
    this.isLogged = false
    promptAction.showToast({ message: '已退出登录' })
    // 🌟 退出后必须重新验证身份：替换掉主页，避免返回键落回未登录的主界面
    router.replaceUrl({ url: 'pages/common/LoginPage' })
  }

  // 🌟 深浅色模式切换：写入应用颜色模式（配合 dark 资源目录自动换肤），并持久化选择
  toggleColorMode() {
    this.colorModeSetting = this.colorModeSetting === 1 ? 0 : 1
    let dark = this.colorModeSetting === 1
    let ctx = getContext(this) as common.UIAbilityContext
    ctx.getApplicationContext().setColorMode(dark ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
    promptAction.showToast({ message: dark ? '已切换为深色模式' : '已切换为浅色模式' })
  }

  // 🌟 清空本地数据（含二次确认），清空后各页面展示空状态
  clearAllData() {
    AppStorage.setOrCreate('todoList', [])
    AppStorage.setOrCreate('scheduleList', [])
    AppStorage.setOrCreate('noteList', [])
    // 笔记模块：笔记本分类 / 模拟云端快照 / 离线开关一并清空
    AppStorage.setOrCreate('notebookList', [])
    AppStorage.setOrCreate('noteCloud', {})
    AppStorage.setOrCreate('noteCloudTime', {})
    AppStorage.setOrCreate('noteOffline', false)
    AppStorage.setOrCreate('favList', [])
    AppStorage.setOrCreate('postList', [])
    AppStorage.setOrCreate('messageList', [])
    AppStorage.setOrCreate('nickname', '')
    AppStorage.setOrCreate('avatarEmoji', '')
    AppStorage.setOrCreate('avatarUri', '')
    AppStorage.setOrCreate('isLogged', false)
    AppStorage.setOrCreate('regAccount', '')
    AppStorage.setOrCreate('regPassword', '')
    AppStorage.setOrCreate('followList', [])
    AppStorage.setOrCreate('friendList', [])
    AppStorage.setOrCreate('readPostIds', [])
    AppStorage.setOrCreate('chatTheme', 'default')
    AppStorage.setOrCreate('chatBgOpacity', 100)
    // 🌟 课程模块：清空学习进度、单词、学习日志、打卡与成就
    AppStorage.setOrCreate('languageSetting', 'en')
    AppStorage.setOrCreate('courseProgress', {})
    AppStorage.setOrCreate('wordKnown', [])
    AppStorage.setOrCreate('studyLog', {})
    AppStorage.setOrCreate('studyLogBySubject', {})
    AppStorage.setOrCreate('checkinList', [])
    AppStorage.setOrCreate('achievementList', [])
    AppStorage.setOrCreate('quizPerfect', false)
    AppStorage.setOrCreate('listenPerfect', false)
    // 🌟 身份 + 班级模块：作业、提交、班级群、练习轮换一并清空
    AppStorage.setOrCreate('userRole', 'student')
    AppStorage.setOrCreate('regRole', '')
    AppStorage.setOrCreate('hwList', [])
    AppStorage.setOrCreate('hwSubs', [])
    AppStorage.setOrCreate('classGroupMsgs', [])
    AppStorage.setOrCreate('classGroupNick', '')
    AppStorage.setOrCreate('classGroupNotice', '')
    AppStorage.setOrCreate('classGroupQuit', false)
    AppStorage.setOrCreate('classGroupSeeded', false)
    AppStorage.setOrCreate('practiceSeen', {})
    AppStorage.setOrCreate('practiceCursor', {})
    AppStorage.setOrCreate('t_viewedProgress', false)
    // 新增功能数据清空
    AppStorage.setOrCreate('followItems', [])
    AppStorage.setOrCreate('followSeeded', false)
    AppStorage.setOrCreate('taskList', [])
    AppStorage.setOrCreate('interactionTasks', [])
    AppStorage.setOrCreate('pointRules', {})
    AppStorage.setOrCreate('practiceQuestions', [])
    AppStorage.setOrCreate('pointRecords', [])
    AppStorage.setOrCreate('pointEnabled', true)
    AppStorage.setOrCreate('pointsTotal', 0)
    // 🌟 全局模块：个人资料、课程成员、助教、题库、资源、消息中心与隐私设置
    AppStorage.setOrCreate('studentId', '')
    AppStorage.setOrCreate('userBio', '')
    AppStorage.setOrCreate('boundPhone', '')
    AppStorage.setOrCreate('thirdPartyBinds', [])
    AppStorage.setOrCreate('enrolledCourses', [])
    AppStorage.setOrCreate('enrollmentSeeded', false)
    AppStorage.setOrCreate('assistantList', [])
    AppStorage.setOrCreate('questionBank', [])
    AppStorage.setOrCreate('questionBankSeeded', false)
    AppStorage.setOrCreate('resourceList', [])
    AppStorage.setOrCreate('resourceSeeded', false)
    AppStorage.setOrCreate('messageCenterSeeded', false)
    AppStorage.setOrCreate('messageSeededScope', '')
    AppStorage.setOrCreate('messageStore', {})
    AppStorage.setOrCreate('messageScope', '')
    AppStorage.setOrCreate('networkOnline', true)
    AppStorage.setOrCreate('privacyShowProfile', true)
    AppStorage.setOrCreate('privacyShowNotes', true)
    AppStorage.setOrCreate('privacyShowFollow', false)
    AppStorage.setOrCreate('privacyAnonymous', false)
    AppStorage.setOrCreate('privacyCourseData', true)
    AppStorage.setOrCreate('pushEnabled', true)
    AppStorage.setOrCreate('pushClass', true)
    AppStorage.setOrCreate('pushSignin', true)
    AppStorage.setOrCreate('pushHomework', true)
    AppStorage.setOrCreate('pushRecharge', true)
    AppStorage.setOrCreate('pushReport', true)
    AppStorage.setOrCreate('surveyQuestions', [])
    AppStorage.setOrCreate('isDark', false)
    AppStorage.setOrCreate('skinMode', 'light')
    // 🌟 补清模块状态：金币、讲师评价、班级群、课表与演示退出标记，避免清空后残留旧数据
    AppStorage.setOrCreate('coins', 0)
    AppStorage.setOrCreate('coinRecords', [])
    AppStorage.setOrCreate('coinOrders', [])
    AppStorage.setOrCreate('coinFreeClaims', {})
    AppStorage.setOrCreate('taskReminderIds', {})
    AppStorage.setOrCreate('userExp', 0)
    AppStorage.setOrCreate('teacherReviews', [])
    AppStorage.setOrCreate('chatGroups', [])
    AppStorage.setOrCreate('groupMembersMap', {})
    AppStorage.setOrCreate('groupNotices', [])
    AppStorage.setOrCreate('groupFiles', [])
    AppStorage.setOrCreate('groupReports', [])
    AppStorage.setOrCreate('groupMsgsMap', {})
    AppStorage.setOrCreate('groupChatArchive', {})
    AppStorage.setOrCreate('groupUnreadMap', {})
    AppStorage.setOrCreate('groupMuteMap', {})
    AppStorage.setOrCreate('groupSeeded', false)
    AppStorage.setOrCreate('assistantCanCreate', false)
    AppStorage.setOrCreate('fileRetentionDays', 30)
    AppStorage.setOrCreate('courseQuit', false)
    AppStorage.setOrCreate('courseTable', [])
    // 🌟 重置自动生成标记，下次以学生身份进入时重新生成默认课表
    AppStorage.setOrCreate('courseTableAutoSeeded', false)
    AppStorage.setOrCreate('timetableCloud', {})
    AppStorage.setOrCreate('timetableCloudTime', {})
    // 🌟 清空后登录态已失效：直接回到身份验证页，不允许停在未验证的主界面
    router.replaceUrl({ url: 'pages/common/LoginPage' })
    promptAction.showToast({ message: '本地数据已清空' })
  }

  confirmClear() {
    AlertDialog.show({
      title: '清空本地数据',
      message: '将删除全部待办、日程、笔记、收藏、帖子和消息，且无法恢复。确定继续吗？',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '清空',
        fontColor: '#EF4444',
        action: () => {
          this.clearAllData()
        }
      }
    })
  }

  // 🌟 统计数字在 @Builder 内部直接读取列表（不能用按值传参，否则不随数据刷新）
  @Builder
  statItem(type: string, label: string) {
    Column({ space: 4 }) {
      if (type === 'todo') {
        Text(`${this.todoList.length}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#3F7EF6')
      } else if (type === 'schedule') {
        Text(`${this.scheduleList.length}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#55C873')
      } else if (type === 'note') {
        Text(`${this.noteList.length}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#E8A33E')
      } else {
        Text(`${this.favList.length}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#E74846')
      }
      Text(label).fontSize(12).fontColor($r('app.color.text_sub'))
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    // 🌟 点击统计项快捷跳转到对应功能页
    .onClick(() => {
      let url = type === 'todo' ? 'pages/study/TodoPage'
        : type === 'schedule' ? 'pages/study/SchedulePage'
          : type === 'note' ? 'pages/study/NotePage' : 'pages/study/FavoritesPage'
      router.pushUrl({ url: url })
    })
  }

  @Builder
  settingRow(title: string, value: string, valueColor: ResourceColor, onTap: () => void) {
    Row() {
      Text(title).fontSize(15).fontColor($r('app.color.text_main'))
      Blank()
      if (value !== '') {
        Text(value).fontSize(14).fontColor(valueColor)
      }
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.text_sub')]).margin({ left: 4 })
    }
    .width('100%').height(56).padding({ left: 20, right: 20 })
    .onClick(() => onTap())
  }

  // 🌟 未登录时的个人卡片：头像 + 未登录昵称 + 「登录 / 注册」按钮，点击按钮进入登录注册页
  @Builder
  profileCard() {
    Row() {
      // 头像占位
      Row() {
        SymbolGlyph($r('sys.symbol.person')).fontSize(36).fontColor([Color.White])
      }
      .width(64).height(64)
      .linearGradient({ angle: 135, colors: [['#4C8BF5', 0], ['#3F7EF6', 1]] })
      .borderRadius(32)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .margin({ right: 16 })

      Column({ space: 6 }) {
        Text('未登录')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Text('登录后可同步待办、日程与笔记')
          .fontSize(13).fontColor($r('app.color.text_sub'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 登录 / 注册按钮
      Text('登录 / 注册')
        .fontSize(13).fontWeight(FontWeight.Medium).fontColor(Color.White)
        .padding({ left: 14, right: 14, top: 9, bottom: 9 })
        .linearGradient({ angle: 90, colors: [['#4C8BF5', 0], ['#3F7EF6', 1]] })
        .borderRadius(18)
        .shadow({ radius: 6, color: 'rgba(63,126,246,0.35)', offsetY: 3 })
        .onClick(() => router.replaceUrl({ url: 'pages/common/LoginPage' }))
    }
    .width('90%')
    .padding(24)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(20)
    .margin({ top: 10, bottom: 16 })
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 5 })
  }

  build() {
    Scroll() {
      Column() {
      // 页面标题：与首页 / 消息页保持一致的头部节奏
      Row() {
        Column({ space: 3 }) {
          Text('我的')
            .fontSize(26).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Text(this.isLogged ? `${Permission.roleLabel()} · 个人资料与学习空间` : '个人资料与学习空间')
            .fontSize(11).fontColor($r('app.color.text_hint'))
        }.alignItems(HorizontalAlign.Start)
      }
      .width('90%')
      .padding({ top: 24, bottom: 4 })

      if (!this.isLogged) {
        this.profileCard()
      } else {
        // 顶部：头像（可点击更换）+ 昵称（登录名，可修改）
        Row() {
          if (this.avatarUri !== '') {
            // 🌟 自定义头像：圆形裁切、等比填充
            Image('file://' + this.avatarUri)
              .width(64).height(64)
              .borderRadius(32)
              .objectFit(ImageFit.Cover)
              .margin({ right: 16 })
              .onClick(() => this.openAvatarDialog())
          } else if (this.avatarEmoji !== '' && findAvatar(this.avatarEmoji) !== undefined) {
            // 🌟 符号头像：图标 + 专属底色
            Row() {
              SymbolGlyph(findAvatar(this.avatarEmoji)!.icon).fontSize(30).fontColor([Color.White])
            }
            .width(64).height(64)
            .backgroundColor(findAvatar(this.avatarEmoji)!.color)
            .borderRadius(32)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 16 })
            .onClick(() => this.openAvatarDialog())
          } else {
            Row() {
              SymbolGlyph($r('sys.symbol.person'))
                .fontSize(36)
                .fontColor([Color.White])
            }
            .width(64)
            .height(64)
            .backgroundColor($r('app.color.primary'))
            .borderRadius(32)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 16 })
            .onClick(() => this.openAvatarDialog())
          }

          Column({ space: 6 }) {
            Row({ space: 8 }) {
              Text(this.displayName())
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_main'))
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              // 🌟 身份标签：学生 / 授课教师 / 助教 / 后台管理员，不同角色隔离入口
              Text(Permission.roleShortLabel())
                .fontSize(10).fontWeight(FontWeight.Medium).fontColor(Color.White)
                .backgroundColor(Permission.roleColor())
                .borderRadius(6)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              // 🌟 我的等级徽章：统一经验等级，点击进入「等级与权益」
              Text(`LV${this.expLv() + 1}`)
                .fontSize(11).fontWeight(FontWeight.Bold).fontColor(Color.White)
                .backgroundColor(LEVEL_COLORS[this.expLv()])
                .borderRadius(4)
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                .onClick(() => {
                  router.pushUrl({ url: 'pages/course/LevelPage' })
                })
              Blank()
              SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14)
                .fontColor([$r('app.color.text_hint')])
            }
            .width('100%')

            // 🌟 学号 / 工号 + 个人简介：点击整张卡片进入个人资料页
            Text(`${Permission.isStudent() ? '学号' : '工号'}：${this.idLabel()}`)
              .fontSize(12).fontColor($r('app.color.text_sub'))
            Text(this.bioLabel())
              .fontSize(11).fontColor($r('app.color.text_hint'))
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })

            // 🌟 金币余额：学生专属，用于点赞 / 投币赞赏（不可购买课程）
            if (Permission.isStudent()) {
              Row({ space: 6 }) {
                Text('币')
                  .fontSize(10).fontWeight(FontWeight.Bold).fontColor(Color.White)
                  .width(16).height(16).borderRadius(8)
                  .backgroundColor('#E8B93E').textAlign(TextAlign.Center)
                Text(`${this.coins} 金币`)
                  .fontSize(12).fontWeight(FontWeight.Medium).fontColor('#E8A33E')
                Text('· 点赞投币 · 每日登录 / 学习 / 打卡可赚取')
                  .fontSize(10).fontColor($r('app.color.text_hint'))
              }.alignItems(VerticalAlign.Center)
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('90%')
        .padding(24)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(20)
        .margin({ top: 10, bottom: 16 })
        .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 5 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/common/ProfilePage' })
        })
      }

      // 数据统计卡片（与首页四卡片呼应，自动同步）
      Row() {
        this.statItem('todo', '待办')
        Divider().vertical(true).height(30).color($r('app.color.divider_color'))
        this.statItem('schedule', '日程')
        Divider().vertical(true).height(30).color($r('app.color.divider_color'))
        this.statItem('note', '笔记')
        Divider().vertical(true).height(30).color($r('app.color.divider_color'))
        this.statItem('fav', '收藏')
      }
      .width('90%')
      .height(80)
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(20)
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ bottom: 16 })
      .shadow({ radius: 10, color: 'rgba(0,0,0,0.02)', offsetY: 4 })

      // 🌟 账号与工具：设置 + 个人资料
      //    消息中心已合并到底部「消息」Tab，不再单独提供入口
      Column({ space: 0 }) {
        this.settingRow('设置', '', $r('app.color.text_sub'), (): void => {
          router.pushUrl({ url: 'pages/common/SettingsPage' })
        })
        Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
        this.settingRow('个人资料', '', $r('app.color.text_sub'), (): void => {
          router.pushUrl({ url: 'pages/common/ProfilePage' })
        })
      }
      .width('90%')
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(20)
      .margin({ bottom: 16 })

      // 🌟 角色专属入口：学生 / 教师 / 助教看到的入口完全隔离
      Column({ space: 0 }) {
        Row({ space: 6 }) {
          Text(Permission.isStudent() ? '学习空间' : Permission.isAssistant() ? '助教工作台' : '教学管理')
            .fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_sub'))
          Text(Permission.roleShortLabel()).fontSize(9).fontColor(Color.White)
            .backgroundColor(Permission.roleColor())
            .padding({ left: 5, right: 5, top: 1, bottom: 1 }).borderRadius(4)
          Blank()
        }
        .width('100%').padding({ left: 20, right: 20, top: 14, bottom: 4 })

        if (Permission.canSeeStudentEntries()) {
          this.settingRow('我的金币', `${this.coins} 金币`, '#E8A33E', (): void => {
            router.pushUrl({ url: 'pages/study/CoinPage' })
          })
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
          this.settingRow('我的笔记', `${this.noteList.length} 条`, $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/study/NotePage' })
          })
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
          this.settingRow('我的课程', '', $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/course/MyCoursesPage' })
          })
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
          this.settingRow('我的学分', '', $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/study/PointsPage' })
          })
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
          this.settingRow('关注列表', '', $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/social/FollowPage' })
          })
        }

        if (Permission.canSeeTeacherEntries()) {
          this.settingRow('我教授的课程', `${Permission.myTeachingCourses().length} 门`, $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/course/MyCoursesPage' })
          })
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
          this.settingRow('我的题库', '', $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/course/QuestionBankPage' })
          })
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
          this.settingRow('互动任务管理', '', $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/study/TaskPage' })
          })
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
          this.settingRow('课堂台账', '', $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/study/DataViewPage' })
          })
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
          this.settingRow('学分总览', '', $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/study/PointsPage' })
          })
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
          this.settingRow('讲师主页管理', '', $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/course/TeacherPage', params: { teacherId: AppStorage.get<string>('myTeacherId') ?? '' } })
          })
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
          this.settingRow('助教管理', '', $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/course/AssistantManagePage' })
          })
        }

        if (Permission.canSeeAssistantEntries()) {
          this.settingRow('发布签到任务', '', $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/study/SigninPage', params: { assistant: '1' } })
          })
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
          this.settingRow('作业批阅', '', $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/course/HomeworkPage' })
          })
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
          this.settingRow('群公告维护', '', $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/course/ClassGroupPage' })
          })
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
          this.settingRow('各类台账', '', $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/study/DataViewPage' })
          })
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
          this.settingRow('互动任务', '', $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/study/TaskPage' })
          })
        }
      }
      .width('90%')
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(20)
      .margin({ bottom: 16 })

      // 通用学习入口：学生看到作答类入口，教师/助教看到教学台账入口（角色隔离）
      Column({ space: 0 }) {
        if (Permission.canSeeStudentEntries()) {
          this.settingRow('随堂练习', '', $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/study/PracticePage' })
          })
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
          // 学生也可进入：有进行中的任务时直接签到 / 作答，无任务时展示空状态
          this.settingRow('课堂签到', '', $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/study/SigninPage' })
          })
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
          this.settingRow('调查问卷', '', $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/study/SurveyPage' })
          })
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
        } else if (Permission.isAssistant()) {
          this.settingRow('互动任务与台账', '', $r('app.color.text_sub'), (): void => {
            router.pushUrl({ url: 'pages/study/DataViewPage' })
          })
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
        }
        this.settingRow('资源安全', '', $r('app.color.text_sub'), (): void => {
          router.pushUrl({ url: 'pages/common/StorageAuditPage' })
        })
      }
      .width('90%')
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(20)
      .margin({ bottom: 16 })

      // 功能列表（昵称 / 头像在名片与「个人资料」页维护，此处不再重复提供入口）
      Column() {
        this.settingRow('清空本地数据', '清空', $r('app.color.danger'), (): void => this.confirmClear())

        Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })

        this.settingRow('深色模式', this.colorModeSetting === 1 ? '深色' : '浅色', $r('app.color.text_sub'), (): void => this.toggleColorMode())
        // 🌟 聊天主题：一键切换聊天气泡、文字、字体效果、背景
        this.settingRow('聊天主题', chatThemeByKey(this.chatTheme).name, $r('app.color.text_sub'), (): void => this.openThemeDialog())

        Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })

        // 🌟 学习语言设置已移除：语言切换统一在底部「课程」页顶部的「当前学习」处

        // 🌟 等级与权益：查看当前经验等级、升级条件与各等级特权
        this.settingRow('等级与权益', `LV${this.expLv() + 1} ${LEVEL_NAMES[this.expLv()]}`, $r('app.color.text_sub'), (): void => {
          router.pushUrl({ url: 'pages/course/LevelPage' })
        })

        Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })

        this.settingRow('关于我们', 'v1.0.0', $r('app.color.text_sub'), (): void => {
          AlertDialog.show({
            title: '关于我们',
            message: '校园小助手 v1.0.0\n一款记录学习与生活的好帮手：待办、日程、笔记、收藏、社区一站搞定。',
            autoCancel: true,
            alignment: DialogAlignment.Center,
            primaryButton: {
              value: '知道了',
              action: () => {
              }
            }
          })
        })

        if (this.isLogged) {
          Divider().color($r('app.color.divider_color')).margin({ left: 20, right: 20 })
          this.settingRow('退出登录', '', $r('app.color.danger'), (): void => this.logout())
        }
      }
      .width('90%')
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(20)
      .shadow({ radius: 10, color: 'rgba(0,0,0,0.02)', offsetY: 4 })

      Blank()
      }
      .width('100%')
      .backgroundColor($r('app.color.page_bg'))
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }
}
