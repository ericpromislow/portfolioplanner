require "sqlite3"


@spec_dir = File.dirname(__FILE__)
@base_dir = File.absolute_path(File.dirname(@spec_dir))
$:.push(File.join(@base_dir, "lib"))
@input_dir = File.join(@base_dir, "test/fixtures")

class DateTotalDatabase
  def initialize(data_dir, dbName)
    db_path = File.join(data_dir, dbName)
    if !File.exist?(db_path)

      @db = SQLite3::Database.new(db_path)

      @db.execute <<-SQL
        create table totals (
          chart_date integer primary key,
          total_value integer
      );
      SQL
    else
      @db = SQLite3::Database.open(db_path)

    end
  end

  def add(date, total)
    jd = Date.parse(date).jd
    rows = @db.execute("select * from totals where chart_date = #{jd}")
    if rows.size > 0
      @db.execute("update totals set total_value = #{total} where chart_date = #{jd}")
    else
      @db.execute("insert into totals values(#{jd}, #{total})")
    end
  end

  def close
    @db.close
  end

  def rows
    result = @db.execute("select * from totals order by chart_date ASC")
    result.map { |row| [ Date.jd(row[0]).to_s, row[1]] }
  end
end
