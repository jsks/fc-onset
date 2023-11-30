data {
    int n;

    int k;
    matrix<lower=0, upper=1>[n, k] T;

    int m;
    matrix[n, m] X;

    int<lower=1> n_countries;
    array[n] int<lower=1, upper=n_countries> country_id;

    int<lower=1> n_contest_types;
    array[n] int<lower=1, upper=n_contest_types> contest_id;
}

generated quantities {
    real alpha = normal_rng(0, 2.5);
    array[m] real beta;
    for (i in 1:m)
        beta[i] = normal_rng(0, 1);

    real<lower=0> sigma = abs(normal_rng(0, 1));
    array[n_countries] real gamma;
    for (i in 1:n_countries)
        gamma[i] = normal_rng(0, sigma);

    array[k] real mu;
    mu[1] = normal_rng(0.5, 1);
    mu[2] = normal_rng(0.5, 1);
    mu[3] = normal_rng(0, 1);

    array[k] real<lower=0> tau;
    for (i in 1:k)
        tau[i] = abs(normal_rng(0, 2));

    matrix[k, n_contest_types] delta;
    for (i in 1:k) {
        for (j in 1:n_contest_types)
            delta[i, j] = normal_rng(mu[i], tau[i]);
    }

    array[n] real<lower=0, upper=1> theta;
    for (i in 1:n) {
        theta[i] = Phi_approx(alpha + dot_product(X[i, ], to_vector(beta)) +
                                dot_product(T[i, ], delta[, contest_id[i]]) +
                                gamma[country_id[i]]);
    }


    array[n] real y_sim = bernoulli_rng(theta);
}
