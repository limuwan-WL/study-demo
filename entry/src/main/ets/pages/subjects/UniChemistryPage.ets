import { SubjectPageView } from './SubjectPageView';

// 大学化学 · 备考风（实色导航 + 描边标签 + 左色条列表行）
@Entry
@Component
struct UniChemistryPage {
  build() {
    Column() {
      SubjectPageView({ subjectId: 'unichem' })
    }
    .width('100%')
    .height('100%')
  }
}
