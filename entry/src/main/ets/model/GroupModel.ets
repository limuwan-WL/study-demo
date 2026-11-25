// ==================== 班级群（师生共用）模型 ====================
// 🌟 说明：本项目无后端。云端存储、推送、审核均以本地 AppStorage 模拟，
//    页面中会明确标注「本地模拟」，不伪造真实服务。
import { GroupMember, GroupMsg, groupMembers } from './HomeworkModel'
import { formatStamp } from './DataModel'
import { Permission } from './PermissionModel'

export const MAIN_GROUP_ID: string = 'g_main'
// 🌟 课程 key 与 Permission / Guard / 学科页保持一致，避免同一课程两套 id
export const GROUP_COURSE_ID: string = 'csbasic'
export const GROUP_COURSE_NAME: string = '数据结构与算法'
export const MAIN_TEACHER: string = '张老师'
export const MAIN_GROUP_NAME: string = '数据结构与算法 · 班级群'
// 🌟 消息限时撤回：2 分钟内可撤回
export const RECALL_WINDOW_MS: number = 2 * 60 * 1000
export const DEFAULT_RETENTION_DAYS: number = 30

// ==================== 群组 ====================
export class ChatGroup {
  id: string = ''
  name: string = ''
  courseId: string = GROUP_COURSE_ID
  courseName: string = GROUP_COURSE_NAME
  teacherName: string = MAIN_TEACHER
  ownerName: string = MAIN_TEACHER
  isMain: boolean = false
  intro: string = ''
  createdAt: number = 0
  dissolved: boolean = false

  constructor(id: string, name: string, isMain: boolean, ownerName: string) {
    this.id = id
    this.name = name
    this.isMain = isMain
    this.ownerName = ownerName
    this.createdAt = Date.now()
  }
}

// ==================== 群公告 ====================
export class GroupNotice {
  id: string = ''
  groupId: string = ''
  title: string = ''
  // 🌟 富文本：支持「## 标题」「- 列表」「**加粗**」标记，渲染时转换为 HTML
  content: string = ''
  attachmentName: string = ''
  attachmentUri: string = ''
  pinned: boolean = false
  author: string = ''
  createdAt: number = 0
  updatedAt: number = 0
  // 🌟 已读成员名列表（无后端，本地记录）
  readBy: string[] = []

  constructor(groupId: string, title: string, content: string, author: string) {
    this.id = `n_${Date.now()}_${Math.floor(Math.random() * 1000)}`
    this.groupId = groupId
    this.title = title
    this.content = content
    this.author = author
    this.createdAt = Date.now()
    this.updatedAt = this.createdAt
  }
}

// ==================== 群文件归档 ====================
export class GroupFile {
  id: string = ''
  groupId: string = ''
  name: string = ''
  kind: string = 'doc' // doc / image / video
  size: string = ''
  uploader: string = ''
  uploadAt: number = 0
  uri: string = ''
  msgId: string = ''
  // 🌟 云端归档过期策略：上传时记录保留天数（本地模拟）
  retentionDays: number = DEFAULT_RETENTION_DAYS
  downloaded: boolean = false

  constructor(groupId: string, name: string, kind: string, size: string, uploader: string, uri: string) {
    this.id = `f_${Date.now()}_${Math.floor(Math.random() * 1000)}`
    this.groupId = groupId
    this.name = name
    this.kind = kind
    this.size = size
    this.uploader = uploader
    this.uploadAt = Date.now()
    this.uri = uri
    this.retentionDays = retentionDays()
  }
}

// ==================== 举报 ====================
export class GroupReport {
  id: string = ''
  groupId: string = ''
  type: string = 'message' // message / file
  targetId: string = ''
  targetText: string = ''
  detail: string = ''
  screenshots: string[] = []
  reporter: string = ''
  createdAt: number = 0
  status: string = 'pending' // pending / reviewing / done
  result: string = ''

  constructor(groupId: string, type: string) {
    this.id = `r_${Date.now()}_${Math.floor(Math.random() * 1000)}`
    this.groupId = groupId
    this.type = type
    this.reporter = currentName()
    this.createdAt = Date.now()
  }
}

// ==================== 当前身份 ====================
export function currentRole(): string {
  return AppStorage.get<string>('userRole') ?? 'student'
}

export function currentName(): string {
  return AppStorage.get<string>('nickname') ?? '张同学'
}

export function roleLabel(role: string): string {
  if (role === 'teacher') {
    return '授课教师'
  }
  if (role === 'assistant') {
    return '助教'
  }
  return '学生'
}

export function roleColor(role: string): string {
  if (role === 'teacher') {
    return '#E8A33E'
  }
  if (role === 'assistant') {
    return '#8B5CF6'
  }
  return '#4C8BF5'
}

// ==================== 权限（按角色严格隔离） ====================
// 新建群：默认仅授课教师；助教需授课教师开启「助教建群权限」
export function assistantCanCreate(): boolean {
  return AppStorage.get<boolean>('assistantCanCreate') ?? false
}

export function canCreateGroup(): boolean {
  let role = currentRole()
  if (role === 'teacher') {
    return true
  }
  return role === 'assistant' && assistantCanCreate()
}

// 发布 / 编辑群公告：授课教师 + 助教
export function canPublishNotice(): boolean {
  let role = currentRole()
  return role === 'teacher' || role === 'assistant'
}

// 导出签到台账 / 批阅作业：授课教师 + 助教
export function canExportLedger(): boolean {
  return canPublishNotice()
}

export function canGradeHomework(): boolean {
  return canPublishNotice()
}

// 修改课程基础配置 / 学分规则 / 删除课程：仅授课教师
export function canEditCourseBase(): boolean {
  return currentRole() === 'teacher'
}

export function canEditPointRule(): boolean {
  return currentRole() === 'teacher'
}

export function canDeleteCourse(): boolean {
  return currentRole() === 'teacher'
}

// 群主判定：昵称一致即群主；群主仍为默认授课教师时，教师角色视为群主（演示昵称可改）
export function isGroupOwner(g: ChatGroup): boolean {
  if (g.ownerName === currentName()) {
    return true
  }
  return g.ownerName === MAIN_TEACHER && currentRole() === 'teacher'
}

export function isAssistantRole(): boolean {
  return currentRole() === 'assistant'
}

// ==================== 存储读写 ====================
function copyMsgMap(): Record<string, GroupMsg[]> {
  let raw: Record<string, GroupMsg[]> = AppStorage.get<Record<string, GroupMsg[]>>('groupMsgsMap') ?? {}
  let map: Record<string, GroupMsg[]> = {}
  Object.keys(raw).forEach((k: string) => {
    map[k] = raw[k]
  })
  return map
}

function copyMemberMap(): Record<string, GroupMember[]> {
  let raw: Record<string, GroupMember[]> =
    AppStorage.get<Record<string, GroupMember[]>>('groupMembersMap') ?? {}
  let map: Record<string, GroupMember[]> = {}
  Object.keys(raw).forEach((k: string) => {
    map[k] = raw[k]
  })
  return map
}

function copyArchive(): Record<string, GroupMsg[]> {
  let raw: Record<string, GroupMsg[]> =
    AppStorage.get<Record<string, GroupMsg[]>>('groupChatArchive') ?? {}
  let map: Record<string, GroupMsg[]> = {}
  Object.keys(raw).forEach((k: string) => {
    map[k] = raw[k]
  })
  return map
}

function copyUnread(): Record<string, number> {
  let raw: Record<string, number> = AppStorage.get<Record<string, number>>('groupUnreadMap') ?? {}
  let map: Record<string, number> = {}
  Object.keys(raw).forEach((k: string) => {
    map[k] = raw[k]
  })
  return map
}

function copyMute(): Record<string, string> {
  let raw: Record<string, string> = AppStorage.get<Record<string, string>>('groupMuteMap') ?? {}
  let map: Record<string, string> = {}
  Object.keys(raw).forEach((k: string) => {
    map[k] = raw[k]
  })
  return map
}

// ==================== 群列表 ====================
export function allGroups(): ChatGroup[] {
  return AppStorage.get<ChatGroup[]>('chatGroups') ?? []
}

export function visibleGroups(): ChatGroup[] {
  return allGroups().filter((g: ChatGroup) => !g.dissolved)
}

export function groupById(gid: string): ChatGroup | undefined {
  let hit = allGroups().filter((g: ChatGroup) => g.id === gid)
  return hit.length > 0 ? hit[0] : undefined
}

export function saveGroup(g: ChatGroup): void {
  let list = allGroups().slice()
  let idx = list.findIndex((x: ChatGroup) => x.id === g.id)
  if (idx >= 0) {
    list[idx] = g
  } else {
    list.push(g)
  }
  AppStorage.setOrCreate('chatGroups', list)
}

export function mainGroup(): ChatGroup | undefined {
  let hit = allGroups().filter((g: ChatGroup) => g.isMain)
  return hit.length > 0 ? hit[0] : undefined
}

// ==================== 成员 ====================
export function membersOf(gid: string): GroupMember[] {
  let map = copyMemberMap()
  let list = map[gid] ?? []
  return list.filter((m: GroupMember) => !m.removed)
}

export function saveMembers(gid: string, list: GroupMember[]): void {
  let map = copyMemberMap()
  map[gid] = list
  AppStorage.setOrCreate('groupMembersMap', map)
}

export function addMember(gid: string, name: string, role: string): void {
  let list = membersOf(gid).slice()
  let hit = list.filter((m: GroupMember) => m.name === name)
  if (hit.length > 0) {
    hit[0].role = role
  } else {
    list.push(new GroupMember(name, role))
  }
  saveMembers(gid, list)
}

export function setMemberRole(gid: string, name: string, role: string): boolean {
  let list = membersOf(gid).slice()
  let hit = list.filter((m: GroupMember) => m.name === name)
  if (hit.length === 0) {
    return false
  }
  hit[0].role = role
  saveMembers(gid, list)
  return true
}

export function removeMember(gid: string, name: string): void {
  let list = membersOf(gid).filter((m: GroupMember) => m.name !== name)
  saveMembers(gid, list)
}

export function ownerMember(gid: string): GroupMember | undefined {
  let g = groupById(gid)
  if (g === undefined) {
    return undefined
  }
  let owner = g.ownerName
  let hit = membersOf(gid).filter((m: GroupMember) => m.name === owner)
  return hit.length > 0 ? hit[0] : undefined
}

// ==================== 消息（本地 + 云端归档模拟） ====================
export function msgsOf(gid: string): GroupMsg[] {
  if (gid === MAIN_GROUP_ID) {
    return AppStorage.get<GroupMsg[]>('classGroupMsgs') ?? []
  }
  let map = copyMsgMap()
  return map[gid] ?? []
}

export function saveMsgs(gid: string, list: GroupMsg[]): void {
  if (gid === MAIN_GROUP_ID) {
    AppStorage.setOrCreate('classGroupMsgs', list)
    return
  }
  let map = copyMsgMap()
  map[gid] = list
  AppStorage.setOrCreate('groupMsgsMap', map)
}

// 🌟 只清除本机缓存，云端归档保留
export function clearLocalMsgs(gid: string): void {
  saveMsgs(gid, [])
  AppStorage.setOrCreate('classGroupSeeded', true)
}

export function archiveOf(gid: string): GroupMsg[] {
  let map = copyArchive()
  return map[gid] ?? []
}

// 每条消息同时写入「云端归档」（本地模拟），清空本地聊天记录不会删除归档
export function archiveAppend(gid: string, m: GroupMsg): void {
  let map = copyArchive()
  let list = (map[gid] ?? []).slice()
  list.push(m)
  if (list.length > 500) {
    list = list.slice(list.length - 500)
  }
  map[gid] = list
  AppStorage.setOrCreate('groupChatArchive', map)
}

export function archiveAppendMany(gid: string, list: GroupMsg[]): void {
  let map = copyArchive()
  let target = (map[gid] ?? []).slice()
  list.forEach((m: GroupMsg) => {
    target.push(m)
  })
  if (target.length > 500) {
    target = target.slice(target.length - 500)
  }
  map[gid] = target
  AppStorage.setOrCreate('groupChatArchive', map)
}

// ==================== 未读与免打扰 ====================
export function unreadOf(gid: string): number {
  let map = copyUnread()
  let n = map[gid]
  return n === undefined ? 0 : n
}

export function setUnread(gid: string, n: number): void {
  let map = copyUnread()
  map[gid] = n
  AppStorage.setOrCreate('groupUnreadMap', map)
}

export function bumpUnread(gid: string): void {
  setUnread(gid, unreadOf(gid) + 1)
}

export function clearUnread(gid: string): void {
  setUnread(gid, 0)
}

export function totalUnread(): number {
  let n = 0
  visibleGroups().forEach((g: ChatGroup) => {
    n += unreadOf(g.id)
  })
  return n
}

// 免打扰两档：off 正常 / reddot 关推送保留红点 / block 全部屏蔽
export function muteModeOf(gid: string): string {
  let map = copyMute()
  let mode = map[gid]
  return mode === undefined ? 'off' : mode
}

export function setMuteMode(gid: string, mode: string): void {
  let map = copyMute()
  map[gid] = mode
  AppStorage.setOrCreate('groupMuteMap', map)
}

export function muteLabel(gid: string): string {
  let mode = muteModeOf(gid)
  if (mode === 'reddot') {
    return '免打扰 · 保留红点'
  }
  if (mode === 'block') {
    return '完全屏蔽'
  }
  return '正常接收'
}

// ==================== 群公告 ====================
export function noticesOf(gid: string): GroupNotice[] {
  let all = AppStorage.get<GroupNotice[]>('groupNotices') ?? []
  let list = all.filter((n: GroupNotice) => n.groupId === gid)
  return list.sort((a: GroupNotice, b: GroupNotice) => {
    if (a.pinned !== b.pinned) {
      return a.pinned ? -1 : 1
    }
    return b.updatedAt - a.updatedAt
  })
}

export function noticeById(nid: string): GroupNotice | undefined {
  let all = AppStorage.get<GroupNotice[]>('groupNotices') ?? []
  let hit = all.filter((n: GroupNotice) => n.id === nid)
  return hit.length > 0 ? hit[0] : undefined
}

export function saveNotice(n: GroupNotice): void {
  let all = AppStorage.get<GroupNotice[]>('groupNotices') ?? []
  let list = all.slice()
  let idx = list.findIndex((x: GroupNotice) => x.id === n.id)
  if (idx >= 0) {
    list[idx] = n
  } else {
    list.push(n)
  }
  AppStorage.setOrCreate('groupNotices', list)
}

export function noticeRead(n: GroupNotice): boolean {
  return n.readBy.indexOf(currentName()) >= 0
}

export function markNoticeRead(n: GroupNotice): void {
  if (noticeRead(n)) {
    return
  }
  let list = n.readBy.slice()
  list.push(currentName())
  n.readBy = list
  saveNotice(n)
}

export function pinnedNotice(gid: string): GroupNotice | undefined {
  let list = noticesOf(gid).filter((n: GroupNotice) => n.pinned)
  return list.length > 0 ? list[0] : undefined
}

// 富文本标记 -> HTML（供 RichText 渲染）
function escapeHtml(s: string): string {
  return s.split('&').join('&amp;').split('<').join('&lt;').split('>').join('&gt;')
}

function inlineHtml(s: string): string {
  let out = escapeHtml(s)
  let parts = out.split('**')
  if (parts.length < 3) {
    return out
  }
  let merged = ''
  for (let i = 0; i < parts.length; i++) {
    if (i % 2 === 1) {
      merged += `<b>${parts[i]}</b>`
    } else {
      merged += parts[i]
    }
  }
  return merged
}

export function noticeHtml(content: string): string {
  let lines = content.split('\n')
  let html = ''
  lines.forEach((line: string) => {
    let t = line.trim()
    if (t === '') {
      html += '<p style="height:6px"></p>'
    } else if (t.indexOf('## ') === 0) {
      html += `<h3 style="font-size:15px;color:#18181A;margin:6px 0">${inlineHtml(t.substring(3))}</h3>`
    } else if (t.indexOf('- ') === 0) {
      html += `<p style="font-size:13px;color:#333333;line-height:20px;margin:2px 0">• ${inlineHtml(t.substring(2))}</p>`
    } else {
      html += `<p style="font-size:13px;color:#333333;line-height:20px;margin:2px 0">${inlineHtml(t)}</p>`
    }
  })
  return html
}

export function noticePlain(content: string): string {
  return content.split('**').join('').split('## ').join('').split('- ').join('')
}

// ==================== 文件归档 ====================
export function retentionDays(): number {
  let n = AppStorage.get<number>('fileRetentionDays')
  return n === undefined || n <= 0 ? DEFAULT_RETENTION_DAYS : n
}

export function setRetentionDays(n: number): void {
  AppStorage.setOrCreate('fileRetentionDays', n)
}

export function filesOf(gid: string): GroupFile[] {
  let all = AppStorage.get<GroupFile[]>('groupFiles') ?? []
  return all.filter((f: GroupFile) => f.groupId === gid)
    .sort((a: GroupFile, b: GroupFile) => b.uploadAt - a.uploadAt)
}

export function saveFiles(list: GroupFile[]): void {
  AppStorage.setOrCreate('groupFiles', list)
}

export function addGroupFile(gid: string, name: string, kind: string, size: string,
  uploader: string, uri: string, msgId: string): GroupFile {
  let f = new GroupFile(gid, name, kind, size, uploader, uri)
  f.msgId = msgId
  let all = AppStorage.get<GroupFile[]>('groupFiles') ?? []
  saveFiles([f].concat(all))
  return f
}

// 🌟 群内文件自动归档：图片 / 视频 / 文件消息写入归档列表
export function archiveFromMsg(gid: string, m: GroupMsg): void {
  if (m.kind === 'image') {
    addGroupFile(gid, `图片_${formatStamp(m.time).split(' ').join('_')}.jpg`, 'image', '—', m.name, m.media, m.id)
  } else if (m.kind === 'video') {
    addGroupFile(gid, `视频_${formatStamp(m.time).split(' ').join('_')}.mp4`, 'video', '—', m.name, m.media, m.id)
  } else if (m.kind === 'file') {
    addGroupFile(gid, m.fileName === '' ? '未命名文件' : m.fileName, 'doc',
      m.fileSize === '' ? '—' : m.fileSize, m.name, m.fileUri, m.id)
  }
}

export function fileKindName(kind: string): string {
  if (kind === 'image') {
    return '图片'
  }
  if (kind === 'video') {
    return '视频'
  }
  return '文档'
}

export function fileKindIcon(kind: string): string {
  if (kind === 'image') {
    return '🖼️'
  }
  if (kind === 'video') {
    return '🎬'
  }
  return '📄'
}

export function fileExpireAt(f: GroupFile): number {
  let days = f.retentionDays === undefined || f.retentionDays <= 0 ? retentionDays() : f.retentionDays
  return f.uploadAt + days * 86400000
}

export function fileExpired(f: GroupFile): boolean {
  return Date.now() >= fileExpireAt(f)
}

export function fileExpireLabel(f: GroupFile): string {
  if (fileExpired(f)) {
    return '已过期'
  }
  let left = Math.ceil((fileExpireAt(f) - Date.now()) / 86400000)
  return `${left} 天后清理`
}

// 清理过期归档（本地模拟云端清理策略）
export function cleanExpiredFiles(gid: string): number {
  let all = AppStorage.get<GroupFile[]>('groupFiles') ?? []
  let keep: GroupFile[] = []
  let removed = 0
  all.forEach((f: GroupFile) => {
    if (f.groupId === gid && fileExpired(f)) {
      removed++
    } else {
      keep.push(f)
    }
  })
  saveFiles(keep)
  return removed
}

// ==================== 举报 ====================
export function reportsOf(gid: string): GroupReport[] {
  let all = AppStorage.get<GroupReport[]>('groupReports') ?? []
  return all.filter((r: GroupReport) => r.groupId === gid)
    .sort((a: GroupReport, b: GroupReport) => b.createdAt - a.createdAt)
}

export function addReport(r: GroupReport): void {
  let all = AppStorage.get<GroupReport[]>('groupReports') ?? []
  AppStorage.setOrCreate('groupReports', [r].concat(all))
}

export function reportStatusName(s: string): string {
  if (s === 'reviewing') {
    return '审核中'
  }
  if (s === 'done') {
    return '已处理'
  }
  return '待审核'
}

// ==================== 群操作 ====================
export function notifyGroup(gid: string, text: string, actor: string): void {
  let m = new GroupMsg()
  m.id = `sys_${Date.now()}_${Math.floor(Math.random() * 1000)}`
  m.name = '群通知'
  m.role = 'teacher'
  m.kind = 'system'
  m.text = `${text}\n（本地模拟通知，未接入真实推送服务）`
  m.time = Date.now()
  let list = msgsOf(gid).concat([m])
  saveMsgs(gid, list)
  archiveAppend(gid, m)
  if (actor !== currentName()) {
    bumpUnread(gid)
  }
}

export function transferOwner(gid: string, name: string): void {
  let g = groupById(gid)
  if (g === undefined) {
    return
  }
  g.ownerName = name
  saveGroup(g)
  let list = membersOf(gid).slice()
  list.forEach((m: GroupMember) => {
    if (m.name === name && m.role === 'student') {
      m.role = 'assistant'
    }
  })
  saveMembers(gid, list)
  notifyGroup(gid, `群主已移交给 ${name}。`, currentName())
}

export function dissolveGroup(gid: string): void {
  let g = groupById(gid)
  if (g === undefined) {
    return
  }
  g.dissolved = true
  saveGroup(g)
  notifyGroup(gid, '该群聊已被群主解散。', currentName())
}

// 🌟 退出课程：标记已退出，并把当前用户从各群成员中移除（模拟收回课程访问权限）
export function quitCourse(): void {
  AppStorage.setOrCreate('courseQuit', true)
  // 🌟 退出课程同时撤销选课关系，避免「已退出」但仍能访问学科页 / 班级群
  Permission.leaveCourse(GROUP_COURSE_ID)
  let name = currentName()
  let map = copyMemberMap()
  Object.keys(map).forEach((gid: string) => {
    map[gid] = map[gid].filter((m: GroupMember) => m.name !== name)
  })
  AppStorage.setOrCreate('groupMembersMap', map)
}

export function courseQuit(): boolean {
  return AppStorage.get<boolean>('courseQuit') ?? false
}

// 🌟 仅用于演示环境恢复访问，按钮会明确标注「演示」
export function restoreCourseDemo(): void {
  // 同步恢复选课关系，否则 Guard.course 仍会拦截班级群与学科页
  Permission.joinCourse(GROUP_COURSE_ID)
  AppStorage.setOrCreate('courseQuit', false)
}

// ==================== 演示数据 ====================
function seedMsg(id: string, name: string, role: string, text: string, minutesAgo: number): GroupMsg {
  let m = new GroupMsg()
  m.id = id
  m.name = name
  m.role = role
  m.text = text
  m.time = Date.now() - minutesAgo * 60000
  return m
}

function seedFile(gid: string, name: string, kind: string, size: string, uploader: string,
  hoursAgo: number): GroupFile {
  let f = new GroupFile(gid, name, kind, size, uploader, '')
  f.uploadAt = Date.now() - hoursAgo * 3600000
  f.retentionDays = DEFAULT_RETENTION_DAYS
  return f
}

// 🌟 首次启动灌入主群 + 子分组群、公告、归档文件、云端归档与未读
export function ensureGroupSeed(): void {
  if (AppStorage.get<boolean>('groupSeeded') === true) {
    return
  }
  let now = Date.now()

  let main = new ChatGroup(MAIN_GROUP_ID, MAIN_GROUP_NAME, true, MAIN_TEACHER)
  main.intro = '本课程主班级群，授课教师与全体学生共同交流'
  main.createdAt = now - 30 * 86400000
  let sub1 = new ChatGroup('g_ds_algo', '算法攻坚小组', false, MAIN_TEACHER)
  sub1.intro = '主群衍生的算法专题讨论组'
  sub1.createdAt = now - 12 * 86400000
  let sub2 = new ChatGroup('g_ds_review', '期末复习互助组', false, MAIN_TEACHER)
  sub2.intro = '期末复习资料共享与互助答疑'
  sub2.createdAt = now - 5 * 86400000
  AppStorage.setOrCreate('chatGroups', [main, sub1, sub2])

  // 成员：主群含全名学生，并把李小红设为助教；子群为部分成员
  let mainMembers: GroupMember[] = groupMembers()
  mainMembers.forEach((m: GroupMember) => {
    if (m.name === '李小红') {
      m.role = 'assistant'
    }
  })
  // 演示环境把当前登录用户也加入主群，便于体验成员管理与退出课程
  let me = currentName()
  let hasMe = mainMembers.some((m: GroupMember) => m.name === me)
  if (!hasMe && currentRole() !== 'teacher') {
    mainMembers.push(new GroupMember(me, currentRole() === 'assistant' ? 'assistant' : 'student'))
  }
  let algoMembers: GroupMember[] = [new GroupMember(MAIN_TEACHER, 'teacher')]
  algoMembers.push(new GroupMember('王小明', 'student'))
  algoMembers.push(new GroupMember('张一凡', 'student'))
  let reviewMembers: GroupMember[] = [new GroupMember(MAIN_TEACHER, 'teacher')]
  reviewMembers.push(new GroupMember('李小红', 'assistant'))
  reviewMembers.push(new GroupMember('刘思远', 'student'))
  reviewMembers.push(new GroupMember('陈雨欣', 'student'))
  let memberMap: Record<string, GroupMember[]> = {}
  memberMap[MAIN_GROUP_ID] = mainMembers
  memberMap['g_ds_algo'] = algoMembers
  memberMap['g_ds_review'] = reviewMembers
  AppStorage.setOrCreate('groupMembersMap', memberMap)

  // 群公告
  let n1 = new GroupNotice(MAIN_GROUP_ID, '第 8 周课程安排',
    '## 本周重点\n- 图的深度优先遍历与广度优先遍历\n- 最短路径 Dijkstra 算法\n**周五 19:00** 线上答疑，请提前准备问题。', MAIN_TEACHER)
  n1.pinned = true
  n1.attachmentName = '第8周课件.pdf'
  n1.createdAt = now - 6 * 3600000
  n1.updatedAt = n1.createdAt
  n1.readBy = ['王小明', '张一凡', '李小红']
  let n2 = new GroupNotice(MAIN_GROUP_ID, '作业提交流程说明',
    '作业请在「我的作业」中提交，支持文字、照片与录音。\n- 截止时间前可修改\n**逾期提交会按规则扣分**。', MAIN_TEACHER)
  n2.pinned = false
  n2.createdAt = now - 3 * 86400000
  n2.updatedAt = n2.createdAt
  n2.readBy = ['王小明']
  let n3 = new GroupNotice('g_ds_algo', '算法专题讨论',
    '## 讨论主题\n- 递归与分治\n本周六晚一起过一遍经典题单。', MAIN_TEACHER)
  n3.pinned = true
  n3.createdAt = now - 8 * 3600000
  n3.updatedAt = n3.createdAt
  n3.readBy = []
  AppStorage.setOrCreate('groupNotices', [n1, n2, n3])

  // 文件归档（本地模拟云端存储）
  let files: GroupFile[] = []
  files.push(seedFile(MAIN_GROUP_ID, '第8周课件.pdf', 'doc', '1.8MB', MAIN_TEACHER, 6))
  files.push(seedFile(MAIN_GROUP_ID, '实验报告模板.docx', 'doc', '96KB', MAIN_TEACHER, 30))
  files.push(seedFile(MAIN_GROUP_ID, '图的遍历思维导图.png', 'image', '860KB', '王小明', 20))
  files.push(seedFile(MAIN_GROUP_ID, '课程录播-图的遍历.mp4', 'video', '128MB', MAIN_TEACHER, 48))
  files.push(seedFile('g_ds_algo', '算法题单.docx', 'doc', '120KB', MAIN_TEACHER, 10))
  AppStorage.setOrCreate('groupFiles', files)

  // 云端聊天归档（本地模拟）：清空本地记录后仍可检索
  let mainArchive: GroupMsg[] = []
  mainArchive.push(seedMsg('a1', MAIN_TEACHER, 'teacher', '欢迎同学们加入班级群，学习问题可以随时在这里讨论～', 180))
  mainArchive.push(seedMsg('a2', '王小明', 'student', '老师好！同学们好！', 175))
  mainArchive.push(seedMsg('a3', MAIN_TEACHER, 'teacher', '第 8 周课件已经上传到群文件，大家提前预习一下。', 120))
  let fa = seedMsg('a4', MAIN_TEACHER, 'teacher', '第8周课件.pdf', 118)
  fa.kind = 'file'
  fa.fileName = '第8周课件.pdf'
  fa.fileSize = '1.8MB'
  mainArchive.push(fa)
  mainArchive.push(seedMsg('a5', '李小红', 'assistant', '收到，谢谢老师！有问题我会在群里汇总。', 90))
  mainArchive.push(seedMsg('a6', '张一凡', 'student', '老师，Dijkstra 算法的手写推导可以再讲一遍吗？', 40))
  let algoArchive: GroupMsg[] = []
  algoArchive.push(seedMsg('b1', MAIN_TEACHER, 'teacher', '这个小组主要讨论算法题，周五前把题单做完。', 300))
  algoArchive.push(seedMsg('b2', '王小明', 'student', '好的，我先做递归部分。', 280))
  let archiveMap: Record<string, GroupMsg[]> = {}
  archiveMap[MAIN_GROUP_ID] = mainArchive
  archiveMap['g_ds_algo'] = algoArchive
  AppStorage.setOrCreate('groupChatArchive', archiveMap)

  // 未读红点（本地模拟多端同步）
  let unread: Record<string, number> = {}
  unread[MAIN_GROUP_ID] = 2
  unread['g_ds_algo'] = 1
  AppStorage.setOrCreate('groupUnreadMap', unread)

  let muteMap: Record<string, string> = {}
  muteMap[MAIN_GROUP_ID] = 'off'
  AppStorage.setOrCreate('groupMuteMap', muteMap)
  AppStorage.setOrCreate('fileRetentionDays', DEFAULT_RETENTION_DAYS)
  AppStorage.setOrCreate('assistantCanCreate', false)
  AppStorage.setOrCreate('courseQuit', false)
  AppStorage.setOrCreate('groupSeeded', true)
}
