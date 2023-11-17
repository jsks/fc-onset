data {
    int n;

    // Treatment
    int k;
    matrix<lower=0, upper=1>[n, k] T;
    int<lower=1, upper=k> interaction_id;

    // Additional covariates
    int m;
    matrix[n, m] X;

    int<lower=1> n_countries;
    array[n] int<lower=1, upper=n_countries> country_id;

    int<lower=1> n_conflict_types;
    array[n] int<lower=1, upper=n_conflict_types> conflict_type;

    array[n] int<lower=0, upper=1> y;
}

parameters {
    real alpha;
    vector[m] beta;

    //vector[n_countries] raw_country;
    //real<lower=0, upper=pi()/2> sigma_unif;

    matrix[n_conflict_types, k] raw_delta;
    vector[k] mu;
    vector<lower=0, upper=pi()/2>[k] tau_unif;
}

transformed parameters {
    // sigma ~ HalfCauchy(0, 1)
    //real sigma = tan(sigma_unif);

    // Z_country ~ normal(0, sigma);
    //vector[n_countries] Z_country = raw_country * sigma;

    vector[k] tau;
    matrix[n_conflict_types, k] delta;

    for (i in 1:k) {
        tau[i] = tan(tau_unif[i]);
        delta[, i] = mu[i] + raw_delta[, i] * tau[i];
    }

    vector[n] nu = alpha + X * beta;
    for (i in 1:k)
        nu += T[, i] .* delta[conflict_type, i];

    vector[n] theta = Phi_approx(nu);
}

model {
    alpha ~ normal(0, 5);
    beta ~ normal(0, 2.5);

    mu ~ normal(1, 1);
    for (i in 1:k)
        raw_delta[, i] ~ std_normal();

    //raw_country ~ std_normal();

    target += bernoulli_lpmf(y | theta);
}

generated quantities {
    // Average marginal effects per treatment condition
    array[k] real ame;
    {
        vector[n] base = alpha + X * beta;
        vector[n] T0 = Phi_approx(base);

        for (i in 1:k) {
            if (i == interaction_id)
                ame[i] = mean(Phi_approx(base + sum(delta[conflict_type, ])) - T0);
            else
                ame[i] = mean(Phi_approx(base + delta[conflict_type, i]) - T0);
        }
    }
}
