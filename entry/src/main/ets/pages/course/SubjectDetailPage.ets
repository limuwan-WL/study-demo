import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';
import { SubjectConfig, SubjectCourse, CourseChapter, subjectById, stageName, chaptersOf } from '../../model/SubjectModel';
import { biliSearch } from '../../model/LevelTraining';
import { Permission } from '../../model/PermissionModel';

// ==================== 学科课程详情页 ====================
// 按学科主题色渲染：头部信息卡 + 模块标签 + 章节列表 + 底部操作栏
// 🌟 访问控制统一由 Permission.canAccessCourse 负责；金币仅用于点赞/投币，不参与购买课程
@Entry
@Component
struct SubjectDetailPage {
  @State collected: boolean = false

  private cfg: SubjectConfig = subjectById('chinese')
  title: string = ''
  module: string = ''
  teacher: string = ''
  lessons: number = 0
  minutes: number = 0
  heat: number = 0
  tag: string = ''
  filter1: string = ''
  filter2: string = ''

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, string>;
    if (params && params['subjectId']) {
      this.cfg = subjectById(params['subjectId']);
      this.title = params['title'] !== undefined ? params['title'] : '';
      this.module = params['module'] !== undefined ? params['module'] : '';
      this.teacher = params['teacher'] !== undefined ? params['teacher'] : '';
      this.lessons = params['lessons'] !== undefined ? Number(params['lessons']) : 0;
      this.minutes = params['minutes'] !== undefined ? Number(params['minutes']) : 0;
      this.heat = params['heat'] !== undefined ? Number(params['heat']) : 0;
      this.tag = params['tag'] !== undefined ? params['tag'] : '';
      this.filter1 = params['filter1'] !== undefined ? params['filter1'] : '';
      this.filter2 = params['filter2'] !== undefined ? params['filter2'] : '';
      // 🌟 课程访问权限：未加入课程的学生 / 非授课教师统一拦截（权限集中在 Permission，页面不写死角色）
      if (!Permission.canAccessCourse(params['subjectId'])) {
        promptAction.showToast({ message: Permission.courseDeniedReason(params['subjectId']) });
        router.back();
        return;
      }
    }
  }

  // 🌟 已通过 Permission 选课校验，全部章节可直接观看

  build() {
    Column() {
      Scroll() {
        Column() {
          // 头部：学科主题渐变
          Column({ space: 10 }) {
            Row() {
              SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(22).fontColor([Color.White])
                .onClick(() => router.back())
              Blank()
              Text(stageName(this.cfg.stage)).fontSize(10).fontColor(Color.White)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor('#33FFFFFF').borderRadius(8)
            }.width('100%')

            Text(this.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
              .lineHeight(28)
            Row({ space: 8 }) {
              Text(this.module).fontSize(10).fontColor(Color.White)
                .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                .backgroundColor('#40FFFFFF').borderRadius(6)
              Text(this.tag).fontSize(10).fontColor(Color.White)
                .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                .backgroundColor(this.tag === '真题' ? '#EF4444' : '#E8A33E').borderRadius(6)
            }
            Text(`${this.filter1}${this.filter2 !== '' ? ' · ' + this.filter2 : ''} · ${this.cfg.name}`)
              .fontSize(11).fontColor('#FFFFFFCC')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 18, right: 18, top: 46, bottom: 20 })
          .linearGradient({ angle: 135, colors: [[this.cfg.c1, 0], [this.cfg.c2, 1]] })
          .borderRadius({ bottomLeft: 20, bottomRight: 20 })

          // 数据卡
          Row() {
            this.stat('主讲', this.teacher)
            this.stat('课时', `${this.lessons}讲`)
            this.stat('时长', `${this.minutes}分/讲`)
            this.stat('热度', `${this.heat}`)
          }
          .width('92%')
          .padding({ top: 14, bottom: 14 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(14)
          .margin({ top: 14 })
          .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 4 })

          // 章节列表
          Text('课程章节').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
            .width('92%').margin({ top: 18, bottom: 10 })

          // 🌟 本模块教学视频入口：检索词与学科、模块方向、模块完全一致
          Row({ space: 8 }) {
            Text('本模块教学视频').fontSize(11).fontColor($r('app.color.text_hint'))
            Text(`${this.cfg.name}${this.filter1 !== '' ? ' · ' + this.filter1 : ''}${this.module !== '' ? ' · ' + this.module : ''}`)
              .fontSize(11).fontColor(this.cfg.c2)
              .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([this.cfg.c2])
          }
          .width('92%')
          .padding({ left: 10, right: 10, top: 8, bottom: 8 })
          .margin({ bottom: 10 })
          .backgroundColor(`${this.cfg.c1}12`)
          .borderRadius(10)
          .onClick(() => {
            router.pushUrl({ url: 'pages/common/WebViewPage', params: { url: this.moduleVideoUrl() } })
          })

          Column({ space: 10 }) {
            ForEach(chaptersOf(this.cfg, this.fakeCourse()), (ch: CourseChapter) => {
              Column({ space: 8 }) {
                Row({ space: 10 }) {
                  Text(`${ch.index}`)
                    .fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.cfg.c2)
                    .width(26).height(26).borderRadius(13)
                    .backgroundColor(`${this.cfg.c1}1A`)
                    .textAlign(TextAlign.Center)
                  // 🌟 标题与副信息分层：标题最多两行省略，时长/试看徽标另起一行，长章节名不再挤压排版
                  Column({ space: 6 }) {
                    Text(ch.title).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                      .width('100%').maxLines(2).lineHeight(19)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Row({ space: 8 }) {
                      Text(`${ch.minutes}分钟`).fontSize(10).fontColor($r('app.color.text_hint'))
                      Text(ch.free ? '免费试看' : '观看')
                        .fontSize(10)
                        .fontColor(ch.free ? Color.White : this.cfg.c2)
                        .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                        .backgroundColor(ch.free ? this.cfg.c1 : `${this.cfg.c1}18`)
                        .borderRadius(8)
                    }.width('100%')
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
              }
              .width('100%')
              .padding(12)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(12)
              // 🌟 每章进入各自的章节详情页，携带章节完整身份参数（此前统一跳 WebViewPage 导致各章内容相同）
              .onClick(() => this.openChapter(ch))
            }, (ch: CourseChapter) => `${ch.index}_${ch.free ? 1 : 0}`)
          }.width('92%')

          Blank().height(80)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      // 底部操作栏
      Row({ space: 12 }) {
        Column({ space: 3 }) {
          SymbolGlyph(this.collected ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
            .fontSize(20)
            .fontColor([this.collected ? '#E8B93E' : $r('app.color.text_sub')])
          Text('收藏').fontSize(9).fontColor($r('app.color.text_sub'))
        }
        .width(52)
        .onClick(() => {
          this.collected = !this.collected
          promptAction.showToast({ message: this.collected ? '已收藏课程' : '已取消收藏' })
        })

        // 🌟 选课校验已通过，统一提供学习入口（金币不可用于购买课程）
        Button('开始学习')
          .layoutWeight(1)
          .backgroundColor(this.cfg.c2)
          .onClick(() => {
            router.pushUrl({ url: 'pages/common/WebViewPage', params: { url: this.moduleVideoUrl() } })
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor($r('app.color.card_bg'))
      .shadow({ radius: 10, color: 'rgba(0,0,0,0.06)', offsetY: -2 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  // 章节生成需要一个 SubjectCourse 形状的数据
  fakeCourse(): SubjectCourse {
    let c = new SubjectCourse()
    c.title = this.title
    c.module = this.module
    c.filter1 = this.filter1
    c.lessons = this.lessons
    c.minutes = this.minutes
    return c
  }

  // 🌟 打开章节详情页：把该章节的完整参数传给 ChapterPage，保证每章展示各自内容
  openChapter(ch: CourseChapter): void {
    router.pushUrl({
      url: 'pages/course/ChapterPage',
      params: {
        subjectId: this.cfg.id,
        courseTitle: this.title,
        module: this.module,
        filter1: this.filter1,
        filter2: this.filter2,
        teacher: this.teacher,
        lessons: `${this.lessons}`,
        minutes: `${this.minutes}`,
        chIndex: `${ch.index}`,
        chTitle: ch.title,
        chMinutes: `${ch.minutes}`,
        chFree: ch.free ? '1' : '0',
        url: this.biliVideoUrl(ch)
      }
    })
  }

  // 🌟 章节对应的 B 站教学视频（已校验）：检索词 = 学科 + 模块方向 + 本节知识点 + 本节环节，
  // 每章链接与其内容一一对应（此前丢弃环节词，整门课各章链接完全相同、与章节内容不对应）
  biliVideoUrl(ch: CourseChapter): string {
    let parts: string[] = [this.cfg.name]
    if (this.filter1 !== '') {
      parts.push(this.filter1)
    }
    parts.push(this.topicOf(ch.title))
    let part = this.chapterPart(ch.title)
    if (part !== '') {
      parts.push(part)
    }
    return biliSearch(parts.join(' '))
  }

  // 🌟 章节环节词：「第N讲 环节｜知识点」取环节（去掉「第N讲」与「强化·」前缀）；
  // 导学 / 测评章没有环节词，返回空（沿用知识点检索）
  chapterPart(title: string): string {
    let bar = title.lastIndexOf('｜')
    if (bar <= 0) {
      return ''
    }
    let head = title.substring(0, bar).trim()
    if (head.startsWith('第')) {
      let j = head.indexOf('讲')
      if (j >= 0 && j < head.length - 1) {
        head = head.substring(j + 1).trim()
      }
    }
    if (head.startsWith('强化·')) {
      head = head.substring(3).trim()
    }
    return head
  }

  // 本课程 + 本模块的教学视频检索入口：同样带上课程主题，避免只落到模块分类
  moduleVideoUrl(): string {
    let parts: string[] = [this.cfg.name]
    if (this.filter1 !== '') {
      parts.push(this.filter1)
    }
    if (this.module !== '' && this.module !== '全部') {
      parts.push(this.module)
    }
    if (this.title !== '') {
      parts.push(this.topicOf(this.title))
    }
    return biliSearch(parts.join(' '))
  }

  // 🌟 章节主题：优先取「｜」后的知识点；导学/测评类取冒号后的主题，避免搜成「学习路径 / 综合检测」
  topicOf(title: string): string {
    let i = title.lastIndexOf('｜')
    if (i >= 0 && i < title.length - 1) {
      return title.substring(i + 1).trim()
    }
    i = title.indexOf('：')
    if (i >= 0 && i < title.length - 1) {
      let rest = title.substring(i + 1).trim()
      if (rest.endsWith(' 学习路径')) {
        rest = rest.substring(0, rest.length - 5).trim()
      }
      if (rest.endsWith(' 综合检测')) {
        rest = rest.substring(0, rest.length - 5).trim()
      }
      if (rest !== '') {
        return rest
      }
    }
    return title
  }

  @Builder
  stat(label: string, value: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(label).fontSize(10).fontColor($r('app.color.text_hint'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }
}
