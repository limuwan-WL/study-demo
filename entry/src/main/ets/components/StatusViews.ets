// ==================== 通用状态视图：空状态引导 + 离线提示条 ====================
// 所有列表页统一使用 EmptyState，避免各页面各写一套空态。
@Component
export struct EmptyState {
  icon: Resource = $r('sys.symbol.inbox')
  title: string = '暂无数据'
  desc: string = ''
  actionLabel: string = ''
  onAction: () => void = () => {
  }

  build() {
    Column({ space: 10 }) {
      Column() {
        SymbolGlyph(this.icon).fontSize(34).fontColor([$r('app.color.text_hint')])
      }
      .width(72).height(72).borderRadius(36)
      .backgroundColor($r('app.color.field_bg'))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Text(this.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
        .margin({ top: 4 })
      if (this.desc !== '') {
        Text(this.desc).fontSize(12).fontColor($r('app.color.text_hint'))
          .textAlign(TextAlign.Center)
          .padding({ left: 32, right: 32 })
      }
      if (this.actionLabel !== '') {
        Text(this.actionLabel)
          .fontSize(13).fontWeight(FontWeight.Medium).fontColor(Color.White)
          .padding({ left: 18, right: 18, top: 9, bottom: 9 })
          .backgroundColor($r('app.color.primary'))
          .borderRadius(18)
          .margin({ top: 6 })
          .onClick(() => this.onAction())
      }
    }
    .width('100%')
    .padding({ top: 64, bottom: 48 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

// 离线 / 弱网提示条：编辑区域顶部使用
@Component
export struct OfflineBar {
  text: string = '当前为弱网离线状态，编辑内容将暂存在本机，联网后自动同步'
  @StorageLink('networkOnline') networkOnline: boolean = true

  build() {
    if (!this.networkOnline) {
      Row({ space: 8 }) {
        Row().width(8).height(8).borderRadius(4).backgroundColor('#F59E0B')
        Text(this.text).fontSize(11).fontColor('#B45309').layoutWeight(1)
        Text('离线').fontSize(10).fontColor(Color.White)
          .backgroundColor('#F59E0B')
          .padding({ left: 6, right: 6, top: 1, bottom: 1 })
          .borderRadius(6)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor('#FEF3C7')
      .borderRadius(10)
    }
  }
}
