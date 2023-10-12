data {
    int n;

    // Treatment
    int k;
    matrix<lower=0, upper=1>[n, k] T;

    // Additional covariates
    int m;
    matrix[n, m] X;

    int<lower=1> n_countries;
    array[n] int<lower=1, upper=n_countries> country_id;

    array[n] int<lower=0, upper=1> y;

    int<lower=0, upper=1> sample_prior;
}

parameters {
    real alpha;
    vector[m] beta;
    vector[k] delta;

    vector[n_countries] raw_country;
    real<lower=0, upper=pi()/2> sigma_unif;
}

transformed parameters {
    // sigma ~ HalfCauchy(0, 1)
    real sigma = tan(sigma_unif);

    // Z_country ~ normal(0, sigma);
    vector[n_countries] Z_country = raw_country * sigma;

    vector[n] theta = Phi_approx(alpha + X * beta + T * delta + Z_country[country_id]);
}

model {
    alpha ~ normal(0, 5);
    beta ~ normal(0, 2.5);
    delta ~ normal(0, 2.5);

    raw_country ~ std_normal();

    if (sample_prior == 0)
       target += bernoulli_lpmf(y | theta);
}
