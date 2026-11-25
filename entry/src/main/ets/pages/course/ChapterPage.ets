import router from '@ohos.router';
import { SubjectConfig, subjectById, stageName } from '../../model/SubjectModel';

// ==================== 章节详情页 ====================
// 🌟 每一章独立成页：从课程详情页携带章节身份（序号/标题/时长/环节/视频链接）进入，
// 页面按章节标题解析出「环节 + 知识点」，生成该章节专属的学习内容，而不是共用同一个外链页
class ChapterSection {
  title: string = ''
  body: string = ''

  constructor(title: string, body: string) {
    this.title = title
    this.body = body
  }
}

@Entry
@Component
struct ChapterPage {
  private cfg: SubjectConfig = subjectById('chinese')
  courseTitle: string = ''
  module: string = ''
  filter1: string = ''
  filter2: string = ''
  teacher: string = ''
  lessons: number = 0
  minutes: number = 0
  chIndex: number = 1
  chTitle: string = ''
  chMinutes: number = 0
  chFree: boolean = false
  videoUrl: string = ''

  aboutToAppear(): void {
    let p = router.getParams() as Record<string, string>;
    if (p) {
      this.cfg = subjectById(p['subjectId'] !== undefined ? p['subjectId'] : 'chinese');
      this.courseTitle = p['courseTitle'] !== undefined ? p['courseTitle'] : '';
      this.module = p['module'] !== undefined ? p['module'] : '';
      this.filter1 = p['filter1'] !== undefined ? p['filter1'] : '';
      this.filter2 = p['filter2'] !== undefined ? p['filter2'] : '';
      this.teacher = p['teacher'] !== undefined ? p['teacher'] : '';
      this.lessons = p['lessons'] !== undefined ? Number(p['lessons']) : 0;
      this.minutes = p['minutes'] !== undefined ? Number(p['minutes']) : 0;
      this.chIndex = p['chIndex'] !== undefined ? Number(p['chIndex']) : 1;
      this.chTitle = p['chTitle'] !== undefined ? p['chTitle'] : '';
      this.chMinutes = p['chMinutes'] !== undefined ? Number(p['chMinutes']) : 0;
      this.chFree = p['chFree'] === '1';
      this.videoUrl = p['url'] !== undefined ? p['url'] : '';
    }
  }

  // 🌟 章节知识点：「第N讲 环节｜知识点」取「｜」后的知识点；导学/测评取「：」后的主题
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

  // 🌟 章节环节：去掉「第N讲」「强化·」前缀，得到本节的环节名（如 材料阅读方法 / 要点拆解）
  partOf(title: string): string {
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

  // 章节类型：导学 / 测评 / 常规
  chapterType(): string {
    if (this.chTitle.startsWith('课程导学')) {
      return '导学'
    }
    if (this.chTitle.startsWith('阶段测评')) {
      return '测评'
    }
    return '精讲'
  }

  // 🌟 章节专属内容：按章节类型和标题里的环节/知识点生成，不同章节内容不同
  sections(): ChapterSection[] {
    let topic: string = this.topicOf(this.chTitle)
    let part: string = this.partOf(this.chTitle)
    let mod: string = this.module !== '' && this.module !== '全部' ? this.module : this.cfg.name
    let list: ChapterSection[] = []

    if (this.chapterType() === '导学') {
      list.push(new ChapterSection('课程定位',
        `《${this.courseTitle}》属于${this.cfg.name}·${mod}，共 ${this.lessons} 讲，每讲约 ${this.minutes} 分钟。` +
          `本讲是整门课的导学，带你先建立「${topic}」的整体认识。`))
      list.push(new ChapterSection('学习路径',
        `1. 先看课程目录，明确 ${this.lessons} 讲之间的先后关系；\n` +
          `2. 按「基础理解 → 典型例题 → 综合练习」的顺序推进；\n` +
          `3. 每讲结束后用 10 分钟做一次自测，再进入下一讲。`))
      list.push(new ChapterSection('学习建议',
        `建议准备一份笔记，按「概念 / 方法 / 易错点」三栏记录。` +
          `${this.filter1 !== '' ? `先修内容：${this.filter1} 的基础知识；` : ''}` +
          `遇到卡点时先回看本讲导学，再进入具体章节。`))
      return list
    }

    if (this.chapterType() === '测评') {
      list.push(new ChapterSection('考查范围',
        `本卷覆盖《${this.courseTitle}》${mod}的全部章节，重点考查「${topic}」的综合运用，` +
          `题型与前面 ${this.lessons - 1} 讲中的例题、随堂练习保持一致。`))
      list.push(new ChapterSection('答题策略',
        `1. 先通览全卷，按「会做 → 半会 → 陌生」标注题目；\n` +
          `2. 先拿稳基础分，再回头处理综合题；\n` +
          `3. 主观题写清步骤与依据，即使结果有误也能拿过程分。`))
      list.push(new ChapterSection('复盘方法',
        `测完之后按错因分类：概念不清、方法选错、计算失误。` +
          `每类错题至少重做一遍，并回到对应章节补上「${topic}」的知识缺口。`))
      return list
    }

    list.push(new ChapterSection('环节说明',
      `本节是「${topic}」的${part !== '' ? `「${part}」环节` : '核心讲解'}，` +
        `属于《${this.courseTitle}》${mod}内容，由${this.teacher !== '' ? this.teacher : '任课老师'}主讲。`))
    list.push(new ChapterSection('本节目标',
      `1. 理解「${topic}」的核心概念与适用条件；\n` +
        `2. 掌握${part !== '' ? part : '典型例题'}的完整分析与书写步骤；\n` +
        `3. 能独立完成本节随堂练习，并说清每一步的依据。`))
    list.push(new ChapterSection('重点内容',
      part !== ''
        ? `围绕「${part}」展开：先交代本节知识点在整门课中的位置，再拆解${part}的操作步骤，` +
          `最后用 ${topic} 的典型例子完整演示一遍，标出容易失分的细节。`
        : `围绕「${topic}」展开：先讲清概念之间的区别与联系，再通过例题演示完整过程，最后归纳方法。`))
    list.push(new ChapterSection('随堂练习',
      `完成 3 道「${topic}」相关练习：1 道基础辨析、1 道${part !== '' ? part : '典型'}应用、1 道综合变式。` +
        `做完对照解析，把错因记到笔记的「易错点」一栏。`))
    list.push(new ChapterSection('学习建议',
      `建议先用 ${this.chMinutes} 分钟看完本节视频，再花 10 分钟整理笔记。` +
        `下一讲会用到本节结论，务必在进入下一讲前完成随堂练习。`))
    return list
  }

  // 顶部类型标签颜色
  typeColor(): string {
    if (this.chapterType() === '测评') {
      return '#EF4444'
    }
    if (this.chapterType() === '导学') {
      return '#E8A33E'
    }
    return this.cfg.c1
  }

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

            Row({ space: 8 }) {
              Text(`第${this.chIndex}讲`).fontSize(10).fontColor(Color.White)
                .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                .backgroundColor('#40FFFFFF').borderRadius(6)
              Text(this.chapterType()).fontSize(10).fontColor(Color.White)
                .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                .backgroundColor(this.typeColor()).borderRadius(6)
              if (this.chFree) {
                Text('免费试看').fontSize(10).fontColor(Color.White)
                  .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                  .backgroundColor('#40FFFFFF').borderRadius(6)
              }
            }

            // 🌟 长章节名收紧字号与行距，最多三行省略，避免撑乱页头
            Text(this.chTitle).fontSize(17).fontWeight(FontWeight.Bold).fontColor(Color.White)
              .lineHeight(24).width('100%').maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(`${this.cfg.name}${this.module !== '' ? ' · ' + this.module : ''}${this.filter1 !== '' ? ' · ' + this.filter1 : ''}`)
              .fontSize(11).fontColor('#FFFFFFCC').width('100%').maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 18, right: 18, top: 46, bottom: 20 })
          .linearGradient({ angle: 135, colors: [[this.cfg.c1, 0], [this.cfg.c2, 1]] })
          .borderRadius({ bottomLeft: 20, bottomRight: 20 })

          // 章节信息卡
          Row() {
            this.stat('时长', `${this.chMinutes}分钟`)
            this.stat('主讲', this.teacher !== '' ? this.teacher : '—')
            this.stat('类型', this.chapterType())
            this.stat('所属', this.module !== '' ? this.module : this.cfg.name)
          }
          .width('92%')
          .padding({ top: 14, bottom: 14 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(14)
          .margin({ top: 14 })
          .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 4 })

          // 本节视频入口（章节专属链接）
          Text('本节视频').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
            .width('92%').margin({ top: 18, bottom: 10 })

          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.book')).fontSize(16).fontColor([this.cfg.c1])
            Text(`观看「${this.topicOf(this.chTitle)}」本节视频`).fontSize(12).fontColor(this.cfg.c2)
              .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([this.cfg.c2])
          }
          .width('92%')
          .padding({ left: 12, right: 12, top: 12, bottom: 12 })
          .backgroundColor(`${this.cfg.c1}12`)
          .borderRadius(10)
          .onClick(() => {
            if (this.videoUrl !== '') {
              router.pushUrl({
                url: 'pages/common/WebViewPage',
                params: { url: this.videoUrl, title: `${this.cfg.name} · 第${this.chIndex}讲` }
              })
            }
          })

          // 本节学习内容
          Text('本节内容').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
            .width('92%').margin({ top: 18, bottom: 10 })

          Column({ space: 10 }) {
            ForEach(this.sections(), (sec: ChapterSection) => {
              Column({ space: 6 }) {
                Row({ space: 6 }) {
                  Row().width(3).height(13).borderRadius(2).backgroundColor(this.cfg.c1)
                  Text(sec.title).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                }.width('100%')
                Text(sec.body)
                  .fontSize(12).fontColor($r('app.color.text_body')).lineHeight(20)
                  .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(12)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(12)
            }, (sec: ChapterSection) => sec.title)
          }.width('92%')

          // 所属课程
          Text('所属课程').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
            .width('92%').margin({ top: 18, bottom: 10 })

          Column({ space: 6 }) {
            Text(this.courseTitle).fontSize(13).fontColor($r('app.color.text_main')).width('100%')
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${this.cfg.name}${this.filter1 !== '' ? ' · ' + this.filter1 : ''}${this.filter2 !== '' ? ' · ' + this.filter2 : ''}` +
              `${this.module !== '' ? ' · ' + this.module : ''} · 共${this.lessons}讲`)
              .fontSize(11).fontColor($r('app.color.text_hint')).width('100%')
          }
          .width('92%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(12)

          Blank().height(80)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      // 底部操作栏：观看本节视频
      Row({ space: 12 }) {
        Button('观看本节视频')
          .layoutWeight(1)
          .backgroundColor(this.cfg.c2)
          .onClick(() => {
            if (this.videoUrl !== '') {
              router.pushUrl({
                url: 'pages/common/WebViewPage',
                params: { url: this.videoUrl, title: `${this.cfg.name} · 第${this.chIndex}讲` }
              })
            }
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

  @Builder
  stat(label: string, value: string) {
    Column({ space: 3 }) {
      Text(value).fontSize(13).fontWeight(FontWeight.Bold).fontColor(this.cfg.c2)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(label).fontSize(10).fontColor($r('app.color.text_hint'))
    }.layoutWeight(1).alignItems(HorizontalAlign.Center)
  }
}
