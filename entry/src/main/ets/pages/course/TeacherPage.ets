import { promptAction } from '@kit.ArkUI'
import router from '@ohos.router'
import { Teacher, TeacherCourse, TeacherMaterial, FollowItem, teachersOfCourse, formatStamp } from '../../model/DataModel'
import { TeacherReview, TeacherReviewStore } from '../../model/ReviewModel'
import { Permission } from '../../model/PermissionModel'
import { Feedback } from '../../utils/Feedback'

// 🌟 匿名评价弹窗：评分 + 文字，提交后仅展示匿名身份
@CustomDialog
struct ReviewDialog {
  controller: CustomDialogController
  teacherName: string = ''
  onClose: () => void = () => {}
  onSubmit: (rating: number, content: string) => void = () => {}
  @State rating: number = 5
  @State content: string = ''

  aboutToDisappear(): void {
    this.onClose()
  }

  @Builder
  starItem(i: number) {
    Text(i <= this.rating ? '★' : '☆')
      .fontSize(26)
      .fontColor(i <= this.rating ? '#F5A623' : $r('app.color.text_hint'))
      .padding({ right: 4 })
      .onClick(() => this.rating = i)
  }

  build() {
    Column({ space: 14 }) {
      Text(`评价 ${this.teacherName}`).fontSize(18).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_main'))
      Text('你的评价将以匿名方式展示，教师不会看到你的昵称与学号')
        .fontSize(11).fontColor($r('app.color.text_hint')).width('100%')
      Row() {
        ForEach([1, 2, 3, 4, 5], (i: number) => {
          this.starItem(i)
        }, (i: number) => `${i}_${this.rating}`)
      }.width('100%').justifyContent(FlexAlign.Center)
      TextArea({ text: this.content, placeholder: '说说课程收获或改进建议（至少 5 个字）' })
        .fontSize(14).height(100).backgroundColor($r('app.color.field_bg')).borderRadius(10)
        .onChange((v: string) => this.content = v)
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).backgroundColor($r('app.color.btn_cancel'))
          .onClick(() => this.controller.close())
        Button('匿名发布').layoutWeight(1).onClick(() => {
          this.onSubmit(this.rating, this.content)
          this.controller.close()
        })
      }.width('100%')
    }.padding(20).backgroundColor($r('app.color.card_bg')).borderRadius(16)
  }
}

// 🌟 讲师维护主页资料弹窗：仅「当前登录讲师本人」可见编辑入口
@CustomDialog
struct TeacherEditDialog {
  controller: CustomDialogController
  bio: string = ''
  career: string = ''
  research: string = ''
  onSave: (bio: string, career: string, research: string) => void = () => {
  }
  @State bioText: string = ''
  @State careerText: string = ''
  @State researchText: string = ''

  aboutToAppear(): void {
    this.bioText = this.bio
    this.careerText = this.career
    this.researchText = this.research
  }

  build() {
    Column({ space: 12 }) {
      Text('编辑主页资料').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      Text('个人简介').fontSize(12).fontColor($r('app.color.text_sub')).width('100%')
      TextArea({ text: this.bioText, placeholder: '介绍教学风格与成果' })
        .height(80).fontSize(13)
        .backgroundColor($r('app.color.field_bg')).borderRadius(12).padding(10)
        .onChange((v: string) => {
          this.bioText = v
        })
      Text('个人履历').fontSize(12).fontColor($r('app.color.text_sub')).width('100%')
      TextArea({ text: this.careerText, placeholder: '教育背景、任职经历等' })
        .height(80).fontSize(13)
        .backgroundColor($r('app.color.field_bg')).borderRadius(12).padding(10)
        .onChange((v: string) => {
          this.careerText = v
        })
      Text('研究方向（用逗号分隔）').fontSize(12).fontColor($r('app.color.text_sub')).width('100%')
      TextInput({ text: this.researchText, placeholder: '如：分布式系统，算法设计' })
        .height(42).fontSize(13)
        .backgroundColor($r('app.color.field_bg')).borderRadius(12).padding({ left: 10, right: 10 })
        .onChange((v: string) => {
          this.researchText = v
        })
      Row({ space: 12 }) {
        Text('取消').fontSize(15).fontColor($r('app.color.text_sub'))
          .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 10, bottom: 10 })
          .onClick(() => this.controller.close())
        Text('保存').fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
          .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 10, bottom: 10 })
          .backgroundColor($r('app.color.primary')).borderRadius(20)
          .onClick(() => {
            if (this.bioText.trim() === '') {
              promptAction.showToast({ message: '个人简介不能为空' })
              return
            }
            this.onSave(this.bioText.trim(), this.careerText.trim(), this.researchText.trim())
            this.controller.close()
          })
      }.width('100%')
    }
    .padding(22)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(20)
  }
}

@Entry
@Component
export struct TeacherPage {
  // 🌟 讲师数据与课程页轮播共用同一份持久化数据
  @StorageLink('teacherList') teachers: Teacher[] = []
  @StorageLink('myTeacherId') myTeacherId: string = ''
  // 🌟 当前登录身份：学生仅浏览，讲师可维护自己的主页
  @StorageLink('userRole') userRole: string = 'student'
  // 🌟 匿名评价：持久化在本机，页面实时联动
  @StorageLink('teacherReviews') reviewList: TeacherReview[] = []
  // 🌟 关注页与讲师主页共用同一份关注数据
  @StorageLink('followItems') followList: FollowItem[] = []
  @StorageLink('nickname') nickname: string = '张同学'
  @State teacherId: string = ''
  @State bioExpanded: boolean = false
  @State avatarFailed: boolean = false
  @State reviewOpen: boolean = false

  private fallback: Teacher = new Teacher('', '', '', '')
  editController: CustomDialogController = new CustomDialogController({
    builder: TeacherEditDialog({}),
    customStyle: true
  })
  reviewController: CustomDialogController = new CustomDialogController({
    builder: ReviewDialog({}),
    customStyle: true
  })

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, string>
    if (params && params['teacherId'] !== undefined) {
      this.teacherId = params['teacherId']
    }
    if (this.teacherId === '' && this.teachers.length > 0) {
      this.teacherId = this.teachers[0].id
    }
  }

  teacher(): Teacher {
    let found = this.teachers.find((t: Teacher) => t.id === this.teacherId)
    return found === undefined ? this.fallback : found
  }

  // 🌟 编辑入口：讲师身份 + 该主页属于当前登录讲师本人
  canEdit(): boolean {
    return this.userRole === 'teacher' && this.teacher().id !== '' && this.teacher().id === this.myTeacherId
  }

  // ==================== 匿名评价 ====================
  myReviews(): TeacherReview[] {
    return this.reviewList.filter((r: TeacherReview) => r.teacherId === this.teacher().id)
      .sort((a: TeacherReview, b: TeacherReview) => b.createdAt - a.createdAt)
  }

  reviewAvg(): string {
    let list = this.myReviews()
    if (list.length === 0) {
      return '暂无评分'
    }
    let total = 0
    list.forEach((r: TeacherReview) => total += r.rating)
    return `${Math.round(total / list.length * 10) / 10} 分`
  }

  canReview(): boolean {
    return Permission.isStudent() && this.teacher().id !== ''
  }

  reviewed(): boolean {
    return TeacherReviewStore.hasReviewed(this.teacher().id, this.nickname)
  }

  openReview() {
    if (this.reviewOpen) {
      return
    }
    this.reviewOpen = true
    this.reviewController = new CustomDialogController({
      builder: ReviewDialog({
        teacherName: this.teacher().name,
        onClose: () => {
          this.reviewOpen = false
        },
        onSubmit: (rating: number, content: string) => {
          this.submitReview(rating, content)
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.reviewController.open()
  }

  submitReview(rating: number, content: string) {
    let course = this.localCourses().length > 0 ? this.localCourses()[0].name : ''
    let reason = TeacherReviewStore.add(this.teacher().id, this.teacher().name, this.nickname, rating, content, course)
    if (reason !== '') {
      Feedback.fail('发布评价', reason)
      return
    }
    this.reviewList = AppStorage.get<TeacherReview[]>('teacherReviews') ?? []
    promptAction.showToast({ message: '匿名评价已发布，感谢反馈' })
  }

  // 星级文本：避免使用 String.repeat，保持 ArkTS 兼容
  starsText(n: number): string {
    let s = ''
    for (let i = 0; i < n; i++) {
      s += '★'
    }
    return s
  }

  localCourses(): TeacherCourse[] {
    return this.teacher().courses.filter((c: TeacherCourse) => c.type === 'local')
  }

  publicCourses(): TeacherCourse[] {
    return this.teacher().courses.filter((c: TeacherCourse) => c.type === 'public')
  }

  // 🌟 同一门课程的授课教师人数（一门课可绑定多位教师）
  coTeachers(courseName: string): number {
    return teachersOfCourse(this.teachers, courseName).length
  }

  toggleFollow() {
    let t = this.teacher()
    t.followed = !t.followed
    t.followers += t.followed ? 1 : -1
    // 数组内对象属性变化需整体替换数组才能触发渲染与持久化
    this.teachers = this.teachers.slice()
    // 🌟 同步关注页数据，避免「讲师主页已关注」与「关注列表」两套状态
    let key = `${t.name} · `
    let exists = this.followList.filter((f: FollowItem) =>
      f.type === 'teacher' && f.title.indexOf(key) === 0)
    if (t.followed && exists.length === 0) {
      let f = new FollowItem('teacher', `${t.name} · ${t.title}`, t.avatar !== '' ? t.avatar : '👨‍🏫', 0, 0,
        t.id, 'teacher')
      this.followList = [f].concat(this.followList)
    } else if (!t.followed && exists.length > 0) {
      this.followList = this.followList.filter((f: FollowItem) =>
        !(f.type === 'teacher' && f.title.indexOf(key) === 0))
    }
    promptAction.showToast({ message: t.followed ? '已关注该教师' : '已取消关注' })
  }

  openEditDialog() {
    let t = this.teacher()
    this.editController = new CustomDialogController({
      builder: TeacherEditDialog({
        bio: t.bio,
        career: t.career,
        research: t.researchAreas.join('，'),
        onSave: (bio: string, career: string, research: string) => {
          t.bio = bio
          t.career = career
          let areas: string[] = []
          research.replace(/[，、；;]/g, ',').split(',').forEach((s: string) => {
            let v = s.trim()
            if (v !== '') {
              areas.push(v)
            }
          })
          t.researchAreas = areas
          this.teachers = this.teachers.slice()
          promptAction.showToast({ message: '主页资料已更新' })
        }
      }),
      autoCancel: true,
      customStyle: true
    })
    this.editController.open()
  }

  openCourse(c: TeacherCourse) {
    if (c.url === '') {
      promptAction.showToast({ message: '该课程暂未开放线上页面' })
      return
    }
    router.pushUrl({ url: c.url, params: { subjectId: c.subjectId, title: c.name } })
  }

  openMaterial(m: TeacherMaterial) {
    promptAction.showToast({ message: `开始下载「${m.title}」` })
  }

  @Builder
  teacherAvatar(size: number) {
    if (this.teacher().avatar !== '' && !this.avatarFailed) {
      Image(this.teacher().avatar)
        .width(size).height(size)
        .borderRadius(size / 2)
        .objectFit(ImageFit.Cover)
        .onError(() => {
          this.avatarFailed = true
        })
    } else {
      Text(this.teacher().avatarText !== '' ? this.teacher().avatarText : this.teacher().name.slice(0, 1))
        .fontSize(size * 0.4).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .width(size).height(size).borderRadius(size / 2).textAlign(TextAlign.Center)
        .linearGradient({ angle: 135, colors: [['#60A5FA', 0], ['#3B82F6', 1]] })
    }
  }

  // 🌟 模块标题
  @Builder
  sectionTitle(title: string) {
    Row({ space: 8 }) {
      Row().width(4).height(14).borderRadius(2).backgroundColor($r('app.color.primary'))
      Text(title).fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
    }.width('100%')
  }

  @Builder
  courseRow(c: TeacherCourse) {
    Row({ space: 10 }) {
      Text('📚')
        .fontSize(16).width(36).height(36).textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.field_bg')).borderRadius(10)
      Column({ space: 3 }) {
        Text(c.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
        Text(`${this.coTeachers(c.name)} 位教师授课`).fontSize(10).fontColor($r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('进入课程').fontSize(11).fontColor($r('app.color.primary'))
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(13).fontColor([$r('app.color.text_hint')])
    }
    .width('100%').padding({ top: 10, bottom: 10 })
    .onClick(() => this.openCourse(c))
  }

  @Builder
  materialRow(m: TeacherMaterial) {
    Row({ space: 10 }) {
      Text('📄')
        .fontSize(16).width(36).height(36).textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.field_bg')).borderRadius(10)
      Column({ space: 3 }) {
        Text(m.title).fontSize(13).fontColor($r('app.color.text_main'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${m.kind} · ${m.size}`).fontSize(10).fontColor($r('app.color.text_hint'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('下载')
        .fontSize(11).fontColor($r('app.color.primary'))
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .borderRadius(10)
        .border({ width: 1, color: $r('app.color.primary') })
    }
    .width('100%').padding({ top: 10, bottom: 10 })
    .onClick(() => this.openMaterial(m))
  }

  build() {
    Column() {
      if (this.teacher().id === '') {
        Column({ space: 12 }) {
          Text('未找到讲师信息').fontSize(15).fontColor($r('app.color.text_sub'))
          Text('返回').fontSize(14).fontColor($r('app.color.primary'))
            .padding({ left: 18, right: 18, top: 8, bottom: 8 })
            .borderRadius(16).border({ width: 1, color: $r('app.color.primary') })
            .onClick(() => router.back())
        }
        .width('100%').height('100%').justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            // ===== 头部：渐变底色 + 头像 + 姓名 / 职称 / 院系 =====
            Column({ space: 14 }) {
              Row() {
                SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(22).fontColor([Color.White])
                  .onClick(() => router.back())
                Blank()
                if (this.canEdit()) {
                  Text('编辑资料')
                    .fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary'))
                    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                    .backgroundColor(Color.White).borderRadius(14)
                    .onClick(() => this.openEditDialog())
                } else {
                  Text(this.teacher().followed ? '已关注' : '+ 关注')
                    .fontSize(12).fontWeight(FontWeight.Medium)
                    .fontColor(this.teacher().followed ? Color.White : $r('app.color.primary'))
                    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                    .backgroundColor(this.teacher().followed ? '#33FFFFFF' : Color.White)
                    .borderRadius(14)
                    .onClick(() => this.toggleFollow())
                }
              }.width('100%')

              Row({ space: 14 }) {
                this.teacherAvatar(72)
                Column({ space: 5 }) {
                  Text(this.teacher().name).fontSize(21).fontWeight(FontWeight.Bold).fontColor(Color.White)
                  Text(`${this.teacher().title}${this.teacher().department !== '' ? ' · ' + this.teacher().department : ''}`)
                    .fontSize(12).fontColor('#DCE9FB')
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Row({ space: 14 }) {
                    Text(`关注 ${this.teacher().followers}`).fontSize(11).fontColor('#FFFFFFCC')
                    Text(`课程 ${this.teacher().courses.length}`).fontSize(11).fontColor('#FFFFFFCC')
                  }
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              }.width('100%').alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ left: 18, right: 18, top: 46, bottom: 22 })
            .linearGradient({ angle: 135, colors: [['#4C8BF5', 0], ['#3F7EF6', 1]] })
            .borderRadius({ bottomLeft: 20, bottomRight: 20 })

            // ===== 个人简介：超长自动折叠，点击展开 =====
            Column({ space: 8 }) {
              this.sectionTitle('个人简介')
              Text(this.teacher().bio)
                .fontSize(13).fontColor($r('app.color.text_sub')).lineHeight(21)
                .maxLines(this.bioExpanded ? 99 : 3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
              if (this.teacher().bio.length > 40) {
                Text(this.bioExpanded ? '收起' : '展开')
                  .fontSize(12).fontColor($r('app.color.primary'))
                  .onClick(() => {
                    this.bioExpanded = !this.bioExpanded
                  })
              }
            }
            .width('90%').padding(16).alignItems(HorizontalAlign.Start)
            .backgroundColor($r('app.color.card_bg')).borderRadius(16)
            .shadow({ radius: 10, color: 'rgba(0,0,0,0.02)', offsetY: 4 })

            // ===== 个人履历 =====
            Column({ space: 8 }) {
              this.sectionTitle('个人履历')
              Text(this.teacher().career === '' ? '暂无履历信息' : this.teacher().career)
                .fontSize(13).fontColor($r('app.color.text_sub')).lineHeight(21).width('100%')
            }
            .width('90%').padding(16).alignItems(HorizontalAlign.Start)
            .backgroundColor($r('app.color.card_bg')).borderRadius(16)
            .shadow({ radius: 10, color: 'rgba(0,0,0,0.02)', offsetY: 4 })

            // ===== 研究方向 =====
            Column({ space: 10 }) {
              this.sectionTitle('研究方向')
              if (this.teacher().researchAreas.length === 0) {
                Text('暂未填写').fontSize(12).fontColor($r('app.color.text_hint'))
              } else {
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.teacher().researchAreas, (r: string) => {
                    Text(r)
                      .fontSize(12).fontColor($r('app.color.primary'))
                      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                      .backgroundColor($r('app.color.primary_weak')).borderRadius(12)
                      .margin({ right: 8, bottom: 8 })
                  }, (r: string) => r)
                }.width('100%')
              }
            }
            .width('90%').padding(16).alignItems(HorizontalAlign.Start)
            .backgroundColor($r('app.color.card_bg')).borderRadius(16)
            .shadow({ radius: 10, color: 'rgba(0,0,0,0.02)', offsetY: 4 })

            // ===== 开设课程清单：本校授课课程 / 公开课程 =====
            Column({ space: 8 }) {
              this.sectionTitle('开设课程')
              Text('本校授课课程').fontSize(12).fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_sub')).width('100%').margin({ top: 4 })
              if (this.localCourses().length === 0) {
                Text('暂无本校授课课程').fontSize(12).fontColor($r('app.color.text_hint')).width('100%')
              } else {
                ForEach(this.localCourses(), (c: TeacherCourse) => {
                  this.courseRow(c)
                }, (c: TeacherCourse) => c.id)
              }
              Divider().color($r('app.color.divider_color')).margin({ top: 4, bottom: 4 })
              Text('公开课程').fontSize(12).fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_sub')).width('100%')
              if (this.publicCourses().length === 0) {
                Text('暂无公开课程').fontSize(12).fontColor($r('app.color.text_hint')).width('100%')
              } else {
                ForEach(this.publicCourses(), (c: TeacherCourse) => {
                  this.courseRow(c)
                }, (c: TeacherCourse) => c.id)
              }
            }
            .width('90%').padding(16).alignItems(HorizontalAlign.Start)
            .backgroundColor($r('app.color.card_bg')).borderRadius(16)
            .shadow({ radius: 10, color: 'rgba(0,0,0,0.02)', offsetY: 4 })

            // ===== 学员匿名评价 =====
            Column({ space: 10 }) {
              Row() {
                this.sectionTitle('学员匿名评价')
                Blank()
                Text(this.reviewAvg()).fontSize(13).fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.primary'))
              }.width('100%')
              if (this.myReviews().length === 0) {
                Column({ space: 6 }) {
                  SymbolGlyph($r('sys.symbol.star_fill')).fontSize(34).fontColor([$r('app.color.text_hint')])
                  Text('还没有学员评价').fontSize(13).fontColor($r('app.color.text_sub'))
                  Text('选修过课程的同学可以匿名留下评分与建议').fontSize(11)
                    .fontColor($r('app.color.text_hint'))
                }.width('100%').padding({ top: 14, bottom: 6 })
              } else {
                ForEach(this.myReviews().slice(0, 5), (r: TeacherReview) => {
                  Column({ space: 4 }) {
                    Row() {
                      Text(TeacherReviewStore.anonymousName(r)).fontSize(12)
                        .fontColor($r('app.color.text_sub')).layoutWeight(1)
                      Text(this.starsText(r.rating)).fontSize(12).fontColor('#F5A623')
                    }.width('100%')
                    Text(r.content).fontSize(13).fontColor($r('app.color.text_main')).width('100%')
                    Text(`${r.courseName === '' ? '课程评价' : r.courseName} · ${formatStamp(r.createdAt)}`)
                      .fontSize(10).fontColor($r('app.color.text_hint')).width('100%')
                  }
                  .width('100%').padding(10)
                  .backgroundColor($r('app.color.field_bg')).borderRadius(10)
                  .alignItems(HorizontalAlign.Start)
                }, (r: TeacherReview) => r.id)
                if (this.myReviews().length > 5) {
                  Text(`共 ${this.myReviews().length} 条匿名评价`).fontSize(11)
                    .fontColor($r('app.color.text_hint')).width('100%')
                }
              }
              if (this.canReview()) {
                Button(this.reviewed() ? '你已匿名评价' : '匿名评价')
                  .fontSize(14).height(38).width('100%')
                  .backgroundColor(this.reviewed() ? $r('app.color.field_bg') : $r('app.color.primary'))
                  .fontColor(this.reviewed() ? $r('app.color.text_hint') : Color.White)
                  .enabled(!this.reviewed())
                  .onClick(() => this.openReview())
              }
            }
            .width('90%').padding(16).alignItems(HorizontalAlign.Start)
            .backgroundColor($r('app.color.card_bg')).borderRadius(16)
            .shadow({ radius: 10, color: 'rgba(0,0,0,0.02)', offsetY: 4 })

            // ===== 公开课件资源 =====
            Column({ space: 6 }) {
              this.sectionTitle('公开课件资源')
              if (this.teacher().materials.length === 0) {
                Text('暂无公开课件').fontSize(12).fontColor($r('app.color.text_hint')).width('100%')
              } else {
                ForEach(this.teacher().materials, (m: TeacherMaterial) => {
                  this.materialRow(m)
                }, (m: TeacherMaterial) => m.title)
              }
            }
            .width('90%').padding(16).alignItems(HorizontalAlign.Start)
            .backgroundColor($r('app.color.card_bg')).borderRadius(16)
            .shadow({ radius: 10, color: 'rgba(0,0,0,0.02)', offsetY: 4 })

            Blank().height(30)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.TopStart)
      }
    }
    .width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }
}
