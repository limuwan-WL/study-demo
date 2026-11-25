import { SubjectPageView } from './SubjectPageView';

// 高等数学 · 大学备考风（实色导航 + 描边标签 + 密集进度卡）
@Entry
@Component
struct AdvMathPage {
  build() {
    Column() {
      SubjectPageView({ subjectId: 'advmath' })
    }
    .width('100%')
    .height('100%')
  }
}
