import { LanguageCoursePage } from './LanguageCoursePage';

// 日语 · 大学（复用日语分级课程，8 门 × 5 课时，共 40 课时）
@Entry
@Component
struct JapanesePage {
  build() {
    Column() {
      LanguageCoursePage({ lang: 'ja', title: '日语', color: '#E85D75' })
    }
    .width('100%')
    .height('100%')
  }
}
