// ==================== 预置头像（我的页 / 个人资料页共用） ====================
// 使用系统符号 + 彩色底：emoji 在部分环境渲染为黑块，系统符号全环境可用。
export class AvatarOption {
  key: string = ''
  icon: Resource = $r('sys.symbol.face_smiling')
  color: string = '#3F7EF6'

  constructor(key: string, icon: Resource, color: string) {
    this.key = key
    this.icon = icon
    this.color = color
  }
}

export const AVATAR_LIST: AvatarOption[] = [
  new AvatarOption('笑脸', $r('sys.symbol.face_smiling'), '#3F7EF6'),
  new AvatarOption('爪印', $r('sys.symbol.pawprint'), '#E8A33E'),
  new AvatarOption('小鱼', $r('sys.symbol.fish'), '#14B8A6'),
  new AvatarOption('绿叶', $r('sys.symbol.leaf_fill'), '#55C873'),
  new AvatarOption('学霸', $r('sys.symbol.graduationcap'), '#8B5CF6'),
  new AvatarOption('篮球', $r('sys.symbol.basketball_fill'), '#EF7D44'),
  new AvatarOption('游戏', $r('sys.symbol.gamecontroller_fill'), '#6366F1'),
  new AvatarOption('相机', $r('sys.symbol.camera_fill'), '#0EA5E9'),
  new AvatarOption('星星', $r('sys.symbol.star_fill'), '#E8B93E'),
  new AvatarOption('爱心', $r('sys.symbol.heart_fill'), '#EF4444'),
  new AvatarOption('火焰', $r('sys.symbol.flame_fill'), '#F97316'),
  new AvatarOption('月亮', $r('sys.symbol.moon_fill'), '#64748B')
]

export function findAvatar(key: string): AvatarOption | undefined {
  return AVATAR_LIST.find((a: AvatarOption) => a.key === key)
}
