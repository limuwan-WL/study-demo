// ==================== 上课日程提醒 ====================
// 使用系统 reminderAgentManager 发布每周重复的闹钟提醒。
// 若当前设备/模拟器不允许发布提醒，会返回 ok=false 并给出明确原因，不会假装提醒已生效。
import { reminderAgentManager } from '@kit.BackgroundTasksKit'
import { CourseItem, timeToMinutes, weekdayName } from '../model/TimetableModel'

export class ReminderResult {
  ok: boolean = false
  reminderId: number = 0
  message: string = ''
}

function notificationIdOf(courseId: string): number {
  let hash = 0
  for (let i = 0; i < courseId.length; i++) {
    hash = (hash * 31 + courseId.charCodeAt(i)) % 90000
  }
  return hash + 1000
}

export class CourseReminder {
  static async publish(course: CourseItem, minutesBefore: number): Promise<ReminderResult> {
    let result = new ReminderResult()
    let total = timeToMinutes(course.startTime) - minutesBefore
    if (total < 0) {
      total = 0
    }
    let hour = Math.floor(total / 60)
    let minute = total % 60
    let content = `${course.name} ${course.startTime} 开始`
    if (course.location !== '') {
      content = `${content} · ${course.location}`
    }
    let alarm: reminderAgentManager.ReminderRequestAlarm = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
      hour: hour,
      minute: minute,
      daysOfWeek: [course.dayOfWeek],
      title: `上课提醒 · 每周${weekdayName(course.dayOfWeek)}`,
      content: content,
      notificationId: notificationIdOf(course.id)
    }
    try {
      let id = await reminderAgentManager.publishReminder(alarm)
      result.ok = true
      result.reminderId = id
      result.message = `已开启提醒：每周${weekdayName(course.dayOfWeek)} ${course.startTime} 前 ${minutesBefore} 分钟`
      return result
    } catch (e) {
      result.message = '提醒发布失败：请确认已授予提醒权限，或在支持提醒代理的真机上使用'
      return result
    }
  }

  static async cancel(reminderId: number): Promise<void> {
    if (reminderId <= 0) {
      return
    }
    try {
      await reminderAgentManager.cancelReminder(reminderId)
    } catch (e) {
      // 提醒可能已被系统清理，取消失败不影响本地开关状态
    }
  }
}

// ==================== 任务定时提醒 ====================
// 🌟 一次性提醒：定时发布的签到 / 练习 / 问卷到点提醒，应用退到后台仍由系统提醒代理触发
// ⚠️ 依赖 ohos.permission.PUBLISH_AGENT_REMINDER；模拟器或不支持提醒代理的设备会返回 ok=false，
//    此时任务仍会在应用内到点自动发布（各任务页的本地计时逻辑），不会出现「假装已提醒」。
export class TaskReminder {
  private static ids(): Record<string, number> {
    return AppStorage.get<Record<string, number>>('taskReminderIds') ?? {}
  }

  static async schedule(taskId: string, title: string, content: string, at: number): Promise<ReminderResult> {
    let r = new ReminderResult()
    let seconds = Math.floor((at - Date.now()) / 1000)
    if (seconds <= 0) {
      r.message = '时间已过，无需设置提醒'
      return r
    }
    let timer: reminderAgentManager.ReminderRequestTimer = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
      triggerTimeInSeconds: seconds,
      title: title,
      content: content,
      notificationId: notificationIdOf(taskId)
    }
    try {
      let id = await reminderAgentManager.publishReminder(timer)
      let cur = TaskReminder.ids()
      let next: Record<string, number> = {}
      Object.keys(cur).forEach((k: string) => {
        next[k] = cur[k]
      })
      next[taskId] = id
      AppStorage.setOrCreate('taskReminderIds', next)
      r.ok = true
      r.reminderId = id
      r.message = '已设置后台定时提醒，退到后台也会按时提醒'
      return r
    } catch (e) {
      r.message = '后台提醒发布失败（设备限制），将仅在应用内到点提醒'
      return r
    }
  }

  static async cancel(taskId: string): Promise<void> {
    let cur = TaskReminder.ids()
    let id = cur[taskId]
    if (id === undefined || id <= 0) {
      return
    }
    try {
      await reminderAgentManager.cancelReminder(id)
    } catch (e) {
      // 已被系统清理时忽略
    }
    let next: Record<string, number> = {}
    Object.keys(cur).forEach((k: string) => {
      if (k !== taskId) {
        next[k] = cur[k]
      }
    })
    AppStorage.setOrCreate('taskReminderIds', next)
  }
}
