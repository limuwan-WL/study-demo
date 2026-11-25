// ==================== 统一上传策略：大小上限 + 图片压缩 + 内容审核 ====================
// 🌟 所有上传入口（资源中心 / 笔记图片 / 头像等）共用同一套策略，避免各页面各写一份。
//    当前工程为本地沙箱存储，审核为本地关键词模拟（无真实后端）。
import { fileIo as fs } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { ResourceAudit, formatSize, validateSize } from '../model/ResourceModel'

export class UploadResult {
  ok: boolean = false
  uri: string = ''
  sizeBytes: number = 0
  reason: string = ''
  blocked: boolean = false
  compressed: boolean = false
}

export class UploadPolicy {
  // 真实图片压缩：解码 → 以 quality 60 重新编码 JPEG；失败时原样拷贝兜底（返回最终字节数，0 表示失败）
  static async compressImage(srcUri: string, dest: string): Promise<number> {
    try {
      let src = image.createImageSource(srcUri)
      let pm = await src.createPixelMap()
      let packer = image.createImagePacker()
      let opt: image.PackingOption = { format: 'image/jpeg', quality: 60 }
      let buf = await packer.packing(pm, opt)
      let file = fs.openSync(dest, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
      fs.writeSync(file.fd, buf)
      fs.closeSync(file)
      let size = fs.statSync(dest).size
      packer.release()
      pm.release()
      src.release()
      if (size > 0) {
        return size
      }
    } catch (e) {
      // 压缩失败走拷贝兜底
    }
    try {
      let src = fs.openSync(srcUri, fs.OpenMode.READ_ONLY)
      fs.copyFileSync(src.fd, dest)
      fs.closeSync(src)
      return fs.statSync(dest).size
    } catch (e2) {
      return 0
    }
  }

  // 图片上传全流程：大小校验 → 自动压缩 → 内容审核
  static async prepareImage(srcUri: string, dest: string, displayName: string): Promise<UploadResult> {
    let res = new UploadResult()
    let rawSize = 0
    try {
      rawSize = fs.statSync(srcUri).size
    } catch (e) {
      rawSize = 0
    }
    let sizeReason = validateSize('image', rawSize)
    if (sizeReason !== '') {
      res.reason = sizeReason
      return res
    }
    let finalSize = await UploadPolicy.compressImage(srcUri, dest)
    if (finalSize <= 0) {
      res.reason = '图片读取或压缩失败，请更换图片重试'
      return res
    }
    res.sizeBytes = finalSize
    res.compressed = finalSize < rawSize
    res.uri = dest
    res.blocked = ResourceAudit.check(displayName) === 'blocked'
    res.ok = !res.blocked
    res.reason = res.blocked ? ResourceAudit.reason(displayName) : ''
    return res
  }

  // 普通文件：只做大小校验与内容审核（不做压缩）
  static checkFile(name: string, sizeBytes: number): UploadResult {
    let res = new UploadResult()
    let sizeReason = validateSize('file', sizeBytes)
    if (sizeReason !== '') {
      res.reason = sizeReason
      return res
    }
    res.sizeBytes = sizeBytes
    res.blocked = ResourceAudit.check(name) === 'blocked'
    res.ok = !res.blocked
    res.reason = res.blocked ? ResourceAudit.reason(name) : ''
    return res
  }

  static sizeLabel(bytes: number): string {
    return formatSize(bytes)
  }
}
