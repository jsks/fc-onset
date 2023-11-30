functions {
    vector colSums(matrix m) {
        vector[cols(m)] sums;
        for (i in 1:cols(m))
            sums[i] = sum(m[, i]);

        return sums;
    }
}

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

    vector[n_countries] raw_country;
    real<lower=0> sigma;

    matrix[K, n_contest_types] raw_delta;
    vector[K] mu;
    vector<lower=0>[K] tau;
}

transformed parameters {
    // gamma ~ normal(0, sigma);
    vector[n_countries] gamma = raw_country * sigma;

    // delta[i, j] ~ normal(mu_i, tau_i)
    matrix[K, n_contest_types] delta;
    for (i in 1:n_contest_types)
        delta[, i] = mu + raw_delta[, i] .* tau;

    vector<lower=0, upper=1>[N] theta = Phi_approx(alpha + X * beta + gamma[country_id] +
                                                   rows_dot_product(T, delta[, contest_id]'));
}

model {
    // Priors
    target += normal_lupdf(alpha | 0, 2.5);
    target += std_normal_lupdf(beta);

    target += std_normal_lupdf(raw_country);
    target += std_normal_lupdf(sigma);

    target += std_normal_lupdf(to_vector(raw_delta));
    target += normal_lupdf(mu | 0.5, 1);
    target += normal_lupdf(tau | 0, 2.5);

    // Likelihood
    target += bernoulli_lpmf(y | theta);
}

generated quantities {
    // Log-likelihood
    vector[N] log_lik;
    for (i in 1:N)
        log_lik[i] = bernoulli_lpmf(y[i] | theta[i]);

    // AME per treatment condition by incompatibility group
    matrix[K, n_contest_types] ame = rep_matrix(0, K, n_contest_types);
    {
        // First, calculate the marginal effects for each observation
        array[K] vector[N] margins;
        vector[N] base = alpha + X * beta + gamma[country_id];
        vector[N] T0 = Phi_approx(base);

        for (i in 1:K) {
            if (i == interaction_id)
                margins[i] = Phi_approx(base + colSums(delta[, contest_id])) - T0;
            else
                margins[i] = Phi_approx(base + to_vector(delta[i, contest_id])) - T0;
        }

        // Average over each type of incompatibility
        for (i in 1:n_contest_types) {
            int count = 0;

            for (j in 1:N) {
                if (contest_id[j] != i)
                   continue;

                count += 1;
                for (k in 1:K)
                    ame[k, i] += margins[k][j];
             }

             ame[, i] /= count;
         }
    }
}
