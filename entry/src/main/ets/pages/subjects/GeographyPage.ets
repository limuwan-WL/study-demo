import { SubjectPageView } from './SubjectPageView';

// 地理 · 初中简约风（白色导航 + 下划线标签 + 顶部色条卡）
@Entry
@Component
struct GeographyPage {
  build() {
    Column() {
      SubjectPageView({ subjectId: 'geography' })
    }
    .width('100%')
    .height('100%')
  }
}
