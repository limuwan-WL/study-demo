// 🌟 聊天主题系统：每个主题提供浅色 / 深色两套配色，与深浅色模式联动
// 影响范围：聊天页整体——聊天气泡（聊天框）、聊天文字、字体效果（字重 / 衬线体）、
// 聊天背景（列表基色 + 底层渐变）、顶栏 / 输入栏、头像、时间文字、气泡描边、发送按钮点缀色

export interface ChatThemeStyle {
  key: string
  name: string
  desc: string
  // 聊天区基色（'r, g, b' 字符串，用于和透明度叠加）与底层渐变
  listBaseLight: string
  gradTopLight: string
  gradBottomLight: string
  listBaseDark: string
  gradTopDark: string
  gradBottomDark: string
  // 气泡（聊天框）与聊天文字
  myBubbleLight: string
  myTextLight: string
  otherBubbleLight: string
  otherTextLight: string
  myBubbleDark: string
  myTextDark: string
  otherBubbleDark: string
  otherTextDark: string
  // 顶栏 / 输入栏底色
  barBgLight: string
  barBgDark: string
  // 输入框底色
  inputBgLight: string
  inputBgDark: string
  // 时间等辅助文字
  timeLight: string
  timeDark: string
  // 气泡描边
  borderLight: string
  borderDark: string
  // 点缀色（发送按钮、头像）
  accentLight: string
  accentDark: string
  // 字体效果：字重 + 是否衬线体
  fontWeight: FontWeight
  serif: boolean
  // 气泡圆角
  radius: number
}

export const CHAT_THEMES: ChatThemeStyle[] = [
  {
    key: 'default', name: '清新蓝（默认）', desc: '经典蓝白配色，干净利落',
    listBaseLight: '246, 248, 250', gradTopLight: '#DCE9FB', gradBottomLight: '#F6F8FA',
    listBaseDark: '16, 18, 20', gradTopDark: '#14273F', gradBottomDark: '#101214',
    myBubbleLight: '#3F7EF6', myTextLight: '#FFFFFF', otherBubbleLight: '#FFFFFF', otherTextLight: '#333333',
    myBubbleDark: '#3F7EF6', myTextDark: '#FFFFFF', otherBubbleDark: '#1C2026', otherTextDark: '#E6E8EB',
    barBgLight: '#FFFFFF', barBgDark: '#1C2026',
    inputBgLight: '#F0F2F5', inputBgDark: '#262B33',
    timeLight: '#B0B5C0', timeDark: '#6E7580',
    borderLight: 'transparent', borderDark: 'transparent',
    accentLight: '#3F7EF6', accentDark: '#5B8FF0',
    fontWeight: FontWeight.Normal, serif: false, radius: 16
  },
  {
    key: 'japanese', name: '日式小清新', desc: '樱花粉 × 米白，轻盈柔和',
    listBaseLight: '252, 240, 243', gradTopLight: '#F9D8E1', gradBottomLight: '#FCF0F3',
    listBaseDark: '44, 32, 36', gradTopDark: '#3A2430', gradBottomDark: '#2C2024',
    myBubbleLight: '#EF9FB2', myTextLight: '#FFFFFF', otherBubbleLight: '#FFFDF9', otherTextLight: '#6B5A52',
    myBubbleDark: '#C97B8F', myTextDark: '#FFFFFF', otherBubbleDark: '#3A2C31', otherTextDark: '#EBDDD8',
    barBgLight: '#FFF8FA', barBgDark: '#241C1F',
    inputBgLight: '#FBE9EE', inputBgDark: '#3A2C31',
    timeLight: '#C48B9B', timeDark: '#8A6B75',
    borderLight: '#F2C7D2', borderDark: '#5A3C48',
    accentLight: '#E58CA4', accentDark: '#D998AB',
    fontWeight: FontWeight.Lighter, serif: false, radius: 18
  },
  {
    key: 'pastoral', name: '中式田园', desc: '竹青 × 稻黄，质朴自然',
    listBaseLight: '246, 241, 222', gradTopLight: '#E0EAC6', gradBottomLight: '#F6F1DE',
    listBaseDark: '42, 44, 30', gradTopDark: '#313A22', gradBottomDark: '#2A2C1E',
    myBubbleLight: '#7BA05B', myTextLight: '#FFFFFF', otherBubbleLight: '#FDF8E7', otherTextLight: '#4A4A33',
    myBubbleDark: '#5E7F44', myTextDark: '#FFFFFF', otherBubbleDark: '#3A3E2C', otherTextDark: '#E5E3D2',
    barBgLight: '#FBF8EC', barBgDark: '#22251A',
    inputBgLight: '#F0EBD4', inputBgDark: '#3A3E2C',
    timeLight: '#A89B6E', timeDark: '#8A8A66',
    borderLight: '#D5CFA8', borderDark: '#55583C',
    accentLight: '#6E8B3D', accentDark: '#8FAD66',
    fontWeight: FontWeight.Normal, serif: false, radius: 12
  },
  {
    key: 'luxury', name: '西式奢靡风', desc: '香槟金 × 墨紫，典雅洋气',
    listBaseLight: '244, 236, 214', gradTopLight: '#EBD9A9', gradBottomLight: '#F4ECD6',
    listBaseDark: '43, 34, 50', gradTopDark: '#3A2B4E', gradBottomDark: '#2B2232',
    myBubbleLight: '#C9A227', myTextLight: '#FFFFFF', otherBubbleLight: '#FFFBEF', otherTextLight: '#4A4230',
    myBubbleDark: '#A9821F', myTextDark: '#FFFFFF', otherBubbleDark: '#3A2E47', otherTextDark: '#EAE2D3',
    barBgLight: '#F9F3E4', barBgDark: '#231C2B',
    inputBgLight: '#EFE6CC', inputBgDark: '#3A2E47',
    timeLight: '#B49B5C', timeDark: '#9C8560',
    borderLight: '#D9BE6E', borderDark: '#6E5A2E',
    accentLight: '#B08D2E', accentDark: '#CBA94B',
    fontWeight: FontWeight.Medium, serif: true, radius: 16
  },
  {
    key: 'ocean', name: '海洋清新', desc: '青蓝 × 水色，透亮清爽',
    listBaseLight: '235, 246, 248', gradTopLight: '#C9E9EF', gradBottomLight: '#EBF6F8',
    listBaseDark: '16, 36, 42', gradTopDark: '#123842', gradBottomDark: '#10242A',
    myBubbleLight: '#2AA5B8', myTextLight: '#FFFFFF', otherBubbleLight: '#FFFFFF', otherTextLight: '#2E4A52',
    myBubbleDark: '#1F8496', myTextDark: '#FFFFFF', otherBubbleDark: '#1E343C', otherTextDark: '#D8E8EC',
    barBgLight: '#F5FBFC', barBgDark: '#1A3038',
    inputBgLight: '#DFF2F5', inputBgDark: '#223C44',
    timeLight: '#7FAAB4', timeDark: '#5E7E88',
    borderLight: '#BCE3EA', borderDark: '#2E525E',
    accentLight: '#2298AC', accentDark: '#4FB3C4',
    fontWeight: FontWeight.Normal, serif: false, radius: 16
  },
  {
    key: 'milktea', name: '奶茶暖棕', desc: '焦糖奶茶色，温柔治愈',
    listBaseLight: '247, 240, 232', gradTopLight: '#EAD9C8', gradBottomLight: '#F7F0E8',
    listBaseDark: '42, 35, 30', gradTopDark: '#382C24', gradBottomDark: '#2A231E',
    myBubbleLight: '#B98A5E', myTextLight: '#FFFFFF', otherBubbleLight: '#FFFDF9', otherTextLight: '#5A4A3A',
    myBubbleDark: '#96683F', myTextDark: '#FFFFFF', otherBubbleDark: '#3A2E26', otherTextDark: '#EADFD3',
    barBgLight: '#FBF5EE', barBgDark: '#241E19',
    inputBgLight: '#F0E4D6', inputBgDark: '#3A2E26',
    timeLight: '#B29477', timeDark: '#8A7260',
    borderLight: '#E0CCB4', borderDark: '#54463A',
    accentLight: '#A87A4F', accentDark: '#C49A6E',
    fontWeight: FontWeight.Normal, serif: false, radius: 14
  },
  {
    key: 'retro', name: '复古文艺', desc: '牛皮纸 × 咖啡棕，衬线旧时光',
    listBaseLight: '240, 233, 219', gradTopLight: '#E0D4B8', gradBottomLight: '#F0E9DB',
    listBaseDark: '40, 36, 28', gradTopDark: '#332D20', gradBottomDark: '#28241C',
    myBubbleLight: '#8C6E4A', myTextLight: '#FFFFFF', otherBubbleLight: '#FAF6EA', otherTextLight: '#4E4230',
    myBubbleDark: '#6E5537', myTextDark: '#FFFFFF', otherBubbleDark: '#383226', otherTextDark: '#E5DCC8',
    barBgLight: '#F5F0E2', barBgDark: '#211E17',
    inputBgLight: '#E8E0CC', inputBgDark: '#383226',
    timeLight: '#A08D68', timeDark: '#7E7053',
    borderLight: '#D4C6A2', borderDark: '#4E4632',
    accentLight: '#7E6238', accentDark: '#A98C5E',
    fontWeight: FontWeight.Medium, serif: true, radius: 10
  },
  {
    key: 'starry', name: '梦幻星空', desc: '星云紫 × 月光白，浪漫柔和',
    listBaseLight: '237, 238, 250', gradTopLight: '#D8D4F2', gradBottomLight: '#EDEEFA',
    listBaseDark: '22, 22, 40', gradTopDark: '#2A2450', gradBottomDark: '#161628',
    myBubbleLight: '#7B6FD0', myTextLight: '#FFFFFF', otherBubbleLight: '#FFFFFF', otherTextLight: '#3E3A5E',
    myBubbleDark: '#5E50B8', myTextDark: '#FFFFFF', otherBubbleDark: '#262444', otherTextDark: '#DCDAF2',
    barBgLight: '#F4F4FC', barBgDark: '#1C1C32',
    inputBgLight: '#E3E2F6', inputBgDark: '#2E2C50',
    timeLight: '#9A94C6', timeDark: '#6E68A0',
    borderLight: '#CCC8EC', borderDark: '#403C6E',
    accentLight: '#6C5ECC', accentDark: '#8F84E0',
    fontWeight: FontWeight.Normal, serif: false, radius: 18
  },
  {
    key: 'neon', name: '暗夜霓虹', desc: '赛博紫 × 霓虹青，潮酷炫彩',
    listBaseLight: '240, 238, 248', gradTopLight: '#DCC8F0', gradBottomLight: '#F0EEF8',
    listBaseDark: '14, 14, 20', gradTopDark: '#1E1440', gradBottomDark: '#0E0E14',
    myBubbleLight: '#8A4FD8', myTextLight: '#FFFFFF', otherBubbleLight: '#E8FFFB', otherTextLight: '#0E5A4E',
    myBubbleDark: '#7A3FD0', myTextDark: '#FFFFFF', otherBubbleDark: '#142430', otherTextDark: '#2DE2C8',
    barBgLight: '#F5F2FA', barBgDark: '#12121C',
    inputBgLight: '#E4D8F2', inputBgDark: '#1C2836',
    timeLight: '#8A76B0', timeDark: '#5E5E86',
    borderLight: '#C8AEE8', borderDark: '#2A4A5A',
    accentLight: '#8A4FD8', accentDark: '#2DE2C8',
    fontWeight: FontWeight.Medium, serif: false, radius: 20
  },
  {
    key: 'mint', name: '薄荷苏打', desc: '薄荷绿 × 冰白，清凉透气',
    listBaseLight: '233, 246, 240', gradTopLight: '#CDEDE1', gradBottomLight: '#E9F6F0',
    listBaseDark: '18, 38, 32', gradTopDark: '#16382E', gradBottomDark: '#122620',
    myBubbleLight: '#3EBD93', myTextLight: '#FFFFFF', otherBubbleLight: '#FFFFFF', otherTextLight: '#2E4E42',
    myBubbleDark: '#2E9E7A', myTextDark: '#FFFFFF', otherBubbleDark: '#1E362E', otherTextDark: '#D6EAE0',
    barBgLight: '#F3FBF7', barBgDark: '#182420',
    inputBgLight: '#DDF1E8', inputBgDark: '#22382E',
    timeLight: '#7FA898', timeDark: '#5E8072',
    borderLight: '#BCE4D6', borderDark: '#2C4C40',
    accentLight: '#2FA984', accentDark: '#5BC4A2',
    fontWeight: FontWeight.Normal, serif: false, radius: 16
  },
  {
    key: 'peach', name: '蜜桃汽水', desc: '蜜桃橙 × 奶白，元气满满',
    listBaseLight: '255, 241, 234', gradTopLight: '#FFDDCB', gradBottomLight: '#FFF1EA',
    listBaseDark: '42, 30, 26', gradTopDark: '#3A2820', gradBottomDark: '#2A1E1A',
    myBubbleLight: '#F2825C', myTextLight: '#FFFFFF', otherBubbleLight: '#FFFDFB', otherTextLight: '#5C4438',
    myBubbleDark: '#D06845', myTextDark: '#FFFFFF', otherBubbleDark: '#3C2A22', otherTextDark: '#F2DDD2',
    barBgLight: '#FFF7F2', barBgDark: '#241C18',
    inputBgLight: '#FFE6D8', inputBgDark: '#3C2A22',
    timeLight: '#C69478', timeDark: '#94705C',
    borderLight: '#F5C9B2', borderDark: '#54382C',
    accentLight: '#E8703F', accentDark: '#F2926C',
    fontWeight: FontWeight.Normal, serif: false, radius: 18
  },
  {
    key: 'honey', name: '蜂蜜柚子', desc: '蜂蜜黄 × 暖白，甜蜜明亮',
    listBaseLight: '255, 248, 225', gradTopLight: '#FFEDB8', gradBottomLight: '#FFF8E1',
    listBaseDark: '40, 36, 20', gradTopDark: '#383018', gradBottomDark: '#282414',
    myBubbleLight: '#D99A00', myTextLight: '#FFFFFF', otherBubbleLight: '#FFFDF5', otherTextLight: '#5A4E2E',
    myBubbleDark: '#B88800', myTextDark: '#FFFFFF', otherBubbleDark: '#383220', otherTextDark: '#EFE6C8',
    barBgLight: '#FFFBF0', barBgDark: '#201E12',
    inputBgLight: '#FFF0CC', inputBgDark: '#383220',
    timeLight: '#C2A55C', timeDark: '#8E7A48',
    borderLight: '#F0DB9A', borderDark: '#4C4224',
    accentLight: '#D69C00', accentDark: '#E8B83C',
    fontWeight: FontWeight.Medium, serif: false, radius: 14
  },
  {
    key: 'mono', name: '极简黑白', desc: '纯黑白灰，克制高级感',
    listBaseLight: '250, 250, 250', gradTopLight: '#E8E8E8', gradBottomLight: '#FAFAFA',
    listBaseDark: '18, 18, 18', gradTopDark: '#262626', gradBottomDark: '#121212',
    myBubbleLight: '#262626', myTextLight: '#FFFFFF', otherBubbleLight: '#F0F0F0', otherTextLight: '#1A1A1A',
    myBubbleDark: '#E6E6E6', myTextDark: '#121212', otherBubbleDark: '#262626', otherTextDark: '#E6E6E6',
    barBgLight: '#FFFFFF', barBgDark: '#1A1A1A',
    inputBgLight: '#EFEFEF', inputBgDark: '#262626',
    timeLight: '#A0A0A0', timeDark: '#606060',
    borderLight: '#D8D8D8', borderDark: '#3A3A3A',
    accentLight: '#262626', accentDark: '#E6E6E6',
    fontWeight: FontWeight.Medium, serif: false, radius: 6
  }
]

export function chatThemeByKey(key: string): ChatThemeStyle {
  let found = CHAT_THEMES.find((t: ChatThemeStyle) => t.key === key)
  return found !== undefined ? found : CHAT_THEMES[0]
}

// 🌟 按当前深浅色模式解析出的最终颜色集合
export class ChatColors {
  listBase: string = '246, 248, 250'
  gradTop: string = '#DCE9FB'
  gradBottom: string = '#F6F8FA'
  myBubble: string = '#3F7EF6'
  myText: string = '#FFFFFF'
  otherBubble: string = '#FFFFFF'
  otherText: string = '#333333'
  barBg: string = '#FFFFFF'
  inputBg: string = '#F0F2F5'
  timeColor: string = '#B0B5C0'
  bubbleBorder: string = 'transparent'
  accent: string = '#3F7EF6'
  fontWeight: FontWeight = FontWeight.Normal
  serif: boolean = false
  radius: number = 16
}

export function resolveChatColors(key: string, dark: boolean): ChatColors {
  let t = chatThemeByKey(key)
  let c = new ChatColors()
  if (dark) {
    c.listBase = t.listBaseDark
    c.gradTop = t.gradTopDark
    c.gradBottom = t.gradBottomDark
    c.myBubble = t.myBubbleDark
    c.myText = t.myTextDark
    c.otherBubble = t.otherBubbleDark
    c.otherText = t.otherTextDark
    c.barBg = t.barBgDark
    c.inputBg = t.inputBgDark
    c.timeColor = t.timeDark
    c.bubbleBorder = t.borderDark
    c.accent = t.accentDark
  } else {
    c.listBase = t.listBaseLight
    c.gradTop = t.gradTopLight
    c.gradBottom = t.gradBottomLight
    c.myBubble = t.myBubbleLight
    c.myText = t.myTextLight
    c.otherBubble = t.otherBubbleLight
    c.otherText = t.otherTextLight
    c.barBg = t.barBgLight
    c.inputBg = t.inputBgLight
    c.timeColor = t.timeLight
    c.bubbleBorder = t.borderLight
    c.accent = t.accentLight
  }
  c.fontWeight = t.fontWeight
  c.serif = t.serif
  c.radius = t.radius
  return c
}
