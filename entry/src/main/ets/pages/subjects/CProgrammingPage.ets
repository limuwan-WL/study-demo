import { SubjectPageView } from './SubjectPageView';

// C语言程序设计 · 备考风（深色终端导航 + 描边标签 + 深色代码卡双列）
@Entry
@Component
struct CProgrammingPage {
  build() {
    Column() {
      SubjectPageView({ subjectId: 'clang' })
    }
    .width('100%')
    .height('100%')
  }
}
