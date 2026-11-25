import { promptAction } from '@kit.ArkUI'
import router from '@ohos.router'
import { common } from '@kit.AbilityKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo as fs, picker } from '@kit.CoreFileKit'
import { Permission } from '../../model/PermissionModel'
import {
  ResourceItem, ResourceVisibility, ResourceStore, ResourceAudit,
  formatSize, validateSize, visibilityLabel, visibilityColor, auditLabel, auditColor,
  IMAGE_MAX_MB, FILE_MAX_MB
} from '../../model/ResourceModel'
import { Feedback } from '../../utils/Feedback'
import { EmptyState } from '../../components/StatusViews'
import { UploadPolicy } from '../../utils/UploadPolicy'

// 🌟 可见范围选择：私有 / 课程可见 / 公开
@CustomDialog
struct VisibilityDialog {
  controller: CustomDialogController
  current: ResourceVisibility = 'private'
  onPick: (v: ResourceVisibility) => void = () => {
  }

  @Builder
  option(v: ResourceVisibility, title: string, desc: string) {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(title).fontSize(14).fontColor($r('app.color.text_main'))
        Text(desc).fontSize(11).fontColor($r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (this.current === v) {
        SymbolGlyph($r('sys.symbol.checkmark_circle')).fontSize(17).fontColor([$r('app.color.primary')])
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.field_bg'))
    .borderRadius(12)
    .onClick(() => {
      this.onPick(v)
      this.controller.close()
    })
  }

  build() {
    Column({ space: 10 }) {
      Text('资源可见范围').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        .margin({ bottom: 4 })
      this.option('private', '私有', '仅自己可见，用于个人草稿与备份')
      this.option('course', '课程可见', '仅已加入该课程的学生与授课教师可见')
      this.option('public', '公开', '所有用户可见，进入公开资源区')
    }
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
  }
}

// ==================== 资源存储与安全 ====================
// 🌟 图片 / 文件大小上限 + 图片自动压缩 + 上传审核 + 私有/课程/公开三档可见性
@Entry
@Component
export struct StorageAuditPage {
  @State list: ResourceItem[] = []
  @State filter: string = 'all'
  @State busy: boolean = false
  @State progress: number = 0
  @State stage: string = ''
  visibilityController: CustomDialogController = new CustomDialogController({
    builder: VisibilityDialog({}),
    customStyle: true
  })

  aboutToAppear(): void {
    ResourceStore.ensureSeed()
    this.list = ResourceStore.list().slice()
  }

  refresh(): void {
    this.list = ResourceStore.list().slice()
  }

  filtered(): ResourceItem[] {
    if (this.filter === 'all') {
      return this.list
    }
    if (this.filter === 'blocked') {
      return this.list.filter((r: ResourceItem) => r.audit === 'blocked')
    }
    return this.list.filter((r: ResourceItem) => r.kind === this.filter)
  }

  // ==================== 图片上传：选择 → 压缩 → 审核 ====================
  async pickImage(): Promise<void> {
    if (this.busy) {
      Feedback.info('正在处理上一个上传，请稍候')
      return
    }
    try {
      let options = new photoAccessHelper.PhotoSelectOptions()
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      options.maxSelectNumber = 1
      let result = await new photoAccessHelper.PhotoViewPicker().select(options)
      if (result.photoUris.length === 0) {
        return
      }
      let srcUri = result.photoUris[0]
      let rawSize = 0
      try {
        rawSize = fs.statSync(srcUri).size
      } catch (e) {
        rawSize = 0
      }
      let reason = validateSize('image', rawSize)
      if (reason !== '') {
        Feedback.fail('上传图片', reason)
        return
      }
      this.busy = true
      this.progress = 20
      this.stage = '图片压缩中…'
      let ctx = getContext(this) as common.UIAbilityContext
      let dest = `${ctx.filesDir}/res_${Date.now()}.jpg`
      let finalSize = await this.compressImage(srcUri, dest)
      if (finalSize <= 0) {
        this.busy = false
        Feedback.fail('上传图片', '图片读取或压缩失败，请更换图片重试')
        return
      }
      this.progress = 75
      this.stage = '内容审核中…'
      let name = `图片_${Date.now()}.jpg`
      let item = new ResourceItem(name, 'image', finalSize, dest)
      item.compressed = finalSize < rawSize
      item.audit = ResourceAudit.check(name)
      item.auditReason = ResourceAudit.reason(name)
      this.finishUpload(item)
    } catch (err) {
      this.busy = false
      Feedback.fail('上传图片', '无法读取所选图片或相册权限不足')
    }
  }

  // 真实图片压缩：统一走 UploadPolicy（解码 → quality 60 重编码；失败则原样拷贝）
  async compressImage(srcUri: string, dest: string): Promise<number> {
    return UploadPolicy.compressImage(srcUri, dest)
  }

  // ==================== 文件上传：选择 → 大小校验 → 审核 ====================
  async pickFile(): Promise<void> {
    if (this.busy) {
      Feedback.info('正在处理上一个上传，请稍候')
      return
    }
    try {
      let docPicker = new picker.DocumentViewPicker(getContext(this))
      let options = new picker.DocumentSelectOptions()
      options.maxSelectNumber = 1
      let uris = await docPicker.select(options)
      if (uris.length === 0) {
        return
      }
      let uri = uris[0]
      let rawSize = 0
      try {
        rawSize = fs.statSync(uri).size
      } catch (e) {
        rawSize = 0
      }
      let reason = validateSize('file', rawSize)
      if (reason !== '') {
        Feedback.fail('上传文件', reason)
        return
      }
      this.busy = true
      this.progress = 40
      this.stage = '文件上传中…'
      let ctx = getContext(this) as common.UIAbilityContext
      let name = this.fileNameOf(uri)
      let dest = `${ctx.filesDir}/res_${Date.now()}_${name.replace(/[\\/:*?"<>|]/g, '_')}`
      let src = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      fs.copyFileSync(src.fd, dest)
      fs.closeSync(src)
      let size = fs.statSync(dest).size
      this.progress = 75
      this.stage = '内容审核中…'
      let item = new ResourceItem(name, 'file', size, dest)
      item.audit = ResourceAudit.check(name)
      item.auditReason = ResourceAudit.reason(name)
      this.finishUpload(item)
    } catch (err) {
      this.busy = false
      Feedback.fail('上传文件', '文件读取失败或未授予文件访问权限')
    }
  }

  fileNameOf(uri: string): string {
    let cut = uri.lastIndexOf('/')
    let raw = cut >= 0 ? uri.substring(cut + 1) : uri
    try {
      return decodeURIComponent(raw)
    } catch (e) {
      return raw
    }
  }

  finishUpload(item: ResourceItem): void {
    ResourceStore.add(item)
    this.refresh()
    this.progress = 100
    this.busy = false
    this.stage = ''
    if (item.audit === 'blocked') {
      promptAction.showToast({ message: `内容审核未通过：${item.auditReason}` })
    } else if (item.compressed) {
      Feedback.success(`上传成功，已自动压缩至 ${formatSize(item.sizeBytes)}`)
    } else {
      Feedback.success(`上传成功，大小 ${formatSize(item.sizeBytes)}`)
    }
  }

  // ==================== 可见范围 / 删除 ====================
  openVisibility(item: ResourceItem): void {
    if (item.audit === 'blocked') {
      Feedback.fail('设置可见范围', '资源已被审核屏蔽，不能对外可见')
      return
    }
    this.visibilityController = new CustomDialogController({
      builder: VisibilityDialog({
        current: item.visibility,
        onPick: (v: ResourceVisibility) => this.applyVisibility(item, v)
      }),
      autoCancel: true,
      customStyle: true
    })
    this.visibilityController.open()
  }

  applyVisibility(item: ResourceItem, v: ResourceVisibility): void {
    if (v === 'course' && Permission.isStudent() && Permission.enrolledCourses().length === 0) {
      Feedback.fail('设置课程可见', '你尚未加入任何课程，请先加入课程')
      return
    }
    ResourceStore.setVisibility(item.id, v)
    this.refresh()
    Feedback.success(`可见范围已设为：${visibilityLabel(v)}`)
  }

  removeResource(item: ResourceItem): void {
    Feedback.confirm('删除资源', `确定删除「${item.name}」吗？删除后不可恢复。`, () => {
      if (item.uri !== '') {
        try {
          fs.unlinkSync(item.uri)
        } catch (e) {
          // 文件已不存在时忽略
        }
      }
      if (ResourceStore.remove(item.id)) {
        this.refresh()
        Feedback.success('资源已删除')
      } else {
        Feedback.fail('删除资源', '未找到该资源记录')
      }
    }, '删除', true)
  }

  // ==================== UI ====================
  @Builder
  chip(key: string, label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.filter === key ? Color.White : $r('app.color.text_sub'))
      .backgroundColor(this.filter === key ? $r('app.color.primary') : $r('app.color.field_bg'))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(12)
      .onClick(() => {
        this.filter = key
      })
  }

  @Builder
  resourceRow(r: ResourceItem) {
    Row({ space: 10 }) {
      // 缩略图：图片且通过审核才展示；其余用类型字块
      if (r.kind === 'image' && r.audit !== 'blocked' && r.uri !== '') {
        Image('file://' + r.uri)
          .width(48).height(48).borderRadius(10).objectFit(ImageFit.Cover)
      } else {
        Text(r.kind === 'image' ? '图' : '文')
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .width(48).height(48).borderRadius(10)
          .backgroundColor(r.audit === 'blocked' ? '#9CA3AF' : '#3F7EF6')
          .textAlign(TextAlign.Center)
      }

      Column({ space: 5 }) {
        Text(r.name).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Row({ space: 6 }) {
          Text(formatSize(r.sizeBytes)).fontSize(10).fontColor($r('app.color.text_hint'))
          if (r.compressed) {
            Text('已压缩').fontSize(9).fontColor('#3B82F6')
              .backgroundColor('#DBEAFE').padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .borderRadius(4)
          }
          Text(auditLabel(r.audit)).fontSize(9).fontColor(Color.White)
            .backgroundColor(auditColor(r.audit))
            .padding({ left: 5, right: 5, top: 1, bottom: 1 }).borderRadius(4)
          if (r.audit !== 'blocked') {
            Text(visibilityLabel(r.visibility)).fontSize(9)
              .fontColor(visibilityColor(r.visibility))
              .backgroundColor($r('app.color.field_bg'))
              .padding({ left: 5, right: 5, top: 1, bottom: 1 }).borderRadius(4)
              .onClick(() => this.openVisibility(r))
          }
        }
        .width('100%')
        if (r.audit === 'blocked') {
          Text('违规资源已自动屏蔽，不可预览与分享').fontSize(10).fontColor('#EF4444')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('删除').fontSize(11).fontColor($r('app.color.danger'))
        .onClick(() => this.removeResource(r))
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(22)
          .fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Text('资源安全').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Text(Permission.roleLabel()).fontSize(11).fontColor(Color.White)
          .backgroundColor(Permission.roleColor())
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .borderRadius(8)
      }
      .width('92%')
      .padding({ top: 16, bottom: 10 })

      Column({ space: 12 }) {
        // 规则说明
        Column({ space: 6 }) {
          Text('上传规则').fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
          Text(`· 图片上限 ${IMAGE_MAX_MB}MB，上传后自动压缩为 JPEG（质量 60）`)
            .fontSize(11).fontColor($r('app.color.text_sub'))
          Text(`· 文件上限 ${FILE_MAX_MB}MB，超出上限直接拦截并提示具体大小`)
            .fontSize(11).fontColor($r('app.color.text_sub'))
          Text('· 所有资源先审后发，命中违规关键词将自动屏蔽')
            .fontSize(11).fontColor($r('app.color.text_sub'))
          Text('· 可见范围分私有 / 课程可见 / 公开，课程可见仅同课程成员可访问')
            .fontSize(11).fontColor($r('app.color.text_sub'))
          Text('说明：当前为本地关键词审核与本地沙箱存储（无真实后端）')
            .fontSize(10).fontColor($r('app.color.text_hint'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(14)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(14)

        // 上传入口
        Row({ space: 10 }) {
          Text('从相册上传图片')
            .fontSize(13).fontWeight(FontWeight.Medium).fontColor(Color.White)
            .layoutWeight(1).textAlign(TextAlign.Center).height(42)
            .backgroundColor(this.busy ? '#9CA3AF' : '#3F7EF6').borderRadius(12)
            .onClick(() => {
              this.pickImage()
            })
          Text('上传文件')
            .fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary'))
            .layoutWeight(1).textAlign(TextAlign.Center).height(42)
            .backgroundColor($r('app.color.primary_weak')).borderRadius(12)
            .onClick(() => {
              this.pickFile()
            })
        }
        .width('100%')

        // 处理进度
        if (this.busy) {
          Column({ space: 7 }) {
            Row() {
              Text(this.stage).fontSize(12).fontColor($r('app.color.text_main')).layoutWeight(1)
              Text(`${this.progress}%`).fontSize(11).fontColor('#3F7EF6')
            }.width('100%')
            Row() {
              Row().width(`${this.progress}%`).height(6).backgroundColor('#3F7EF6').borderRadius(3)
            }.width('100%').height(6).backgroundColor($r('app.color.field_bg')).borderRadius(3)
          }
          .width('100%').padding(12).backgroundColor($r('app.color.card_bg')).borderRadius(12)
        }

        // 筛选
        Row({ space: 8 }) {
          this.chip('all', '全部')
          this.chip('image', '图片')
          this.chip('file', '文件')
          this.chip('blocked', '已屏蔽')
        }
        .width('100%')
      }
      .width('92%')
      .margin({ bottom: 8 })

      if (this.filtered().length === 0) {
        EmptyState({
          icon: $r('sys.symbol.inbox'),
          title: '暂无资源',
          desc: '从相册或文件中选择内容上传，系统会自动压缩与审核',
          actionLabel: '上传图片',
          onAction: () => {
            this.pickImage()
          }
        })
      } else {
        List({ space: 8 }) {
          ForEach(this.filtered(), (r: ResourceItem) => {
            ListItem() {
              this.resourceRow(r)
            }
          }, (r: ResourceItem) => `${r.id}_${r.audit}_${r.visibility}`)
        }
        .width('92%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .padding({ bottom: 20 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
