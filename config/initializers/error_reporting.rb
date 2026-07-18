# Unhandled controller and job exceptions land in Rails.error; in production
# they are forwarded to the owner's inbox (deduplicated, see ErrorEmailSubscriber).
Rails.application.config.after_initialize do
  Rails.error.subscribe(ErrorEmailSubscriber.new) if Rails.env.production?
end
