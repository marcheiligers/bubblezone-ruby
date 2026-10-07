# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# gem "bubbletea", path: "../bubbletea-ruby"
# gem "lipgloss", path: "../lipgloss-ruby"

gem "ffi", "~> 1.17", platforms: :jruby

gem "irb"
gem "maxitest", "~> 7.0"
gem "rake", "~> 13.0"
gem "rubocop", "~> 1.82"

install_if -> { RUBY_ENGINE != "jruby" } do
  gem "rake-compiler"
  gem "rake-compiler-dock"
end
