// ==================== 离线草稿（表单类编辑区的本地暂存） ====================
// 🌟 弱网 / 离线时保存到本机；网络恢复后由页面调用 sync 完成自动提交；
//    若本地草稿版本落后于服务端（演示中用已有提交模拟），弹出「版本冲突」由用户选择。
export class OfflineDraft {
  key: string = ''
  payload: string = ''
  savedAt: number = 0
  version: number = 0

  constructor(key: string, payload: string, version: number) {
    this.key = key
    this.payload = payload
    this.version = version
    this.savedAt = Date.now()
  }
}

export class OfflineDraftStore {
  static list(): OfflineDraft[] {
    return AppStorage.get<OfflineDraft[]>('offlineDrafts') ?? []
  }

  static save(key: string, payload: string, version: number): void {
    let rest = OfflineDraftStore.list().filter((d: OfflineDraft) => d.key !== key)
    AppStorage.setOrCreate<OfflineDraft[]>('offlineDrafts', rest.concat([new OfflineDraft(key, payload, version)]))
  }

  static get(key: string): OfflineDraft | undefined {
    return OfflineDraftStore.list().find((d: OfflineDraft) => d.key === key)
  }

  static remove(key: string): void {
    AppStorage.setOrCreate<OfflineDraft[]>('offlineDrafts', OfflineDraftStore.list().filter((d: OfflineDraft) => d.key !== key))
  }

  static count(): number {
    return OfflineDraftStore.list().length
  }
}
