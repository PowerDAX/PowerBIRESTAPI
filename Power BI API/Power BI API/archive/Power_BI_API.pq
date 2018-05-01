// This file contains your Data Connector logic
section Power_BI_API;

[DataSource.Kind="Power_BI_API", Publish="Power_BI_API.Publish"]
shared Power_BI_API.Contents = (optional message as text) =>
    let
        _message = if (message <> null) then message else "(no message)",
        a = "Hello from Power_BI_API: " & _message
    in
        a;

// Data Source Kind description
Power_BI_API = [
    Authentication = [
        // Key = [],
        // UsernamePassword = [],
        // Windows = [],
        Implicit = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
Power_BI_API.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = Power_BI_API.Icons,
    SourceTypeImage = Power_BI_API.Icons
];

Power_BI_API.Icons = [
    Icon16 = { Extension.Contents("Power_BI_API16.png"), Extension.Contents("Power_BI_API20.png"), Extension.Contents("Power_BI_API24.png"), Extension.Contents("Power_BI_API32.png") },
    Icon32 = { Extension.Contents("Power_BI_API32.png"), Extension.Contents("Power_BI_API40.png"), Extension.Contents("Power_BI_API48.png"), Extension.Contents("Power_BI_API64.png") }
];
