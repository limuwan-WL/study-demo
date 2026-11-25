import router from '@ohos.router'
import { SUBJECTS, SubjectConfig, stageName } from '../../model/SubjectModel'
import { Permission, AssistantInfo } from '../../model/PermissionModel'
import { TeacherCourse } from '../../model/DataModel'
import { Feedback } from '../../utils/Feedback'
import { EmptyState } from '../../components/StatusViews'

// ==================== 我的课程 / 我教授的课程 ====================
// 🌟 学生：已加入课程 + 可加入课程；教师：自己授课的课程；助教：被分配的课程
@Entry
@Component
export struct MyCoursesPage {
  @StorageLink('enrolledCourses') enrolled: string[] = []

  subjectOf(id: string): SubjectConfig | undefined {
    return SUBJECTS.find((s: SubjectConfig) => s.id === id)
  }

  enrolledSubjects(): SubjectConfig[] {
    let list: SubjectConfig[] = []
    this.enrolled.forEach((id: string) => {
      let s = this.subjectOf(id)
      if (s !== undefined) {
        list.push(s)
      }
    })
    return list
  }

  joinableSubjects(): SubjectConfig[] {
    return SUBJECTS.filter((s: SubjectConfig) => this.enrolled.indexOf(s.id) < 0)
  }

  join(s: SubjectConfig): void {
    if (Permission.joinCourse(s.id)) {
      this.enrolled = Permission.enrolledCourses().slice()
      // 🌟 重新加入班级群所属课程时同步复位退出标记，避免群入口仍显示「已退出」
      if (s.id === 'csbasic') {
        AppStorage.setOrCreate('courseQuit', false)
      }
      Feedback.success(`已加入《${s.name}》，可访问课程页面与班级群`)
    } else {
      Feedback.fail('加入课程', '你已加入该课程')
    }
  }

  leave(s: SubjectConfig): void {
    Feedback.confirm('退出课程', `退出《${s.name}》后，将无法访问课程页面、班级群与课程内笔记，且需重新加入。`, () => {
      if (Permission.leaveCourse(s.id)) {
        this.enrolled = Permission.enrolledCourses().slice()
        // 🌟 与班级群的退出状态保持一致，避免「已退课但仍可进群」
        if (s.id === 'csbasic') {
          AppStorage.setOrCreate('courseQuit', true)
        }
        Feedback.success(`已退出《${s.name}》`)
      } else {
        Feedback.fail('退出课程', '未找到该课程的加入记录')
      }
    }, '退出', true)
  }

  openSubject(id: string): void {
    let s = this.subjectOf(id)
    if (s === undefined) {
      Feedback.fail('进入课程', '课程资源暂未开放')
      return
    }
    if (!Permission.canAccessCourse(s.id)) {
      Feedback.fail('进入课程', Permission.courseDeniedReason(s.id))
      return
    }
    router.pushUrl({ url: s.page })
  }

  @Builder
  sectionTitle(title: string, desc: string) {
    Column({ space: 3 }) {
      Text(title).fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      if (desc !== '') {
        Text(desc).fontSize(11).fontColor($r('app.color.text_hint'))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ top: 4, bottom: 8 })
  }

  @Builder
  subjectCard(s: SubjectConfig, extra: string) {
    Row({ space: 12 }) {
      Text(s.name.slice(0, 1))
        .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .width(48).height(48).borderRadius(12)
        .textAlign(TextAlign.Center)
        .linearGradient({ angle: 135, colors: [[s.c1, 0], [s.c2, 1]] })
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(s.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
          Text(stageName(s.stage)).fontSize(9).fontColor($r('app.color.primary'))
            .backgroundColor($r('app.color.primary_weak'))
            .padding({ left: 5, right: 5, top: 1, bottom: 1 }).borderRadius(4)
        }
        Text(extra).fontSize(11).fontColor($r('app.color.text_hint'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('进入')
        .fontSize(12).fontColor(Color.White)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor($r('app.color.primary')).borderRadius(12)
        .onClick(() => this.openSubject(s.id))
      Text('退出')
        .fontSize(12).fontColor($r('app.color.text_sub'))
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor($r('app.color.field_bg')).borderRadius(12)
        .onClick(() => this.leave(s))
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(22)
          .fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Text(Permission.isStudent() ? '我的课程' : Permission.isAssistant() ? '协助课程' : '我教授的课程')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Text(Permission.roleShortLabel()).fontSize(10).fontColor(Color.White)
          .backgroundColor(Permission.roleColor())
          .padding({ left: 7, right: 7, top: 2, bottom: 2 }).borderRadius(6)
      }
      .width('92%')
      .padding({ top: 16, bottom: 10 })

      Scroll() {
        Column({ space: 10 }) {
          if (Permission.isStudent()) {
            // 学生：已加入课程
            this.sectionTitle('已加入课程', '只有已加入的课程才能访问课程页面与班级群')
            if (this.enrolledSubjects().length === 0) {
              EmptyState({
                icon: $r('sys.symbol.inbox'),
                title: '还没有加入任何课程',
                desc: '从下方课程库加入后，即可学习课程、进入班级群并查看课程笔记',
                actionLabel: '浏览课程库',
                onAction: () => {
                  Feedback.info('请在下方「可加入课程」中选择并加入')
                }
              })
            } else {
              ForEach(this.enrolledSubjects(), (s: SubjectConfig) => {
                this.subjectCard(s, `已加入 · ${s.topics.length > 0 ? s.topics[0] : '课程内容'}`)
              }, (s: SubjectConfig) => s.id)
            }

            // 学生：可加入课程
            this.sectionTitle('可加入课程', '加入后自动获得该课程的学习与群聊权限')
            ForEach(this.joinableSubjects(), (s: SubjectConfig) => {
              Row({ space: 12 }) {
                Text(s.name.slice(0, 1))
                  .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
                  .width(40).height(40).borderRadius(10)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(s.c1)
                Column({ space: 3 }) {
                  Text(s.name).fontSize(14).fontColor($r('app.color.text_main'))
                  Text(`${stageName(s.stage)} · ${s.topics.length} 个专题`)
                    .fontSize(10).fontColor($r('app.color.text_hint'))
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text('加入')
                  .fontSize(12).fontColor($r('app.color.primary'))
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor($r('app.color.primary_weak')).borderRadius(12)
                  .onClick(() => this.join(s))
              }
              .width('100%').padding(12)
              .backgroundColor($r('app.color.card_bg')).borderRadius(14)
            }, (s: SubjectConfig) => `join_${s.id}`)
          } else if (Permission.isTeacher()) {
            this.sectionTitle('我教授的课程', '教师仅能查看自己授课课程内的学生数据，不能跨课程获取其他班级信息')
            if (Permission.myTeachingCourses().length === 0) {
              EmptyState({
                icon: $r('sys.symbol.inbox'),
                title: '暂无授课课程',
                desc: '课程基础配置由后台管理员分配，分配后会展示在这里'
              })
            } else {
              ForEach(Permission.myTeachingCourses(), (c: TeacherCourse) => {
                Row({ space: 12 }) {
                  Text(c.name.slice(0, 1))
                    .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White)
                    .width(48).height(48).borderRadius(12).textAlign(TextAlign.Center)
                    .backgroundColor('#4A5A6E')
                  Column({ space: 4 }) {
                    Text(c.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                    Text('授课教师 · 可管理签到、作业与助教').fontSize(10).fontColor($r('app.color.text_hint'))
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Text('课程')
                    .fontSize(12).fontColor($r('app.color.primary'))
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .backgroundColor($r('app.color.primary_weak')).borderRadius(12)
                    .onClick(() => {
                      if (c.url !== '') {
                        router.pushUrl({ url: c.url })
                      } else {
                        this.openSubject(c.subjectId)
                      }
                    })
                  Text('名册')
                    .fontSize(12).fontColor($r('app.color.text_sub'))
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .backgroundColor($r('app.color.field_bg')).borderRadius(12)
                    .onClick(() => {
                      if (Permission.canViewStudents(c.subjectId)) {
                        router.pushUrl({ url: 'pages/study/DataViewPage' })
                      } else {
                        Feedback.fail('查看名册', '该课程不在你的授课范围内')
                      }
                    })
                }
                .width('100%').padding(12)
                .backgroundColor($r('app.color.card_bg')).borderRadius(14)
              }, (c: TeacherCourse) => c.id)
            }
          } else if (Permission.isAssistant()) {
            this.sectionTitle('协助课程', '助教由主讲教师添加，可发布签到、查看台账、批阅作业、维护群公告')
            if (Permission.assistantCourses().length === 0) {
              EmptyState({
                icon: $r('sys.symbol.inbox'),
                title: '暂未被分配课程',
                desc: '请联系主讲教师，在「助教管理」中添加你并分配课程'
              })
            } else {
              ForEach(Permission.assistantCourses(), (a: AssistantInfo) => {
                Row({ space: 12 }) {
                  Text(a.courseName.slice(0, 1))
                    .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White)
                    .width(48).height(48).borderRadius(12).textAlign(TextAlign.Center)
                    .backgroundColor('#8B5CF6')
                  Column({ space: 4 }) {
                    Text(a.courseName).fontSize(15).fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_main'))
                    Text('助教 · 不可修改课程配置 / 学分规则 / 删除课程')
                      .fontSize(10).fontColor($r('app.color.text_hint'))
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Text('进入')
                    .fontSize(12).fontColor(Color.White)
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .backgroundColor('#8B5CF6').borderRadius(12)
                    .onClick(() => this.openSubject(a.courseKey))
                }
                .width('100%').padding(12)
                .backgroundColor($r('app.color.card_bg')).borderRadius(14)
              }, (a: AssistantInfo) => `${a.name}_${a.courseKey}`)
            }
          }
        }
        .width('92%')
        .padding({ top: 2, bottom: 30 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
