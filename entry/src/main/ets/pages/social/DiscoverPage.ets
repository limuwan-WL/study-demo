import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { PostItem, FavItem, formatTime, MessageItem, CommentItem, parsePostTime, unreadPostCount } from '../../model/DataModel';

const CATEGORY_COLOR: Record<string, string> = { '学习分享': '#3F7EF6', '求助': '#E8A33E' };

// 🌟 发布帖子弹窗（复用统一的弹窗交互）
@CustomDialog
struct PublishDialog {
  controller: CustomDialogController
  @State inputTitle: string = ''
  @State inputContent: string = ''
  @State category: string = '学习分享'
  onClose: () => void = () => {}
  onConfirm: (title: string, content: string, category: string) => void = () => {}

  aboutToDisappear(): void {
    this.onClose()
  }

  build() {
    Column({ space: 14 }) {
      Text('发布帖子').fontSize(18).fontWeight(FontWeight.Bold)
      TextInput({ text: this.inputTitle, placeholder: '帖子标题' })
        .onChange((v: string) => this.inputTitle = v).backgroundColor($r('app.color.field_bg'))
      Row() {
        Text('分类').fontSize(14).fontColor($r('app.color.text_label')).width(50)
        Row({ space: 8 }) {
          ForEach(['学习分享', '求助'], (c: string) => {
            Text(c)
              .fontSize(13)
              .fontColor(this.category === c ? Color.White : $r('app.color.text_label'))
              .backgroundColor(this.category === c ? CATEGORY_COLOR[c] : $r('app.color.field_bg'))
              .padding({ left: 14, right: 14, top: 5, bottom: 5 })
              .borderRadius(14)
              .onClick(() => this.category = c)
          }, (c: string) => c)
        }
      }.width('100%')
      TextArea({ text: this.inputContent, placeholder: '正文内容...' })
        .onChange((v: string) => this.inputContent = v)
        .backgroundColor($r('app.color.field_bg')).height(120)
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).backgroundColor($r('app.color.btn_cancel')).onClick(() => this.controller.close())
        Button('发布').layoutWeight(1).backgroundColor('#3F7EF6').onClick(() => {
          if (this.inputTitle.trim() === '' || this.inputContent.trim() === '') {
            promptAction.showToast({ message: '标题和内容不能为空' })
            return
          }
          this.onConfirm(this.inputTitle.trim(), this.inputContent.trim(), this.category)
          this.controller.close()
        })
      }.width('100%')
    }.padding(20).backgroundColor($r('app.color.card_bg')).borderRadius(16)
  }
}

@Component
export struct DiscoverPage {
  @StorageLink('postList') postList: PostItem[] = []
  @StorageLink('favList') favList: FavItem[] = []
  @StorageLink('nickname') nickname: string = '张同学'
  // 🌟 发现页红点 = 尚未查看过的帖子数，与列表里的「新内容」一一对应
  @StorageLink('readPostIds') readPostIds: string[] = []
  // 🌟 关注的作者列表（持久化）
  @StorageLink('followList') followList: string[] = []
  // 🌟 帖子评论 + 消息通知（模拟他人互动时写入）
  @StorageLink('commentMap') commentMap: Record<string, CommentItem[]> = {}
  @StorageLink('messageList') messageList: MessageItem[] = []
  @State curCategory: string = '全部'
  @State dialogVisible: boolean = false
  dialogController: CustomDialogController = new CustomDialogController({
    builder: PublishDialog({}),
    customStyle: true
  })

  getFiltered(): PostItem[] {
    let list: PostItem[] = []
    // 🌟 「关注」分类：只看已关注作者的帖子
    if (this.curCategory === '关注') {
      list = this.postList.filter((p: PostItem) => this.isFollowed(p.author))
    } else if (this.curCategory === '全部') {
      list = this.postList.slice()
    } else {
      list = this.postList.filter((p: PostItem) => p.category === this.curCategory)
    }
    // 🌟 按发帖时间排序：新帖永远在最上面
    return list.sort((a: PostItem, b: PostItem) => parsePostTime(b) - parsePostTime(a))
  }

  isFollowed(author: string): boolean {
    return this.followList.indexOf(author) >= 0
  }

  // 🌟 某个作者的全部帖子（关注页分组用，组内也按时间倒序）
  postsOf(author: string): PostItem[] {
    return this.postList.filter((p: PostItem) => p.author === author)
      .sort((a: PostItem, b: PostItem) => parsePostTime(b) - parsePostTime(a))
  }

  // 🌟 关注 / 取消关注作者
  toggleFollow(author: string) {
    if (this.isFollowed(author)) {
      this.followList = this.followList.filter((a: string) => a !== author)
      promptAction.showToast({ message: '已取消关注' })
    } else {
      this.followList = [author, ...this.followList]
      promptAction.showToast({ message: `已关注 ${author}，可在「关注」分类查看` })
    }
  }

  isFav(post: PostItem): boolean {
    return this.favList.some((f: FavItem) => f.type === 'post' && f.postId === post.id)
  }

  openPublish() {
    if (this.dialogVisible) {
      return
    }
    this.dialogVisible = true
    this.dialogController = new CustomDialogController({
      builder: PublishDialog({
        inputTitle: '',
        inputContent: '',
        category: '学习分享',
        onClose: () => {
          this.dialogVisible = false
        },
        onConfirm: (t: string, c: string, cat: string) => {
          this.publish(t, c, cat)
        }
      }),
      autoCancel: true, // 点击遮罩层可关闭
      customStyle: true
    })
    this.dialogController.open()
  }

  publish(title: string, content: string, category: string) {
    let post = new PostItem(title, content.slice(0, 40), content, this.nickname === '' ? '我' : this.nickname, category, formatTime(new Date()))
    post.createdAt = Date.now()
    this.postList = [post, ...this.postList]
    // 🌟 自己发布的帖子不算「新内容」，直接标记为已查看
    this.readPostIds = [post.id, ...this.readPostIds]
    promptAction.showToast({ message: '发布成功' })
  }

  // 🌟 关注页作者头部：头像圈 + 名字 + 帖子数 + 取消关注按钮
  @Builder
  authorHeader(author: string) {
    Row({ space: 10 }) {
      Text(author.slice(0, 1))
        .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .width(44).height(44)
        .linearGradient({ angle: 135, colors: [['#4C8BF5', 0], ['#3F7EF6', 1]] })
        .borderRadius(22).textAlign(TextAlign.Center)
      Column({ space: 2 }) {
        Text(author).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
        Text(`共 ${this.postsOf(author).length} 篇帖子`).fontSize(11).fontColor($r('app.color.text_sub'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('取消关注')
        .fontSize(12).fontColor($r('app.color.text_sub'))
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor($r('app.color.field_bg'))
        .borderRadius(14)
        .onClick(() => this.toggleFollow(author))
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 5 })
  }

  toggleLike(post: PostItem) {
    this.postList = this.postList.map((p: PostItem) => {
      if (p.id === post.id) {
        p.liked = !p.liked
        p.likes = p.liked ? p.likes + 1 : p.likes - 1
      }
      return p
    })
  }

  // 🌟 尚未查看的帖子数（红点数字）
  newCount(): number {
    return unreadPostCount(this.postList, this.readPostIds, this.nickname)
  }

  // 🌟 一键已读：把当前所有帖子标记为已查看，红点清零
  markAllRead() {
    this.readPostIds = this.postList.map((p: PostItem) => p.id)
    promptAction.showToast({ message: '已全部标记为已读' })
  }

  // 🌟 收藏联动：帖子收藏后自动加入收藏夹并标记来源
  toggleFav(post: PostItem) {
    if (this.isFav(post)) {
      this.favList = this.favList.filter((f: FavItem) => !(f.type === 'post' && f.postId === post.id))
      promptAction.showToast({ message: '已取消收藏' })
    } else {
      let fav = new FavItem(post.title, '', 'post', post.id)
      this.favList = [fav, ...this.favList]
      promptAction.showToast({ message: '已收藏到收藏夹' })
    }
  }

  @Builder
  categoryChip(name: string) {
    Text(name)
      .fontSize(14)
      .fontColor(this.curCategory === name ? Color.White : $r('app.color.text_label'))
      .backgroundColor(this.curCategory === name ? '#3F7EF6' : $r('app.color.card_bg'))
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      .borderRadius(16)
      .onClick(() => this.curCategory = name)
  }

  @Builder
  emptyTip(msg: string) {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.inbox')).fontSize(40).fontColor([$r('app.color.text_hint')])
      Text(msg).fontSize(14).fontColor($r('app.color.text_sub'))
    }.width('100%').padding({ top: 80 })
  }

  @Builder
  postCard(post: PostItem) {
    Column() {
      // 卡片主体：点击进入帖子详情
      Column({ space: 8 }) {
        Row() {
          Text(post.category)
            .fontSize(10).fontColor(Color.White)
            .backgroundColor(CATEGORY_COLOR[post.category])
            .padding({ left: 6, right: 6, top: 2, bottom: 2 }).borderRadius(6)
          Blank()
          Text(post.time).fontSize(11).fontColor($r('app.color.text_hint'))
        }.width('100%')

        Text(post.title)
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          .width('100%').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(post.brief)
          .fontSize(13).fontColor($r('app.color.text_sub'))
          .width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })

        Row() {
          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.person')).fontSize(12).fontColor([$r('app.color.text_hint')])
            Text(post.author).fontSize(11).fontColor($r('app.color.text_hint'))
          }
          Blank()
          // 🌟 关注作者按钮
          Text(this.isFollowed(post.author) ? '已关注' : '+ 关注')
            .fontSize(10)
            .fontColor(this.isFollowed(post.author) ? $r('app.color.text_sub') : Color.White)
            .backgroundColor(this.isFollowed(post.author) ? $r('app.color.field_bg') : '#3F7EF6')
            .padding({ left: 10, right: 10, top: 3, bottom: 3 })
            .borderRadius(10)
            .onClick(() => this.toggleFollow(post.author))
        }.width('100%')
      }
      .width('100%').alignItems(HorizontalAlign.Start)
      .onClick(() => {
        router.pushUrl({ url: 'pages/social/PostDetailPage', params: { postId: post.id } })
      })

      Divider().color($r('app.color.divider_color')).margin({ top: 8, bottom: 8 })

      // 底部操作区：点赞 / 评论 / 收藏
      Row() {
        Row({ space: 4 }) {
          // 🌟 点赞后变成红色实心爱心
          SymbolGlyph(post.liked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
            .fontSize(16)
            .fontColor([post.liked ? '#EF4444' : $r('app.color.text_sub')])
          Text(`${post.likes}`).fontSize(12).fontColor(post.liked ? '#EF4444' : $r('app.color.text_sub'))
        }
        .onClick(() => this.toggleLike(post))
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })

        Blank()

        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.message')).fontSize(16).fontColor([$r('app.color.text_sub')])
          Text(`${post.comments}`).fontSize(12).fontColor($r('app.color.text_sub'))
        }
        .onClick(() => {
          // 🌟 跳到详情页查看和发送评论
          router.pushUrl({ url: 'pages/social/PostDetailPage', params: { postId: post.id } })
        })
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })

        Blank()

        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.star'))
            .fontSize(16)
            .fontColor([this.isFav(post) ? '#E8A33E' : $r('app.color.text_sub')])
          Text(this.isFav(post) ? '已收藏' : '收藏')
            .fontSize(12).fontColor(this.isFav(post) ? '#E8A33E' : $r('app.color.text_sub'))
        }
        .onClick(() => this.toggleFav(post))
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      }.width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 5 })
  }

  build() {
    Column() {
      Row() {
        Text('发现')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_main'))
        Blank()
        // 🌟 有未查看的帖子时提供一键已读
        if (this.newCount() > 0) {
          Text('一键已读')
            .fontSize(14).fontColor($r('app.color.primary'))
            .margin({ right: 14 })
            .onClick(() => this.markAllRead())
        }
        // 右上角发布按钮，与各页面的蓝色新增按钮风格统一
        Button('+ 发布')
          .height(36)
          .backgroundColor('#3F7EF6')
          .fontSize(14)
          .onClick(() => this.openPublish())
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 30, bottom: 14 })

      // 分类筛选
      Row({ space: 8 }) {
        this.categoryChip('全部')
        this.categoryChip('关注')
        this.categoryChip('学习分享')
        this.categoryChip('求助')
      }
      .width('100%')
      .padding({ left: 20, bottom: 12 })

      if (this.curCategory === '关注') {
        // 🌟 关注页：按作者分组展示（作者头部 + TA 的帖子在下面），参考社区个人主页
        List({ space: 12 }) {
          ForEach(this.followList, (author: string) => {
            ListItem() {
              Column({ space: 12 }) {
                this.authorHeader(author)
                ForEach(this.postsOf(author), (post: PostItem) => {
                  this.postCard(post)
                }, (post: PostItem) => `${post.id}_${post.likes}_${post.liked}_${post.comments}`)
                if (this.postsOf(author).length === 0) {
                  Text('TA 还没有发过帖子')
                    .fontSize(13).fontColor($r('app.color.text_hint'))
                    .width('100%').textAlign(TextAlign.Center)
                    .padding({ top: 12, bottom: 12 })
                    .backgroundColor($r('app.color.card_bg'))
                    .borderRadius(16)
                }
              }.width('100%')
            }
          }, (author: string) => author)
          if (this.followList.length === 0) {
            ListItem() {
              this.emptyTip('还没有关注的作者，去帖子里点「+ 关注」吧')
            }
          }
        }
        .width('90%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      } else {
        List({ space: 12 }) {
          ForEach(this.getFiltered(), (post: PostItem) => {
            ListItem() {
              this.postCard(post)
            }
          }, (post: PostItem) => `${post.id}_${post.likes}_${post.liked}_${post.comments}`)
          if (this.getFiltered().length === 0) {
            ListItem() {
              this.emptyTip('暂时没有帖子')
            }
          }
        }
        .width('90%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
