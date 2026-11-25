// 主题颜色工具类：根据 isDark 返回对应颜色
// 新增颜色只需在 COLOR_TABLE 中添加一行，页面调用 ThemeColor.get('xxx') 即可自动适配主题

interface ColorEntry {
  name: string
  light: string
  dark: string
}

const COLOR_TABLE: ColorEntry[] = [
  { name: 'page_bg', light: '#F6F8FA', dark: '#101214' },
  { name: 'card_bg', light: '#FFFFFF', dark: '#1C2026' },
  { name: 'field_bg', light: '#F0F2F5', dark: '#262B33' },
  { name: 'divider', light: '#F0F0F0', dark: '#262B33' },
  { name: 'text_main', light: '#18181A', dark: '#E6E8EB' },
  { name: 'text_body', light: '#333333', dark: '#C9CDD2' },
  { name: 'text_sub', light: '#8A919F', dark: '#9BA1A8' },
  { name: 'text_hint', light: '#B0B5C0', dark: '#6E747C' },
  { name: 'primary', light: '#3F7EF6', dark: '#5B93F7' },
  { name: 'danger', light: '#EF4444', dark: '#F87171' },
  { name: 'success', light: '#10B981', dark: '#34D399' },
  { name: 'warning', light: '#F59E0B', dark: '#FBBF24' },
  { name: 'btn_cancel', light: '#B0B5C0', dark: '#4A505A' },
  { name: 'primary_weak', light: '#EAF1FE', dark: '#1E2A3D' },
  { name: 'overlay', light: 'rgba(0,0,0,0.5)', dark: 'rgba(0,0,0,0.7)' }
]

export class ThemeColor {
  static isDark: boolean = false

  static get(name: string): string {
    const dark: boolean = ThemeColor.isDark
    for (let i = 0; i < COLOR_TABLE.length; i++) {
      const entry: ColorEntry = COLOR_TABLE[i]
      if (entry.name === name) {
        return dark ? entry.dark : entry.light
      }
    }
    return dark ? '#FFFFFF' : '#000000'
  }
}
