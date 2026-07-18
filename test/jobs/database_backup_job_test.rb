require "test_helper"

class DatabaseBackupJobTest < ActiveSupport::TestCase
  setup do
    # Own root per test run: the suite runs in parallel workers and the shared
    # storage/backups would race on the VACUUM INTO destination.
    @backups_root = Pathname(Dir.mktmpdir("backups"))
  end

  teardown do
    FileUtils.rm_rf(@backups_root)
  end

  test "writes a dated, valid snapshot of the primary database" do
    DatabaseBackupJob.perform_now(@backups_root.to_s)

    snapshot = @backups_root.join(Time.current.strftime("%Y-%m-%d"), "primary.sqlite3")
    assert File.exist?(snapshot), "expected #{snapshot} to exist"

    db = SQLite3::Database.new(snapshot.to_s, readonly: true)
    assert_equal "ok", db.get_first_value("PRAGMA integrity_check")
    assert db.get_first_value("SELECT COUNT(*) FROM users").positive?
  ensure
    db&.close
  end

  test "keeps only the newest #{DatabaseBackupJob::KEEP_DAYS} daily snapshots" do
    stale_days = 10.downto(1).map { |n| (Date.current - n).iso8601 }
    stale_days.each { |day| FileUtils.mkdir_p(@backups_root.join(day)) }

    DatabaseBackupJob.perform_now(@backups_root.to_s)

    remaining = Dir.children(@backups_root).sort
    assert_equal DatabaseBackupJob::KEEP_DAYS, remaining.size
    assert_includes remaining, Time.current.strftime("%Y-%m-%d")
    assert_equal remaining, stale_days.push(Date.current.iso8601).last(DatabaseBackupJob::KEEP_DAYS)
  end
end
