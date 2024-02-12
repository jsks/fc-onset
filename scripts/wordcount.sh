#!/usr/bin/env zsh
# Approximate word count for a quarto/Rmarkdown file. Includes body
# text count + references, abstract, and figure captions while
# excluding appendix and code blocks.
###

abstract=$(yq -f extract '.abstract' $1 | wc -w)

body=$(sed -e '/^```/,/^```/d' -e '/^#\s*Appendix/,$d' $1 | \
           pandoc --quiet --citeproc -f markdown -t plain | \
           wc -w)

# This assumes that only fig-cap values are multiline within code
# blocks
figure_captions=$(grep '^#|' $1 | sed -e 's/^#|\s*//' -e '/^.*:/d' | wc -w)

print "$1: $((abstract + body + figure_captions))"
