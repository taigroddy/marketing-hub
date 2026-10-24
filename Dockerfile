FROM ruby:3.3-slim

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      curl \
      git \
      libpq-dev \
      libyaml-dev \
      nodejs \
      npm \
      pkg-config \
      postgresql-client \
      tzdata && \
    npm install -g yarn && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Pre-install bundler and rails 8 for bootstrapping
RUN gem install bundler && gem install rails -v '~> 8.0.0'

WORKDIR /app

# Install entrypoint script
COPY bin/docker-entrypoint /usr/bin/docker-entrypoint
RUN chmod +x /usr/bin/docker-entrypoint

ENTRYPOINT ["docker-entrypoint"]
EXPOSE 3000

CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
