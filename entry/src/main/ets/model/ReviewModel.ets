// ==================== 讲师匿名评价 ====================
// 🌟 学生可对授课教师提交匿名评价，教师端仅能看到匿名化后的评分与内容；
//    数据保存在本机（PersistProp: teacherReviews），无真实后端。
export class TeacherReview {
  id: string = ''
  teacherId: string = ''
  teacherName: string = ''
  rating: number = 5
  content: string = ''
  courseName: string = ''
  createdAt: number = 0
}

export class TeacherReviewStore {
  static of(teacherId: string): TeacherReview[] {
    let list = AppStorage.get<TeacherReview[]>('teacherReviews') ?? []
    return list.filter((r: TeacherReview) => r.teacherId === teacherId)
      .sort((a: TeacherReview, b: TeacherReview) => b.createdAt - a.createdAt)
  }

  // 同一学生对同一教师仅可评价一次，避免刷评
  static hasReviewed(teacherId: string, reviewer: string): boolean {
    let list = AppStorage.get<TeacherReview[]>('teacherReviews') ?? []
    return list.some((r: TeacherReview) => r.teacherId === teacherId && r.id.indexOf(`_${reviewer}_`) >= 0)
  }

  // 提交评价：返回空串表示成功，否则返回具体失败原因
  static add(teacherId: string, teacherName: string, reviewer: string, rating: number,
    content: string, courseName: string): string {
    if (rating < 1 || rating > 5) {
      return '请选择 1-5 星评分'
    }
    let text = content.trim()
    if (text.length < 5) {
      return '评价内容至少 5 个字，便于老师改进教学'
    }
    if (TeacherReviewStore.hasReviewed(teacherId, reviewer)) {
      return '你已评价过该教师，暂不支持重复评价'
    }
    let r = new TeacherReview()
    r.id = `rev_${teacherId}_${reviewer}_${Date.now()}`
    r.teacherId = teacherId
    r.teacherName = teacherName
    r.rating = rating
    r.content = text
    r.courseName = courseName
    r.createdAt = Date.now()
    let list = AppStorage.get<TeacherReview[]>('teacherReviews') ?? []
    AppStorage.setOrCreate('teacherReviews', [r].concat(list))
    return ''
  }

  // 匿名展示名：不暴露学生昵称与学号
  static anonymousName(r: TeacherReview): string {
    let seq = r.id.length % 97
    return `匿名同学 ${seq < 10 ? '0' + seq : seq}`
  }
}
