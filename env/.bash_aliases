export SDK_PATH="../../sdk/sdk_lite"
export COMMON_PATH="../../common"
export CONFIGURATION_PATH="../../configurations"

export GCC_TOOLCHAIN_PATH=/usr/bin/
export IAR_TOOLCHAIN_PATH="/mnt/c/bin/IARSystems/EmbeddedWorkbench8.2/arm/bin"
export COMMANDER=/mnt/c/bin/commander/commander.exe
export PATH=$(dirname $COMMANDER):$PATH
export IMGBUILDER=/mnt/c/epauchard/projects/new_zigbee_ble_module/sdk/somfy_gecko_sdk_suite/v2.5/protocol/zigbee/tool/image-builder/image-builder-windows.exe
export PATH=$(dirname $IMGBUILDER):$PATH
export PROBE_SERIAL=440161643
# export PROBE_SERIAL=440075646  # wstk debug out
export GDB_SERVER="/mnt/c/bin/SEGGER/JLink/JLinkGDBServerCL.exe -select USB=$PROBE_SERIAL -device EFR32MG12PxxxF1024 -endian little -if SWD -speed auto -noir -LocalhostOnly"
export GDB_SERVER_HOST_PORT="localhost:2331"

alias usegcc='export TOOLCHAIN=gcc && export TOOLCHAIN_PATH=$GCC_TOOLCHAIN_PATH'
alias useiar='export TOOLCHAIN=iar && export TOOLCHAIN_PATH=$IAR_TOOLCHAIN_PATH'
useiar
alias gmr='git for-each-ref --count=10 --sort=-committerdate --format='\''%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) - %(contents:subject) - %(authorname) (%(color:green)%(committerdate:relative)%(color:reset))'\'''
alias glg="git log --graph"
alias glgmr='git log --graph $(git for-each-ref --count=10 --sort=-committerdate --format="%(objectname)")'

alias chrome='/mnt/c/Program\ Files\ \(x86\)/Google/Chrome/Application/chrome.exe'
# export PATH='"/mnt/c/Program Files (x86)/Google/Chrome/Application/"':$PATH

alias commander=commander.exe
# disable bootloader - boot to app : https://www.silabs.com/community/mcu/32-bit/forum.topic.html/clearing_the_clw0bi-zKhc
alias commander_no_boot='commander flash --patch 0x0fe041e8:0xfffffffd:4'

alias cat="batcat"

export DISPLAY=:0

function glogs() {
   minicom -m -c on -D $*
}

function grepc() {
   grep --include="*.[ch]" $*
}

function windows2unixpath() {
   # tr needs \\, bash will escape each \ so double it
   echo $* | tr '\\\\' '/' | sed 's![cC]:!/mnt/c!' | sed 's! !\\ !g'
}

function cdwin() {
  cd $(windows2unixpath $*)
}

function flash_test_node_zigbee() {
   pushd ~/bin/testnode
   commander flash testnode-WSTK-IAR_updat-0x6_wstk-tn_d_bootloader_debug_bundle.hex "$@"
   popd
}

function flash_test_node_ble() {
   pushd ~/bin/testnode
   commander flash ble_ncp_no_boot.hex "$@"
   popd
}

alias repo='/mnt/c/epauchard/projects/new_zigbee_ble_module/manifests/myrepo.py --dir=/mnt/c/epauchard/projects/new_zigbee_ble_module/ --manifest=/mnt/c/epauchard/projects/new_zigbee_ble_module/manifests/manifest.xml'
alias e='explorer.exe .'

function repo_sync_soliotek() {
    repo forall -i sdk -pc "
    URL=https://gitlab.soliotek.com/somfy/\$REPO_PROJECT.git
    # URL=git@gitlab.soliotek.com:somfy/\$REPO_PROJECT.git
    git remote set-url soliotek \$URL ||  git remote add soliotek \$URL
    git remote update
    git push soliotek somfy/master:master;
    "
    repo forall -r sdk -pc "
    URL=https://gitlab.soliotek.com/somfy/\$REPO_PROJECT.git
    # URL=git@gitlab.soliotek.com:somfy/\$REPO_PROJECT.git
    git remote set-url soliotek \$URL ||  git remote add soliotek \$URL
    git remote update
    git push soliotek somfy/develop:develop;
    git push soliotek somfy-sdk/silabs_original_sdk:silabs_original_sdk;
    "
}

function check_repos() {
repo forall -pc "git remote update ; echo local ; git rev-parse HEAD ; echo soliotek ; git rev-parse soliotek/master ; echo somfy ; git rev-parse somfy/master ; echo most recent ; git for-each-ref --count=1 --sort=-committerdate --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) - %(contents:subject) - %(authorname) (%(color:green)%(committerdate:relative)%(color:reset))'"
}
alias zb="cd /mnt/c/epauchard/projects/new_zigbee_ble_module/"

function gpg_decrypt_epa() {
   base64 --wrap 0 | base64 -d | gpg --decrypt
}

function gpg_encrypt_epa() {
   gpg --encrypt --armor -r "Emmanuel Pauchard"
}

# $1: ELF file to disassemble
# $2: symbol to filter
function disassemble() {
   [[ -z $2 ]] && echo "Usage: disassemble elf_file symbol" && return 1
   arm-none-eabi-objdump -d $1 | awk -v RS= "/^[[:xdigit:]]+ <$2>/"
}

function merge_test_reports() {
   xml_tests_merge $(find -name "*xml") > $(basename $(pwd)).xml
}

# $1: the object file name
# Note: IAR does not seem to generate really usefull information for this. gcc does a better job
function find_defined_macros() {
   arm-none-eabi-readelf -w=m $1  | less
}

cd /mnt/c/epauchard/projects
