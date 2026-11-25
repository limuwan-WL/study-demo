// ==================== 全局权限模型（集中式，避免各页面重复写死） ====================
// 🌟 当前工程为本地模拟数据，无真实后端：角色、课程成员、助教名单均持久化在 AppStorage。
//    所有页面统一通过本文件判断「能看什么 / 能做什么」，新增角色或动作只需改这里。
import { NoteItem, Teacher, TeacherCourse } from './DataModel'
import { StudentProgress, mockStudentProgress } from './HomeworkModel'

export type UserRole = 'student' | 'teacher' | 'assistant' | 'admin'

// 细粒度动作：页面按钮 / 数据入口统一引用这些常量
export class Action {
  static readonly COURSE_VIEW: string = 'course.view'
  static readonly COURSE_JOIN: string = 'course.join'
  static readonly COURSE_MANAGE_BASE: string = 'course.manageBase'
  static readonly COURSE_POINT_RULE: string = 'course.pointRule'
  static readonly COURSE_DELETE: string = 'course.delete'
  static readonly COURSE_STUDENT_VIEW: string = 'course.studentView'
  static readonly HOMEWORK_GRADE: string = 'homework.grade'
  static readonly TASK_MANAGE: string = 'task.manage'
  static readonly SIGNIN_PUBLISH: string = 'signin.publish'
  static readonly QUESTION_EDIT: string = 'question.edit'
  static readonly ASSISTANT_MANAGE: string = 'assistant.manage'
  static readonly GROUP_ENTER: string = 'group.enter'
  static readonly GROUP_NOTICE: string = 'group.notice'
  static readonly GROUP_LEDGER: string = 'group.ledger'
  static readonly GROUP_REPORT: string = 'group.report'
  static readonly NOTE_COURSE: string = 'note.course'
  static readonly NOTE_PUBLIC: string = 'note.public'
  static readonly RECHARGE: string = 'wallet.recharge'
  static readonly ADMIN_CONSOLE: string = 'admin.console'
}

// 各角色允许的动作：未列出即默认拒绝（ArkTS 不允许 Record 对象字面量，改用函数返回）
function roleActions(role: UserRole): string[] {
  if (role === 'student') {
    return [
      Action.COURSE_VIEW, Action.COURSE_JOIN, Action.GROUP_ENTER, Action.GROUP_REPORT,
      Action.NOTE_COURSE, Action.NOTE_PUBLIC, Action.RECHARGE, 'homework.submit',
      'checkin.join', 'note.private'
    ]
  }
  if (role === 'assistant') {
    return [
      Action.COURSE_VIEW, Action.GROUP_ENTER, Action.GROUP_NOTICE, Action.GROUP_LEDGER,
      Action.GROUP_REPORT, Action.HOMEWORK_GRADE, Action.TASK_MANAGE, Action.SIGNIN_PUBLISH,
      Action.NOTE_COURSE, Action.NOTE_PUBLIC, Action.COURSE_STUDENT_VIEW,
      'homework.submit', 'checkin.join', 'note.private'
    ]
  }
  if (role === 'teacher') {
    return [
      Action.COURSE_VIEW, Action.COURSE_MANAGE_BASE, Action.COURSE_POINT_RULE, Action.COURSE_DELETE,
      Action.COURSE_STUDENT_VIEW, Action.HOMEWORK_GRADE, Action.TASK_MANAGE, Action.SIGNIN_PUBLISH,
      Action.QUESTION_EDIT, Action.ASSISTANT_MANAGE, Action.GROUP_ENTER, Action.GROUP_NOTICE,
      Action.GROUP_LEDGER, Action.GROUP_REPORT, Action.NOTE_COURSE, Action.NOTE_PUBLIC,
      'checkin.join', 'note.private'
    ]
  }
  return [
    Action.COURSE_VIEW, Action.COURSE_MANAGE_BASE, Action.COURSE_POINT_RULE, Action.COURSE_DELETE,
    Action.COURSE_STUDENT_VIEW, Action.HOMEWORK_GRADE, Action.TASK_MANAGE, Action.SIGNIN_PUBLISH,
    Action.QUESTION_EDIT, Action.ASSISTANT_MANAGE, Action.GROUP_ENTER, Action.GROUP_NOTICE,
    Action.GROUP_LEDGER, Action.GROUP_REPORT, Action.NOTE_COURSE, Action.NOTE_PUBLIC,
    Action.RECHARGE, Action.ADMIN_CONSOLE, 'homework.submit', 'checkin.join', 'note.private'
  ]
}

// 默认加入的演示课程（首次启动灌入，之后以用户实际加入为准）
const DEFAULT_ENROLLED: string[] = ['csbasic', 'english', 'advmath']

export class Permission {
  static role(): UserRole {
    let r = AppStorage.get<string>('userRole') ?? 'student'
    if (r === 'teacher' || r === 'assistant' || r === 'admin') {
      return r as UserRole
    }
    return 'student'
  }

  static is(role: string): boolean {
    return Permission.role() === role
  }

  static isStudent(): boolean {
    return Permission.role() === 'student'
  }

  static isTeacher(): boolean {
    return Permission.role() === 'teacher'
  }

  static isAssistant(): boolean {
    return Permission.role() === 'assistant'
  }

  static roleLabel(role: string = Permission.role()): string {
    if (role === 'teacher') {
      return '授课教师'
    }
    if (role === 'assistant') {
      return '助教'
    }
    if (role === 'admin') {
      return '后台管理员'
    }
    return '学生'
  }

  static roleShortLabel(role: string = Permission.role()): string {
    if (role === 'teacher') {
      return '教师'
    }
    if (role === 'assistant') {
      return '助教'
    }
    if (role === 'admin') {
      return '管理员'
    }
    return '学生'
  }

  static roleColor(role: string = Permission.role()): string {
    if (role === 'teacher') {
      return '#E8A33E'
    }
    if (role === 'assistant') {
      return '#8B5CF6'
    }
    if (role === 'admin') {
      return '#EF4444'
    }
    return '#3F7EF6'
  }

  // ==================== 动作权限 ====================
  static hasAction(action: string): boolean {
    let list = roleActions(Permission.role())
    return list !== undefined && list.indexOf(action) >= 0
  }

  static deniedReason(action: string): string {
    if (Permission.isAssistant()) {
      if (action === Action.COURSE_MANAGE_BASE || action === Action.COURSE_POINT_RULE ||
        action === Action.COURSE_DELETE) {
        return '助教不可修改课程基础配置、学分规则或删除课程'
      }
      if (action === Action.QUESTION_EDIT) {
        return '助教仅可协助教学，题库维护由授课教师负责'
      }
      return '当前助教身份无权执行该操作'
    }
    if (Permission.isStudent()) {
      return '学生身份无权执行该操作'
    }
    return '当前身份无权执行该操作'
  }

  // ==================== 课程成员 ====================
  static enrolledCourses(): string[] {
    return AppStorage.get<string[]>('enrolledCourses') ?? []
  }

  // 首次启动灌入默认演示课程；用户主动退出全部课程后不会因重启被重新灌入
  static ensureEnrollmentSeed(): void {
    if (AppStorage.get<boolean>('enrollmentSeeded') === true) {
      return
    }
    AppStorage.setOrCreate<boolean>('enrollmentSeeded', true)
    if (Permission.enrolledCourses().length === 0) {
      AppStorage.setOrCreate<string[]>('enrolledCourses', DEFAULT_ENROLLED.slice())
    }
  }

  static isEnrolled(courseKey: string): boolean {
    return Permission.enrolledCourses().indexOf(courseKey) >= 0
  }

  static joinCourse(courseKey: string): boolean {
    if (courseKey === '' || Permission.isEnrolled(courseKey)) {
      return false
    }
    AppStorage.setOrCreate<string[]>('enrolledCourses', Permission.enrolledCourses().concat([courseKey]))
    return true
  }

  static leaveCourse(courseKey: string): boolean {
    let list = Permission.enrolledCourses()
    if (list.indexOf(courseKey) < 0) {
      return false
    }
    AppStorage.setOrCreate<string[]>('enrolledCourses', list.filter((k: string) => k !== courseKey))
    return true
  }

  // 我授课的课程（教师）：来自讲师主页数据中 type=local 的课程
  static myTeachingCourses(): TeacherCourse[] {
    let teachers = AppStorage.get<Teacher[]>('teacherList') ?? []
    let myId = AppStorage.get<string>('myTeacherId') ?? ''
    let me = teachers.find((t: Teacher) => t.id === myId)
    if (me === undefined) {
      return []
    }
    return me.courses.filter((c: TeacherCourse) => c.type === 'local')
  }

  static ownsSubject(subjectId: string): boolean {
    return Permission.myTeachingCourses().some((c: TeacherCourse) => c.subjectId === subjectId)
  }

  // 助教被分配协助的课程
  static assistantCourses(name: string = ''): AssistantInfo[] {
    let who = name === '' ? (AppStorage.get<string>('nickname') ?? '') : name
    return assistants().filter((a: AssistantInfo) => a.name === who)
  }

  static assistsSubject(subjectId: string, name: string = ''): boolean {
    return Permission.assistantCourses(name).some((a: AssistantInfo) => a.courseKey === subjectId)
  }

  // 能否进入某门课程：学生看是否已加入；教师看是否自己授课；助教看是否被分配
  static canAccessCourse(subjectId: string): boolean {
    if (Permission.role() === 'admin') {
      return true
    }
    if (Permission.isTeacher()) {
      return Permission.ownsSubject(subjectId)
    }
    if (Permission.isAssistant()) {
      return Permission.assistsSubject(subjectId)
    }
    return Permission.isEnrolled(subjectId)
  }

  static courseDeniedReason(subjectId: string): string {
    if (Permission.isTeacher()) {
      return '该课程不在您的授课范围内，无法查看其他班级数据'
    }
    if (Permission.isAssistant()) {
      return '您尚未被主讲教师分配到该课程'
    }
    return '您尚未加入该课程，加入后才能访问课程页面与班级群'
  }

  // ==================== 教师数据隔离 ====================
  // 名册只对「该课程授课教师 / 被分配的助教 / 管理员」开放，学生不能查看他人数据
  static canViewStudents(subjectId: string): boolean {
    if (Permission.role() === 'admin') {
      return true
    }
    if (Permission.isTeacher()) {
      return Permission.ownsSubject(subjectId)
    }
    if (Permission.isAssistant()) {
      return Permission.assistsSubject(subjectId)
    }
    return false
  }

  static visibleRoster(subjectId: string): StudentProgress[] {
    if (!Permission.canViewStudents(subjectId)) {
      return []
    }
    return mockStudentProgress()
  }

  // ==================== 笔记可见性 ====================
  // 本地笔记均属于当前登录账号：私有仅自己可见；课程可见需已加入课程；公开所有人可见
  static canViewNote(note: NoteItem): boolean {
    if (note.visibility === 'private') {
      return true
    }
    if (note.visibility === 'course') {
      // 🌟 绑定课程后按课程成员关系校验（学生需已加入该课，教师需授课，助教需被分配）
      let cid = note.courseId === undefined ? '' : note.courseId
      if (cid !== '') {
        return Permission.canAccessCourse(cid)
      }
      // 历史笔记没有 courseId：沿用旧规则，避免升级后旧笔记突然不可见
      if (Permission.isStudent()) {
        return Permission.enrolledCourses().length > 0
      }
      return true
    }
    return true
  }

  static visibleNotes(notes: NoteItem[]): NoteItem[] {
    return notes.filter((n: NoteItem) => Permission.canViewNote(n))
  }

  // 🌟 当前用户可绑定的课程（笔记课程可见等场景复用）
  static myCourseIds(): string[] {
    if (Permission.isStudent()) {
      return Permission.enrolledCourses()
    }
    if (Permission.isAssistant()) {
      return Permission.assistantCourses().map((a: AssistantInfo) => a.courseKey)
    }
    return Permission.myTeachingCourses().map((c: TeacherCourse) => c.subjectId)
  }

  // ==================== 我的页面入口 ====================
  static canSeeStudentEntries(): boolean {
    return Permission.isStudent()
  }

  static canSeeTeacherEntries(): boolean {
    return Permission.isTeacher()
  }

  static canSeeAssistantEntries(): boolean {
    return Permission.isAssistant()
  }
}

// ==================== 助教名单（由主讲教师添加） ====================
export class AssistantInfo {
  name: string = ''
  courseKey: string = ''
  courseName: string = ''
  addedBy: string = ''
  addedAt: number = 0
  permissions: string[] = []

  constructor(name: string, courseKey: string, courseName: string, addedBy: string) {
    this.name = name
    this.courseKey = courseKey
    this.courseName = courseName
    this.addedBy = addedBy
    this.addedAt = Date.now()
    // 助教权限范围：发布签到、查看台账、批阅作业、维护群公告
    this.permissions = ['发布签到任务', '查看各类台账', '批阅作业', '维护群公告']
  }
}

export function assistants(): AssistantInfo[] {
  return AppStorage.get<AssistantInfo[]>('assistantList') ?? []
}

function saveAssistants(list: AssistantInfo[]): void {
  AppStorage.setOrCreate<AssistantInfo[]>('assistantList', list)
}

// 返回空字符串表示成功，否则返回失败原因
export function addAssistant(name: string, courseKey: string): string {
  if (name.trim() === '') {
    return '助教姓名不能为空'
  }
  if (courseKey === '') {
    return '请先选择要协助的课程'
  }
  let exists = assistants().some((a: AssistantInfo) => a.name === name.trim() && a.courseKey === courseKey)
  if (exists) {
    return '该助教已在本课程中'
  }
  let myName = AppStorage.get<string>('nickname') ?? ''
  let courseName = courseKey
  let mine = Permission.myTeachingCourses().find((c: TeacherCourse) => c.subjectId === courseKey)
  if (mine !== undefined) {
    courseName = mine.name
  }
  saveAssistants(assistants().concat([new AssistantInfo(name.trim(), courseKey, courseName, myName)]))
  return ''
}

export function removeAssistant(name: string, courseKey: string): boolean {
  let list = assistants().filter((a: AssistantInfo) => !(a.name === name && a.courseKey === courseKey))
  if (list.length === assistants().length) {
    return false
  }
  saveAssistants(list)
  return true
}
