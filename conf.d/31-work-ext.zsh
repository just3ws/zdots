# conf.d/31-work-ext.zsh — load the machine's work-extension layer (Z-262).
#
# Tenant/employer configuration lives outside the platform repos in
# ${ZDOTS_WORK_EXT:-~/.config/zdots-work} (its own repo, own history).
# Absent dir = personal machine = silent no-op.

local _zwx="${ZDOTS_WORK_EXT:-$HOME/.config/zdots-work}"
[[ -r "$_zwx/init.zsh" ]] && source "$_zwx/init.zsh"
unset _zwx

return 0
