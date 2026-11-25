import router from '@ohos.router'
import { Action, AssistantInfo, Permission, addAssistant, assistants, removeAssistant } from '../../model/PermissionModel'
import { TeacherCourse } from '../../model/DataModel'
import { Feedback } from '../../utils/Feedback'
import { EmptyState } from '../../components/StatusViews'

// ==================== 助教管理（仅主讲教师） ====================
// 🌟 助教由主讲教师添加；权限：发布签到、查看台账、批阅作业、维护群公告；
//    不可修改课程基础配置、调整学分规则、删除课程。
@Entry
@Component
export struct AssistantManagePage {
  @StorageLink('assistantList') assistantList: AssistantInfo[] = []
  @State name: string = ''
  @State courseKey: string = ''

  aboutToAppear(): void {
    // 🌟 页面级角色隔离：助教管理仅主讲教师可用，其余身份直接退回
    if (!Permission.isTeacher()) {
      Feedback.fail('进入助教管理', Permission.deniedReason(Action.ASSISTANT_MANAGE))
      router.back()
      return
    }
    this.assistantList = assistants().slice()
    let courses = Permission.myTeachingCourses()
    if (this.courseKey === '' && courses.length > 0) {
      this.courseKey = courses[0].subjectId
    }
  }

  refresh(): void {
    this.assistantList = assistants().slice()
  }

  add(): void {
    if (!Permission.hasAction(Action.ASSISTANT_MANAGE)) {
      Feedback.fail('添加助教', Permission.deniedReason(Action.ASSISTANT_MANAGE))
      return
    }
    let err = addAssistant(this.name, this.courseKey)
    if (err !== '') {
      Feedback.fail('添加助教', err)
      return
    }
    this.name = ''
    this.refresh()
    Feedback.success('助教已添加，已获得签到、台账、批阅与公告权限')
  }

  remove(a: AssistantInfo): void {
    Feedback.confirm('移除助教', `确定移除助教「${a.name}」吗？移除后其将失去《${a.courseName}》的协助权限。`, () => {
      if (removeAssistant(a.name, a.courseKey)) {
        this.refresh()
        Feedback.success('助教已移除')
      } else {
        Feedback.fail('移除助教', '未找到该助教记录')
      }
    }, '移除', true)
  }

  @Builder
  courseChip(c: TeacherCourse) {
    Text(c.name)
      .fontSize(12)
      .fontColor(this.courseKey === c.subjectId ? Color.White : $r('app.color.text_sub'))
      .backgroundColor(this.courseKey === c.subjectId ? $r('app.color.primary') : $r('app.color.field_bg'))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(12)
      .onClick(() => {
        this.courseKey = c.subjectId
      })
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(22)
          .fontColor([$r('app.color.text_main')])
          .onClick(() => router.back())
        Text('助教管理').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Text('仅主讲教师').fontSize(10).fontColor(Color.White)
          .backgroundColor('#E8A33E')
          .padding({ left: 7, right: 7, top: 2, bottom: 2 }).borderRadius(6)
      }
      .width('92%')
      .padding({ top: 16, bottom: 12 })

      if (!Permission.isTeacher()) {
        EmptyState({
          icon: $r('sys.symbol.lock'),
          title: '无权管理助教',
          desc: '只有主讲教师可以添加、移除助教并分配课程；助教与学生均无此权限',
          actionLabel: '返回',
          onAction: () => router.back()
        })
      } else {
        Scroll() {
          Column({ space: 12 }) {
            // 添加表单
            Column({ space: 10 }) {
              Text('添加助教').fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
              TextInput({ text: this.name, placeholder: '输入助教姓名 / 账号' })
                .height(42).fontSize(13).backgroundColor($r('app.color.field_bg')).borderRadius(10)
                .onChange((v: string) => {
                  this.name = v
                })
              Text('协助课程').fontSize(11).fontColor($r('app.color.text_hint'))
              if (Permission.myTeachingCourses().length === 0) {
                Text('暂无可分配的授课课程').fontSize(12).fontColor($r('app.color.text_hint'))
              } else {
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(Permission.myTeachingCourses(), (c: TeacherCourse) => {
                    Row() {
                      this.courseChip(c)
                    }.margin({ right: 8, bottom: 6 })
                  }, (c: TeacherCourse) => c.id)
                }
              }
              Text('添加助教')
                .fontSize(13).fontWeight(FontWeight.Medium).fontColor(Color.White)
                .width('100%').textAlign(TextAlign.Center).height(40)
                .backgroundColor($r('app.color.primary')).borderRadius(12)
                .onClick(() => this.add())
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(14)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(16)

            // 权限边界说明
            Column({ space: 6 }) {
              Text('助教权限范围').fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
              Text('可执行：发布签到任务 · 查看各类台账 · 批阅作业 · 维护群公告')
                .fontSize(11).fontColor('#047857')
              Text('不可执行：修改课程基础配置 · 调整学分规则 · 删除课程')
                .fontSize(11).fontColor('#B91C1C')
              Text('权限判断集中在 PermissionModel，各页面按钮会按角色自动隔离。')
                .fontSize(10).fontColor($r('app.color.text_hint'))
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(14)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(16)

            // 助教列表
            Text(`在岗助教（${this.assistantList.length}）`)
              .fontSize(12).fontColor($r('app.color.text_hint'))
              .width('100%').padding({ left: 4, top: 2 })

            if (this.assistantList.length === 0) {
              EmptyState({
                icon: $r('sys.symbol.inbox'),
                title: '还没有助教',
                desc: '在上方输入助教姓名并选择课程，即可添加协助教学的助教'
              })
            } else {
              ForEach(this.assistantList, (a: AssistantInfo) => {
                Column({ space: 8 }) {
                  Row({ space: 10 }) {
                    Text(a.name.slice(0, 1)).fontSize(15).fontWeight(FontWeight.Bold).fontColor(Color.White)
                      .width(40).height(40).borderRadius(20).textAlign(TextAlign.Center)
                      .backgroundColor('#8B5CF6')
                    Column({ space: 3 }) {
                      Text(a.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                      Text(`协助《${a.courseName}》 · 添加人：${a.addedBy}`)
                        .fontSize(10).fontColor($r('app.color.text_hint'))
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                    Text('移除').fontSize(11).fontColor($r('app.color.danger'))
                      .onClick(() => this.remove(a))
                  }.width('100%')
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(a.permissions, (p: string) => {
                      Text(p).fontSize(9).fontColor('#6D28D9')
                        .backgroundColor('#EDE9FE')
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .borderRadius(4)
                        .margin({ right: 6, bottom: 4 })
                    }, (p: string) => p)
                  }.width('100%')
                }
                .width('100%')
                .padding(12)
                .backgroundColor($r('app.color.card_bg'))
                .borderRadius(14)
              }, (a: AssistantInfo) => `${a.name}_${a.courseKey}`)
            }
          }
          .width('92%')
          .padding({ bottom: 30 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
