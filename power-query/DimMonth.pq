let
    Start = #date(2017, 1, 1),
    Values = List.Transform({0..19}, each Date.ToText(Date.AddMonths(Start, _), [Format="yyyy-MM", Culture="en-US"])),
    Months = Table.FromColumns({Values}, type table [Month = text])
in
    Months
