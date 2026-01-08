query 60411 "PMP15 Curr & Prev Bin Query"
{
    // version PMP15 

    // List Modification
    // Version List       Name
    // =============================================================================================================
    // PMP15              PMP SPUI - Sort-PO Creation & Recording (Logic)

    // QUERY
    // Date        Developer  Version List  Description
    // =============================================================================================================
    // 2026/01/06  SW         PMP15         Create Query

    Caption = 'Current & Previous Bin Query';
    QueryType = Normal;

    elements
    {
        dataitem(Current_Bin; Bin)
        {
            column(CURR_LocationCode; "Location Code") { }
            column(CURR_Code; "Code") { }
            column(CURR_Description; Description) { }
            column(CURR_ZoneCode; "Zone Code") { }
            column(CURR_AdjustmentBin; "Adjustment Bin") { }
            column(CURR_BinTypeCode; "Bin Type Code") { }
            column(CURR_WarehouseClassCode; "Warehouse Class Code") { }
            column(CURR_BlockMovement; "Block Movement") { }
            column(CURR_SpecialEquipmentCode; "Special Equipment Code") { }
            column(CURR_BinRanking; "Bin Ranking") { }
            column(CURR_MaximumCubage; "Maximum Cubage") { }
            column(CURR_MaximumWeight; "Maximum Weight") { }
            column(CURR_Empty; Empty) { }
            column(CURR_Default; Default) { }
            column(CURR_CrossDockBin; "Cross-Dock Bin") { }
            column(CURR_Dedicated; Dedicated) { }
            column(CURR_PMP16RackNo; "PMP16 Rack No.") { }
            column(CURR_PMP16BayNo; "PMP16 Bay No.") { }
            column(CURR_PMP16LevelNo; "PMP16 Level No.") { }
            column(CURR_PMP16PosIdx; "PMP16 Pos Idx") { }
            column(CURR_PMP15BinType; "PMP15 Bin Type") { }
            column(CURR_PMP15PreviousBin; "PMP15 Previous Bin") { }
            column(CURR_SME02AreaType; "SME02 Area Type") { }
            dataitem(Previous_Bin; Bin)
            {
                DataItemLink = Code = Current_Bin."PMP15 Previous Bin";
                column(PREV_LocationCode; "Location Code") { }
                column(PREV_Code; "Code") { }
                column(PREV_Description; Description) { }
                column(PREV_ZoneCode; "Zone Code") { }
                column(PREV_AdjustmentBin; "Adjustment Bin") { }
                column(PREV_BinTypeCode; "Bin Type Code") { }
                column(PREV_WarehouseClassCode; "Warehouse Class Code") { }
                column(PREV_BlockMovement; "Block Movement") { }
                column(PREV_SpecialEquipmentCode; "Special Equipment Code") { }
                column(PREV_BinRanking; "Bin Ranking") { }
                column(PREV_MaximumCubage; "Maximum Cubage") { }
                column(PREV_MaximumWeight; "Maximum Weight") { }
                column(PREV_Empty; Empty) { }
                column(PREV_Default; Default) { }
                column(PREV_CrossDockBin; "Cross-Dock Bin") { }
                column(PREV_Dedicated; Dedicated) { }
                column(PREV_PMP16RackNo; "PMP16 Rack No.") { }
                column(PREV_PMP16BayNo; "PMP16 Bay No.") { }
                column(PREV_PMP16LevelNo; "PMP16 Level No.") { }
                column(PREV_PMP16PosIdx; "PMP16 Pos Idx") { }
                column(PREV_PMP15BinType; "PMP15 Bin Type") { }
                column(PREV_PMP15PreviousBin; "PMP15 Previous Bin") { }
                column(PREV_SME02AreaType; "SME02 Area Type") { }
            }
        }
    }

    trigger OnBeforeOpen()
    begin

    end;
}
