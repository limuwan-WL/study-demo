import { http } from '@kit.NetworkKit';

// 🌟 账号改为由 MySQL 后端统一存储：App 通过 HTTP 调用 server/ 提供的接口
// 接口地址可通过 AppStorage 的 apiBaseUrl 配置（模拟器默认 10.0.2.2，真机改成电脑局域网 IP）
const DEFAULT_BASE_URL: string = 'http://10.0.2.2:3000'

export interface AccountRow {
  id: number
  accountNo: string
  role: string
  nickname: string
}

export interface AuthResult {
  ok: boolean
  // ok / not_found / bad_password / duplicate / invalid / offline / error
  code: string
  message: string
  account: AccountRow | null
}

interface ApiAccount {
  id?: number
  accountNo?: string
  role?: string
  nickname?: string
}

interface ApiResp {
  ok?: boolean
  code?: string
  message?: string
  account?: ApiAccount
  accounts?: ApiAccount[]
}

function baseUrl(): string {
  let url = AppStorage.get<string>('apiBaseUrl')
  return url === undefined || url === '' ? DEFAULT_BASE_URL : url
}

function toAccount(item: ApiAccount): AccountRow {
  return {
    id: item.id === undefined ? 0 : item.id,
    accountNo: item.accountNo === undefined ? '' : item.accountNo,
    role: item.role === undefined ? '' : item.role,
    nickname: item.nickname === undefined ? '' : item.nickname
  }
}

async function request(path: string, method: http.RequestMethod, body: object | null): Promise<ApiResp> {
  const req = http.createHttp()
  try {
    const options: http.HttpRequestOptions = {
      method: method,
      header: { 'Content-Type': 'application/json' },
      connectTimeout: 5000,
      readTimeout: 5000
    }
    if (body !== null) {
      options.extraData = JSON.stringify(body)
    }
    const res = await req.request(baseUrl() + path, options)
    if (res.responseCode !== 200) {
      return { ok: false, code: 'error', message: `账号服务异常（${res.responseCode}）` }
    }
    const text: string = typeof res.result === 'string' ? res.result : JSON.stringify(res.result)
    return JSON.parse(text) as ApiResp
  } catch (e) {
    return { ok: false, code: 'offline', message: '无法连接账号服务器，请检查网络与服务是否启动' }
  } finally {
    req.destroy()
  }
}

function toResult(resp: ApiResp): AuthResult {
  let account: AccountRow | null = resp.account === undefined ? null : toAccount(resp.account)
  let code: string = resp.code === undefined ? 'error' : resp.code
  let message: string = resp.message === undefined ? '请求失败' : resp.message
  return { ok: resp.ok === true, code: code, message: message, account: account }
}

export class AccountStore {
  // 兼容原有调用：账号改存 MySQL 后无需本地初始化
  static init(): void {
  }

  // 注册：由后端写入 MySQL，学号/教工号唯一
  static async register(accountNo: string, password: string, role: string, nickname: string): Promise<AuthResult> {
    const body: Record<string, string> = {
      'accountNo': accountNo,
      'password': password,
      'role': role,
      'nickname': nickname
    }
    return toResult(await request('/api/auth/register', http.RequestMethod.POST, body))
  }

  // 登录：后端校验账号与密码哈希
  static async login(accountNo: string, password: string): Promise<AuthResult> {
    const body: Record<string, string> = { 'accountNo': accountNo, 'password': password }
    return toResult(await request('/api/auth/login', http.RequestMethod.POST, body))
  }

  // 修改密码：服务端校验旧密码哈希后才更新
  static async changePassword(accountNo: string, oldPassword: string, newPassword: string): Promise<boolean> {
    const body: Record<string, string> = {
      'accountNo': accountNo,
      'password': oldPassword,
      'newPassword': newPassword
    }
    const resp = await request('/api/auth/password', http.RequestMethod.POST, body)
    return resp.ok === true
  }

  // 忘记密码重置：未登录场景，仅校验账号存在与身份一致（演示用途）
  static async resetPassword(accountNo: string, newPassword: string, role: string): Promise<boolean> {
    const body: Record<string, string> = { 'accountNo': accountNo, 'newPassword': newPassword, 'role': role }
    const resp = await request('/api/auth/reset', http.RequestMethod.POST, body)
    return resp.ok === true
  }

  // 账号列表：从 MySQL 读取
  static async listAccounts(): Promise<AccountRow[]> {
    const resp = await request('/api/auth/accounts', http.RequestMethod.GET, null)
    if (resp.accounts === undefined) {
      return []
    }
    const list: AccountRow[] = []
    for (let i = 0; i < resp.accounts.length; i++) {
      list.push(toAccount(resp.accounts[i]))
    }
    return list
  }

  // 按学号/教工号取单个账号（列表接口数据量小，直接查找）
  static async getAccount(accountNo: string): Promise<AccountRow | null> {
    const list = await AccountStore.listAccounts()
    for (let i = 0; i < list.length; i++) {
      if (list[i].accountNo === accountNo) {
        return list[i]
      }
    }
    return null
  }

  // 注销账号：校验密码后从 MySQL 物理删除
  static async remove(accountNo: string, password: string): Promise<boolean> {
    const body: Record<string, string> = { 'accountNo': accountNo, 'password': password }
    const resp = await request('/api/auth/delete', http.RequestMethod.POST, body)
    return resp.ok === true
  }
}
