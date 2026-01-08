query 60412 "PMP15 ProdBOMLineItemTypeQuery"
{
    Caption = 'PMP15 ProdBOMLineItemTypeQuery';
    QueryType = Normal;

    elements
    {
        dataitem(ProductionBOMHeader; "Production BOM Header")
        {
            column(ProdBOMH_No; "No.") { }
            column(ProdBOMH_Description; Description) { }
            column(ProdBOMH_Description2; "Description 2") { }
            column(ProdBOMH_SearchName; "Search Name") { }
            column(ProdBOMH_UnitofMeasureCode; "Unit of Measure Code") { }
            column(ProdBOMH_LowLevelCode; "Low-Level Code") { }
            column(ProdBOMH_Comment; Comment) { }
            column(ProdBOMH_CreationDate; "Creation Date") { }
            column(ProdBOMH_LastDateModified; "Last Date Modified") { }
            column(ProdBOMH_Status; Status) { }
            column(ProdBOMH_VersionNos; "Version Nos.") { }
            column(ProdBOMH_NoSeries; "No. Series") { }
            dataitem(ProductionBOMLine; "Production BOM Line")
            {
                DataItemLink = "Production BOM No." = ProductionBOMHeader."No.";
                // DataItemTableFilter = Type = const(Item);
                column(ProdBOML_ProductionBOMNo; "Production BOM No.") { }
                column(ProdBOML_LineNo; "Line No.") { }
                column(ProdBOML_VersionCode; "Version Code") { }
                column(ProdBOML_Type; "Type") { }
                column(ProdBOML_No; "No.") { }
                column(ProdBOML_Description; Description) { }
                column(ProdBOML_UnitofMeasureCode; "Unit of Measure Code") { }
                column(ProdBOML_Quantity; Quantity) { }
                column(ProdBOML_Position; Position) { }
                column(ProdBOML_Position2; "Position 2") { }
                column(ProdBOML_Position3; "Position 3") { }
                column(ProdBOML_LeadTimeOffset; "Lead-Time Offset") { }
                column(ProdBOML_RoutingLinkCode; "Routing Link Code") { }
                column(ProdBOML_Scrap; "Scrap %") { }
                column(ProdBOML_VariantCode; "Variant Code") { }
                column(ProdBOML_Comment; Comment) { }
                column(ProdBOML_StartingDate; "Starting Date") { }
                column(ProdBOML_EndingDate; "Ending Date") { }
                column(ProdBOML_Length; Length) { }
                column(ProdBOML_Width; Width) { }
                column(ProdBOML_Weight; Weight) { }
                column(ProdBOML_Depth; Depth) { }
                column(ProdBOML_CalculationFormula; "Calculation Formula") { }
                column(ProdBOML_Quantityper; "Quantity per") { }
                column(ProdBOML_PMP05WasteComponentItemNo; "PMP05 Waste Component Item No.") { }
                column(ProdBOML_PMP05WasteCompVariantCode; "PMP05 Waste Comp. Variant Code") { }
                dataitem(Item; Item)
                {
                    DataItemLink = "No." = ProductionBOMLine."No.";
                    column(ITEM_No; "No.") { }
                    column(ITEM_Description; Description) { }
                    column(ITEM_Type; "Type") { }
                    column(ITEM_AssemblyBOM; "Assembly BOM") { }
                    column(ITEM_BaseUnitofMeasure; "Base Unit of Measure") { }
                    column(ITEM_VendorNo; "Vendor No.") { }
                    column(ITEM_VendorItemNo; "Vendor Item No.") { }
                    column(ITEM_ItemCategoryCode; "Item Category Code") { }
                    column(ITEM_ItemCategoryId; "Item Category Id") { }
                    column(ITEM_PMP04OwnerClass; "PMP04 Owner Class") { }
                    column(ITEM_PMP04ItemOwnerExternal; "PMP04 Item Owner External") { }
                    column(ITEM_PMP04ItemOwnerInternal; "PMP04 Item Owner Internal") { }
                    column(ITEM_PMP04ItemOwnerExtinProd; "PMP04 Item Owner Ext. in Prod.") { }
                    column(ITEM_PMP04PackageNos; "PMP04 Package Nos") { }
                    column(ITEM_PMP04ItemGroup; "PMP04 Item Group") { }
                    column(ITEM_PMP04ItemClassL1; "PMP04 Item Class L1") { }
                    column(ITEM_PMP04ItemClassL2; "PMP04 Item Class L2") { }
                    column(ITEM_PMP04ItemTypeL1; "PMP04 Item Type L1") { }
                    column(ITEM_PMP04ItemTypeL2; "PMP04 Item Type L2") { }
                    column(ITEM_PMP04Description3; "PMP04 Description 3") { }
                    column(ITEM_PMP04ProdSorte; "PMP04 Prod. Sorte") { }
                    column(ITEM_PMP04FormatNo; "PMP04 Format No.") { }
                    column(ITEM_PMP04TobaccoStandard; "PMP04 Tobacco Standard") { }
                    column(ITEM_PMP04CustomerCountry; "PMP04 Customer Country") { }
                    column(ITEM_PMP04ItemTypeL3; "PMP04 Item Type L3") { }
                    column(ITEM_PMP04PlannerCode; "PMP04 Planner Code") { }
                    column(ITEM_PMP04UseActWghtinITInvt; "PMP04 Use Act Wght in IT Invt") { }
                    column(ITEM_PMP04ItemClassL3; "PMP04 Item Class L3") { }
                }
            }
        }
    }

    trigger OnBeforeOpen()
    begin

    end;
}
