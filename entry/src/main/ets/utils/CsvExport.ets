// 🌟 台账导出工具：写入应用沙箱内的 CSV 文件
// ⚠️ 端上不生成真正的 .xlsx（需要 ZIP + XML 打包链路），这里导出 Excel 可直接打开的 UTF-8 CSV
import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { csvCell } from '../model/InteractionModel'

export class CsvExport {
  static toText(rows: string[][]): string {
    let lines: string[] = []
    rows.forEach((r: string[]) => {
      lines.push(r.map((c: string) => csvCell(c)).join(','))
    })
    // BOM 让 Excel 识别为 UTF-8，避免中文乱码
    return '\uFEFF' + lines.join('\r\n')
  }

  static write(ctx: common.UIAbilityContext, fileName: string, rows: string[][]): string {
    let path = `${ctx.filesDir}/${fileName}`
    let file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, CsvExport.toText(rows))
    fs.closeSync(file)
    return path
  }
}
