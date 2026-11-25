import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { PostItem, FavItem, CommentItem, userLevel, levelColor } from '../../model/DataModel';

const CATEGORY_COLOR: Record<string, string> = { '学习分享': '#3F7EF6', '求助': '#E8A33E' };

// 🌟 评论线程：一条主评论 + 挂在它下方的回复
class CommentThread {
  root: CommentItem = new CommentItem('', '')
  replies: CommentItem[] = []
}

@Entry
@Component
struct PostDetailPage {
  @StorageLink('postList') postList: PostItem[] = []
  @StorageLink('favList') favList: FavItem[] = []
  @StorageLink('nickname') nickname: string = '张同学'
  // 🌟 评论：按帖子 id 分组持久化
  @StorageLink('commentMap') commentMap: Record<string, CommentItem[]> = {}
  // 🌟 关注的作者列表（持久化）
  @StorageLink('followList') followList: string[] = []
  @State inputComment: string = ''
  // 🌟 当前回复的目标（replyTo 作者名用于展示，replyToId 定位挂载的父评论）
  @State replyTo: string = ''
  @State replyToId: string = ''
  // 🌟 展开了回复的评论线程 id 列表
  @State expandedIds: string[] = []
  postId: string = ''

  aboutToAppear() {
    let params = router.getParams() as Record<string, string>;
    if (params && params['postId']) {
      this.postId = params['postId'];
    }
    // 🌟 查看帖子详情后把该帖子标记为已查看，发现页红点数随之减少
    if (this.postId !== '') {
      let readIds = AppStorage.get<string[]>('readPostIds') ?? [];
      if (readIds.indexOf(this.postId) < 0) {
        AppStorage.setOrCreate('readPostIds', [this.postId].concat(readIds));
      }
    }
  }

  getPost(): PostItem | undefined {
    return this.postList.find((p: PostItem) => p.id === this.postId)
  }

  // 🌟 当前帖子的评论列表（新评论在前）
  comments(): CommentItem[] {
    let list = this.commentMap[this.postId]
    return list === undefined ? [] : list
  }

  isFav(post: PostItem): boolean {
    return this.favList.some((f: FavItem) => f.type === 'post' && f.postId === post.id)
  }

  isFollowed(author: string): boolean {
    return this.followList.indexOf(author) >= 0
  }

  // 🌟 关注 / 取消关注作者
  toggleFollow(author: string) {
    if (this.isFollowed(author)) {
      this.followList = this.followList.filter((a: string) => a !== author)
      promptAction.showToast({ message: '已取消关注' })
    } else {
      this.followList = [author, ...this.followList]
      promptAction.showToast({ message: `已关注 ${author}` })
    }
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

  // 🌟 发送评论：写入 commentMap 并让帖子评论数 +1
  sendComment() {
    let content = this.inputComment.trim()
    if (content === '') {
      promptAction.showToast({ message: '评论内容不能为空' })
      return
    }
    let post = this.getPost()
    if (post === undefined) {
      return
    }
    let author = this.nickname === '' ? '我' : this.nickname
    let c = new CommentItem(author, content, this.replyTo, this.replyToId)
    // 整体替换 map，保证 @StorageLink 触发刷新
    let newList = [c, ...this.comments()]
    let newMap: Record<string, CommentItem[]> = {}
    Object.keys(this.commentMap).forEach((k: string) => {
      newMap[k] = this.commentMap[k]
    })
    newMap[this.postId] = newList
    this.commentMap = newMap

    this.postList = this.postList.map((p: PostItem) => {
      if (p.id === this.postId) {
        p.comments = p.comments + 1
      }
      return p
    })
    this.inputComment = ''
    this.replyTo = ''
    this.replyToId = ''
    promptAction.showToast({ message: '评论成功' })
  }

  @Builder
  emptyTip(msg: string) {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.inbox')).fontSize(40).fontColor([$r('app.color.text_hint')])
      Text(msg).fontSize(14).fontColor($r('app.color.text_sub'))
    }.width('100%').padding({ top: 120 })
  }

  // 🌟 兼容旧数据：老评论可能没有新字段（undefined）
  safeStr(v: string): string {
    return typeof v === 'string' ? v : ''
  }

  // 🌟 把平铺评论整理成线程：主评论 + 挂在下面的回复（两遍扫描，兼容回复出现在父评论前面的情况）
  getThreads(): CommentThread[] {
    // 🌟 读取折叠状态建立依赖：切换折叠/展开时让 ForEach 重新 diff
    if (this.expandedIds.length === -1) {
      return []
    }
    let list = this.comments()
    let threads: CommentThread[] = []
    let byId: Record<string, CommentThread> = {}
    let resolveParent = (c: CommentItem): string => {
      let rt = this.safeStr(c.replyToId)
      if (rt === '' && this.safeStr(c.replyToAuthor) !== '') {
        // 旧数据只有作者名：挂到同作者的第一条评论下
        let parent = list.find((p: CommentItem) => p.author === c.replyToAuthor && p.id !== c.id)
        if (parent !== undefined) {
          rt = parent.id
        }
      }
      return rt
    }
    list.forEach((c: CommentItem) => {
      if (resolveParent(c) === '') {
        let t = new CommentThread()
        t.root = c
        threads.push(t)
        byId[c.id] = t
      }
    })
    list.forEach((c: CommentItem) => {
      if (byId[c.id] !== undefined) {
        return
      }
      let t = byId[resolveParent(c)]
      if (t === undefined) {
        let t2 = new CommentThread()
        t2.root = c
        threads.push(t2)
        byId[c.id] = t2
      } else {
        t.replies.push(c)
      }
    })
    return threads
  }

  isExpanded(rootId: string): boolean {
    return this.expandedIds.indexOf(rootId) >= 0
  }

  // 🌟 折叠时只显示前 2 条回复
  visibleReplies(t: CommentThread): CommentItem[] {
    return this.isExpanded(t.root.id) ? t.replies : t.replies.slice(0, 2)
  }

  toggleExpanded(rootId: string) {
    if (this.isExpanded(rootId)) {
      this.expandedIds = this.expandedIds.filter((x: string) => x !== rootId)
    } else {
      this.expandedIds = [rootId, ...this.expandedIds]
    }
  }

  // 🌟 是否为回复类评论（带「回复 @某某」标记）
  isReply(c: CommentItem): boolean {
    return this.safeStr(c.replyToAuthor) !== ''
  }

  // 🌟 评论点赞 / 点踩（再点一次取消；赞和踩互斥）
  voteComment(c: CommentItem, vote: number) {
    let newList = this.comments().map((x: CommentItem) => {
      if (x.id === c.id) {
        if (x.myVote === vote) {
          if (vote === 1) {
            x.likes = Math.max(0, x.likes - 1)
          } else {
            x.dislikes = Math.max(0, x.dislikes - 1)
          }
          x.myVote = 0
        } else {
          if (vote === 1) {
            x.likes = x.likes + 1
            if (x.myVote === -1) {
              x.dislikes = Math.max(0, x.dislikes - 1)
            }
          } else {
            x.dislikes = x.dislikes + 1
            if (x.myVote === 1) {
              x.likes = Math.max(0, x.likes - 1)
            }
          }
          x.myVote = vote
        }
      }
      return x
    })
    let newMap: Record<string, CommentItem[]> = {}
    Object.keys(this.commentMap).forEach((k: string) => {
      newMap[k] = this.commentMap[k]
    })
    newMap[this.postId] = newList
    this.commentMap = newMap
  }

  // 🌟 线程 key：带上主评论/回复的点赞状态与折叠状态，保证投票、展开收起后 UI 刷新
  threadKey(t: CommentThread): string {
    let sig = t.replies.map((r: CommentItem) => `${r.likes}_${r.dislikes}_${r.myVote}`).join('-')
    return `${t.root.id}_${t.root.likes}_${t.root.dislikes}_${t.root.myVote}_${t.replies.length}_${this.isExpanded(t.root.id) ? 1 : 0}_${sig}`
  }

  // 🌟 用户等级徽章：LV0~LV6，颜色随等级递进（B 站样式小圆角标签）
  @Builder
  levelBadge(name: string, size: number) {
    Text(`LV${userLevel(name)}`)
      .fontSize(size).fontWeight(FontWeight.Bold).fontColor(Color.White)
      .backgroundColor(levelColor(userLevel(name)))
      .borderRadius(3)
      .padding({ left: 4, right: 4, top: 1, bottom: 1 })
  }

  // 🌟 评论行（B 站平铺样式：昵称 + 等级徽章，无头像；rootId 用于「回复」时定位挂载点）
  @Builder
  commentRow(c: CommentItem, rootId: string) {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text(c.author).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_sub'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        this.levelBadge(c.author, 10)
      }
      if (this.safeStr(c.replyToAuthor) !== '') {
        Text(`回复 @${this.safeStr(c.replyToAuthor)}`)
          .fontSize(12).fontWeight(FontWeight.Medium).fontColor('#3F7EF6')
      }
      Text(c.content).fontSize(15).fontColor($r('app.color.text_main')).width('100%')
      // 元信息行：时间 + 点赞点踩 + 回复
      Row({ space: 16 }) {
        Text(c.time).fontSize(12).fontColor($r('app.color.text_hint'))
        Row({ space: 4 }) {
          SymbolGlyph(c.myVote === 1 ? $r('sys.symbol.hand_thumbsup_fill') : $r('sys.symbol.hand_thumbsup'))
            .fontSize(13)
            .fontColor([c.myVote === 1 ? '#3F7EF6' : $r('app.color.text_sub')])
          Text(`${c.likes}`)
            .fontSize(12).fontColor(c.myVote === 1 ? '#3F7EF6' : $r('app.color.text_sub'))
        }
        .onClick(() => this.voteComment(c, 1))
        Row({ space: 4 }) {
          SymbolGlyph(c.myVote === -1 ? $r('sys.symbol.hand_thumbsdown_fill') : $r('sys.symbol.hand_thumbsdown'))
            .fontSize(13)
            .fontColor([c.myVote === -1 ? '#E8A33E' : $r('app.color.text_sub')])
          Text(`${c.dislikes}`)
            .fontSize(12).fontColor(c.myVote === -1 ? '#E8A33E' : $r('app.color.text_sub'))
        }
        .onClick(() => this.voteComment(c, -1))
        Text('回复').fontSize(12).fontColor($r('app.color.text_sub'))
          .onClick(() => {
            this.replyTo = c.author
            this.replyToId = rootId
          })
        Blank()
      }.width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 10, bottom: 10 })
  }

  // 🌟 回复行：第一行「小头像 + 昵称 + 等级 + 回复 @某某」，正文独占第二行，避免串行挤压
  @Builder
  replyRow(r: CommentItem, rootId: string) {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text(r.author.slice(0, 1))
          .fontSize(10).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .width(24).height(24).backgroundColor('#3F7EF6')
          .borderRadius(12).textAlign(TextAlign.Center)
        Column({ space: 5 }) {
          // 第一行：回复人与被回复人
          Row({ space: 6 }) {
            Text(r.author).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_sub'))
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: '45%' })
            this.levelBadge(r.author, 9)
            if (this.safeStr(r.replyToAuthor) !== '') {
              Text(`回复 @${this.safeStr(r.replyToAuthor)}`)
                .fontSize(12).fontWeight(FontWeight.Medium).fontColor('#3F7EF6')
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          // 第二行：回复正文完整展示
          Text(r.content).fontSize(14).fontColor($r('app.color.text_main')).width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      // 元信息行缩进到与正文左对齐（小头像 24 + 间距 6）
      Row({ space: 16 }) {
        Text(r.time).fontSize(12).fontColor($r('app.color.text_hint'))
        Row({ space: 4 }) {
          SymbolGlyph(r.myVote === 1 ? $r('sys.symbol.hand_thumbsup_fill') : $r('sys.symbol.hand_thumbsup'))
            .fontSize(13)
            .fontColor([r.myVote === 1 ? '#3F7EF6' : $r('app.color.text_sub')])
          Text(`${r.likes}`)
            .fontSize(12).fontColor(r.myVote === 1 ? '#3F7EF6' : $r('app.color.text_sub'))
        }
        .onClick(() => this.voteComment(r, 1))
        Row({ space: 4 }) {
          SymbolGlyph(r.myVote === -1 ? $r('sys.symbol.hand_thumbsdown_fill') : $r('sys.symbol.hand_thumbsdown'))
            .fontSize(13)
            .fontColor([r.myVote === -1 ? '#E8A33E' : $r('app.color.text_sub')])
          Text(`${r.dislikes}`)
            .fontSize(12).fontColor(r.myVote === -1 ? '#E8A33E' : $r('app.color.text_sub'))
        }
        .onClick(() => this.voteComment(r, -1))
        Text('回复').fontSize(12).fontColor($r('app.color.text_sub'))
          .onClick(() => {
            this.replyTo = r.author
            this.replyToId = rootId
          })
        Blank()
      }
      .width('100%')
      .padding({ left: 30 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 6, bottom: 6 })
  }

  // 🌟 评论线程：主评论 + 折叠的回复区（B 站样式：回复平铺，无底色容器）
  @Builder
  commentThread(t: CommentThread) {
    Column() {
      // 🌟 主评论缺失时的孤儿回复（找不到父评论）也用回复样式
      if (this.isReply(t.root)) {
        this.replyRow(t.root, t.root.id)
      } else {
        this.commentRow(t.root, t.root.id)
      }
      if (t.replies.length > 0) {
        Column() {
          ForEach(this.visibleReplies(t), (r: CommentItem) => {
            this.replyRow(r, t.root.id)
          }, (r: CommentItem) => `${r.id}_${r.likes}_${r.dislikes}_${r.myVote}`)
          if (t.replies.length > 2) {
            Text(this.isExpanded(t.root.id) ? '收起回复' : `共${t.replies.length}条回复，点击查看`)
              .fontSize(12).fontColor($r('app.color.text_sub'))
              .width('100%')
              .padding({ top: 4, bottom: 4 })
              .onClick(() => this.toggleExpanded(t.root.id))
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 34 })
        .margin({ top: 2 })
      }
    }.width('100%')
  }

  build() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([$r('app.color.text_main')]).onClick(() => router.back())
        Text('帖子详情').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 16 })
      }.width('100%').height(60).padding({ left: 16 })

      if (this.getPost() === undefined) {
        this.emptyTip('帖子不存在或已被删除')
      } else {
        // 内容 + 评论区整体可滚动
        Scroll() {
          Column({ space: 10 }) {
            Row() {
              Text(this.getPost()!.category)
                .fontSize(10).fontColor(Color.White)
                .backgroundColor(CATEGORY_COLOR[this.getPost()!.category])
                .padding({ left: 6, right: 6, top: 2, bottom: 2 }).borderRadius(6)
              Blank()
              Text(this.getPost()!.time).fontSize(11).fontColor($r('app.color.text_hint'))
            }.width('100%')

            Text(this.getPost()!.title)
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              .width('100%')

            Row() {
              Row({ space: 4 }) {
                SymbolGlyph($r('sys.symbol.person')).fontSize(12).fontColor([$r('app.color.text_hint')])
                Text(this.getPost()!.author).fontSize(12).fontColor($r('app.color.text_sub'))
                this.levelBadge(this.getPost()!.author, 9)
              }
              Blank()
              // 🌟 关注作者按钮
              Text(this.isFollowed(this.getPost()!.author) ? '已关注' : '+ 关注')
                .fontSize(11)
                .fontColor(this.isFollowed(this.getPost()!.author) ? $r('app.color.text_sub') : Color.White)
                .backgroundColor(this.isFollowed(this.getPost()!.author) ? $r('app.color.field_bg') : '#3F7EF6')
                .padding({ left: 12, right: 12, top: 4, bottom: 4 })
                .borderRadius(12)
                .onClick(() => this.toggleFollow(this.getPost()!.author))
            }.width('100%')

            Divider().color($r('app.color.divider_color'))

            Text(this.getPost()!.content)
              .fontSize(15).fontColor($r('app.color.text_body')).lineHeight(24)
              .width('100%')

            Divider().color($r('app.color.divider_color'))

            Row() {
              Row({ space: 4 }) {
                // 🌟 点赞后变成红色实心爱心
                SymbolGlyph(this.getPost()!.liked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
                  .fontSize(16)
                  .fontColor([this.getPost()!.liked ? '#EF4444' : $r('app.color.text_sub')])
                Text(`${this.getPost()!.likes}`)
                  .fontSize(12).fontColor(this.getPost()!.liked ? '#EF4444' : $r('app.color.text_sub'))
              }
              .onClick(() => this.toggleLike(this.getPost()!))
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })

              Blank()

              Row({ space: 4 }) {
                SymbolGlyph($r('sys.symbol.message')).fontSize(16).fontColor([$r('app.color.text_sub')])
                Text(`${this.comments().length}`).fontSize(12).fontColor($r('app.color.text_sub'))
              }
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })

              Blank()

              Row({ space: 4 }) {
                SymbolGlyph($r('sys.symbol.star'))
                  .fontSize(16)
                  .fontColor([this.isFav(this.getPost()!) ? '#E8A33E' : $r('app.color.text_sub')])
                Text(this.isFav(this.getPost()!) ? '已收藏' : '收藏')
                  .fontSize(12).fontColor(this.isFav(this.getPost()!) ? '#E8A33E' : $r('app.color.text_sub'))
              }
              .onClick(() => this.toggleFav(this.getPost()!))
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            }.width('100%')

            Divider().color($r('app.color.divider_color'))

            // 评论区
            Text(`全部评论 (${this.comments().length})`)
              .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              .width('100%')
              .margin({ top: 4 })

            if (this.comments().length === 0) {
              Text('还没有评论，快来抢沙发～')
                .fontSize(13).fontColor($r('app.color.text_hint'))
                .width('100%').textAlign(TextAlign.Center)
                .padding({ top: 20, bottom: 20 })
            } else {
              Column() {
                ForEach(this.getThreads(), (t: CommentThread) => {
                  this.commentThread(t)
                  Divider().color($r('app.color.divider_color'))
                }, (t: CommentThread) => this.threadKey(t))
              }.width('100%')
            }
          }
          .width('90%')
          .padding(20)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 14, bottom: 14 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)

        // 🌟 回复目标提示条（点击「取消」退出回复状态）
        if (this.replyTo !== '') {
          Row({ space: 8 }) {
            Text(`正在回复 @${this.replyTo}`)
              .fontSize(12).fontWeight(FontWeight.Medium).fontColor('#3F7EF6')
              .layoutWeight(1)
            Text('取消').fontSize(12).fontColor($r('app.color.text_sub')).onClick(() => {
              this.replyTo = ''
            })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.primary_weak'))
        }
        // 底部评论输入栏
        Row({ space: 10 }) {
          TextInput({ text: this.inputComment, placeholder: this.replyTo === '' ? '写下你的评论...' : `回复 @${this.replyTo}...` })
            .layoutWeight(1).height(42).fontSize(14)
            .backgroundColor($r('app.color.field_bg'))
            .onChange((v: string) => this.inputComment = v)
          Text('发送')
            .fontSize(14).fontColor(Color.White)
            .padding({ left: 18, right: 18, top: 10, bottom: 10 })
            .backgroundColor('#3F7EF6')
            .borderRadius(21)
            .onClick(() => this.sendComment())
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8, bottom: 8 })
        .backgroundColor($r('app.color.card_bg'))
      }
    }
    .width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }
}
