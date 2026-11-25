import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

// 🌟 账号数据库：学号 / 教工号注册登录的本地记忆
// 表 user_account：一个学号或教工号一行，密码只保存加盐哈希，不落明文
const DB_NAME: string = 'campus_helper.db'
const TABLE: string = 'user_account'
const CREATE_SQL: string = `CREATE TABLE IF NOT EXISTS ${TABLE} (` +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  'accountNo TEXT NOT NULL UNIQUE, ' +
  'passwordHash TEXT NOT NULL, ' +
  'role TEXT NOT NULL, ' +
  'nickname TEXT NOT NULL DEFAULT \'\', ' +
  'createdAt INTEGER NOT NULL)'

export interface AccountRow {
  id: number
  accountNo: string
  role: string
  nickname: string
}

export interface AuthResult {
  ok: boolean
  // ok / not_found / bad_password / duplicate / error
  code: string
  message: string
  account: AccountRow | null
}

// 密码加盐哈希：SHA-256(accountNo + ':' + password)，库中不保存明文
async function hashPassword(accountNo: string, password: string): Promise<string> {
  let md = cryptoFramework.createMd('SHA256')
  let bytes = new util.TextEncoder().encodeInto(accountNo + ':' + password)
  await md.update({ data: bytes })
  let digest = await md.digest()
  let hex: string = ''
  for (let i = 0; i < digest.data.length; i++) {
    let part = digest.data[i].toString(16)
    hex += part.length === 1 ? '0' + part : part
  }
  return hex
}

export class AccountStore {
  private static initPromise: Promise<relationalStore.RdbStore> | null = null

  // 在 EntryAbility.onCreate 或页面 aboutToAppear 调用，重复调用无副作用
  static init(context: common.Context): void {
    if (AccountStore.initPromise === null) {
      AccountStore.initPromise = AccountStore.open(context)
    }
  }

  private static async open(context: common.Context): Promise<relationalStore.RdbStore> {
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    }
    const store = await relationalStore.getRdbStore(context, config)
    await store.executeSql(CREATE_SQL)
    return store
  }

  private static async ready(): Promise<relationalStore.RdbStore> {
    if (AccountStore.initPromise === null) {
      throw new Error('账号数据库尚未初始化')
    }
    return await AccountStore.initPromise
  }

  // 按学号/教工号查询一条账号记录（含密码哈希），不存在返回 null
  private static async findRaw(accountNo: string): Promise<relationalStore.ValuesBucket | null> {
    const store = await AccountStore.ready()
    const rs = await store.querySql(
      `SELECT id, accountNo, passwordHash, role, nickname FROM ${TABLE} WHERE accountNo = ? LIMIT 1`, [accountNo])
    if (!rs.goToFirstRow()) {
      rs.close()
      return null
    }
    const bucket: relationalStore.ValuesBucket = {
      'id': rs.getLong(rs.getColumnIndex('id')),
      'accountNo': rs.getString(rs.getColumnIndex('accountNo')),
      'passwordHash': rs.getString(rs.getColumnIndex('passwordHash')),
      'role': rs.getString(rs.getColumnIndex('role')),
      'nickname': rs.getString(rs.getColumnIndex('nickname'))
    }
    rs.close()
    return bucket
  }

  static async exists(accountNo: string): Promise<boolean> {
    const raw = await AccountStore.findRaw(accountNo)
    return raw !== null
  }

  // 注册：学号/教工号已存在则返回 duplicate
  static async register(accountNo: string, password: string, role: string, nickname: string): Promise<AuthResult> {
    try {
      if (await AccountStore.exists(accountNo)) {
        return { ok: false, code: 'duplicate', message: '该学号/教工号已注册，请直接登录', account: null }
      }
      const store = await AccountStore.ready()
      const pwdHash = await hashPassword(accountNo, password)
      const bucket: relationalStore.ValuesBucket = {
        'accountNo': accountNo,
        'passwordHash': pwdHash,
        'role': role,
        'nickname': nickname,
        'createdAt': Date.now()
      }
      const rowId = await store.insert(TABLE, bucket)
      if (rowId < 0) {
        return { ok: false, code: 'error', message: '注册失败，请稍后重试', account: null }
      }
      const account: AccountRow = { id: rowId, accountNo: accountNo, role: role, nickname: nickname }
      return { ok: true, code: 'ok', message: '注册成功', account: account }
    } catch (e) {
      return { ok: false, code: 'error', message: '注册失败：' + (e as Error).message, account: null }
    }
  }

  // 登录：校验学号/教工号与密码
  static async login(accountNo: string, password: string): Promise<AuthResult> {
    try {
      const raw = await AccountStore.findRaw(accountNo)
      if (raw === null) {
        return { ok: false, code: 'not_found', message: '该学号/教工号尚未注册', account: null }
      }
      const pwdHash = await hashPassword(accountNo, password)
      if (pwdHash !== raw['passwordHash']) {
        return { ok: false, code: 'bad_password', message: '学号/教工号或密码错误', account: null }
      }
      const account: AccountRow = {
        id: raw['id'] as number,
        accountNo: raw['accountNo'] as string,
        role: raw['role'] as string,
        nickname: raw['nickname'] as string
      }
      return { ok: true, code: 'ok', message: '登录成功', account: account }
    } catch (e) {
      return { ok: false, code: 'error', message: '登录失败：' + (e as Error).message, account: null }
    }
  }

  // 修改密码：同步更新数据库中的密码哈希
  static async changePassword(accountNo: string, newPassword: string): Promise<boolean> {
    try {
      const store = await AccountStore.ready()
      const bucket: relationalStore.ValuesBucket = {
        'passwordHash': await hashPassword(accountNo, newPassword)
      }
      const predicates = new relationalStore.RdbPredicates(TABLE)
      predicates.equalTo('accountNo', accountNo)
      const rows = await store.update(bucket, predicates)
      return rows > 0
    } catch (e) {
      return false
    }
  }
}
