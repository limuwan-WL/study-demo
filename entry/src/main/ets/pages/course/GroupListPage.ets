import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import { Guard } from '../../utils/Guard'
import { GroupMember } from '../../model/HomeworkModel'
import {
  ChatGroup,
  GroupNotice,
  restoreCourseDemo,
  canCreateGroup,
  currentName
} from '../../model/GroupModel'

// ==================== 班级群列表（主群 + 子分组群） ====================
@Entry
@Component
struct GroupListPage {
  @StorageLink('chatGroups') groups: ChatGroup[] = []
  @StorageLink('groupMembersMap') memberMap: Record<string, GroupMember[]> = {}
  @StorageLink('groupUnreadMap') unreadMap: Record<string, number> = {}
  @StorageLink('groupMuteMap') muteMap: Record<string, string> = {}
  @StorageLink('groupNotices') noticeList: GroupNotice[] = []
  @StorageLink('userRole') userRole: string = 'student'
  @StorageLink('courseQuit') quit: boolean = false

  aboutToAppear(): void {
    // 🌟 未加入课程的用户无法进入班级群列表；已主动退出课程时保留页面以展示「恢复访问（演示）」
    if (!this.quit && !Guard.course('csbasic')) {
      router.back()
    }
  }

  // 🌟 主群（一门课程绑定一个主班级群）
  mainOne(): ChatGroup | undefined {
    let hit = this.groups.filter((g: ChatGroup) => g.isMain && !g.dissolved)
    return hit.length > 0 ? hit[0] : undefined
  }

  subGroups(): ChatGroup[] {
    return this.groups.filter((g: ChatGroup) => !g.isMain && !g.dissolved)
  }

  memberCount(gid: string): number {
    let list = this.memberMap[gid]
    return list === undefined ? 0 : list.filter((m: GroupMember) => !m.removed).length
  }

  unread(gid: string): number {
    let n = this.unreadMap[gid]
    return n === undefined ? 0 : n
  }

  muteMode(gid: string): string {
    let m = this.muteMap[gid]
    return m === undefined ? 'off' : m
  }

  noticePreview(gid: string): string {
    let list = this.noticeList.filter((n: GroupNotice) => n.groupId === gid)
      .sort((a: GroupNotice, b: GroupNotice) => {
        if (a.pinned !== b.pinned) {
          return a.pinned ? -1 : 1
        }
        return b.updatedAt - a.updatedAt
      })
    if (list.length === 0) {
      return '暂无群公告'
    }
    let plain = list[0].content.split('**').join('').split('## ').join('').split('- ').join('')
      .split('\n').join(' ')
    return plain
  }

  openGroup(g: ChatGroup): void {
    if (this.quit) {
      promptAction.showToast({ message: '你已退出课程，访问权限已收回' })
      return
    }
    router.pushUrl({ url: 'pages/course/ClassGroupPage', params: { groupId: g.id } })
  }

  @Builder
  groupCard(g: ChatGroup) {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Text(g.isMain ? '班' : '组')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .width(50).height(50).borderRadius(14).textAlign(TextAlign.Center)
          .backgroundColor(g.isMain ? '#4C8BF5' : '#8B5CF6')

        Column({ space: 4 }) {
          Row({ space: 6 }) {
            Text(g.name)
              .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            if (g.isMain) {
              Text('主班级群')
                .fontSize(9).fontColor('#3F7EF6')
                .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                .backgroundColor('#3F7EF61A').borderRadius(6)
            }
          }.width('100%')

          Text(`${g.courseName} · ${this.memberCount(g.id)} 人 · 群主 ${g.ownerName}`)
            .fontSize(11).fontColor($r('app.color.text_hint'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)

        Column({ space: 4 }) {
          if (this.unread(g.id) > 0 && this.muteMode(g.id) !== 'block') {
            Text(`${this.unread(g.id) > 99 ? '99+' : this.unread(g.id)}`)
              .fontSize(10).fontColor(Color.White).fontWeight(FontWeight.Bold)
              .height(18).constraintSize({ minWidth: 18 })
              .padding({ left: 5, right: 5 })
              .backgroundColor('#EF4444').borderRadius(9).textAlign(TextAlign.Center)
          }
          if (this.muteMode(g.id) !== 'off') {
            Text(this.muteMode(g.id) === 'block' ? '🚫' : '🔕')
              .fontSize(12)
          }
        }.alignItems(HorizontalAlign.End)
      }.width('100%')

      Row({ space: 6 }) {
        Text(this.muteMode(g.id) === 'off' ? '群公告' : '群公告 · 免打扰')
          .fontSize(10).fontColor($r('app.color.text_hint'))
        Text(this.noticePreview(g.id))
          .fontSize(11).fontColor($r('app.color.text_sub'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%').padding({ left: 8, right: 8, top: 6, bottom: 6 })
      .backgroundColor($r('app.color.field_bg')).borderRadius(8)
    }
    .width('90%').padding(16).margin({ bottom: 12 })
    .backgroundColor($r('app.color.card_bg')).borderRadius(16)
    .onClick(() => this.openGroup(g))
  }

  @Builder
  blockedView() {
    Column({ space: 14 }) {
      Text('🚫').fontSize(44)
      Text('你已退出「数据结构与算法」').fontSize(16).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_main'))
      Text('已移出班级群，课程全部访问权限已收回。\n（本页为本地模拟，未接入真实教务系统）')
        .fontSize(12).fontColor($r('app.color.text_sub')).textAlign(TextAlign.Center).lineHeight(20)
      Row({ space: 12 }) {
        Text('返回课程')
          .fontSize(13).fontColor($r('app.color.text_label'))
          .padding({ left: 18, right: 18, top: 9, bottom: 9 })
          .backgroundColor($r('app.color.field_bg')).borderRadius(18)
          .onClick(() => router.back())
        Text('恢复访问（演示）')
          .fontSize(13).fontColor(Color.White)
          .padding({ left: 18, right: 18, top: 9, bottom: 9 })
          .backgroundColor($r('app.color.primary')).borderRadius(18)
          .onClick(() => {
            restoreCourseDemo()
            this.quit = false
            promptAction.showToast({ message: '已恢复课程访问（演示操作）' })
          })
      }
    }
    .width('100%').layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      // 顶部栏
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20).fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Column({ space: 2 }) {
          Text('班级群').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Text(`${currentName()} · ${this.userRole === 'teacher' ? '授课教师' : this.userRole === 'assistant' ? '助教' : '学生'}视角`)
            .fontSize(11).fontColor($r('app.color.text_hint'))
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        if (this.quit === false && canCreateGroup()) {
          Row({ space: 4 }) {
            Text('＋').fontSize(18).fontColor($r('app.color.primary'))
            Text('新建').fontSize(13).fontColor($r('app.color.primary'))
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .borderRadius(14)
          .border({ width: 1, color: $r('app.color.primary') })
          .onClick(() => router.pushUrl({ url: 'pages/course/GroupCreatePage' }))
        }
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.card_bg'))

      if (this.quit) {
        this.blockedView()
      } else {
        Scroll() {
          Column() {
            // 说明条
            Row({ space: 6 }) {
              Text('ℹ️').fontSize(12)
              Text('一门课程绑定一个主班级群；教师可额外创建多个子分组群。多端同步与云端为本地模拟。')
                .fontSize(10).fontColor($r('app.color.text_hint')).layoutWeight(1)
            }
            .width('90%').padding(10).margin({ top: 12, bottom: 12 })
            .backgroundColor($r('app.color.primary_weak')).borderRadius(10)

            // 主班级群
            Row() {
              Text('主班级群').fontSize(12).fontColor($r('app.color.text_hint'))
              Blank()
              Text('一门课程仅一个').fontSize(10).fontColor($r('app.color.text_hint'))
            }.width('90%').padding({ left: 4, bottom: 8 })

            if (this.mainOne() !== undefined) {
              this.groupCard(this.mainOne() as ChatGroup)
            } else {
              Column({ space: 8 }) {
                Text('暂无主班级群').fontSize(13).fontColor($r('app.color.text_sub'))
                if (canCreateGroup()) {
                  Text('新建主班级群')
                    .fontSize(12).fontColor(Color.White)
                    .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                    .backgroundColor($r('app.color.primary')).borderRadius(16)
                    .onClick(() => router.pushUrl({ url: 'pages/course/GroupCreatePage' }))
                }
              }
              .width('90%').padding(20).backgroundColor($r('app.color.card_bg')).borderRadius(16)
              .alignItems(HorizontalAlign.Center).margin({ bottom: 12 })
            }

            // 子分组群
            Row() {
              Text('子分组群').fontSize(12).fontColor($r('app.color.text_hint'))
              Blank()
              Text(`${this.subGroups().length} 个`).fontSize(10).fontColor($r('app.color.text_hint'))
            }.width('90%').padding({ left: 4, top: 8, bottom: 8 })

            if (this.subGroups().length === 0) {
              Text('教师还没有创建子分组群')
                .fontSize(12).fontColor($r('app.color.text_hint'))
                .width('90%').padding(18).textAlign(TextAlign.Center)
                .backgroundColor($r('app.color.card_bg')).borderRadius(16)
            } else {
              ForEach(this.subGroups(), (g: ChatGroup) => {
                this.groupCard(g)
              }, (g: ChatGroup) => g.id)
            }

            if (!canCreateGroup()) {
              Text(this.userRole === 'assistant'
                ? '助教建群权限尚未开启，请联系授课教师在群设置中开启。'
                : '仅授课教师可新建班级群。')
                .fontSize(10).fontColor($r('app.color.text_hint'))
                .width('90%').padding({ top: 6, left: 4, bottom: 40 })
            } else {
              Row().width('100%').height(40)
            }
          }.width('100%')
        }
        .layoutWeight(1).align(Alignment.Top).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
