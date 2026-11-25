// 初始化脚本：创建数据库 campus_helper 与账号表 user_account
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
require('dotenv').config();

async function main() {
  const dbName = process.env.DB_NAME || 'campus_helper';
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    multipleStatements: true
  });
  await conn.query(`CREATE DATABASE IF NOT EXISTS \`${dbName}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci`);
  await conn.query(`USE \`${dbName}\``);
  const sql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
  await conn.query(sql);
  const [rows] = await conn.query(
    'SELECT COUNT(*) AS total FROM information_schema.tables WHERE table_schema = ? AND table_name = ?',
    [dbName, 'user_account']);
  console.log(`[migrate] 数据库 ${dbName} 就绪，user_account 表${rows[0].total === 1 ? '已创建' : '创建失败'}`);
  await conn.end();
}

main().catch((e) => {
  console.error('[migrate] 失败：', e.message);
  process.exit(1);
});
