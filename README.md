# ActiveFedora

Code: [![Version](https://badge.fury.io/rb/active-fedora.png)](http://badge.fury.io/rb/active-fedora)
[![Build Status](https://circleci.com/gh/samvera/active_fedora.svg?style=svg)](https://circleci.com/gh/samvera/active_fedora)
[![Coverage Status](https://coveralls.io/repos/github/samvera/active_fedora/badge.svg?branch=master)](https://coveralls.io/github/samvera/active_fedora?branch=master)

Docs: [![Contribution Guidelines](http://img.shields.io/badge/CONTRIBUTING-Guidelines-blue.svg)](./CONTRIBUTING.md)
[![Apache 2.0 License](http://img.shields.io/badge/APACHE2-license-blue.svg)](./LICENSE)

Jump in: [![Slack Status](http://slack.samvera.org/badge.svg)](http://slack.samvera.org/)

# What is ActiveFedora?

ActiveFedora is a Ruby gem for creating and
managing objects in the Fedora Repository Architecture
([http://fedora-commons.org](http://fedora-commons.org)). ActiveFedora
is loosely based on “ActiveRecord” in Rails. Version 9.0+ works with Fedora 4 and prior versions work on Fedora 3. Version 9.2+ works with Solr 4.10. Version 10.0+ works with Fedora >= 4.5.1.

## Product Owner & Maintenance
ActiveFedora is a Core Component of the Samvera community. The documentation for
what this means can be found
[here](http://samvera.github.io/core_components.html#requirements-for-a-core-component).

### Product Owner

[no-reply](https://github.com/no-reply)

# Help

The Samvera community is here to help. Please see our [support guide](./SUPPORT.md).

# Getting Started

The [Dive into Hydra](https://github.com/samvera/hydra/wiki/Dive-into-Hydra)
gives you a brief tour through ActiveFedora’s features on the command line.

## Prerequisites

- A Fedora Commons Repository installation (configured by URL in fedora.yml)
- A Solr index (configured by URL in solr.yml)
- A JDK8+ installation (if running the test suite)

## Installation

The gem is hosted on rubygems.

```bash
gem install active-fedora
```

## Generators

You can generate a model inheriting from ActiveFedora::Base.

```bash
rails generate active_fedora:model Book
```

## Testing (this Gem)

In order to run the RSpec tests, you need to have a copy of the
ActiveFedora source code, and then run bundle install in the source
directory. You can download the source code by doing the following:

```bash
git clone https://github.com/samvera/active_fedora.git
cd active_fedora
bundle install
```

### Using the continuous integration server

You can test ActiveFedora using the same process as our continuous
integration server. This will automatically pull down a copy of Solr and Fedora Content Repository.

The `ci` rake task will download solr and fedora, start them,
and run the tests for you.

```bash
rake active_fedora:ci
```

### Testing Manually

If you want to run the tests manually, follow these instructions:

```bash
solr_wrapper
```

To start FCRepo, open another shell and run:

```bash
fcrepo_wrapper -p 8986
```

Now you’re ready to run the tests. In the directory where active\_fedora
is installed, run:

```bash
rake spec
```

## Contributing

If you're working on PR for this project, create a feature branch off of `main`.

This repository follows the [Samvera Community Code of Conduct](https://samvera.atlassian.net/wiki/spaces/samvera/pages/405212316/Code+of+Conduct) and [language recommendations](https://github.com/samvera/maintenance/blob/master/templates/CONTRIBUTING.md#language).  Please ***do not*** create a branch called `master` for this repository or as part of your pull request; the branch will either need to be removed or renamed before it can be considered for inclusion in the code base and history of this repository.

# Release Process

The [release process](https://github.com/samvera/active_fedora/wiki/Release-management-process) is documented on the wiki.

# Acknowledgments

This software has been developed by and is brought to you by the Samvera community.  Learn more at the
[Samvera website](http://samvera.org/).

![Samvera Logo](https://wiki.duraspace.org/download/thumbnails/87459292/samvera-fall-font2-200w.png?version=1&modificationDate=1498550535816&api=v2)
