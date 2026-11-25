// ==================== 成长体系：经验值 + 硬币 ====================
// 🌟 全应用等级口径统一：等级由经验值驱动（LV1~LV4），不再按课时/昵称分别计算
// 经验来源：每日登录 / 聊天消息（有日上限）/ 完成课程 / 练习学习 / 社区打卡
// 硬币：随成长事件同步获得，用于购买学科课程

// 等级名称与主题色（LV1~LV4）
export const LEVEL_NAMES: string[] = ['入门', '初级', '中级', '高级']
export const LEVEL_COLORS: string[] = ['#55C873', '#3F7EF6', '#E8A33E', '#EF4444']

// 各等级所需累计经验：LV1 0 / LV2 100 / LV3 300 / LV4 600
export const EXP_THRESHOLDS: number[] = [0, 100, 300, 600]

// 成长事件的经验与硬币奖励
export const EXP_REWARDS: Record<string, number> = {
  'dailyLogin': 10,   // 每日登录
  'chat': 1,          // 聊天消息（日上限 20）
  'lesson': 15,       // 完成一节课程
  'practice': 8,      // 完成一次练习（单词/语法/口语/听力）
  'checkin': 5        // 社区学习打卡
}
export const COIN_REWARDS: Record<string, number> = {
  'dailyLogin': 5,
  'chat': 1,          // 日上限 10
  'lesson': 5,
  'practice': 3,
  'checkin': 2
}
// 聊天每日奖励上限（防止刷经验/硬币）
export const CHAT_EXP_DAILY_CAP: number = 20
export const CHAT_COIN_DAILY_CAP: number = 10

// 🌟 教师成长：教师等级只由教学任务积累经验，不发放金币
export const TEACHER_EXP_REWARDS: Record<string, number> = {
  'assign': 20,     // 布置一次作业
  'progress': 5,    // 查看学生学习进度（每天一次）
  'group': 1,       // 班级群发言（日上限 20）
  'checkin': 5      // 教学打卡
}
export const TEACHER_GROUP_DAILY_CAP: number = 20

// 🌟 当前身份：老师不参与金币体系（金币只服务学生的学习兑换）
export function isTeacherRole(): boolean {
  return (AppStorage.get<string>('userRole') ?? 'student') === 'teacher'
}

function dateKey(d: Date): string {
  let m = (d.getMonth() + 1).toString().padStart(2, '0')
  let day = d.getDate().toString().padStart(2, '0')
  return `${d.getFullYear()}-${m}-${day}`
}

function today(): string {
  return dateKey(new Date())
}

// ==================== 纯计算（供页面配合 @StorageLink 响应式调用） ====================

// 由累计经验值计算等级（0~3）
export function expLevelOf(exp: number): number {
  let lv = 0
  for (let i = 0; i < EXP_THRESHOLDS.length; i++) {
    if (exp >= EXP_THRESHOLDS[i]) {
      lv = i
    }
  }
  return lv
}

// 当前级内进度百分比（0~100）
export function levelProgressOf(exp: number): number {
  let lv = expLevelOf(exp)
  if (lv >= 3) {
    return 100
  }
  let base = EXP_THRESHOLDS[lv]
  let next = EXP_THRESHOLDS[lv + 1]
  return Math.min(100, Math.floor((exp - base) * 100 / (next - base)))
}

// 距下一级还差多少经验（满级返回 0）
export function expToNextOf(exp: number): number {
  let lv = expLevelOf(exp)
  if (lv >= 3) {
    return 0
  }
  return EXP_THRESHOLDS[lv + 1] - exp
}

// ==================== AppStorage 读写 ====================

export function currentExp(): number {
  return AppStorage.get<number>('userExp') ?? 0
}

export function currentCoins(): number {
  return AppStorage.get<number>('coins') ?? 0
}

export function addExp(amount: number): void {
  AppStorage.setOrCreate('userExp', currentExp() + amount)
}

export function addCoins(amount: number): void {
  // 🌟 老师不需要金币：教师侧任何成长事件都不发放
  if (isTeacherRole()) {
    return
  }
  AppStorage.setOrCreate('coins', currentCoins() + amount)
}

// 购买扣费：余额不足返回 false
export function spendCoins(amount: number): boolean {
  let coins = currentCoins()
  if (coins < amount) {
    return false
  }
  AppStorage.setOrCreate('coins', coins - amount)
  return true
}

// ==================== 成长事件 ====================

// 每日登录奖励：每天首次启动发放一次（EntryAbility 启动时调用）
export function dailyLogin(): void {
  if (AppStorage.get<string>('lastLoginDate') === today()) {
    return
  }
  AppStorage.setOrCreate('lastLoginDate', today())
  addExp(EXP_REWARDS['dailyLogin'])
  addCoins(COIN_REWARDS['dailyLogin'])
}

// 聊天消息奖励：每条 +1 经验 +1 硬币，有每日上限
export function onChatMessage(): void {
  if (AppStorage.get<string>('chatAwardDate') !== today()) {
    AppStorage.setOrCreate('chatAwardDate', today())
    AppStorage.setOrCreate('chatExpCount', 0)
    AppStorage.setOrCreate('chatCoinCount', 0)
  }
  let expCnt = AppStorage.get<number>('chatExpCount') ?? 0
  let coinCnt = AppStorage.get<number>('chatCoinCount') ?? 0
  if (expCnt < CHAT_EXP_DAILY_CAP) {
    AppStorage.setOrCreate('chatExpCount', expCnt + 1)
    addExp(EXP_REWARDS['chat'])
  }
  if (coinCnt < CHAT_COIN_DAILY_CAP) {
    AppStorage.setOrCreate('chatCoinCount', coinCnt + 1)
    addCoins(COIN_REWARDS['chat'])
  }
}

// 完成一节课程（CourseModel.completeLesson 内调用）
export function onLessonComplete(): void {
  addExp(EXP_REWARDS['lesson'])
  addCoins(COIN_REWARDS['lesson'])
}

// 完成一次练习（CourseModel.recordStudy 内调用）
export function onPractice(): void {
  addExp(EXP_REWARDS['practice'])
  addCoins(COIN_REWARDS['practice'])
}

// 社区打卡（课程页打卡弹窗确认时调用）
export function onCheckin(): void {
  addExp(EXP_REWARDS['checkin'])
  addCoins(COIN_REWARDS['checkin'])
}

// ==================== 教师成长事件（只加经验，无金币） ====================

// 布置一次作业
export function onTeacherAssign(): void {
  addExp(TEACHER_EXP_REWARDS['assign'])
}

// 查看学生学习进度：每天只计一次
export function onTeacherProgress(): void {
  if (AppStorage.get<string>('teacherProgressDate') === today()) {
    return
  }
  AppStorage.setOrCreate('teacherProgressDate', today())
  addExp(TEACHER_EXP_REWARDS['progress'])
}

// 班级群发言：每日上限，避免刷经验
export function onTeacherGroupMessage(): void {
  if (AppStorage.get<string>('teacherGroupDate') !== today()) {
    AppStorage.setOrCreate('teacherGroupDate', today())
    AppStorage.setOrCreate('teacherGroupCount', 0)
  }
  let cnt = AppStorage.get<number>('teacherGroupCount') ?? 0
  if (cnt >= TEACHER_GROUP_DAILY_CAP) {
    return
  }
  AppStorage.setOrCreate('teacherGroupCount', cnt + 1)
  addExp(TEACHER_EXP_REWARDS['group'])
}
