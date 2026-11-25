// ==================== 消息中心（独立于群聊） ====================
// 🌟 统一收纳：系统通知 / 上课提醒 / 签到提醒 / 作业批阅 / 充值订单 / 举报反馈
//    数据仍写入 messageList（与底部「消息」页共享持久化），只是分类与展示独立。
import { MessageItem } from './DataModel'
import { Permission } from './PermissionModel'
import { SEED_HW_ID } from './HomeworkModel'

export class MessageCategory {
  key: string = ''
  label: string = ''
  color: string = ''

  constructor(key: string, label: string, color: string) {
    this.key = key
    this.label = label
    this.color = color
  }
}

export const MESSAGE_CATEGORIES: MessageCategory[] = [
  new MessageCategory('system', '系统通知', '#8B5CF6'),
  new MessageCategory('class', '上课提醒', '#3F7EF6'),
  new MessageCategory('signin', '签到提醒', '#10B981'),
  new MessageCategory('homework', '作业批阅', '#F59E0B'),
  new MessageCategory('recharge', '充值订单', '#E8A33E'),
  new MessageCategory('report', '举报反馈', '#EF4444'),
  new MessageCategory('social', '互动消息', '#EC4899')
]

export function categoryOf(type: string): MessageCategory {
  if (type === 'like' || type === 'comment') {
    return MESSAGE_CATEGORIES[6]
  }
  let hit = MESSAGE_CATEGORIES.find((c: MessageCategory) => c.key === type)
  return hit === undefined ? MESSAGE_CATEGORIES[0] : hit
}

export function categoryLabel(type: string): string {
  if (type === 'like') {
    return '点赞'
  }
  if (type === 'comment') {
    return '评论'
  }
  return categoryOf(type).label
}

// 生成「今天 14:00」这类简短时间
export function msgTime(ts: number): string {
  let d = new Date(ts)
  let hh = d.getHours().toString().padStart(2, '0')
  let mm = d.getMinutes().toString().padStart(2, '0')
  let day = d.getDate()
  let now = new Date()
  if (day === now.getDate()) {
    return `${hh}:${mm}`
  }
  return `${d.getMonth() + 1}月${day}日 ${hh}:${mm}`
}

export class MessageCenter {
  static list(): MessageItem[] {
    return AppStorage.get<MessageItem[]>('messageList') ?? []
  }

  // ==================== 身份作用域 ====================
  // 🌟 根因：messageList 只有一份全局数据，教师/学生共用同一列表。
  //    这里按「当前身份」分账持久化，messageList 仅作为当前身份的镜像，
  //    所有页面沿用原 @StorageLink('messageList')，无需逐页改造。
  static scopeKey(): string {
    return Permission.role()
  }

  static store(): Record<string, MessageItem[]> {
    let raw = AppStorage.get<Record<string, MessageItem[]>>('messageStore')
    if (raw === undefined) {
      return {}
    }
    // PersistentStorage 反序列化后是普通对象，这里原样拷贝一份避免直接改引用
    let next: Record<string, MessageItem[]> = {}
    let keys = Object.keys(raw)
    for (let i = 0; i < keys.length; i++) {
      next[keys[i]] = raw[keys[i]]
    }
    return next
  }

  // 切换 / 初次登录时调用：保存旧身份镜像，加载当前身份的消息
  static activateScope(): void {
    let key = MessageCenter.scopeKey()
    let current = AppStorage.get<string>('messageScope') ?? ''
    if (current === key) {
      return
    }
    let store = MessageCenter.store()
    if (current !== '') {
      store[current] = MessageCenter.list()
    } else if (store['student'] === undefined && MessageCenter.list().length > 0) {
      // 升级迁移：历史上只有一份 messageList，归入学生作用域，教师登录时保持干净
      store['student'] = MessageCenter.list()
    }
    let scoped = store[key]
    if (scoped === undefined) {
      scoped = []
    }
    store[key] = scoped
    AppStorage.setOrCreate<Record<string, MessageItem[]>>('messageStore', store)
    AppStorage.setOrCreate<string>('messageScope', key)
    AppStorage.setOrCreate<MessageItem[]>('messageList', scoped)
  }

  static save(list: MessageItem[]): void {
    AppStorage.setOrCreate<MessageItem[]>('messageList', list)
    // 同步写回当前身份的作用域，保证切换身份后数据不串
    let key = AppStorage.get<string>('messageScope') ?? ''
    if (key === '') {
      return
    }
    let store = MessageCenter.store()
    store[key] = list
    AppStorage.setOrCreate<Record<string, MessageItem[]>>('messageStore', store)
  }

  static unreadCount(): number {
    return MessageCenter.list().filter((m: MessageItem) => !m.isRead).length
  }

  static unreadOf(type: string): number {
    return MessageCenter.list().filter((m: MessageItem) => !m.isRead && MessageCenter.match(m.type, type)).length
  }

  static match(msgType: string, filter: string): boolean {
    if (filter === 'all') {
      return true
    }
    if (filter === 'social') {
      return msgType === 'like' || msgType === 'comment'
    }
    return msgType === filter
  }

  static filtered(filter: string): MessageItem[] {
    return MessageCenter.list().filter((m: MessageItem) => MessageCenter.match(m.type, filter))
  }

  static markRead(id: string): void {
    let list = MessageCenter.list().map((m: MessageItem) => {
      if (m.id === id) {
        m.isRead = true
      }
      return m
    })
    MessageCenter.save(list)
  }

  static markAllRead(): void {
    let list = MessageCenter.list().map((m: MessageItem) => {
      m.isRead = true
      return m
    })
    MessageCenter.save(list)
  }

  // 业务页面（充值 / 签到 / 作业批阅 / 举报 / 互动任务）写入消息中心
  // 🌟 route / taskId：点击消息后跳转的目标页面与任务 id（空串表示仅已读）
  static push(type: string, sender: string, content: string, postId: string = '',
    route: string = '', taskId: string = ''): void {
    let item = new MessageItem(`mc_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
      type, sender, content, msgTime(Date.now()), false, postId, route, taskId)
    MessageCenter.save([item].concat(MessageCenter.list()))
  }

  // 按设置页的推送分项开关决定是否生成通知
  static pushIfEnabled(type: string, sender: string, content: string, postId: string = '',
    route: string = '', taskId: string = ''): void {
    if (AppStorage.get<boolean>('pushEnabled') === false) {
      return
    }
    let key = type === 'class' ? 'pushClass'
      : type === 'signin' ? 'pushSignin'
        : type === 'homework' ? 'pushHomework'
          : type === 'recharge' ? 'pushRecharge'
            : type === 'report' ? 'pushReport' : ''
    if (key !== '' && AppStorage.get<boolean>(key) === false) {
      return
    }
    MessageCenter.push(type, sender, content, postId, route, taskId)
  }

  // 首次进入某身份作用域时灌入演示数据（按 role 各灌一次）
  // 🌟 学生：课程 / 签到 / 作业 / 充值 / 举报通知；教师与助教：教学任务与提交提醒
  static ensureSeed(): void {
    // 🌟 兼容旧数据：已灌入的作业批阅消息补齐跳转参数，保证「查看批注」能直达
    MessageCenter.patchHomeworkMessage()
    let key = MessageCenter.scopeKey()
    // 🌟 种子标记按身份分别记录：学生灌过一次后再登录教师，仍然要为教师灌一次
    let seededKey = `messageSeededScope_${key}`
    let legacySeeded = AppStorage.get<string>('messageSeededScope') ?? ''
    // messageCenterSeeded = false 代表「清空本地数据」或首次启动，需要重新灌种子
    let seededFlag = AppStorage.get<boolean>('messageCenterSeeded') ?? false
    if (seededFlag && AppStorage.get<string>(seededKey) === key) {
      return
    }
    // 兼容旧版本单一标记：学生作用域已灌过时不再重复插入
    if (seededFlag && key === 'student' && legacySeeded === 'student') {
      AppStorage.setOrCreate<string>(seededKey, key)
      return
    }
    AppStorage.setOrCreate<string>(seededKey, key)
    AppStorage.setOrCreate<string>('messageSeededScope', key)
    AppStorage.setOrCreate<boolean>('messageCenterSeeded', true)
    if (!Permission.isStudent()) {
      MessageCenter.seedStaff()
      return
    }
    let list = MessageCenter.list()
    let lacks = list.filter((m: MessageItem) =>
    m.type === 'class' || m.type === 'signin' || m.type === 'homework' ||
      m.type === 'recharge' || m.type === 'report').length === 0
    if (!lacks) {
      return
    }
    let now = Date.now()
    let seed: MessageItem[] = [
      new MessageItem('mc_class_1', 'class', '教务系统',
        '《高等数学（下册）》今天 14:00 开课，请提前 5 分钟进入教室', msgTime(now), false,
        '', 'pages/study/CourseTablePage'),
      new MessageItem('mc_signin_1', 'signin', '签到助手',
        '《数据结构》第 6 次课签到已开始，请在 10 分钟内完成签到', msgTime(now - 20 * 60000), false,
        '', 'pages/study/SigninPage'),
      new MessageItem('mc_hw_1', 'homework', '王老师',
        '已批阅你的「数据结构第 3 章作业」，得分 92，点击查看批注', msgTime(now - 3 * 3600000), false,
        '', 'pages/course/HomeworkPage', SEED_HW_ID),
      new MessageItem('mc_recharge_1', 'recharge', '金币中心',
        '你的 30 元金币充值已到账，订单号 R20261118001，余额可在「我的金币」查看', msgTime(now - 26 * 3600000), true,
        '', 'pages/study/CoinPage'),
      new MessageItem('mc_report_1', 'report', '平台客服',
        '你提交的群消息举报已处理：违规内容已删除，感谢你的反馈', msgTime(now - 50 * 3600000), true,
        '', 'pages/course/ClassGroupPage')
    ]
    MessageCenter.save(seed.concat(list))
  }

  // 🌟 旧版本作业批阅消息没有 route/taskId，这里补齐，避免升级后仍点不进批注
  static patchHomeworkMessage(): void {
    let list = MessageCenter.list()
    let changed = false
    list.forEach((m: MessageItem) => {
      if (m.id === 'mc_hw_1' && (m.route === '' || m.taskId === '')) {
        m.route = 'pages/course/HomeworkPage'
        m.taskId = SEED_HW_ID
        changed = true
      }
    })
    if (changed) {
      MessageCenter.save(list)
    }
  }

  // 🌟 教师 / 助教的消息种子：教学提醒、待批阅作业、签到进度与举报反馈
  static seedStaff(): void {
    let list = MessageCenter.list()
    if (list.length > 0) {
      return
    }
    let now = Date.now()
    let seed: MessageItem[] = [
      new MessageItem('mc_t_class_1', 'class', '教务系统',
        '《数据结构与算法》今天 14:00 开课，教室 A302', msgTime(now), false,
        '', 'pages/study/TaskPage'),
      new MessageItem('mc_t_signin_1', 'signin', '签到助手',
        '你发布的第 6 次课签到进行中，已有 32/48 人完成，可查看签到台账', msgTime(now - 25 * 60000), false,
        '', 'pages/study/SigninPage'),
      new MessageItem('mc_t_hw_1', 'homework', '作业助手',
        '李同学提交了「数据结构第 3 章作业」，可查看其作答与批注详情', msgTime(now - 2 * 3600000), false,
        '', 'pages/course/HomeworkPage'),
      new MessageItem('mc_t_report_1', 'report', '平台客服',
        '你提交的群消息举报已由后台审核处理：违规内容已删除', msgTime(now - 30 * 3600000), true,
        '', 'pages/course/ClassGroupPage'),
      new MessageItem('mc_t_sys_1', 'system', '系统消息',
        '欢迎使用教师工作台：互动任务、题库与台账入口已按身份隔离展示', msgTime(now - 48 * 3600000), true)
    ]
    MessageCenter.save(seed)
  }
}
