// ==================== 课表云端同步（本地模拟层） ====================
// ⚠️ 当前工程没有真实后端，这里用 PersistentStorage 模拟云端快照：
//    - 同一账号的本机快照可上传 / 拉取，用于演示「换设备登录后恢复课表」的完整流程；
//    - 接口形态与真实云同步一致（push / pull），接入后端时只需替换本文件实现；
//    - UI 上明确标注「本地模拟云端（无真实后端）」，不冒充真实网络同步。
import { CourseItem, copyCourses } from '../model/TimetableModel'
import { formatStamp } from '../model/DataModel'

const CLOUD_KEY: string = 'timetableCloud'
const CLOUD_TIME_KEY: string = 'timetableCloudTime'

export class TimetableSync {
  static readonly LABEL: string = '本地模拟云端（无真实后端）'

  private static accountKey(account: string): string {
    return account === '' ? 'guest' : account
  }

  static push(account: string, courses: CourseItem[]): string {
    let key = TimetableSync.accountKey(account)
    let cloud = AppStorage.get<Record<string, CourseItem[]>>(CLOUD_KEY) ?? {}
    let next: Record<string, CourseItem[]> = {}
    Object.keys(cloud).forEach((k: string) => {
      next[k] = cloud[k]
    })
    next[key] = copyCourses(courses)
    AppStorage.setOrCreate<Record<string, CourseItem[]>>(CLOUD_KEY, next)

    let stamp = formatStamp(Date.now())
    let times = AppStorage.get<Record<string, string>>(CLOUD_TIME_KEY) ?? {}
    let nextTimes: Record<string, string> = {}
    Object.keys(times).forEach((k: string) => {
      nextTimes[k] = times[k]
    })
    nextTimes[key] = stamp
    AppStorage.setOrCreate<Record<string, string>>(CLOUD_TIME_KEY, nextTimes)
    return stamp
  }

  static pull(account: string): CourseItem[] {
    let key = TimetableSync.accountKey(account)
    let cloud = AppStorage.get<Record<string, CourseItem[]>>(CLOUD_KEY) ?? {}
    let list = cloud[key]
    if (list === undefined || list === null) {
      return []
    }
    return copyCourses(list)
  }

  static cloudCount(account: string): number {
    return TimetableSync.pull(account).length
  }

  static cloudTime(account: string): string {
    let key = TimetableSync.accountKey(account)
    let times = AppStorage.get<Record<string, string>>(CLOUD_TIME_KEY) ?? {}
    let value = times[key]
    return value === undefined ? '' : value
  }
}
