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

CONTAINER_CMD ?= podman ## Command for building project image
QUARTO_OPTS   ?=        ## Additional options passed to quarto
NO_SBC        ?=        ## Skip simulation-based calibration

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

schemas    := $(wildcard $(model_data)/*.RData)
model_fits := $(schemas:$(model_data)/%.RData=$(post)/%/fit.rds)

# Escape codes for colourized output in `help` command
blue   := \033[1;34m
green  := \033[0;32m
white  := \033[0;37m
reset  := \033[0m

all: $(manuscript:%.qmd=%.pdf) ## Default rule generates manuscript pdf
.PHONY: build clean dataset init help models todo preview wc wp
.SECONDARY:

###
# Development commands
clean: clean-stan ## Clean generated files
	rm -rf $(foreach ext,pdf docx html tex log,$(qmd_files:%.qmd=%.$(ext))) \
		$(qmd_files:%.qmd=%_files) $(data)/*.{csv,rds,RData} \
		$(model_data)

clean-stan: ## Clean compiled stan models
	$(MAKE) -C $$($(cmdstan)) clean-all
	rm -rf stan/{hierarchical_probit,sim}

help:
	@printf 'To run all models and compile $(manuscript):\n\n'
	@printf '\t$$ make init\n'
	@printf '\t$$ make -O -j$(shell nproc)\n\n'
	@printf 'Compile a specific document or output format with `make <file.[html|pdf|docx]>.`\n'
	@printf 'Additionally, the following commands are available:\n\n'
	@grep -E '^\S+:.*##' $(MAKEFILE_LIST) | \
		sort | \
		awk -F ':.*##' \
			'{ printf "\t$(blue)%-10s $(white)%s$(reset)\n", $$1, $$2 }'
	@printf '\nAnd, the following environmental variables can be set:\n\n'
	@grep -E '^\S+\s*\?=.*##' $(MAKEFILE_LIST) | \
		sort | \
		awk -F '?= *| *##' \
			'{ printf "\t$(blue)%-10s" \
				  "$(white)%s\t" \
				  "[Default: \"$(green)%s$(white)\"]$(reset)\n", \
			   $$1, $$3, $$2 }'
	@printf '\n'

todo: ## List TODO comments in project files tracked by git
	@grep --color=always --exclude=Makefile -rni todo $$(git ls-files) || :

preview: ## Auto-rebuild html manuscript
	quarto preview $(manuscript) --to html

wc: ## Rough estimate of word count for manuscript
	@printf '$(manuscript): '
	@scripts/wordcount.sh $(manuscript)

wp: QUARTO_OPTS += --cache-refresh
wp: $(manuscript:%.qmd=%.pdf) ## Working paper build for manuscript pdf
	mv $(manuscript:%.qmd=%.pdf) \
		Frozen_Conflict-$(shell date +'%F')-$(shell git rev-parse --short HEAD).pdf

###
# Container image
build:  ## Build container image
	git ls-files | grep -E 'renv|Makevars|Rprofile|fc.utils' | \
		tar Tczf - renv-archive.tar.gz
	$(CONTAINER_CMD) build -t ghcr.io/jsks/fc-onset .

###
# Frozen conflict dataset
$(data)/conflict_episodes.csv $(data)/conflict_candidates.csv &: \
		R/conflict_candidates.R \
		$(raw)/ucdp-peace-agreements-221.xlsx \
		$(raw)/ucdp-term-acd-3-2021.xlsx
	Rscript R/conflict_candidates.R

$(dataset)/frozen_conflicts.rds: R/dataset.R \
		$(dataset)/adjusted_conflict_candidates.csv \
		$(raw)/UcdpPrioConflict_v23_1.rds \
		$(raw)/ucdp-term-acd-3-2021.xlsx
	Rscript R/dataset.R

doc/coding-protocol.pdf: $(data)/conflict_candidates.csv $(data)/conflict_episodes.csv
doc/codebook.pdf: library.bib

dataset.zip: $(dataset)/frozen_conflicts.rds \
		doc/coding-protocol.pdf \
		doc/codebook.pdf
	zip -j $@ $^

dataset: dataset.zip ## Create a zip archive of the dataset

###
# Probit Models
$(post)/sbc.rds: R/sbc.R \
		stan/hierarchical_probit \
		stan/sim
	Rscript R/sbc.R

sbc: $(post)/sbc.rds ## Run simulation-based calibration

init: R/models.R data/merged_data.rds ## Generate datasets for each model run
	rm -rf $(model_data)
	Rscript R/models.R

data/merged_data.rds: R/merge.R \
		$(raw)/frozen_conflicts.rds \
		$(raw)/ucdp-term-acd-3-2021.xlsx \
		$(raw)/UcdpPrioConflict_v23_1.rds \
		$(raw)/ucdp-esd-ay-181.dta \
		$(raw)/NMC-60-abridged.csv \
		$(raw)/V-Dem-CY-Full+Others-v13.rds \
		refs/ucdp_countries.csv
	Rscript R/merge.R

stan/%: stan/%.stan
	$(MAKE) -C $$($(cmdstan)) $(CURDIR)/stan/$*

$(post)/%/fit.rds: \
		R/probit.R \
		$(model_data)/%.RData \
		stan/hierarchical_probit \
		data/merged_data.rds
	Rscript R/probit.R $(model_data)/$*.RData

models: $(model_fits) ## Run all Stan models
ifndef model_fits
	$(error No model inputs found. Run `make init` first to generate.)
endif

###
# Presentation slides
slides/%.html: slides/%.qmd
	quarto render $< --to revealjs $(QUARTO_OPTS)

slides/%.pdf: slides/%.qmd
	quarto render $< --to beamer $(QUARTO_OPTS)

###
# Manuscript dependencies
$(manuscript:%.qmd=%.pdf): \
		templates/title.tex \
		templates/before-body.tex

$(foreach ext, pdf docx html, $(manuscript:%.qmd=%.$(ext))): \
		$(raw)/frozen_conflicts.rds \
		$(data)/merged_data.rds \
		$(data)/conflict_episodes.csv \
		$(data)/conflict_candidates.csv \
		refs/labels.csv \
		$(model_fits)

ifndef NO_SBC
$(foreach ext, pdf docx html, $(manuscript:%.qmd=%.$(ext))): \
		.WAIT $(post)/sbc.rds
endif

###
# Implicit rules for pdf and html generation
%.docx: %.qmd
	quarto render $< --to docx $(QUARTO_OPTS)

%.html: %.qmd
	quarto render $< --to html $(QUARTO_OPTS)

%.pdf: %.qmd
	quarto render $< --to pdf $(QUARTO_OPTS)
