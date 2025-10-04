#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

log_info "Starting Jupyter environment setup..."

# 初始化 pyenv 环境
#export PYENV_ROOT="${HOME}/.pyenv"
#[[ -d ${PYENV_ROOT}/bin ]] && export PATH="${PYENV_ROOT}/bin:${PATH}"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# pip 软件源
# export PIP_CHANNELS="${PIP_CHANNELS:-https://pypi.org/simple}"

# 指定 cling 的 python 版本
# 获取pyenv版本
# 为空则返回最新稳定版，如 3.13.3
# --latest-alpha 返回最新 alpha，如 3.14.0a7t
# --latest-dev 返回最新 dev，如 3.14t-dev
# --latest-t 返回最新 t，如 3.13.3t
# 3.13.2t 如果存在就返回它，不存在则返回最新稳定版
# 3.99.9 不存在，返回 fallback 稳定版
#export PY_VERSION=3.12.10
#export PY_ENV=py${PY_VERSION}

# pip 包安装带重试逻辑
retry_pip_install_bulk() {
  local retries=3
  local sleep_seconds=2
  local pkgs=("$@")
  for ((i=1; i<=retries; i++)); do
    log_info "Installing pip packages in bulk (attempt ${i}/${retries})"
    if python -m pip install --no-cache-dir -v "${pkgs[@]}" --break-system-packages -i ${PIP_CHANNELS}; then
      log_info "All pip packages installed successfully."
      return 0
    else
      log_warning "Failed attempt ${i} to install pip packages, retrying after ${sleep_seconds}s..."
      sleep $sleep_seconds
    fi
  done
  log_error "Failed to install pip packages after ${retries} attempts."
  exit 1
}

# pip 包重安装带重试逻辑
retry_pip_force_reinstall_bulk() {
  local retries=3
  local sleep_seconds=2
  local pkgs=("$@")
  for ((i=1; i<=retries; i++)); do
    log_info "Reinstalling pip packages in bulk (attempt ${i}/${retries})"
    if python -m pip install --force-reinstall -v "${pkgs[@]}" --break-system-packages -i ${PIP_CHANNELS}; then
      log_info "All pip packages reinstalling successfully."
      return 0
    else
      log_warning "Failed attempt ${i} to reinstalling pip packages, retrying after ${sleep_seconds}s..."
      sleep $sleep_seconds
    fi
  done
  log_error "Failed to reinstalling pip packages after ${retries} attempts."
  exit 1
}

# 获取pyenv版本
# resolve_python_version	返回最新稳定版，如 3.13.3
# resolve_python_version --latest-alpha	返回最新 alpha，如 3.14.0a7t
# resolve_python_version --latest-dev	返回最新 dev，如 3.14t-dev
# resolve_python_version --latest-t	返回最新 t，如 3.13.3t
# resolve_python_version 3.13.2t	如果存在就返回它，不存在则返回最新稳定版
# resolve_python_version 3.99.9	不存在，返回 fallback 稳定版
resolve_python_version() {
  local version=""
  local mode="stable"

  # 参数解析
  for arg in "$@"; do
    case "${arg}" in
      --latest-dev) mode="dev" ;;
      --latest-alpha) mode="alpha" ;;
      --latest-t) mode="t" ;;
      --*) echo "Unknown option: ${arg}" >&2; return 1 ;;
      *) version="${arg}" ;;  # 不是 -- 开头就是版本
    esac
  done

  local list=$(pyenv install --list 2>/dev/null | sed 's/^[ \t]*//' | grep -E '^2|^3\.')

  # 如果用户指定了版本，且存在，直接返回该版本
  if [[ -n "${version}" ]] && echo "${list}" | grep -qx "${version}"; then
    echo "${version}"
    return 0
  fi

  # 回退逻辑
  local fallback=""
  # 过滤算法
  case "${mode}" in
    alpha)
      fallback=$(echo "${list}" | grep -E '\.[0-9]+a[0-9]+?$' | tail -n1)
      ;;
    dev)
      fallback=$(echo "${list}" | grep -E 'dev$' | tail -n1)
      ;;
    t)
      fallback=$(echo "${list}" | grep -E 't$' | tail -n1)
      ;;
    stable)
      fallback=$(echo "${list}" | grep -vE 'dev$|t$|a' | tail -n1)
      ;;
  esac

  echo "${fallback}"
}

# 编译指定版本 python
pyenv install -v -f $(resolve_python_version ${PY_VERSION})
# 刷新
pyenv rehash
# 当前版本检查
pyenv version
pyenv versions

# 获取安装好的 python 版本
#PY_VERSION=$(pyenv versions | sed 's/^[ \t]*//')
pyenv global ${PY_VERSION}
pyenv virtualenv ${PY_VERSION} ${PY_ENV}
pyenv global ${PY_ENV} ${PY_VERSION}
pyenv activate ${PY_ENV}

# python 虚拟环境检查
pyenv version
pyenv versions

# 所需软件包列表
pip_packages=(
  # jupyter 类别：构建完整的 Jupyter 环境及扩展
  jupyterlab                     # 下一代 Jupyter 用户界面，支持交互式笔记本和代码
  notebook                       # 经典 Jupyter Notebook 应用
  voila                          # 可将 Jupyter 笔记本转换为独立的 Web 应用
  ipywidgets                     # 为笔记本提供交互式控件（HTML widgets）
  qtconsole                      # 基于 Qt 的 Jupyter 控制台，提供终端式界面
  jupyter_contrib_nbextensions   # 社区贡献的 Notebook 扩展集合，可增强功能
  jupyterlab-git                 # 在 JupyterLab 中集成 Git 版本控制功能
  jupyterlab-dash                # 允许在 JupyterLab 中嵌入和交互使用 Dash 应用
  # data 类别：用于数值计算、数据处理和可视化
  numpy                          # 数组计算基础库，为后续科学计算提供支持
  scipy                          # 科学计算库，包含大量算法和数学工具
  pandas                         # 数据分析和数据结构处理工具
  matplotlib                     # 绘图和数据可视化库
  # machine 类别：机器学习
  seaborn                        # 基于 matplotlib 的统计数据可视化库
  scikit-learn                   # 机器学习库，提供分类、回归、聚类等算法
  tensorflow                     # 由 Google 开发的一个可商业化的开源深度学习框架
  # network 类别：与网络请求、爬虫及数据库交互相关
  beautifulsoup4                 # HTML/XML 解析库，用于网页数据爬取和处理
  requests                       # 简单优雅的 HTTP 请求库
  SQLAlchemy                     # SQL 工具包及 ORM，用于数据库交互
  retrying                       # 帮助实现函数重试机制的库，适用于网络请求等场景
  httpx                          # 现代化的 HTTP 客户端，支持同步与异步请求
)

# 备用功能，所需强制重装安装包
pip_force_packages=(
  setuptools                      # 生成 console_scripts entrypoints
  wheel                           # 确保正确的 wheel 安装机制
)

# 更新 pip 工具包
python -m pip install --no-cache-dir -v --upgrade pip --break-system-packages -i ${PIP_CHANNELS}

# 一次性安装全部包
log_info "Installing pip packages individually with retries..."
retry_pip_install_bulk "${pip_packages[@]}"

#log_info "Installing pip packages individually with retries..."
#for pkg in "${pip_packages[@]}"; do
#  retry_pip_install_bulk "$pkg"
#done

# 备用功能，补丁修复: 强制重新安装 setuptools, wheel，确保 jupyter 命令正确生成
log_info "Reinstalling setuptools and wheel to fix entrypoints..."
retry_pip_force_reinstall_bulk "${pip_force_packages[@]}"

#log_info "Reinstalling setuptools and wheel to fix entrypoints..."
#for pkg in "${pip_force_packages[@]}"; do
#  retry_pip_force_reinstall_bulk "$pkg"
#done

# 将激活环境及 locale 配置写入配置文件中，保留长期有效
echo "pyenv activate ${PY_ENV}" | tee -a /etc/environment "${HOME}/.profile"

# 获取当前 shell 名称
CURRENT_SHELL=$(basename "${SHELL}")

log_info "Detected shell: ${CURRENT_SHELL}"

case "${CURRENT_SHELL}" in
  bash)
    if ! grep -q "pyenv activate ${PY_ENV}" "${HOME}/.bashrc"; then
      log_info "Initializing ${PY_ENV} for bash..."
      # 固化 ${PY_ENV} 环境
      # 在 docker 非交互式容器中毫无意义，可以没有，但是我希望，这能帮助我理解
      echo "pyenv activate ${PY_ENV}" | tee -a /etc/skel/.bashrc "${HOME}/.bashrc"
    fi
    ;;
  zsh)
    if ! grep -q "pyenv activate ${PY_ENV}" "${HOME}/.zshrc"; then
      log_info "Initializing ${PY_ENV} for zsh..."
      # 固化 ${PY_ENV} 环境
      # 在 docker 非交互式容器中毫无意义，可以没有，但是我希望，这能帮助我理解
      echo "pyenv activate ${PY_ENV}" | tee -a /etc/skel/.zshrc "${HOME}/.zshrc"
    fi
    ;;
  *)
    log_error "Unsupported shell: ${CURRENT_SHELL}"
    exit 1
    ;;
esac

log_info "Jupyter setup is complete."
# jupyter --version
python -m jupyter --version