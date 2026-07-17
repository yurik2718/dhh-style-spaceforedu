class CreateDocumentAccesses < ActiveRecord::Migration[8.1]
  def change
    create_table :document_accesses do |t|
      t.references :request_document, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :via, null: false

      t.timestamps
    end
  end
end
