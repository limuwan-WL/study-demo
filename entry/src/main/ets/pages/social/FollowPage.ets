import router from '@ohos.router'
import { promptAction } from '@kit.ArkUI'
import { FollowItem, FollowType, Teacher, NoteItem, defaultFollows, normalizeFollows, formatUpdateTime } from '../../model/DataModel'

const FILTER_ALL: string = 'all'
const SORT_UPDATE: string = 'update'
const SORT_FOLLOW: string = 'follow'

function typeLabel(t: FollowType): string {
  switch (t) {
    case 'teacher': return '教师'
    case 'course': return '课程'
    case 'note': return '公开笔记'
    case 'activity': return '活动'
  }
}

function chipLabel(key: string): string {
  return key === FILTER_ALL ? '全部' : typeLabel(key as FollowType)
}

@Entry
@Component
export struct FollowPage {
  @StorageLink('followItems') followList: FollowItem[] = []
  // 🌟 与讲师主页共用关注状态：取消关注教师时同步主页按钮
  @StorageLink('teacherList') teachers: Teacher[] = []
  @StorageLink('followSeeded') followSeeded: boolean = false
  // 🌟 公开笔记类关注的跳转兜底：按标题在当前笔记中定位
  @StorageLink('noteList') noteList: NoteItem[] = []
  @State filter: string = FILTER_ALL
  @State keyword: string = ''
  // 🌟 默认按内容最新更新排序，可切换为按关注时间排序
  @State sortMode: string = SORT_UPDATE

  aboutToAppear() {
    if (!this.followSeeded) {
      if (this.followList.length === 0) {
        this.followList = defaultFollows()
      } else {
        // 老版本只存了标题与更新时间文案，这里补齐排序用时间戳
        this.followList = normalizeFollows(this.followList)
      }
      this.followSeeded = true
    }
  }

  // 搜索与分类均只作用于已关注内容，不会检索全站未关注资源
  visibleList(): FollowItem[] {
    const kw: string = this.keyword.trim().toLowerCase()
    let list: FollowItem[] = this.followList.filter((f: FollowItem) => {
      if (this.filter !== FILTER_ALL && f.type !== this.filter) {
        return false
      }
      if (kw === '') {
        return true
      }
      return f.title.toLowerCase().indexOf(kw) >= 0 || typeLabel(f.type).indexOf(kw) >= 0
    })
    list = list.slice().sort((a: FollowItem, b: FollowItem) => {
      return this.sortMode === SORT_FOLLOW ? b.followedAt - a.followedAt : b.updatedAt - a.updatedAt
    })
    return list
  }

  typeColor(t: FollowType): string {
    switch (t) {
      case 'teacher': return '#3F7EF6'
      case 'course': return '#10B981'
      case 'note': return '#8B5CF6'
      case 'activity': return '#F59E0B'
    }
  }

  // 点击已关注项：先清除红点，再按类型跳转到对应详情
  openItem(f: FollowItem) {
    if (f.hasNew) {
      f.hasNew = false
      this.followList = this.followList.slice()
    }
    let target = f.targetType === '' ? f.type : f.targetType
    if (target === 'teacher') {
      if (f.targetId === '') {
        promptAction.showToast({ message: '该教师主页暂不可用' })
        return
      }
      router.pushUrl({ url: 'pages/course/TeacherPage', params: { teacherId: f.targetId } })
      return
    }
    if (target === 'course') {
      if (f.targetId === '') {
        promptAction.showToast({ message: '该课程已下架' })
        return
      }
      router.pushUrl({
        url: 'pages/course/SubjectDetailPage',
        params: { subjectId: f.targetId, title: f.title }
      })
      return
    }
    if (target === 'note') {
      let noteId = f.targetId
      if (noteId === '') {
        // 历史关注数据没有 targetId：按标题匹配当前笔记
        let hit = this.noteList.filter((n: NoteItem) => !n.isDeleted && n.title === f.title)
        noteId = hit.length > 0 ? hit[0].id : ''
      }
      if (noteId === '') {
        promptAction.showToast({ message: '笔记已删除或不可访问' })
        return
      }
      router.pushUrl({ url: 'pages/study/NoteDetailPage', params: { id: noteId } })
      return
    }
    promptAction.showToast({ message: '活动详情暂未开放' })
  }

  // 快速取消关注：一步移除，失败无从谈起，直接给出反馈
  unfollow(f: FollowItem) {
    this.followList = this.followList.filter((x: FollowItem) => x.id !== f.id)
    // 🌟 教师类关注同步回讲师主页，避免两处关注状态不一致
    if (f.type === 'teacher') {
      let name = f.title.split(' · ')[0]
      let hit = this.teachers.filter((t: Teacher) => t.name === name && t.followed)
      if (hit.length > 0) {
        hit.forEach((t: Teacher) => {
          t.followed = false
          t.followers = Math.max(0, t.followers - 1)
        })
        this.teachers = this.teachers.slice()
      }
    }
    promptAction.showToast({ message: `已取消关注「${f.title}」` })
  }

  @Builder
  emptyTip(title: string, sub: string) {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.inbox')).fontSize(40).fontColor([$r('app.color.text_hint')])
      Text(title).fontSize(14).fontColor($r('app.color.text_sub'))
      if (sub !== '') {
        Text(sub).fontSize(12).fontColor($r('app.color.text_hint'))
      }
    }.width('100%').padding({ top: 70 })
  }

  @Builder
  followCard(f: FollowItem) {
    Row({ space: 10 }) {
      Row({ space: 12 }) {
        Text(f.cover).fontSize(26).width(52).height(52).textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.field_bg')).borderRadius(12)

        Column({ space: 5 }) {
          Row() {
            Text(f.title).fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_main')).layoutWeight(1)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            // 有新增内容时展示红点
            if (f.hasNew) {
              Circle().width(8).height(8).fill($r('app.color.danger')).margin({ left: 6 })
            }
          }.width('100%')

          Row({ space: 6 }) {
            Text(typeLabel(f.type)).fontSize(10).fontColor(Color.White)
              .backgroundColor(this.typeColor(f.type))
              .padding({ left: 6, right: 6, top: 1, bottom: 1 }).borderRadius(5)
            Text(`更新于 ${formatUpdateTime(f.updatedAt)}`)
              .fontSize(11).fontColor($r('app.color.text_hint'))
              .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.width('100%')

          if (this.sortMode === SORT_FOLLOW) {
            Text(`关注于 ${formatUpdateTime(f.followedAt)}`).fontSize(11).fontColor($r('app.color.text_hint'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .layoutWeight(1)
      .onClick(() => this.openItem(f))

      Text('取消关注').fontSize(11).fontColor($r('app.color.text_sub'))
        .backgroundColor($r('app.color.field_bg'))
        .padding({ left: 10, right: 10, top: 6, bottom: 6 }).borderRadius(12)
        .onClick(() => this.unfollow(f))
    }
    .width('100%').padding(12).backgroundColor($r('app.color.card_bg')).borderRadius(12)
  }

  build() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24)
          .fontColor([$r('app.color.text_main')]).onClick(() => router.back())
        Text('我的关注').fontSize(20).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_main')).margin({ left: 12 })
        Blank()
        Text(`${this.followList.length} 个关注`).fontSize(12).fontColor($r('app.color.text_hint'))
      }
      .width('100%').height(60).padding({ left: 16, right: 16 })

      // 顶端搜索：仅在已关注内容里检索，结果直接展示在输入框下方
      TextInput({ placeholder: '搜索已关注的教师、课程、笔记、活动', text: $$this.keyword })
        .width('92%').height(40).backgroundColor($r('app.color.field_bg')).borderRadius(20)
        .placeholderColor($r('app.color.text_hint'))
        .fontColor($r('app.color.text_main'))
        .fontSize(13)

      if (this.keyword.trim() !== '') {
        Row() {
          Text(`在已关注内容中匹配 ${this.visibleList().length} 条`)
            .fontSize(12).fontColor($r('app.color.text_hint'))
          Blank()
          Text('清除').fontSize(12).fontColor($r('app.color.primary'))
            .onClick(() => { this.keyword = '' })
        }
        .width('92%').margin({ top: 8 })
      }

      // 分类筛选标签
      Scroll() {
        Row({ space: 8 }) {
          ForEach([FILTER_ALL, 'teacher', 'course', 'note', 'activity'], (f: string) => {
            Text(chipLabel(f))
              .fontSize(13)
              .fontWeight(this.filter === f ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.filter === f ? Color.White : $r('app.color.text_main'))
              .backgroundColor(this.filter === f ? '#3F7EF6' : $r('app.color.field_bg'))
              .padding({ left: 14, right: 14, top: 6, bottom: 6 }).borderRadius(14)
              .onClick(() => { this.filter = f })
          }, (f: string) => f)
        }.padding({ left: 16, right: 16 })
      }
      .scrollBar(BarState.Off)
      .margin({ top: 10, bottom: 8 })

      // 排序方式：默认最近更新，可切换为关注时间
      Row() {
        Text(`共 ${this.visibleList().length} 个`).fontSize(12).fontColor($r('app.color.text_hint'))
        Blank()
        Row({ space: 0 }) {
          ForEach([SORT_UPDATE, SORT_FOLLOW], (m: string) => {
            Text(m === SORT_UPDATE ? '最近更新' : '关注时间')
              .fontSize(12)
              .fontWeight(this.sortMode === m ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.sortMode === m ? Color.White : $r('app.color.text_sub'))
              .backgroundColor(this.sortMode === m ? '#3F7EF6' : Color.Transparent)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 }).borderRadius(11)
              .onClick(() => { this.sortMode = m })
          }, (m: string) => m)
        }
        .padding(2)
        .backgroundColor($r('app.color.field_bg'))
        .borderRadius(13)
      }
      .width('92%')
      .margin({ bottom: 8 })

      List({ space: 10 }) {
        ForEach(this.visibleList(), (f: FollowItem) => {
          ListItem() {
            this.followCard(f)
          }
        }, (f: FollowItem) => `${f.id}_${f.hasNew}`)
        if (this.visibleList().length === 0) {
          ListItem() {
            if (this.keyword.trim() !== '') {
              this.emptyTip('未找到相关关注内容', '仅搜索已关注内容，试试其他关键词')
            } else {
              this.emptyTip('暂无关注内容', '关注教师、课程、笔记或活动后会出现在这里')
            }
          }
        }
      }.width('92%').layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }
}
