let
    Labels = #table(type table [Coverage = text, Position = Int64.Type], {
        {"OutsidePeriod", 1}, {"OtherStatus", 2}, {"InvalidDelivery", 3}, {"SellerCount", 4}, {"MissingState", 5}, {"Included", 6}
    }),
    Hold = Table.Buffer(OrdersScope),
    Counts = Table.Group(Hold, {"Coverage"}, {{"Orders", each Table.RowCount(_), Int64.Type}}),
    Join = Table.NestedJoin(Labels, {"Coverage"}, Counts, {"Coverage"}, "Count", JoinKind.LeftOuter),
    Expand = Table.ExpandTableColumn(Join, "Count", {"Orders"}),
    WithZero = Table.ReplaceValue(Expand, null, 0, Replacer.ReplaceValue, {"Orders"}),
    Sorted = Table.Buffer(Table.RemoveColumns(Table.Sort(WithZero, {{"Position", Order.Ascending}}), {"Position"})),
    All = Table.InsertRows(Sorted, 0, {[Coverage="SourceTotal", Orders=Table.RowCount(Hold)]})
in
    All
