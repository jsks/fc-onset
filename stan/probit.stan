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

    int<lower=1> n_contest_types;
    array[n] int<lower=1, upper=n_contest_types> contest_id;

    array[n] int<lower=0, upper=1> y;
}

parameters {
    real alpha;
    vector[m] beta;

    vector[n_countries] raw_country;
    real<lower=0> sigma;

    matrix[k, n_contest_types] raw_delta;
    vector[k] mu;
    vector<lower=0>[k] tau;
}

transformed parameters {
    // gamma ~ normal(0, sigma);
    vector[n_countries] gamma = raw_country * sigma;

    // delta[i, j] ~ normal(mu_i, tau_i)
    matrix[k, n_contest_types] delta;
    for (i in 1:n_contest_types)
        delta[, i] = mu + raw_delta[, i] .* tau;

    vector<lower=0, upper=1>[n] theta = Phi_approx(alpha + X * beta + gamma[country_id] +
                                                   rows_dot_product(T, delta[, contest_id]'));
}

model {
    // Priors
    target += normal_lupdf(alpha | 0, 5);
    target += normal_lupdf(beta | 0, 2.5);

    target += std_normal_lupdf(raw_country);
    target += normal_lupdf(sigma | 0, 2);

    target += std_normal_lupdf(to_vector(raw_delta));
    target += normal_lupdf(mu | 1, 1);
    target += normal_lupdf(tau | 0, 2);

    // Likelihood
    target += bernoulli_lpmf(y | theta);
}

generated quantities {
    // Average marginal effects per treatment condition
    array[k] real ame;
    {
        vector[n] base = alpha + X * beta + gamma[country_id];
        vector[n] T0 = Phi_approx(base);

        vector[n_contest_types] T3;
        for (i in 1:n_contest_types)
            T3[i] = sum(delta[, i]);

        for (i in 1:k) {
            if (i == interaction_id)
                ame[i] = mean(Phi_approx(base + T3[contest_id]) - T0);
            else
                ame[i] = mean(Phi_approx(base + to_vector(delta[i, contest_id])) - T0);
        }
    }
}
