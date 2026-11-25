import { SubjectPageView } from './SubjectPageView';

// 数学 · 小学柔和风（渐变大标题 + 药丸筛选 + 顶部色条卡瀑布流）
@Entry
@Component
struct MathPage {
  build() {
    Column() {
      SubjectPageView({ subjectId: 'math' })
    }
    .width('100%')
    .height('100%')
  }
}
