# Base16 material-dark (https://github.com/chriskempson/base16)
# Scheme: Sean Washington (http://seanwash.com)
# Ported by Mike Hall (https://just3ws.com)

_gen_fzf_default_opts() {

local color00='#263238'
local color01='#263238'
local color02='#37474f'
local color03='#707880'
local color04='#b5bd68'
local color05='#8abeb7'
local color06='#00005f'
local color07='#b294bb'
local color08='#cc6666'
local color09='#cc6666'
local color0A='#f0c674'
local color0B='#b5be63'
local color0C='#8abeb7'
local color0D='#81a2be'
local color0E='#ba8baf'
local color0F='#a16946'

export FZF_DEFAULT_OPTS="
  --color=bg+:$color01,bg:$color00,spinner:$color0C,hl:$color0D
  --color=fg:$color04,header:$color0D,info:$color0A,pointer:$color0C
  --color=marker:$color0C,fg+:$color06,prompt:$color0A,hl+:$color0D
"

}

_gen_fzf_default_opts
