# Audit trail for passport-grade files: every download is attributable.
# Rows live and die with their document (5-year retention purge included).
class DocumentAccess < ApplicationRecord
  VIAS = %w[download archive].freeze

  belongs_to :request_document
  belongs_to :user, strict_loading: false

  validates :via, inclusion: { in: VIAS }
end
