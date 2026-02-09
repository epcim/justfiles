
# settings
set export := true
set dotenv-load := true
set positional-arguments := true

# runtime
fish_bin := `which fish`
bash_bin := `which bash`
temp := `mktemp -d`
ROOT := env('BASE', env('TOP', env('PWD')))

default:
  just --list


# Install common dependencies with brew
brew-install:
  brew install aider node
  npm install -g @openai/codex

# Configure, as of now only interpolate your env API_KEY variables to config files
# TODO, Use ENV vars directly
configure-static:
  envsubst < aider.conf.yml >| ~/.aider.conf.yml
  [ -d ~/.codex ] || mkdir ~/.codex
  envsubst < codex.config.yml >| ~/.codex/config.yml
  [ -d ~/.config/shell_gpt ] || cp -r shell_gpt ~/.config/ &&\
    envsubst < shell_gpt/.sgptrc >| ~/.config/shell_gpt/.sgptrc


# Start openwebui
run-openwebui:
  #!{{bash_bin}}
  echo cd $ROOT/deploy/openwebui
  cd $ROOT/deploy/openwebui
  pwd
  docker-compose up -d
  docker-compose logs -f openwebui

# Stop all docker compose services
stop-all:
  #!{{bash_bin}}
  cd $ROOT/deploy/openwebui
  docker-compose down
  rm -rf .storage

# call ollama
ollama ARGS:
  ollama $ARGS

#list Ollama models
@ollama-models:
    curl -s https://ollama.com/library | grep -oP 'href="/library/\K[^"]+'

#list model tags
@ollama-tags model:
    curl -s https://ollama.com/library/$1/tags | grep -o "$1:[^\" ]*q[^\" ]*" | grep -E -v 'text|base|fp|q[45]_[01]'
