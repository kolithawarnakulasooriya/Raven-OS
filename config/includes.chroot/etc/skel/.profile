if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin:$PATH"
fi

export PIP_REQUIRE_VIRTUALENV=true
export PYTHONDONTWRITEBYTECODE=1