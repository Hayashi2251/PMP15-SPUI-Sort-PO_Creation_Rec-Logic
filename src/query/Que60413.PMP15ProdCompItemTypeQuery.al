query 60413 "PMP15Prod-Comp. ItemType Query"
{
    // version PMP15 

    // List Modification
    // Version List       Name
    // =============================================================================================================
    // PMP15              PMP SPUI - Sort-PO Creation & Recording (Logic)

    // QUERY
    // Date        Developer  Version List  Description
    // =============================================================================================================
    // 2026/01/10  SW         PMP15         Create Query

    Caption = 'Production Order Component Item Type Query';
    QueryType = Normal;

    elements
    {
        dataitem(ProdOrderComponent; "Prod. Order Component")
        {
            column(POCOMP_Status; Status) { }
            column(POCOMP_ProdOrderNo; "Prod. Order No.") { }
            column(POCOMP_ProdOrderLineNo; "Prod. Order Line No.") { }
            column(POCOMP_LineNo; "Line No.") { }
            column(POCOMP_ItemNo; "Item No.") { }
            column(POCOMP_Description; Description) { }
            column(POCOMP_UnitofMeasureCode; "Unit of Measure Code") { }
            column(POCOMP_Quantity; Quantity) { }
            column(POCOMP_Scrap; "Scrap %") { }
            column(POCOMP_VariantCode; "Variant Code") { }
            column(POCOMP_QtyRoundingPrecision; "Qty. Rounding Precision") { }
            column(POCOMP_QtyRoundingPrecisionBase; "Qty. Rounding Precision (Base)") { }
            column(POCOMP_ExpectedQuantity; "Expected Quantity") { }
            column(POCOMP_RemainingQuantity; "Remaining Quantity") { }
            column(POCOMP_LocationCode; "Location Code") { }
            column(POCOMP_ShortcutDimension1Code; "Shortcut Dimension 1 Code") { }
            column(POCOMP_ShortcutDimension2Code; "Shortcut Dimension 2 Code") { }
            column(POCOMP_BinCode; "Bin Code") { }
            column(POCOMP_Quantityper; "Quantity per") { }
            column(POCOMP_UnitCost; "Unit Cost") { }
            column(POCOMP_CostAmount; "Cost Amount") { }
            column(POCOMP_DueDate; "Due Date") { }
            column(POCOMP_DueTime; "Due Time") { }
            column(POCOMP_QtyperUnitofMeasure; "Qty. per Unit of Measure") { }
            column(POCOMP_RemainingQtyBase; "Remaining Qty. (Base)") { }
            column(POCOMP_QuantityBase; "Quantity (Base)") { }
            column(POCOMP_DimensionSetID; "Dimension Set ID") { }
            column(POCOMP_OriginalItemNo; "Original Item No.") { }
            column(POCOMP_OriginalVariantCode; "Original Variant Code") { }
            dataitem(Item; Item)
            {
                DataItemLink = "No." = ProdOrderComponent."Item No.";
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

    trigger OnBeforeOpen()
    begin

    end;
}
