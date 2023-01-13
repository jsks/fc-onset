# Makefile template for Rmarkdown projects
#
# Includes implicit rules to generate docx, pdf, and html versions of
# Rmd files as well as several commands for development workflows.
#
# Invoke `make help` to get started.
#
# By default, Make will compile the pdf versions of all Rmd files
# found in the current working directory.
#
# Note, this Makefile only targets GNU Make + Linux, and requires the
# following dependencies:
#     - entr
#     - pandoc
#     - R & Rmarkdown
###

SHELL = /bin/bash -eo pipefail

rmd_files  := $(wildcard *.Rmd)
docx_files := $(rmd_files:%.Rmd=%.docx)
html_files := $(rmd_files:%.Rmd=%.html)
tex_files  := $(rmd_files:%.Rmd=%.tex)
pdf_files  := $(rmd_files:%.Rmd=%.pdf)

all: $(pdf_files) ## Default rule generates pdf versions of all Rmd files
.PHONY: clean help todo watch wc

###
# Development commands as PHONY targets
clean: ## Clean generated html, tex, and pdf files
	rm -f $(docx_files) $(html_files) $(tex_files) $(pdf_files)

help:
	@printf 'Compile a specific document with `make <file.pdf>.`\n\n'
	@printf 'Additionally, the following commands are available:\n\n'
	@egrep '^\S+:.*##' $(MAKEFILE_LIST) | \
		sort | \
		awk -F ':.*##' \
			'{ printf "\t\033[01;34m%-5s \033[00;37m%s\033[0m\n", $$1, $$2 }'
	@printf '\n'

todo: ## List TODO comments in project files tracked by git
	@grep --color=always --exclude=Makefile -rni todo $$(git ls-files) | :

watch: ## Auto-rebuild pdf documents (requires the program `entr`)
	ls *.Rmd | entr -r make -f ./Makefile

wc: $(rmd_files) ## Rough estimate of word count per Rmd file
	@# Strip code blocks and bibliography before word count
	@for i in $(rmd_files); do \
		printf "$$i: "; \
		sed -e '/^```/,/^```/d' "$$i" | \
			awk '/---/ { i++ } /---/ && i == 2 { print "suppress-bibliography: true" } 1' | \
			pandoc --quiet --citeproc -f markdown -t plain | \
			wc -w; \
	done

###
# Implicit rules for pdf and html generation
%.docx: %.Rmd
	Rscript -e "rmarkdown::render('$<', 'word_document', '$@')"

%.html: %.Rmd
	Rscript -e "rmarkdown::render('$<', 'html_document', '$@')"

%.pdf: %.Rmd
	Rscript -e "rmarkdown::render('$<', 'pdf_document', '$@')"
