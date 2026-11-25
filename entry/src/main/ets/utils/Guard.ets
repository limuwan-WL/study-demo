// ==================== 页面级权限守卫（统一提示文案，页面只调用一个方法） ====================
import { promptAction } from '@kit.ArkUI'
import { Action, Permission } from '../model/PermissionModel'

export class Guard {
  // 动作权限：无权时统一 Toast 具体原因
  static action(action: string, label: string): boolean {
    if (Permission.hasAction(action)) {
      return true
    }
    promptAction.showToast({ message: Permission.deniedReason(action) })
    return false
  }

  // 课程访问：未加入课程 / 非授课教师 / 未分配助教均拦截
  static course(subjectId: string): boolean {
    if (Permission.canAccessCourse(subjectId)) {
      return true
    }
    promptAction.showToast({ message: Permission.courseDeniedReason(subjectId) })
    return false
  }

  static teacher(label: string): boolean {
    if (Permission.isTeacher()) {
      return true
    }
    promptAction.showToast({ message: `${Permission.roleLabel()}身份无法${label}` })
    return false
  }

  // 教学侧操作统一走动作权限表（教师 / 助教 / 管理员），避免页面重复判断角色
  static staff(label: string): boolean {
    if (Permission.hasAction(Action.GROUP_LEDGER)) {
      return true
    }
    promptAction.showToast({ message: `仅授课教师、助教或管理员可${label}` })
    return false
  }

  static actionLabel(action: string): string {
    if (action === Action.COURSE_MANAGE_BASE) {
      return '修改课程基础配置'
    }
    if (action === Action.COURSE_POINT_RULE) {
      return '调整学分规则'
    }
    if (action === Action.COURSE_DELETE) {
      return '删除课程'
    }
    if (action === Action.QUESTION_EDIT) {
      return '维护题库'
    }
    if (action === Action.ASSISTANT_MANAGE) {
      return '管理助教'
    }
    return '执行该操作'
  }
}
