Frozen Conflict Onset
---

![R-CMD-check workflow](https://github.com/jsks/fc-onset/actions/workflows/R-CMD-check.yml/badge.svg)

Code repository hosting replication files for the analysis of external state support and frozen civil conflict onset.

### Getting Started

The following raw data sources are required and are not distributed within this repository. They should be saved under `./data/raw`.

- [UCDP Conflict Termination Dataset v3-2021](https://ucdp.uu.se/downloads/index.html#termination) - `ucdp-term-acd-3-2021.xlsx`
- [UCDP ACD v23.1](https://ucdp.uu.se/downloads/index.html#armedconflict) - `UcdpPrioConflict_v23_1.rds`
- [UCDP External Support Dataset 181](https://ucdp.uu.se/downloads/index.html#externalsupport) - `ucdp-esd-ay-181.dta`
- [NMC 6.0](https://correlatesofwar.org/data-sets/national-material-capabilities)  - `NMC-60-abridged.csv`
- [V-Dem CY-Full v13](https://v-dem.net) - `V-Dem-CY-Full+Others-v13.rds`

### Replicating

To fully replicate all results by running the entire pipeline with an identical computing environment use the `ghcr.io/jsks/fc-onset:latest` container image. Simply mount the project directory to `/proj` and run the default command. Note, this also runs the simulation based calibration in the appendix, which may take a significant amount of time.

```sh
$ git clone https://github.com/jsks/fc-onset && cd fc-onset
$ docker run -v ./:/proj ghcr.io/jsks/fc-onset:latest
```

Alternatively, if you wish to run the pipeline in your local environment ensure that you first have the following dependencies installed:

- Bash
- GNU Make (>=4.4)
- R (>=4.0) with an appropriate toolchain
- quarto-cli with working texlive installation
- [go-yq](https://github.com/mikefarah/yq)

Then, clone the repository, install all R package dependencies using the `renv` lockfile, and install `cmdstan` using `cmdstanr`.

```sh
$ git clone https://github.com/jsks/fc-onset && cd fc-onset
$ Rscript -e "renv::restore()" -e "cmdstanr::install_cmdstan()"
```

Finally, invoke `make` directly to clean/merge the data sources, run the Stan models, and compile the final pdf, `paper.pdf`. Note, no attempt has been made to ensure the portability of the code in this project beyond Linux amd64.

```sh
$ make init # clean/merge, and prep data for Stan
$ make -O -j $(nproc) # Run all models, and compile paper.qmd
```

Additional documentation on the available commands in the pipeline can be found through `make`.

```sh
$ make help
```

## License

This project is licensed under a [Creative Commons Attribution-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-sa/4.0/).

![](https://i.creativecommons.org/l/by-sa/4.0/88x31.png)
