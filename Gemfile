source "https://rubygems.org"

gem "rails",             "~> 8.1"
gem "propshaft",         "~> 1.3"
gem "sqlite3",           "~> 2.9"
gem "puma",              "~> 8.0"
gem "importmap-rails",   "~> 2.2"
gem "turbo-rails",       "~> 2.0"
gem "stimulus-rails",    "~> 1.3"
gem "tailwindcss-rails", "~> 4.4"
gem "bcrypt",            "~> 3.1"

# Authorization
gem "pundit", "~> 2.5"

# Pagination
gem "pagy", "~> 43.5"

# Locale data for dates, numbers, currencies across all languages
gem "rails-i18n", "~> 8.1"

# Prevent dangerous migrations (missing null constraints, locking migrations, etc.)
gem "strong_migrations", "~> 2.7"

# Rate limiting (brute force protection on login)
gem "rack-attack", "~> 6.8"

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache",  "~> 1.0"
gem "solid_queue",  "~> 1.4"
gem "solid_cable",  "~> 3.0"

gem "bootsnap",        "~> 1.23", require: false
gem "kamal",           "~> 2.11", require: false
gem "thruster",        "~> 0.1",  require: false
gem "image_processing", "~> 1.2"
gem "heroicons",        "~> 1.0", require: "heroicon"

# Active Storage attachment validations (content_type, size)
gem "active_storage_validations", "~> 3.0"

# Zip archive of a request's attachments (admin download)
gem "rubyzip", "~> 3.0", require: "zip"

# Payments — Stripe API client (signed webhooks, payment intents)
gem "stripe", "~> 15.0"

# Web Push notifications (VAPID)
gem "web-push", "~> 3.0"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "debug",                 "~> 1.11", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit",         "~> 0.9",  require: false
  gem "brakeman",              "~> 8.0",  require: false
  gem "rubocop-rails-omakase", "~> 1.1",  require: false
end

group :development do
  gem "web-console",   "~> 4.3"
  gem "letter_opener", "~> 1.10"
  gem "hotwire-spark", "~> 0.1"
  gem "bullet",        "~> 8.1"
end

group :test do
  gem "capybara",          "~> 3.40"
  gem "selenium-webdriver", "~> 4.44"
  gem "webmock",           "~> 3.26"
end
