#!/usr/bin/env zsh
#
# Approximate word count for a quarto/Rmarkdown file. Includes body
# text count + references, abstract, and figure captions while
# excluding appendix and code blocks.
###

setopt err_exit

if [[ $# -ne 1 ]]; then
    print -u 2 "Missing file argument"
    print -u 2 "Usage: $0 <file.[qmd|Rmd|md]>"
    exit 1
fi

[[ ! -f $1 ]] && { print -u 2 "Invalid file: $1"; exit 1 }

abstract=$(yq -f extract '.abstract' $1 | wc -w)

body=$(sed -e '/^```/,/^```/d' -e '/^#\s*Appendix/,$d' $1 | \
           pandoc --quiet --citeproc -f markdown -t plain | \
           wc -w)

# This assumes that only fig-cap values are multiline within code
# blocks
figure_captions=$(grep '^#|' $1 | sed -e 's/^#|\s*//' -e '/^.*:/d' | wc -w)

print "$((abstract + body + figure_captions))"
