class CreateQueries < ActiveRecord::Migration[7.1]
  def change
    create_table :queries do |t|
      t.references :user, null: false, foreign_key: true
      t.text :question, null: false
      t.text :answer
      t.string :status, default: 'pending', null: false
      t.float :processing_time
      t.jsonb :metadata, default: {}
      t.datetime :queried_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end

    add_index :queries, :status
    add_index :queries, :queried_at
    add_index :queries, [:user_id, :queried_at]
    add_index :queries, :metadata, using: :gin
  end
end
