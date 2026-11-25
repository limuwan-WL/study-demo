import { common } from '@kit.AbilityKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import router from '@ohos.router'
import { Permission } from '../../model/PermissionModel'
import { AvatarOption, AVATAR_LIST, findAvatar } from '../../model/AvatarModel'
import { Feedback } from '../../utils/Feedback'
import { UploadPolicy } from '../../utils/UploadPolicy'

// 🌟 资料字段编辑弹窗（昵称 / 学号 / 简介共用）
@CustomDialog
struct FieldEditDialog {
  controller: CustomDialogController
  title: string = ''
  placeholder: string = ''
  value: string = ''
  multiline: boolean = false
  maxLength: number = 40
  @State text: string = ''
  onSave: (v: string) => void = () => {
  }

  aboutToAppear(): void {
    this.text = this.value
  }

  aboutToDisappear(): void {
  }

  build() {
    Column({ space: 14 }) {
      Text(this.title).fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      if (this.multiline) {
        TextArea({ text: this.text, placeholder: this.placeholder })
          .height(100).fontSize(13)
          .backgroundColor($r('app.color.field_bg')).borderRadius(12).padding(10)
          .maxLength(this.maxLength)
          .onChange((v: string) => {
            this.text = v
          })
      } else {
        TextInput({ text: this.text, placeholder: this.placeholder })
          .height(44).fontSize(14)
          .backgroundColor($r('app.color.field_bg')).borderRadius(12)
          .maxLength(this.maxLength)
          .onChange((v: string) => {
            this.text = v
          })
      }
      Row({ space: 10 }) {
        Text('取消').fontSize(14).fontColor($r('app.color.text_sub'))
          .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 10, bottom: 10 })
          .onClick(() => this.controller.close())
        Text('保存').fontSize(14).fontWeight(FontWeight.Medium).fontColor(Color.White)
          .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 10, bottom: 10 })
          .backgroundColor($r('app.color.primary')).borderRadius(20)
          .onClick(() => {
            this.onSave(this.text.trim())
            this.controller.close()
          })
      }.width('100%')
    }
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
  }
}

// 🌟 预置头像选择（个人资料页内使用）
@CustomDialog
struct AvatarPickDialog {
  controller: CustomDialogController
  current: string = ''
  onClose: () => void = () => {
  }
  onPick: (key: string) => void = () => {
  }
  onAlbum: () => void = () => {
  }

  aboutToDisappear(): void {
    this.onClose()
  }

  build() {
    Column({ space: 14 }) {
      Text('选择头像').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(AVATAR_LIST, (opt: AvatarOption) => {
          Row() {
            SymbolGlyph(opt.icon).fontSize(24).fontColor([Color.White])
          }
          .width(50).height(50)
          .backgroundColor(opt.color)
          .borderRadius(25)
          .border({ width: 3, color: this.current === opt.key ? '#3F7EF6' : Color.Transparent })
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .margin(5)
          .onClick(() => {
            this.onPick(opt.key)
            this.controller.close()
          })
        }, (opt: AvatarOption) => opt.key)
      }.width('100%')
      Text('从相册选择')
        .fontSize(13).fontColor($r('app.color.primary'))
        .width('100%').textAlign(TextAlign.Center)
        .padding({ top: 10, bottom: 10 })
        .backgroundColor($r('app.color.field_bg')).borderRadius(14)
        .onClick(() => {
          this.onAlbum()
          this.controller.close()
        })
    }
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
  }
}

// ==================== 个人资料 ====================
// 🌟 头像 / 昵称 / 学号（教师为工号）/ 个人简介 + 身份标签 + 账号安全入口
@Entry
@Component
export struct ProfilePage {
  @StorageLink('nickname') nickname: string = ''
  @StorageLink('avatarEmoji') avatarEmoji: string = ''
  @StorageLink('avatarUri') avatarUri: string = ''
  @StorageLink('studentId') studentId: string = ''
  @StorageLink('userBio') userBio: string = ''
  @StorageLink('userRole') userRole: string = 'student'
  @StorageLink('boundPhone') boundPhone: string = ''
  @StorageLink('regAccount') regAccount: string = ''
  @State fieldTitle: string = ''
  @State fieldPlaceholder: string = ''
  @State fieldValue: string = ''
  @State fieldMultiline: boolean = false
  @State avatarDialogVisible: boolean = false
  fieldController: CustomDialogController = new CustomDialogController({
    builder: FieldEditDialog({}),
    customStyle: true
  })
  avatarController: CustomDialogController = new CustomDialogController({
    builder: AvatarPickDialog({}),
    customStyle: true
  })

  nameLabel(): string {
    return Permission.isStudent() ? '学号' : '工号'
  }

  displayName(): string {
    return this.nickname !== '' ? this.nickname : '未设置昵称'
  }

  idLabel(): string {
    return this.studentId !== '' ? this.studentId : '未填写'
  }

  bioLabel(): string {
    return this.userBio !== '' ? this.userBio : '还没有填写个人简介'
  }

  avatarIcon(): Resource {
    let opt = findAvatar(this.avatarEmoji)
    return opt === undefined ? $r('sys.symbol.face_smiling') : opt.icon
  }

  avatarColor(): string {
    let opt = findAvatar(this.avatarEmoji)
    return opt === undefined ? '#3F7EF6' : opt.color
  }

  phoneLabel(): string {
    // 🌟 手机号与登录账号解耦：只认单独绑定的手机号，不再把学号/教工号当手机号
    let phone = this.boundPhone
    return phone === '' ? '未绑定' : `${phone.slice(0, 3)}****${phone.slice(7)}`
  }

  openField(key: string): void {
    if (key === 'nickname') {
      this.fieldTitle = '修改昵称'
      this.fieldPlaceholder = '请输入昵称'
      this.fieldValue = this.nickname
      this.fieldMultiline = false
    } else if (key === 'studentId') {
      this.fieldTitle = `填写${this.nameLabel()}`
      this.fieldPlaceholder = `请输入${this.nameLabel()}`
      this.fieldValue = this.studentId
      this.fieldMultiline = false
    } else {
      this.fieldTitle = '个人简介'
      this.fieldPlaceholder = '介绍你的学习方向、兴趣或教学方向'
      this.fieldValue = this.userBio
      this.fieldMultiline = true
    }
    this.fieldController = new CustomDialogController({
      builder: FieldEditDialog({
        title: this.fieldTitle,
        placeholder: this.fieldPlaceholder,
        value: this.fieldValue,
        multiline: this.fieldMultiline,
        maxLength: key === 'bio' ? 100 : 20,
        onSave: (v: string) => {
          if (key !== 'bio' && v === '') {
            Feedback.fail('保存资料', '内容不能为空')
            return
          }
          if (key === 'nickname') {
            this.nickname = v
          } else if (key === 'studentId') {
            this.studentId = v
          } else {
            this.userBio = v
          }
          Feedback.success('资料已保存')
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.fieldController.open()
  }

  openAvatar(): void {
    if (this.avatarDialogVisible) {
      return
    }
    this.avatarDialogVisible = true
    this.avatarController = new CustomDialogController({
      builder: AvatarPickDialog({
        current: this.avatarEmoji,
        onClose: () => {
          this.avatarDialogVisible = false
        },
        onPick: (key: string) => {
          this.avatarEmoji = key
          this.avatarUri = ''
          Feedback.success('头像已更新')
        },
        onAlbum: () => {
          setTimeout(() => {
            this.pickFromAlbum()
          }, 200)
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.avatarController.open()
  }

  async pickFromAlbum(): Promise<void> {
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
        Feedback.fail('更换头像', up.reason)
        return
      }
      let old = this.avatarUri
      this.avatarUri = up.uri
      if (old !== '' && old.indexOf(ctx.filesDir) === 0) {
        try {
          fs.unlinkSync(old)
        } catch (e) {
          // 旧头像删除失败不影响新头像
        }
      }
      Feedback.success('头像已更新')
    } catch (err) {
      Feedback.fail('更换头像', '无法读取所选图片或相册权限不足')
    }
  }

  // 🌟 行内展示值在 @Builder 内部按 key 直接读取状态（不能用按值传参，否则保存后不刷新）
  rowValue(key: string): string {
    if (key === 'nickname') {
      return this.displayName()
    }
    if (key === 'id') {
      return this.idLabel()
    }
    if (key === 'bio') {
      return this.userBio === '' ? '未填写' : this.userBio
    }
    if (key === 'phone') {
      return this.phoneLabel()
    }
    return ''
  }

  @Builder
  row(key: string, title: string, onTap: () => void) {
    Row() {
      Text(title).fontSize(14).fontColor($r('app.color.text_main'))
      Blank()
      if (this.rowValue(key) !== '') {
        Text(this.rowValue(key)).fontSize(12).fontColor($r('app.color.text_sub'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '55%' })
          .margin({ right: 4 })
      }
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(13)
        .fontColor([$r('app.color.text_hint')])
    }
    .width('100%')
    .height(50)
    .padding({ left: 16, right: 16 })
    .onClick(() => onTap())
  }

  @Builder
  avatarView() {
    if (this.avatarUri !== '') {
      Image('file://' + this.avatarUri)
        .width(76).height(76).borderRadius(38).objectFit(ImageFit.Cover)
        .onClick(() => this.openAvatar())
    } else if (this.avatarEmoji !== '' && findAvatar(this.avatarEmoji) !== undefined) {
      Row() {
        SymbolGlyph(this.avatarIcon()).fontSize(34).fontColor([Color.White])
      }
      .width(76).height(76)
      .backgroundColor(this.avatarColor())
      .borderRadius(38)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => this.openAvatar())
    } else {
      Row() {
        Text(this.displayName().slice(0, 1))
          .fontSize(28).fontWeight(FontWeight.Bold).fontColor(Color.White)
      }
      .width(76).height(76)
      .linearGradient({ angle: 135, colors: [['#4C8BF5', 0], ['#3F7EF6', 1]] })
      .borderRadius(38)
      .justifyContent(FlexAlign.Center)
      .onClick(() => this.openAvatar())
    }
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(22)
          .fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Text('个人资料').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Text('编辑').fontSize(13).fontColor($r('app.color.primary'))
          .onClick(() => this.openField('nickname'))
      }
      .width('92%')
      .padding({ top: 16, bottom: 12 })

      Scroll() {
        Column({ space: 14 }) {
          // 资料头部
          Column({ space: 12 }) {
            Row({ space: 14 }) {
              this.avatarView()
              Column({ space: 6 }) {
                Row({ space: 8 }) {
                  Text(this.displayName()).fontSize(19).fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.text_main'))
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(Permission.roleShortLabel())
                    .fontSize(10).fontColor(Color.White)
                    .backgroundColor(Permission.roleColor())
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 }).borderRadius(6)
                }.width('100%')
                Text(`${this.nameLabel()}：${this.idLabel()}`)
                  .fontSize(12).fontColor($r('app.color.text_sub'))
                Text(this.bioLabel())
                  .fontSize(11).fontColor($r('app.color.text_hint'))
                  .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }.width('100%')
            Text('点击头像可更换；身份由注册账号绑定，不支持自行切换')
              .fontSize(10).fontColor($r('app.color.text_hint'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(18)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(18)

          // 基础资料
          Column() {
            Text('基础资料').fontSize(11).fontColor($r('app.color.text_hint'))
              .width('100%').padding({ left: 16, top: 12, bottom: 2 })
            this.row('nickname', '昵称', () => this.openField('nickname'))
            Divider().color($r('app.color.divider_color')).margin({ left: 16, right: 16 })
            this.row('id', this.nameLabel(), () => this.openField('studentId'))
            Divider().color($r('app.color.divider_color')).margin({ left: 16, right: 16 })
            this.row('bio', '个人简介', () => this.openField('bio'))
          }
          .width('100%')
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(18)

          // 账号与安全
          Column() {
            Text('账号与安全').fontSize(11).fontColor($r('app.color.text_hint'))
              .width('100%').padding({ left: 16, top: 12, bottom: 2 })
            this.row('none', '修改登录密码', () => {
              router.pushUrl({ url: 'pages/common/ChangePasswordPage' })
            })
            Divider().color($r('app.color.divider_color')).margin({ left: 16, right: 16 })
            this.row('phone', '绑定手机号', () => {
              router.pushUrl({ url: 'pages/common/ChangePhonePage' })
            })
            Divider().color($r('app.color.divider_color')).margin({ left: 16, right: 16 })
            this.row('none', '绑定第三方账号', () => {
              router.pushUrl({ url: 'pages/common/ThirdPartyBindPage' })
            })
            Divider().color($r('app.color.divider_color')).margin({ left: 16, right: 16 })
            this.row('none', '隐私设置', () => {
              router.pushUrl({ url: 'pages/common/PrivacySettingsPage' })
            })
          }
          .width('100%')
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(18)

          Text('账号与资料均保存在本机（无真实后端），清除本地数据后不可恢复')
            .fontSize(10).fontColor($r('app.color.text_hint'))
            .width('100%').padding({ left: 4, top: 2 })
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
