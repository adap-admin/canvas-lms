# used with circle CI
#  david101011/bytelion-circleci-ruby

FROM circleci/ruby:2.4.1-stretch

RUN sudo apt-get update ; \
    sudo apt-get install zlib1g-dev libxml2-dev \
	libsqlite3-dev libpq-dev \
	libxmlsec1-dev curl make g++ \
	postgresql-client-9.6 apt-utils

RUN curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash - ; \
    sudo apt-get install -y nodejs build-essential

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - ; \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list ; \
    sudo apt-get update && sudo apt-get install yarn=1.10.1-1

