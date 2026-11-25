// ==================== 统一操作反馈（成功 Toast / 失败原因 / 二次确认） ====================
import { promptAction } from '@kit.ArkUI'

export class Feedback {
  static success(message: string): void {
    promptAction.showToast({ message: message })
  }

  static info(message: string): void {
    promptAction.showToast({ message: message })
  }

  // 操作失败必须带具体原因，避免只提示「失败」
  static fail(action: string, reason: string): void {
    promptAction.showToast({ message: `${action}失败：${reason}` })
  }

  // 通用二次确认弹窗：危险操作统一红色确认按钮
  static confirm(title: string, message: string, onConfirm: () => void,
    confirmLabel: string = '确定', danger: boolean = false): void {
    AlertDialog.show({
      title: title,
      message: message,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: confirmLabel,
        fontColor: danger ? '#EF4444' : '#3F7EF6',
        action: () => onConfirm()
      }
    })
  }
}
