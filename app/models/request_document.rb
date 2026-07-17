class RequestDocument < ApplicationRecord
  KINDS          = %w[diploma transcript passport language_certificate apostille translation].freeze
  REQUIRED_KINDS = %w[diploma transcript passport].freeze

  belongs_to :homologation_request, inverse_of: :request_documents
  has_one_attached :file
  has_many :document_accesses, dependent: :delete_all

  validates :kind, inclusion: { in: KINDS }, uniqueness: { scope: :homologation_request_id }
  validates :file, attached: true,
                   content_type: %w[application/pdf image/jpeg image/png image/webp],
                   size: { less_than: 15.megabytes }

  scope :required, -> { where(kind: REQUIRED_KINDS) }

  def required? = REQUIRED_KINDS.include?(kind)

  def record_access!(by:, via:)
    document_accesses.create!(user: by, via: via)
  end

  # The browser saves this as Content-Disposition's filename. Predictable
  # across students so admin can pile downloads into one folder without
  # collisions: passport_Anna.pdf, passport_Maria.pdf, not two IMG_2841.JPG.
  def download_filename
    "#{kind}_#{FilenameSlug.from(homologation_request.user.name)}#{File.extname(file.filename.to_s)}"
  end
end
