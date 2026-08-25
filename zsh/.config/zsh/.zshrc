# .zshrc — Zsh configuration loader
# Individual modules are in $ZDOTDIR/conf.d/ and sourced in numerical order.

for f in "${ZDOTDIR}"/conf.d/[0-9][0-9]-*.zsh(N); do
  source "$f"
done
