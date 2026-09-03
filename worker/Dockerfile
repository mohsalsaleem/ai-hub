FROM ruby:3.3.6-slim

WORKDIR /worker

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libyaml-0-2 sqlite3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY worker.rb ./
COPY lib ./lib

RUN groupadd --system --gid 1000 worker && \
    useradd --system --create-home --uid 1000 --gid worker worker && \
    mkdir -p /state && chown -R worker:worker /worker /state

USER worker
VOLUME ["/state"]

CMD ["ruby", "worker.rb"]
