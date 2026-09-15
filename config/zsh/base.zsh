bindkey -e

# 単語の区切り文字を指定する
autoload -Uz select-word-style
select-word-style default
# ここで指定した文字は単語区切りとみなされる
# / も区切りと扱うので、^W でディレクトリ１つ分を削除できる
zstyle ':zle:*' word-chars " _-/=;@:{},|"
zstyle ':zle:*' word-style unspecified

# 補完で小文字でも大文字にマッチさせる
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# ../ の後は今いるディレクトリを補完しない
zstyle ':completion:*' ignore-parents parent pwd ..

# sudo の後ろでコマンド名を補完する
zstyle ':completion:*:sudo:*' command-path /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/X11R6/bin

# ps コマンドのプロセス名補完
zstyle ':completion:*:processes' command 'ps x -o pid,s,args'

# オプション
# 日本語ファイル名を表示可能にする
setopt print_eight_bit

# beep を無効にする
setopt no_beep

# フローコントロールを無効にする
setopt no_flow_control

# '#' 以降をコメントとして扱う
setopt interactive_comments

# ディレクトリ名だけでcdする
setopt auto_cd

# cd したら自動的にpushdする
setopt auto_pushd

# 重複したディレクトリを追加しない
setopt pushd_ignore_dups

# 同時に起動したzshの間でヒストリを共有する
setopt share_history

# 履歴を追記し、並行シェルで壊れにくくする
setopt append_history
setopt inc_append_history
setopt hist_fcntl_lock

# 履歴の品質
setopt extended_history
setopt hist_ignore_space
setopt hist_expire_dups_first

# 同じコマンドをヒストリに残さない
setopt hist_ignore_all_dups

# ヒストリファイルに保存するとき、すでに重複したコマンドがあったら古い方を削除する
setopt hist_save_nodups

# ヒストリに保存するときに余分なスペースを削除する
setopt hist_reduce_blanks

# 補完候補が複数あるときに自動的に一覧表示する
setopt auto_menu

# 高機能なワイルドカード展開を使用する
setopt extended_glob

# alias
alias la="ls -a"
alias ll="ls -l"
alias lal="ls -al"

setopt magic_equal_subst

# GCLOUD ENV
if [[ -r "${XDG_CONFIG_HOME}/gcloud/application_default_credentials.json" ]]; then
  export GOOGLE_APPLICATION_CREDENTIALS="${XDG_CONFIG_HOME}/gcloud/application_default_credentials.json"
fi

if (( $+commands[ghq] && $+commands[fzf] )); then
  function ghq-fzf() {
    local dir=$(ghq root)/$(ghq list | fzf)
    if [[ -n $dir ]]; then
      BUFFER="cd -- $dir"
      zle accept-line
    fi
  }
  zle -N ghq-fzf
  bindkey '^]' ghq-fzf
fi

if (( $+commands[wt] )) || [[ -n "${WORKTRUNK_BIN:-}" ]]; then
  wt() {
    local use_source=false
    local -a args
    for arg in "$@"; do
      if [[ "$arg" == "--source" ]]; then use_source=true; else args+=("$arg"); fi
    done

    # clap の補完ハンドラは引数解析より前に走るため、ここで早期 return する
    if [[ -n "${COMPLETE:-}" ]]; then
      command "${WORKTRUNK_BIN:-wt}" "${args[@]}"
      return
    fi

    local cd_file exec_file exit_code=0
    cd_file="$(mktemp)"
    exec_file="$(mktemp)"

    if [[ "$use_source" == true ]]; then
      WORKTRUNK_DIRECTIVE_CD_FILE="$cd_file" WORKTRUNK_DIRECTIVE_EXEC_FILE="$exec_file" \
        cargo run --bin wt --quiet -- "${args[@]}" || exit_code=$?
    else
      WORKTRUNK_DIRECTIVE_CD_FILE="$cd_file" WORKTRUNK_DIRECTIVE_EXEC_FILE="$exec_file" \
        command "${WORKTRUNK_BIN:-wt}" "${args[@]}" || exit_code=$?
    fi

    if [[ -s "$cd_file" ]]; then
      cd -- "$(<"$cd_file")"
      local cd_exit=$?
      if [[ $exit_code -eq 0 ]]; then exit_code=$cd_exit; fi
    fi
    if [[ -s "$exec_file" ]]; then
      source "$exec_file"
      local src_exit=$?
      if [[ $exit_code -eq 0 ]]; then exit_code=$src_exit; fi
    fi

    rm -f "$cd_file" "$exec_file"
    return "$exit_code"
  }

  _wt_lazy_complete() {
    if ! (( $+functions[_clap_dynamic_completer_wt] )); then
      # `command` でシェル関数を迂回しバイナリを直接呼ぶ。-V は recency 順を保つため _describe をパッチしている
      eval "$(COMPLETE=zsh command "${WORKTRUNK_BIN:-wt}" 2>/dev/null | sed "s/_describe 'values'/_describe -V 'values'/")" || return
    fi
    _clap_dynamic_completer_wt "$@"
  }

  if (( $+functions[compdef] )); then
    # compinit 実行前にここへ到達しうるため、compdef 登録は zsh-defer で後回しにする
    zsh-defer compdef _wt_lazy_complete wt
    zstyle ':completion:*:wt:*' list-max 1
    zstyle ':completion:*:*:wt:*' list-grouped false
  fi
fi

if [[ -f ~/.zshrc.zwc && ~/.zshrc -nt ~/.zshrc.zwc ]] || [[ ! -f ~/.zshrc.zwc ]]; then
  zcompile ~/.zshrc
fi
