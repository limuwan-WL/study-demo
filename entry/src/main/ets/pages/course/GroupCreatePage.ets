import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import { GroupMember, groupMembers } from '../../model/HomeworkModel'
import {
  ChatGroup,
  MAIN_GROUP_ID,
  MAIN_TEACHER,
  GROUP_COURSE_NAME,
  canCreateGroup,
  currentName,
  currentRole,
  notifyGroup
} from '../../model/GroupModel'

// ==================== 新建班级群 ====================
// 🌟 权限：默认仅授课教师可建群；授课教师开启「助教建群权限」后助教可建
// 🌟 约束：一门课程仅一个主班级群，已有主群时只能创建子分组群
@Entry
@Component
struct GroupCreatePage {
  @StorageLink('chatGroups') groups: ChatGroup[] = []
  @StorageLink('groupMembersMap') memberMap: Record<string, GroupMember[]> = {}
  @StorageLink('userRole') userRole: string = 'student'
  @State groupName: string = ''
  @State useMain: boolean = false
  @State search: string = ''
  @State selected: string[] = []

  aboutToAppear(): void {
    // 🌟 页面级角色隔离：默认仅授课教师可建群；助教需教师开启建群权限
    if (!canCreateGroup()) {
      promptAction.showToast({ message: '当前身份无新建班级群权限' })
      router.back()
      return
    }
    this.useMain = !this.hasMain()
    this.selected = this.students().slice()
    // 子分组群默认名提示
    if (!this.useMain) {
      this.groupName = ''
    }
  }

  hasMain(): boolean {
    return this.groups.some((g: ChatGroup) => g.isMain && !g.dissolved)
  }

  students(): string[] {
    let names: string[] = []
    groupMembers().forEach((m: GroupMember) => {
      if (m.role !== 'teacher') {
        names.push(m.name)
      }
    })
    return names
  }

  filteredStudents(): string[] {
    let key = this.search.trim()
    if (key === '') {
      return this.students()
    }
    return this.students().filter((n: string) => n.indexOf(key) >= 0)
  }

  isPicked(name: string): boolean {
    return this.selected.indexOf(name) >= 0
  }

  toggle(name: string): void {
    if (this.isPicked(name)) {
      this.selected = this.selected.filter((n: string) => n !== name)
    } else {
      this.selected = this.selected.concat([name])
    }
  }

  create(): void {
    let name = this.groupName.trim()
    if (name === '') {
      promptAction.showToast({ message: '请输入群名称' })
      return
    }
    if (this.selected.length === 0) {
      promptAction.showToast({ message: '请至少选择 1 名班级成员' })
      return
    }
    let gid = this.useMain ? MAIN_GROUP_ID : `g_${Date.now()}`
    let creator = currentName()
    let g = new ChatGroup(gid, name, this.useMain, creator)
    g.courseName = GROUP_COURSE_NAME
    g.teacherName = MAIN_TEACHER
    g.intro = this.useMain ? '本课程主班级群' : '主群衍生的子分组群'

    // 群成员：授课教师 + 创建者（非教师时按助教/学生身份）+ 选中学生
    let list: GroupMember[] = []
    let hasTeacher = false
    if (creator === MAIN_TEACHER) {
      list.push(new GroupMember(MAIN_TEACHER, 'teacher'))
      hasTeacher = true
    } else {
      list.push(new GroupMember(MAIN_TEACHER, 'teacher'))
      let creatorRole = currentRole()
      list.push(new GroupMember(creator, creatorRole === 'assistant' ? 'assistant'
        : creatorRole === 'teacher' ? 'teacher' : 'student'))
      hasTeacher = true
    }
    if (hasTeacher) {
      this.selected.forEach((n: string) => {
        if (n !== creator) {
          list.push(new GroupMember(n, 'student'))
        }
      })
    }

    // 写入群列表与成员表
    let nextGroups = this.groups.slice()
    if (this.useMain) {
      nextGroups = nextGroups.filter((x: ChatGroup) => !x.isMain)
    }
    nextGroups.push(g)
    AppStorage.setOrCreate('chatGroups', nextGroups)
    this.groups = nextGroups

    let map: Record<string, GroupMember[]> = {}
    Object.keys(this.memberMap).forEach((k: string) => {
      map[k] = this.memberMap[k]
    })
    map[gid] = list
    AppStorage.setOrCreate('groupMembersMap', map)
    this.memberMap = map

    // 建群通知（本地模拟推送）
    notifyGroup(gid, `群聊「${name}」已创建，共 ${list.length} 名成员。`, creator)
    promptAction.showToast({ message: '群聊创建成功' })
    router.back()
  }

  @Builder
  studentRow(name: string) {
    Row({ space: 10 }) {
      Text(this.isPicked(name) ? '☑' : '☐')
        .fontSize(20).fontColor(this.isPicked(name) ? '#3F7EF6' : $r('app.color.text_hint'))
        .width(24).textAlign(TextAlign.Center)
      Text(name.substring(0, 1))
        .fontSize(12).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .width(30).height(30).borderRadius(15).textAlign(TextAlign.Center)
        .backgroundColor('#4C8BF5')
      Text(name).fontSize(14).fontColor($r('app.color.text_main')).layoutWeight(1)
      Text('学生').fontSize(10).fontColor($r('app.color.text_sub'))
    }
    .width('100%').height(48).padding({ left: 12, right: 12 })
    .onClick(() => this.toggle(name))
  }

  @Builder
  noPermission() {
    Column({ space: 12 }) {
      Text('🔒').fontSize(40)
      Text('暂无建群权限').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      Text(this.userRole === 'assistant'
        ? '助教建群权限尚未开启，请联系授课教师在「群设置 - 权限管理」中开启。'
        : '仅授课教师可新建班级群。')
        .fontSize(12).fontColor($r('app.color.text_sub')).textAlign(TextAlign.Center).lineHeight(20)
      Text('返回')
        .fontSize(13).fontColor(Color.White)
        .padding({ left: 20, right: 20, top: 9, bottom: 9 })
        .backgroundColor($r('app.color.primary')).borderRadius(18)
        .onClick(() => router.back())
    }
    .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20).fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Text('新建班级群').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          .layoutWeight(1)
        if (canCreateGroup()) {
          Text('创建')
            .fontSize(14).fontWeight(FontWeight.Medium).fontColor(Color.White)
            .padding({ left: 16, right: 16, top: 7, bottom: 7 })
            .backgroundColor($r('app.color.primary')).borderRadius(16)
            .onClick(() => this.create())
        }
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.card_bg'))

      if (!canCreateGroup()) {
        this.noPermission()
      } else {
        Scroll() {
          Column() {
            // 群类型
            Text('群类型').fontSize(12).fontColor($r('app.color.text_hint'))
              .width('90%').padding({ left: 4, top: 14, bottom: 6 })
            Row({ space: 10 }) {
              Text(`主班级群${this.hasMain() ? '（已有）' : ''}`)
                .fontSize(13)
                .fontColor(this.useMain ? Color.White : $r('app.color.text_sub'))
                .backgroundColor(this.useMain ? '#3F7EF6' : $r('app.color.field_bg'))
                .padding({ left: 12, right: 12, top: 8, bottom: 8 }).borderRadius(16)
                .opacity(this.hasMain() ? 0.5 : 1)
                .onClick(() => {
                  if (this.hasMain()) {
                    promptAction.showToast({ message: '一门课程仅可绑定一个主班级群' })
                    return
                  }
                  this.useMain = true
                })
              Text('子分组群')
                .fontSize(13)
                .fontColor(!this.useMain ? Color.White : $r('app.color.text_sub'))
                .backgroundColor(!this.useMain ? '#8B5CF6' : $r('app.color.field_bg'))
                .padding({ left: 12, right: 12, top: 8, bottom: 8 }).borderRadius(16)
                .onClick(() => {
                  if (this.hasMain()) {
                    this.useMain = false
                  } else {
                    this.useMain = false
                  }
                })
            }.width('90%')

            // 群名称
            Text('群名称').fontSize(12).fontColor($r('app.color.text_hint'))
              .width('90%').padding({ left: 4, top: 16, bottom: 6 })
            TextInput({ text: this.groupName, placeholder: this.useMain ? '如：数据结构与算法 · 班级群' : '如：算法攻坚小组' })
              .height(44).fontSize(14)
              .backgroundColor($r('app.color.card_bg')).borderRadius(12)
              .padding({ left: 12, right: 12 })
              .onChange((v: string) => {
                this.groupName = v
              })

            // 课程信息（固定绑定当前课程）
            Row({ space: 8 }) {
              Text('📚').fontSize(14)
              Text(`绑定课程：${GROUP_COURSE_NAME}`).fontSize(12).fontColor($r('app.color.text_sub'))
              Blank()
              Text('自动').fontSize(10).fontColor($r('app.color.primary'))
            }
            .width('90%').padding(12).margin({ top: 12 })
            .backgroundColor($r('app.color.card_bg')).borderRadius(12)

            // 成员
            Row() {
              Text('群成员').fontSize(12).fontColor($r('app.color.text_hint'))
              Blank()
              Text(`已选 ${this.selected.length + 1} 人（含授课教师）`).fontSize(10).fontColor($r('app.color.text_hint'))
            }.width('90%').padding({ left: 4, top: 18, bottom: 6 })

            Row({ space: 8 }) {
              Text('👩‍🏫').fontSize(16)
              Column({ space: 2 }) {
                Text(MAIN_TEACHER).fontSize(14).fontColor($r('app.color.text_main'))
                Text('授课教师（自动加入，群主候选）').fontSize(10).fontColor($r('app.color.text_hint'))
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text('必选').fontSize(10).fontColor('#E8A33E')
            }
            .width('90%').padding(12)
            .backgroundColor($r('app.color.card_bg')).borderRadius(12)

            TextInput({ placeholder: '搜索班级成员', text: this.search })
              .height(36).fontSize(13)
              .backgroundColor($r('app.color.field_bg')).borderRadius(18)
              .padding({ left: 14, right: 14 })
              .margin({ top: 12, bottom: 8 })
              .onChange((v: string) => {
                this.search = v
              })

            Column() {
              ForEach(this.filteredStudents(), (n: string) => {
                this.studentRow(n)
              }, (n: string) => n)
            }
            .width('90%').backgroundColor($r('app.color.card_bg')).borderRadius(12)
            .padding({ top: 4, bottom: 4 })

            Text('说明：建群与成员变更为本地模拟；助教建群需授课教师授权。')
              .fontSize(10).fontColor($r('app.color.text_hint'))
              .width('90%').padding({ top: 12, left: 4, bottom: 40 })
          }.width('100%')
        }
        .layoutWeight(1).align(Alignment.Top).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
