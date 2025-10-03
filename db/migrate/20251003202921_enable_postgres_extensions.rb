class EnablePostgresExtensions < ActiveRecord::Migration[7.1]
  def change
    # Enable pgcrypto for encryption (HIPAA compliance)
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
  end
end
