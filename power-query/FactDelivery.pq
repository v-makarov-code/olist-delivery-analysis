let
    Eligible = Table.SelectRows(OrdersScope, each [Coverage] = "Included"),
    ReviewFields = Table.SelectColumns(SourceCsv("olist_order_reviews_dataset.csv"), {
        "order_id", "review_score", "review_answer_timestamp", "review_creation_date", "review_id"
    }),
    ScoreType = Table.TransformColumns(ReviewFields, {{"review_score", each try Int64.From(_) otherwise null, Int64.Type}}),
    ValidScores = Table.SelectRows(ScoreType, each [review_score] <> null and [review_score] >= 1 and [review_score] <= 5),
    ReviewOrder = {{"review_answer_timestamp", Order.Descending}, {"review_creation_date", Order.Descending},
        {"review_id", Order.Descending}, {"review_score", Order.Descending}},
    Reviews = Table.Group(ValidScores, {"order_id"}, {{"ReviewScore", each Table.Sort(_, ReviewOrder){0}[review_score], Int64.Type}}),
    JoinReviews = Table.NestedJoin(Eligible, {"OrderId"}, Reviews, {"order_id"}, "Review", JoinKind.LeftOuter),
    WithReview = Table.ExpandTableColumn(JoinReviews, "Review", {"ReviewScore"}),
    WithRoute = Table.AddColumn(WithReview, "Route", each [Origin] & " > " & [Destination], type text),
    WithMonth = Table.AddColumn(WithRoute, "Month", each Date.ToText(Date.From([PurchasedAt]), [Format="yyyy-MM", Culture="en-US"]), type text),
    WithDelay = Table.AddColumn(WithMonth, "DelayDays", each Duration.Days(Date.From([DeliveredAt]) - Date.From([PromisedAt])), Int64.Type),
    WithLate = Table.AddColumn(WithDelay, "Late", each if [DelayDays] > 0 then 1 else 0, Int64.Type),
    WithBand = Table.AddColumn(WithLate, "DelayBand", each
        if [DelayDays] <= 0 then 0 else if [DelayDays] <= 3 then 1 else if [DelayDays] <= 7 then 2 else 3, Int64.Type),
    WithPromise = Table.AddColumn(WithBand, "PromisedDays", each Duration.Days(Date.From([PromisedAt]) - Date.From([PurchasedAt])), Int64.Type),
    WithActual = Table.AddColumn(WithPromise, "ActualDays", each Duration.Days(Date.From([DeliveredAt]) - Date.From([PurchasedAt])), Int64.Type),
    WithStageValid = Table.AddColumn(WithActual, "ValidStages", each
        if [ApprovedAt] <> null and [CarrierAt] <> null and [PurchasedAt] <= [ApprovedAt] and [ApprovedAt] <= [CarrierAt] and [CarrierAt] <= [DeliveredAt]
        then 1 else 0, Int64.Type),
    WithPrep = Table.AddColumn(WithStageValid, "PrepDays", each if [ValidStages] = 1 then Duration.TotalDays([CarrierAt] - [ApprovedAt]) else null, type nullable number),
    WithTransit = Table.AddColumn(WithPrep, "TransitDays", each if [ValidStages] = 1 then Duration.TotalDays([DeliveredAt] - [CarrierAt]) else null, type nullable number),
    Selected = Table.SelectColumns(WithTransit, {
        "OrderId", "Route", "Month", "Origin", "Destination", "PurchasedAt", "PromisedAt", "DeliveredAt", "ApprovedAt", "CarrierAt",
        "Late", "DelayDays", "PromisedDays", "ActualDays", "ValidStages", "PrepDays", "TransitDays", "ReviewScore", "DelayBand"
    })
in
    Selected
