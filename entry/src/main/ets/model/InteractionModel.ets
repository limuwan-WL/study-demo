// ==================== 教学互动任务模型 ====================
// 🌟 教师 / 助教在班级群内发起的签到、随堂练习、调查问卷、随机抽选统一收口到这里
// 🌟 说明：无后端，任务与台账保存在本地 AppStorage（PersistentStorage 持久化），
//    推送 / 定位 / 虚拟定位校验均为本地模拟，页面会明确标注，不伪造真实服务
import { PracticeQuestion, SurveyQuestion, PointRecord, genId, formatStamp } from './DataModel'
import { GroupMsg, groupMembers } from './HomeworkModel'
import { MAIN_GROUP_ID, archiveAppend } from './GroupModel'
import { MessageCenter } from './MessageCenterModel'

// 🌟 课程 key 与 Permission / Guard / 学科页统一为 csbasic
export const COURSE_ID: string = 'csbasic'
// 🌟 历史版本曾使用 ds_2026 作为课程 id，读取旧学分记录时做兼容归一
export const LEGACY_COURSE_ID: string = 'ds_2026'
export const COURSE_NAME: string = '数据结构与算法'
export const TASK_KEY: string = 'interactionTasks'

export function normalizeCourseId(cid: string): string {
  if (cid === '' || cid === LEGACY_COURSE_ID) {
    return COURSE_ID
  }
  return cid
}

// ==================== 角色与权限 ====================
// student 学生 / teacher 授课教师 / assistant 助教
export class Role {
  static current(): string {
    return AppStorage.get<string>('userRole') ?? 'student'
  }

  static isTeacher(): boolean {
    return Role.current() === 'teacher'
  }

  static isAssistant(): boolean {
    return Role.current() === 'assistant'
  }

  // 发起互动任务：授课教师与助教
  static canLaunch(): boolean {
    return Role.isTeacher() || Role.isAssistant()
  }

  // 修改课程基础配置（群公告、课程信息）：仅授课教师
  static canEditCourseConfig(): boolean {
    return Role.isTeacher()
  }

  // 修改学分规则：仅授课教师，助教只读
  static canEditPointRule(): boolean {
    return Role.isTeacher()
  }

  static label(): string {
    if (Role.isTeacher()) {
      return '授课教师'
    }
    if (Role.isAssistant()) {
      return '助教'
    }
    return '学生'
  }
}

// ==================== 类型定义 ====================
export type SigninMode = 'location' | 'code' | 'pattern'
export type SigninStatus = 'signed' | 'absent' | 'leave' | 'makeup'
export type PracticeMode = 'timed' | 'open'
export type AnalysisTiming = 'submit' | 'end'
export type TaskStatus = 'pending' | 'ongoing' | 'ended' | 'withdrawn'
export type TaskType = 'signin' | 'practice' | 'survey' | 'random'
export type PickPool = 'all' | 'unsigned' | 'unsubmitted'
export type PickResolution = 'pending' | 'answered' | 'refused'

export function taskTypeName(t: string): string {
  if (t === 'signin') {
    return '课堂签到'
  }
  if (t === 'practice') {
    return '随堂练习'
  }
  if (t === 'survey') {
    return '调查问卷'
  }
  return '随机抽选'
}

export function taskTypeIcon(t: string): string {
  if (t === 'signin') {
    return '✅'
  }
  if (t === 'practice') {
    return '📝'
  }
  if (t === 'survey') {
    return '📋'
  }
  return '🎲'
}

export function statusName(s: TaskStatus): string {
  if (s === 'pending') {
    return '待发布'
  }
  if (s === 'ongoing') {
    return '进行中'
  }
  if (s === 'ended') {
    return '已结束'
  }
  return '已撤回'
}

export function statusColor(s: TaskStatus): string {
  if (s === 'pending') {
    return '#F59E0B'
  }
  if (s === 'ongoing') {
    return '#3F7EF6'
  }
  if (s === 'ended') {
    return '#10B981'
  }
  return '#94A3B8'
}

export function signinModeName(m: SigninMode): string {
  if (m === 'location') {
    return '位置签到'
  }
  if (m === 'code') {
    return '验证码签到'
  }
  return '图案签到'
}

// ==================== 签到记录 ====================
export class SigninEntry {
  student: string = ''
  status: SigninStatus = 'absent'
  time: number = 0
  method: string = ''
  note: string = ''

  constructor(student: string) {
    this.student = student
  }
}

export function signinStatusName(s: SigninStatus): string {
  if (s === 'signed') {
    return '已签到'
  }
  if (s === 'makeup') {
    return '已签到(补签)'
  }
  if (s === 'leave') {
    return '请假'
  }
  return '未签到'
}

// ==================== 随堂练习 ====================
export class PracticeSubmission {
  id: string = ''
  student: string = ''
  answers: string[] = []
  objectiveScore: number = 0
  subjectiveScore: number = 0
  graded: boolean = false
  late: boolean = false
  penalty: number = 0
  submitAt: number = 0
  attempt: number = 1
  remark: string = ''

  constructor(student: string, answers: string[]) {
    this.id = genId()
    this.student = student
    this.answers = answers
    this.submitAt = Date.now()
  }
}

// ==================== 调查问卷 ====================
export class SurveyResponse {
  id: string = ''
  student: string = '' // 匿名问卷写入空字符串，不关联学生信息
  answers: string[] = []
  submitAt: number = 0

  constructor(student: string, answers: string[]) {
    this.id = genId()
    this.student = student
    this.answers = answers
    this.submitAt = Date.now()
  }
}

// ==================== 随机抽选 ====================
export class PickEntry {
  id: string = ''
  student: string = ''
  pickedAt: number = 0
  resolution: PickResolution = 'pending'
  remark: string = ''
  notified: boolean = false

  constructor(student: string) {
    this.id = genId()
    this.student = student
    this.pickedAt = Date.now()
  }
}

export function pickPoolName(p: PickPool): string {
  if (p === 'unsigned') {
    return '未签到学生'
  }
  if (p === 'unsubmitted') {
    return '未提交练习学生'
  }
  return '全部学生'
}

// ==================== 互动任务 ====================
export class TaskItem {
  id: string = ''
  title: string = ''
  type: TaskType = 'signin'
  status: TaskStatus = 'pending'
  total: number = 0
  done: number = 0
  time: string = ''
  createdAt: number = 0
  courseId: string = COURSE_ID
  teacherName: string = ''
  // 🌟 任务管理：定时发布时间 / 结束时间 / 提前结束与撤回时间
  publishAt: number = 0
  endAt: number = 0
  closedAt: number = 0
  withdrawnAt: number = 0

  // ---- 签到配置 ----
  signinMode: SigninMode = 'location'
  radius: number = 100
  virtualCheck: boolean = true
  // 🌟 真实定位签到：教师发起时记录的签到点坐标（0/0 表示未设置，学生端回退演示距离）
  signinLat: number = 0
  signinLng: number = 0
  validMinutes: number = 30
  code: string = ''
  codeExpireAt: number = 0
  pattern: number[] = []
  patternUsed: boolean = false // 单次图案签到：用过一次即失效，需教师重新绘制
  allowMakeup: boolean = true
  signinEntries: SigninEntry[] = []

  // ---- 练习配置 ----
  practiceMode: PracticeMode = 'open'
  startAt: number = 0
  allowLate: boolean = false
  latePenalty: number = 20
  maxSubmits: number = 1
  allowEdit: boolean = false
  analysisTiming: AnalysisTiming = 'submit'
  // 🌟 练习增强：题目乱序 / 作答切屏提醒
  shuffleQuestions: boolean = false
  switchRemind: boolean = false
  questions: PracticeQuestion[] = []
  submissions: PracticeSubmission[] = []

  // ---- 问卷配置 ----
  anonymous: boolean = true
  surveyQuestions: SurveyQuestion[] = []
  responses: SurveyResponse[] = []

  // ---- 抽选配置 ----
  pool: PickPool = 'all'
  picks: PickEntry[] = []

  constructor(title: string, type: TaskType) {
    this.id = genId()
    this.title = title
    this.type = type
    this.createdAt = Date.now()
    this.time = formatStamp(this.createdAt)
    this.teacherName = AppStorage.get<string>('nickname') ?? ''
  }
}

// ==================== 名册与工具 ====================
export function classStudents(): string[] {
  let list: string[] = []
  groupMembers().forEach((m) => {
    if (m.role !== 'teacher') {
      list.push(m.name)
    }
  })
  return list
}

export function nowTs(): number {
  return Date.now()
}

export function fmtDateTime(ts: number): string {
  if (ts <= 0) {
    return ''
  }
  return formatStamp(ts)
}

export function fmtClock(ts: number): string {
  if (ts <= 0) {
    return '--:--'
  }
  let d = new Date(ts)
  let h = d.getHours().toString().padStart(2, '0')
  let min = d.getMinutes().toString().padStart(2, '0')
  return `${h}:${min}`
}

// 剩余时间文案：超时后显示已结束
export function remainText(endAt: number, now: number): string {
  if (endAt <= 0) {
    return '不限时'
  }
  let diff = endAt - now
  if (diff <= 0) {
    return '已到截止时间'
  }
  let total = Math.floor(diff / 1000)
  let m = Math.floor(total / 60)
  let s = total % 60
  if (m >= 60) {
    let h = Math.floor(m / 60)
    return `剩余 ${h} 小时 ${m % 60} 分`
  }
  return `剩余 ${m}:${s.toString().padStart(2, '0')}`
}

// 🌟 超时自动关闭：进行中的任务到达截止时间即视为已结束（不依赖后端定时器）
export function effectiveStatus(t: TaskItem, now: number): TaskStatus {
  if (t.status === 'ongoing' && t.endAt > 0 && now >= t.endAt) {
    return 'ended'
  }
  return t.status
}

export function isAnswerable(t: TaskItem, now: number): boolean {
  return effectiveStatus(t, now) === 'ongoing'
}

export function findTask(list: TaskItem[], id: string): TaskItem | undefined {
  let hit = list.filter((t: TaskItem) => t.id === id)
  return hit.length > 0 ? hit[0] : undefined
}

export function tasksOfType(list: TaskItem[], type: TaskType): TaskItem[] {
  return list.filter((t: TaskItem) => t.type === type)
}

export function latestTaskOfType(list: TaskItem[], type: TaskType): TaskItem | undefined {
  let arr = tasksOfType(list, type).slice().sort((a: TaskItem, b: TaskItem) => b.createdAt - a.createdAt)
  return arr.length > 0 ? arr[0] : undefined
}

// 🌟 学生端入口优先定位到「进行中」的任务；没有进行中时回退到最近一次任务（可查看已结束状态）
export function latestActiveTaskOfType(list: TaskItem[], type: TaskType, now: number): TaskItem | undefined {
  let ongoing = tasksOfType(list, type).filter((t: TaskItem) => effectiveStatus(t, now) === 'ongoing')
  if (ongoing.length > 0) {
    let arr = ongoing.slice().sort((a: TaskItem, b: TaskItem) => b.createdAt - a.createdAt)
    return arr[0]
  }
  return latestTaskOfType(list, type)
}

export function countSigned(t: TaskItem): number {
  let n = 0
  t.signinEntries.forEach((e: SigninEntry) => {
    if (e.status === 'signed' || e.status === 'makeup') {
      n++
    }
  })
  return n
}

export function countLeave(t: TaskItem): number {
  return t.signinEntries.filter((e: SigninEntry) => e.status === 'leave').length
}

export function countAbsent(t: TaskItem): number {
  return t.signinEntries.filter((e: SigninEntry) => e.status === 'absent').length
}

export function countSubmitted(t: TaskItem): number {
  let names: string[] = []
  t.submissions.forEach((s: PracticeSubmission) => {
    if (!names.includes(s.student)) {
      names.push(s.student)
    }
  })
  return names.length
}

export function taskDoneCount(t: TaskItem): number {
  if (t.type === 'signin') {
    return countSigned(t)
  }
  if (t.type === 'practice') {
    return countSubmitted(t)
  }
  if (t.type === 'survey') {
    return t.responses.length
  }
  return t.picks.length
}

// ==================== 消息通知（本地模拟） ====================
// 🌟 任务对应的消息中心分类
export function taskMessageType(t: TaskItem): string {
  if (t.type === 'signin') {
    return 'signin'
  }
  if (t.type === 'practice') {
    return 'homework'
  }
  return 'class'
}

// 🌟 任务对应的学生端页面：消息中心点击后按任务 id 直达
export function taskRoute(t: TaskItem): string {
  if (t.type === 'signin') {
    return 'pages/study/SigninPage'
  }
  if (t.type === 'practice') {
    return 'pages/study/PracticePage'
  }
  if (t.type === 'survey') {
    return 'pages/study/SurveyPage'
  }
  return 'pages/study/RandomPickPage'
}

// 仅写入班级群消息 + 云端归档（本地模拟）
export function pushGroupNotice(text: string): GroupMsg {
  let msgs = AppStorage.get<GroupMsg[]>('classGroupMsgs') ?? []
  let m = new GroupMsg()
  m.id = `notice_${Date.now()}_${Math.floor(Math.random() * 1000)}`
  m.name = AppStorage.get<string>('nickname') ?? '老师'
  m.role = 'teacher'
  m.kind = 'text'
  m.text = `${text}\n（本地模拟通知，未接入真实推送服务）`
  m.time = Date.now()
  AppStorage.setOrCreate('classGroupMsgs', msgs.concat([m]))
  // 🌟 系统通知同步写入群归档，保证「清空本地聊天后仍可检索」对通知同样成立
  archiveAppend(MAIN_GROUP_ID, m)
  return m
}

export function notifyClassGroup(text: string): void {
  pushGroupNotice(text)
}

// 🌟 任务通知统一入口：班级群 + 消息中心（带任务 id 与跳转页面），避免各页面重复写入
export function notifyTask(t: TaskItem, text: string, groupToo: boolean = true, sender: string = '教学互动'): void {
  if (groupToo) {
    pushGroupNotice(text)
  }
  MessageCenter.pushIfEnabled(taskMessageType(t), sender, text, '', taskRoute(t), t.id)
}

// ==================== 任务创建 ====================
export function newSigninTask(title: string, mode: SigninMode, radius: number, virtualCheck: boolean,
  validMinutes: number, allowMakeup: boolean, lat: number = 0, lng: number = 0): TaskItem {
  let t = new TaskItem(title, 'signin')
  t.status = 'ongoing'
  t.signinMode = mode
  t.radius = radius
  t.virtualCheck = virtualCheck
  t.signinLat = lat
  t.signinLng = lng
  t.validMinutes = validMinutes
  t.allowMakeup = allowMakeup
  t.code = String(Math.floor(1000 + Math.random() * 9000))
  t.codeExpireAt = Date.now() + validMinutes * 60000
  t.endAt = Date.now() + validMinutes * 60000
  t.total = classStudents().length
  let entries: SigninEntry[] = []
  classStudents().forEach((name: string) => entries.push(new SigninEntry(name)))
  t.signinEntries = entries
  return t
}

export function newPracticeTask(title: string, questions: PracticeQuestion[]): TaskItem {
  let t = new TaskItem(title, 'practice')
  t.status = 'pending'
  t.questions = questions
  t.total = classStudents().length
  return t
}

export function newSurveyTask(title: string, questions: SurveyQuestion[], anonymous: boolean): TaskItem {
  let t = new TaskItem(title, 'survey')
  t.status = 'pending'
  t.surveyQuestions = questions
  t.anonymous = anonymous
  t.total = classStudents().length
  return t
}

export function newRandomTask(pool: PickPool): TaskItem {
  let t = new TaskItem(`随机抽选·${pickPoolName(pool)}`, 'random')
  t.status = 'ongoing'
  t.pool = pool
  t.total = classStudents().length
  return t
}

// 🌟 发布 / 提前结束 / 撤回：统一处理任务状态与班级通知
export function launchTask(t: TaskItem): void {
  t.status = 'ongoing'
  t.publishAt = 0
  if (t.endAt === 0) {
    if (t.type === 'signin') {
      t.endAt = Date.now() + t.validMinutes * 60000
      t.codeExpireAt = t.endAt
    } else if (t.type === 'practice' && t.practiceMode === 'timed') {
      t.startAt = Date.now()
      t.endAt = Date.now() + 30 * 60000
    }
  } else if (t.type === 'signin' && t.codeExpireAt === 0) {
    t.codeExpireAt = t.endAt
  }
  // 定时签到时验证码在发起时刻才生成，避免提前泄露
  if (t.type === 'signin' && t.signinMode === 'code' && t.code === '') {
    t.code = String(Math.floor(1000 + Math.random() * 9000))
  }
}

export function endTask(t: TaskItem): void {
  t.status = 'ended'
  t.closedAt = Date.now()
}

export function withdrawTask(t: TaskItem): void {
  t.status = 'withdrawn'
  t.withdrawnAt = Date.now()
}

// 🌟 定时发布：任意入口打开时把到点的待发布任务切换为进行中（本地计时，无后端调度）
export function autoPublishDue(list: TaskItem[], now: number): boolean {
  let changed = false
  list.forEach((t: TaskItem) => {
    if (t.status === 'pending' && t.publishAt > 0 && t.publishAt <= now) {
      launchTask(t)
      changed = true
      notifyTask(t, `【${taskTypeName(t.type)}】${t.title} 已按计划发布，请同学们及时参与。`)
    }
  })
  return changed
}

// ==================== 随堂练习判分 ====================
export function isObjectiveQuestion(q: PracticeQuestion): boolean {
  return q.type === 'single' || q.type === 'multi' || q.type === 'judge' || q.type === 'fill'
}

export function perQuestionScore(questions: PracticeQuestion[]): number {
  if (questions.length === 0) {
    return 0
  }
  return 100 / questions.length
}

export function objectiveFullScore(questions: PracticeQuestion[]): number {
  let n = 0
  questions.forEach((q: PracticeQuestion) => {
    if (isObjectiveQuestion(q)) {
      n++
    }
  })
  return Math.round(perQuestionScore(questions) * n * 10) / 10
}

export function subjectiveFullScore(questions: PracticeQuestion[]): number {
  let n = 0
  questions.forEach((q: PracticeQuestion) => {
    if (!isObjectiveQuestion(q)) {
      n++
    }
  })
  return Math.round(perQuestionScore(questions) * n * 10) / 10
}

function normalizeAnswer(v: string): string {
  return v.trim().toLowerCase().replace(/\s+/g, '')
}

// 🌟 客观题自动判分：单选/判断比较选项下标，多选比较集合，填空去空格后不区分大小写
export function gradeAnswer(q: PracticeQuestion, ans: string): boolean {
  if (!isObjectiveQuestion(q)) {
    return false
  }
  if (q.type === 'single' || q.type === 'judge') {
    return normalizeAnswer(ans) === normalizeAnswer(String(q.answer))
  }
  if (q.type === 'multi') {
    let right = (q.answer as number[]).slice().sort((a: number, b: number) => a - b).join(',')
    let picked = ans.split(',').filter((x: string) => x !== '').map((x: string) => Number(x))
    picked.sort((a: number, b: number) => a - b)
    return picked.join(',') === right
  }
  return normalizeAnswer(ans) === normalizeAnswer(q.answer as string)
}

export function objectiveScore(questions: PracticeQuestion[], answers: string[]): number {
  if (questions.length === 0) {
    return 0
  }
  let per = perQuestionScore(questions)
  let score = 0
  questions.forEach((q: PracticeQuestion, i: number) => {
    if (isObjectiveQuestion(q) && answers[i] !== undefined && gradeAnswer(q, answers[i])) {
      score += per
    }
  })
  return Math.round(score * 10) / 10
}

// 🌟 迟交扣分：按提交时记录的扣分比例折算总分
export function submissionScore(s: PracticeSubmission): number {
  let raw = s.objectiveScore + s.subjectiveScore
  return Math.round(raw * (1 - s.penalty / 100) * 10) / 10
}

export function analysisVisible(t: TaskItem, s: PracticeSubmission | undefined, now: number): boolean {
  if (t.analysisTiming === 'submit') {
    return s !== undefined
  }
  // 全部任务结束后才可见解析
  return effectiveStatus(t, now) === 'ended'
}

// 🌟 学生能否再次提交：限次 + 是否允许修改
export function canSubmitAgain(t: TaskItem, student: string): boolean {
  let mine = t.submissions.filter((s: PracticeSubmission) => s.student === student)
  if (mine.length === 0) {
    return true
  }
  if (!t.allowEdit) {
    return false
  }
  return mine.length < t.maxSubmits
}

// ==================== 问卷统计 ====================
export function surveyOptionCount(t: TaskItem, qi: number, optIdx: number): number {
  let n = 0
  t.responses.forEach((r: SurveyResponse) => {
    let a = r.answers[qi]
    if (a === undefined) {
      return
    }
    let parts = a.split(',')
    if (parts.includes(String(optIdx))) {
      n++
    }
  })
  return n
}

export function surveyScaleAvg(t: TaskItem, qi: number): number {
  let sum = 0
  let n = 0
  t.responses.forEach((r: SurveyResponse) => {
    let a = r.answers[qi]
    if (a !== undefined && a !== '') {
      sum += Number(a)
      n++
    }
  })
  return n === 0 ? 0 : Math.round(sum / n * 10) / 10
}

// ==================== 学分规则 ====================
export class PointRule {
  enabled: boolean = true
  signin: number = 5
  practice: number = 10
  random: number = 8
  singleCap: number = 10
  courseCap: number = 100
}

export class PointAction {
  key: string = ''
  label: string = ''

  constructor(key: string, label: string) {
    this.key = key
    this.label = label
  }
}

export const POINT_ACTIONS: PointAction[] = [
  new PointAction('signin', '完成签到'),
  new PointAction('practice', '提交随堂练习'),
  new PointAction('random', '被抽中并完成答题')
]

function copyRule(raw: PointRule): PointRule {
  let r = new PointRule()
  r.enabled = raw.enabled === undefined ? true : raw.enabled
  r.signin = raw.signin === undefined ? 5 : raw.signin
  r.practice = raw.practice === undefined ? 10 : raw.practice
  r.random = raw.random === undefined ? 8 : raw.random
  r.singleCap = raw.singleCap === undefined ? 10 : raw.singleCap
  r.courseCap = raw.courseCap === undefined ? 100 : raw.courseCap
  return r
}

export function allPointRules(): Record<string, PointRule> {
  let raw = AppStorage.get<Record<string, PointRule>>('pointRules')
  let map: Record<string, PointRule> = {}
  if (raw !== undefined) {
    let src: Record<string, PointRule> = raw
    Object.keys(src).forEach((k: string) => {
      map[k] = copyRule(src[k])
    })
  }
  return map
}

export function ruleOf(courseId: string): PointRule {
  let map = allPointRules()
  return map[courseId] === undefined ? new PointRule() : map[courseId]
}

export function saveRule(courseId: string, rule: PointRule): void {
  let map = allPointRules()
  map[courseId] = rule
  AppStorage.setOrCreate('pointRules', map)
}

export function actionLabel(key: string): string {
  let hit = POINT_ACTIONS.filter((a: PointAction) => a.key === key)
  return hit.length > 0 ? hit[0].label : key
}

export function studentPointTotal(records: PointRecord[], student: string, courseId: string): number {
  let total = 0
  records.forEach((r: PointRecord) => {
    let cid = normalizeCourseId(r.courseId)
    if (r.student === student && cid === courseId) {
      total += r.points
    }
  })
  return total
}

// 🌟 发放学分：按行为分值 + 单次上限 + 课程总分上限计算，返回本次实际获得学分
export function awardPoints(actionKey: string, student: string): number {
  if (student === '') {
    return 0
  }
  let rule = ruleOf(COURSE_ID)
  if (!rule.enabled) {
    return 0
  }
  let base = 0
  if (actionKey === 'signin') {
    base = rule.signin
  } else if (actionKey === 'practice') {
    base = rule.practice
  } else if (actionKey === 'random') {
    base = rule.random
  } else {
    return 0
  }
  let gain = Math.min(base, rule.singleCap)
  let records = AppStorage.get<PointRecord[]>('pointRecords') ?? []
  let current = studentPointTotal(records, student, COURSE_ID)
  let actual = Math.max(0, Math.min(gain, rule.courseCap - current))
  if (actual <= 0) {
    return 0
  }
  let rec = new PointRecord(actionLabel(actionKey), actual, current + actual)
  rec.student = student
  rec.courseId = COURSE_ID
  rec.actionKey = actionKey
  let list: PointRecord[] = [rec].concat(records)
  AppStorage.setOrCreate('pointRecords', list)
  AppStorage.setOrCreate('pointsTotal', current + actual)
  return actual
}

// ==================== CSV 导出（Excel 兼容） ====================
export function csvCell(v: string): string {
  let s = v === undefined || v === null ? '' : v
  if (s.indexOf('"') >= 0 || s.indexOf(',') >= 0 || s.indexOf('\n') >= 0) {
    return `"${s.split('"').join('""')}"`
  }
  return s
}

export function signinCsvRows(t: TaskItem): string[][] {
  let rows: string[][] = [['姓名', '签到状态', '签到时间', '签到方式', '备注']]
  t.signinEntries.forEach((e: SigninEntry) => {
    rows.push([
      e.student,
      signinStatusName(e.status),
      e.time > 0 ? fmtDateTime(e.time) : '',
      e.method,
      e.note
    ])
  })
  return rows
}

export function pointsCsvRows(records: PointRecord[], courseId: string, student: string): string[][] {
  let rows: string[][] = [['学生', '行为', '学分', '累计', '时间', '课程']]
  records.forEach((r: PointRecord) => {
    let cid = normalizeCourseId(r.courseId)
    if (cid !== courseId) {
      return
    }
    if (student !== '' && r.student !== student) {
      return
    }
    rows.push([r.student, r.action, String(r.points), String(r.total), r.time, COURSE_NAME])
  })
  return rows
}

export function practiceCsvRows(t: TaskItem): string[][] {
  let rows: string[][] = [['学生', '客观题得分', '主观题得分', '总分', '是否迟交', '提交时间', '批阅状态']]
  t.submissions.forEach((s: PracticeSubmission) => {
    rows.push([
      s.student,
      String(s.objectiveScore),
      String(s.subjectiveScore),
      String(submissionScore(s)),
      s.late ? '是' : '否',
      fmtDateTime(s.submitAt),
      s.graded ? '已批阅' : '待批阅'
    ])
  })
  return rows
}

// ==================== 演示数据 ====================
function entry(name: string, status: SigninStatus, minutesAgo: number, method: string, note: string): SigninEntry {
  let e = new SigninEntry(name)
  e.status = status
  e.time = status === 'absent' || status === 'leave' ? 0 : Date.now() - minutesAgo * 60000
  e.method = method
  e.note = note
  return e
}

export function defaultTasks(): TaskItem[] {
  let list: TaskItem[] = []
  let students = classStudents()

  // 1. 进行中的签到
  let signin = new TaskItem('第 8 周课堂签到', 'signin')
  signin.status = 'ongoing'
  signin.signinMode = 'code'
  signin.code = '3847'
  signin.validMinutes = 30
  signin.endAt = Date.now() + 18 * 60000
  signin.codeExpireAt = signin.endAt
  signin.total = students.length
  let entries: SigninEntry[] = []
  students.forEach((name: string, i: number) => {
    if (i < 3) {
      entries.push(entry(name, 'signed', 8, '验证码', ''))
    } else if (i === 3) {
      entries.push(entry(name, 'leave', 0, '', '病假'))
    } else {
      entries.push(entry(name, 'absent', 0, '', ''))
    }
  })
  signin.signinEntries = entries
  list.push(signin)

  // 2. 进行中的随堂练习（含客观题与主观题）
  let practice = new TaskItem('数据结构随堂练习', 'practice')
  practice.status = 'ongoing'
  practice.practiceMode = 'timed'
  practice.startAt = Date.now() - 20 * 60000
  practice.endAt = Date.now() + 25 * 60000
  practice.allowLate = true
  practice.latePenalty = 20
  practice.maxSubmits = 1
  practice.analysisTiming = 'submit'
  let q1 = new PracticeQuestion('1. 下列哪种数据结构是先进先出（FIFO）？', 'single')
  q1.opts = ['栈(Stack)', '队列(Queue)', '二叉树', '哈希表']
  q1.answer = 1
  q1.analysis = '队列遵循先进先出原则，栈是后进先出。'
  let q2 = new PracticeQuestion('2. 以下属于线性结构的有（多选）？', 'multi')
  q2.opts = ['数组', '链表', '栈', '图']
  q2.answer = [0, 1, 2]
  q2.analysis = '图是非线性结构，数组、链表、栈均为线性结构。'
  let q3 = new PracticeQuestion('3. 判断：栈的插入与删除都在栈顶进行。', 'judge')
  q3.answer = 0
  q3.analysis = '栈是后进先出，入栈与出栈都在栈顶操作。'
  let q4 = new PracticeQuestion('4. 二分查找的时间复杂度是 ______。', 'fill')
  q4.answer = 'O(log n)'
  q4.analysis = '二分查找每次折半，复杂度为 O(log n)。'
  let q5 = new PracticeQuestion('5. 简述队列在广度优先搜索中的作用。', 'essay')
  q5.analysis = '队列用于按层保存待访问节点，保证先访问的节点先扩展。'
  practice.questions = [q1, q2, q3, q4, q5]
  practice.total = students.length
  if (students.length >= 2) {
    let s1 = new PracticeSubmission(students[0], ['1', '0,1,2', '0', 'O(log n)', ''])
    s1.objectiveScore = 60
    s1.subjectiveScore = 0
    s1.graded = false
    let s2 = new PracticeSubmission(students[1], ['0', '0,1', '0', 'O(n)', ''])
    s2.objectiveScore = 40
    s2.late = true
    s2.penalty = 20
    s2.subjectiveScore = 12
    s2.graded = true
    practice.submissions = [s1, s2]
  }
  list.push(practice)

  // 3. 已结束的问卷
  let survey = new TaskItem('教学满意度问卷', 'survey')
  survey.status = 'ended'
  survey.anonymous = true
  survey.closedAt = Date.now() - 3600000
  let sq1 = new SurveyQuestion('1. 你对本课程的整体满意度？', 'single')
  sq1.opts = ['非常满意', '满意', '一般', '不满意']
  let sq2 = new SurveyQuestion('2. 你认为哪些方面需要改进？（多选）', 'multi')
  sq2.opts = ['教学内容', '教学方式', '作业量', '考核方式']
  let sq3 = new SurveyQuestion('3. 请为教师授课打分（1-5 分）', 'scale')
  sq3.maxScale = 5
  let sq4 = new SurveyQuestion('4. 你对课程有什么建议？', 'essay')
  survey.surveyQuestions = [sq1, sq2, sq3, sq4]
  survey.total = students.length
  survey.responses = [
    new SurveyResponse('', ['1', '0,1', '5', '希望多讲一些算法推导过程']),
    new SurveyResponse('', ['1', '2', '4', '作业量适中']),
    new SurveyResponse('', ['0', '0', '5', ''])
  ]
  list.push(survey)

  // 4. 已撤回的抽选
  let random = new TaskItem('随机抽选·全部学生', 'random')
  random.status = 'withdrawn'
  random.withdrawnAt = Date.now() - 7200000
  random.pool = 'all'
  random.total = students.length
  if (students.length >= 2) {
    let p1 = new PickEntry(students[0])
    p1.resolution = 'answered'
    p1.notified = true
    let p2 = new PickEntry(students[2])
    p2.resolution = 'refused'
    p2.remark = '身体不适，已改由下一位同学作答'
    p2.notified = true
    random.picks = [p1, p2]
  }
  list.push(random)

  return list
}
