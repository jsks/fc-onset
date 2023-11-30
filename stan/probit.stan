data {
    int N;

    // Treatment
    int K;
    matrix<lower=0, upper=1>[N, K] T;
    int<lower=1, upper=K> interaction_id;

    // Additional covariates
    int M;
    matrix[N, M] X;

    int<lower=1> n_countries;
    array[N] int<lower=1, upper=n_countries> country_id;

    int<lower=1> n_contest_types;
    array[N] int<lower=1, upper=n_contest_types> contest_id;

    array[N] int<lower=0, upper=1> y;
}

parameters {
    real alpha;
    vector[M] beta;

    vector[K] delta;
}

transformed parameters {
    vector<lower=0, upper=1>[N] theta = Phi_approx(alpha + X * beta + T * delta);
}

model {
    // Priors
    target += normal_lupdf(alpha | 0, 2.5);
    target += std_normal_lupdf(beta);

    target += normal_lupdf(delta | 0.5, 1);

    // Likelihood
    target += bernoulli_lpmf(y | theta);
}

generated quantities {
    // Log-likelihood
    vector[N] log_lik;
    for (i in 1:N)
        log_lik[i] = bernoulli_lpmf(y[i] | theta[i]);
}