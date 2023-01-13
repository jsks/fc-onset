data {
  int N;
  int k;

  matrix[N, k] X;

  array[N] int<lower=0, upper=1> y;
}

parameters {
  real alpha;
  vector[k] beta;
}

transformed parameters {
  vector[N] theta;
  theta = X * beta + alpha;
}

model {
  y ~ bernoulli_logit(theta);
}
