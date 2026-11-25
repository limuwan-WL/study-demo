import { LanguageCoursePage } from './LanguageCoursePage';

// 韩语 · 大学（复用现有 8 门韩语分级课程，共 40 课时）
@Entry
@Component
struct KoreanPage {
  build() {
    Column() {
      LanguageCoursePage({ lang: 'ko', title: '韩语', color: '#8B5CF6' })
    }
    .width('100%')
    .height('100%')
  }
}
