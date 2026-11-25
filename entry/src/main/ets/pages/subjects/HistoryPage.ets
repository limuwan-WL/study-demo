import { SubjectPageView } from './SubjectPageView';

// 历史 · 初中学术风（深色导航 + 实色圆片 + 时间轴列表）
@Entry
@Component
struct HistoryPage {
  build() {
    Column() {
      SubjectPageView({ subjectId: 'history' })
    }
    .width('100%')
    .height('100%')
  }
}
