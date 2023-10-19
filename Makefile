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

SHELL = /bin/bash -eo pipefail -O globstar

data	:= data
dataset := $(data)/dataset
raw	:= $(data)/raw

post    := posteriors

qmd_files  := $(shell ls ./**/*.qmd)
pdf_files  := $(qmd_files:%.qmd=%.pdf)

all: $(pdf_files) ## Default rule generates pdf versions of all qmd files
.PHONY: clean dataset help todo watch wc
.SECONDARY:

###
# Development commands
clean: ## Clean generated files
	rm -rf $(foreach ext,pdf docx html tex log,$(qmd_files:%.qmd=%.$(ext))) \
		$(qmd_files:%.qmd=%_files) $(data)/*.{csv,rds,RData}

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
# Onset dataset
$(data)/dyadic_candidates.csv $(data)/dyadic_episodes.csv &: \
	R/dyadic_candidates.R \
	$(raw)/ucdp-peace-agreements-221.xlsx \
	$(raw)/ucdp-term-dyad-3-2021.xlsx
	Rscript $<

$(data)/conflict_candidates.csv R/conflict_candidates.R \
	$(data)/conflict_episodes.csv &: \
	$(raw)/ucdp-peace-agreements-221.xlsx \
	$(raw)/ucdp-term-acd-3-2021.xlsx \
	$(raw)/ucdp-esd-dy-181.dta
	Rscript $<

$(dataset)/frozen_conflicts.rds: R/dataset.R \
	$(dataset)/adjusted_conflict_candidates.csv \
	$(data)/conflict_episodes.csv
	Rscript $<

doc/coding-protocol.pdf: $(data)/dyadic_candidates.csv \
	$(data)/dyadic_episodes.csv

doc/codebook.pdf: library.bib

dataset: $(dataset)/frozen_conflicts.rds \
	doc/coding-protocol.pdf \
	doc/codebook.pdf

###
# Probit Models
data/model_data.rds: R/new_merge.R \
	$(dataset)/frozen_conflicts.rds \
	$(raw)/ucdp-esd-ay-181.dta
	Rscript $<

$(post)/probit.rds: R/probit.R \
	data/model_data.rds
	Rscript $<

###
# Manuscript
paper.pdf: $(dataset)/frozen_conflicts.rds \
	$(post)/probit.rds

###
# Implicit rules for pdf and html generation
%.docx: %.qmd
	quarto render $< --to docx

%.html: %.qmd
	quarto render $< --to html

%.pdf: %.qmd
	quarto render $< --to pdf
