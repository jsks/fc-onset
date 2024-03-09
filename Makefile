# Pipeline runner for the Frozen Conflict Onset project
#
# Note, this Makefile only targets GNU Make (>=4.4) + Linux, and
# requires the following dependencies:
#     - Cmdstanr/Cmdstan
#     - pandoc
#     - R
#     - quarto-cli
#     - zip
#
# Invoke `make help` to get started.
###

SHELL = /bin/bash -eo pipefail -O globstar

# Default command for running/building project containers/image
CONTAINER_CMD ?= podman

# Default output directory for manuscript files
OUTPUT_DIR    ?= .
_mk           != mkdir -p $(OUTPUT_DIR)

# Additional options passed to quarto
QUARTO_OPTS   ?=

manuscript := paper.qmd
qmd_files  != ls ./**/*.qmd
qmd_slides := $(wildcard slides/*.qmd)

data       := data
model_data := $(data)/model_inputs
dataset    := $(data)/dataset
raw        := $(data)/raw
post       := posteriors

# Define as normal variable to defer execution. Grab the last line because renv
# has decided to hijack stdout even in non-interactive sessions.
cmdstan	   := Rscript -e 'cat(cmdstanr::cmdstan_path())' | tail -n1
stan_model := stan/hierarchical_probit

schemas     := $(wildcard $(model_data)/*.RData)
model_fits  := $(schemas:$(model_data)/%.RData=$(post)/%/fit.rds)

all: $(manuscript:%.qmd=$(OUTPUT_DIR)/%.pdf) ## Default rule generates manuscript pdf
.PHONY: bootstrap build clean dataset help models todo preview wc wp
.SECONDARY:

###
# Development commands
clean: ## Clean generated files
	rm -rf $(foreach ext,pdf docx html tex log,$(qmd_files:%.qmd=%.$(ext))) \
		$(qmd_files:%.qmd=%_files) $(data)/*.{csv,rds,RData} \
		$(model_data)
	$(MAKE) -C $$($(cmdstan)) STANPROG=$(CURDIR)/$(stan_model) clean-program

help:
	@printf 'To run all models and compile $(manuscript):\n\n'
	@printf '\t$$ make bootstrap\n'
	@printf '\t$$ make -O -j$(shell nproc)\n\n'
	@printf 'Compile a specific document or output format with `make <file.[html|pdf|docx]>.`\n'
	@printf 'Additionally, the following commands are available:\n\n'
	@grep -E '^\S+:.*##' $(MAKEFILE_LIST) | \
		sort | \
		awk -F ':.*##' \
			'{ printf "\t\033[01;34m%-10s \033[00;37m%s\033[0m\n", $$1, $$2 }'
	@printf '\n'

todo: ## List TODO comments in project files tracked by git
	@grep --color=always --exclude=Makefile -rni todo $$(git ls-files) || :

preview: ## Auto-rebuild html manuscript
	quarto preview $(manuscript) --to html

wc: paper.qmd ## Rough estimate of word count for manuscript
	@printf '$(manuscript): '
	@scripts/wordcount.sh $(manuscript)

wp: QUARTO_OPTS += --cache-refresh
wp: QUARTO_OPTS += -o $(OUTPUT_DIR)/Frozen_Conflict-$(shell date +'%F')-$(shell git rev-parse --short HEAD).pdf
wp: $(manuscript:%.qmd=$(OUTPUT_DIR)/%.pdf) ## Working paper build for manuscript pdf

###
# Container image
build:  ## Build container image
	git archive --format=tar.gz -o fc-onset-HEAD.tar.gz HEAD
	$(CONTAINER_CMD) build --jobs $(shell nproc) -t ghcr.io/jsks/fc-onset .

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

bootstrap: R/models.R data/merged_data.rds ## Generate datasets for each model run
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
	$(MAKE) -C $$($(cmdstan)) $(CURDIR)/stan/$*

$(post)/%/fit.rds: \
		R/probit.R \
		$(model_data)/%.RData \
		$(stan_model) \
	data/merged_data.rds
	Rscript $< $(model_data)/$*.RData

models: $(model_fits) ## Run all Stan models
ifndef model_fits
	$(error No model inputs found. Run `make bootstrap` first to generate.)
endif

###
# Presentation slides
slides/%.html: slides/%.qmd
	quarto render $< --to revealjs $(QUARTO_OPTS)

slides/%.pdf: slides/%.qmd
	quarto render $< --to beamer $(QUARTO_OPTS)

slides: $(qmd_slides:slides/%.qmd=slides/%.html) ## Generate presentation slides

###
# Manuscript dependencies
$(foreach ext, pdf docx html, $(manuscript:%.qmd=$(OUTPUT_DIR)/%.$(ext))): \
		templates/title.tex \
		templates/before-body.tex \
		$(raw)/frozen_conflicts.rds \
		$(data)/merged_data.rds \
		$(model_fits) \
		.WAIT $(post)/sbc.rds

###
# Implicit rules for pdf and html generation
$(OUTPUT_DIR)/%.docx: %.qmd
	quarto render $< --to docx --output-dir $(@D) $(QUARTO_OPTS)

$(OUTPUT_DIR)/%.html: %.qmd
	quarto render $< --to html --output-dir $(@D) $(QUARTO_OPTS)

$(OUTPUT_DIR)/%.pdf: %.qmd
	quarto render $< --to pdf --output-dir $(@D) $(QUARTO_OPTS)
