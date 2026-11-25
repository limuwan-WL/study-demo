import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import { formatStamp } from '../../model/DataModel'
import {
  GroupFile,
  MAIN_GROUP_ID,
  saveFiles,
  fileKindName,
  fileKindIcon,
  fileExpireLabel,
  fileExpired,
  cleanExpiredFiles,
  setRetentionDays,
  currentRole
} from '../../model/GroupModel'

// ==================== 历史文件归档 ====================
// 🌟 群内文件自动归档；云端存储、过期清理与批量下载均为本地模拟
@Entry
@Component
struct GroupFilesPage {
  @StorageLink('groupFiles') allFiles: GroupFile[] = []
  @StorageLink('fileRetentionDays') retention: number = 30
  @State groupId: string = MAIN_GROUP_ID
  @State kind: string = 'all'
  @State timeRange: string = 'all'
  @State selectMode: boolean = false
  @State selected: string[] = []

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, string>
    if (params !== undefined && params['groupId'] !== undefined && params['groupId'] !== '') {
      this.groupId = params['groupId']
    }
  }

  files(): GroupFile[] {
    let now = Date.now()
    return this.allFiles.filter((f: GroupFile) => f.groupId === this.groupId)
      .filter((f: GroupFile) => this.kind === 'all' || f.kind === this.kind)
      .filter((f: GroupFile) => {
        if (this.timeRange === 'all') {
          return true
        }
        let days = this.timeRange === '7' ? 7 : 30
        return now - f.uploadAt <= days * 86400000
      })
      .sort((a: GroupFile, b: GroupFile) => b.uploadAt - a.uploadAt)
  }

  totalSize(): string {
    let n = this.files().length
    return `${n} 个文件`
  }

  picked(id: string): boolean {
    return this.selected.indexOf(id) >= 0
  }

  toggle(id: string): void {
    if (this.picked(id)) {
      this.selected = this.selected.filter((x: string) => x !== id)
    } else {
      this.selected = this.selected.concat([id])
    }
  }

  toggleAll(): void {
    if (this.selected.length === this.files().length) {
      this.selected = []
    } else {
      this.selected = this.files().map((f: GroupFile) => f.id)
    }
  }

  batchDownload(): void {
    if (this.selected.length === 0) {
      promptAction.showToast({ message: '请先选择要下载的文件' })
      return
    }
    let all = this.allFiles.slice()
    all.forEach((f: GroupFile) => {
      if (this.selected.indexOf(f.id) >= 0) {
        f.downloaded = true
      }
    })
    saveFiles(all)
    this.allFiles = all
    let n = this.selected.length
    this.selected = []
    this.selectMode = false
    promptAction.showToast({ message: `已模拟批量下载 ${n} 个文件（未接入真实云端存储）` })
  }

  clean(): void {
    let expired = this.files().filter((f: GroupFile) => fileExpired(f)).length
    if (expired === 0) {
      promptAction.showToast({ message: '暂无过期文件' })
      return
    }
    AlertDialog.show({
      title: '清理过期文件',
      message: `将按保留策略清理 ${expired} 个过期文件（本地模拟云端清理，不可恢复）。`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '清理', fontColor: '#EF4444', action: () => {
          let n = cleanExpiredFiles(this.groupId)
          this.selected = []
          promptAction.showToast({ message: `已清理 ${n} 个过期文件（本地模拟）` })
        }
      }
    })
  }

  @Builder
  filterChip(label: string, active: boolean, onTap: () => void, danger: boolean) {
    Text(label)
      .fontSize(12)
      .fontColor(active ? Color.White : $r('app.color.text_sub'))
      .backgroundColor(active ? (danger ? '#EF4444' : '#3F7EF6') : $r('app.color.field_bg'))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(14)
      .onClick(() => onTap())
  }

  @Builder
  fileRow(f: GroupFile) {
    Row({ space: 10 }) {
      if (this.selectMode) {
        Text(this.picked(f.id) ? '☑' : '☐')
          .fontSize(18).fontColor(this.picked(f.id) ? '#3F7EF6' : $r('app.color.text_hint'))
          .width(22).textAlign(TextAlign.Center)
      }
      Text(fileKindIcon(f.kind)).fontSize(22)
        .width(40).height(40).textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.field_bg')).borderRadius(10)
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(f.name).fontSize(13).fontColor($r('app.color.text_main'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          if (f.downloaded) {
            Text('已下载').fontSize(9).fontColor('#22C55E')
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .backgroundColor('#22C55E1A').borderRadius(4)
          }
        }.width('100%')
        Text(`${fileKindName(f.kind)} · ${f.size} · ${f.uploader}`)
          .fontSize(10).fontColor($r('app.color.text_hint'))
        Text(`${formatStamp(f.uploadAt)} · ${fileExpireLabel(f)}`)
          .fontSize(10).fontColor(fileExpired(f) ? '#EF4444' : $r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }
    .width('100%').padding({ top: 9, bottom: 9, left: 12, right: 12 })
    .onClick(() => {
      if (this.selectMode) {
        this.toggle(f.id)
      } else {
        promptAction.showToast({ message: '云端文件预览需接入真实存储，当前为演示环境' })
      }
    })
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20).fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Column({ space: 2 }) {
          Text('历史文件归档').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Text('群内文件自动归档 · 云端存储本地模拟').fontSize(10).fontColor($r('app.color.text_hint'))
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text(this.selectMode ? '取消' : '批量')
          .fontSize(13).fontColor($r('app.color.primary'))
          .onClick(() => {
            this.selectMode = !this.selectMode
            if (!this.selectMode) {
              this.selected = []
            }
          })
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.card_bg'))

      Scroll() {
        Column() {
          // 分类
          Row({ space: 8 }) {
            this.filterChip('全部', this.kind === 'all', (): void => {
              this.kind = 'all'
            }, false)
            this.filterChip('文档', this.kind === 'doc', (): void => {
              this.kind = 'doc'
            }, false)
            this.filterChip('图片', this.kind === 'image', (): void => {
              this.kind = 'image'
            }, false)
            this.filterChip('视频', this.kind === 'video', (): void => {
              this.kind = 'video'
            }, false)
          }.width('90%').margin({ top: 12 })

          // 时间筛选
          Row({ space: 8 }) {
            Text('上传时间').fontSize(11).fontColor($r('app.color.text_hint'))
            this.filterChip('全部', this.timeRange === 'all', (): void => {
              this.timeRange = 'all'
            }, false)
            this.filterChip('近 7 天', this.timeRange === '7', (): void => {
              this.timeRange = '7'
            }, false)
            this.filterChip('近 30 天', this.timeRange === '30', (): void => {
              this.timeRange = '30'
            }, false)
          }.width('90%').margin({ top: 8, bottom: 8 })

          // 云端策略
          Column({ space: 8 }) {
            Row({ space: 6 }) {
              Text('☁️').fontSize(14)
              Text(`云端存储（本地模拟） · 保留 ${this.retention} 天后自动清理`)
                .fontSize(11).fontColor($r('app.color.text_sub')).layoutWeight(1)
            }.width('100%')
            if (currentRole() === 'teacher') {
              Row({ space: 8 }) {
                Text('清理策略').fontSize(10).fontColor($r('app.color.text_hint'))
                this.filterChip('7 天', this.retention === 7, (): void => {
                  setRetentionDays(7)
                  this.retention = 7
                  promptAction.showToast({ message: '新归档文件保留 7 天（本地模拟）' })
                }, false)
                this.filterChip('30 天', this.retention === 30, (): void => {
                  setRetentionDays(30)
                  this.retention = 30
                  promptAction.showToast({ message: '新归档文件保留 30 天（本地模拟）' })
                }, false)
                this.filterChip('90 天', this.retention === 90, (): void => {
                  setRetentionDays(90)
                  this.retention = 90
                  promptAction.showToast({ message: '新归档文件保留 90 天（本地模拟）' })
                }, false)
                Blank()
                Text('清理过期')
                  .fontSize(10).fontColor('#EF4444')
                  .onClick(() => this.clean())
              }.width('100%')
            } else {
              Text('仅授课教师可调整云端清理策略。')
                .fontSize(9).fontColor($r('app.color.text_hint')).width('100%')
            }
          }
          .width('90%').padding(12).margin({ bottom: 12 })
          .backgroundColor($r('app.color.card_bg')).borderRadius(12)

          Row() {
            Text(`文件列表 · ${this.totalSize()}`).fontSize(11).fontColor($r('app.color.text_hint'))
            Blank()
            if (this.selectMode) {
              Text(this.selected.length === this.files().length && this.files().length > 0 ? '取消全选' : '全选')
                .fontSize(11).fontColor($r('app.color.primary'))
                .onClick(() => this.toggleAll())
            }
          }.width('90%').padding({ left: 4, bottom: 6 })

          Column() {
            if (this.files().length === 0) {
              Text('该分类下暂无归档文件').fontSize(12).fontColor($r('app.color.text_hint'))
                .width('100%').padding(24).textAlign(TextAlign.Center)
            } else {
              ForEach(this.files(), (f: GroupFile) => {
                this.fileRow(f)
              }, (f: GroupFile) => f.id)
            }
          }
          .width('90%').backgroundColor($r('app.color.card_bg')).borderRadius(14)
          .padding({ top: 4, bottom: 4 })

          if (this.selectMode) {
            Text(`批量下载（${this.selected.length}）`)
              .fontSize(14).fontColor(Color.White)
              .width('90%').height(44).textAlign(TextAlign.Center)
              .backgroundColor(this.selected.length > 0 ? $r('app.color.primary') : $r('app.color.text_hint'))
              .borderRadius(22).margin({ top: 14 })
              .onClick(() => this.batchDownload())
          }

          Text('说明：群内文件发送后自动归档；云端存储、下载与过期清理均为本地模拟，未接入真实对象存储。')
            .fontSize(10).fontColor($r('app.color.text_hint'))
            .width('90%').padding({ top: 12, left: 4, bottom: 40 })
        }.width('100%')
      }
      .layoutWeight(1).align(Alignment.Top).scrollBar(BarState.Off)
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
