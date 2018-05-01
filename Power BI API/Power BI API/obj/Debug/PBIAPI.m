///////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////
/////////////                                                                 /////////////
/////////////    Title: Power BI REST API Connector for Power BI              ///////////// 
/////////////    Created by: Miguel Escobar (@EscobarMiguel90)                ///////////// 
/////////////    Website: https://github.com/migueesc123/powerbiRESTAPI       ///////////// 
/////////////                                                                 ///////////// 
///////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////

section PowerBIRESTAPI;

//
// OAuth configuration settings
//
client_id = Text.FromBinary(Extension.Contents("AppID.txt"));  // TODO: set your API client ID value in the AppID.txt file
redirect_uri = "http://localhost:13526/redirect";
token_uri = "https://login.windows.net/common/oauth2/token";
authorize_uri = "https://login.windows.net/common/oauth2/authorize";
logout_uri = "https://login.microsoftonline.com/logout.srf";
resourceUri = "https://analysis.windows.net/powerbi/api";

windowWidth = 720;
windowHeight = 1024;

//
// Exported function(s)
//
MyFx = (path as text) =>
    let 
        mv = path
        in
            mv; 

[DataSource.Kind="PowerBIRESTAPI", Publish="PowerBIRESTAPI.UI"]
shared PowerBIRESTAPI.Navigation = () as table =>
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},{
            {Extension.LoadString("MyWorkspace"),  "MyWorkspace",  MyWorkspaceNavTable(),   "Folder", "MyWorkspace",  false},
            {Extension.LoadString("AppWorkspace"), "AppWorkspace", AppWorkspacesNavTable(), "Folder", "AppWorkspace", false},
            {"Functions",                          "Functions",    FunctionsNavTable(),     "Folder", "Functions",    false}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

MyWorkspaceNavTable = () as table => 
    let
        objects = #table(
            {"Name",  "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},{
            {Extension.LoadString("Imports"),        "Imports",        PowerBIRESTAPI.MWImports(),        "Table", "Table", true},
            {Extension.LoadString("Dashboards"),     "Dashboards",     PowerBIRESTAPI.MWDashboards(),     "Table", "Table", true},
            {Extension.LoadString("Reports"),        "Reports",        PowerBIRESTAPI.MWReports(),        "Table", "Table", true},
            {Extension.LoadString("Datasets"),       "Datasets",       PowerBIRESTAPI.MWDatasets(),       "Table", "Table", true},
            {Extension.LoadString("RefreshHistory"), "RefreshHistory", PowerBIRESTAPI.MWRefreshHistory(), "Table", "Table", true},
			{Extension.LoadString("Relationships"),  "Relationships",  PowerBIRESTAPI.MWRelated(),        "Table", "Table", true}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;


AppWorkspacesNavTable = () as table => 
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},{
            {"Gateways",            "Gateways",            PowerBIRESTAPI.Gateways(),            "Table", "Table", true},
            {"GatewaysDataSources", "GatewaysDataSources", PowerBIRESTAPI.GatewaysDataSources(), "Table", "Table", true},
			{"Workspaces",          "Workspaces",          PowerBIRESTAPI.GroupsList(),          "Table", "Table", true},
			{"Imports",             "Imports",             PowerBIRESTAPI.GroupsImports(),       "Table", "Table", true},
			{"Relationships",       "Relationships",       PowerBIRESTAPI.GroupsRelated(),       "Table", "Table", true},
            {"Datasets",            "Datasets",            PowerBIRESTAPI.GroupsDatasets(),      "Table", "Table", true},
            {"Members",             "Members",             PowerBIRESTAPI.GroupsMembers(),       "Table", "Table", true},
            {"Reports",             "Reports",             PowerBIRESTAPI.GroupsReports(),       "Table", "Table", true},
            {"Dashboards",          "Dashboards",          PowerBIRESTAPI.GroupsDashboards(),    "Table", "Table", true},
            {"RefreshHistory",      "RefreshHistory",      PowerBIRESTAPI.AWRefreshHistory(),    "Table", "Table", true}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

FunctionsNavTable = () as table => 
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},{
            {Extension.LoadString("GETData"), "GETData", PowerBIRESTAPI.GETData, "Function", "GETData", true}
        }),
        NavTable = Table.ForceToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;


 [DataSource.Kind="PowerBIRESTAPI"]
 PowerBIRESTAPI.MWRefreshHistory = () =>
let
    source = Json.Document(Web.Contents("https://api.powerbi.com/v1.0/myorg/datasets"))[value],    
    ConvertedToTable = Table.FromList(source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ExpandedColumn = Table.ExpandRecordColumn(ConvertedToTable, "Column1", {"id"}, {"datasetId"}),
    refreshHistory = Table.AddColumn(ExpandedColumn, "Call", each try Json.Document(Web.Contents( "https://api.powerbi.com/v1.0/myorg/datasets/" & [datasetId] & "/refreshes", [
      Headers = [
                #"Content-type" = "application/json"
            ]])) otherwise null),
       ExpandRefreshHistory = Table.ExpandRecordColumn(refreshHistory, "Call", {"value"}, {"value"}),
           ExpandToList = Table.ExpandListColumn(ExpandRefreshHistory, "value"),
    refreshHistoryData = Table.ExpandRecordColumn(ExpandToList, "value", {"id", "refreshType", "startTime", "endTime", "serviceExceptionJson", "status"}, {"refreshId", "refreshType", "startDatetime", "endDatetime", "serviceExceptionJson", "status"}),
    errorDescriptionJSON = Table.TransformColumns(refreshHistoryData,{{"serviceExceptionJson", Json.Document}}),
    replaceErrors = Table.ReplaceErrorValues(errorDescriptionJSON, {{"serviceExceptionJson", null}}),
    DataType = Table.TransformColumnTypes(replaceErrors,{{"datasetId", type text}, {"refreshId", Int64.Type}, {"refreshType", type text}, {"startDatetime", type datetimezone}, {"endDatetime", type datetimezone}, {"status", type text}}),
    Filtered = Table.SelectRows(DataType, each [refreshId] <> null and [refreshId] <> ""),
    DuplicatedColumn = Table.DuplicateColumn(Filtered, "startDatetime", "startDate"),
    ChangedType = Table.TransformColumnTypes(DuplicatedColumn,{{"startDate", type date}}),
    AddTimeTemp = Table.AddColumn(ChangedType, "startTimeTemp", each DateTime.Time([startDatetime]), type time),
    Time = Table.AddColumn(AddTimeTemp, "startTime", each Text.Replace(Text.Lower(Text.From([startTimeTemp], "en-US")), " am", ":00 AM"), type text),
    ChangedType2 = Table.TransformColumnTypes(Time,{{"startTime", type time}}),
    DeleteTimeTemp = Table.RemoveColumns(ChangedType2,{"startTimeTemp"}),
    ExpandedServiceExceptionJson = Table.ExpandRecordColumn(DeleteTimeTemp, "serviceExceptionJson", {"error"}, {"error"}),
    ExpandedError = Table.ExpandRecordColumn(ExpandedServiceExceptionJson, "error", {"code"}, {"errorCode"}),
    SortedRows = Table.Sort(ExpandedError,{{"startDatetime", Order.Ascending}}),
    AddedIndex = Table.AddIndexColumn(SortedRows, "Index", 0, 1)
in
    AddedIndex;



 [DataSource.Kind="PowerBIRESTAPI"]
 PowerBIRESTAPI.AWRefreshHistory = () =>
let
    source = PowerBIRESTAPI.GroupsDatasets(),
    value = Table.SelectColumns( source, {"groupId","datasetId"}),
    refreshHistory = Table.AddColumn( value, "Call", each try Json.Document(Web.Contents( "https://api.powerbi.com/v1.0/myorg/groups/" & [groupId] & "/datasets/" & [datasetId] & "/refreshes", [
      Headers = [
                #"Content-type" = "application/json"
            ]])) otherwise null),
       ExpandrefreshHistory = Table.ExpandRecordColumn(refreshHistory, "Call", {"value"}, {"value"}),
           ExpandToList = Table.ExpandListColumn(ExpandrefreshHistory, "value"),
    refreshHistoryData = Table.ExpandRecordColumn(ExpandToList, "value", {"id", "refreshType", "startTime", "endTime", "serviceExceptionJson", "status"}, {"refreshId", "refreshType", "startDatetime", "endDatetime", "serviceExceptionJson", "status"}),
    errorDescriptionJSON = Table.TransformColumns(refreshHistoryData,{{"serviceExceptionJson", Json.Document}}),
    replaceErrors = Table.ReplaceErrorValues(errorDescriptionJSON, {{"serviceExceptionJson", null}}),
    DataType = Table.TransformColumnTypes(replaceErrors,{{"groupId", type text}, {"datasetId", type text}, {"refreshId", Int64.Type}, {"refreshType", type text}, {"startDatetime", type datetimezone}, {"endDatetime", type datetimezone}, {"status", type text}}),
    Filtered = Table.SelectRows(DataType, each [refreshId] <> null and [refreshId] <> ""),
    DuplicatedColumn = Table.DuplicateColumn(Filtered, "startDatetime", "startDate"),
    ChangedType = Table.TransformColumnTypes(DuplicatedColumn,{{"startDate", type date}}),
    AddTimeTemp = Table.AddColumn(ChangedType, "startTimeTemp", each DateTime.Time([startDatetime]), type time),
    Time = Table.AddColumn(AddTimeTemp, "startTime", each Text.Replace(Text.Lower(Text.From([startTimeTemp], "en-US")), " am", ":00 AM"), type text),
    ChangedType2 = Table.TransformColumnTypes(Time,{{"startTime", type time}}),
    DeleteTimeTemp = Table.RemoveColumns(ChangedType2,{"startTimeTemp"}),
    ExpandedServiceExceptionJson = Table.ExpandRecordColumn(DeleteTimeTemp, "serviceExceptionJson", {"error"}, {"error"}),
    ExpandedError = Table.ExpandRecordColumn(ExpandedServiceExceptionJson, "error", {"code"}, {"errorCode"}),
    SortedRows = Table.Sort(ExpandedError,{{"startDatetime", Order.Ascending}}),
    AddedIndex = Table.AddIndexColumn(SortedRows, "Index", 0, 1)
in
    AddedIndex;


[DataSource.Kind="PowerBIRESTAPI"]
shared PowerBIRESTAPI.GETData =    Value.ReplaceType(GETData, GETDataType);

 GETDataType = type function (
        optional path as ( type text meta[
        Documentation.FieldCaption = "url Path",
        Documentation.FieldDescription = "Text string to be added to the https://api.powerbi.com/v1.0/myorg"]
        )) as table meta [                  
        Documentation.Name = "PowerBIRESTAPI.GETData",
        Documentation.LongDescription = "Makes a call to the Power BI REST API and returns the raw response",
        Documentation.Examples = {[
            Description = "Returns raw data from any of the https://api.powerbi.com/v1.0/myorg endpoints. ",
            Code = "=PowerBIRESTAPI.GETData(""datasets"")
            Get the full documentation at  https://msdn.microsoft.com/en-us/library/dn877544.aspx",
            Result = "Raw response for all the datasets in the Personal Workspace of the authenticated user."
        ]}
    ]; 

GETData = (optional path as text) =>
let
    source = Json.Document(Web.Contents("https://api.powerbi.com/v1.0/myorg", [RelativePath = path]))
in
    source;

[DataSource.Kind="PowerBIRESTAPI"]
 PowerBIRESTAPI.Gateways = () =>
let
  source = Json.Document(Web.Contents("https://api.powerbi.com/v1.0/myorg/gateways")),
    Converted = Record.ToTable(source),
    Transposed = Table.Transpose(Converted),
    Promoted = Table.PromoteHeaders(Transposed, [PromoteAllScalars=true]),
    Expanded = Table.ExpandListColumn(Promoted, "value"),
    Expanded1 = Table.ExpandRecordColumn(Expanded, "value", {"id", "name", "type", "publicKey", "gatewayAnnotation"}, {"gatewayId", "name", "type", "publicKey", "gatewayAnnotation"}),
    Split = Table.SplitColumn(Expanded1, "gatewayAnnotation", Splitter.SplitTextByDelimiter(":", QuoteStyle.Csv), {"gatewayAnnotation.1", "gatewayAnnotation.2", "gatewayAnnotation.3", "gatewayAnnotation.4", "gatewayAnnotation.5"}),
    Split1 = Table.SplitColumn(Split, "gatewayAnnotation.3", Splitter.SplitTextByDelimiter(",", QuoteStyle.Csv), {"gatewayAnnotation.3.1", "gatewayAnnotation.3.2"}),
    Split2 = Table.SplitColumn(Split1, "gatewayAnnotation.2", Splitter.SplitTextByDelimiter(",", QuoteStyle.Csv), {"gatewayAnnotation.2.1", "gatewayAnnotation.2.2"}),
    DataTypes1 = Table.TransformColumnTypes(Split2,{{"gatewayAnnotation.1", type text}, {"gatewayAnnotation.2.1", type text}, {"gatewayAnnotation.2.2", type text}, {"gatewayAnnotation.3.1", type text}, {"gatewayAnnotation.3.2", type text}, {"gatewayAnnotation.4", type text}, {"gatewayAnnotation.5", type text}}),
    Replace = Table.ReplaceValue(DataTypes1,"[","",Replacer.ReplaceText,{"gatewayAnnotation.2.1"}),
    Replace1 = Table.ReplaceValue(Replace,"]","",Replacer.ReplaceText,{"gatewayAnnotation.2.1"}),
    Replace2 = Table.ReplaceValue(Replace1,"}","",Replacer.ReplaceText,{"gatewayAnnotation.5"}),
    Rename = Table.RenameColumns(Replace2,{{"gatewayAnnotation.5", "gatewayMachine"}, {"gatewayAnnotation.3.1", "gatewayVersion"}, {"gatewayAnnotation.2.1", "gatewayContact"}}),
    Remove = Table.RemoveColumns(Rename,{"@odata.context", "gatewayAnnotation.1", "gatewayAnnotation.2.2", "gatewayAnnotation.3.2", "gatewayAnnotation.4", "publicKey"})
in
    Remove;

[DataSource.Kind="PowerBIRESTAPI"]
 PowerBIRESTAPI.GatewaysDataSources = () =>
let
  source = Json.Document(Web.Contents("https://api.powerbi.com/v1.0/myorg/gateways")),
    Converted = Record.ToTable(source),
    Transposed = Table.Transpose(Converted),
    Promoted = Table.PromoteHeaders(Transposed, [PromoteAllScalars=true]),
    Expanded = Table.ExpandListColumn(Promoted, "value"),
    Expanded1 = Table.ExpandRecordColumn(Expanded, "value", {"id", "name", "type", "publicKey", "gatewayAnnotation"}, {"gatewayId", "name", "type", "publicKey", "gatewayAnnotation"}),
    Columns = Table.SelectColumns(Expanded1,{"gatewayId"}),
      DataSources = Table.AddColumn( Columns, "DataSources", each try Table.FromRecords( Json.Document(Web.Contents( "https://api.powerbi.com/v1.0/myorg/gateways/" & [gatewayId] &"/datasources") )[value] ) otherwise null ),
	  Expanded2 = Table.ExpandTableColumn(DataSources, "DataSources", {"id", "datasourceType", "connectionDetails", "credentialType", "datasourceName"}, {"datasourceId", "datasourceType", "connectionDetails", "credentialType", "datasourceName"}),
	  DataSourceStatus = Table.AddColumn( Expanded2, "datasourceStatus", each try Table.FromRecords( Json.Document(Web.Contents( "https://api.powerbi.com/v1.0/myorg/gateways/" & [gatewayId] &"/datasources/" & [dataSourceId] &"/status") )[value] ) otherwise null )
in
    DataSourceStatus;

[DataSource.Kind="PowerBIRESTAPI"]
 PowerBIRESTAPI.GroupsList = () =>
let
  source = Json.Document(Web.Contents("https://api.powerbi.com/v1.0/myorg/groups"))[value],
    ToTable = Table.FromRecords(source),
    columnNames = Table.RenameColumns(ToTable,{{"id", "groupId"}, {"name", "groupName"}}),
    DataTypes = Table.TransformColumnTypes(columnNames,{{"groupId", type text}, {"groupName", type text}, {"isReadOnly", type logical}})
    in
    DataTypes;

[DataSource.Kind="PowerBIRESTAPI"]
 PowerBIRESTAPI.GroupsImports = () =>
let
  source = Json.Document(Web.Contents("https://api.powerbi.com/v1.0/myorg/groups"))[value],
    ToTable = Table.FromRecords(source),
    columnNames = Table.RenameColumns(ToTable,{{"id", "groupId"}, {"name", "groupName"}}),
      Columns = Table.SelectColumns(columnNames,{"groupId"}),
      Imports = Table.AddColumn( Columns, "Imports", each try Table.FromRecords( Json.Document(Web.Contents( "https://api.powerbi.com/v1.0/myorg/groups/" & Text.From([groupId]) &"/imports") )[value] ) otherwise null ),
	  Expanded = Table.ExpandTableColumn(Imports, "Imports", {"id", "importState", "createdDateTime", "updatedDateTime", "name", "connectionType", "source"}, {"importId", "importState", "createdDateTime", "updatedDateTime", "importName", "connectionType", "source"}),
      DuplicatedColumn = Table.DuplicateColumn(Expanded, "createdDateTime", "createdDate"),
      ChangedDatetime = Table.TransformColumnTypes(DuplicatedColumn,{{"createdDate", type datetime},{"createdDateTime", type datetime},{"updatedDateTime", type datetime}}),
      ChangedDate = Table.TransformColumnTypes(ChangedDatetime,{{"createdDate", type date}}),
      FilteredRows = Table.SelectRows(ChangedDate, each ([importId] <> null))
    in
    FilteredRows;
	
[DataSource.Kind="PowerBIRESTAPI"]
 PowerBIRESTAPI.GroupsRelated = () =>
let
  source = Json.Document(Web.Contents("https://api.powerbi.com/v1.0/myorg/groups"))[value],
    ToTable = Table.FromRecords(source),
    columnNames = Table.RenameColumns(ToTable,{{"id", "groupId"}, {"name", "groupName"}}),
      Columns = Table.SelectColumns(columnNames,{"groupId"}),
      Imports = Table.AddColumn( Columns, "Imports", each try Table.FromRecords( Json.Document(Web.Contents( "https://api.powerbi.com/v1.0/myorg/groups/" & Text.From([groupId]) &"/imports") )[value] ) otherwise null ),
	  Expanded = Table.ExpandTableColumn(Imports, "Imports", {"id", "datasets", "reports"}, {"importId", "datasets", "reports"}),
	  Expanded1 = Table.ExpandListColumn(Expanded, "datasets"),
      Expanded2 = Table.ExpandRecordColumn(Expanded1, "datasets", {"id"}, {"datasetId"}),
      Expanded3 = Table.ExpandListColumn(Expanded2, "reports"),
      Expanded4 = Table.ExpandRecordColumn(Expanded3, "reports", {"id"}, {"reportId"})
    in
    Expanded4;
	
[DataSource.Kind="PowerBIRESTAPI"]
 PowerBIRESTAPI.GroupsMembers = () =>
let
  source = Json.Document(Web.Contents("https://api.powerbi.com/v1.0/myorg/groups"))[value],
    ToTable = Table.FromRecords(source),
    columnNames = Table.RenameColumns(ToTable,{{"id", "groupId"}, {"name", "groupName"}}),
      Columns = Table.SelectColumns(columnNames,{"groupId"}),
      Members = Table.AddColumn( Columns, "Members", each try Table.FromRecords( Json.Document(Web.Contents( "https://api.powerbi.com/v1.0/myorg/groups/" & Text.From([groupId]) & "/users") )[value] ) otherwise null ),
      Expand = Table.ExpandTableColumn(Members, "Members", {"emailAddress", "groupUserAccessRight"}, {"emailAddress", "groupUserAccessRight"})
    in 
    Expand;

[DataSource.Kind="PowerBIRESTAPI"]
 PowerBIRESTAPI.GroupsDatasets = () =>
let
  source = Json.Document(Web.Contents("https://api.powerbi.com/v1.0/myorg/groups"))[value],
    ToTable = Table.FromRecords(source),
      columnNames = Table.RenameColumns(ToTable,{{"id", "groupId"}, {"name", "groupName"}}),
      keepColumns = Table.SelectColumns(columnNames,{"groupId"}),
      addColumn = Table.AddColumn( keepColumns, "Datasets", each try Table.FromList(Json.Document(Web.Contents( "https://api.powerbi.com/v1.0/myorg/groups/" & Text.From([groupId]) & "/datasets") )[value],  Splitter.SplitByNothing(), null, null, ExtraValues.Error) otherwise null ),
      ExpandedDatasets = Table.ExpandTableColumn(addColumn, "Datasets", {"Column1"}, {"Column1"}),
      ExpandedColumn = Table.ExpandRecordColumn(ExpandedDatasets, "Column1", {"id", "name", "addRowsAPIEnabled", "configuredBy", "isRefreshable", "isEffectiveIdentityRequired", "isEffectiveIdentityRolesRequired", "isOnPremGatewayRequired"}, {"datasetId", "datasetName", "addRowsAPIEnabled", "configuredBy", "isRefreshable", "isEffectiveIdentityRequired", "isEffectiveIdentityRolesRequired", "isOnPremGatewayRequired"}),
      RemoveNull = Table.SelectRows(ExpandedColumn, each [datasetId] <> null and [datasetId] <> "")
in
    RemoveNull;


 [DataSource.Kind="PowerBIRESTAPI"]
PowerBIRESTAPI.MWRelated = () =>
let
  source = Json.Document(Web.Contents("https://api.powerbi.com/v1.0/myorg/imports"))[value],
    ToTable = Table.FromList(source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ExpandedColumn = Table.ExpandRecordColumn(ToTable, "Column1", {"id", "datasets", "reports"}, {"importId", "datasets", "reports"}),
	  Expanded1 = Table.ExpandListColumn(ExpandedColumn, "datasets"),
      Expanded2 = Table.ExpandRecordColumn(Expanded1, "datasets", {"id"}, {"datasetId"}),
      Expanded3 = Table.ExpandListColumn(Expanded2, "reports"),
      Expanded4 = Table.ExpandRecordColumn(Expanded3, "reports", {"id"}, {"reportId"})
    in
    Expanded4;


 [DataSource.Kind="PowerBIRESTAPI"]
PowerBIRESTAPI.MWDatasets = () =>
let
  source = Json.Document(Web.Contents("https://api.powerbi.com/v1.0/myorg/datasets"))[value],
    ConvertedToTable = Table.FromList(source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ExpandedColumn = Table.ExpandRecordColumn(ConvertedToTable, "Column1", {"id", "name", "addRowsAPIEnabled", "configuredBy", "isRefreshable", "isEffectiveIdentityRequired", "isEffectiveIdentityRolesRequired", "isOnPremGatewayRequired"}, {"datasetId", "datasetName", "addRowsAPIEnabled", "configuredBy", "isRefreshable", "isEffectiveIdentityRequired", "isEffectiveIdentityRolesRequired", "isOnPremGatewayRequired"}),
    DataTypes = Table.TransformColumnTypes(ExpandedColumn,{{"datasetId", type text}, {"datasetName", type text}, {"configuredBy", type text}, {"addRowsAPIEnabled", type logical}, {"isRefreshable", type logical}, {"isEffectiveIdentityRequired", type logical}, {"isEffectiveIdentityRolesRequired", type logical}, {"isOnPremGatewayRequired", type logical}})
    in
    DataTypes;

[DataSource.Kind="PowerBIRESTAPI"]
 PowerBIRESTAPI.GroupsReports = () =>
let
  source = Json.Document(Web.Contents("https://api.powerbi.com/v1.0/myorg/groups"))[value],
    ToTable = Table.FromRecords(source),
    columnNames = Table.RenameColumns(ToTable,{{"id", "groupId"}, {"name", "groupName"}}),
      members = Table.AddColumn( columnNames, "Reports", each try Table.FromRecords(Json.Document(Web.Contents( "https://api.powerbi.com/v1.0/myorg/groups/" & Text.From([groupId])&"/reports") )[value] ) otherwise null ),
      Columns = Table.SelectColumns(members,{"groupId", "Reports"}),
      Expanded = Table.ExpandTableColumn(Columns, "Reports", {"id", "modelId", "name", "webUrl", "embedUrl", "isOwnedByMe", "isOriginalPbixReport", "datasetId"}, {"reportId", "modelId", "reportName", "webUrl", "embedUrl", "isOwnedByMe", "isOriginalPbixReport", "datasetId"}),
      DataTypes = Table.TransformColumnTypes(Expanded,{{"reportId", type text}, {"reportName", type text}, {"webUrl", type text}, {"embedUrl", type text}, {"datasetId", type text}, {"groupId", type text}, {"modelId", Int64.Type}, {"isOwnedByMe", type logical}, {"isOriginalPbixReport", type logical}}),
      FilteredRows = Table.SelectRows(DataTypes, each ([reportId] <> null))
    in
    FilteredRows;

[DataSource.Kind="PowerBIRESTAPI"]
 shared PowerBIRESTAPI.MWReports = () =>
let
  source = Json.Document(Web.Contents("https://api.powerbi.com/v1.0/myorg/reports"))[value],
    ToTable = Table.FromRecords(source),
     DataTypes = Table.TransformColumnTypes(ToTable,{{"id", type text}, {"name", type text}, {"webUrl", type text}, {"embedUrl", type text}, {"datasetId", type text},  {"modelId", Int64.Type}, {"isOwnedByMe", type logical}, {"isOriginalPbixReport", type logical}}),
     RenamedColumns = Table.RenameColumns(DataTypes,{{"id", "reportId"}, {"name", "reportName"}}),
     FilteredRows = Table.SelectRows(RenamedColumns, each [reportId] <> null and [reportId] <> "")
    in
    FilteredRows;

[DataSource.Kind="PowerBIRESTAPI"]
PowerBIRESTAPI.GroupsDashboards = () =>
let
  source = Json.Document(Web.Contents("https://api.powerbi.com/v1.0/myorg/groups"))[value],
    ToTable = Table.FromRecords(source),
    columnNames = Table.RenameColumns(ToTable,{{"id", "groupId"}, {"name", "groupName"}}),
      members = Table.AddColumn( columnNames, "Dashboards", each try Table.FromRecords(Json.Document(Web.Contents( "https://api.powerbi.com/v1.0/myorg/groups/" & Text.From([groupId])&"/dashboards") )[value] ) otherwise null ),
      Columns = Table.SelectColumns(members,{"groupId", "Dashboards"}),
      Expanded = Table.ExpandTableColumn(Columns, "Dashboards", {"id", "displayName", "isReadOnly", "embedUrl"}, {"dashboardId", "displayName", "isReadOnly", "embedUrl"}),
      DataTypes = Table.TransformColumnTypes(Expanded,{{"dashboardId", type text}, {"displayName", type text}, {"embedUrl", type text}, {"isReadOnly", type logical}})
    in
    DataTypes;


 [DataSource.Kind="PowerBIRESTAPI"]
 PowerBIRESTAPI.MWImports = () =>
let
  source = Json.Document(Web.Contents("https://api.powerbi.com/v1.0/myorg/imports"))[value],
    ToTable = Table.FromList(source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ExpandedColumn = Table.ExpandRecordColumn(ToTable, "Column1", {"id", "importState", "createdDateTime", "updatedDateTime", "name", "connectionType", "source"}, {"id", "importState", "createdDateTime", "updatedDateTime", "name", "connectionType", "source"}),
      DuplicatedColumn = Table.DuplicateColumn(ExpandedColumn, "createdDateTime", "createdDate"),
      ChangedDatetime = Table.TransformColumnTypes(DuplicatedColumn,{{"createdDate", type datetime}}),
      ChangedDate = Table.TransformColumnTypes(ChangedDatetime,{{"createdDate", type date}})
    in
    ChangedDate;


[DataSource.Kind="PowerBIRESTAPI"]
shared PowerBIRESTAPI.MWDashboards = () =>
let
  source = Json.Document(Web.Contents("https://api.powerbi.com/v1.0/myorg/dashboards"))[value],
    ToTable = Table.FromRecords(source),
    DataTypes = Table.TransformColumnTypes(ToTable,{{"id", type text}, {"displayName", type text}, {"embedUrl", type text}, {"isReadOnly", type logical}}),
    RenameColumns = Table.RenameColumns(DataTypes,{{"id", "dashboardId"}})
    in
    RenameColumns;

//
// Data Source definition
//
PowerBIRESTAPI = [
    Authentication = [
        OAuth = [
            StartLogin=StartLogin,
            FinishLogin=FinishLogin,
            Refresh=Refresh,
            Logout=Logout
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel") 
];

//
// UI Export definition
//
PowerBIRESTAPI.UI = [
    Beta = true,
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    SourceImage = PBIAPI.Icons ,
    SourceTypeImage = PBIAPI.Icons 
];

PBIAPI.Icons = [
    Icon16 = { Extension.Contents("PBIAPI16.png"), Extension.Contents("PBIAPI20.png"), Extension.Contents("PBIAPI24.png"), Extension.Contents("PBIAPI32.png") },
    Icon32 = { Extension.Contents("PBIAPI32.png"), Extension.Contents("PBIAPI40.png"), Extension.Contents("PBIAPI48.png"), Extension.Contents("PBIAPI64.png") }
];

//
// OAuth implementation
//
// See the following links for more details on AAD/Graph OAuth:
// * https://docs.microsoft.com/en-us/azure/active-directory/active-directory-protocols-oauth-code 
// * https://graph.microsoft.io/en-us/docs/authorization/app_authorization
//
// StartLogin builds a record containing the information needed for the client
// to initiate an OAuth flow. Note for the AAD flow, the display parameter is
// not used.
//
// resourceUrl: Derived from the required arguments to the data source function
//              and is used when the OAuth flow requires a specific resource to 
//              be passed in, or the authorization URL is calculated (i.e. when
//              the tenant name/ID is included in the URL). In this example, we
//              are hardcoding the use of the "common" tenant, as specified by
//              the 'authorize_uri' variable.
// state:       Client state value we pass through to the service.
// display:     Used by certain OAuth services to display information to the
//              user.
//
// Returns a record containing the following fields:
// LoginUri:     The full URI to use to initiate the OAuth flow dialog.
// CallbackUri:  The return_uri value. The client will consider the OAuth
//               flow complete when it receives a redirect to this URI. This
//               generally needs to match the return_uri value that was
//               registered for your application/client. 
// WindowHeight: Suggested OAuth window height (in pixels).
// WindowWidth:  Suggested OAuth window width (in pixels).
// Context:      Optional context value that will be passed in to the FinishLogin
//               function once the redirect_uri is reached. 
//
StartLogin = (resourceUrl, state, display) =>
    let
        authorizeUrl = authorize_uri & "?" & Uri.BuildQueryString([
            client_id = client_id,  
            redirect_uri = redirect_uri,
            state = state,
            response_type = "code",
            response_mode = "query",
            resource = resourceUri
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = 720,
            WindowWidth = 1024,
            Context = null
        ];

// FinishLogin is called when the OAuth flow reaches the specified redirect_uri. 
// Note for the AAD flow, the context and state parameters are not used. 
//
// context:     The value of the Context field returned by StartLogin. Use this to 
//              pass along information derived during the StartLogin call (such as
//              tenant ID)
// callbackUri: The callbackUri containing the authorization_code from the service.
// state:       State information that was specified during the call to StartLogin. 
FinishLogin = (context, callbackUri, state) =>
    let
        // parse the full callbackUri, and extract the Query string
        parts = Uri.Parts(callbackUri)[Query],
        // if the query string contains an "error" field, raise an error
        // otherwise call TokenMethod to exchange our code for an access_token
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    TokenMethod("authorization_code", "code", parts[code])
    in
        result;

// Called when the access_token has expired, and a refresh_token is available.
// 
Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", "refresh_token", refresh_token);

Logout = (token) => logout_uri;


// grantType:  Maps to the "grant_type" query parameter.
// tokenField: The name of the query parameter to pass in the code.
// code:       Is the actual code (authorization_code or refresh_token) to send to the service.
TokenMethod = (grantType, tokenField, code) =>
    let
        queryString = [
            client_id = client_id,
            resource = resourceUri,
            grant_type = grantType,
            redirect_uri = redirect_uri
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),

        tokenResponse = Web.Contents(token_uri, [
            Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = {400} 
        ]),
        body = Json.Document(tokenResponse),
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body)
                 else
                    body
    in
        result;

Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

Table.ForceToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;