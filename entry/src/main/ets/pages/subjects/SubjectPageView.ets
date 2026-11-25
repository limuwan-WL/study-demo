import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';
import {
  SubjectConfig, SubjectCourse, subjectById, subjectCourses, stageName
} from '../../model/SubjectModel';
import { LEVEL_NAMES, ACHIEVEMENTS, Achievement } from '../../model/CourseModel';
import { expLevelOf, levelProgressOf, expToNextOf } from '../../model/GrowthModel';

// ==================== 学科课程页共享视图 ====================
// 通过 SubjectConfig 驱动出 16 套不同观感与交互：
// - 顶部导航 4 变体：0 渐变大标题(小学柔和) / 1 白色极简+下划线(初中简约) / 2 实色条+徽标(备考) / 3 深色学术条
// - 筛选 4 变体：0 柔和药丸 / 1 下划线标签 / 2 描边方标签 / 3 实色圆片；两行横向可滚动（年级/分册 + 版本/方向）
// - 卡片 6 变体：0 横幅图卡 / 1 顶部色条卡 / 2 左色条列表行 / 3 时间轴卡 / 4 备考密集卡(进度+考点) / 5 深色代码卡
// - 交互按学段区分：小学卡片带「去学习」胶囊；初中卡片可点星收藏；大学卡片显示进度与「刷题」入口
// - 统一：竖屏、瀑布流(WaterFlow)、下拉刷新(Refresh)、点击卡片进课程详情
@Component
export struct SubjectPageView {
  subjectId: string = 'chinese'

  @State sel1: number = 0 // 第一行筛选（年级/分册/板块）
  @State sel2: number = 0 // 第二行筛选（教材版本/考研方向）
  @State selModule: string = '全部'
  @State refreshing: boolean = false
  @State tick: number = 0 // 下拉刷新轮换内容
  @State favIds: string[] = [] // 初中收藏交互

  // 🌟 学习数据（与课程页共享）：等级 / 学习进度 / 成就实时同步
  @StorageLink('courseProgress') courseProgress: Record<string, number> = {}
  // 🌟 按学科/语言分账的学习日志：学科页只展示本学科的学习时长与打卡
  @StorageLink('studyLogBySubject') studyLogBySubject: Record<string, Record<string, number>> = {}
  @StorageLink('achievementList') achievements: string[] = []
  // 🌟 成长体系：等级统一由经验值驱动（每日登录/聊天/课程/练习/打卡获得）
  @StorageLink('userExp') userExp: number = 0

  cfg(): SubjectConfig {
    return subjectById(this.subjectId)
  }

  list(): SubjectCourse[] {
    let cfg = this.cfg()
    let f1 = cfg.f1[this.sel1]
    let f2 = cfg.f2.length > 0 ? cfg.f2[this.sel2] : ''
    return subjectCourses(cfg, f1, f2, this.selModule, this.tick)
  }

  goDetail(c: SubjectCourse) {
    router.pushUrl({
      url: 'pages/course/SubjectDetailPage',
      params: {
        subjectId: this.subjectId,
        title: c.title,
        module: c.module,
        teacher: c.teacher,
        lessons: `${c.lessons}`,
        minutes: `${c.minutes}`,
        heat: `${c.heat}`,
        tag: c.tag,
        filter1: c.filter1,
        filter2: c.filter2
      }
    })
  }

  toggleFav(c: SubjectCourse) {
    let id = c.id
    if (this.favIds.includes(id)) {
      this.favIds = this.favIds.filter((x: string) => x !== id)
      promptAction.showToast({ message: '已取消收藏' })
    } else {
      this.favIds.push(id)
      promptAction.showToast({ message: '已加入收藏' })
    }
  }

  // ---------------- 顶部导航：4 变体 ----------------
  @Builder
  header() {
    if (this.cfg().navStyle === 0) {
      // 小学柔和：渐变大圆角横幅 + 圆形返回钮
      Stack({ alignContent: Alignment.TopStart }) {
        Column({ space: 6 }) {
          Text(this.cfg().name).fontSize(26).fontWeight(FontWeight.Bold).fontColor(Color.White)
          Text(`${stageName(this.cfg().stage)}同步课程 · ${this.cfg().modules.length} 大模块`)
            .fontSize(12).fontColor('#FFFFFFCC')
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 54, bottom: 22 })

        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(22).fontColor([Color.White])
            .onClick(() => router.back())
        }
        .width(34).height(34).borderRadius(17)
        .backgroundColor('#33FFFFFF')
        .justifyContent(FlexAlign.Center)
        .margin({ left: 12, top: 48 })
      }
      .width('100%')
      .linearGradient({ angle: 135, colors: [[this.cfg().c1, 0], [this.cfg().c2, 1]] })
      .borderRadius({ bottomLeft: 24, bottomRight: 24 })
    }

    if (this.cfg().navStyle === 1) {
      // 初中极简：白底居中标题 + 主题色下划线
      Column() {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([this.cfg().c2])
            .onClick(() => router.back())
          Text(this.cfg().name).fontSize(19).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_main')).layoutWeight(1).textAlign(TextAlign.Center)
          Row().width(24)
        }
        .width('100%').height(56).padding({ left: 16, right: 16 })

        Row().width(36).height(3).borderRadius(2).backgroundColor(this.cfg().c2)
      }
      .width('100%')
      .backgroundColor($r('app.color.card_bg'))
      .shadow({ radius: 6, color: 'rgba(0,0,0,0.04)', offsetY: 2 })
    }

    if (this.cfg().navStyle === 2) {
      // 备考实色条：左返回 + 白色标题 + 右侧阶段徽标
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([Color.White])
          .onClick(() => router.back())
        Text(this.cfg().name).fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .layoutWeight(1).margin({ left: 10 })
        Text(stageName(this.cfg().stage) + (this.cfg().stage === 'uni' ? '备考' : '同步'))
          .fontSize(10).fontColor(Color.White)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .borderRadius(8)
          .border({ width: 1, color: '#99FFFFFF' })
      }
      .width('100%').height(56).padding({ left: 16, right: 16 })
      .backgroundColor(this.cfg().c2)
    }

    if (this.cfg().navStyle === 3) {
      // 深色学术条：色块字标 + 白标题
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([Color.White])
          .onClick(() => router.back())
        Text(this.cfg().name.slice(0, 1))
          .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .width(30).height(30).borderRadius(8)
          .backgroundColor(this.cfg().c1).textAlign(TextAlign.Center)
        Text(this.cfg().name).fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .layoutWeight(1)
        Text(stageName(this.cfg().stage)).fontSize(11).fontColor('#99FFFFFF')
      }
      .width('100%').height(60).padding({ left: 14, right: 16 })
      .backgroundColor('#2B3242')
    }
  }

  // ---------------- 筛选：4 变体（两行横向滚动） ----------------
  @Builder
  chipText(text: string, selected: boolean, style: number) {
    if (style === 0) {
      // 柔和药丸
      Text(text)
        .fontSize(12).fontWeight(selected ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(selected ? Color.White : $r('app.color.text_sub'))
        .padding({ left: 14, right: 14, top: 7, bottom: 7 })
        .backgroundColor(selected ? this.cfg().c1 : $r('app.color.field_bg'))
        .borderRadius(15)
    }
    if (style === 1) {
      // 下划线标签：选中用主题色下划线 + 正文色文字，避免深色主题下同色看不清
      Column({ space: 4 }) {
        Text(text)
          .fontSize(13).fontWeight(selected ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(selected ? $r('app.color.text_main') : $r('app.color.text_sub'))
        Row().width(selected ? 20 : 0).height(2.5).borderRadius(2).backgroundColor($r('app.color.primary'))
      }.padding({ left: 6, right: 6, top: 6, bottom: 2 })
    }
    if (style === 2) {
      // 描边方标签：选中改为实底 + 白字，保证深浅色主题都可读
      Text(text)
        .fontSize(12).fontWeight(selected ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(selected ? Color.White : $r('app.color.text_sub'))
        .padding({ left: 11, right: 11, top: 6, bottom: 6 })
        .borderRadius(6)
        .border({ width: selected ? 1.5 : 1, color: selected ? this.cfg().c2 : $r('app.color.divider_color') })
        .backgroundColor(selected ? this.cfg().c2 : Color.Transparent)
    }
    if (style === 3) {
      // 实色圆片：未选中文字改用主题正文色，避免深色背景上的深色文字
      Text(text)
        .fontSize(12).fontWeight(FontWeight.Medium)
        .fontColor(selected ? Color.White : $r('app.color.text_main'))
        .padding({ left: 13, right: 13, top: 6, bottom: 6 })
        .backgroundColor(selected ? this.cfg().c2 : $r('app.color.field_bg'))
        .borderRadius(14)
    }
  }

  @Builder
  filterRow(row: number, label: string, options: string[], style: number) {
    Row({ space: 8 }) {
      Text(label).fontSize(11).fontColor($r('app.color.text_hint')).width(30)
      Scroll() {
        Row({ space: 8 }) {
          ForEach(options, (opt: string, idx: number) => {
            Row() {
              this.chipText(opt, row === 0 ? this.sel1 === idx : this.sel2 === idx, style)
            }
            .onClick(() => {
              // 🌟 直接写组件状态：@Builder 内按值传入的选中值和回调不会触发刷新
              if (row === 0) {
                this.sel1 = idx
              } else {
                this.sel2 = idx
              }
            })
          }, (opt: string, idx: number) =>
          `${row}_${opt}_${row === 0 ? (this.sel1 === idx ? 1 : 0) : (this.sel2 === idx ? 1 : 0)}`)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  // 🌟 模块筛选行：按字符串选中态渲染（'全部' + 学科模块）
  @Builder
  moduleRow() {
    Row({ space: 8 }) {
      Text('模块').fontSize(11).fontColor($r('app.color.text_hint')).width(30)
      Scroll() {
        Row({ space: 8 }) {
          ForEach(['全部'].concat(this.cfg().modules), (opt: string) => {
            Row() {
              this.chipText(opt, this.selModule === opt, this.cfg().filterStyle)
            }
            .onClick(() => {
              this.selModule = opt
            })
          }, (opt: string) => `${this.cfg().id}_${opt}_${this.selModule === opt ? 1 : 0}`)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  filterArea() {
    Column({ space: 10 }) {
      this.filterRow(0, this.cfg().f1Label, this.cfg().f1, this.cfg().filterStyle)
      if (this.cfg().f2.length > 0) {
        this.filterRow(1, this.cfg().f2Label, this.cfg().f2, this.cfg().filterStyle)
      }
      this.moduleRow()
    }
    .width('92%')
    .padding({ top: 12, bottom: 4 })
  }

  // ---------------- 卡片：统一两列排布（按学段保留 4 种观感） ----------------
  // 🌟 全部学科改为两列卡片流：小学横幅卡 / 初中色条卡 / 大学备考卡 / 计算机代码卡
  @Builder
  card(c: SubjectCourse) {
    if (this.cfg().cardStyle === 0) {
      this.cardBanner(c)
    }
    if (this.cfg().cardStyle === 1 || this.cfg().cardStyle === 2 || this.cfg().cardStyle === 3) {
      this.cardTopStrip(c)
    }
    if (this.cfg().cardStyle === 4) {
      this.cardExam(c)
    }
    if (this.cfg().cardStyle === 5) {
      this.cardCode(c)
    }
  }

  // 小学：横幅图卡 + 「去学习」胶囊（柔和阴影、大圆角）
  @Builder
  cardBanner(c: SubjectCourse) {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          Text(c.module)
            .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor('#40FFFFFF').borderRadius(10)
        }
        .width('100%').height(64)
        .linearGradient({ angle: 120, colors: [[c.c1, 0], [c.c2, 1]] })
        .borderRadius({ topLeft: 16, topRight: 16 })

        Text(c.tag)
          .fontSize(9).fontColor(Color.White)
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .backgroundColor(c.tag === '真题' ? '#EF4444' : '#E8A33E')
          .borderRadius(6)
          .margin({ left: 10, top: 44 })
      }
      .width('100%')

      Column({ space: 6 }) {
        Text(c.title).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).lineHeight(20)
        Text(`${c.filter1} · ${c.filter2 !== '' ? c.filter2 + ' · ' : ''}${c.teacher}`)
          .fontSize(10).fontColor($r('app.color.text_hint'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Row() {
          Text(`${c.lessons}讲`).fontSize(10).fontColor($r('app.color.text_sub'))
          Blank()
          // 🌟 小学交互：胶囊按钮直接开始学习
          Text('去学习')
            .fontSize(10).fontColor(Color.White)
            .padding({ left: 12, right: 12, top: 4, bottom: 4 })
            .backgroundColor(c.c1).borderRadius(11)
            .onClick(() => {
              promptAction.showToast({ message: `开始学习：${c.title}` })
              this.goDetail(c)
            })
        }.width('100%')
      }
      .padding(12)
    }
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .shadow({ radius: 12, color: 'rgba(0,0,0,0.05)', offsetY: 5 })
    .onClick(() => this.goDetail(c))
  }

  // 初中：顶部细色条卡（利落直角、轻边框），右上星标收藏
  @Builder
  cardTopStrip(c: SubjectCourse) {
    Column({ space: 8 }) {
      Row().width('100%').height(4).borderRadius(2).backgroundColor(c.c1)
      Text(c.title).fontSize(13.5).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).lineHeight(19)
      Text(`${c.filter1} · ${c.module} · ${c.lessons}讲`)
        .fontSize(10).fontColor($r('app.color.text_hint'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Row() {
        // 🌟 标签文字改用正文色：深色主题下学科主题色会与卡片底色相近而「被盖住」
        Text(c.tag).fontSize(9).fontColor($r('app.color.text_body'))
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(`${c.c1}1A`).borderRadius(5)
        Blank()
        // 🌟 初中交互：星标收藏
        SymbolGlyph(this.favIds.includes(c.id) ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
          .fontSize(16)
          .fontColor([this.favIds.includes(c.id) ? '#E8B93E' : $r('app.color.text_hint')])
          .onClick(() => this.toggleFav(c))
          .padding(4)
      }.width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(10)
    .border({ width: 1, color: $r('app.color.divider_color') })
    .onClick(() => this.goDetail(c))
  }

  // 大学备考：密集卡（进度条 + 考点/热度），真题模块有「刷题」入口
  @Builder
  cardExam(c: SubjectCourse) {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text(c.module).fontSize(9).fontColor(Color.White)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(c.c2).borderRadius(4)
        Text(c.tag).fontSize(9).fontColor(c.tag === '真题' ? '#EF4444' : $r('app.color.text_body'))
          .padding({ left: 5, right: 5, top: 2, bottom: 2 })
          .border({ width: 1, color: c.tag === '真题' ? '#EF4444' : `${c.c1}66` }).borderRadius(4)
        Blank()
        Text(`${c.heat}人在学`).fontSize(9).fontColor($r('app.color.text_hint'))
      }.width('100%')

      Text(c.title).fontSize(13.5).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).lineHeight(19)

      Stack({ alignContent: Alignment.Start }) {
        Row().width('100%').height(5).borderRadius(3).backgroundColor($r('app.color.field_bg'))
        Row()
          .width(`${c.progress}%`)
          .height(5).borderRadius(3)
          .linearGradient({ angle: 90, colors: [[c.c1, 0], [c.c2, 1]] })
      }.width('100%')

      Row() {
        Text(`${c.teacher} · ${c.lessons}讲 · 已学${c.progress}%`)
          .fontSize(9.5).fontColor($r('app.color.text_hint')).layoutWeight(1)
        // 🌟 大学交互：真题模块直接「刷题」
        if (c.module.indexOf('真题') >= 0 || c.module.indexOf('习题') >= 0 || c.module.indexOf('题') >= 0) {
          Text('刷题')
            .fontSize(9.5).fontColor(Color.White)
            .padding({ left: 9, right: 9, top: 3, bottom: 3 })
            .backgroundColor(c.c1).borderRadius(8)
            .onClick(() => {
              promptAction.showToast({ message: '进入刷题模式，共 20 题' })
              this.goDetail(c)
            })
        }
      }.width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(10)
    .border({ width: 1, color: $r('app.color.divider_color') })
    .onClick(() => this.goDetail(c))
  }

  // 🌟 深色代码卡内的标签配色：不直接使用学科主题色（计算机主题色偏深，会和深色底融在一起）
  codeTagColor(tag: string): string {
    if (tag === '真题') {
      return '#FF9B93'
    }
    if (tag === '打卡') {
      return '#F5C86B'
    }
    if (tag === '精品') {
      return '#8FB8FF'
    }
    return '#7FE0B0'
  }

  codeTagBg(tag: string): string {
    if (tag === '真题') {
      return '#3A2426'
    }
    if (tag === '打卡') {
      return '#3A3220'
    }
    if (tag === '精品') {
      return '#22304A'
    }
    return '#20362B'
  }

  // 大学计算机：深色代码卡（伪代码块头部 + 等宽感标题）
  @Builder
  cardCode(c: SubjectCourse) {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Row().width(8).height(8).borderRadius(4).backgroundColor('#FF5F57')
        Row().width(8).height(8).borderRadius(4).backgroundColor('#FEBC2E')
        Row().width(8).height(8).borderRadius(4).backgroundColor('#28C840')
        Blank()
        Text(c.module).fontSize(9).fontColor('#A9B8CC')
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor('#1E2430')
      .borderRadius({ topLeft: 10, topRight: 10 })

      Column({ space: 7 }) {
        Text(c.title).fontSize(13.5).fontWeight(FontWeight.Medium).fontColor(Color.White)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).lineHeight(19)
        Text(`/* ${c.filter1}${c.filter2 !== '' ? ' · ' + c.filter2 : ''} · ${c.lessons}讲 */`)
          .fontSize(9.5).fontColor('#93A4BC').maxLines(1)
        Row() {
          // 🌟 深色卡内标签用固定高对比配色，避免学科主题色与底色混在一起看不清
          Text(c.tag).fontSize(9).fontColor(this.codeTagColor(c.tag))
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(this.codeTagBg(c.tag)).borderRadius(4)
          Blank()
          Text(`${c.teacher}`).fontSize(9.5).fontColor('#A9B8CC')
        }.width('100%')
      }
      .padding(12)
    }
    .backgroundColor('#2B3242')
    .borderRadius(10)
    .border({ width: 1, color: '#39424F' })
    .onClick(() => this.goDetail(c))
  }

  // ---------------- 学习中心：等级 + 学习进度 + 成就墙（参考英语学习页） ----------------

  // 🌟 当前学科对应的学习账本 key：语言类学科复用语种 key，其余学科用自己的 id
  studyScope(): string {
    let id = this.cfg().id
    if (id === 'korean') {
      return 'ko'
    }
    if (id === 'japanese') {
      return 'ja'
    }
    if (id === 'english' || id === 'englishmiddle') {
      return 'en'
    }
    return id
  }

  scopedStudyLog(): Record<string, number> {
    let map = this.studyLogBySubject[this.studyScope()]
    return map === undefined ? {} : map
  }

  // 🌟 累计完成课时：只统计本学科（按课程 id 前缀），不再把其他课程算进来
  totalDone(): number {
    let prefix = `${this.studyScope()}_`
    let total = 0
    Object.keys(this.courseProgress).forEach((k: string) => {
      if (k.startsWith(prefix)) {
        total += this.courseProgress[k]
      }
    })
    return total
  }

  levelIdx(): number {
    return Math.min(3, Math.floor(this.totalDone() / 10))
  }

  streak(): number {
    let log = this.scopedStudyLog()
    let streak = 0
    let d = new Date()
    if (log[dateKey(d)] === undefined) {
      d = new Date(d.getTime() - 86400000)
    }
    while (log[dateKey(d)] !== undefined && log[dateKey(d)] > 0) {
      streak++
      d = new Date(d.getTime() - 86400000)
    }
    return streak
  }

  totalMinutes(): number {
    let log = this.scopedStudyLog()
    let total = 0
    Object.keys(log).forEach((k: string) => {
      total += log[k]
    })
    return total
  }

  @Builder
  statMini(label: string, value: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      Text(label).fontSize(10).fontColor($r('app.color.text_hint'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  studyCenter() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        // 🌟 等级徽章：学科主题渐变 + 等级名，统一经验等级口径
        Text(`LV${expLevelOf(this.userExp) + 1}`)
          .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .width(44).height(44).borderRadius(12)
          .textAlign(TextAlign.Center)
          .linearGradient({ angle: 135, colors: [[this.cfg().c1, 0], [this.cfg().c2, 1]] })
          .shadow({ radius: 6, color: `${this.cfg().c1}55`, offsetY: 3 })
        Column({ space: 3 }) {
          Text(`学习等级 · ${LEVEL_NAMES[expLevelOf(this.userExp)]}`)
            .fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
          Text(expLevelOf(this.userExp) >= 3 ? `经验 ${this.userExp}，已是最高等级`
            : `经验 ${this.userExp} · 距下一级还差 ${expToNextOf(this.userExp)} 点`)
            .fontSize(11).fontColor($r('app.color.text_sub'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        // 🌟 经验徽章：与「我的」页成长体系一致
        Text('经验')
          .fontSize(10).fontColor(Color.White)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(`${this.cfg().c1}CC`).borderRadius(9)
      }.width('100%').alignItems(VerticalAlign.Center)

      // 升级进度条（学科主题渐变）
      Stack({ alignContent: Alignment.Start }) {
        Row().width('100%').height(6).borderRadius(3).backgroundColor($r('app.color.field_bg'))
        Row()
          .width(`${levelProgressOf(this.userExp)}%`)
          .height(6).borderRadius(3)
          .linearGradient({ angle: 90, colors: [[this.cfg().c1, 0], [this.cfg().c2, 1]] })
      }.width('100%')

      Divider().color($r('app.color.divider_color'))

      Row() {
        this.statMini('累计课时', `${this.totalDone()}`)
        this.statMini('连续打卡', `${this.streak()} 天`)
        this.statMini('累计学习', `${this.totalMinutes()} 分`)
        this.statMini('成就', `${this.achievements.length}/${ACHIEVEMENTS.length}`)
      }.width('100%')
    }
    .width('92%')
    .padding(14)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .border({ width: 1, color: `${this.cfg().c1}26` })
    .margin({ top: 12 })
    .shadow({ radius: 10, color: `${this.cfg().c1}18`, offsetY: 4 })
  }

  @Builder
  achievementWall() {
    Column({ space: 10 }) {
      Row() {
        Text('成就墙').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Text(`${this.achievements.length}/${ACHIEVEMENTS.length} 已解锁`)
          .fontSize(11).fontColor($r('app.color.text_hint'))
      }.width('92%').margin({ top: 14 })

      Scroll() {
        Row({ space: 10 }) {
          ForEach(ACHIEVEMENTS, (a: Achievement) => {
            Column({ space: 6 }) {
              Row() {
                SymbolGlyph(this.achievements.includes(a.id) ? a.icon : $r('sys.symbol.lock'))
                  .fontSize(20)
                  .fontColor([this.achievements.includes(a.id) ? a.color : $r('app.color.text_hint')])
              }
              .width(44).height(44).borderRadius(22)
              .backgroundColor(this.achievements.includes(a.id) ? `${a.color}22` : $r('app.color.field_bg'))
              .justifyContent(FlexAlign.Center)
              Text(a.name).fontSize(10.5)
                .fontColor(this.achievements.includes(a.id) ? $r('app.color.text_main') : $r('app.color.text_hint'))
                .maxLines(1)
            }
            .width(86)
            .padding({ top: 10, bottom: 10 })
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(14)
          }, (a: Achievement) => `${a.id}_${this.achievements.includes(a.id) ? 1 : 0}`)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('92%')
    }
    .width('100%')
  }

  // 🌟 课程两两成行（替代瀑布流）：与筛选/学习中心/成就墙共用同一滚动区，各区块不再相互挤压
  rows(): SubjectCourse[][] {
    let list = this.list()
    let out: SubjectCourse[][] = []
    for (let i = 0; i < list.length; i += 2) {
      out.push(list.slice(i, i + 2))
    }
    return out
  }

  build() {
    Column() {
      this.header()

      // ===== 下拉刷新 + 整页单滚动：筛选 / 学习中心 / 成就墙 / 课程卡自上而下排布 =====
      Refresh({ refreshing: this.refreshing }) {
        Scroll() {
          Column() {
            // ===== 筛选区（每行内部横向滚动，不再套外层横向滚动挤压布局） =====
            this.filterArea()

            // ===== 学习中心：等级 + 学习进度 =====
            this.studyCenter()

            // ===== 成就墙 =====
            this.achievementWall()

            // ===== 课程卡片：统一两列排布 =====
            ForEach(this.rows(), (pair: SubjectCourse[]) => {
              Row({ space: 12 }) {
                ForEach(pair, (c: SubjectCourse) => {
                  Column() {
                    this.card(c)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                }, (c: SubjectCourse) => c.id)
                if (pair.length === 1) {
                  Column().layoutWeight(1)
                }
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
              .margin({ top: 12 })
            }, (pair: SubjectCourse[]) => pair[0].id)
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 20 })
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
        .backgroundColor(this.cfg().cardStyle === 5 ? '#232936' : $r('app.color.page_bg'))
      }
      .layoutWeight(1)
      .onRefreshing(() => {
        // 🌟 下拉刷新：轮换一批课程内容
        this.tick++
        setTimeout((): void => {
          this.refreshing = false
          promptAction.showToast({ message: '已为你推荐新课程' })
        }, 800)
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.cfg().cardStyle === 5 ? '#232936' : $r('app.color.page_bg'))
  }
}

// 🌟 学习日期键（yyyy-MM-dd），与课程页 studyLog 口径一致
function dateKey(d: Date): string {
  let m = (d.getMonth() + 1).toString().padStart(2, '0')
  let day = d.getDate().toString().padStart(2, '0')
  return `${d.getFullYear()}-${m}-${day}`
}
