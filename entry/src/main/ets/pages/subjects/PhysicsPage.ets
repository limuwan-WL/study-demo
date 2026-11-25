import { SubjectPageView } from './SubjectPageView';

// 物理 · 初中简约风（白色极简导航 + 下划线标签 + 顶部色条卡）
@Entry
@Component
struct PhysicsPage {
  build() {
    Column() {
      SubjectPageView({ subjectId: 'physics' })
    }
    .width('100%')
    .height('100%')
  }
}
