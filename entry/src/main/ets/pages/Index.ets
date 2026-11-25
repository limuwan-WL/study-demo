import router from '@ohos.router';
import { MessageItem, PostItem, unreadPostCount } from '../model/DataModel';
import { ensureStudentCourses } from '../model/TimetableModel';
import { Permission } from '../model/PermissionModel';
import { HomePage } from './common/HomePage';
import { MinePage } from './common/MinePage';
import { CoursePage } from './course/CoursePage';
import { DiscoverPage } from './social/DiscoverPage';
import { MessagePage } from './social/MessagePage';


@Entry
@Component
struct Index {
  private tabsController: TabsController = new TabsController()
  @State currentIndex: number = 0
  // 🌟 发现页红点 = 尚未查看过的帖子数，查看详情 / 一键已读后自动减少
  @StorageLink('postList') postList: PostItem[] = []
  @StorageLink('readPostIds') readPostIds: string[] = []
  @StorageLink('nickname') nickname: string = ''
  // 🌟 消息页红点 = 未读消息总数，读完自动清零
  @StorageLink('messageList') messageList: MessageItem[] = []
  // 🌟 登录态：未完成身份验证时不允许停留在主界面
  @StorageLink('isLogged') isLogged: boolean = false

  onPageShow() {
    // 🌟 兜底拦截：任何绕过登录页直接回到主页的路径都会被送回身份验证页
    if (!this.isLogged) {
      router.replaceUrl({ url: 'pages/common/LoginPage' })
      return
    }
    // 🌟 学生端进入主界面时，若还没有课表则自动生成一份
    if (Permission.isStudent()) {
      ensureStudentCourses()
    }
  }

  unreadCount(): number {
    return this.messageList.filter((m: MessageItem) => !m.isRead).length
  }

  newPostCount(): number {
    return unreadPostCount(this.postList, this.readPostIds, this.nickname)
  }

  // 🌟 底栏对齐：图标始终是 Stack 里唯一定尺寸子组件，红点改为悬浮角标，不再挤动图标位置
  @Builder
  tabBuilder(index: number, title: string, icon: Resource) {
    Column({ space: 4 }) {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph(icon).fontSize(24).fontWeight(FontWeight.Medium).fontColor([this.currentIndex === index ? '#3F7EF6' : $r('app.color.text_sub')])
        // 🌟 课程 Tab（index 1），发现页红点顺延到 index 2，消息页红点顺延到 index 3
        if (index === 2 && this.newPostCount() > 0) {
          Text(this.newPostCount() > 99 ? '99+' : `${this.newPostCount()}`)
            .fontSize(9).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .height(14).padding({ left: 4, right: 4 })
            .borderRadius(7).backgroundColor('#EF4444')
            .textAlign(TextAlign.Center)
            .offset({ x: 11, y: -7 })
        }
        if (index === 3 && this.unreadCount() > 0) {
          Text(this.unreadCount() > 99 ? '99+' : `${this.unreadCount()}`)
            .fontSize(9).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .height(14).padding({ left: 4, right: 4 })
            .borderRadius(7).backgroundColor('#EF4444')
            .textAlign(TextAlign.Center)
            .offset({ x: 11, y: -7 })
        }
      }.width(32).height(28)
      Text(title)
        .fontSize(11).lineHeight(14)
        .fontColor(this.currentIndex === index ? '#3F7EF6' : $r('app.color.text_sub'))
    }.width('100%').height(56).justifyContent(FlexAlign.Center)
    .onClick(() => { this.currentIndex = index; this.tabsController.changeIndex(index) })
  }

  build() {
    Tabs({ barPosition: BarPosition.End, controller: this.tabsController, index: this.currentIndex }) {
      TabContent() { HomePage() }.tabBar(this.tabBuilder(0, '首页', $r('sys.symbol.house')))
      TabContent() { CoursePage() }.tabBar(this.tabBuilder(1, '课程', $r('sys.symbol.graduationcap')))
      TabContent() { DiscoverPage() }.tabBar(this.tabBuilder(2, '发现', $r('sys.symbol.magnifyingglass')))
      TabContent() { MessagePage() }.tabBar(this.tabBuilder(3, '消息', $r('sys.symbol.message')))
      TabContent() { MinePage() }.tabBar(this.tabBuilder(4, '我的', $r('sys.symbol.person')))
    }
    .barMode(BarMode.Fixed).scrollable(false).barHeight(60)
    .onChange((index: number) => {
      this.currentIndex = index
      // 🌟 进入发现页不再清红点：查看帖子详情才逐个减 1，发现页支持「一键已读」
    })
    .backgroundColor($r('app.color.page_bg'))
  }
}
