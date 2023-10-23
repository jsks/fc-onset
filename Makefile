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
#     - zip
###

SHELL = /bin/bash -eo pipefail -O globstar

manuscript := paper.qmd

data	:= data
dataset := $(data)/dataset
raw	:= $(data)/raw

post    := posteriors

qmd_files  := $(shell ls ./**/*.qmd)
pdf_files  := $(qmd_files:%.qmd=%.pdf)

schemas        := $(wildcard models/*.yml)
model_outputs  := $(schemas:models/%.yml=$(post)/%/model_output.rds)

all: $(manuscript:%.qmd=%.pdf) ## Default rule generates manuscript pdf
.PHONY: bootstrap clean dataset help models todo watch wc
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
			'{ printf "\t\033[01;34m%-10s \033[00;37m%s\033[0m\n", $$1, $$2 }'
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
$(data)/conflict_candidates.csv: \
	R/conflict_candidates.R \
	$(raw)/ucdp-peace-agreements-221.xlsx \
	$(raw)/ucdp-term-acd-3-2021.xlsx
	Rscript $<

$(dataset)/frozen_conflicts.rds: R/dataset.R \
	$(dataset)/adjusted_conflict_candidates.csv \
	$(raw)/UcdpPrioConflict_v23_1.rds \
	$(raw)/ucdp-term-acd-3-2021.xlsx
	Rscript $<

doc/coding-protocol.pdf: $(data)/conflict_candidates.csv
doc/codebook.pdf: library.bib

dataset.zip: $(dataset)/frozen_conflicts.rds \
	doc/coding-protocol.pdf \
	doc/codebook.pdf
	zip -j $@ $^

dataset: dataset.zip ## Create a zip archive of the dataset

###
# Probit Models
bootstrap: R/models.R
	rm -rf models/
	Rscript $<

data/model_data.rds: R/merge.R \
	$(raw)/frozen_conflicts.rds \
	$(raw)/ucdp-term-acd-3-2021.xlsx \
	$(raw)/UcdpPrioConflict_v23_1.rds \
	$(raw)/ucdp-esd-ay-181.dta \
	$(raw)/NMC-60-abridged.csv \
	$(raw)/V-Dem-CY-Full+Others-v13.rds \
	refs/ucdp_countries.csv
	Rscript $<

$(post)/%/model_input.RData $(post)/%/model_output.rds &: \
	R/probit.R \
	models/%.yml \
	stan/probit.stan \
	data/model_data.rds
	Rscript $< models/$*.yml

models: $(model_outputs)

###
# Manuscript
paper.pdf: $(raw)/frozen_conflicts.rds \
	$(model_outputs)

###
# Implicit rules for pdf and html generation
%.docx: %.qmd
	quarto render $< --to docx

%.html: %.qmd
	quarto render $< --to html

%.pdf: %.qmd
	quarto render $< --to pdf
