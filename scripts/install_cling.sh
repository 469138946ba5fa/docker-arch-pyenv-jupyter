#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

log_info "Starting Cling environment setup..."

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
pyenv activate "${PY_ENV}"

# === CONFIGURATION ===
LLVM_REPO="https://github.com/root-project/llvm-project"
CLING_REPO="https://github.com/root-project/cling"
CLING_BRANCH="cling-latest"

SRC_DIR="/tmp"
INSTALL_PREFIX="/usr/local"
SHARE_DIR="${INSTALL_PREFIX}/share/cling"
BUILD_DIR="${SHARE_DIR}/build"
KERNEL_DIR="${SHARE_DIR}/Jupyter"

PYTHON_EXEC="${PYTHON_EXEC:-python3}"
JUPYTER_KERNEL_USER="--user"
RETRIES=5
CORENUM="${CORENUM:-$(($(nproc)/3))}"
CLING_BUILD_MODE="${CLING_BUILD_MODE:-online}"

ARCHITECTURE="$(uname -m)"
SRC_ARCHIVE="/usr/local/src/llvm-project.tar.gz"
BUILD_ARCHIVE="/usr/local/src/llvm-clang-cling-build-${ARCHITECTURE}.tar.gz"

log_info "Detected architecture: ${ARCHITECTURE}"
log_info "使用构建模式：${CLING_BUILD_MODE} for ${ARCHITECTURE}"

# === UTIL ===
retry() {
  local count=0
  until "$@"; do
    count=$((count + 1))
    if [[ ${count} -ge ${RETRIES} ]]; then
      log_error "命令失败：$*"
      return 1
    fi
    log_warning "命令失败，重试 ${count}/${RETRIES}：$*"
    sleep $((count * 2))
  done
}

# 解压 llvm-project 源码
extract_llvm_src_if_needed() {
  if [[ ! -d "${SRC_DIR}/llvm-project" && -f "${SRC_ARCHIVE}" ]]; then
    log_info "解压 LLVM 源码到 ${SRC_DIR}/llvm-project"
    tar -xzf "${SRC_ARCHIVE}" -C "${SRC_DIR}"
    git config --global --add safe.directory "${SRC_DIR}/llvm-project"
    git -C "${SRC_DIR}/llvm-project" pull
    git -C "${SRC_DIR}/llvm-project" checkout "${CLING_BRANCH}"
  fi
}

# === STEP 1: 获取 LLVM/CLING 源码 ===
clone_sources() {
  case "${CLING_BUILD_MODE}" in
    online)
      log_info "侦测到 ${CLING_BUILD_MODE} 模式..."
      log_info "[online] 克隆 LLVM 项目..."
      if [[ ! -d "${SRC_DIR}/llvm-project" ]]; then
        retry git clone "${LLVM_REPO}" "${SRC_DIR}/llvm-project"
        retry git -C "${SRC_DIR}/llvm-project" fetch --all
        retry git -C "${SRC_DIR}/llvm-project" checkout "${CLING_BRANCH}"
      fi
      ;;
    local)
      log_info "侦测到 ${CLING_BUILD_MODE} 模式..."
      log_info "[local] 解压本地 LLVM 源码..."
      extract_llvm_src_if_needed
      ;;
    prebuilt)
      log_info "侦测到 ${CLING_BUILD_MODE} 模式..."
      ;;
    *)
      log_error "未知构建模式：${CLING_BUILD_MODE}"
      exit 1
      ;;
  esac

  if [[ ! -d "${SRC_DIR}/cling" ]]; then
    retry git clone "${CLING_REPO}" "${SRC_DIR}/cling"
  fi
}

# === STEP 2: BUILD ===
build_cling() {
  log_info "构建 Cling..."
  log_info "[prebuilt] 将在 build_cling 中解压 llvm-project + build"
  case "${CLING_BUILD_MODE}" in
    online|local)
      cmake -G Ninja -B"${BUILD_DIR}" -S"${SRC_DIR}/llvm-project/llvm" \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
        -DLLVM_EXTERNAL_PROJECTS="cling" \
        -DLLVM_EXTERNAL_CLING_SOURCE_DIR="${SRC_DIR}/cling/" \
        -DLLVM_ENABLE_PROJECTS="clang" \
        -DLLVM_TARGETS_TO_BUILD="host;NVPTX" \
        -DCMAKE_BUILD_TYPE=Release

      cmake --build "${BUILD_DIR}" --target clang cling -- -j${CORENUM}
      cmake --build "${BUILD_DIR}" --target libclingJupyter -- -j${CORENUM}
      cmake --build "${BUILD_DIR}" -- -j${CORENUM}
      cmake --install "${BUILD_DIR}"
      ;;
    prebuilt)
      log_info "解压预编译包 (包含修正后的 cmake_install.cmake)..."
      if [[ -f "${BUILD_ARCHIVE}" ]]; then
        # 1. 解压预编译包 (包含修正后的 cmake_install.cmake)
        tar zxvf "${BUILD_ARCHIVE}" -C "/"
      else
        log_error "未找到预构建产物：${BUILD_ARCHIVE}"
        exit 1
      fi
      ;;
    *)
      log_error "未知构建模式：${CLING_BUILD_MODE}"
      exit 1
      ;;
  esac

  # 这一步是为了修复 Cling 的一个已知问题，它有时会去构建目录寻找资源。
  # 无论哪种模式，我们都确保这个目录和符号链接存在。
  log_info "修复 Cling 资源路径..."
  # 清理可能存在的旧构建目录（如果不是 prebuilt 模式）
  rm -frv "${BUILD_DIR}"

  # 重新创建 lib 目录
  # 修复找不到 lib/clang/18 的错误
  # 修复参考 https://github.com/root-project/cling/issues/536
  mkdir -pv ${BUILD_DIR}/lib
  ln -fsv ${INSTALL_PREFIX}/lib/clang ${BUILD_DIR}/lib/clang
}

# === STEP 3: 注册 Jupyter 内核 ===
setup_kernels() {
  log_info "安装 Cling Jupyter 内核..."

  if [[ ! -d "${SRC_DIR}/cling/tools/Jupyter/kernel" ]]; then
    log_error "缺失 cling 源码目录，无法注册 Jupyter 内核"
    exit 1
  fi

  cp -a "${SRC_DIR}/cling/tools/Jupyter/kernel" "${KERNEL_DIR}"

  pushd "${KERNEL_DIR}/kernel" > /dev/null
  cp -a cling-cpp20 cling-cpp23
  sed -i 's/20/23/g' cling-cpp23/kernel.json

  ${PYTHON_EXEC} -m pip install -e .

  for k in cling-cpp*/; do
    log_info "注册 Jupyter 内核：${k}"
    jupyter-kernelspec install "${k}" ${JUPYTER_KERNEL_USER}
  done
  popd > /dev/null
}

# === STEP 4: 验证 ===
validate() {
  log_info "验证 Cling 和 Jupyter 内核..."
  cling --version || { log_error "cling 未安装或不可执行"; exit 1; }
  jupyter-kernelspec list
}

# === MAIN ===
main() {
  mkdir -p "${SRC_DIR}" "${BUILD_DIR}" "${KERNEL_DIR}"

  log_info "开始安装 Cling..."
  clone_sources
  build_cling
  setup_kernels
  validate

  log_info "Cling 安装完成。"
}

main "$@"

log_info "cling & cling Jupter kernel setup is complete."
jupyter-kernelspec list
cling --version
# 测试打印，如果输出 Hello World! 就算成功
/usr/local/bin/cling '#include <stdio.h>' 'printf("C++ Cling Hello World!\n");'