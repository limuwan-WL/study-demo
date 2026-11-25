// 校园小助手账号服务：App 通过 HTTP 访问，账号数据统一存 MySQL
const express = require('express');
const crypto = require('crypto');
const pool = require('./db');
require('dotenv').config();

const app = express();
app.use(express.json());
// 请求日志：联调时用于确认请求确实来自 App
app.use((req, res, next) => {
  console.log(`[req] ${req.method} ${req.url} from ${req.ip}`);
  next();
});

const ROLES = ['student', 'teacher', 'assistant'];
const ACCOUNT_RE = /^[A-Za-z0-9]{4,20}$/;
const PASSWORD_RE = /^[A-Za-z0-9_]{8,}$/;

// 与 App 端保持一致的加盐哈希：SHA-256(accountNo:password)
function hashPassword(accountNo, password) {
  return crypto.createHash('sha256').update(`${accountNo}:${password}`).digest('hex');
}

function toAccount(row) {
  return {
    id: Number(row.id),
    accountNo: row.account_no,
    role: row.role,
    nickname: row.nickname
  };
}

function fail(res, code, message, status = 200) {
  res.status(status).json({ ok: false, code, message, account: null });
}

// 健康检查：确认服务与 MySQL 都可用
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ ok: true, code: 'ok', message: 'server ok' });
  } catch (e) {
    res.status(500).json({ ok: false, code: 'error', message: e.message });
  }
});

// 注册：学号/教工号唯一，密码只存哈希
app.post('/api/auth/register', async (req, res) => {
  const body = req.body || {};
  const accountNo = String(body.accountNo || '').trim();
  const password = String(body.password || '');
  const role = String(body.role || '');
  const nickname = String(body.nickname || '').trim() || accountNo;
  if (!ACCOUNT_RE.test(accountNo)) {
    return fail(res, 'invalid', '学号/教工号格式不正确');
  }
  if (!PASSWORD_RE.test(password)) {
    return fail(res, 'invalid', '密码至少 8 位，仅可包含字母、数字、下划线');
  }
  if (!ROLES.includes(role)) {
    return fail(res, 'invalid', '身份不合法');
  }
  try {
    const now = Date.now();
    await pool.query(
      'INSERT INTO user_account (account_no, password_hash, role, nickname, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
      [accountNo, hashPassword(accountNo, password), role, nickname, now, now]);
    const [rows] = await pool.query(
      'SELECT id, account_no, role, nickname FROM user_account WHERE account_no = ?', [accountNo]);
    res.json({ ok: true, code: 'ok', message: '注册成功', account: toAccount(rows[0]) });
  } catch (e) {
    if (e.code === 'ER_DUP_ENTRY') {
      return fail(res, 'duplicate', '该学号/教工号已注册，请直接登录');
    }
    fail(res, 'error', '注册失败：' + e.message, 500);
  }
});

// 登录：校验账号存在与密码哈希
app.post('/api/auth/login', async (req, res) => {
  const body = req.body || {};
  const accountNo = String(body.accountNo || '').trim();
  const password = String(body.password || '');
  if (accountNo === '' || password === '') {
    return fail(res, 'invalid', '学号/教工号和密码不能为空');
  }
  try {
    const [rows] = await pool.query(
      'SELECT id, account_no, password_hash, role, nickname FROM user_account WHERE account_no = ?', [accountNo]);
    if (rows.length === 0) {
      return fail(res, 'not_found', '该学号/教工号尚未注册');
    }
    if (rows[0].password_hash !== hashPassword(accountNo, password)) {
      return fail(res, 'bad_password', '学号/教工号或密码错误');
    }
    res.json({ ok: true, code: 'ok', message: '登录成功', account: toAccount(rows[0]) });
  } catch (e) {
    fail(res, 'error', '登录失败：' + e.message, 500);
  }
});

// 修改 / 重置密码：调用方需先用旧密码登录校验
app.post('/api/auth/password', async (req, res) => {
  const body = req.body || {};
  const accountNo = String(body.accountNo || '').trim();
  const newPassword = String(body.newPassword || '');
  if (!PASSWORD_RE.test(newPassword)) {
    return fail(res, 'invalid', '新密码至少 8 位，仅可包含字母、数字、下划线');
  }
  try {
    const [result] = await pool.query(
      'UPDATE user_account SET password_hash = ?, updated_at = ? WHERE account_no = ?',
      [hashPassword(accountNo, newPassword), Date.now(), accountNo]);
    if (result.affectedRows === 0) {
      return fail(res, 'not_found', '账号不存在');
    }
    res.json({ ok: true, code: 'ok', message: '密码已更新', account: null });
  } catch (e) {
    fail(res, 'error', '修改密码失败：' + e.message, 500);
  }
});

// 注销账号：物理删除
app.post('/api/auth/delete', async (req, res) => {
  const body = req.body || {};
  const accountNo = String(body.accountNo || '').trim();
  try {
    const [result] = await pool.query('DELETE FROM user_account WHERE account_no = ?', [accountNo]);
    if (result.affectedRows === 0) {
      return fail(res, 'not_found', '账号不存在');
    }
    res.json({ ok: true, code: 'ok', message: '账号已注销', account: null });
  } catch (e) {
    fail(res, 'error', '注销失败：' + e.message, 500);
  }
});

// 本机/服务端已注册账号列表（按注册时间倒序）
app.get('/api/auth/accounts', async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, account_no, role, nickname FROM user_account ORDER BY created_at DESC');
    res.json({ ok: true, code: 'ok', message: 'ok', accounts: rows.map(toAccount) });
  } catch (e) {
    res.status(500).json({ ok: false, code: 'error', message: e.message, accounts: [] });
  }
});

const PORT = Number(process.env.PORT || 3000);
app.listen(PORT, '0.0.0.0', () => {
  console.log(`[server] 账号服务已启动：http://0.0.0.0:${PORT}`);
});
