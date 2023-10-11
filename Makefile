# Makefile template for Quarto (qmd) files
#
# Includes implicit rules to generate docx, pdf, and html versions of
# qmd files as well as several commands for development workflows.
#
# Invoke `make help` to get started.
#
# By default, Make will compile the pdf versions of all qmd files
# found in the current working directory.
#
# Note, this Makefile only targets GNU Make + Linux, and requires the
# following dependencies:
#     - entr
#     - pandoc
#     - R
#     - quarto-cli
###

SHELL = /bin/bash -eo pipefail

qmd_files  := $(wildcard *.qmd)
docx_files := $(qmd_files:%.qmd=%.docx)
html_files := $(qmd_files:%.qmd=%.html)
tex_files  := $(qmd_files:%.qmd=%.tex)
pdf_files  := $(qmd_files:%.qmd=%.pdf)

all: $(pdf_files) ## Default rule generates pdf versions of all qmd files
.PHONY: clean help todo watch wc

###
# Development commands as PHONY targets
clean: ## Clean generated html, tex, and pdf files
	rm -f $(docx_files) $(html_files) $(tex_files) $(pdf_files)

help:
	@printf 'Compile a specific document with `make <file.pdf>.`\n\n'
	@printf 'Additionally, the following commands are available:\n\n'
	@grep -E '^\S+:.*##' $(MAKEFILE_LIST) | \
		sort | \
		awk -F ':.*##' \
			'{ printf "\t\033[01;34m%-5s \033[00;37m%s\033[0m\n", $$1, $$2 }'
	@printf '\n'

todo: ## List TODO comments in project files tracked by git
	@grep --color=always --exclude=Makefile -rni todo $$(git ls-files) || :

watch: ## Auto-rebuild pdf documents (requires the program `entr`)
	ls *.qmd | entr -r make -f ./Makefile

wc: $(qmd_files) ## Rough estimate of word count per qmd file
	@# We could use `quarto render --no-execute` instead of `sed`,
	@# but quarto is horribly slow...
	@for i in $(qmd_files); do \
		printf "$$i: "; \
		sed -e '/^```/,/^```/d' "$$i" | \
			pandoc -M 'suppress-bibliography=true' --quiet --citeproc \
				-f markdown -t plain | wc -w; \
	done

###
# Implicit rules for pdf and html generation
%.docx: %.qmd
	quarto render $< --to docx

%.html: %.qmd
	quarto render $< --to html

%.pdf: %.qmd
	quarto render $< --to pdf
