import { SubjectPageView } from './SubjectPageView';

// 语文 · 小学柔和风（渐变大标题 + 药丸筛选 + 横幅图卡瀑布流）
@Entry
@Component
struct ChinesePage {
  build() {
    Column() {
      SubjectPageView({ subjectId: 'chinese' })
    }
    .width('100%')
    .height('100%')
  }
}
