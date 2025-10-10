#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

log_info "Setting up JBang and configuring Jupyter Java Kernel..."

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

# jbang 环境
# export PATH="${HOME}/.jbang/bin:${PATH}"

curl -Ls https://sh.jbang.dev | bash -s - app setup
jbang trust add https://github.com/jupyter-java/jbang-catalog/
jbang trust add https://github.com/jupyter-java/
jbang install-kernel@jupyter-java
rm -rf "${HOME}/.jbang/currentjdk" "${HOME}/.jbang/cache/jdks"
log_info "JBang setup completed."
jupyter-kernelspec list