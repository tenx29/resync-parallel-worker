local Dataset = {}
Dataset.__index = Dataset

function Dataset.new(headers: {string})
    local self = setmetatable({}, Dataset)
    self.headers = headers
    self.data = {}
    return self
end

function Dataset:AppendRow(row: {any}): number
    assert(#row == #self.headers, "Row length does not match number of headers")
    table.insert(self.data, row)
    return #self.data
end

function Dataset:SetRow(index: number, row: {any})
    assert(#row == #self.headers, "Row length does not match number of headers")
    self.data[index] = row
end

function Dataset:GetRow(index: number): {any}
    return self.data[index]
end

function Dataset:SetCell(row: number, column: number, value: any)
    assert(column <= #self.headers, "Column index out of bounds")
    if not self.data[row] then
        self.data[row] = {}
    end
    self.data[row][column] = value
end

function Dataset:HeaderToCsv(columns: {number}?): string
    local headerValues = {}
    for i, header in ipairs(self.headers) do
        if not columns or table.find(columns, i) then
            table.insert(headerValues, header)
        end
    end
    return table.concat(headerValues, ",")
end

function Dataset:RowToCsv(row: number, columns: {number}?): string
    assert(row <= #self.data, "Row index out of bounds")
    local rowValues = {}
    for col, value in ipairs(self.data[row]) do
        if not columns or table.find(columns, col) then
            table.insert(rowValues, value)
        end
    end
    return table.concat(rowValues, ",")
end

-- Returns a CSV string representation of the dataset
-- If columns is provided, only the columns specified will be included in the CSV
function Dataset:ToCsv(columns: {number}?): string
    local csv = self:HeaderToCsv(columns) .. "\n"
    
    for i, _ in ipairs(self.data) do
        csv = csv .. self:RowToCsv(i, columns) .. "\n"
    end
    return csv
end

return Dataset
