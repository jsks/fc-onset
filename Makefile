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
qmd_files  != ls ./**/*.qmd
qmd_slides := $(wildcard slides/*.qmd)

data       := data
model_data := $(data)/models
dataset    := $(data)/dataset
raw        := $(data)/raw
post       := posteriors

cmdstan    != Rscript -e 'cat(cmdstanr::cmdstan_path())'
stan_model := stan/hierarchical_probit

schemas     := $(wildcard $(model_data)/*.rds)
model_fits  := $(schemas:$(model_data)/%.rds=$(post)/%/fit.rds)

all: $(manuscript:%.qmd=%.pdf) ## Default rule generates manuscript pdf
.PHONY: bootstrap clean dataset help models todo watch wc
.SECONDARY:

###
# Development commands
clean: ## Clean generated files
	rm -rf $(foreach ext,pdf docx html tex log,$(qmd_files:%.qmd=%.$(ext))) \
		$(qmd_files:%.qmd=%_files) $(data)/*.{csv,rds,RData} \
		$(model_data)
	$(MAKE) -C $(cmdstan) STANPROG=$(CURDIR)/$(stan_model) clean-program

help:
	@printf 'To run all models and compile $(manuscript):\n\n'
	@printf '\t$$ make bootstrap\n'
	@printf '\t$$ make -j $(shell nproc)\n\n'
	@printf 'Compile a specific document or output format with `make <file.[html|pdf|docx]>.`\n'
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

wc: paper.qmd ## Rough estimate of word count for manuscript
	@# We could use `quarto render --no-execute` instead of `sed`,
	@# but quarto is horribly slow...
	@printf "$(manuscript): "; \
	sed -e '/^```/,/^```/d' "$(manuscript)" | \
		pandoc -M 'suppress-bibliography=true' --quiet --citeproc \
			-f markdown -t plain | wc -w; \

###
# Frozen conflict dataset
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
$(post)/sbc.rds: R/sbc.R \
	$(stan_model) \
	stan/sim
	Rscript $<

sbc: $(post)/sbc.rds ## Run simulation-based calibration

bootstrap: R/models.R \ ## Generate datasets for each model run
		data/merged_data.rds
	rm -rf $(model_data)
	Rscript $<

data/merged_data.rds: R/merge.R \
	$(raw)/frozen_conflicts.rds \
	$(raw)/ucdp-term-acd-3-2021.xlsx \
	$(raw)/UcdpPrioConflict_v23_1.rds \
	$(raw)/ucdp-esd-ay-181.dta \
	$(raw)/NMC-60-abridged.csv \
	$(raw)/V-Dem-CY-Full+Others-v13.rds \
	refs/ucdp_countries.csv
	Rscript $<

stan/%: stan/%.stan
	$(MAKE) -C $(cmdstan) $(CURDIR)/stan/$*

$(post)/%/fit.rds: \
	R/probit.R \
	$(model_data)/%.RData \
	$(stan_model) \
	data/merged_data.rds
	Rscript $< $(model_data)/$*.RData

models: $(model_fits) ## Run all Stan models
ifndef model_fits
	$(error No models found. Run `make bootstrap` to generate model profiles.)
endif

###
# Presentation slides
slides/%.html: slides/%.qmd
	quarto render $< --to revealjs

slides/%.pdf: slides/%.qmd
	quarto render $< --to beamer

slides: $(qmd_slides:slides/%.qmd=slides/%.html) ## Generate presentation slides

###
# Manuscript dependencies
$(foreach ext, pdf docx html, $(manuscript:%.qmd=%.$(ext))): \
	$(raw)/frozen_conflicts.rds \
	$(data)/merged_data.rds \
	$(model_fits) \
	.WAIT $(post)/sbc.rds

###
# Implicit rules for pdf and html generation
%.docx: %.qmd
	quarto render $< --to docx

%.html: %.qmd
	quarto render $< --to html

%.pdf: %.qmd
	quarto render $< --to pdf
