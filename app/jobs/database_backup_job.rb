class DatabaseBackupJob < ApplicationJob
  queue_as :default

  KEEP_DAYS = 7

  # Daily snapshot of every SQLite database via VACUUM INTO — SQLite's official
  # safe online-backup mechanism. Snapshots land in storage/backups/<date>/ on
  # the app volume; ship that directory off-site (see doc/deploy.md).
  def perform(backups_root_override = nil)
    @backups_root = backups_root_override && Pathname(backups_root_override)
    date_dir = backups_root.join(Time.current.strftime("%Y-%m-%d"))
    FileUtils.mkdir_p(date_dir)

    sqlite_configs.each do |config|
      source      = File.expand_path(config.database, Rails.root)
      destination = date_dir.join("#{config.name}.sqlite3")
      next unless File.exist?(source)

      FileUtils.rm_f(destination) # VACUUM INTO refuses to overwrite
      database = SQLite3::Database.new(source)
      begin
        database.execute("VACUUM INTO ?", destination.to_s)
      ensure
        database.close
      end
    end

    prune
  end

  private
    def backups_root
      @backups_root || Rails.root.join("storage", "backups")
    end

    def sqlite_configs
      ActiveRecord::Base.configurations
        .configs_for(env_name: Rails.env.to_s)
        .select { |config| config.adapter == "sqlite3" }
    end

    def prune
      Dir.children(backups_root).sort.reverse.drop(KEEP_DAYS).each do |stale|
        FileUtils.rm_rf(backups_root.join(stale))
      end
    end
end
