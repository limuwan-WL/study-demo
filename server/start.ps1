# 校园小助手账号服务启动脚本
# 流程：定位 Node → 安装依赖 → 建库建表 → 启动 HTTP 接口
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

# 1) 定位 Node：优先系统 PATH，其次 DevEco Studio 自带
$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $node) {
  $candidates = @(
    'D:\app\devecostudio-windows-26.0.1.290\DevEco Studio\tools\node\node.exe'
  )
  foreach ($c in $candidates) {
    if (Test-Path $c) { $node = $c; break }
  }
}
if (-not $node) {
  Write-Host '[错误] 未找到 node.exe，请先安装 Node.js 18 及以上版本' -ForegroundColor Red
  exit 1
}
$nodeDir = Split-Path -Parent $node
$npm = Join-Path $nodeDir 'npm.cmd'
Write-Host "[1/4] Node: $node"

# 2) 数据库凭据：环境变量 > server/.env > 交互输入（密码不写入任何文件）
if (-not $env:DB_USER) { $env:DB_USER = 'root' }
if (-not $env:DB_NAME) { $env:DB_NAME = 'campus_helper' }
if (-not $env:DB_PASSWORD -and -not (Test-Path (Join-Path $root '.env'))) {
  $secure = Read-Host "请输入 MySQL 密码（用户 $($env:DB_USER)）" -AsSecureString
  $env:DB_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}

# 3) 首次运行安装依赖（国内镜像加速）
if (-not (Test-Path (Join-Path $root 'node_modules'))) {
  Write-Host '[2/4] 首次运行，安装依赖...'
  if (-not $env:npm_config_registry) { $env:npm_config_registry = 'https://registry.npmmirror.com' }
  & $npm install --omit=dev --no-audit --no-fund
  if ($LASTEXITCODE -ne 0) {
    Write-Host '[错误] 依赖安装失败，请检查网络' -ForegroundColor Red
    exit 1
  }
} else {
  Write-Host '[2/4] 依赖已存在，跳过安装'
}

# 4) 检查/创建数据库与账号表
Write-Host '[3/4] 检查数据库与 user_account 表...'
& $node migrate.js
if ($LASTEXITCODE -ne 0) {
  Write-Host '[错误] 建库失败：请确认 MySQL 已启动、账号密码正确' -ForegroundColor Red
  exit 1
}

# 5) 启动服务（前台运行，Ctrl+C 停止）
$port = '3000'
if ($env:PORT) { $port = $env:PORT }
Write-Host "[4/4] 启动账号服务：http://127.0.0.1:$port" -ForegroundColor Green
Write-Host "      健康检查：http://127.0.0.1:$port/health"
$lan = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -notmatch '^127\.' -and $_.IPAddress -notmatch '^169\.' } |
  Select-Object -First 1).IPAddress
if ($lan) {
  Write-Host "      真机访问：http://${lan}:$port （App 的 apiBaseUrl 改成该地址）"
}
& $node server.js
