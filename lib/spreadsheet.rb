require 'rspreadsheet'

class Spreadsheet
  def create(path, analyzer)
    summary = analyzer.get_summary
    @analyzer = analyzer
    workbook = Rspreadsheet.new
    ws = workbook.create_worksheet
    @summary_rows = []

    row = 3
    ws.cell("B#{row}").value = "Allocations"
    row += 1

    row = write_header(row, ws)

    row = write_full_total(row, summary, ws)

    row = write_adjustments_by_category(row, summary, ws)

    write_final_totals(row, ws)

    workbook.save(path)
  end

  private

  def cellFromRCOne(row, column)
    cellFromRCZero(row, column - 1)
  end

  def cellFromRCZero(row, column)
    "%s%d" % [('A'.ord + column).chr, row]
  end

  def cellFromRCAlpha(row, column)
    "%s%d" % [column, row]
  end

  def write_adjustments_by_category(row, summary, ws)
    sorted_keys = @analyzer.sorted_categories(summary)
    sorted_keys.each do |category|
      adjustment = summary[:adjustments_by_category][category]
      first_row = row
      cell = ws.cell(cellFromRCAlpha(row, 'A'))
      cell.value = category
      cell.format.bold = true
      row = write_holdings_by_category(row, summary, category, ws)
      @summary_rows << row
      row = write_total_for_category(adjustment, first_row, row, ws, summary[:holdings_by_category][category].size > 0)
    end
    return row
  end


  def write_final_totals(row, ws)
    write_bold_cell(row, 'B', "Full Total", ws)
    %w/C D E F/.each do |col|
      write_bold_formula(row, col,
        @summary_rows.map{|row| cellFromRCAlpha(row, col) }.join("+"), ws)
    end
  end

  def write_total_for_category(adjustment, first_row, row, ws, have_items=true)
    write_bold_cell(row, 'B', "Total", ws)
    write_bold_cell(row, 'C', adjustment[:total], ws)
    write_bold_cell(row, 'D', adjustment[:actualFraction], ws)
    write_bold_cell(row, 'E', adjustment[:desiredFraction], ws)
    write_bold_cell(row, 'F', adjustment[:delta], ws)
    if have_items
      cell = ws.cell(cellFromRCAlpha(row, "G"))
      cell.formula = "=sum(%s:%s)" % [cellFromRCAlpha(first_row, "G"), cellFromRCAlpha(row - 1, "G")]
      cell.format.bold = true

      (first_row .. row - 1).to_a.each do |this_row|
        cell = ws.cell(cellFromRCAlpha(this_row, "H"))
        cell.formula = "=" + "(G%d/G$%d)*E$%d" % [this_row, row, row]
        cell = ws.cell(cellFromRCAlpha(this_row, "I"))
        cell.formula = "=" + "(H%d - D%d)*%s" % [this_row, this_row, @full_total_cell]
      end
    end
    return row + 1
  end

  def write_bold_cell(row, colAlpha, value, ws)
    cell = ws.cell(cellFromRCAlpha(row, colAlpha))
    cell.value = value
    cell.format.bold = true
  end

  def write_bold_formula(row, colAlpha, formula, ws)
    cell = ws.cell(cellFromRCAlpha(row, colAlpha))
    formula = "=" + formula if formula[0] != '='
    cell.formula = formula
    cell.format.bold = true
  end

  def write_cell(row, colAlpha, value, ws)
    cell = ws.cell(cellFromRCAlpha(row, colAlpha))
    cell.value = value
  end

  def write_full_total(row, summary, ws)
    cell = ws.cell(cellFromRCAlpha(row, 'A'))
    cell.value = "Full Total"
    cell.format.bold = true
    cell = ws.cell(cellFromRCAlpha(row, 'C'))
    @full_total_cell = "$C$%d" % row
    cell.value = summary[:full_total]
    cell.format.bold = true
    row + 1
  end

  def write_header(row, ws)
    ['Category', nil, nil, 'Actual %', 'Target %', 'Move', 'Category Weight',
    'Revised Target', 'Revised Move'].each_with_index do |val, i|
      next if val.nil?
      ws.cell(cellFromRCZero(row, i)).value = val
    end
    row + 1
  end

  def write_holdings_by_category(row, summary, category, ws)
    summary[:holdings_by_category][category].sort.each do |symbol, block|
      adjustment = summary[:adjustments_by_category][category]
      weight = block[:weight]
      actual_percentage = block[:value] / summary[:full_total]
      desired_percentage = (weight / 100.0) * adjustment[:desiredFraction]
      write_cell(row, "B", symbol, ws)
      write_cell(row, "C", block[:value], ws)
      write_cell(row, "D", actual_percentage, ws)
      write_cell(row, "E", desired_percentage, ws)
      write_cell(row, "F", block[:delta], ws)
      write_cell(row, "G", block[:weight], ws)
      row += 1
    end
    return row
  end

end
