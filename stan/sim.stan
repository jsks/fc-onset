data {
    int N;

    int K;
    matrix<lower=0, upper=1>[N, K] T;

    int M;
    matrix[N, M] X;

    int<lower=1> n_countries;
    array[N] int<lower=1, upper=n_countries> country_id;

    int<lower=1> n_contest_types;
    array[N] int<lower=1, upper=n_contest_types> contest_id;
}

generated quantities {
    real alpha = normal_rng(0, 2.5);
    array[M] real beta;
    for (i in 1:M)
        beta[i] = normal_rng(0, 1);

    real<lower=0> sigma = abs(normal_rng(0, 1));
    array[n_countries] real gamma;
    for (i in 1:n_countries)
        gamma[i] = normal_rng(0, sigma);

    array[K] real mu;
    for (i in 1:K)
        mu[i] = std_normal_rng();

    array[K] real<lower=0> tau;
    for (i in 1:K)
        tau[i] = abs(normal_rng(0, 2.5));

    matrix[K, n_contest_types] delta;
    for (i in 1:K) {
        for (j in 1:n_contest_types)
            delta[i, j] = normal_rng(mu[i], tau[i]);
    }

    array[N] real<lower=0, upper=1> theta;
    for (i in 1:N) {
        theta[i] = Phi_approx(alpha + dot_product(X[i, ], to_vector(beta)) +
                                dot_product(T[i, ], delta[, contest_id[i]]) +
                                gamma[country_id[i]]);
    }


    array[N] real y_sim = bernoulli_rng(theta);
}
