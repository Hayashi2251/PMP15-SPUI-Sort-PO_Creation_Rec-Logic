pageextension 60408 "PMP15 Whse Entry List Ext" extends "Warehouse Entries"
{
    // VERSION PMP15 

    // VERSION
    // Version List       Name
    // ============================================================================================================
    // PMP15              PMP SPUI - Sort-PO Creation & Recording (Logic)
    // 
    // PAGE EXTENSION
    // Date        Developer  Version List  Trigger                     Description
    // ============================================================================================================
    // 2025/09/12  SW         PMP15         -                           Create Page Extension
    // 

    #region Layout
    layout
    {
        addlast(Control1)
        {
            field("Sub Merk 1"; Rec."PMP15 Sub Merk 1")
            {
                ApplicationArea = All;
                Caption = 'Sub Merk 1';
                ToolTip = 'Display the Sub Merk 1 value';
                Editable = false;
            }
            field("Sub Merk 2"; Rec."PMP15 Sub Merk 2")
            {
                ApplicationArea = All;
                Caption = 'Sub Merk 2';
                ToolTip = 'Display the Sub Merk 2 value';
                Editable = false;
            }
            field("Sub Merk 3"; Rec."PMP15 Sub Merk 3")
            {
                ApplicationArea = All;
                Caption = 'Sub Merk 3';
                ToolTip = 'Display the Sub Merk 3 value';
                Editable = false;
            }
            field("Sub Merk 4"; Rec."PMP15 Sub Merk 4")
            {
                ApplicationArea = All;
                Caption = 'Sub Merk 4';
                ToolTip = 'Display the Sub Merk 4 value';
                Editable = false;
            }
            field("Sub Merk 5"; Rec."PMP15 Sub Merk 5")
            {
                ApplicationArea = All;
                Caption = 'Sub Merk 5';
                ToolTip = 'Display the Sub Merk 5 value';
                Editable = false;
            }
            field("L/R"; Rec."PMP15 L/R")
            {
                ApplicationArea = All;
                Caption = 'L/R';
                ToolTip = 'Display the L/R value';
                Editable = false;
            }
            field("Return"; Rec."PMP15 Return")
            {
                ApplicationArea = All;
                Caption = 'Return';
                ToolTip = 'Display the Return value';
                Editable = false;
            }
            field("SOR Step"; Rec."PMP15 SOR Step")
            {
                ApplicationArea = All;
                Caption = 'SOR Step';
                ToolTip = 'Display the SOR Step value';
                Editable = false;
            }
            field("SOR Step Code"; Rec."PMP15 SOR Step Code")
            {
                ApplicationArea = All;
                Caption = 'SOR Step Code';
                ToolTip = 'Display the SOR Step Code value';
                Editable = false;
            }
            field("Tobacco Type"; Rec."PMP15 Tobacco Type")
            {
                ApplicationArea = All;
                Caption = 'Tobacco Type';
                ToolTip = 'Display the Tobacco Type value';
                Editable = false;
            }
            field("Rework"; Rec."PMP15 Rework")
            {
                ApplicationArea = All;
                Caption = 'Rework';
                ToolTip = 'Display the Rework value';
                Editable = false;
            }
            field("Variant Changes (From)"; Rec."PMP15 Variant Changes (From)")
            {
                ApplicationArea = All;
                Caption = 'Variant Changes (From)';
                ToolTip = 'Display the Variant Changes (From) value';
                Editable = false;
            }
            field("Variant Changes (To)"; Rec."PMP15 Variant Changes (To)")
            {
                ApplicationArea = All;
                Caption = 'Variant Change (To)';
                ToolTip = 'Display the Variant Change (To) value';
                Editable = false;
            }

            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/06 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
            field("PMP15 Prod. Order No."; Rec."PMP15 Prod. Order No.")
            {
                ApplicationArea = All;
                Caption = 'Prod. Order No.';
                ToolTip = 'Display the Prod. Order No. value';
                Editable = false;
            }
            field("PMP15 Production Type"; Rec."PMP15 Production Type")
            {
                ApplicationArea = All;
                Caption = 'Production Type';
                ToolTip = 'Display the Production Type value';
                Editable = false;
            }
            field("PMP15 Bin SOR Step"; Rec."PMP15 Bin SOR Step")
            {
                ApplicationArea = All;
                Caption = 'Bin SOR Step';
                ToolTip = 'Display the Bin SOR Step value';
                Editable = false;
            }
            field("PMP15 Crop"; Rec."PMP15 Crop")
            {
                ApplicationArea = All;
                Caption = 'Crop';
                ToolTip = 'Display the Crop value';
                Editable = false;
            }
            field("PMP15 Cycle (Separately)"; Rec."PMP15 Cycle (Separately)")
            {
                ApplicationArea = All;
                Caption = 'Cycle (Separately)';
                ToolTip = 'Display the Cycle (Separately) value';
                Editable = false;
            }
            field("PMP15 Invoice No."; Rec."PMP15 Invoice No.")
            {
                ApplicationArea = All;
                Caption = 'Invoice No.';
                ToolTip = 'Display the Invoice No. value';
                Editable = false;
            }
            field("PMP15 Delivery"; Rec."PMP15 Delivery")
            {
                ApplicationArea = All;
                Caption = 'Delivery';
                ToolTip = 'Display the Delivery value';
                Editable = false;
            }
            field("PMP15 Cycle Code"; Rec."PMP15 Cycle Code")
            {
                ApplicationArea = All;
                Caption = 'Cycle';
                ToolTip = 'Display the Cycle value';
                Editable = false;
            }
            field("PMP15 Output Item No."; Rec."PMP15 Output Item No.")
            {
                ApplicationArea = All;
                Caption = 'Output Item No.';
                ToolTip = 'Display the Output Item No. value';
                Editable = false;
            }
            field("PMP15 Output Variant Code"; Rec."PMP15 Output Variant Code")
            {
                ApplicationArea = All;
                Caption = 'Output Variant Code';
                ToolTip = 'Display the Output Variant Code value';
                Editable = false;
            }
            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/06 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
        }
    }
    #endregion Layout

    #region Actions
    actions { }
    #endregion Actions
}
