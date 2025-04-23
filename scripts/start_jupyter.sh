#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

log_info "Initializing pyenv..."


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
#export PATH="${PYENV_ROOT}/versions/${PY_ENV}/bin:${PATH}"
pyenv activate ${PY_ENV}

# 配置 locale
# export LANGUAGE=zh_CN.UTF-8
# export LC_ALL=zh_CN.UTF-8
# export LANG=zh_CN.UTF-8
# export LC_CTYPE=zh_CN.UTF-8

# jbang 环境
# export PATH="${HOME}/.jbang/bin:${PATH}"
# java 环境
# export JAVA_HOME=${HOME}/.jbang/currentjdk
# export CLASSPATH=.:${JAVA_HOME}/lib
# export PATH=${PATH}:${JAVA_HOME}/bin

# 将日志输出重定向到日志文件
LOG_FILE="/notebook/jupyter_startup.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

log_info "Starting JupyterLab service..."

if [ ! -d "/notebook" ]; then
  log_error "/notebook directory does not exist. Please check volume mounts."
  exit 1
fi

for cmd in pyenv jupyter-lab; do
  if ! command_exists "${cmd}"; then
    log_error "${cmd} is not installed. Aborting."
    exit 1
  fi
done

# --------- 开始统一修改 jupyter_server_config.py ---------

# 确保配置文件目录存在
mkdir -p "${HOME}/.jupyter"

# 如配置文件不存在则生成 jupyter_server_config.py
if [ ! -f "${HOME}/.jupyter/jupyter_server_config.py" ]; then
    log_info "Generating Jupyter server configuration..."
    jupyter-server --generate-config -y
fi

# 设置密码：如果JUPYTER_PASSWORD变量未设置，则采用默认值
if [[ -z "${JUPYTER_PASSWORD:-}" ]]; then
    log_warning "JUPYTER_PASSWORD variable not set, using default value: 123456"
    export JUPYTER_PASSWORD=123456
fi

# 生成密码哈希（新版Jupyter使用 Notebook.auth 模块产生密码哈希）
# JUPYTER_PASSWORD_HASH=$(python -c "from notebook.auth import passwd; print(passwd('${JUPYTER_PASSWORD}'))")
JUPYTER_PASSWORD_HASH=$(python -c "
try:
    from jupyter_server.auth.security import passwd
except ImportError:
    from notebook.auth import passwd
print(passwd('${JUPYTER_PASSWORD}'))
")

log_info "Appending custom configuration for default shell and JUPYTER_PASSWORD to Jupyter server config..."

# 将 Terminal 默认 shell 和密码写入 jupyter_server_config.py
cat <<EOF >> "${HOME}/.jupyter/jupyter_server_config.py"

# ------------------------------
# Custom configuration appended automatically via startup script
c.ServerApp.terminado_settings = {'shell_command': ['/bin/bash']}
c.ServerApp.password = "${JUPYTER_PASSWORD_HASH}"
# ------------------------------
EOF

log_info "Jupyter server configuration updated at ${HOME}/.jupyter/jupyter_server_config.py"

# 设置默认主题为 JupyterLab Dark
mkdir -p "${HOME}/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/"
cat <<'EOF' > "${HOME}/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/themes.jupyterlab-settings"
{
    "theme": "JupyterLab Dark"
}
EOF
log_info "Default JupyterLab theme set to 'JupyterLab Dark'."

# --------- 启动 JupyterLab ---------
log_info "Launching JupyterLab on port 8888..."
jupyter-lab --allow-root --no-browser --notebook-dir=/notebook --ip=0.0.0.0 --port=8888
