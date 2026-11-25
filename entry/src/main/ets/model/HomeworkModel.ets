// ==================== 班级作业 + 班级群 + 老师成就 数据模型 ====================
// 🌟 单机演示：作业、提交、群消息均持久化在 AppStorage，多角色通过切换登录体验

export class Homework {
  id: string = ''
  title: string = ''
  content: string = ''
  teacher: string = ''
  time: number = 0
}

// 提交类型：text 文字 / photo 照片 / video 视频 / audio 录音
export class HomeworkSubmission {
  id: string = ''
  homeworkId: string = ''
  student: string = ''
  type: string = 'text'
  text: string = ''
  attachment: string = '' // 附件说明（演示环境记录类型与数量，如「照片×2」「录音 15″」）
  time: number = 0
  // 🌟 教师批阅结果：score < 0 表示未批阅；annotation 为文字批注
  score: number = -1
  annotation: string = ''
}

// 🌟 内置一份「已批阅」作业：消息「点击查看批注」需要有对应的作业与批注数据
export const SEED_HW_ID = 'hw_seed_1'

export function ensureGradedHomework(student: string): void {
  let list = AppStorage.get<Homework[]>('hwList')
  if (list === undefined) {
    list = []
  }
  if (list.filter((h: Homework) => h.id === SEED_HW_ID).length === 0) {
    let h = new Homework()
    h.id = SEED_HW_ID
    h.title = '数据结构第 3 章作业'
    h.content = '完成第 3 章课后习题 1-8 题，重点理解栈与队列的应用'
    h.teacher = '王老师'
    h.time = Date.now() - 3 * 3600000
    AppStorage.setOrCreate<Homework[]>('hwList', [h].concat(list))
  }
  let subs = AppStorage.get<HomeworkSubmission[]>('hwSubs')
  if (subs === undefined) {
    subs = []
  }
  let mine = subs.filter((s: HomeworkSubmission) =>
  s.homeworkId === SEED_HW_ID && s.student === student)
  if (student !== '' && mine.length === 0) {
    let sub = new HomeworkSubmission()
    sub.id = `sub_seed_${student}`
    sub.homeworkId = SEED_HW_ID
    sub.student = student
    sub.type = 'text'
    sub.text = '已完成第 3 章习题 1-8 题。第 5 题栈空的边界处理把握不大，请老师指正。'
    sub.time = Date.now() - 2 * 3600000
    sub.score = 92
    sub.annotation = '整体思路清晰，答题规范。第 5 题在栈为空时的边界条件需要再检查；另外代码缩进统一一下会更好。'
    AppStorage.setOrCreate<HomeworkSubmission[]>('hwSubs', subs.concat([sub]))
  }
}


export class GroupMsg {
  id: string = ''
  name: string = ''
  role: string = 'student' // student / assistant / teacher（老师为群主）
  text: string = ''
  time: number = 0
  // 🌟 消息类型：text 文字 / image 图片 / video 视频 / file 文件 / sticker 表情包 / system 系统通知
  kind: string = 'text'
  media: string = '' // 图片 / 视频的本地 URI
  recalled: boolean = false // 是否已撤回
  // 🌟 文件消息：名称 / 体积 / 本地 URI
  fileName: string = ''
  fileSize: string = ''
  fileUri: string = ''
  // 🌟 @ 指定成员：记录被提及的成员名
  mentions: string[] = []
}

// 🌟 班级群成员：教师为群主，助教与普通学生为群成员
export class GroupMember {
  id: string = ''
  name: string = ''
  role: string = 'student' // student / assistant / teacher
  nick: string = ''
  joinedAt: number = 0
  removed: boolean = false

  constructor(name: string, role: string) {
    this.id = `gm_${name}_${role}`
    this.name = name
    this.role = role
    this.joinedAt = Date.now()
  }
}

export function subsOf(homeworkId: string, subs: HomeworkSubmission[]): HomeworkSubmission[] {
  return subs.filter((s: HomeworkSubmission) => s.homeworkId === homeworkId)
}

export function mySub(homeworkId: string, student: string, subs: HomeworkSubmission[]): HomeworkSubmission | undefined {
  let hit = subs.filter((s: HomeworkSubmission) => s.homeworkId === homeworkId && s.student === student)
  return hit.length > 0 ? hit[0] : undefined
}

export function subTypeName(type: string): string {
  if (type === 'photo') {
    return '照片'
  }
  if (type === 'video') {
    return '视频'
  }
  if (type === 'audio') {
    return '录音'
  }
  return '文字'
}

export function fmtTime(t: number): string {
  let d = new Date(t)
  return `${d.getMonth() + 1}月${d.getDate()}日 ${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`
}

// ==================== 班级学生名册（演示数据，老师端查看学习进度） ====================

export class StudentProgress {
  name: string = ''
  lessons: number = 0 // 已完成课时
  words: number = 0 // 掌握单词
  minutes: number = 0 // 累计学习分钟
  checkins: number = 0 // 打卡次数

  constructor(name: string, lessons: number, words: number, minutes: number, checkins: number) {
    this.name = name
    this.lessons = lessons
    this.words = words
    this.minutes = minutes
    this.checkins = checkins
  }
}

export function mockStudentProgress(): StudentProgress[] {
  return [
    new StudentProgress('王小明', 12, 45, 186, 5),
    new StudentProgress('李小红', 8, 30, 124, 3),
    new StudentProgress('张一凡', 15, 62, 215, 7),
    new StudentProgress('刘思远', 5, 18, 76, 2),
    new StudentProgress('陈雨欣', 9, 36, 152, 4)
  ]
}

// 🌟 班级群成员：老师为群主，学生为群成员
export function groupMembers(): GroupMember[] {
  let list: GroupMember[] = [new GroupMember('张老师', 'teacher')]
  mockStudentProgress().forEach((s: StudentProgress) => {
    list.push(new GroupMember(s.name, 'student'))
  })
  return list
}

// ==================== 老师成就墙 ====================
// 🌟 老师成就与学生成就相互独立：围绕布置作业、批改提交、班级互动、学生成长解锁

export class TeacherAchievement {
  id: string = ''
  name: string = ''
  desc: string = ''
  icon: Resource
  color: string = ''

  constructor(id: string, name: string, desc: string, icon: Resource, color: string) {
    this.id = id
    this.name = name
    this.desc = desc
    this.icon = icon
    this.color = color
  }
}

export const TEACHER_ACHIEVEMENTS: TeacherAchievement[] = [
  new TeacherAchievement('t_first', '初为人师', '布置第 1 次作业', $r('sys.symbol.star_fill'), '#E8B93E'),
  new TeacherAchievement('t_hw5', '勤勉耕耘', '累计布置 5 次作业', $r('sys.symbol.book'), '#8B5CF6'),
  new TeacherAchievement('t_sub1', '第一份作业', '收到第 1 份学生提交', $r('sys.symbol.leaf_fill'), '#55C873'),
  new TeacherAchievement('t_sub10', '悉心批改', '累计收到 10 份作业提交', $r('sys.symbol.checkmark_circle'), '#14B8A6'),
  new TeacherAchievement('t_speak', '班级之声', '在班级群发送第 1 条消息', $r('sys.symbol.face_smiling'), '#0EA5E9'),
  new TeacherAchievement('t_active', '热火朝天', '班级群消息达到 30 条', $r('sys.symbol.flame_fill'), '#F97316'),
  new TeacherAchievement('t_view', '洞察学情', '查看学生学习进度', $r('sys.symbol.person_filled_badge_plus'), '#6366F1'),
  new TeacherAchievement('t_master', '桃李满门', '班级累计完成 50 节课', $r('sys.symbol.heart_fill'), '#EF4444')
]

// 🌟 计算老师已解锁成就：本地真实数据（作业/提交/群消息）+ 名册汇总
export function teacherUnlockedIds(nickname: string, localLessons: number): string[] {
  let hw = AppStorage.get<Homework[]>('hwList')
  let subs = AppStorage.get<HomeworkSubmission[]>('hwSubs')
  let msgs = AppStorage.get<GroupMsg[]>('classGroupMsgs')
  let hwCount = hw === undefined ? 0 : hw.length
  let subCount = subs === undefined ? 0 : subs.length
  let msgCount = msgs === undefined ? 0 : msgs.length
  let myMsgCount = 0
  if (msgs !== undefined) {
    // 老师发言按角色统计，改过本群昵称也不影响成就解锁
    myMsgCount = msgs.filter((m: GroupMsg) => m.role === 'teacher').length
  }
  let viewed = AppStorage.get<boolean>('t_viewedProgress')
  let totalLessons = localLessons
  mockStudentProgress().forEach((s: StudentProgress) => {
    totalLessons += s.lessons
  })

  let ids: string[] = []
  if (hwCount >= 1) {
    ids.push('t_first')
  }
  if (hwCount >= 5) {
    ids.push('t_hw5')
  }
  if (subCount >= 1) {
    ids.push('t_sub1')
  }
  if (subCount >= 10) {
    ids.push('t_sub10')
  }
  if (myMsgCount >= 1) {
    ids.push('t_speak')
  }
  if (msgCount >= 30) {
    ids.push('t_active')
  }
  if (viewed === true) {
    ids.push('t_view')
  }
  if (totalLessons >= 50) {
    ids.push('t_master')
  }
  return ids
}
