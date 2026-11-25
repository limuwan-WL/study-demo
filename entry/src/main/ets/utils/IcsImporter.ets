// ==================== .ics 课表解析 ====================
// 支持标准 iCalendar（VCALENDAR / VEVENT）课表文件：
//   SUMMARY            -> 课程名称
//   LOCATION           -> 授课地点
//   DESCRIPTION        -> 任课教师（也兼容 ORGANIZER / X-TEACHER）
//   DTSTART / DTEND    -> 上课时段（兼容 DURATION）
//   RRULE BYDAY        -> 星期（一个事件可映射到多个星期）
// 解析失败时通过 errorType 明确区分：format（格式问题）/ missing（字段缺失）/ parse（解析失败）
import { ParsedCourse, timeToMinutes, minutesToTime } from '../model/TimetableModel'

export class IcsParseResult {
  ok: boolean = false
  errorType: string = '' // format / missing / parse
  message: string = ''
  courses: ParsedCourse[] = []
  mappings: string[] = []
  skipped: number = 0
}

class IcsEvent {
  summary: string = ''
  location: string = ''
  description: string = ''
  organizer: string = ''
  teacher: string = ''
  dtStart: string = ''
  dtEnd: string = ''
  duration: string = ''
  rrule: string = ''
}

class IcsDateTime {
  ok: boolean = false
  hasTime: boolean = false
  date: Date = new Date()
}

// 折行还原：iCalendar 用行首空格/Tab 表示续行
function unfoldLines(text: string): string[] {
  let raw = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n')
  let lines: string[] = []
  for (let i = 0; i < raw.length; i++) {
    let line = raw[i]
    if ((line.indexOf(' ') === 0 || line.indexOf('\t') === 0) && lines.length > 0) {
      lines[lines.length - 1] = lines[lines.length - 1] + line.substring(1)
    } else {
      lines.push(line)
    }
  }
  return lines
}

function fieldKey(line: string): string {
  let colon = line.indexOf(':')
  let left = colon >= 0 ? line.substring(0, colon) : line
  let semi = left.indexOf(';')
  return (semi >= 0 ? left.substring(0, semi) : left).toUpperCase()
}

function fieldValue(line: string): string {
  let colon = line.indexOf(':')
  return colon >= 0 ? line.substring(colon + 1) : ''
}

function unescapeIcs(value: string): string {
  return value.replace(/\\n/gi, ' ').replace(/\\,/g, ',').replace(/\\;/g, ';').replace(/\\\\/g, '\\')
}

function stripMailto(value: string): string {
  let v = value.trim()
  if (v.toLowerCase().indexOf('mailto:') === 0) {
    v = v.substring(7)
  }
  return unescapeIcs(v)
}

// 解析 DTSTART/DTEND：支持 20260901T080000、20260901T0800、20260901、带 Z 的 UTC 时间
function parseIcsDateTime(raw: string): IcsDateTime {
  let result = new IcsDateTime()
  let m = raw.trim().match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?)?(Z)?$/)
  if (m === null) {
    return result
  }
  let year = parseInt(m[1])
  let month = parseInt(m[2]) - 1
  let day = parseInt(m[3])
  let hasTime = m[4] !== undefined
  let hour = hasTime ? parseInt(m[4]) : 0
  let minute = hasTime ? parseInt(m[5]) : 0
  let second = (m[6] !== undefined) ? parseInt(m[6]) : 0
  let isUtc = m[7] !== undefined
  let date: Date
  if (isUtc) {
    date = new Date(Date.UTC(year, month, day, hour, minute, second))
  } else {
    date = new Date(year, month, day, hour, minute, second)
  }
  if (isNaN(date.getTime())) {
    return result
  }
  result.ok = true
  result.hasTime = hasTime
  result.date = date
  return result
}

function weekdayOfDate(d: Date): number {
  let w = d.getDay()
  return w === 0 ? 7 : w
}

// RRULE:BYDAY=MO,WE -> [1,3]
// 🌟 只解析 BYDAY 片段：直接在整条 RRULE 上匹配会把 FREQ（FR）、WEEKLY（WE）误判成星期
function weekdaysFromRule(rrule: string): number[] {
  let days: number[] = []
  let byday = ''
  rrule.split(';').forEach((part: string) => {
    let p = part.trim()
    if (p.toUpperCase().indexOf('BYDAY=') === 0) {
      byday = p.substring(6)
    }
  })
  if (byday === '') {
    return days
  }
  let matches = byday.toUpperCase().match(/(MO|TU|WE|TH|FR|SA|SU)/g)
  if (matches === null) {
    return days
  }
  matches.forEach((code: string) => {
    let day = 0
    if (code === 'MO') {
      day = 1
    } else if (code === 'TU') {
      day = 2
    } else if (code === 'WE') {
      day = 3
    } else if (code === 'TH') {
      day = 4
    } else if (code === 'FR') {
      day = 5
    } else if (code === 'SA') {
      day = 6
    } else if (code === 'SU') {
      day = 7
    }
    if (day > 0 && days.indexOf(day) < 0) {
      days.push(day)
    }
  })
  return days
}

// DURATION:PT1H30M / PT50M
function durationMinutes(raw: string): number {
  let m = raw.trim().match(/^P(?:T(\d+)H)?(?:(\d+)M)?$/i)
  if (m === null) {
    return 0
  }
  let hours = m[1] !== undefined ? parseInt(m[1]) : 0
  let mins = m[2] !== undefined ? parseInt(m[2]) : 0
  if (isNaN(hours) || isNaN(mins)) {
    return 0
  }
  return hours * 60 + mins
}

function extractEvents(lines: string[]): IcsEvent[] {
  let events: IcsEvent[] = []
  let current: IcsEvent | null = null
  let inAlarm = false
  for (let i = 0; i < lines.length; i++) {
    let line = lines[i]
    let upper = line.trim().toUpperCase()
    if (upper === 'BEGIN:VEVENT') {
      current = new IcsEvent()
      inAlarm = false
      continue
    }
    if (upper === 'END:VEVENT') {
      if (current !== null) {
        events.push(current)
      }
      current = null
      inAlarm = false
      continue
    }
    if (upper === 'BEGIN:VALARM') {
      inAlarm = true
      continue
    }
    if (upper === 'END:VALARM') {
      inAlarm = false
      continue
    }
    if (current === null || inAlarm) {
      continue
    }
    let key = fieldKey(line)
    let value = fieldValue(line)
    if (key === 'SUMMARY') {
      current.summary = unescapeIcs(value).trim()
    } else if (key === 'LOCATION') {
      current.location = unescapeIcs(value).trim()
    } else if (key === 'DESCRIPTION') {
      current.description = unescapeIcs(value).trim()
    } else if (key === 'ORGANIZER') {
      current.organizer = stripMailto(value)
    } else if (key === 'X-TEACHER' || key === 'X-COURSE-TEACHER') {
      current.teacher = unescapeIcs(value).trim()
    } else if (key === 'DTSTART') {
      current.dtStart = value
    } else if (key === 'DTEND') {
      current.dtEnd = value
    } else if (key === 'DURATION') {
      current.duration = value
    } else if (key === 'RRULE') {
      current.rrule = value
    }
  }
  return events
}

export function parseIcsText(text: string): IcsParseResult {
  let result = new IcsParseResult()
  try {
    if (text === undefined || text === null || text.trim() === '') {
      result.errorType = 'parse'
      result.message = '文件内容为空，无法解析。'
      return result
    }
    let upperText = text.toUpperCase()
    if (upperText.indexOf('BEGIN:VCALENDAR') < 0) {
      result.errorType = 'format'
      result.message = '不是有效的 .ics 日历文件（缺少 BEGIN:VCALENDAR）。请确认导出格式为 iCalendar（.ics）。'
      return result
    }
    let lines = unfoldLines(text)
    let events = extractEvents(lines)
    if (events.length === 0) {
      result.errorType = 'format'
      result.message = '文件中没有找到课程事件（VEVENT），请确认导出的是课表日历而不是空日历。'
      return result
    }

    let missingSummary = 0
    let missingTime = 0
    let hasLocation = false
    let hasTeacher = false
    let dedupe: Record<string, boolean> = {}
    let courses: ParsedCourse[] = []

    events.forEach((ev: IcsEvent) => {
      let name = ev.summary.trim()
      if (name === '') {
        missingSummary++
        return
      }
      let start = parseIcsDateTime(ev.dtStart)
      if (!start.ok || !start.hasTime) {
        missingTime++
        return
      }
      let startMins = start.date.getHours() * 60 + start.date.getMinutes()
      let endMins = startMins + 100
      if (ev.dtEnd !== '') {
        let end = parseIcsDateTime(ev.dtEnd)
        if (end.ok && end.hasTime) {
          let em = end.date.getHours() * 60 + end.date.getMinutes()
          if (em > startMins) {
            endMins = em
          }
        }
      } else if (ev.duration !== '') {
        let dm = durationMinutes(ev.duration)
        if (dm > 0) {
          endMins = startMins + dm
        }
      }
      if (endMins > 23 * 60 + 59) {
        endMins = 23 * 60 + 59
      }
      let teacher = ev.teacher !== '' ? ev.teacher : (ev.description !== '' ? ev.description : ev.organizer)
      let location = ev.location
      if (location !== '') {
        hasLocation = true
      }
      if (teacher !== '') {
        hasTeacher = true
      }
      let days = weekdaysFromRule(ev.rrule)
      if (days.length === 0) {
        days.push(weekdayOfDate(start.date))
      }
      days.forEach((day: number) => {
        let key = `${name}|${day}|${minutesToTime(startMins)}|${minutesToTime(endMins)}|${location}|${teacher}`
        if (dedupe[key] === true) {
          return
        }
        dedupe[key] = true
        let course = new ParsedCourse()
        course.name = name
        course.location = location
        course.teacher = teacher
        course.dayOfWeek = day
        course.startTime = minutesToTime(startMins)
        course.endTime = minutesToTime(endMins)
        courses.push(course)
      })
    })

    result.skipped = missingSummary + missingTime

    if (courses.length === 0) {
      result.errorType = 'missing'
      let detail: string[] = []
      if (missingSummary > 0) {
        detail.push(`课程名称 ${missingSummary} 个`)
      }
      if (missingTime > 0) {
        detail.push(`上课时段 ${missingTime} 个`)
      }
      result.message = `共解析到 ${events.length} 个事件，但均缺少必要字段（${detail.join('、')}），未导入任何课程。`
      return result
    }

    result.ok = true
    result.courses = courses
    let mappings: string[] = ['SUMMARY → 课程名称', 'DTSTART / DTEND → 上课时段', 'RRULE BYDAY → 星期']
    if (hasLocation) {
      mappings.push('LOCATION → 授课地点')
    }
    if (hasTeacher) {
      mappings.push('DESCRIPTION / ORGANIZER → 任课教师')
    }
    if (!hasLocation) {
      mappings.push('LOCATION → 文件未提供（显示为「—」）')
    }
    if (!hasTeacher) {
      mappings.push('DESCRIPTION / ORGANIZER → 文件未提供（显示为「—」）')
    }
    result.mappings = mappings
    if (missingSummary > 0 || missingTime > 0) {
      result.message = `已跳过 ${missingSummary + missingTime} 个缺少必要字段的事件。`
    }
    return result
  } catch (e) {
    result.errorType = 'parse'
    result.message = '解析过程中发生异常，文件可能已损坏或编码不受支持。'
    return result
  }
}

// 供预览用的时段文案
export function timeRangeText(startTime: string, endTime: string): string {
  let a = timeToMinutes(startTime)
  let b = timeToMinutes(endTime)
  if (b <= a) {
    return startTime
  }
  return `${startTime}-${endTime}`
}
