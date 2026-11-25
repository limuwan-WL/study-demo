// ==================== 资源存储与安全（本地模拟） ====================
// ⚠️ 无真实后端：文件拷贝到应用沙箱，元数据持久化在 AppStorage；
//    审核采用本地关键词审核（演示），真实项目应替换为服务端内容审核接口。
export type ResourceKind = 'image' | 'file'
export type ResourceVisibility = 'private' | 'course' | 'public'
export type AuditState = 'reviewing' | 'passed' | 'blocked'

export const IMAGE_MAX_MB: number = 5
export const FILE_MAX_MB: number = 20

export class ResourceItem {
  id: string = ''
  name: string = ''
  kind: ResourceKind = 'file'
  sizeBytes: number = 0
  visibility: ResourceVisibility = 'private'
  audit: AuditState = 'passed'
  auditReason: string = ''
  uri: string = ''
  createdAt: number = 0
  compressed: boolean = false

  constructor(name: string, kind: ResourceKind, sizeBytes: number, uri: string) {
    this.id = `res_${Date.now()}_${Math.floor(Math.random() * 1000)}`
    this.name = name
    this.kind = kind
    this.sizeBytes = sizeBytes
    this.uri = uri
    this.createdAt = Date.now()
  }
}

export function formatSize(bytes: number): string {
  if (bytes >= 1024 * 1024) {
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }
  if (bytes >= 1024) {
    return `${Math.round(bytes / 1024)} KB`
  }
  return `${bytes} B`
}

export function limitBytes(kind: ResourceKind): number {
  return (kind === 'image' ? IMAGE_MAX_MB : FILE_MAX_MB) * 1024 * 1024
}

// 返回空字符串表示通过，否则返回具体超限原因
export function validateSize(kind: ResourceKind, size: number): string {
  let max = limitBytes(kind)
  if (size > max) {
    return `${kind === 'image' ? '图片' : '文件'}上限 ${kind === 'image' ? IMAGE_MAX_MB : FILE_MAX_MB}MB，当前 ${formatSize(size)}`
  }
  return ''
}

const BLOCK_WORDS: string[] = ['违规', '色情', '暴力', '涉政', '赌博', '广告', '外挂', 'exe']

// 本地关键词审核：命中即屏蔽；其余进入「已通过」
export class ResourceAudit {
  static check(name: string): AuditState {
    let lower = name.toLowerCase()
    let hit = BLOCK_WORDS.some((w: string) => lower.indexOf(w) >= 0)
    return hit ? 'blocked' : 'passed'
  }

  static reason(name: string): string {
    let lower = name.toLowerCase()
    let hit = BLOCK_WORDS.find((w: string) => lower.indexOf(w) >= 0)
    return hit === undefined ? '' : `命中违规关键词「${hit}」，已自动屏蔽`
  }
}

export function visibilityLabel(v: ResourceVisibility): string {
  if (v === 'course') {
    return '课程可见'
  }
  if (v === 'public') {
    return '公开'
  }
  return '私有'
}

export function visibilityColor(v: ResourceVisibility): string {
  if (v === 'course') {
    return '#8B5CF6'
  }
  if (v === 'public') {
    return '#10B981'
  }
  return '#64748B'
}

export function auditLabel(a: AuditState): string {
  if (a === 'blocked') {
    return '已屏蔽'
  }
  if (a === 'reviewing') {
    return '审核中'
  }
  return '已通过'
}

export function auditColor(a: AuditState): string {
  if (a === 'blocked') {
    return '#EF4444'
  }
  if (a === 'reviewing') {
    return '#8B5CF6'
  }
  return '#10B981'
}

export class ResourceStore {
  static list(): ResourceItem[] {
    return AppStorage.get<ResourceItem[]>('resourceList') ?? []
  }

  static save(list: ResourceItem[]): void {
    AppStorage.setOrCreate<ResourceItem[]>('resourceList', list)
  }

  static add(item: ResourceItem): void {
    ResourceStore.save([item].concat(ResourceStore.list()))
  }

  static remove(id: string): boolean {
    let list = ResourceStore.list()
    let next = list.filter((r: ResourceItem) => r.id !== id)
    if (next.length === list.length) {
      return false
    }
    ResourceStore.save(next)
    return true
  }

  static setVisibility(id: string, v: ResourceVisibility): void {
    let next = ResourceStore.list().map((r: ResourceItem) => {
      if (r.id === id) {
        r.visibility = v
      }
      return r
    })
    ResourceStore.save(next)
  }

  // 首次进入灌入演示记录（一条通过、一条屏蔽），便于直接看到审核效果
  static ensureSeed(): void {
    if (AppStorage.get<boolean>('resourceSeeded') === true) {
      return
    }
    AppStorage.setOrCreate<boolean>('resourceSeeded', true)
    if (ResourceStore.list().length > 0) {
      return
    }
    let ok = new ResourceItem('课程笔记.pdf', 'file', 2.3 * 1024 * 1024, '')
    ok.audit = 'passed'
    ok.visibility = 'course'
    let bad = new ResourceItem('违规图片.jpg', 'image', 1.1 * 1024 * 1024, '')
    bad.audit = 'blocked'
    bad.auditReason = '命中违规关键词「违规」，已自动屏蔽'
    ResourceStore.save([bad, ok])
  }
}
