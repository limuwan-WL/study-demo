import { SubjectPageView } from './SubjectPageView';

// 普通心理学 · 备考风（柔和导航 + 药丸筛选 + 顶部色条卡）
@Entry
@Component
struct PsychologyPage {
  build() {
    Column() {
      SubjectPageView({ subjectId: 'psychology' })
    }
    .width('100%')
    .height('100%')
  }
}
