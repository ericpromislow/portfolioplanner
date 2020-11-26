require 'rspec'

require 'date'

spec_dir = File.dirname(__FILE__)
base_dir = File.absolute_path(File.dirname(spec_dir))
$:.push(File.join(base_dir, "lib"))
tmp_dir = File.join(base_dir, "tmp")

require 'date_total_db'

describe 'DateTotalDatabase' do

  db = nil
  before do
    db_path = File.join(tmp_dir, "totals.db")
    if File.exist?(db_path)
      File.delete(db_path)
    end
    db = DateTotalDatabase.new(tmp_dir, "totals.db")

  end

  it 'create a database' do
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

  it 'filters out older months' do
    date_and_values = [
      ["2020-01-01", 100],
      ["2020-01-02", 120],
      ["2020-01-03", 90],
      ["2020-01-04", 110],
      ["2020-02-01", 131],
      ["2020-02-02", 81],
      ["2020-02-03", 91],
      ["2020-02-04", 111],
      ["2020-03-01", 102],
      ["2020-03-02", 92],
      ["2020-03-03", 132],
      ["2020-03-04", 122],
      ["2020-04-01", 103],
      ["2020-04-02", 93],
      ["2020-04-03", 123],
  ]
    begin
      date_and_values.each { |d, v| db.add(d, v) }
    ensure
      db.close
    end

    db2 = DateTotalDatabase.new(tmp_dir, "totals.db")
    begin
      vals = db2.rows
      expect(vals.size).to eql(12)
      expect(vals).to eq(
        [["2020-01-01", 100],  # Always keep the first line regardless.
          ["2020-01-02", 120],
        ["2020-01-03", 90],
        ["2020-02-01", 131],
        ["2020-02-02", 81],
        ["2020-03-01", 102],
        ["2020-03-02", 92],
        ["2020-03-03", 132],
        ["2020-03-04", 122],
        ["2020-04-01", 103],
        ["2020-04-02", 93],
        ["2020-04-03", 123],
          ]
      )
    ensure
      db.close
    end

  end
end
