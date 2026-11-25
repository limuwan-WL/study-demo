import { SubjectPageView } from './SubjectPageView';

// 计算机基础 · 备考风（深色终端导航 + 描边标签 + 深色代码卡单列）
@Entry
@Component
struct CSBasicsPage {
  build() {
    Column() {
      SubjectPageView({ subjectId: 'csbasic' })
    }
    .width('100%')
    .height('100%')
  }
}
