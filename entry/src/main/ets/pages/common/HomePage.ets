import router from '@ohos.router';
import { BusinessError } from '@kit.BasicServicesKit';
import { TodoItem, ScheduleItem, NoteItem, FavItem, sortSchedule } from '../../model/DataModel';
import { CourseItem, todayWeekday, weekdayName, timeToMinutes } from '../../model/TimetableModel';
import { Permission } from '../../model/PermissionModel';

@Component
export struct HomePage {
  @State searchText: string = ''
  // 🌟 直接绑定数据列表：任何页面增删改后，回到首页统计自动同步
  @StorageLink('todoList') todoList: TodoItem[] = []
  @StorageLink('scheduleList') scheduleList: ScheduleItem[] = []
  @StorageLink('noteList') noteList: NoteItem[] = []
  @StorageLink('favList') favList: FavItem[] = []
  @StorageLink('courseTable') courseTable: CourseItem[] = []
  // 🌟 昵称：首页问候语跟随「我的」页修改实时变化
  @StorageLink('nickname') nickname: string = '张同学'

  // 🌟 卡片副标题在 @Builder 内部按类型直接读取列表（不能把算好的字符串按值传进 @Builder，否则数据变化后不刷新）
  @Builder
  cardDetail(type: string) {
    if (type === 'todo') {
      Text(`${this.todoList.filter((t: TodoItem) => !t.isDone).length} 项待完成`)
        .fontSize(12).fontColor($r('app.color.text_sub')).width('100%').margin({ top: 16, left: 4 })
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    } else if (type === 'schedule') {
      Text(this.scheduleSummary())
        .fontSize(12).fontColor($r('app.color.text_sub')).width('100%').margin({ top: 16, left: 4 })
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    } else if (type === 'note') {
      Text(this.noteSummary())
        .fontSize(12).fontColor($r('app.color.text_sub')).width('100%').margin({ top: 16, left: 4 })
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    } else {
      Text(`${this.favList.length} 个收藏`)
        .fontSize(12).fontColor($r('app.color.text_sub')).width('100%').margin({ top: 16, left: 4 })
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
  }

  scheduleSummary(): string {
    let sorted = sortSchedule(this.scheduleList)
    return sorted.length > 0 ? `${sorted[0].date.slice(5)} ${sorted[0].time} ${sorted[0].content}` : '无安排'
  }

  noteSummary(): string {
    let active = this.noteList.filter((n: NoteItem) => !n.isDeleted)
    return active.length > 0 ? `最近: ${active[0].title}` : '暂无笔记，点击进入新建'
  }

  // 🌟 课程卡片副标题：无课表时引导导入；有课表时展示今日课程
  courseSummary(): string {
    if (this.courseTable.length === 0) {
      return '导入课表文件，查看你的课程安排'
    }
    let today = todayWeekday()
    let todays = this.courseTable.filter((c: CourseItem) => c.dayOfWeek === today)
      .sort((a: CourseItem, b: CourseItem) => timeToMinutes(a.startTime) - timeToMinutes(b.startTime))
    if (todays.length === 0) {
      return `本周共 ${this.courseTable.length} 门课，今日（${weekdayName(today)}）无课`
    }
    return `今日 ${todays.length} 门课 · ${todays[0].startTime} ${todays[0].name}`
  }

  // 🌟 首页问候：按时间与身份变化，替代固定文案
  greeting(): string {
    let h = new Date().getHours()
    let period = h < 6 ? '夜深了' : h < 12 ? '早上好' : h < 14 ? '中午好' : h < 18 ? '下午好' : '晚上好'
    return `${period}，${this.nickname}`
  }

  // 🌟 日期副标题：日期 + 身份对应的行动引导
  todayLine(): string {
    let d = new Date()
    let action = Permission.isStudent() ? '开启今天的学习计划吧' : '看看今天的教学安排吧'
    return `${d.getMonth() + 1}月${d.getDate()}日 ${weekdayName(todayWeekday())} · ${action}`
  }

  build() {
    Column() {
      Column() {
        Text(this.greeting()).fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main')).margin({ bottom: 4 })
        Text(this.todayLine()).fontSize(13).fontColor($r('app.color.text_sub'))
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, top: 30, bottom: 20 })

      // 点击进入全局搜索页（同时检索待办 / 笔记 / 收藏 / 帖子）
      Search({ value: this.searchText, placeholder: '搜索功能 / 内容' })
        .width('90%').height(40).backgroundColor($r('app.color.card_bg'))
        .placeholderColor($r('app.color.text_sub')).placeholderFont({ size: 14 }).textFont({ size: 14 })
        .margin({ bottom: 20 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/social/SearchPage' }).catch((err: BusinessError) => {
            console.error('跳转失败');
          })
        })

      Column({ space: 16 }) {
        Row({ space: 16 }) {
          this.gridCard('待', '待办事项', '#3F7EF6', 'todo', 'pages/study/TodoPage')
          this.gridCard('日', '日程安排', '#55C873', 'schedule', 'pages/study/SchedulePage')
        }
        Row({ space: 16 }) {
          this.gridCard('我', '我的笔记', '#E8A33E', 'note', 'pages/study/NotePage')
          this.gridCard('收', '收藏夹', '#E74846', 'fav', 'pages/study/FavoritesPage')
        }
        // 🌟 课程卡片：进入课程表（默认本周视图，可切换本月视图）
        this.courseCard()
        // 🌟 学科课程已移至底部导航「课程」页
      }.width('90%')
      Blank()
    }.width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }

  @Builder
  courseCard() {
    Row() {
      Text('课').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .width(36).height(36).backgroundColor('#14B8A6').borderRadius(10).textAlign(TextAlign.Center)
      Column({ space: 4 }) {
        Text('课程表').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
        Text(this.courseSummary()).fontSize(12).fontColor($r('app.color.text_sub'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.text_hint')])
    }
    .width('100%').height(68).padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_bg')).borderRadius(16)
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 5 })
    .onClick(() => {
      router.pushUrl({ url: 'pages/study/CourseTablePage' }).catch((err: BusinessError) => { console.error('跳转失败'); })
    })
  }

  @Builder
  gridCard(iconText: string, title: string, bgColor: string, type: string, targetUrl: string) {
    Column() {
      Row() {
        Text(iconText).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .width(36).height(36).backgroundColor(bgColor).borderRadius(10).textAlign(TextAlign.Center)
        Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main')).margin({ left: 10 })
      }.width('100%').alignItems(VerticalAlign.Center)

      this.cardDetail(type)
    }
    .width('47%').height(110).backgroundColor($r('app.color.card_bg')).borderRadius(16).padding(16)
    .justifyContent(FlexAlign.Center).shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 5 })
    .onClick(() => {
      router.pushUrl({ url: targetUrl }).catch((err: BusinessError) => { console.error('跳转失败'); })
    })
  }
}
