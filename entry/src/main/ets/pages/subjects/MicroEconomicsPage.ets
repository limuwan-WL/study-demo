import { SubjectPageView } from './SubjectPageView';

// 微观经济学 · 备考风（实色导航 + 描边标签 + 密集进度卡）
@Entry
@Component
struct MicroEconomicsPage {
  build() {
    Column() {
      SubjectPageView({ subjectId: 'microecon' })
    }
    .width('100%')
    .height('100%')
  }
}
