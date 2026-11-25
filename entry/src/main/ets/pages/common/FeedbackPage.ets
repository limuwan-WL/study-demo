import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { FeedbackItem, formatStamp } from '../../model/DataModel'
import { ThemeColor } from '../../utils/ThemeColor'

const FEEDBACK_TYPES: string[] = ['功能异常', '使用建议', '内容举报', '其他']
const MAX_LENGTH: number = 200
const MIN_LENGTH: number = 5

@Entry
@Component
export struct FeedbackPage {
  @StorageLink('feedbackList') feedbackList: FeedbackItem[] = []
  @State fbType: string = '功能异常'
  @State content: string = ''
  @State shotUri: string = ''

  aboutToAppear() {
    ThemeColor.isDark = AppStorage.get<boolean>('isDark') ?? false
  }

  // 🌟 可选截图：从系统相册选一张，拷到应用沙箱，避免选择器临时 URI 失效
  async pickScreenshot() {
    try {
      let options = new photoAccessHelper.PhotoSelectOptions()
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      options.maxSelectNumber = 1
      let result = await new photoAccessHelper.PhotoViewPicker().select(options)
      if (result.photoUris.length === 0) {
        return
      }
      let ctx = getContext(this) as common.UIAbilityContext
      let dest = `${ctx.filesDir}/feedback_${Date.now()}.jpg`
      let src = fs.openSync(result.photoUris[0], fs.OpenMode.READ_ONLY)
      fs.copyFileSync(src.fd, dest)
      fs.closeSync(src)
      this.shotUri = dest
    } catch (err) {
      promptAction.showToast({ message: '未能读取所选图片，请重试' })
    }
  }

  submit() {
    let text = this.content.trim()
    if (text === '') {
      promptAction.showToast({ message: '请输入反馈内容' })
      return
    }
    if (text.length < MIN_LENGTH) {
      promptAction.showToast({ message: `反馈内容至少 ${MIN_LENGTH} 个字` })
      return
    }
    if (text.length > MAX_LENGTH) {
      promptAction.showToast({ message: `反馈内容不能超过 ${MAX_LENGTH} 个字` })
      return
    }
    let images: string[] = this.shotUri === '' ? [] : [this.shotUri]
    let list: FeedbackItem[] = this.feedbackList.slice()
    list.unshift(new FeedbackItem(this.fbType, text, images))
    this.feedbackList = list
    this.content = ''
    this.shotUri = ''
    promptAction.showToast({ message: '反馈已提交，感谢你的反馈' })
  }

  @Builder
  header() {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(24)
        .fontColor([ThemeColor.get('text_main')])
        .onClick(() => router.back())
      Text('客服反馈').fontSize(20).fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get('text_main')).margin({ left: 12 })
    }
    .width('100%').height(56).padding({ left: 16 })
  }

  @Builder
  typeChip(t: string) {
    Text(t)
      .fontSize(13)
      .fontColor(this.fbType === t ? Color.White : ThemeColor.get('text_sub'))
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(this.fbType === t ? ThemeColor.get('primary') : ThemeColor.get('field_bg'))
      .borderRadius(16)
      .onClick(() => {
        this.fbType = t
      })
  }

  @Builder
  historyRow(item: FeedbackItem) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(item.type)
          .fontSize(11).fontColor(ThemeColor.get('primary'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(8).backgroundColor(ThemeColor.get('primary_weak'))
        Text(formatStamp(item.createdAt))
          .fontSize(11).fontColor(ThemeColor.get('text_hint')).layoutWeight(1)
        Text(item.status).fontSize(11).fontColor(ThemeColor.get('success'))
      }.width('100%')

      Text(item.content)
        .fontSize(13).fontColor(ThemeColor.get('text_main'))
        .maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (item.images.length > 0) {
        Row({ space: 8 }) {
          ForEach(item.images, (uri: string, index: number) => {
            Image('file://' + uri)
              .width(64).height(64).borderRadius(8)
              .objectFit(ImageFit.Cover)
              .backgroundColor(ThemeColor.get('field_bg'))
          }, (uri: string, index: number) => `${item.id}_${index}`)
        }.width('100%')
      }
    }
    .width('100%').padding(14)
    .backgroundColor(ThemeColor.get('card_bg')).borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      this.header()

      Scroll() {
        Column({ space: 14 }) {
          // 本地模拟说明
          Row({ space: 8 }) {
            Text('i').fontSize(11).fontWeight(FontWeight.Bold).fontColor(Color.White)
              .width(18).height(18).borderRadius(9)
              .backgroundColor(ThemeColor.get('primary')).textAlign(TextAlign.Center)
            Text('当前无后端服务：反馈会保存在本机记录中，不会真实发送到服务器')
              .fontSize(12).fontColor(ThemeColor.get('text_sub')).layoutWeight(1)
          }
          .width('100%').padding(12)
          .backgroundColor(ThemeColor.get('card_bg')).borderRadius(12)

          // 反馈表单
          Column({ space: 14 }) {
            Column({ space: 8 }) {
              Text('反馈类型').fontSize(12).fontColor(ThemeColor.get('text_sub')).width('100%')
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(FEEDBACK_TYPES, (t: string) => {
                  Row() {
                    this.typeChip(t)
                  }.margin({ right: 8, bottom: 8 })
                }, (t: string) => `${t}_${this.fbType === t ? 1 : 0}`)
              }.width('100%')
            }.width('100%')

            Column({ space: 8 }) {
              Row() {
                Text('反馈内容').fontSize(12).fontColor(ThemeColor.get('text_sub')).layoutWeight(1)
                Text(`${this.content.length}/${MAX_LENGTH}`)
                  .fontSize(11)
                  .fontColor(this.content.length >= MAX_LENGTH ? ThemeColor.get('warning') : ThemeColor.get('text_hint'))
              }.width('100%')
              TextArea({ text: this.content, placeholder: `请描述你遇到的问题或建议（${MIN_LENGTH}-${MAX_LENGTH} 字）` })
                .maxLength(MAX_LENGTH)
                .height(120).width('100%').fontSize(14)
                .backgroundColor(ThemeColor.get('field_bg')).borderRadius(10)
                .onChange((v: string) => this.content = v)
            }.width('100%')

            // 可选截图
            Column({ space: 8 }) {
              Text('上传截图（可选）').fontSize(12).fontColor(ThemeColor.get('text_sub')).width('100%')
              if (this.shotUri === '') {
                Row({ space: 6 }) {
                  Text('＋').fontSize(18).fontColor(ThemeColor.get('primary'))
                  Text('添加截图').fontSize(13).fontColor(ThemeColor.get('primary'))
                }
                .width(96).height(96).borderRadius(10)
                .justifyContent(FlexAlign.Center)
                .backgroundColor(ThemeColor.get('field_bg'))
                .border({ width: 1, color: ThemeColor.get('divider'), style: BorderStyle.Dashed })
                .onClick(() => this.pickScreenshot())
              } else {
                Stack({ alignContent: Alignment.TopEnd }) {
                  Image('file://' + this.shotUri)
                    .width(96).height(96).borderRadius(10)
                    .objectFit(ImageFit.Cover)
                  Text('✕')
                    .fontSize(11).fontColor(Color.White)
                    .width(20).height(20).borderRadius(10)
                    .textAlign(TextAlign.Center)
                    .backgroundColor('rgba(0,0,0,0.55)')
                    .margin(4)
                    .onClick(() => this.shotUri = '')
                }.width(96).height(96)
              }
            }.width('100%').alignItems(HorizontalAlign.Start)

            Button('提交反馈')
              .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
              .width('100%').height(46).borderRadius(23)
              .backgroundColor(ThemeColor.get('primary'))
              .onClick(() => this.submit())
          }
          .width('100%').padding(16)
          .backgroundColor(ThemeColor.get('card_bg')).borderRadius(14)
          .alignItems(HorizontalAlign.Start)

          // 历史反馈
          Text(`我的反馈（${this.feedbackList.length}）`)
            .fontSize(14).fontWeight(FontWeight.Bold).fontColor(ThemeColor.get('text_main'))
            .width('100%').padding({ left: 4, top: 4 })

          if (this.feedbackList.length === 0) {
            Column({ space: 8 }) {
              Text('💬').fontSize(30)
              Text('还没有提交过反馈').fontSize(13).fontColor(ThemeColor.get('text_sub'))
              Text('提交后可在这里查看处理记录').fontSize(11).fontColor(ThemeColor.get('text_hint'))
            }
            .width('100%').padding({ top: 28, bottom: 28 })
            .backgroundColor(ThemeColor.get('card_bg')).borderRadius(14)
            .alignItems(HorizontalAlign.Center)
          } else {
            ForEach(this.feedbackList, (item: FeedbackItem) => {
              this.historyRow(item)
            }, (item: FeedbackItem) => item.id)
          }
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
