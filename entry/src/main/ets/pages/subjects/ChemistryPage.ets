import { SubjectPageView } from './SubjectPageView';

// 化学 · 初中专业风（实色导航 + 描边标签 + 左色条列表行）
@Entry
@Component
struct ChemistryPage {
  build() {
    Column() {
      SubjectPageView({ subjectId: 'chemistry' })
    }
    .width('100%')
    .height('100%')
  }
}
