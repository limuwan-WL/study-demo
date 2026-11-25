import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import { GroupMsg } from '../../model/HomeworkModel'
import { formatStamp } from '../../model/DataModel'
import {
  MAIN_GROUP_ID,
  roleLabel,
  roleColor
} from '../../model/GroupModel'

// ==================== 聊天记录检索 ====================
// 🌟 检索对象为「云端归档」（本地模拟）；清空本地聊天记录不影响这里
@Entry
@Component
struct ChatSearchPage {
  @StorageLink('groupChatArchive') archiveMap: Record<string, GroupMsg[]> = {}
  @State groupId: string = MAIN_GROUP_ID
  @State keyword: string = ''
  @State sender: string = 'all'
  @State kind: string = 'all'
  @State timeRange: string = 'all'

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

  senders(): string[] {
    let names: string[] = []
    this.archive().forEach((m: GroupMsg) => {
      if (m.kind !== 'system' && names.indexOf(m.name) < 0) {
        names.push(m.name)
      }
    })
    return names
  }

  results(): GroupMsg[] {
    let key = this.keyword.trim()
    let now = Date.now()
    return this.archive().filter((m: GroupMsg) => {
      if (m.kind === 'system') {
        return false
      }
      if (this.sender !== 'all' && m.name !== this.sender) {
        return false
      }
      // 🌟 消息类型筛选：文件 / 图片 / 视频 / 表情包 / 文字
      if (this.kind !== 'all' && m.kind !== this.kind) {
        return false
      }
      if (this.timeRange !== 'all') {
        let days = this.timeRange === '7' ? 7 : 30
        if (now - m.time > days * 86400000) {
          return false
        }
      }
      if (key !== '') {
        let body = m.kind === 'file' ? m.fileName : m.text
        if (body.indexOf(key) < 0) {
          return false
        }
      }
      return true
    }).sort((a: GroupMsg, b: GroupMsg) => b.time - a.time)
  }

  kindName(m: GroupMsg): string {
    if (m.kind === 'file') {
      return '文件'
    }
    if (m.kind === 'image') {
      return '图片'
    }
    if (m.kind === 'video') {
      return '视频'
    }
    if (m.kind === 'sticker') {
      return '表情包'
    }
    return '文字'
  }

  contentText(m: GroupMsg): string {
    if (m.kind === 'file') {
      return `[文件] ${m.fileName}`
    }
    if (m.kind === 'image') {
      return '[图片]'
    }
    if (m.kind === 'video') {
      return '[视频]'
    }
    return m.text
  }

  @Builder
  chip(label: string, active: boolean, onTap: () => void) {
    Text(label)
      .fontSize(12)
      .fontColor(active ? Color.White : $r('app.color.text_sub'))
      .backgroundColor(active ? '#3F7EF6' : $r('app.color.field_bg'))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(14)
      .onClick(() => onTap())
  }

  @Builder
  resultRow(m: GroupMsg) {
    Column({ space: 5 }) {
      Row({ space: 6 }) {
        Text(m.name.substring(0, 1))
          .fontSize(10).fontColor(Color.White)
          .width(20).height(20).borderRadius(10).textAlign(TextAlign.Center)
          .backgroundColor(roleColor(m.role))
        Text(m.name).fontSize(12).fontColor($r('app.color.text_main'))
        Text(roleLabel(m.role))
          .fontSize(8).fontColor(roleColor(m.role))
          .padding({ left: 4, right: 4, top: 1, bottom: 1 })
          .backgroundColor($r('app.color.field_bg')).borderRadius(4)
        Blank()
        Text(this.kindName(m)).fontSize(9).fontColor($r('app.color.text_hint'))
        Text(formatStamp(m.time)).fontSize(9).fontColor($r('app.color.text_hint'))
      }.width('100%')
      Text(this.contentText(m))
        .fontSize(13).fontColor($r('app.color.text_body'))
        .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%').padding(12)
    .backgroundColor($r('app.color.card_bg')).borderRadius(12).margin({ bottom: 8 })
    .onClick(() => promptAction.showToast({ message: '演示环境无法跳转到云端原始消息' }))
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20).fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Text('聊天记录检索').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          .layoutWeight(1)
        Text(`${this.results().length} 条`).fontSize(11).fontColor($r('app.color.text_hint'))
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.card_bg'))

      Scroll() {
        Column() {
          // 关键词
          Row({ space: 8 }) {
            Text('🔍').fontSize(15)
            TextInput({ text: this.keyword, placeholder: '搜索关键词 / 文件名' })
              .fontSize(13).height(38).layoutWeight(1)
              .backgroundColor($r('app.color.field_bg')).borderRadius(19)
              .padding({ left: 12, right: 12 })
              .onChange((v: string) => {
                this.keyword = v
              })
            if (this.keyword !== '') {
              Text('清除')
                .fontSize(11).fontColor($r('app.color.text_hint'))
                .onClick(() => {
                  this.keyword = ''
                })
            }
          }
          .width('90%').padding(10).margin({ top: 12 })
          .backgroundColor($r('app.color.card_bg')).borderRadius(14)

          // 发送人
          Text('发送人').fontSize(11).fontColor($r('app.color.text_hint'))
            .width('90%').padding({ left: 4, top: 12, bottom: 6 })
          Scroll() {
            Row({ space: 8 }) {
              this.chip('全部', this.sender === 'all', (): void => {
                this.sender = 'all'
              })
              ForEach(this.senders(), (s: string) => {
                this.chip(s, this.sender === s, (): void => {
                  this.sender = s
                })
              }, (s: string) => s)
            }
          }
          .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('90%')

          // 消息类型
          Text('消息类型').fontSize(11).fontColor($r('app.color.text_hint'))
            .width('90%').padding({ left: 4, top: 12, bottom: 6 })
          Scroll() {
            Row({ space: 8 }) {
              this.chip('全部', this.kind === 'all', (): void => {
                this.kind = 'all'
              })
              this.chip('文字', this.kind === 'text', (): void => {
                this.kind = 'text'
              })
              this.chip('图片', this.kind === 'image', (): void => {
                this.kind = 'image'
              })
              this.chip('文件', this.kind === 'file', (): void => {
                this.kind = 'file'
              })
              this.chip('视频', this.kind === 'video', (): void => {
                this.kind = 'video'
              })
              this.chip('表情包', this.kind === 'sticker', (): void => {
                this.kind = 'sticker'
              })
            }
          }
          .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('90%')

          // 时间范围
          Text('时间范围').fontSize(11).fontColor($r('app.color.text_hint'))
            .width('90%').padding({ left: 4, top: 12, bottom: 6 })
          Row({ space: 8 }) {
            this.chip('全部', this.timeRange === 'all', (): void => {
              this.timeRange = 'all'
            })
            this.chip('近 7 天', this.timeRange === '7', (): void => {
              this.timeRange = '7'
            })
            this.chip('近 30 天', this.timeRange === '30', (): void => {
              this.timeRange = '30'
            })
          }.width('90%')

          // 说明
          Row({ space: 6 }) {
            Text('☁️').fontSize(12)
            Text('检索范围为云端归档（本地模拟）。清空本地聊天记录只删本机缓存，云端归档仍可检索。')
              .fontSize(10).fontColor($r('app.color.text_hint')).layoutWeight(1)
          }
          .width('90%').padding(10).margin({ top: 12, bottom: 10 })
          .backgroundColor($r('app.color.primary_weak')).borderRadius(10)

          if (this.results().length === 0) {
            Column({ space: 8 }) {
              Text('🗂️').fontSize(30)
              Text('没有找到匹配的聊天记录').fontSize(12).fontColor($r('app.color.text_hint'))
            }
            .width('90%').padding(30).alignItems(HorizontalAlign.Center)
          } else {
            Column() {
              ForEach(this.results(), (m: GroupMsg) => {
                this.resultRow(m)
              }, (m: GroupMsg) => m.id)
            }.width('90%')
          }

          Text('云端记录与检索为本地模拟，未接入真实服务端存储与检索接口。')
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
