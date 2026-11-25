import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';
import { SubjectConfig, Stage, subjectsByStage, stageName } from '../../model/SubjectModel';

// ==================== 学科课程（嵌入「课程」Tab 页） ====================
// 20 门学科按 小学 / 初中 / 大学 分组，点击进入对应学科课程页
// 注意：作为区块嵌入 CoursePage 的滚动容器，自身不再嵌套 Scroll
@Component
export struct SubjectHubView {
  @State query: string = ''

  filtered(stage: Stage): SubjectConfig[] {
    return subjectsByStage(stage).filter((s: SubjectConfig) => {
      return this.query === '' || s.name.includes(this.query)
    })
  }

  // 🌟 正方形网格：每行 3 个等宽等高方块，适配不同屏宽
  chunk(list: SubjectConfig[]): SubjectConfig[][] {
    let rows: SubjectConfig[][] = []
    for (let i = 0; i < list.length; i += 3) {
      rows.push(list.slice(i, i + 3))
    }
    return rows
  }

  @Builder
  subjectSquare(s: SubjectConfig) {
    Column({ space: 6 }) {
      Text(s.name.slice(0, 1))
        .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .width(34).height(34).borderRadius(10)
        .backgroundColor(s.c1)
        .textAlign(TextAlign.Center)
        .shadow({ radius: 6, color: `${s.c1}55`, offsetY: 3 })
      Text(s.name)
        .fontSize(11.5).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%').textAlign(TextAlign.Center)
      Text(`${s.modules.length} 模块`)
        .fontSize(9).fontColor($r('app.color.text_hint'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%').textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .aspectRatio(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(6)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.03)', offsetY: 3 })
    .onClick(() => {
      router.pushUrl({ url: s.page })
    })
  }

  @Builder
  stageSection(stage: Stage) {
    if (this.filtered(stage).length > 0) {
      Column({ space: 12 }) {
        Row({ space: 8 }) {
          Row().width(4).height(14).borderRadius(2).backgroundColor($r('app.color.primary'))
          Text(stageName(stage)).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Text(stage === 'primary' ? '柔和趣味' : (stage === 'middle' ? '专业简约' : '备考复习'))
            .fontSize(10).fontColor($r('app.color.text_hint'))
          Blank()
          Text(`${this.filtered(stage).length} 门`).fontSize(11).fontColor($r('app.color.text_hint'))
        }.width('100%')

        // 🌟 学科方块网格：等宽等高正方形，末尾用占位块保持列宽一致
        Column({ space: 10 }) {
          ForEach(this.chunk(this.filtered(stage)), (row: SubjectConfig[]) => {
            Row({ space: 10 }) {
              this.subjectSquare(row[0])
              if (row.length > 1) {
                this.subjectSquare(row[1])
              } else {
                Column().layoutWeight(1).aspectRatio(1)
              }
              if (row.length > 2) {
                this.subjectSquare(row[2])
              } else {
                Column().layoutWeight(1).aspectRatio(1)
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }, (row: SubjectConfig[]) => row[0].id)
        }.width('100%')
      }
      .width('90%')
      .margin({ top: 16 })
    }
  }

  build() {
    Column() {
      // 搜索框
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(16).fontColor([$r('app.color.text_hint')])
        TextInput({ text: this.query, placeholder: '搜索学科，如：物理' })
          .backgroundColor(Color.Transparent)
          .padding(0)
          .layoutWeight(1)
          .onChange((v: string) => {
            this.query = v
          })
        if (this.query !== '') {
          Text('清空').fontSize(12).fontColor($r('app.color.primary'))
            .onClick(() => {
              this.query = ''
              promptAction.showToast({ message: '已清空搜索' })
            })
        }
      }
      .width('90%')
      .padding({ left: 14, right: 14 })
      .height(42)
      .backgroundColor($r('app.color.field_bg'))
      .borderRadius(21)
      .margin({ top: 4 })

      this.stageSection('primary')
      this.stageSection('middle')
      this.stageSection('uni')
    }
    .width('100%')
  }
}
