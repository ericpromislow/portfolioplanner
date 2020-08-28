require 'rspec'

require 'date'

spec_dir = File.dirname(__FILE__)
base_dir = File.absolute_path(File.dirname(spec_dir))
$:.push(File.join(base_dir, "lib"))
tmp_dir = File.join(base_dir, "tmp")


require 'date_total_db'

describe 'DateTotalDatabase' do

  it 'create a database' do
    db_path = File.join(tmp_dir, "totals.db")
    if File.exist?(db_path)
      File.delete(db_path)
    end
    db = DateTotalDatabase.new(tmp_dir, "totals.db")
    dates = ["2020-01-01", "2020-02-01", "2020-03-01"]
    begin
      db.add(dates[0], 100)
      db.add(dates[1], 130)
      db.add(dates[2], 140)
    ensure
      db.close
    end

    db2 = DateTotalDatabase.new(tmp_dir, "totals.db")
    begin
      vals = db2.rows
      expect(vals.size).to eql(3)
      expect(vals).to include(
        [dates[0], 100],
        [dates[1], 130],
        [dates[2], 140],
      )
    ensure
      db.close
    end
  end
end
