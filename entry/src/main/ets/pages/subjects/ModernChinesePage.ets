import { LanguageCoursePage } from './LanguageCoursePage';

// 现代汉语 · 大学（与日语/韩语统一为语种课程内页：互动学习 + 分级课程 + 学习进度）
@Entry
@Component
struct ModernChinesePage {
  build() {
    Column() {
      LanguageCoursePage({ lang: 'zh', title: '现代汉语', color: '#BA6878' })
    }
    .width('100%')
    .height('100%')
  }
}
