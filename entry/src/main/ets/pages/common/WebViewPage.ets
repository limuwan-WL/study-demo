import router from '@ohos.router';
import { promptAction, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';

@Entry
@Component
struct WebViewPage {
  @State url: string = '';
  // 🌟 页面标题：优先取跳转方传入的标题（如收藏项标题），为空时回退站点名
  @State pageTitle: string = '';
  // 🌟 视频全屏状态：全屏时隐藏顶部栏，让网页（含视频播放器）铺满整个窗口
  @State isFullScreen: boolean = false;
  // 🌟 是否正在浏览 B 站（用于区分站内跳转和站外跳转）
  private inBilibili: boolean = false;
  // 必须实例化一个控制器
  controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear() {
    let params = router.getParams() as Record<string, string>;
    if (params && params['url']) {
      this.url = params['url'];
    }
    // 🌟 每次进入（含切换收藏项）都重新取标题，旧页面实例不会复用，避免残留上一个标题
    if (params && params['title']) {
      this.pageTitle = params['title'];
    }
  }

  aboutToDisappear() {
    // 🌟 防御：全屏横屏状态下直接退出页面时，恢复屏幕方向
    window.getLastWindow(getContext(this)).then((win: window.Window) => {
      win.setPreferredOrientation(window.Orientation.UNSPECIFIED)
    })
  }

  // 🌟 返回上一页：进入方式统一为 pushUrl，这里用 router.back() 出页面（回到进入前的收藏/课程页）
  // 不再用网页历史后退：站点 302 重定向会让 accessBackward() 一直为 true，导致永远走不到 router.back()
  goBack() {
    if (this.isFullScreen) {
      this.exitFullScreen()
      return
    }
    router.back()
  }

  // 🌟 系统返回键/侧滑：与顶部返回保持一致，保证能回到进入前的页面
  onBackPress(): boolean {
    this.goBack()
    return true
  }

  // 🌟 进入视频全屏：隐藏顶栏 + 切横屏（H5 播放器的全屏按钮会触发 onFullScreenEnter）
  enterFullScreen() {
    this.isFullScreen = true
    window.getLastWindow(getContext(this)).then((win: window.Window) => {
      win.setPreferredOrientation(window.Orientation.LANDSCAPE)
    })
  }

  // 🌟 退出视频全屏：恢复顶栏 + 恢复竖屏跟随
  exitFullScreen() {
    this.isFullScreen = false
    window.getLastWindow(getContext(this)).then((win: window.Window) => {
      win.setPreferredOrientation(window.Orientation.UNSPECIFIED)
    })
  }

  // 🌟 判断是否为 B 站相关域名（站内跳转白名单）
  isBilibiliUrl(url: string): boolean {
    const hosts: string[] = ['bilibili.com', 'b23.tv', 'acg.tv', 'hdslb.com', 'bilivideo.com', 'bilivideo.cn', 'biliapi.net', 'biliapi.com']
    return hosts.some((h: string) => url.indexOf(h) >= 0)
  }

  // 🌟 从网址取站点域名（去掉协议、端口后的首段路径和 www. 前缀）
  hostOf(url: string): string {
    let s = url
    const scheme = s.indexOf('://')
    if (scheme >= 0) {
      s = s.substring(scheme + 3)
    }
    const slash = s.indexOf('/')
    if (slash >= 0) {
      s = s.substring(0, slash)
    }
    if (s.startsWith('www.')) {
      s = s.substring(4)
    }
    return s
  }

  // 🌟 顶部标题取值规则：跳转方传入的标题（收藏项标题）→ 站点名（B 站系列统一为「哔哩哔哩」）→「网页详情」
  headerTitle(): string {
    if (this.pageTitle !== '') {
      return this.pageTitle
    }
    if (this.isBilibiliUrl(this.url)) {
      return '哔哩哔哩'
    }
    const host = this.hostOf(this.url)
    return host !== '' ? host : '网页详情'
  }

  // 🌟 链接失败提示：全页只保留这一条提示，且 2 秒内不重复弹，避免多条提示叠加
  private lastTipAt: number = 0

  notifyLinkIssue() {
    const now = Date.now()
    if (now - this.lastTipAt < 2000) {
      return
    }
    this.lastTipAt = now
    promptAction.showToast({ message: '未找到可打开此链接的应用' })
  }

  // 🌟 站外跳转：唤起系统浏览器或目标应用
  // silentFail：网页内「打开App」这类深链失败时不提示——页面自身已有「App内打开/下载App」引导，避免重复提示
  openOutside(url: string, silentFail: boolean = false) {
    let context = getContext(this) as common.UIAbilityContext
    context.openLink(url).catch(() => {
      if (!silentFail) {
        this.notifyLinkIssue()
      }
    })
  }

  build() {
    Column() {
      // 顶部返回栏（视频全屏时隐藏，让网页铺满屏幕）
      if (!this.isFullScreen) {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .onClick(() => {
              // 🌟 顶部返回箭头 = 退出网页页，回到进入前的页面（与 pushUrl 进入方式匹配）
              this.goBack()
            })
          Text(this.headerTitle()).fontSize(18).margin({ left: 16, right: 16 }).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        }
        .width('100%')
        .height(50)
        .padding({ left: 16 })
        .backgroundColor($r('app.color.card_bg'))
      }

      // Web组件加载网页：直接用真实网址初始化（占位页+手动loadUrl会与拦截器产生竞态导致页面空白）
      Web({ src: this.url, controller: this.controller })
        .width('100%')
        .layoutWeight(1)
        .domStorageAccess(true) // 允许使用本地存储
        .javaScriptAccess(true) // 允许执行 JavaScript：视频播放器、页面跳转都依赖 JS（ArkWeb 默认禁止，不开网页能显示但无法交互）
        .onControllerAttached(() => {
          // 🌟 伪装标准安卓 Chrome 移动端 UA：B 站等视频网站按 UA 识别环境，默认 ArkWeb UA 会被
          // 判定为未知浏览器而降级播放器，导致暂停/全屏等控制条交互全部失灵；标准 UA 下播放器功能完整
          this.controller.setCustomUserAgent('Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36')
          // 🌟 初始页面可能已用旧 UA 发起请求，这里用新 UA 重新加载一次，确保站点返回完整版页面
          this.controller.refresh()
        })
        // 🌟 站内外跳转拦截：站内继续内嵌打开，站外交给系统浏览器/目标应用
        .onLoadIntercept((event) => {
          let url = event.data.getRequestUrl()
          if (!event.data.isMainFrame()) {
            return false // 子资源（图片/脚本/接口/子框架）一律放行
          }
          if (url.startsWith('about:') || url.startsWith('data:') || url.startsWith('blob:') || url.startsWith('javascript:')) {
            return true // 占位页/页内协议：不加载也不做站外跳转
          }
          if (!url.startsWith('http://') && !url.startsWith('https://')) {
            // 🌟 站外深链（bilibili:// 等）：尝试唤起对应 App（页面里的「打开」按钮）
            // 失败不提示：网页自身已有「App内打开 / 下载App」引导，再弹一条就重复了
            this.openOutside(url, true)
            return true
          }
          if (this.isBilibiliUrl(url)) {
            // 🌟 站内跳转：B 站相关页面在当前内嵌网页里继续打开
            this.inBilibili = true
            return false
          }
          if (this.inBilibili) {
            // 🌟 站外跳转：B 站页面里点击的外部链接，交给系统浏览器打开
            this.openOutside(url)
            return true
          }
          // 非浏览B站场景（如百度）保持默认：所有页面都在内嵌网页里打开
          return false
        })
        // 🌟 主文档加载失败（如 B 站风控/网络异常）时改用系统浏览器打开，避免停在空白页
        // 提示统一由 openOutside 在真正失败时给出，这里不再单独弹一条，避免两条提示叠加
        .onErrorReceive((event) => {
          if (event.request.isMainFrame()) {
            this.openOutside(event.request.getRequestUrl())
          }
        })
        // 🌟 新窗口链接（target="_blank"）：ArkWeb 默认点击无反应，这里直接在当前内嵌网页里打开
        .multiWindowAccess(true)
        .onWindowNew((event) => {
          this.controller.loadUrl(event.targetUrl)
        })
        // 🌟 H5 视频全屏：ArkWeb 不会自动铺满屏幕，需要在此回调里自行处理全屏 UI
        .onFullScreenEnter(() => {
          this.enterFullScreen()
        })
        // 🌟 网页端退出全屏（播放器按钮）时恢复页面布局
        .onFullScreenExit(() => {
          this.exitFullScreen()
        })
    }
    .width('100%')
    .height('100%')
  }
}