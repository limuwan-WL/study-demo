// ==================== 课程表数据模型 ====================
// 说明：课程按「每周固定星期 + 时段」重复出现，周一=1 ... 周日=7
import { genId } from './DataModel'

export const WEEK_NAMES: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']

export function weekdayName(day: number): string {
  let idx = day - 1
  return idx >= 0 && idx < 7 ? WEEK_NAMES[idx] : WEEK_NAMES[0]
}

// 时间 "08:00" -> 分钟数，便于排序与计算
export function timeToMinutes(time: string): number {
  let parts = time.split(':')
  if (parts.length < 2) {
    return 0
  }
  let h = parseInt(parts[0])
  let m = parseInt(parts[1])
  if (isNaN(h) || isNaN(m)) {
    return 0
  }
  return h * 60 + m
}

export function minutesToTime(mins: number): string {
  let total = Math.max(0, mins)
  let h = Math.floor(total / 60)
  let m = total % 60
  return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`
}

// 🌟 标准作息时段（覆盖上午 / 下午 / 晚间），课表固定展示这些行，
//    再并入课程中出现的自定义开始时间，避免「有课才有行」导致只剩两三个时段。
export const DEFAULT_SLOT_TIMES: string[] = [
  '08:00', '08:55', '10:00', '10:55',
  '14:00', '14:55', '16:00', '16:55',
  '19:00', '19:55'
]

// 标准时段的默认下课时间（45 分钟一节）
export function defaultSlotEnd(start: string): string {
  return minutesToTime(timeToMinutes(start) + 45)
}

// 🌟 ForEach 渲染 key：必须包含颜色等可变字段。
//    ArkUI 的 ForEach 在 key 不变时复用旧节点，若只按 id 取 key，
//    改颜色 / 改名称后数组元素已替换但界面不会刷新。
export function courseRenderKey(c: CourseItem): string {
  return `${c.id}_${c.dayOfWeek}_${c.startTime}_${c.endTime}_${c.colorIndex}_${c.name}_${c.location}_${c.teacher}_${c.reminderEnabled ? 1 : 0}`
}


// 今天对应星期：周一=1 ... 周日=7
export function todayWeekday(): number {
  let d = new Date().getDay()
  return d === 0 ? 7 : d
}

export class CourseItem {
  id: string = ''
  name: string = ''
  location: string = ''
  teacher: string = ''
  dayOfWeek: number = 1
  startTime: string = '08:00'
  endTime: string = '09:40'
  colorIndex: number = 0 // 对应当前表格主题 palette 的下标，主题切换时自动换色
  reminderEnabled: boolean = false
  reminderMinutes: number = 10
  reminderId: number = 0

  constructor(name: string, location: string, teacher: string, dayOfWeek: number,
    startTime: string, endTime: string, colorIndex: number = 0) {
    this.id = genId()
    this.name = name
    this.location = location
    this.teacher = teacher
    this.dayOfWeek = dayOfWeek
    this.startTime = startTime
    this.endTime = endTime
    this.colorIndex = colorIndex
  }
}

// 从本地缓存读回的对象不再是类实例，统一做一次字段拷贝，避免共享引用
export function copyCourse(course: CourseItem): CourseItem {
  let item = new CourseItem(course.name, course.location, course.teacher, course.dayOfWeek,
    course.startTime, course.endTime, course.colorIndex)
  item.id = course.id
  item.reminderEnabled = course.reminderEnabled
  item.reminderMinutes = course.reminderMinutes
  item.reminderId = course.reminderId
  return item
}

export function copyCourses(list: CourseItem[]): CourseItem[] {
  let result: CourseItem[] = []
  list.forEach((c: CourseItem) => result.push(copyCourse(c)))
  return result
}

export function sortCourses(list: CourseItem[]): CourseItem[] {
  return list.slice().sort((a: CourseItem, b: CourseItem) => {
    if (a.dayOfWeek !== b.dayOfWeek) {
      return a.dayOfWeek - b.dayOfWeek
    }
    return timeToMinutes(a.startTime) - timeToMinutes(b.startTime)
  })
}

export function coursesOnDay(list: CourseItem[], dayOfWeek: number): CourseItem[] {
  let result = list.filter((c: CourseItem) => c.dayOfWeek === dayOfWeek)
  return result.slice().sort((a: CourseItem, b: CourseItem) => timeToMinutes(a.startTime) - timeToMinutes(b.startTime))
}

// 🌟 学生端默认课表：首次进入且课表为空时自动生成，首页 / 待办 / 课表页立即有内容
export function defaultStudentCourses(): CourseItem[] {
  let list: CourseItem[] = [
    new CourseItem('高等数学（下）', '教 A201', '李季', 1, '08:00', '09:40', 0),
    new CourseItem('大学英语', '外语楼 305', '王敏', 1, '10:00', '11:40', 1),
    new CourseItem('数据结构', '计科楼 B402', '王建国', 1, '14:00', '15:40', 2),
    new CourseItem('线性代数', '教 A305', '陈立', 2, '08:00', '09:40', 3),
    new CourseItem('大学物理', '理科楼 210', '周珊', 2, '10:00', '11:40', 4),
    new CourseItem('数据结构', '计科楼 B402', '王建国', 3, '08:00', '09:40', 2),
    new CourseItem('体育（篮球）', '体育馆', '赵强', 3, '14:00', '15:40', 5),
    new CourseItem('大学英语', '外语楼 305', '王敏', 4, '10:00', '11:40', 1),
    new CourseItem('操作系统', '计科楼 A108', '王建国', 4, '14:00', '15:40', 6),
    new CourseItem('高等数学（下）', '教 A201', '李季', 5, '08:00', '09:40', 0),
    new CourseItem('程序设计实验', '实验楼 302', '王建国', 5, '14:00', '15:40', 7)
  ]
  return sortCourses(list)
}

// 🌟 自动生成判定（纯函数，便于单元测试）：从未生成过且当前课表为空
export function shouldGenerateStudentCourses(seeded: boolean, existingCount: number): boolean {
  return !seeded && existingCount === 0
}

// 🌟 自动生成只执行一次：返回 true 表示本次确实生成了课表
export function ensureStudentCourses(): boolean {
  let seeded = AppStorage.get<boolean>('courseTableAutoSeeded') === true
  if (seeded) {
    return false
  }
  let current = AppStorage.get<CourseItem[]>('courseTable') ?? []
  // 无论是否生成都标记为已初始化，避免用户主动删空后被反复填充
  AppStorage.setOrCreate<boolean>('courseTableAutoSeeded', true)
  if (!shouldGenerateStudentCourses(seeded, current.length)) {
    return false
  }
  AppStorage.setOrCreate<CourseItem[]>('courseTable', defaultStudentCourses())
  return true
}

// 导入阶段使用的中间结构：只保留课表字段，id / 颜色由页面生成
export class ParsedCourse {
  name: string = ''
  location: string = ''
  teacher: string = ''
  dayOfWeek: number = 1
  startTime: string = '08:00'
  endTime: string = '09:40'
}

// ==================== 表格主题 ====================
// 默认主题「经典黑白」：白底 + 黑色边框；每个主题自带一套课程色板，
// 课程只记录 colorIndex，切换主题时色块颜色自动跟随，同时支持手动改单门课颜色。
export class TableTheme {
  key: string = ''
  name: string = ''
  desc: string = ''
  bg: string = '#FFFFFF'
  border: string = '#000000'
  headerBg: string = '#F5F6F8'
  headerText: string = '#18181A'
  textMain: string = '#18181A'
  textSub: string = '#6B7280'
  chipText: string = '#FFFFFF'
  palette: string[] = []

  constructor(key: string, name: string, desc: string, bg: string, border: string, headerBg: string,
    headerText: string, textMain: string, textSub: string, chipText: string, palette: string[]) {
    this.key = key
    this.name = name
    this.desc = desc
    this.bg = bg
    this.border = border
    this.headerBg = headerBg
    this.headerText = headerText
    this.textMain = textMain
    this.textSub = textSub
    this.chipText = chipText
    this.palette = palette
  }
}

export const TABLE_THEMES: TableTheme[] = [
  new TableTheme('classic', '经典黑白（默认）', '白底黑框，最接近纸质课表',
    '#FFFFFF', '#000000', '#F5F6F8', '#18181A', '#18181A', '#6B7280', '#FFFFFF',
    ['#3F7EF6', '#55C873', '#E8A33E', '#E74846', '#8B5CF6', '#14B8A6', '#EC4899', '#6366F1']),
  new TableTheme('ocean', '清透蓝', '淡蓝底 + 深蓝框，清爽易读',
    '#F7FAFF', '#1F3A5F', '#E7F0FF', '#173A63', '#173A63', '#5C728C', '#FFFFFF',
    ['#2F6FED', '#1C93C9', '#2AA38A', '#6C7CE0', '#3E8FC4', '#5BA9E8', '#4E7BD6', '#29B6C8']),
  new TableTheme('warm', '暖纸米', '米黄底 + 棕框，护眼柔和',
    '#FFFBF2', '#6B4F2A', '#F6EBD7', '#4A3A22', '#4A3A22', '#8A775C', '#FFFFFF',
    ['#C07B34', '#8E9A3E', '#B05A5A', '#9A6BB0', '#4F8A6D', '#C99A3C', '#A8693F', '#7A8B4A']),
  new TableTheme('night', '墨夜', '深色底 + 灰框，夜间不刺眼',
    '#1B1F24', '#5B6470', '#232A33', '#E6E8EB', '#E6E8EB', '#9BA1A8', '#FFFFFF',
    ['#5B93F7', '#4FC98A', '#F0B44E', '#F0716B', '#A984F0', '#3FC6BE', '#F074A8', '#8093F0'])
]

export function tableThemeByKey(key: string): TableTheme {
  let found = TABLE_THEMES.find((t: TableTheme) => t.key === key)
  return found !== undefined ? found : TABLE_THEMES[0]
}

// 为课程分配色板下标：优先沿用同名课程已有颜色，新课程依次取下一个颜色
export function nextColorIndex(existing: CourseItem[]): number {
  return existing.length === 0 ? 0 : existing.length % 8
}
