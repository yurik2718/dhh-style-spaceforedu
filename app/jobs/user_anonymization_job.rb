class UserAnonymizationJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user&.deletion_requested_at?

    # Full-graph teardown: this job touches every association on purpose.
    user.strict_loading!(false)
    user.anonymize!
  end
end
