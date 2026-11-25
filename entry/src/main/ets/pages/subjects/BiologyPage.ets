import { SubjectPageView } from './SubjectPageView';

// 生物 · 初中简约风（白色导航 + 药丸筛选 + 顶部色条卡）
@Entry
@Component
struct BiologyPage {
  build() {
    Column() {
      SubjectPageView({ subjectId: 'biology' })
    }
    .width('100%')
    .height('100%')
  }
}
