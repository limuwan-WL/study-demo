import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { GroupMsg } from '../../model/HomeworkModel'
import { formatStamp } from '../../model/DataModel'
import { MessageCenter } from '../../model/MessageCenterModel'
import {
  GroupFile,
  GroupReport,
  MAIN_GROUP_ID,
  addReport,
  reportStatusName,
  currentName
} from '../../model/GroupModel'

// ==================== 举报 ====================
// 🌟 无后端：提交后进入「后台审核」为本地模拟，界面明确标注
@Entry
@Component
struct ReportPage {
  @StorageLink('groupChatArchive') archiveMap: Record<string, GroupMsg[]> = {}
  @StorageLink('groupFiles') allFiles: GroupFile[] = []
  @StorageLink('groupReports') reportList: GroupReport[] = []
  @State groupId: string = MAIN_GROUP_ID
  @State reportType: string = 'message'
  @State targetId: string = ''
  @State targetText: string = ''
  @State detail: string = ''
  @State screenshots: string[] = []
  @State showTargets: boolean = false

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, string>
    if (params !== undefined && params['groupId'] !== undefined && params['groupId'] !== '') {
      this.groupId = params['groupId']
    }
  }

  archive(): GroupMsg[] {
    let list = this.archiveMap[this.groupId]
    return list === undefined ? [] : list
  }

  recentMsgs(): GroupMsg[] {
    return this.archive().filter((m: GroupMsg) => m.kind !== 'system')
      .sort((a: GroupMsg, b: GroupMsg) => b.time - a.time).slice(0, 20)
  }

  groupFiles(): GroupFile[] {
    return this.allFiles.filter((f: GroupFile) => f.groupId === this.groupId)
      .sort((a: GroupFile, b: GroupFile) => b.uploadAt - a.uploadAt).slice(0, 20)
  }

  myReports(): GroupReport[] {
    return this.reportList.filter((r: GroupReport) => r.groupId === this.groupId)
      .sort((a: GroupReport, b: GroupReport) => b.createdAt - a.createdAt)
  }

  typeName(t: string): string {
    if (t === 'message') {
      return '违规发言'
    }
    if (t === 'file') {
      return '违规文件'
    }
    return '其他违规'
  }

  msgText(m: GroupMsg): string {
    if (m.kind === 'file') {
      return `[文件] ${m.fileName}`
    }
    if (m.kind === 'image') {
      return '[图片]'
    }
    if (m.kind === 'video') {
      return '[视频]'
    }
    if (m.kind === 'sticker') {
      return `[表情包] ${m.text}`
    }
    return m.text
  }

  pickScreenshots(): void {
    try {
      let photoPicker = new photoAccessHelper.PhotoViewPicker()
      let opt = new photoAccessHelper.PhotoSelectOptions()
      opt.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      opt.maxSelectNumber = 3 - this.screenshots.length
      if (opt.maxSelectNumber <= 0) {
        promptAction.showToast({ message: '最多上传 3 张截图' })
        return
      }
      photoPicker.select(opt).then((res: photoAccessHelper.PhotoSelectResult) => {
        this.screenshots = this.screenshots.concat(res.photoUris).slice(0, 3)
      }).catch((err: BusinessError) => {
        promptAction.showToast({ message: '未选择截图' })
      })
    } catch (e) {
      promptAction.showToast({ message: '当前设备不支持选择图片' })
    }
  }

  submit(): void {
    if (this.reportType !== 'other' && this.targetId === '') {
      promptAction.showToast({ message: this.reportType === 'file' ? '请选择要举报的文件' : '请选择要举报的消息' })
      return
    }
    if (this.detail.trim() === '') {
      promptAction.showToast({ message: '请填写举报说明' })
      return
    }
    let r = new GroupReport(this.groupId, this.reportType)
    r.targetId = this.targetId
    r.targetText = this.targetText
    r.detail = this.detail.trim()
    r.screenshots = this.screenshots.slice()
    r.status = 'pending'
    r.result = '已提交至后台审核（本地模拟，无真实审核服务）'
    addReport(r)
    // 🌟 举报提交后写入消息中心「举报反馈」，后续审核结果也在此查看
    MessageCenter.pushIfEnabled('report', '举报反馈',
      `你提交的${this.reportType === 'file' ? '文件' : this.reportType === 'message' ? '消息' : '其他'}举报已进入审核队列，处理结果会在这里通知你`)
    promptAction.showToast({ message: '举报已提交，等待后台审核（本地模拟）' })
    router.back()
  }

  @Builder
  typeChip(label: string, value: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.reportType === value ? Color.White : $r('app.color.text_sub'))
      .backgroundColor(this.reportType === value ? '#EF4444' : $r('app.color.field_bg'))
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .borderRadius(15)
      .onClick(() => {
        this.reportType = value
        this.targetId = ''
        this.targetText = ''
        this.showTargets = false
      })
  }

  @Builder
  targetPicker() {
    Column({ space: 6 }) {
      Row() {
        Text(this.reportType === 'file' ? '选择违规文件' : '定位具体消息')
          .fontSize(12).fontColor($r('app.color.text_main')).layoutWeight(1)
        Text(this.showTargets ? '收起' : '选择')
          .fontSize(11).fontColor($r('app.color.primary'))
          .onClick(() => {
            this.showTargets = !this.showTargets
          })
      }.width('100%')
      if (this.targetText !== '') {
        Text(this.targetText)
          .fontSize(11).fontColor($r('app.color.text_sub'))
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%').padding(8)
          .backgroundColor($r('app.color.field_bg')).borderRadius(8)
      }
      if (this.showTargets) {
        Column() {
          if (this.reportType === 'file') {
            ForEach(this.groupFiles(), (f: GroupFile) => {
              Row({ space: 8 }) {
                Text('📄').fontSize(14)
                Text(f.name).fontSize(12).fontColor($r('app.color.text_main'))
                  .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(f.uploader).fontSize(9).fontColor($r('app.color.text_hint'))
              }
              .width('100%').padding({ left: 8, right: 8, top: 7, bottom: 7 })
              .onClick(() => {
                this.targetId = f.id
                this.targetText = `[文件] ${f.name}`
                this.showTargets = false
              })
            }, (f: GroupFile) => `rf_${f.id}`)
          } else {
            ForEach(this.recentMsgs(), (m: GroupMsg) => {
              Column({ space: 2 }) {
                Row({ space: 6 }) {
                  Text(m.name).fontSize(10).fontColor($r('app.color.text_sub'))
                  Blank()
                  Text(formatStamp(m.time)).fontSize(9).fontColor($r('app.color.text_hint'))
                }.width('100%')
                Text(this.msgText(m)).fontSize(11).fontColor($r('app.color.text_main'))
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
              }
              .width('100%').padding({ left: 8, right: 8, top: 6, bottom: 6 })
              .onClick(() => {
                this.targetId = m.id
                this.targetText = `${m.name}：${this.msgText(m)}`
                this.showTargets = false
              })
            }, (m: GroupMsg) => `rm_${m.id}`)
          }
        }
        .width('100%').constraintSize({ maxHeight: 220 })
        .backgroundColor($r('app.color.field_bg')).borderRadius(8)
        .padding(4)
      }
    }
    .width('100%').padding(12)
    .backgroundColor($r('app.color.card_bg')).borderRadius(12)
  }

  @Builder
  historyRow(r: GroupReport) {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        Text(this.typeName(r.type)).fontSize(11).fontColor('#EF4444')
          .padding({ left: 5, right: 5, top: 1, bottom: 1 })
          .backgroundColor('#EF44441A').borderRadius(4)
        Text(reportStatusName(r.status)).fontSize(10).fontColor('#F59E0B')
        Blank()
        Text(formatStamp(r.createdAt)).fontSize(9).fontColor($r('app.color.text_hint'))
      }.width('100%')
      if (r.targetText !== '') {
        Text(r.targetText).fontSize(11).fontColor($r('app.color.text_sub'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      }
      Text(r.detail).fontSize(12).fontColor($r('app.color.text_body'))
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      Text(r.result).fontSize(9).fontColor($r('app.color.text_hint')).width('100%')
    }
    .width('100%').padding(12)
    .backgroundColor($r('app.color.card_bg')).borderRadius(12).margin({ bottom: 8 })
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20).fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Text('举报群聊内容').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          .layoutWeight(1)
        Text('提交')
          .fontSize(14).fontColor(Color.White)
          .padding({ left: 16, right: 16, top: 7, bottom: 7 })
          .backgroundColor('#EF4444').borderRadius(16)
          .onClick(() => this.submit())
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.card_bg'))

      Scroll() {
        Column() {
          Row({ space: 6 }) {
            Text('ℹ️').fontSize(12)
            Text('提交后将进入后台审核；无后端时审核流程为本地模拟，不会真正处理违规内容。')
              .fontSize(10).fontColor($r('app.color.text_hint')).layoutWeight(1)
          }
          .width('90%').padding(10).margin({ top: 12 })
          .backgroundColor($r('app.color.primary_weak')).borderRadius(10)

          // 举报类型
          Text('举报类型').fontSize(11).fontColor($r('app.color.text_hint'))
            .width('90%').padding({ left: 4, top: 14, bottom: 6 })
          Row({ space: 8 }) {
            this.typeChip('违规发言', 'message')
            this.typeChip('违规文件', 'file')
            this.typeChip('其他', 'other')
          }.width('90%')

          // 定位对象
          if (this.reportType !== 'other') {
            Column() {
              this.targetPicker()
            }.width('90%').margin({ top: 12 })
          }

          // 截图
          Column({ space: 8 }) {
            Row() {
              Text('截图证据').fontSize(12).fontColor($r('app.color.text_main')).layoutWeight(1)
              Text(`添加（${this.screenshots.length}/3）`).fontSize(11).fontColor($r('app.color.primary'))
                .onClick(() => this.pickScreenshots())
            }.width('100%')
            if (this.screenshots.length > 0) {
              Scroll() {
                Row({ space: 8 }) {
                  ForEach(this.screenshots, (s: string, idx: number) => {
                    Stack({ alignContent: Alignment.TopEnd }) {
                      Image(s).width(72).height(72).borderRadius(8).objectFit(ImageFit.Cover)
                      Text('×')
                        .fontSize(12).fontColor(Color.White)
                        .width(18).height(18).textAlign(TextAlign.Center)
                        .backgroundColor('#99000000').borderRadius(9)
                        .onClick(() => {
                          let list = this.screenshots.slice()
                          list.splice(idx, 1)
                          this.screenshots = list
                        })
                    }
                  }, (s: string) => s)
                }
              }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
            }
          }
          .width('90%').padding(12).margin({ top: 12 })
          .backgroundColor($r('app.color.card_bg')).borderRadius(12)

          // 说明
          Column({ space: 6 }) {
            Text('举报说明').fontSize(12).fontColor($r('app.color.text_main')).width('100%')
            TextArea({ text: this.detail, placeholder: '请描述违规情况，便于审核处理' })
              .fontSize(13).height(110)
              .backgroundColor($r('app.color.field_bg')).borderRadius(10)
              .padding(10)
              .onChange((v: string) => {
                this.detail = v
              })
          }
          .width('90%').padding(12).margin({ top: 12 })
          .backgroundColor($r('app.color.card_bg')).borderRadius(12)

          Text('提交人：' + currentName())
            .fontSize(10).fontColor($r('app.color.text_hint'))
            .width('90%').padding({ left: 4, top: 8 })

          // 历史举报
          Text('我的举报记录').fontSize(11).fontColor($r('app.color.text_hint'))
            .width('90%').padding({ left: 4, top: 18, bottom: 8 })
          if (this.myReports().length === 0) {
            Text('暂无举报记录').fontSize(12).fontColor($r('app.color.text_hint'))
              .width('90%').padding(18).textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.card_bg')).borderRadius(12)
          } else {
            Column() {
              ForEach(this.myReports(), (r: GroupReport) => {
                this.historyRow(r)
              }, (r: GroupReport) => r.id)
            }.width('90%')
          }

          Text('举报与审核均为本地模拟，未接入真实内容安全审核平台。')
            .fontSize(9).fontColor($r('app.color.text_hint'))
            .width('90%').padding({ top: 10, left: 4, bottom: 40 })
        }.width('100%')
      }
      .layoutWeight(1).align(Alignment.Top).scrollBar(BarState.Off)
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
