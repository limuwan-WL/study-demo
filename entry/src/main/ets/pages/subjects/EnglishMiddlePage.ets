import { SubjectPageView } from './SubjectPageView';

// 英语 · 初中（沿用英语学习页结构，按 7~9 年级人教版组织）
@Entry
@Component
struct EnglishMiddlePage {
  build() {
    Column() {
      SubjectPageView({ subjectId: 'englishmiddle' })
    }
    .width('100%')
    .height('100%')
  }
}
