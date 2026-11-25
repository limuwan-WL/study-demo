import router from '@ohos.router';
import { TodoItem, NoteItem, FavItem, PostItem } from '../../model/DataModel';
import { Permission } from '../../model/PermissionModel';

class SearchResult {
  type: string = ''
  typeColor: string = ''
  title: string = ''
  detail: string = ''
  target: string = ''
  key: string = ''

  constructor(type: string, typeColor: string, title: string, detail: string, target: string, key: string) {
    this.type = type
    this.typeColor = typeColor
    this.title = title
    this.detail = detail
    this.target = target
    this.key = key
  }
}

@Entry
@Component
struct SearchPage {
  @State searchText: string = ''
  @StorageLink('todoList') todoList: TodoItem[] = []
  @StorageLink('noteList') noteList: NoteItem[] = []
  @StorageLink('favList') favList: FavItem[] = []
  @StorageLink('postList') postList: PostItem[] = []

  // 🌟 全局搜索：同时检索待办、笔记、收藏、帖子，结果标注来源
  getResults(): SearchResult[] {
    let kw = this.searchText.trim()
    if (kw === '') {
      return []
    }
    let res: SearchResult[] = []

    this.todoList.filter((t: TodoItem) => t.content.includes(kw)).forEach((t: TodoItem) => {
      res.push(new SearchResult('待办', '#3F7EF6', t.content, t.isDone ? '状态：已完成' : '状态：未完成', 'pages/study/TodoPage', t.id))
    })

    // 🌟 与笔记页保持一致：回收站笔记与不可见笔记不进入全局搜索结果
    this.noteList.filter((n: NoteItem) =>
      !n.isDeleted && Permission.canViewNote(n) && (n.title.includes(kw) || n.content.includes(kw)))
      .forEach((n: NoteItem) => {
        let detail = n.content === '' ? '（无正文）' : n.content
        res.push(new SearchResult('笔记', '#E8A33E', n.title, detail, 'pages/study/NoteDetailPage', n.id))
      })

    this.favList.filter((f: FavItem) => f.title.includes(kw)).forEach((f: FavItem) => {
      res.push(new SearchResult('收藏', '#E74846', f.title, f.type === 'post' ? '来自发现页的帖子' : f.url, 'pages/study/FavoritesPage', f.id))
    })

    this.postList.filter((p: PostItem) => p.title.includes(kw) || p.brief.includes(kw)).forEach((p: PostItem) => {
      res.push(new SearchResult('帖子', '#8B5CF6', p.title, `${p.category} · ${p.author}`, 'pages/social/PostDetailPage', p.id))
    })

    return res
  }

  go(r: SearchResult) {
    // NoteDetailPage 用 id，PostDetailPage 用 postId，其余页面忽略参数
    router.pushUrl({ url: r.target, params: { id: r.key, postId: r.key } })
  }

  @Builder
  resultRow(r: SearchResult) {
    Row() {
      Text(r.type)
        .fontSize(10).fontColor(Color.White)
        .backgroundColor(r.typeColor)
        .padding({ left: 6, right: 6, top: 2, bottom: 2 }).borderRadius(6)
      Column({ space: 4 }) {
        Text(r.title).fontSize(15).fontColor($r('app.color.text_main'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(r.detail).fontSize(12).fontColor($r('app.color.text_sub'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })

      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.text_hint')])
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
    .onClick(() => this.go(r))
  }

  build() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([$r('app.color.text_main')]).onClick(() => router.back())
        Text('搜索').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 16 })
      }.width('100%').height(60).padding({ left: 16 })

      Search({ value: this.searchText, placeholder: '搜索待办 / 笔记 / 收藏 / 帖子' })
        .width('90%').height(40).backgroundColor($r('app.color.card_bg'))
        .margin({ top: 6, bottom: 14 })
        .onChange((v: string) => this.searchText = v)

      List({ space: 10 }) {
        ForEach(this.getResults(), (r: SearchResult) => {
          ListItem() {
            this.resultRow(r)
          }
        }, (r: SearchResult) => r.type + r.key)
        if (this.searchText.trim() === '') {
          ListItem() {
            Column({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(40).fontColor([$r('app.color.text_hint')])
              Text('输入关键词，同时搜索待办、笔记、收藏和帖子')
                .fontSize(14).fontColor($r('app.color.text_sub'))
            }.width('100%').padding({ top: 80 })
          }
        } else if (this.getResults().length === 0) {
          ListItem() {
            Text('未找到相关内容')
              .fontSize(14).fontColor($r('app.color.text_sub'))
              .width('100%').textAlign(TextAlign.Center).padding({ top: 80 })
          }
        }
      }
      .width('90%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }
}
