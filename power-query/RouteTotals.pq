let
    Summary = Table.Group(FactDelivery, {"Route"}, {
        {"Delivered", each Table.RowCount(_), Int64.Type},
        {"LateOrders", each List.Sum([Late]), Int64.Type}
    }),
    WithRate = Table.AddColumn(Summary, "LateRate", each [LateOrders] / [Delivered], Percentage.Type),
    Sorted = Table.Sort(WithRate, {{"LateOrders", Order.Descending}, {"Route", Order.Ascending}})
in
    Sorted
