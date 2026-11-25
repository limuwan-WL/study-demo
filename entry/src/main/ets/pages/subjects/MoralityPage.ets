import { SubjectPageView } from './SubjectPageView';

// 道德与法治 · 初中专业风（实色导航 + 描边标签 + 左色条列表行）
@Entry
@Component
struct MoralityPage {
  build() {
    Column() {
      SubjectPageView({ subjectId: 'morality' })
    }
    .width('100%')
    .height('100%')
  }
}
