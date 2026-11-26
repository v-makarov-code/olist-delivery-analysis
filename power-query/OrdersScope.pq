let
    Orders = SourceCsv("olist_orders_dataset.csv"),
    Renamed = Table.RenameColumns(Orders, {
        {"order_id", "OrderId"}, {"customer_id", "CustomerId"}, {"order_status", "Status"},
        {"order_purchase_timestamp", "PurchasedAt"}, {"order_approved_at", "ApprovedAt"},
        {"order_delivered_carrier_date", "CarrierAt"}, {"order_delivered_customer_date", "DeliveredAt"},
        {"order_estimated_delivery_date", "PromisedAt"}
    }),
    ParseTime = (x as nullable text) as nullable datetime =>
        if x = null or Text.Trim(x) = "" then null
        else try DateTime.FromText(x, [Format="yyyy-MM-dd HH:mm:ss", Culture="en-US"]) otherwise null,
    Times = Table.TransformColumns(Renamed, List.Transform(
        {"PurchasedAt", "ApprovedAt", "CarrierAt", "DeliveredAt", "PromisedAt"},
        each {_, ParseTime, type nullable datetime}
    )),
    ItemSellers = Table.Distinct(Table.SelectRows(
        Table.SelectColumns(SourceCsv("olist_order_items_dataset.csv"), {"order_id", "seller_id"}),
        each [seller_id] <> null and [seller_id] <> ""
    )),
    ByOrder = Table.Group(ItemSellers, {"order_id"}, {
        {"SellerCount", each Table.RowCount(_), Int64.Type},
        {"SellerId", each if Table.RowCount(_) = 1 then [seller_id]{0} else null, type nullable text}
    }),
    Customers = Table.Buffer(Table.SelectColumns(SourceCsv("olist_customers_dataset.csv"), {"customer_id", "customer_state"})),
    Sellers = Table.Buffer(Table.SelectColumns(SourceCsv("olist_sellers_dataset.csv"), {"seller_id", "seller_state"})),
    JoinItems = Table.NestedJoin(Times, {"OrderId"}, ByOrder, {"order_id"}, "Items", JoinKind.LeftOuter),
    WithItems = Table.ExpandTableColumn(JoinItems, "Items", {"SellerCount", "SellerId"}),
    JoinCustomers = Table.NestedJoin(WithItems, {"CustomerId"}, Customers, {"customer_id"}, "Customer", JoinKind.LeftOuter),
    WithCustomers = Table.ExpandTableColumn(JoinCustomers, "Customer", {"customer_state"}, {"Destination"}),
    JoinSellers = Table.NestedJoin(WithCustomers, {"SellerId"}, Sellers, {"seller_id"}, "Seller", JoinKind.LeftOuter),
    WithSellers = Table.ExpandTableColumn(JoinSellers, "Seller", {"seller_state"}, {"Origin"}),
    Eligibility = Table.AddColumn(WithSellers, "Coverage", each
        if [PurchasedAt] = null or [PurchasedAt] < #datetime(2017, 1, 1, 0, 0, 0) or [PurchasedAt] >= #datetime(2018, 9, 1, 0, 0, 0) then "OutsidePeriod"
        else if [Status] <> "delivered" then "OtherStatus"
        else if [DeliveredAt] = null or [PromisedAt] = null or [DeliveredAt] < [PurchasedAt] or Date.From([PromisedAt]) < Date.From([PurchasedAt]) then "InvalidDelivery"
        else if [SellerCount] <> 1 then "SellerCount"
        else if [Origin] = null or [Origin] = "" or [Destination] = null or [Destination] = "" then "MissingState"
        else "Included", type text)
in
    Eligibility
