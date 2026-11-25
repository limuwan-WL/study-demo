// ==================== 笔记云端同步（本地模拟层） ====================
// ⚠️ 当前工程没有真实后端，这里用 PersistentStorage 模拟云端快照：
//    - 用「账号 -> 笔记快照」模拟服务端存储，接口形态与真实同步一致（pull / push / 冲突合并）；
//    - 本地每次保存 version + 1，baseVersion 记录上次同步版本，两者比较即可检测版本冲突；
//    - UI 上明确标注「本地模拟云端（无真实后端）」，不冒充真实网络同步。
//    接入后端时只需替换本文件实现，页面无需改动。
import { NoteItem, cloneNote, normalizeNotes, formatStamp } from '../model/DataModel'

const CLOUD_KEY: string = 'noteCloud'
const CLOUD_TIME_KEY: string = 'noteCloudTime'

// 版本冲突：同一篇笔记本地与云端都改过，交给用户选择保留哪一份
export class NoteConflict {
  local: NoteItem
  cloud: NoteItem

  constructor(local: NoteItem, cloud: NoteItem) {
    this.local = local
    this.cloud = cloud
  }
}

export class NoteSyncResult {
  notes: NoteItem[] = []
  conflicts: NoteConflict[] = []
  uploaded: number = 0
  downloaded: number = 0
  time: string = ''

  constructor(notes: NoteItem[], conflicts: NoteConflict[], uploaded: number, downloaded: number, time: string) {
    this.notes = notes
    this.conflicts = conflicts
    this.uploaded = uploaded
    this.downloaded = downloaded
    this.time = time
  }
}

export class NoteSync {
  static readonly LABEL: string = '本地模拟云端（无真实后端）'

  private static accountKey(account: string): string {
    return account === '' ? 'guest' : account
  }

  static pull(account: string): NoteItem[] {
    let cloud = AppStorage.get<Record<string, NoteItem[]>>(CLOUD_KEY) ?? {}
    let list = cloud[NoteSync.accountKey(account)]
    if (list === undefined || list === null) {
      return []
    }
    return normalizeNotes(list)
  }

  static cloudTime(account: string): string {
    let times = AppStorage.get<Record<string, string>>(CLOUD_TIME_KEY) ?? {}
    let value = times[NoteSync.accountKey(account)]
    return value === undefined ? '' : value
  }

  // 永久删除：同时从云端快照移除，避免下次同步又被拉回来
  static purge(account: string, noteId: string): void {
    let key = NoteSync.accountKey(account)
    let cloud = AppStorage.get<Record<string, NoteItem[]>>(CLOUD_KEY) ?? {}
    let list = cloud[key]
    if (list === undefined) {
      return
    }
    let next: Record<string, NoteItem[]> = {}
    Object.keys(cloud).forEach((k: string) => {
      next[k] = cloud[k]
    })
    next[key] = list.filter((n: NoteItem) => n.id !== noteId)
    AppStorage.setOrCreate<Record<string, NoteItem[]>>(CLOUD_KEY, next)
  }

  private static saveCloud(account: string, notes: NoteItem[]): void {
    let key = NoteSync.accountKey(account)
    let cloud = AppStorage.get<Record<string, NoteItem[]>>(CLOUD_KEY) ?? {}
    let next: Record<string, NoteItem[]> = {}
    Object.keys(cloud).forEach((k: string) => {
      next[k] = cloud[k]
    })
    next[key] = notes.map((n: NoteItem) => cloneNote(n))
    AppStorage.setOrCreate<Record<string, NoteItem[]>>(CLOUD_KEY, next)

    let times = AppStorage.get<Record<string, string>>(CLOUD_TIME_KEY) ?? {}
    let nextTimes: Record<string, string> = {}
    Object.keys(times).forEach((k: string) => {
      nextTimes[k] = times[k]
    })
    nextTimes[key] = formatStamp(Date.now())
    AppStorage.setOrCreate<Record<string, string>>(CLOUD_TIME_KEY, nextTimes)
  }

  // 双向同步：上传本地改动、拉取云端新增，唯一冲突返回给页面让用户选择
  static sync(account: string, local: NoteItem[]): NoteSyncResult {
    let cloudNotes = NoteSync.pull(account)
    let cloudById: Record<string, NoteItem> = {}
    cloudNotes.forEach((c: NoteItem) => {
      cloudById[c.id] = c
    })

    let result: NoteItem[] = []
    let conflicts: NoteConflict[] = []
    let localIds: Record<string, boolean> = {}
    let uploaded = 0
    let downloaded = 0

    local.forEach((raw: NoteItem) => {
      let n = cloneNote(raw)
      localIds[n.id] = true
      let c = cloudById[n.id]
      if (c === undefined) {
        // 只在本地存在：首次上传
        n.baseVersion = n.version
        n.syncState = 'synced'
        uploaded++
        result.push(n)
        return
      }
      let localDirty = n.version > n.baseVersion
      let cloudChanged = c.version > n.baseVersion
      if (localDirty && cloudChanged && c.version !== n.version) {
        n.syncState = 'conflict'
        conflicts.push(new NoteConflict(cloneNote(n), cloneNote(c)))
        result.push(n)
      } else if (localDirty) {
        n.baseVersion = n.version
        n.syncState = 'synced'
        uploaded++
        result.push(n)
      } else if (cloudChanged) {
        let down = cloneNote(c)
        down.baseVersion = c.version
        down.syncState = 'synced'
        downloaded++
        result.push(down)
      } else {
        n.syncState = 'synced'
        result.push(n)
      }
    })

    cloudNotes.forEach((c: NoteItem) => {
      if (localIds[c.id] !== true) {
        let down = cloneNote(c)
        down.baseVersion = c.version
        down.syncState = 'synced'
        downloaded++
        result.push(down)
      }
    })

    // 冲突笔记暂不上传：云端快照保留冲突前的云端版本，等用户选择后再同步
    let uploadList = result.map((n: NoteItem) => {
      if (n.syncState !== 'conflict') {
        return n
      }
      let cloudCopy = cloudById[n.id]
      return cloudCopy === undefined ? n : cloudCopy
    })
    NoteSync.saveCloud(account, uploadList)
    return new NoteSyncResult(result, conflicts, uploaded, downloaded, formatStamp(Date.now()))
  }

  // 冲突时选择「保留本地」：版本号压过云端，重新入队等待同步
  static resolveWithLocal(notes: NoteItem[], noteId: string, cloudVersion: number): NoteItem[] {
    return notes.map((n: NoteItem) => {
      if (n.id !== noteId) {
        return n
      }
      let c = cloneNote(n)
      // baseVersion 对齐云端版本：本地版本更高即视为本地更新，下次同步直接上传
      c.baseVersion = cloudVersion
      c.version = Math.max(c.version, cloudVersion) + 1
      c.syncState = 'pending'
      c.updatedAt = Date.now()
      return c
    })
  }

  // 仅用于演示：模拟「另一台设备」修改了云端笔记（本地模拟，无真实网络）
  static simulateRemoteEdit(account: string, note: NoteItem): boolean {
    let cloud = NoteSync.pull(account)
    let exists = cloud.some((c: NoteItem) => c.id === note.id)
    let baseList: NoteItem[] = exists ? cloud : [cloneNote(note)].concat(cloud)
    let next = baseList.map((c: NoteItem) => {
      if (c.id !== note.id) {
        return c
      }
      let copy = cloneNote(c)
      copy.content = copy.content + '\n[来自另一台设备的云端修改]'
      copy.version = Math.max(copy.version, note.version) + 1
      copy.updatedAt = Date.now()
      copy.syncState = 'synced'
      // 云端版本与本地保持一致的回收站状态，避免「保留云端」把已删除的旧快照恢复出来
      copy.isDeleted = note.isDeleted
      copy.deletedAt = note.deletedAt
      return copy
    })
    NoteSync.saveCloud(account, next)
    return true
  }

  // 冲突时选择「保留云端」：直接用云端版本覆盖本地
  static resolveWithCloud(notes: NoteItem[], cloud: NoteItem): NoteItem[] {
    return notes.map((n: NoteItem) => {
      if (n.id !== cloud.id) {
        return n
      }
      let c = cloneNote(cloud)
      c.baseVersion = cloud.version
      c.syncState = 'synced'
      return c
    })
  }
}
