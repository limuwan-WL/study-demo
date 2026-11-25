import { SubjectPageView } from './SubjectPageView';

// 大学物理 · 备考风（极简导航 + 描边标签 + 密集进度卡）
@Entry
@Component
struct UniPhysicsPage {
  build() {
    Column() {
      SubjectPageView({ subjectId: 'uniphysics' })
    }
    .width('100%')
    .height('100%')
  }
}
