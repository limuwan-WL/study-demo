import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import { picker } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import {
  GroupNotice,
  MAIN_GROUP_ID,
  canPublishNotice,
  noticeById,
  noticeHtml,
  noticeRead,
  saveNotice,
  notifyGroup
} from '../../model/GroupModel'

// ==================== 群公告编辑（富文本 + 附件 + 置顶） ====================
@Entry
@Component
struct NoticeEditPage {
  @StorageLink('nickname') nickname: string = '张同学'
  @StorageLink('userRole') userRole: string = 'student'
  @State groupId: string = MAIN_GROUP_ID
  @State editingId: string = ''
  @State title: string = ''
  @State content: string = ''
  @State attachName: string = ''
  @State attachUri: string = ''
  @State pinned: boolean = true
  @State showPreview: boolean = false

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, string>
    if (params !== undefined) {
      if (params['groupId'] !== undefined && params['groupId'] !== '') {
        this.groupId = params['groupId']
      }
      if (params['noticeId'] !== undefined && params['noticeId'] !== '') {
        this.editingId = params['noticeId']
      }
    }
    if (this.editingId !== '') {
      let n = noticeById(this.editingId)
      if (n !== undefined) {
        this.title = n.title
        this.content = n.content
        this.attachName = n.attachmentName
        this.attachUri = n.attachmentUri
        this.pinned = n.pinned
      }
    }
  }

  previewHeight(): number {
    let lines = this.content.split('\n').length
    return Math.min(240, Math.max(80, lines * 20 + 12))
  }

  insert(text: string): void {
    this.content += text
  }

  async pickAttachment(): Promise<void> {
    try {
      let context = getContext(this) as common.UIAbilityContext
      let documentPicker = new picker.DocumentViewPicker(context)
      let options = new picker.DocumentSelectOptions()
      options.maxSelectNumber = 1
      let uris = await documentPicker.select(options)
      if (uris === undefined || uris.length === 0) {
        return
      }
      let uri = uris[0]
      let name = uri
      let slash = name.lastIndexOf('/')
      if (slash >= 0) {
        name = name.substring(slash + 1)
      }
      try {
        name = decodeURIComponent(name)
      } catch (e) {
        // 解码失败保留原文件名
      }
      this.attachName = name
      this.attachUri = uri
    } catch (e) {
      promptAction.showToast({ message: '未选择附件' })
    }
  }

  save(): void {
    if (!canPublishNotice()) {
      promptAction.showToast({ message: '仅授课教师与助教可发布公告' })
      return
    }
    let title = this.title.trim()
    let content = this.content.trim()
    if (title === '') {
      promptAction.showToast({ message: '请输入公告标题' })
      return
    }
    if (content === '') {
      promptAction.showToast({ message: '请输入公告内容' })
      return
    }
    let editing = this.editingId !== ''
    let n: GroupNotice
    if (editing) {
      let old = noticeById(this.editingId)
      if (old === undefined) {
        promptAction.showToast({ message: '公告不存在' })
        return
      }
      n = old
    } else {
      n = new GroupNotice(this.groupId, title, content, this.nickname)
    }
    n.title = title
    n.content = content
    n.attachmentName = this.attachName
    n.attachmentUri = this.attachUri
    n.pinned = this.pinned
    n.updatedAt = Date.now()
    if (!noticeRead(n)) {
      n.readBy = n.readBy.concat([this.nickname])
    }
    saveNotice(n)
    // 🌟 公告变更推送（无后端，本地模拟并标注）
    notifyGroup(this.groupId, `群公告「${title}」已${editing ? '更新' : '发布'}，请及时查看。`, this.nickname)
    promptAction.showToast({ message: editing ? '公告已更新并推送通知（本地模拟）' : '公告已发布并推送通知（本地模拟）' })
    router.back()
  }

  @Builder
  toolbarBtn(label: string, onTap: () => void) {
    Text(label)
      .fontSize(12).fontColor($r('app.color.text_main'))
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor($r('app.color.field_bg')).borderRadius(10)
      .onClick(() => onTap())
  }

  @Builder
  noPermission() {
    Column({ space: 12 }) {
      Text('🔒').fontSize(40)
      Text('无公告发布权限').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      Text('学生仅可查看群公告与群资源。')
        .fontSize(12).fontColor($r('app.color.text_sub'))
      Text('返回')
        .fontSize(13).fontColor(Color.White)
        .padding({ left: 20, right: 20, top: 9, bottom: 9 })
        .backgroundColor($r('app.color.primary')).borderRadius(18)
        .onClick(() => router.back())
    }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20).fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Text(this.editingId === '' ? '发布群公告' : '编辑群公告')
          .fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          .layoutWeight(1)
        if (canPublishNotice()) {
          Text('发布')
            .fontSize(14).fontColor(Color.White)
            .padding({ left: 16, right: 16, top: 7, bottom: 7 })
            .backgroundColor($r('app.color.primary')).borderRadius(16)
            .onClick(() => this.save())
        }
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.card_bg'))

      if (!canPublishNotice()) {
        this.noPermission()
      } else {
        Scroll() {
          Column({ space: 12 }) {
            TextInput({ text: this.title, placeholder: '公告标题' })
              .height(44).fontSize(15).fontWeight(FontWeight.Medium)
              .backgroundColor($r('app.color.card_bg')).borderRadius(12)
              .padding({ left: 12, right: 12 })
              .onChange((v: string) => {
                this.title = v
              })

            // 富文本输入
            Column({ space: 8 }) {
              Row({ space: 8 }) {
                Text('正文').fontSize(11).fontColor($r('app.color.text_hint')).layoutWeight(1)
                Text(this.showPreview ? '编辑' : '预览')
                  .fontSize(11).fontColor($r('app.color.primary'))
                  .onClick(() => {
                    this.showPreview = !this.showPreview
                  })
              }.width('100%')
              if (this.showPreview) {
                Column() {
                  RichText(noticeHtml(this.content))
                    .width('100%')
                    .height(this.previewHeight())
                }
                .width('100%').padding(10)
                .backgroundColor($r('app.color.field_bg')).borderRadius(10)
              } else {
                TextArea({ text: this.content, placeholder: '输入公告内容，可插入标题、列表与加粗' })
                  .fontSize(13).height(160)
                  .backgroundColor($r('app.color.field_bg')).borderRadius(10)
                  .padding(10)
                  .onChange((v: string) => {
                    this.content = v
                  })
              }
              Row({ space: 8 }) {
                this.toolbarBtn('** 加粗', (): void => this.insert('**重点内容**'))
                this.toolbarBtn('## 标题', (): void => this.insert('\n## 小标题'))
                this.toolbarBtn('- 列表', (): void => this.insert('\n- 列表项'))
              }.width('100%')
              Text('支持富文本标记：## 标题、- 列表、**加粗**；发布时可附带附件。')
                .fontSize(9).fontColor($r('app.color.text_hint')).width('100%')
            }
            .width('100%').padding(12)
            .backgroundColor($r('app.color.card_bg')).borderRadius(12)

            // 附件
            Column({ space: 8 }) {
              Row({ space: 8 }) {
                Text('📎').fontSize(16)
                Text(this.attachName === '' ? '添加附件（选填）' : this.attachName)
                  .fontSize(13).fontColor(this.attachName === '' ? $r('app.color.text_sub') : $r('app.color.text_main'))
                  .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                if (this.attachName === '') {
                  Text('选择').fontSize(12).fontColor($r('app.color.primary'))
                } else {
                  Text('移除').fontSize(12).fontColor('#EF4444')
                    .onClick(() => {
                      this.attachName = ''
                      this.attachUri = ''
                    })
                }
              }
              .width('100%').height(44)
              .onClick(() => {
                if (this.attachName === '') {
                  this.pickAttachment()
                }
              })
              Text('附件随公告一起保存在本地（云端存储为本地模拟）。')
                .fontSize(9).fontColor($r('app.color.text_hint')).width('100%')
            }
            .width('100%').padding(12)
            .backgroundColor($r('app.color.card_bg')).borderRadius(12)

            // 置顶
            Row() {
              Column({ space: 2 }) {
                Text('置顶公告').fontSize(14).fontColor($r('app.color.text_main'))
                Text('置顶后显示在群公告列表最前').fontSize(10).fontColor($r('app.color.text_hint'))
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.pinned })
                .selectedColor('#3F7EF6')
                .onChange((v: boolean) => {
                  this.pinned = v
                })
            }
            .width('100%').padding(14)
            .backgroundColor($r('app.color.card_bg')).borderRadius(12)

            Text('发布 / 修改公告后会向群成员推送通知；无后端时以本地模拟并在群内标注。')
              .fontSize(10).fontColor($r('app.color.text_hint'))
              .width('100%').padding({ left: 4, bottom: 30 })
          }.width('90%').margin({ top: 12 })
        }
        .layoutWeight(1).align(Alignment.Top).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
