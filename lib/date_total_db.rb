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

  def daysInMonth(year, month)
    [nil, 31, year % 4 == 0 ? 29 : 28, 31, 30,
     31, 30, 31, 31,
     30, 31, 30, 31][month] or abort("Can't find # days for date #{year}/#{month}")
  end

  def addRows(rows, firstJD, lastJD)
    resMin = @db.execute("select min(chart_date), total_value from totals where chart_date >= #{ firstJD} and chart_date <= #{ lastJD }")[0]
    rows << resMin if resMin
    resMax = @db.execute("select max(chart_date), total_value from totals where chart_date >= #{firstJD} and chart_date <= #{lastJD}")[0]
    rows << resMax if resMax and resMax[0] != resMin[0]
  end

  def reduced_rows
    today = Date.today
    thisYear = today.year
    thisMonth = today.month
    border2Month = thisMonth - 1
    border2Year = thisYear
    if border2Month < 1
      border2Year -= 1
      border2Month += 12
    end
    border1Year = border2Year - 1
    border1Month = border2Month
    
    firstDateEntry = @db.execute("select min(chart_date), total_value from totals")[0]
    firstDate = Date.jd(firstDateEntry[0])
    final_rows = [firstDateEntry]
    year = firstDate.year
    month = firstDate.month
    while year < border1Year
      firstJD = year == firstDate.year ? firstDateEntry[0] + 1 : Date.parse("#{year}-1-1").jd
      lastJD = Date.parse("#{year}-12-31").jd
      addRows(final_rows, firstJD, lastJD)
      year += 1
    end
    if border1Month > 1
      firstJD = Date.parse("#{year}-01-01").jd
      lastJD = Date.parse("#{year}-#{border1Month}-#{daysInMonth(year, border1Month)}").jd
      addRows(final_rows, firstJD, lastJD)
      month = border1Month + 1
      if month > 12
        year += 1
        month = 1
      end
    end

    while year < border2Year || year == border2Year && month < border2Month
      firstJD = Date.parse("#{year}-#{month}-1}").jd
      lastJD = Date.parse("#{year}-#{month}-#{daysInMonth(year, month)}").jd
      addRows(final_rows, firstJD, lastJD)
      month += 1
      if month == 13
        month = 1
        year += 1
      end
    end
      
    today = Date.today
    thisYear = today.year
    thisMonth = today.month
    firstJD = Date.parse("#{year}-#{month}-1").jd
    lastJD = Date.parse("#{thisYear}-#{thisMonth}-#{today.day}").jd
    res = @db.execute("select chart_date, total_value from totals where chart_date >= #{firstJD} and chart_date <= #{lastJD}")
    final_rows += res
    final_rows.map do |dateJD, value|
      dateString = Date.jd(dateJD).to_s
      [dateString, value]
    end
  end
                    
  def rows
    latest_month_query = "select max(chart_date) from totals"
    latest_month_result = @db.execute(latest_month_query)
    latest_month_as_date = Date.jd(latest_month_result[0][0])
    ly = latest_month_as_date.year
    lm = latest_month_as_date.month
    final_ly, final_lm = (lm <= 2 ? [ly - 1, lm + 10] : [ly, lm - 2])

    all_the_rows = all_rows
    # Always keep the first row
    final_rows = [all_the_rows.shift]

    all_the_rows = all_the_rows.map do |dateString, value|
      date = DateTime.parse(dateString)
      [date.year, date.month, dateString, value]
    end
    first_row = all_the_rows.shift
    curr_year = first_row[0]
    curr_month = first_row[1]
    curr_min_value = curr_max_value = first_row[3]
    curr_min = first_row
    curr_max = first_row

    keep_index = all_the_rows.find_index { |year, month, _, _ |
      (year == final_ly && month > final_lm) || year > final_ly
    }
    rows_to_filter = all_the_rows[0 ... keep_index]
    rows_to_keep = all_the_rows[keep_index .. -1]
    first_row = nil

    rows_to_filter.each do |row|
      year, month, _, value = row
      if curr_year < year || curr_month < month
        if first_row
          if first_row[2] < curr_min[2]
            final_rows << first_row[2..3]
          end
          first_row = nil
        end
        if curr_year < year
          first_row = row
        end
        final_rows += sort_rows(curr_min_value, curr_min, curr_max_value, curr_max)
        curr_year = year
        curr_month = month
        curr_min_value = curr_max_value = value
        curr_min = curr_max = row
      else
        if curr_min_value < value
          curr_min_value = value
          curr_min = row
        elsif curr_max_value > value
          curr_max_value = value
          curr_max = row
        end
      end
    end
    if first_row && first_row[2] < curr_min[2]
      final_rows << first_row[2..3]
    end
    final_rows += sort_rows(curr_min_value, curr_min, curr_max_value, curr_max)
    final_rows += rows_to_keep.map{|x| x[2..3]}
    final_rows
  end

  def all_rows
    result = @db.execute("select * from totals order by chart_date ASC")
    result.map { |row| [ Date.jd(row[0]).to_s, row[1]] }
  end

  private

  def sort_rows(curr_min_value, curr_min, curr_max_value, curr_max)
    return [curr_min[2..3]] if curr_min_value == curr_max_value
    return [curr_min[2..3], curr_max[2..3]].sort
  end
end
