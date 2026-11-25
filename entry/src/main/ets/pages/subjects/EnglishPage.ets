import { SubjectPageView } from './SubjectPageView';

// 英语 · 小学柔和风（渐变大标题 + 药丸筛选 + 横幅图卡瀑布流）
@Entry
@Component
struct EnglishPage {
  build() {
    Column() {
      SubjectPageView({ subjectId: 'english' })
    }
    .width('100%')
    .height('100%')
  }
}
