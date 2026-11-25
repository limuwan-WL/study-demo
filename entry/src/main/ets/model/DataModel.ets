// ==================== 日期工具 ====================

export function formatDate(d: Date): string {
  let m = (d.getMonth() + 1).toString().padStart(2, '0')
  let day = d.getDate().toString().padStart(2, '0')
  return `${d.getFullYear()}-${m}-${day}`
}

export function formatTime(d: Date): string {
  let h = d.getHours().toString().padStart(2, '0')
  let min = d.getMinutes().toString().padStart(2, '0')
  return `${h}:${min}`
}

export function getTodayStr(): string {
  return formatDate(new Date())
}

export function formatStamp(ts: number): string {
  let d = new Date(ts)
  return `${formatDate(d).slice(5)} ${formatTime(d)}`
}

// 🌟 关注列表时间展示：今天显示时分、昨天带前缀，更早显示日期，避免一长串时间戳
export function formatUpdateTime(ts: number): string {
  if (ts === undefined || ts <= 0) {
    return ''
  }
  let now = new Date()
  let d = new Date(ts)
  let todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
  if (ts >= todayStart) {
    if (now.getTime() - ts < 60000) {
      return '刚刚'
    }
    return `今天 ${formatTime(d)}`
  }
  if (ts >= todayStart - 86400000) {
    return `昨天 ${formatTime(d)}`
  }
  if (d.getFullYear() === now.getFullYear()) {
    return formatStamp(ts)
  }
  return formatDate(d)
}

export function parseDateTime(date: string, time: string): Date {
  let dp = date.split('-')
  let tp = time.split(':')
  let d = new Date()
  d.setFullYear(parseInt(dp[0]), parseInt(dp[1]) - 1, parseInt(dp[2]))
  d.setHours(parseInt(tp[0]), parseInt(tp[1]), 0, 0)
  return d
}

export function sortSchedule(list: ScheduleItem[]): ScheduleItem[] {
  return list.slice().sort((a: ScheduleItem, b: ScheduleItem) => {
    return parseDateTime(a.date, a.time).getTime() - parseDateTime(b.date, b.time).getTime()
  })
}

export function genId(): string {
  return Date.now().toString() + Math.random().toString()
}

// ==================== 用户等级系统 ====================

// 🌟 用户等级 LV0~LV6：由昵称稳定计算（同一昵称永远同一等级，无需持久化），在评论、聊天、个人页等场景展示
export function userLevel(name: string): number {
  if (name === '') {
    return 0
  }
  let hash = 0
  for (let i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.charCodeAt(i)) % 99991
  }
  return hash % 7
}

// 🌟 等级徽章颜色：随等级递进，LV6 为最高级橙色
export function levelColor(level: number): string {
  const colors: string[] = ['#BFC4CE', '#82C25B', '#4FC3F7', '#5B8FF6', '#9B6DF6', '#F65B8E', '#FFA00A']
  return colors[level] || colors[0]
}

// ==================== 数据模型 ====================

export class TodoItem {
  id: string = ''
  content: string = ''
  isDone: boolean = false
  dueDate: string = '' // 截止时间，格式 YYYY-MM-DD，空表示未设置
  priority: string = '中' // 高 / 中 / 低
  category: string = '' // 分类标签

  constructor(content: string, dueDate: string = '', priority: string = '中', category: string = '') {
    this.id = genId()
    this.content = content
    this.dueDate = dueDate
    this.priority = priority
    this.category = category
  }
}

export class ScheduleItem {
  id: string = ''
  content: string = ''
  date: string = ''
  time: string = ''
  constructor(content: string, date: string, time: string) {
    this.id = genId()
    this.content = content
    this.date = date
    this.time = time
  }
}

// 🌟 帖子时间排序键：优先用发帖时的 createdAt，种子帖解析时间文案（HH:mm / 昨天 / N天前 / 周X）
export function parsePostTime(p: PostItem): number {
  if (p.createdAt > 0) {
    return p.createdAt
  }
  const now = new Date()
  const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
  const t: string = p.time || ''
  if (t === '刚刚') {
    return now.getTime()
  }
  const days = t.match(/^(\d+)天前/)
  if (days !== null && days.length > 1) {
    return midnight - Number(days[1]) * 86400000 + 43200000
  }
  if (t.indexOf('昨天') >= 0) {
    const hm = t.match(/(\d{1,2}):(\d{2})/)
    const mins = hm !== null && hm.length > 2 ? Number(hm[1]) * 60 + Number(hm[2]) : 720
    return midnight - 86400000 + mins * 60000
  }
  const week: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
  for (let i = 0; i < 7; i++) {
    if (t === week[i]) {
      // 取该星期几最近一次出现；若落在本周今天及以后则回退一周，保证早于「昨天」
      let d = new Date(now.getFullYear(), now.getMonth(), now.getDate())
      while (d.getDay() !== i) {
        d = new Date(d.getFullYear(), d.getMonth(), d.getDate() - 1)
      }
      let ts = d.getTime()
      if (ts >= midnight) {
        ts -= 7 * 86400000
      }
      return ts + 43200000
    }
  }
  const hm2 = t.match(/(\d{1,2}):(\d{2})/)
  if (hm2 !== null && hm2.length > 2) {
    return midnight + Number(hm2[1]) * 3600000 + Number(hm2[2]) * 60000
  }
  return 0
}

// ==================== 笔记模块 ====================

// 🌟 默认笔记本 id 固定，便于老数据迁移与「不可删除」判断
export const NOTEBOOK_DEFAULT_ID: string = 'nb_default'

export class NotebookItem {
  id: string = ''
  name: string = ''
  order: number = 0
  isDefault: boolean = false
  createTime: number = 0

  constructor(name: string, order: number = 0, isDefault: boolean = false, id: string = '') {
    this.id = id === '' ? genId() : id
    this.name = name
    this.order = order
    this.isDefault = isDefault
    this.createTime = Date.now()
  }
}

// 笔记内插入的链接
export class NoteLink {
  id: string = ''
  title: string = ''
  url: string = ''

  constructor(title: string, url: string) {
    this.id = genId()
    this.title = title
    this.url = url
  }
}

export class NoteItem {
  id: string = ''
  title: string = ''
  content: string = ''
  createTime: number = 0
  updatedAt: number = 0
  notebookId: string = NOTEBOOK_DEFAULT_ID
  tags: string[] = []
  images: string[] = []
  links: NoteLink[] = []
  pinned: boolean = false
  visibility: string = 'private' // private 私有 / course 仅课程内可见 / public 公开
  // 🌟 课程可见笔记绑定的课程 id；历史笔记为空时按旧的「已加入任意课程」规则兼容
  courseId: string = ''
  shareCode: string = ''
  version: number = 1 // 本地版本号，每次保存 +1
  baseVersion: number = 0 // 上次与云端同步时的版本号，用于冲突检测
  syncState: string = 'local' // local 仅本地 / pending 待同步 / synced 已同步 / conflict 冲突
  isDeleted: boolean = false
  deletedAt: number = 0
  // 🌟 笔记引用：课件名称 / 课程视频时间节点（本地记录，便于回溯课程内容）
  refTitle: string = ''
  refTime: string = ''

  constructor(title: string, content: string) {
    this.id = genId()
    this.title = title
    this.content = content
    this.createTime = Date.now()
    this.updatedAt = this.createTime
  }
}

// 🌟 深拷贝：列表 / 云端快照 / 冲突弹窗都基于副本操作，避免直接改到持久化对象
export function cloneNote(n: NoteItem): NoteItem {
  let copy = new NoteItem(n.title, n.content)
  copy.id = n.id
  copy.createTime = n.createTime
  copy.updatedAt = n.updatedAt
  copy.notebookId = n.notebookId
  let rawTags: string[] = n.tags === undefined ? [] : n.tags
  copy.tags = rawTags.slice()
  let rawImages: string[] = n.images === undefined ? [] : n.images
  copy.images = rawImages.slice()
  let links: NoteLink[] = []
  let rawLinks: NoteLink[] = n.links === undefined ? [] : n.links
  rawLinks.forEach((l: NoteLink) => {
    let cl = new NoteLink(l.title, l.url)
    cl.id = l.id
    links.push(cl)
  })
  copy.links = links
  copy.pinned = n.pinned
  copy.visibility = n.visibility
  copy.courseId = n.courseId === undefined ? '' : n.courseId
  copy.shareCode = n.shareCode
  copy.version = n.version
  copy.baseVersion = n.baseVersion
  copy.syncState = n.syncState
  copy.isDeleted = n.isDeleted
  copy.deletedAt = n.deletedAt
  copy.refTitle = n.refTitle === undefined ? '' : n.refTitle
  copy.refTime = n.refTime === undefined ? '' : n.refTime
  if (copy.updatedAt === undefined || copy.updatedAt === 0) {
    copy.updatedAt = copy.createTime
  }
  return copy
}

// 🌟 引用文案：课件名 / 视频时间节点（兼容历史笔记缺失字段）
export function noteRefText(n: NoteItem): string {
  let title = n.refTitle === undefined ? '' : n.refTitle
  let time = n.refTime === undefined ? '' : n.refTime
  if (title === '' && time === '') {
    return ''
  }
  if (title === '') {
    return `视频节点 ${time}`
  }
  if (time === '') {
    return `课件 ${title}`
  }
  return `课件 ${title} · ${time}`
}

export function visibilityLabel(v: string): string {
  if (v === 'course') {
    return '仅课程内可见'
  }
  if (v === 'public') {
    return '公开'
  }
  return '私有'
}

export function copyNotes(list: NoteItem[]): NoteItem[] {
  return list.map((n: NoteItem) => cloneNote(n))
}

export function copyNotebooks(list: NotebookItem[]): NotebookItem[] {
  return list.map((b: NotebookItem) => {
    let nb = new NotebookItem(b.name, b.order, b.isDefault, b.id)
    nb.createTime = b.createTime
    return nb
  })
}

// 🌟 老数据迁移：补齐新增字段（老版本只存了 title/content/createTime）
export function normalizeNotes(list: NoteItem[]): NoteItem[] {
  return list.map((raw: NoteItem) => {
    let n = cloneNote(raw)
    if (n.notebookId === undefined || n.notebookId === '') {
      n.notebookId = NOTEBOOK_DEFAULT_ID
    }
    if (n.tags === undefined) {
      n.tags = []
    }
    if (n.images === undefined) {
      n.images = []
    }
    if (n.links === undefined) {
      n.links = []
    }
    if (n.visibility === undefined || n.visibility === '') {
      n.visibility = 'private'
    }
    if (n.shareCode === undefined) {
      n.shareCode = ''
    }
    if (n.pinned === undefined) {
      n.pinned = false
    }
    if (n.version === undefined || n.version < 1) {
      n.version = 1
    }
    if (n.baseVersion === undefined) {
      n.baseVersion = 0
    }
    if (n.syncState === undefined || n.syncState === '') {
      n.syncState = 'local'
    }
    if (n.updatedAt === undefined || n.updatedAt === 0) {
      n.updatedAt = n.createTime > 0 ? n.createTime : Date.now()
    }
    if (n.isDeleted === undefined) {
      n.isDeleted = false
    }
    if (n.deletedAt === undefined) {
      n.deletedAt = 0
    }
    return n
  })
}

// 🌟 保证「默认笔记本」始终存在且排在第一位；排序值重新编号
export function normalizeNotebooks(list: NotebookItem[]): NotebookItem[] {
  let res = copyNotebooks(list)
  let hasDefault = false
  res.forEach((b: NotebookItem) => {
    if (b.id === NOTEBOOK_DEFAULT_ID || b.isDefault) {
      hasDefault = true
      b.isDefault = true
      b.id = NOTEBOOK_DEFAULT_ID
      b.name = b.name === '' ? '默认笔记本' : b.name
    }
    if (b.name === undefined || b.name === '') {
      b.name = '未命名笔记本'
    }
    if (b.order === undefined) {
      b.order = 0
    }
  })
  if (!hasDefault) {
    res.push(new NotebookItem('默认笔记本', 0, true, NOTEBOOK_DEFAULT_ID))
  }
  res.sort((a: NotebookItem, b: NotebookItem) => a.order - b.order)
  res.forEach((b: NotebookItem, i: number) => b.order = i)
  return res
}

// 🌟 笔记排序：置顶优先，再按创建 / 修改时间倒序
export function sortNotes(list: NoteItem[], by: string): NoteItem[] {
  return list.slice().sort((a: NoteItem, b: NoteItem) => {
    if (a.pinned !== b.pinned) {
      return a.pinned ? -1 : 1
    }
    let ta = by === 'create' ? a.createTime : a.updatedAt
    let tb = by === 'create' ? b.createTime : b.updatedAt
    return tb - ta
  })
}

export function noteSummaryText(n: NoteItem): string {
  let text = (n.content ?? '').trim()
  if (text === '') {
    text = n.images.length > 0 ? `图片 ${n.images.length} 张` : '（无正文）'
  } else if (n.images.length > 0) {
    text = `${text} · ${n.images.length} 张图片`
  }
  return text
}

// type: 'link' 手动添加的网址 | 'post' 发现页收藏的帖子
export class FavItem {
  id: string = ''
  title: string = ''
  url: string = ''
  type: string = 'link'
  postId: string = ''
  constructor(title: string, url: string, type: string = 'link', postId: string = '') {
    this.id = genId()
    this.title = title
    this.url = url
    this.type = type
    this.postId = postId
  }
}

export class PostItem {
  id: string = ''
  title: string = ''
  brief: string = ''
  content: string = ''
  author: string = ''
  category: string = '' // 学习分享 / 求助
  time: string = ''
  likes: number = 0
  liked: boolean = false
  comments: number = 0
  createdAt: number = 0 // 🌟 发帖时间戳，用于列表按时间排序（种子帖为 0，走时间文案解析）

  constructor(title: string, brief: string, content: string, author: string, category: string, time: string, id: string = '') {
    this.id = id === '' ? genId() : id
    this.title = title
    this.brief = brief
    this.content = content
    this.author = author
    this.category = category
    this.time = time
  }
}

// 🌟 底部「发现」红点：尚未查看过的帖子数，自己发布的帖子不算新内容
export function unreadPostCount(posts: PostItem[], readIds: string[], self: string): number {
  return posts.filter((p: PostItem) => readIds.indexOf(p.id) < 0 && p.author !== self).length
}

// type: 'like' 点赞通知 | 'comment' 评论通知 | 'system' 系统通知
export class MessageItem {
  id: string = ''
  type: string = ''
  sender: string = ''
  content: string = ''
  time: string = ''
  isRead: boolean = false
  postId: string = '' // 空 = 系统通知，不跳转
  // 🌟 统一跳转：route 为目标页面，taskId 为互动任务 id；历史消息无此字段时为空串
  route: string = ''
  taskId: string = ''

  constructor(id: string, type: string, sender: string, content: string, time: string, isRead: boolean,
    postId: string = '', route: string = '', taskId: string = '') {
    this.id = id
    this.type = type
    this.sender = sender
    this.content = content
    this.time = time
    this.isRead = isRead
    this.postId = postId
    this.route = route
    this.taskId = taskId
  }
}

// 聊天消息：按联系人分组持久化在 chatMap 里
export class ChatMessage {
  id: string = ''
  content: string = ''
  isMe: boolean = false
  time: string = ''

  constructor(id: string, content: string, isMe: boolean) {
    this.id = id
    this.content = content
    this.isMe = isMe
    let date = new Date()
    this.time = `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
  }
}

// 🌟 帖子评论：按帖子 id 分组持久化在 commentMap 里
// replyToId 非空 = 挂在某条评论下方的回复；likes/dislikes/myVote = 评论点赞点踩（myVote: 1 赞 -1 踩 0 无）
export class CommentItem {
  id: string = ''
  author: string = ''
  content: string = ''
  time: string = ''
  replyToAuthor: string = ''
  replyToId: string = ''
  likes: number = 0
  dislikes: number = 0
  myVote: number = 0

  constructor(author: string, content: string, replyToAuthor: string = '', replyToId: string = '') {
    this.id = genId()
    this.author = author
    this.content = content
    this.time = formatTime(new Date())
    this.replyToAuthor = replyToAuthor
    this.replyToId = replyToId
  }
}

// 🌟 模拟其他用户互动用的昵称与评论文案
export const SIM_USERS: string[] = ['李同学', '王老师', '学霸小李', '跨端小能手', '热心同学']
export const SIM_COMMENTS: string[] = ['写得不错，支持一下！', '收藏了，谢谢分享！', '正好用得上，感谢！', '讲得很清楚，学到了', '顶一个，期待更多分享！']

// ==================== 金币体系 ====================
export type CoinOpType = 'recharge' | 'tip' | 'like' | 'task'

export class CoinRecord {
  id: string = ''
  type: CoinOpType = 'recharge'
  amount: number = 0
  desc: string = ''
  time: number = 0
  constructor(type: CoinOpType, amount: number, desc: string) {
    this.id = genId()
    this.type = type
    this.amount = amount
    this.desc = desc
    this.time = Date.now()
  }
}

// ==================== 金币充值订单与开票 ====================
export class CoinOrder {
  id: string = ''
  orderNo: string = ''
  channel: string = '微信'
  amountYuan: number = 0
  coins: number = 0
  time: number = 0
  // none 未开票 / applied 已申请 / issued 已开具
  invoiceState: string = 'none'
  invoiceTitle: string = ''
  invoiceTaxNo: string = ''

  constructor(channel: string, amountYuan: number, coins: number) {
    this.id = genId()
    this.channel = channel
    this.amountYuan = amountYuan
    this.coins = coins
    this.time = Date.now()
    let d = new Date(this.time)
    let mm = (d.getMonth() + 1).toString().padStart(2, '0')
    let dd = d.getDate().toString().padStart(2, '0')
    this.orderNo = `R${d.getFullYear()}${mm}${dd}${this.time.toString().slice(-6)}`
  }
}

// ==================== 随堂练习 ====================
export type QType = 'single' | 'multi' | 'judge' | 'fill' | 'essay' | 'image'

export class PracticeQuestion {
  id: string = ''
  title: string = ''
  type: QType = 'single'
  opts: string[] = []
  answer: number | number[] | string = 0
  analysis: string = ''
  constructor(title: string, type: QType) {
    this.id = genId()
    this.title = title
    this.type = type
    if (type === 'judge') { this.opts = ['正确', '错误']; this.answer = 0 }
    else if (type === 'single' || type === 'multi') { this.opts = ['选项A', '选项B'] }
  }
}

// ==================== 调查问卷 ====================
export type SurveyType = 'single' | 'multi' | 'scale' | 'essay'

export class SurveyQuestion {
  id: string = ''
  title: string = ''
  type: SurveyType = 'single'
  opts: string[] = []
  maxScale: number = 5
  constructor(title: string, type: SurveyType) {
    this.id = genId()
    this.title = title
    this.type = type
    if (type === 'single' || type === 'multi') { this.opts = ['选项A', '选项B'] }
  }
}

// ==================== 积分规则 ====================
// 🌟 互动任务相关模型（签到 / 练习 / 问卷 / 抽选 / 任务台账）统一放在 InteractionModel
export class PointRecord {
  id: string = ''
  action: string = ''
  points: number = 0
  total: number = 0
  time: string = ''
  // 🌟 学分台账扩展：归属学生 + 所属课程 + 行为键（签到 / 练习 / 抽选）
  student: string = ''
  courseId: string = ''
  actionKey: string = ''
  constructor(action: string, points: number, total: number) {
    this.id = genId()
    this.action = action
    this.points = points
    this.total = total
    this.time = formatTime(new Date())
  }
}

// ==================== 关注 ====================
export type FollowType = 'teacher' | 'course' | 'note' | 'activity'

export class FollowItem {
  id: string = ''
  type: FollowType = 'teacher'
  title: string = ''
  cover: string = ''
  updateTime: string = ''
  hasNew: boolean = false
  updatedAt: number = 0 // 🌟 内容最近更新时间戳，用于「按更新时间」排序
  followedAt: number = 0 // 🌟 关注时间戳，用于「按关注时间」排序
  targetId: string = ''
  targetType: string = ''
  constructor(type: FollowType, title: string, cover: string, updatedAt: number = 0, followedAt: number = 0,
    targetId: string = '', targetType: string = '') {
    this.id = genId()
    this.type = type
    this.title = title
    this.cover = cover
    this.targetId = targetId
    this.targetType = targetType === '' ? type : targetType
    let now = Date.now()
    this.updatedAt = updatedAt > 0 ? updatedAt : now
    this.followedAt = followedAt > 0 ? followedAt : now
    this.updateTime = formatStamp(this.updatedAt)
  }
}

// 🌟 旧数据兼容：补齐新增的时间戳字段，缺失时按列表顺序倒推，保证排序与时间展示可用
export function normalizeFollows(list: FollowItem[]): FollowItem[] {
  let now = Date.now()
  return list.map((raw: FollowItem, index: number) => {
    let f = new FollowItem(raw.type, raw.title, raw.cover)
    f.id = raw.id
    // 🌟 兼容老数据：补齐跳转目标字段
    f.targetId = raw.targetId === undefined ? '' : raw.targetId
    f.targetType = raw.targetType === undefined || raw.targetType === '' ? raw.type : raw.targetType
    f.hasNew = raw.hasNew === true
    f.updatedAt = raw.updatedAt === undefined || raw.updatedAt <= 0 ? now - index * 3600000 : raw.updatedAt
    f.followedAt = raw.followedAt === undefined || raw.followedAt <= 0 ? now - index * 86400000 : raw.followedAt
    f.updateTime = formatStamp(f.updatedAt)
    return f
  })
}

// 🌟 初始关注数据：更新时间与关注时间刻意错开，便于验证两种排序方式的差异
export function defaultFollows(): FollowItem[] {
  let now = Date.now()
  let list: FollowItem[] = []
  let t = new FollowItem('teacher', '王建国 · 数据结构', '👨‍🏫', now - 8 * 60000, now - 26 * 86400000, 't_wang', 'teacher')
  t.hasNew = true
  list.push(t)
  list.push(new FollowItem('course', '高等数学（上）', '📐', now - 3 * 3600000, now - 32 * 86400000, 'advmath', 'course'))
  let n = new FollowItem('note', '期末复习清单', '📝', now - 20 * 3600000, now - 2 * 86400000, '', 'note')
  n.hasNew = true
  list.push(n)
  list.push(new FollowItem('activity', '校园编程大赛', '🏆', now - 5 * 86400000, now - 40 * 86400000))
  return list
}

// ==================== 讲师 ====================
// 🌟 课程归属：local 本校授课课程 / public 公开课程
export type TeacherCourseType = 'local' | 'public'

// 🌟 讲师课程：一门课程可绑定多位教师（教师侧按课程 id 关联），url 用于跳转对应课程页面
export class TeacherCourse {
  id: string = ''
  name: string = ''
  type: TeacherCourseType = 'local'
  subjectId: string = ''
  url: string = ''

  constructor(id: string, name: string, type: TeacherCourseType, subjectId: string, url: string) {
    this.id = id
    this.name = name
    this.type = type
    this.subjectId = subjectId
    this.url = url
  }
}

// 🌟 公开课件资源（讲义 / 课件 / 习题集）
export class TeacherMaterial {
  title: string = ''
  kind: string = ''
  size: string = ''

  constructor(title: string, kind: string, size: string) {
    this.title = title
    this.kind = kind
    this.size = size
  }
}

export class Teacher {
  id: string = ''
  name: string = ''
  title: string = ''
  avatar: string = '' // 头像图片地址，为空时展示占位头像
  avatarText: string = '' // 头像占位文字（姓名首字）
  department: string = ''
  bio: string = ''
  career: string = ''
  researchAreas: string[] = []
  courses: TeacherCourse[] = []
  materials: TeacherMaterial[] = []
  followed: boolean = false
  followers: number = 0
  account: string = '' // 主页归属账号，空表示当前登录讲师本人

  constructor(id: string, name: string, title: string, bio: string) {
    this.id = id
    this.name = name
    this.title = title
    this.bio = bio
    this.avatarText = name === '' ? '' : name.slice(0, 1)
  }
}

// 🌟 讲师演示数据：同一门课程（如「数据结构」）绑定多位教师
export function defaultTeachers(): Teacher[] {
  let wang = new Teacher('t_wang', '王建国', '教授 · 博导',
    '计算机科学与技术学院教授，主要研究方向为数据结构与算法、分布式系统。主持国家级科研项目 3 项，发表 SCI 论文 20 余篇，获省级教学成果一等奖。')
  wang.department = '计算机科学与技术学院'
  wang.career = '1998 年毕业于清华大学计算机系，2004 年获博士学位；2004 年至今任教于本校计算机科学与技术学院，2012 年晋升教授、博士生导师。主持国家自然科学基金项目 3 项，出版《数据结构与算法实践》等教材 2 部。'
  wang.researchAreas = ['分布式系统', '算法设计', '数据库']
  wang.courses = [
    new TeacherCourse('c_wang_ds', '数据结构', 'local', 'csbasic', 'pages/subjects/CSBasicsPage'),
    new TeacherCourse('c_wang_algo', '高级算法', 'local', 'csbasic', 'pages/subjects/CSBasicsPage'),
    new TeacherCourse('c_wang_dist', '分布式系统原理', 'public', 'csbasic', 'pages/subjects/CSBasicsPage')
  ]
  wang.materials = [
    new TeacherMaterial('数据结构讲义（第 1-3 章）', 'PDF 讲义', '2.4 MB'),
    new TeacherMaterial('算法设计课堂课件', 'PPT 课件', '6.1 MB'),
    new TeacherMaterial('期末复习提纲与真题', 'PDF 习题', '1.2 MB')
  ]
  wang.followers = 1286

  let li = new Teacher('t_li', '李季', '副教授',
    '软件工程系副教授，专注于软件工程与项目管理教学，具有丰富的企业实践经验，曾主导多个大型软件项目的架构设计。')
  li.department = '软件工程系'
  li.career = '2006 年获软件工程硕士学位，曾就职于大型互联网企业担任架构师 6 年；2012 年进入本校任教，主讲软件工程与项目管理相关课程，指导学生多次获得软件设计大赛奖项。'
  li.researchAreas = ['软件工程', '软件架构', '敏捷开发']
  li.courses = [
    new TeacherCourse('c_li_se', '软件工程', 'local', 'csbasic', 'pages/subjects/CSBasicsPage'),
    new TeacherCourse('c_li_pm', '软件项目管理', 'public', 'csbasic', 'pages/subjects/CSBasicsPage')
  ]
  li.materials = [
    new TeacherMaterial('软件工程课程设计指导书', 'PDF 讲义', '1.8 MB'),
    new TeacherMaterial('敏捷开发实战案例', 'PDF 案例', '3.5 MB')
  ]
  li.followed = true
  li.followers = 932

  let zhang = new Teacher('t_zhang', '张秀英', '讲师',
    '计算机基础教学部讲师，主讲大学计算机基础与程序设计，教学风格生动活泼，深受学生喜爱，连续三年获评学生最喜爱教师。')
  zhang.department = '计算机基础教学部'
  zhang.career = '2013 年硕士毕业后留校任教，长期承担计算机基础与程序设计类公共课程教学；主持校级教学改革项目 2 项，建设线上公开课程 1 门。'
  zhang.researchAreas = ['计算机教育', '程序设计入门']
  zhang.courses = [
    new TeacherCourse('c_zhang_base', '大学计算机基础', 'local', 'csbasic', 'pages/subjects/CSBasicsPage'),
    new TeacherCourse('c_zhang_c', 'C 语言程序设计', 'local', 'clang', 'pages/subjects/CProgrammingPage'),
    new TeacherCourse('c_zhang_ds', '数据结构', 'public', 'csbasic', 'pages/subjects/CSBasicsPage')
  ]
  zhang.materials = [
    new TeacherMaterial('大学计算机基础课件（全）', 'PPT 课件', '8.3 MB'),
    new TeacherMaterial('C 语言上机实验手册', 'PDF 实验', '2.0 MB')
  ]
  zhang.followers = 2043

  let chen = new Teacher('t_chen', '陈志强', '教授',
    '人工智能研究所教授、博士生导师，研究方向涵盖机器学习、自然语言处理与计算机视觉，在顶级会议发表论文多篇。')
  chen.department = '人工智能研究所'
  chen.career = '2003 年获计算机应用技术博士学位，曾赴海外访学两年；2010 年加入本校人工智能研究所，主持国家重点研发计划课题 1 项，发表 CCF-A 类论文 15 篇。'
  chen.researchAreas = ['机器学习', '自然语言处理', '计算机视觉']
  chen.courses = [
    new TeacherCourse('c_chen_ai', '人工智能导论', 'local', 'csbasic', 'pages/subjects/CSBasicsPage'),
    new TeacherCourse('c_chen_ml', '机器学习', 'public', 'csbasic', 'pages/subjects/CSBasicsPage'),
    new TeacherCourse('c_chen_dl', '深度学习', 'public', 'csbasic', 'pages/subjects/CSBasicsPage')
  ]
  chen.materials = [
    new TeacherMaterial('机器学习公开课课件', 'PPT 课件', '12.6 MB'),
    new TeacherMaterial('深度学习实验环境说明', 'PDF 文档', '0.9 MB')
  ]
  chen.followers = 1675

  // 🌟 王建国为「当前登录讲师本人」主页（account 为空表示可由讲师身份直接维护）
  return [wang, li, zhang, chen]
}

// 🌟 一门课程可绑定多名授课教师：按课程名筛选教师
export function teachersOfCourse(list: Teacher[], courseName: string): Teacher[] {
  return list.filter((t: Teacher) => t.courses.some((c: TeacherCourse) => c.name === courseName))
}

// 🌟 旧数据兼容：补齐新增字段，避免持久化数据缺字段导致渲染异常
export function normalizeTeachers(list: Teacher[]): Teacher[] {
  let result: Teacher[] = []
  list.forEach((t: Teacher) => {
    if (!t.researchAreas) {
      t.researchAreas = []
    }
    if (!t.courses) {
      t.courses = []
    }
    if (!t.materials) {
      t.materials = []
    }
    if (!t.avatarText) {
      t.avatarText = t.name ? t.name.slice(0, 1) : ''
    }
    if (!t.department) {
      t.department = ''
    }
    if (!t.career) {
      t.career = ''
    }
    if (!t.account) {
      t.account = ''
    }
    result.push(t)
  })
  return result
}

// ==================== 客服反馈 ====================
// 🌟 反馈记录只保存在本机（无后端），用于「我的反馈」历史列表展示
export class FeedbackItem {
  id: string = ''
  type: string = '功能异常'
  content: string = ''
  images: string[] = []
  createdAt: number = 0
  status: string = '已保存'

  constructor(type: string, content: string, images: string[]) {
    this.id = genId()
    this.type = type
    this.content = content
    this.images = images
    this.createdAt = Date.now()
  }
}

// ==================== 首次启动的种子数据 ====================

export function defaultPosts(): PostItem[] {
  let list: PostItem[] = []
  // 🌟 用户自己的帖子：消息页的点赞/评论通知都来自这篇（只出现和用户有关的信息）
  let p13 = new PostItem('第一次用 ArkTS 做出完整小应用', '从待办到社区页，记录我的第一个鸿蒙应用……', '从 Todo 列表到发现页社区，全部用声明式 UI 写完。最大的感受是状态管理一定要先想清楚数据流向，不然改一处牵全身。下面附上踩坑记录，欢迎交流！', '张同学', '学习分享', '10:00', 'p13')
  p13.likes = 8
  p13.comments = 2
  list.push(p13)
  let p1 = new PostItem('ArkTS 状态管理学习心得', '@State、@Prop、@Link 各有分工，用错了就白忙活……', '@State 适合组件内部状态，@Prop 单向同步，@Link 双向同步。跨页面共享数据用 @StorageLink 绑定 AppStorage，再配合 PersistentStorage 就能做到本地持久化，刷新也不丢。', '学霸小李', '学习分享', '10:24', 'p1')
  p1.likes = 12
  p1.comments = 3
  list.push(p1)
  let p2 = new PostItem('一次开发多端部署实战总结', '手机、平板、折叠屏一套代码全适配的思路……', '核心是自适应布局：断点 + 栅格 + 弹性布局。开发时多用百分比和 layoutWeight，少写固定宽高，折叠屏展开态用栅格重排卡片列数即可。', '跨端小能手', '学习分享', '09:15', 'p2')
  p2.likes = 8
  p2.comments = 2
  list.push(p2)
  let p3 = new PostItem('DevEco 模拟器启动白屏怎么办？', '模拟器一直卡在白屏，日志也没报错，求助……', '', '小白同学', '求助', '昨天', 'p3')
  p3.likes = 3
  p3.comments = 5
  list.push(p3)
  let p4 = new PostItem('HarmonyOS 本地持久化三种方案对比', 'Preferences、PersistentStorage、关系型数据库怎么选……', '轻量键值对用 Preferences；UI 状态跟着页面走用 PersistentStorage + AppStorage；数据量大、要条件查询就上关系型数据库。个人应用前两种基本够用。', '架构师老王', '学习分享', '昨天', 'p4')
  p4.likes = 21
  p4.comments = 4
  list.push(p4)
  let p5 = new PostItem('@StorageLink 绑定的数组界面不刷新？', '改了数组里的对象属性，列表就是不更新，求助……', '', '萌新报到', '求助', '周三', 'p5')
  p5.likes = 2
  p5.comments = 6
  list.push(p5)
  // 🌟 扩充帖子数量，社区内容更丰富
  let p6 = new PostItem('一周上手 ArkUI 的学习路线', '从声明式 UI 到组件化，我是这样安排的……', '第一周先过一遍声明式 UI 基本概念和常用组件，第二周练布局（Row/Column/Stack/Flex），第三周学状态管理，第四周做一个 TODO 小项目串起来。官方 Codelab 跟着敲一遍比看视频快。', '李同学', '学习分享', '周三', 'p6')
  p6.likes = 15
  p6.comments = 2
  list.push(p6)
  let p7 = new PostItem('Tabs 底部导航栏红点不显示？', 'Badge 放在 tabBar 里就是不出来，求助……', '', '萌新报到', '求助', '周二', 'p7')
  p7.likes = 1
  p7.comments = 3
  list.push(p7)
  let p8 = new PostItem('校园二手交易群运营一个月总结', '从 0 到 300 人的群，踩过的坑分享……', '定位要准：只做本校、只做二手。定价靠接龙表格，交易自担风险写进群公告。最有效的是每周固定开「跳蚤时间」，集中发品集中成交，群活跃度翻了三倍。', '热心同学', '学习分享', '周二', 'p8')
  p8.likes = 30
  p8.comments = 3
  list.push(p8)
  let p9 = new PostItem('真机调试证书配置求助', '签名一直报 9568322 错误，卡了一天了……', '', '小白同学', '求助', '周一', 'p9')
  p9.likes = 4
  p9.comments = 2
  list.push(p9)
  let p10 = new PostItem('用 List + LazyForEach 优化长列表', '500 条数据滚动也不卡了，记录一下……', '关键是 LazyForEach + IDataSource，只渲染可视区域的 item。item 布局尽量扁平，少嵌套；图片用固定尺寸避免重复测量。实测 500 条列表内存占用降了一半以上。', '架构师老王', '学习分享', '周一', 'p10')
  p10.likes = 18
  p10.comments = 2
  list.push(p10)
  let p11 = new PostItem('高数期末复习资料整理', '极限、导数、积分三块的易错点汇总……', '极限：等价无穷小替换注意条件；导数：复合函数链式法则别漏层；积分：先看能不能凑微分，再考虑分部积分。整理了 30 道易错题，评论区留邮箱发你们。', '学霸小李', '学习分享', '周日', 'p11')
  p11.likes = 42
  p11.comments = 3
  list.push(p11)
  let p12 = new PostItem('Swiper 轮播图自动播放会闪一下？', 'autoPlay 开了以后偶尔回跳到第一张，求助……', '', '跨端小能手', '求助', '周日', 'p12')
  p12.likes = 2
  p12.comments = 2
  list.push(p12)
  return list
}

export function defaultMessages(): MessageItem[] {
  let list: MessageItem[] = []
  // 🌟 点赞/评论通知只关联用户自己发的帖子（p13）
  list.push(new MessageItem('m1', 'like', '李同学', '李同学 赞了你的帖子「第一次用 ArkTS 做出完整小应用」', '10:30', false, 'p13'))
  list.push(new MessageItem('m2', 'comment', '王老师', '王老师 评论了你的帖子：写得很详细，继续加油！', '10:15', false, 'p13'))
  list.push(new MessageItem('m3', 'system', '系统通知', '欢迎来到校园小助手，记得每天来打卡哦～', '09:00', false))
  list.push(new MessageItem('m4', 'like', '学霸小李', '学霸小李 赞了你的帖子「第一次用 ArkTS 做出完整小应用」', '昨天', true, 'p13'))
  // 🌟 群聊消息：好友会话类通知，不关联任何帖子
  list.push(new MessageItem('m5', 'comment', 'ArkTS 交流群', 'ArkTS 交流群：王老师 在群里回复了你的问题', '昨天', true))
  return list
}

// 🌟 帖子评论种子数据（条数与 defaultPosts 里各帖的 comments 数对应；回复用 replyToId 挂在父评论下）
export function defaultComments(): Record<string, CommentItem[]> {
  let map: Record<string, CommentItem[]> = {}
  // p13（用户自己的帖子）：2 条，王老师的评论与消息页通知文案对应
  map['p13'] = [
    new CommentItem('王老师', '写得很详细，继续加油！'),
    new CommentItem('李同学', '踩坑记录太有用了，收藏！')
  ]
  // p1：3 条（含 1 条回复）
  let c1 = new CommentItem('李同学', '总结得很清楚，@Link 的双向同步我之前一直用错，看完秒懂！')
  c1.likes = 5
  let c2 = new CommentItem('王老师', '写得很详细，继续加油！')
  c2.likes = 2
  let c3 = new CommentItem('萌新报到', '请问 @StorageLink 和 @StorageProp 的区别能再展开讲讲吗？')
  map['p1'] = [c1, c2, c3]
  // p2：2 条
  map['p2'] = [
    new CommentItem('跨端小能手', '补充一点：折叠屏展开态还可以用 MediaQuery 监听断点动态切换。'),
    new CommentItem('学霸小李', '收藏了，正好下周要做平板适配。')
  ]
  // p3：5 条（含 1 条回复挂在热心同学下）
  let r1 = new CommentItem('热心同学', '我也遇到过，先重启模拟器试试？')
  let r2 = new CommentItem('架构师老王', '检查一下模拟器镜像版本和 SDK 是否匹配。')
  map['p3'] = [
    r1,
    r2,
    new CommentItem('小白同学', '重启可以了，谢谢大家！', '热心同学', r1.id),
    new CommentItem('李同学', '清一下 previewer 缓存也能解决。'),
    new CommentItem('王老师', '建议看下 build 日志里有没有报错信息。')
  ]
  // p4：4 条
  map['p4'] = [
    new CommentItem('跨端小能手', '关系型数据库性能确实强，但小应用真的用不上。'),
    new CommentItem('学霸小李', 'PersistentStorage 真香，几行代码搞定持久化。'),
    new CommentItem('萌新报到', 'Preferences 和 PersistentStorage 的区别讲得很明白！'),
    new CommentItem('架构师老王', '总结到位，顶一个。')
  ]
  // p5：6 条（含 1 条回复挂在架构师老王下）
  let q1 = new CommentItem('热心同学', '数组里的对象属性改了不会触发渲染，要整体替换数组。')
  let q2 = new CommentItem('架构师老王', '用 @Observed + @ObjectLink，或者直接 this.list = [...this.list]。')
  q2.likes = 8
  map['p5'] = [
    q1,
    q2,
    new CommentItem('萌新报到', '用 map 重新赋值解决了，谢谢！', '架构师老王', q2.id),
    new CommentItem('李同学', '嵌套对象建议用 @Observed 装饰类。'),
    new CommentItem('王老师', '这是状态管理的经典坑，建议置顶。'),
    new CommentItem('学霸小李', '补充：ForEach 的 key 也要记得带上变化字段。')
  ]
  // p6：2 条
  let s1 = new CommentItem('萌新报到', '跟着这个路线学了一周，确实顺很多！')
  map['p6'] = [
    s1,
    new CommentItem('李同学', 'Codelab 链接在官网「快速入门」里就有，一起加油！', '萌新报到', s1.id)
  ]
  // p7：3 条（含 1 条回复）
  let t1 = new CommentItem('热心同学', 'Badge 要包在 Stack 里再放图标上，直接放 tabBar 外面不渲染。')
  map['p7'] = [
    new CommentItem('李同学', '检查一下 badgeSize 是不是太小了。'),
    t1,
    new CommentItem('萌新报到', '包了一层 Stack 就出来了，感谢！', '热心同学', t1.id)
  ]
  // p8：3 条
  map['p8'] = [
    new CommentItem('热心同学', '「跳蚤时间」这个玩法好，周末我们也试试。'),
    new CommentItem('学霸小李', '群公告写清免责声明真的很重要，赞。'),
    new CommentItem('王老师', '运营总结写得很实在。')
  ]
  // p9：2 条
  map['p9'] = [
    new CommentItem('架构师老王', '9568322 一般是证书指纹不对，重新生成一下指纹试试。'),
    new CommentItem('跨端小能手', '检查 deviceIds 里有没有加你的真机。')
  ]
  // p10：2 条
  map['p10'] = [
    new CommentItem('跨端小能手', '补充：cachedCount 可以调预渲染数量。'),
    new CommentItem('李同学', '实测图片固定尺寸那一步提升最明显。')
  ]
  // p11：3 条
  map['p11'] = [
    new CommentItem('李同学', '资料已收到，太感谢了！'),
    new CommentItem('热心同学', '等价无穷小那个坑我也踩过，泪目。'),
    new CommentItem('萌新报到', '30 道易错题带解析吗？求发！')
  ]
  // p12：2 条
  map['p12'] = [
    new CommentItem('架构师老王', '检查是不是开了 loop 又手动改了 index。'),
    new CommentItem('李同学', '把 onChange 里的 setState 去掉就好了。')
  ]
  return map
}

// 🌟 初始待办事项（列表为空时灌入，首页待办卡片展示）
export function defaultTodos(): TodoItem[] {
  let list: TodoItem[] = []
  let today = formatDate(new Date())
  let tomorrow = formatDate(new Date(Date.now() + 86400000))
  list.push(new TodoItem('完成 ArkTS 状态管理练习', today, '高', '学习'))
  list.push(new TodoItem('购买生活用品', tomorrow, '中', '生活'))
  list.push(new TodoItem('整理课程笔记', '', '低', '学习'))
  return list
}

// 🌟 初始日程安排（列表为空时灌入，首页日程卡片展示，日期取启动当天/明天）
export function defaultSchedules(): ScheduleItem[] {
  let list: ScheduleItem[] = []
  let today = formatDate(new Date())
  let tomorrow = formatDate(new Date(Date.now() + 86400000))
  list.push(new ScheduleItem('班级例会', today, '19:00'))
  list.push(new ScheduleItem('图书馆自习', tomorrow, '09:00'))
  list.push(new ScheduleItem('操场打篮球', tomorrow, '17:30'))
  return list
}

// 🌟 初始笔记本：默认笔记本不可删除，其余可自由增删排序
export function defaultNotebooks(): NotebookItem[] {
  let list: NotebookItem[] = []
  list.push(new NotebookItem('默认笔记本', 0, true, NOTEBOOK_DEFAULT_ID))
  list.push(new NotebookItem('课程笔记', 1, false, 'nb_course'))
  list.push(new NotebookItem('灵感收集', 2, false, 'nb_idea'))
  return list
}

// 🌟 初始笔记（列表为空时灌入，首页笔记卡片与笔记页展示）
export function defaultNotes(): NoteItem[] {
  let list: NoteItem[] = []
  let n1 = new NoteItem('欢迎来到校园小助手', '这是一条示例笔记。待办、日程、笔记都会本地持久化，重启应用不会丢失，点击可以查看和继续编辑。')
  n1.tags = ['入门']
  n1.notebookId = NOTEBOOK_DEFAULT_ID
  list.push(n1)
  let n2 = new NoteItem('ArkTS 学习小记', '@State 组件内部状态，@Prop 单向同步，@Link 双向同步；跨页面共享状态用 AppStorage，配合 PersistentStorage 持久化。')
  n2.tags = ['ArkTS', '状态管理']
  n2.notebookId = 'nb_course'
  let link = new NoteLink('ArkUI 官方文档', 'https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-basic-ui-description')
  n2.links = [link]
  list.push(n2)
  let n3 = new NoteItem('期末复习清单', '高数：极限 / 导数 / 积分易错题；英语：背完 Unit 5 单词；专业课：整理第三章思维导图。')
  n3.tags = ['复习']
  n3.notebookId = 'nb_idea'
  n3.pinned = true
  n3.visibility = 'course'
  list.push(n3)
  return list
}

// 🌟 初始收藏网址（收藏夹为空时灌入，收藏页可点击跳转网页）
export function defaultFavs(): FavItem[] {
  let list: FavItem[] = []
  list.push(new FavItem('百度', 'https://www.baidu.com'))
  list.push(new FavItem('哔哩哔哩', 'https://www.bilibili.com'))
  list.push(new FavItem('智慧树', 'https://www.zhihuishu.com'))
  return list
}

// 🌟 收藏夹「缺哪条补哪条」：按 url 逐条检查默认收藏，本地缺的才追加到末尾，已有收藏（含改名/排序）保持不动
export function mergedFavs(existing: FavItem[]): FavItem[] {
  let list = existing.slice()
  defaultFavs().forEach((d: FavItem) => {
    let exists = list.some((f: FavItem) => f.url === d.url)
    if (!exists) {
      list.push(d)
    }
  })
  return list
}
