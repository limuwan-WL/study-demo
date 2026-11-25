import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';
import { SubjectHubView } from './SubjectHubView';
import { SUBJECTS } from '../../model/SubjectModel';
import { Teacher, TeacherCourse } from '../../model/DataModel';
import { onCheckin } from '../../model/GrowthModel';
import {
  Course, CheckinItem, Achievement, ACHIEVEMENTS,
  langByKey, coursesOf, refreshAchievements
} from '../../model/CourseModel';
import {
  TeacherAchievement, TEACHER_ACHIEVEMENTS, teacherUnlockedIds,
  Homework, HomeworkSubmission, StudentProgress, mockStudentProgress
} from '../../model/HomeworkModel';

// 🌟 学习打卡弹窗：输入打卡内容，提交后写入社区并触发成就检查
@CustomDialog
struct CheckinDialog {
  controller: CustomDialogController
  @State content: string = ''
  onClose: () => void = () => {
  }
  onConfirm: (text: string) => void = () => {
  }

  aboutToDisappear(): void {
    this.onClose()
  }

  build() {
    Column({ space: 16 }) {
      Text('学习打卡').fontSize(18).fontWeight(FontWeight.Bold)
      TextArea({ text: this.content, placeholder: '分享今天的学习成果吧～' })
        .height(90)
        .onChange((v: string) => this.content = v)
        .backgroundColor($r('app.color.field_bg'))
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).backgroundColor($r('app.color.btn_cancel')).onClick(() => this.controller.close())
        Button('发布打卡').layoutWeight(1).onClick(() => {
          if (this.content.trim() === '') {
            promptAction.showToast({ message: '打卡内容不能为空' })
            return
          }
          this.onConfirm(this.content.trim())
          this.controller.close()
        })
      }.width('100%')
    }.padding(20).backgroundColor($r('app.color.card_bg')).borderRadius(16)
  }
}

@Component
export struct CoursePage {
  // 🌟 学习语言：在语种课程内页切换后，打卡内容按当前语种展示
  @StorageLink('languageSetting') language: string = 'en'
  @StorageLink('courseProgress') courseProgress: Record<string, number> = {}
  @StorageLink('checkinList') checkinList: CheckinItem[] = []
  @StorageLink('achievementList') achievements: string[] = []
  @StorageLink('nickname') nickname: string = '张同学'
  // 🌟 用户身份：teacher 时课程页展示教学工作台，隐藏学生练习板块
  @StorageLink('userRole') userRole: string = 'student'
  // 🌟 作业数据（老师工作台展示统计）
  @StorageLink('hwList') hwList: Homework[] = []
  @StorageLink('hwSubs') hwSubs: HomeworkSubmission[] = []

  // 🌟 授课名师：与讲师主页共用同一份持久化数据，支持一门课程绑定多位教师
  @StorageLink('teacherList') teachers: Teacher[] = []
  @State teacherIndex: number = 0
  // 🌟 头像加载失败的讲师 id（失败后回退到默认占位头像）
  @State failedAvatars: string[] = []
  private teacherSwiper: SwiperController = new SwiperController()

  @State checkinDialogVisible: boolean = false
  checkinDialogController: CustomDialogController = new CustomDialogController({
    builder: CheckinDialog({}),
    customStyle: true
  })

  // 🌟 学生身份不支持发布打卡：入口整体不渲染，且调用处做兜底拦截
  canPublishCheckin(): boolean {
    return this.userRole !== 'student'
  }

  openCheckinDialog() {
    if (!this.canPublishCheckin() || this.checkinDialogVisible) {
      return
    }
    this.checkinDialogVisible = true
    this.checkinDialogController = new CustomDialogController({
      builder: CheckinDialog({
        onClose: () => {
          this.checkinDialogVisible = false
        },
        onConfirm: (text: string) => {
          let item = new CheckinItem(this.nickname, text, this.language, Date.now())
          this.checkinList = [item].concat(this.checkinList)
          // 🌟 打卡成长奖励：老师侧只加经验，不发放金币
          onCheckin()
          // 🌟 打卡后检查成就（首次打卡解锁「社区之星」）
          let fresh = refreshAchievements(this.language)
          promptAction.showToast({ message: fresh.length > 0 ? `打卡成功！解锁成就：${fresh.join('、')}` : '打卡成功，+5 经验！' })
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.checkinDialogController.open()
  }

  // 🌟 当前语言累计完成课时（老师成就核对班级课时用）
  totalDone(): number {
    let total = 0
    coursesOf(this.language).forEach((c: Course) => {
      total += this.courseDone(c.id)
    })
    return total
  }

  courseDone(courseId: string): number {
    let n = this.courseProgress[courseId]
    return n === undefined ? 0 : n
  }

  likeCheckin(item: CheckinItem) {
    item.liked = !item.liked
    item.likes += item.liked ? 1 : -1
    // 🌟 数组内对象属性变化需整体替换数组才能触发渲染
    this.checkinList = this.checkinList.slice()
  }

  // 🌟 老师身份的教学工作台：只展示所教学的「计算机基础」——学习人数 / 学生进度 / 布置教学任务
  @Builder
  teacherBoard() {
    Column({ space: 12 }) {
      // 课程头部
      Row({ space: 12 }) {
        Text('💻')
          .fontSize(22)
          .width(48).height(48).borderRadius(14).textAlign(TextAlign.Center)
          .backgroundColor('#4A5A6E22')
        Column({ space: 3 }) {
          Text('计算机基础').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Text('我所教学的课程').fontSize(11).fontColor($r('app.color.text_hint'))
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text('查看课程')
          .fontSize(11).fontColor($r('app.color.primary'))
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .borderRadius(12)
          .border({ width: 1, color: $r('app.color.primary') })
          .onClick(() => {
            router.pushUrl({ url: 'pages/subjects/CSBasicsPage' })
          })
      }.width('100%')

      // 班级数据：学习人数 / 平均课时 / 作业情况
      Row() {
        this.statBlock('学习人数', `${mockStudentProgress().length}`)
        this.statBlock('平均课时', `${this.classAvgLessons()}`)
        this.statBlock('已布置作业', `${this.hwList.length}`)
        this.statBlock('收到提交', `${this.hwSubs.length}`)
      }.width('100%')

      // 教学功能入口
      this.classEntry($r('sys.symbol.person_filled_badge_plus'), '#6366F1', '学生进度', '查看每个学生的学习数据', 'pages/course/HomeworkPage', 'progress')
      this.classEntry($r('sys.symbol.book'), '#8B5CF6', '布置教学任务', '布置作业并查看学生提交', 'pages/course/HomeworkPage', 'list')
      this.classEntry($r('sys.symbol.face_smiling'), '#0EA5E9', '班级群聊', '老师与同学自由交流', 'pages/course/GroupListPage', '')
    }
    .width('90%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(20)
    .margin({ top: 16 })
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 5 })
  }

  // 🌟 班级平均完成课时（名册数据）
  classAvgLessons(): number {
    let roster = mockStudentProgress()
    let total = 0
    roster.forEach((s: StudentProgress) => {
      total += s.lessons
    })
    return roster.length === 0 ? 0 : Math.round(total / roster.length)
  }

  // 🌟 班级功能入口行（老师工作台与学生「班级互动」共用）
  @Builder
  classEntry(sym: Resource, color: string, title: string, desc: string, url: string, tab: string) {
    Row({ space: 10 }) {
      SymbolGlyph(sym).fontSize(18).fontColor([color])
      Column({ space: 2 }) {
        Text(title).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
        Text(desc).fontSize(10).fontColor($r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.text_hint')])
    }
    .width('100%').padding({ top: 10, bottom: 10 })
    .onClick(() => {
      router.pushUrl({ url: url, params: { tab: tab } })
    })
  }

  @Builder
  achievementCard(id: string, name: string, desc: string, icon: Resource, color: string, unlocked: boolean) {
    Column({ space: 6 }) {
      Row() {
        SymbolGlyph(unlocked ? icon : $r('sys.symbol.lock'))
          .fontSize(22).fontColor([unlocked ? color : $r('app.color.text_hint')])
      }
      .width(52).height(52).borderRadius(26)
      .backgroundColor(unlocked ? `${color}22` : $r('app.color.field_bg'))
      .justifyContent(FlexAlign.Center)

      Text(name).fontSize(12).fontWeight(FontWeight.Medium)
        .fontColor(unlocked ? $r('app.color.text_main') : $r('app.color.text_hint'))
      Text(desc).fontSize(10).fontColor($r('app.color.text_hint'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(108)
    .padding({ top: 12, bottom: 12 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .margin({ right: 10 })
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.02)', offsetY: 4 })
  }

  // 🌟 老师成就：基于作业/提交/群消息等真实数据计算解锁
  tUnlocked(): string[] {
    return teacherUnlockedIds(this.nickname, this.totalDone())
  }

  @Builder
  checkinRow(item: CheckinItem) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(item.author.slice(0, 1))
          .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .width(32).height(32).borderRadius(16)
          .backgroundColor(langByKey(item.lang).color)
          .textAlign(TextAlign.Center)
        Column({ space: 2 }) {
          Row({ space: 6 }) {
            Text(item.author).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
            Text(langByKey(item.lang).name)
              .fontSize(9).fontColor(langByKey(item.lang).color)
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              .borderRadius(6)
              .border({ width: 1, color: langByKey(item.lang).color })
          }
          Text(item.time).fontSize(10).fontColor($r('app.color.text_hint'))
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)

        Row({ space: 4 }) {
          SymbolGlyph(item.liked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
            .fontSize(15)
            .fontColor([item.liked ? '#EF4444' : $r('app.color.text_sub')])
          Text(`${item.likes}`).fontSize(12).fontColor(item.liked ? '#EF4444' : $r('app.color.text_sub'))
        }
        .onClick(() => this.likeCheckin(item))
        .padding(6)
      }.width('100%').alignItems(VerticalAlign.Center)

      Text(item.content).fontSize(13).fontColor($r('app.color.text_body')).width('100%').lineHeight(20)
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.02)', offsetY: 4 })
  }

  // 🌟 讲师头像：有图片地址时加载，加载失败回退到姓名首字占位图
  @Builder
  teacherAvatar(t: Teacher, size: number) {
    if (t.avatar !== '' && !this.failedAvatars.includes(t.id)) {
      Image(t.avatar)
        .width(size).height(size)
        .borderRadius(size / 2)
        .objectFit(ImageFit.Cover)
        .onError(() => {
          this.failedAvatars = this.failedAvatars.concat([t.id])
        })
    } else {
      Text(t.avatarText !== '' ? t.avatarText : t.name.slice(0, 1))
        .fontSize(size * 0.4).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .width(size).height(size).borderRadius(size / 2).textAlign(TextAlign.Center)
        .linearGradient({ angle: 135, colors: [['#60A5FA', 0], ['#3B82F6', 1]] })
    }
  }

  // 🌟 讲师卡片：头像 + 姓名 + 职称 + 个人简介 + 所授课程
  @Builder
  teacherCard(t: Teacher) {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        this.teacherAvatar(t, 52)
        Column({ space: 5 }) {
          Text(t.name).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Text(`${t.title}${t.department !== '' ? ' · ' + t.department : ''}`)
            .fontSize(11).fontColor($r('app.color.text_sub'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Row({ space: 6 }) {
            ForEach(t.courses.slice(0, 2), (c: TeacherCourse) => {
              Text(c.name)
                .fontSize(10).fontColor($r('app.color.primary'))
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor($r('app.color.primary_weak'))
                .borderRadius(6)
                .maxLines(1)
            }, (c: TeacherCourse) => c.id)
          }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.text_hint')])
      }.width('100%').alignItems(VerticalAlign.Center)

      Text(t.bio)
        .fontSize(12).fontColor($r('app.color.text_sub')).lineHeight(18)
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%').textAlign(TextAlign.Start)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(18)
    .alignItems(HorizontalAlign.Start)
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 4 })
    .onClick(() => {
      router.pushUrl({ url: 'pages/course/TeacherPage', params: { teacherId: t.id } })
    })
  }

  build() {
    Scroll() {
      Column() {
        // ===== 顶部横幅：仅老师展示教学工作台（学生的课程学习卡片已下沉到语种课程内页） =====
        if (this.userRole === 'teacher') {
          Column({ space: 10 }) {
            Row() {
              Column({ space: 4 }) {
                Text('教学工作台').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White)
                Text('布置教学任务 · 关注学生学习进度').fontSize(12).fontColor('#DCE9FB')
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }.width('100%').alignItems(VerticalAlign.Center)

            // 🌟 老师不参与学习进度评定，展示班级维度数据
            Row({ space: 14 }) {
              Row({ space: 5 }) {
                SymbolGlyph($r('sys.symbol.person')).fontSize(14).fontColor(['#FFD48A'])
                Text(`学习人数 ${mockStudentProgress().length}`).fontSize(12).fontColor(Color.White)
              }
              Row({ space: 5 }) {
                SymbolGlyph($r('sys.symbol.graduationcap')).fontSize(14).fontColor(['#FFD48A'])
                Text(`平均课时 ${this.classAvgLessons()}`).fontSize(12).fontColor(Color.White)
              }
              Row({ space: 5 }) {
                SymbolGlyph($r('sys.symbol.star_fill')).fontSize(14).fontColor(['#FFD48A'])
                Text(`成就 ${this.tUnlocked().length}/${TEACHER_ACHIEVEMENTS.length}`).fontSize(12).fontColor(Color.White)
              }
            }
          }
          .width('90%')
          .alignItems(HorizontalAlign.Start)
          .padding(20)
          .linearGradient({ angle: 135, colors: [['#4C8BF5', 0], ['#3F7EF6', 1]] })
          .borderRadius(20)
          .margin({ top: 20 })
          .shadow({ radius: 10, color: 'rgba(63,126,246,0.25)', offsetY: 5 })
        }

        // 🌟 老师身份不展示公共学科宫格，只保留所教学的「计算机基础」
        if (this.userRole !== 'teacher') {
          // ===== 学科课程：20 门学科（小学/初中/大学）=====
          Row() {
            Text('学科课程')
              .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
            Blank()
            Text(`${SUBJECTS.length} 门学科 · 小学/初中/大学同步学`)
              .fontSize(11).fontColor($r('app.color.text_sub'))
          }
          .width('90%').margin({ top: 20, bottom: 4 })

          // 搜索 + 分学段学科宫格（点击进入对应学科课程页）
          SubjectHubView()
        }

        // 🌟 老师身份：展示教学工作台；学生身份：班级互动
        if (this.userRole === 'teacher') {
          this.teacherBoard()
        } else {
          // ===== 班级互动：班级群聊 + 作业 =====
          Text('班级互动')
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
            .width('90%').margin({ top: 20, bottom: 12 })
          Column({ space: 2 }) {
            this.classEntry($r('sys.symbol.face_smiling'), '#0EA5E9', '班级群聊', '老师与同学自由交流', 'pages/course/GroupListPage', '')
            this.classEntry($r('sys.symbol.book'), '#8B5CF6', '我的作业', '查看并提交老师布置的作业（文字 / 照片 / 视频 / 录音）', 'pages/course/HomeworkPage', 'list')
          }
          .width('90%').alignItems(HorizontalAlign.Start).padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.card_bg')).borderRadius(20)
          .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 5 })
        }

        // ===== 成就激励系统（🌟 按身份区分：学生成就 / 教师成就） =====
        Row() {
          Text('成就墙')
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Blank()
          Text(`${this.userRole === 'teacher' ? this.tUnlocked().length : this.achievements.length}/${this.userRole === 'teacher' ? TEACHER_ACHIEVEMENTS.length : ACHIEVEMENTS.length} 已解锁`)
            .fontSize(11).fontColor($r('app.color.text_sub'))
        }
        .width('90%').margin({ top: 20, bottom: 12 })

        Scroll() {
          Row() {
            if (this.userRole === 'teacher') {
              ForEach(TEACHER_ACHIEVEMENTS, (a: TeacherAchievement) => {
                this.achievementCard(a.id, a.name, a.desc, a.icon, a.color, this.tUnlocked().includes(a.id))
              }, (a: TeacherAchievement) => `${a.id}_${this.tUnlocked().includes(a.id) ? 1 : 0}`)
            } else {
              ForEach(ACHIEVEMENTS, (a: Achievement) => {
                this.achievementCard(a.id, a.name, a.desc, a.icon, a.color, this.achievements.includes(a.id))
              }, (a: Achievement) => `${a.id}_${this.achievements.includes(a.id) ? 1 : 0}`)
            }
          }
        }
        .width('90%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)

        // ===== 社区交流 =====
        Row() {
          Text('学习社区')
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Blank()
          if (this.canPublishCheckin()) {
            Text('+ 发布打卡')
              .fontSize(12).fontWeight(FontWeight.Medium).fontColor(Color.White)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor($r('app.color.primary')).borderRadius(13)
              .onClick(() => this.openCheckinDialog())
          }
        }
        .width('90%').margin({ top: 20, bottom: 12 })

        Column({ space: 12 }) {
          ForEach(this.sortedCheckins(), (item: CheckinItem) => {
            this.checkinRow(item)
          }, (item: CheckinItem) => `${item.id}_${item.likes}_${item.liked ? 1 : 0}`)
          if (this.sortedCheckins().length === 0) {
            Text(this.canPublishCheckin() ? '还没有打卡记录，发布第一条打卡吧～' : '还没有打卡记录～')
              .fontSize(13).fontColor($r('app.color.text_hint'))
              .width('100%').textAlign(TextAlign.Center).margin({ top: 10 })
          }
        }.width('90%')

        // ===== 授课名师轮播 =====
        Row() {
          Text('授课名师').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Blank()
          Text(`${this.teachers.length} 位教师 · 左右滑动查看`).fontSize(11).fontColor($r('app.color.text_sub'))
        }.width('90%').margin({ top: 20, bottom: 8 })

        if (this.teachers.length === 0) {
          Text('暂无授课教师信息')
            .fontSize(13).fontColor($r('app.color.text_hint'))
            .width('90%').textAlign(TextAlign.Center).padding({ top: 16, bottom: 16 })
            .backgroundColor($r('app.color.card_bg')).borderRadius(16)
        } else {
          // 🌟 默认关闭自动播放，仅支持手动左右滑动
          Swiper(this.teacherSwiper) {
            ForEach(this.teachers, (t: Teacher) => {
              this.teacherCard(t)
            }, (t: Teacher) => t.id)
          }
          .width('90%')
          .height(168)
          .autoPlay(false)
          .loop(false)
          .indicator(false)
          .itemSpace(10)
          .index(this.teacherIndex)
          .onChange((index: number) => {
            this.teacherIndex = index
          })

          // 分页圆点指示器
          Row({ space: 6 }) {
            ForEach(this.teachers, (t: Teacher, i: number) => {
              Row()
                .width(this.teacherIndex === i ? 18 : 7)
                .height(7)
                .borderRadius(4)
                .backgroundColor(this.teacherIndex === i ? $r('app.color.primary') : $r('app.color.text_hint'))
                .onClick(() => {
                  this.teacherSwiper.changeIndex(i, true)
                  this.teacherIndex = i
                })
            }, (t: Teacher) => `dot_${t.id}`)
          }
          .width('90%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 10 })
        }

        Blank().height(30)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
    .backgroundColor($r('app.color.page_bg'))
  }

  @Builder
  statBlock(label: string, value: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      Text(label).fontSize(11).fontColor($r('app.color.text_sub'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  sortedCheckins(): CheckinItem[] {
    return this.checkinList.slice().sort((a: CheckinItem, b: CheckinItem) => {
      return b.createdAt - a.createdAt
    })
  }
}
