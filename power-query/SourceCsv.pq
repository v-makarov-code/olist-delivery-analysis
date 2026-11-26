(file as text) as table =>
let
    Content = SourceFiles{[Name=file]}[Content],
    Document = Csv.Document(Content, [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.Csv]),
    Headers = Table.PromoteHeaders(Document, [PromoteAllScalars=true])
in
    Headers
