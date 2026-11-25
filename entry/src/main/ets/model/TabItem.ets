export class TabItem {
  title: string = ''
  icon: Resource
  badgeCount?: number

  constructor(title: string, icon: Resource, badgeCount?: number) {
    this.title = title
    this.icon = icon
    this.badgeCount = badgeCount
  }
}