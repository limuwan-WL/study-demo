// ==================== 网络状态（本地模拟弱网） ====================
// 当前工程无真实后端，用一个持久化开关模拟弱网 / 离线：
//   - 关闭后笔记、表单编辑进入「离线保存」；
//   - 重新打开即视为网络恢复，页面负责触发自动同步。
export class NetworkState {
  static online(): boolean {
    let v = AppStorage.get<boolean>('networkOnline')
    return v === undefined ? true : v
  }

  static setOnline(online: boolean): void {
    AppStorage.setOrCreate<boolean>('networkOnline', online)
  }

  static label(): string {
    return NetworkState.online() ? '在线' : '弱网离线'
  }
}
