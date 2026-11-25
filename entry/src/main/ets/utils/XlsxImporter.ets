// ==================== .xlsx 课表解析 ====================
// xlsx = ZIP + XML：先用系统 zlib 解压，再解析 workbook / sharedStrings / sheet 三个 XML。
// 表头识别（别名不区分大小写与空格）：
//   课程名称（课程/科目/name）、星期（周几/day）、开始时间（开始/start）、
//   结束时间（结束/end，可缺省，默认按 100 分钟）、地点（教室/location）、教师（老师/teacher）
// 也支持用「上课时间」一列写成 08:00-09:40 的形式。
// 解析失败会返回明确原因，绝不生成「看似成功」的空课表。
import { zlib, BusinessError } from '@kit.BasicServicesKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { ParsedCourse, minutesToTime } from '../model/TimetableModel'

export class XlsxParseResult {
  ok: boolean = false
  errorType: string = '' // format / missing / parse
  message: string = ''
  courses: ParsedCourse[] = []
  mappings: string[] = []
  skipped: number = 0
}

class SheetRow {
  index: number = 0
  cells: string[] = []
}

class HeaderMap {
  name: number = -1
  day: number = -1
  start: number = -1
  end: number = -1
  timeRange: number = -1
  location: number = -1
  teacher: number = -1
}

function decodeXml(value: string): string {
  return value
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, '\'')
    .replace(/&#(\d+);/g, (whole: string, code: string) => String.fromCharCode(parseInt(code)))
    .replace(/&amp;/g, '&')
}

// 提取一段 XML 里的纯文本：把所有 <t>...</t> 拼接，去掉其余标签
function plainText(fragment: string): string {
  let out = ''
  let re = /<t[^>]*>([\s\S]*?)<\/t>/g
  let m = re.exec(fragment)
  while (m !== null) {
    out += m[1]
    m = re.exec(fragment)
  }
  if (out === '') {
    out = fragment.replace(/<[^>]+>/g, '')
  }
  return decodeXml(out)
}

function attrOf(tag: string, name: string): string {
  let re = new RegExp(`${name}="([^"]*)"`)
  let m = tag.match(re)
  return m === null ? '' : m[1]
}

function columnIndex(ref: string): number {
  let n = 0
  for (let i = 0; i < ref.length; i++) {
    let code = ref.charCodeAt(i)
    if (code >= 65 && code <= 90) {
      n = n * 26 + (code - 64)
    } else {
      break
    }
  }
  return n - 1
}

function parseSharedStrings(xml: string): string[] {
  let list: string[] = []
  let re = /<si>([\s\S]*?)<\/si>/g
  let m = re.exec(xml)
  while (m !== null) {
    list.push(plainText(m[1]).trim())
    m = re.exec(xml)
  }
  return list
}

function parseSheet(xml: string, shared: string[]): SheetRow[] {
  let rows: SheetRow[] = []
  let rowRe = /<row([^>]*)>([\s\S]*?)<\/row>/g
  let rm = rowRe.exec(xml)
  while (rm !== null) {
    let row = new SheetRow()
    row.index = parseInt(attrOf(rm[1], 'r')) || (rows.length + 1)
    let body = rm[2]
    let cellRe = /<c([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g
    let cm = cellRe.exec(body)
    while (cm !== null) {
      let attrs = cm[1]
      let inner = cm[2] === undefined ? '' : cm[2]
      let ref = attrOf(attrs, 'r')
      let col = columnIndex(ref)
      if (col >= 0) {
        let type = attrOf(attrs, 't')
        let value = ''
        if (type === 's') {
          let vm = inner.match(/<v[^>]*>([\s\S]*?)<\/v>/)
          let idx = vm === null ? -1 : parseInt(vm[1])
          value = (idx >= 0 && idx < shared.length) ? shared[idx] : ''
        } else if (type === 'inlineStr') {
          value = plainText(inner)
        } else {
          let vm = inner.match(/<v[^>]*>([\s\S]*?)<\/v>/)
          value = vm === null ? plainText(inner) : decodeXml(vm[1])
        }
        row.cells[col] = value.trim()
      }
      cm = cellRe.exec(body)
    }
    rows.push(row)
    rm = rowRe.exec(xml)
  }
  return rows
}

function normalizeHeader(value: string): string {
  return value.trim().toLowerCase().replace(/\s+/g, '')
}

function headerOf(row: SheetRow): HeaderMap | undefined {
  let map = new HeaderMap()
  row.cells.forEach((raw: string, i: number) => {
    let h = normalizeHeader(raw === undefined ? '' : raw)
    if (h === '') {
      return
    }
    if (map.name < 0 && (h === '课程' || h === '课程名称' || h === '课程名' || h === '科目' ||
      h === 'course' || h === 'subject' || h === 'name')) {
      map.name = i
    } else if (map.day < 0 && (h === '星期' || h === '星期几' || h === '周几' || h === '周' ||
      h === 'day' || h === 'weekday')) {
      map.day = i
    } else if (map.timeRange < 0 && (h === '上课时间' || h === '时间段' || h === 'time' || h === 'timerange')) {
      map.timeRange = i
    } else if (map.start < 0 && (h === '开始时间' || h === '开始' || h === '上课' || h === 'start' ||
      h === 'starttime' || h === 'begintime')) {
      map.start = i
    } else if (map.end < 0 && (h === '结束时间' || h === '结束' || h === '下课' || h === 'end' ||
      h === 'endtime' || h === 'finishtime')) {
      map.end = i
    } else if (map.location < 0 && (h === '地点' || h === '上课地点' || h === '教室' || h === 'location' ||
      h === 'room' || h === 'classroom')) {
      map.location = i
    } else if (map.teacher < 0 && (h === '教师' || h === '老师' || h === '任课教师' || h === '授课教师' ||
      h === 'teacher')) {
      map.teacher = i
    }
  })
  if (map.name >= 0 && map.day >= 0 && (map.start >= 0 || map.timeRange >= 0)) {
    return map
  }
  return undefined
}

function cellOf(row: SheetRow, index: number): string {
  if (index < 0 || index >= row.cells.length) {
    return ''
  }
  let v = row.cells[index]
  return v === undefined ? '' : v.trim()
}

function parseDay(raw: string): number {
  let s = raw.trim()
  if (s === '') {
    return 0
  }
  let lower = s.toLowerCase()
  if (lower.indexOf('mon') >= 0) {
    return 1
  }
  if (lower.indexOf('tue') >= 0) {
    return 2
  }
  if (lower.indexOf('wed') >= 0) {
    return 3
  }
  if (lower.indexOf('thu') >= 0) {
    return 4
  }
  if (lower.indexOf('fri') >= 0) {
    return 5
  }
  if (lower.indexOf('sat') >= 0) {
    return 6
  }
  if (lower.indexOf('sun') >= 0) {
    return 7
  }
  if (s.indexOf('一') >= 0) {
    return 1
  }
  if (s.indexOf('二') >= 0) {
    return 2
  }
  if (s.indexOf('三') >= 0) {
    return 3
  }
  if (s.indexOf('四') >= 0) {
    return 4
  }
  if (s.indexOf('五') >= 0) {
    return 5
  }
  if (s.indexOf('六') >= 0) {
    return 6
  }
  if (s.indexOf('日') >= 0 || s.indexOf('天') >= 0) {
    return 7
  }
  let m = s.match(/[1-7]/)
  return m === null ? 0 : parseInt(m[0])
}

// 支持 08:00 / 8：00 / 8点30 / Excel 时间序列（0~1 的一天比例）
function parseClock(raw: string): number {
  let s = raw.trim()
  if (s === '') {
    return -1
  }
  let num = Number(s)
  if (!isNaN(num) && s.indexOf(':') < 0 && s.indexOf('：') < 0 && s.indexOf('点') < 0) {
    if (num > 0 && num < 1) {
      return Math.round(num * 1440)
    }
    if (num >= 1 && num <= 24) {
      return Math.round(num * 60)
    }
    if (num >= 100 && num < 2400) {
      let h = Math.floor(num / 100)
      let min = Math.round(num % 100)
      if (h >= 0 && h < 24 && min >= 0 && min < 60) {
        return h * 60 + min
      }
    }
  }
  let m = s.match(/(\d{1,2})\s*[:：]\s*(\d{1,2})/)
  if (m !== null) {
    let h = parseInt(m[1])
    let min = parseInt(m[2])
    if (h >= 0 && h < 24 && min >= 0 && min < 60) {
      return h * 60 + min
    }
  }
  let m2 = s.match(/(\d{1,2})\s*[点时]\s*(\d{1,2})?/)
  if (m2 !== null) {
    let h = parseInt(m2[1])
    let min = m2[2] === undefined ? 0 : parseInt(m2[2])
    if (h >= 0 && h < 24 && min >= 0 && min < 60) {
      return h * 60 + min
    }
  }
  return -1
}

function splitRange(raw: string): string[] {
  let normalized = raw.replace(/[~～至到]/g, '-')
  let parts = normalized.split('-')
  if (parts.length < 2) {
    return [raw]
  }
  return [parts[0], parts[1]]
}

export class XlsxImporter {
  private static readText(path: string): string {
    let file = fs.openSync(path, fs.OpenMode.READ_ONLY)
    let stat = fs.statSync(file.fd)
    let buf = new ArrayBuffer(stat.size)
    let readLen = fs.readSync(file.fd, buf)
    fs.closeSync(file)
    let decoder = util.TextDecoder.create('utf-8')
    return decoder.decodeToString(new Uint8Array(buf, 0, readLen))
  }

  private static exists(path: string): boolean {
    try {
      return fs.accessSync(path)
    } catch (e) {
      return false
    }
  }

  private static sheetPath(root: string, workbook: string, rels: string): string {
    let sheetTag = ''
    let sheetRe = /<sheet[^>]*\/>/g
    let sm = sheetRe.exec(workbook)
    if (sm !== null) {
      sheetTag = sm[0]
    }
    let rid = attrOf(sheetTag, 'r:id')
    let target = ''
    if (rid !== '') {
      let relRe = /<Relationship[^>]*\/>/g
      let rm = relRe.exec(rels)
      while (rm !== null) {
        if (attrOf(rm[0], 'Id') === rid) {
          target = attrOf(rm[0], 'Target')
          break
        }
        rm = relRe.exec(rels)
      }
    }
    if (target === '') {
      return `${root}/xl/worksheets/sheet1.xml`
    }
    if (target.indexOf('/') === 0) {
      return `${root}${target}`
    }
    return `${root}/xl/${target}`
  }

  static async parse(uri: string, cacheDir: string): Promise<XlsxParseResult> {
    let result = new XlsxParseResult()
    let base = `${cacheDir}/timetable_xlsx_${Date.now()}`
    try {
      if (!XlsxImporter.exists(base)) {
        fs.mkdirSync(base)
      }
      let src = `${base}/source.xlsx`
      let out = `${base}/unzip`
      // 1. 复制到沙箱（DocumentViewPicker 返回的 uri 不能直接解压）
      let file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      let stat = fs.statSync(file.fd)
      let buf = new ArrayBuffer(stat.size)
      fs.readSync(file.fd, buf)
      fs.closeSync(file)
      let writer = fs.openSync(src, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
      fs.writeSync(writer.fd, buf)
      fs.closeSync(writer)
      // 2. 解压 zip（目标目录必须已存在，否则系统 zlib 报 900002 目标文件无效）
      if (!XlsxImporter.exists(out)) {
        fs.mkdirSync(out)
      }
      await zlib.decompressFile(src, out)
      // 3. 定位第一个工作表
      let workbookXml = XlsxImporter.readText(`${out}/xl/workbook.xml`)
      let relsPath = `${out}/xl/_rels/workbook.xml.rels`
      let relsXml = XlsxImporter.exists(relsPath) ? XlsxImporter.readText(relsPath) : ''
      let sheetFile = XlsxImporter.sheetPath(out, workbookXml, relsXml)
      if (!XlsxImporter.exists(sheetFile)) {
        result.errorType = 'format'
        result.message = '未找到工作表：文件可能不是标准 .xlsx，或工作簿结构已损坏。'
        return result
      }
      let sharedPath = `${out}/xl/sharedStrings.xml`
      let shared = XlsxImporter.exists(sharedPath) ? parseSharedStrings(XlsxImporter.readText(sharedPath)) : []
      let rows = parseSheet(XlsxImporter.readText(sheetFile), shared)
      if (rows.length === 0) {
        result.errorType = 'format'
        result.message = '工作表为空，没有可解析的课程行。'
        return result
      }
      // 4. 表头 + 数据行
      let map: HeaderMap | undefined = undefined
      let headerIndex = -1
      for (let i = 0; i < rows.length && i < 10; i++) {
        let hit = headerOf(rows[i])
        if (hit !== undefined) {
          map = hit
          headerIndex = i
          break
        }
      }
      if (map === undefined || headerIndex < 0) {
        result.errorType = 'missing'
        result.message = '未找到表头：请确保第一行包含「课程名称」「星期」「开始时间」（或「上课时间」）等列。'
        return result
      }
      let courses: ParsedCourse[] = []
      let dedupe: Record<string, boolean> = {}
      let skipped = 0
      let usedLocation = false
      let usedTeacher = false
      for (let i = headerIndex + 1; i < rows.length; i++) {
        let row = rows[i]
        let name = cellOf(row, map.name)
        if (name === '') {
          continue
        }
        let day = parseDay(cellOf(row, map.day))
        let start = -1
        let end = -1
        if (map.timeRange >= 0) {
          let range = splitRange(cellOf(row, map.timeRange))
          start = parseClock(range[0])
          end = range.length > 1 ? parseClock(range[1]) : -1
        } else {
          start = parseClock(cellOf(row, map.start))
          end = parseClock(cellOf(row, map.end))
        }
        if (day <= 0 || start < 0) {
          skipped++
          continue
        }
        if (end <= start) {
          end = start + 100
        }
        if (end > 23 * 60 + 59) {
          end = 23 * 60 + 59
        }
        let location = cellOf(row, map.location)
        let teacher = cellOf(row, map.teacher)
        if (location !== '') {
          usedLocation = true
        }
        if (teacher !== '') {
          usedTeacher = true
        }
        let startTime = minutesToTime(start)
        let endTime = minutesToTime(end)
        let key = `${name}|${day}|${startTime}|${endTime}|${location}|${teacher}`
        if (dedupe[key] === true) {
          continue
        }
        dedupe[key] = true
        let course = new ParsedCourse()
        course.name = name
        course.dayOfWeek = day
        course.startTime = startTime
        course.endTime = endTime
        course.location = location
        course.teacher = teacher
        courses.push(course)
      }
      result.skipped = skipped
      if (courses.length === 0) {
        result.errorType = 'missing'
        result.message = `共读取 ${rows.length - headerIndex - 1} 行数据，但均缺少有效的星期或开始时间，未导入课程。`
        return result
      }
      result.ok = true
      result.courses = courses
      let mappings: string[] = ['课程名称 → 课程名称', '星期 → 星期', '开始时间 → 上课时间']
      mappings.push(map.timeRange >= 0 ? '上课时间 → 起止时段' : '结束时间 → 下课时间（缺省按 100 分钟）')
      mappings.push(usedLocation ? '地点 → 授课地点' : '地点 → 文件未提供（显示为「—」）')
      mappings.push(usedTeacher ? '教师 → 任课教师' : '教师 → 文件未提供（显示为「—」）')
      result.mappings = mappings
      if (skipped > 0) {
        result.message = `已跳过 ${skipped} 行缺少有效星期或开始时间的数据。`
      }
      return result
    } catch (e) {
      let err = e as BusinessError
      console.error(`XlsxImporter parse failed: code=${err.code} message=${err.message}`)
      result.errorType = 'parse'
      result.message = '解析 .xlsx 失败：文件可能已损坏、被加密，或不是标准的 Excel 工作簿。'
      return result
    }
  }
}
