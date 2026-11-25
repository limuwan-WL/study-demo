// 笔记分享工具：生成分享码 / 链接，并复制到剪贴板
// ⚠️ 无后端：分享链接为本地模拟地址，仅用于演示分享流程
import { pasteboard } from '@kit.BasicServicesKit'
import { NoteItem } from '../model/DataModel'

const SHARE_BASE: string = 'https://notes.campus.local/s/'

export class NoteShare {
  // 由笔记 id 稳定计算 8 位分享码，同一篇笔记链接不变
  static code(note: NoteItem): string {
    let raw = note.id
    let hash = 0
    for (let i = 0; i < raw.length; i++) {
      hash = (hash * 31 + raw.charCodeAt(i)) % 99999989
    }
    let code = hash.toString(36)
    while (code.length < 8) {
      code = '0' + code
    }
    return code.substring(code.length - 8)
  }

  static link(note: NoteItem): string {
    let code = note.shareCode === '' ? NoteShare.code(note) : note.shareCode
    return SHARE_BASE + code
  }

  static async copy(text: string): Promise<boolean> {
    try {
      let data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
      await pasteboard.getSystemPasteboard().setData(data)
      return true
    } catch (err) {
      return false
    }
  }
}
