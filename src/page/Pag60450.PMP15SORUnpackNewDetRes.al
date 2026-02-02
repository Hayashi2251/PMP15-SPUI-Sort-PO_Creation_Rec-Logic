page 60450 "PMP15 SOR Unpack New-Det. Res"
{
    // VERSION PMP15 

    // VERSION
    // Version List       Name
    // ============================================================================================================
    // PMP15              ID Localization
    // 
    // PAGE
    // Date        Developer  Version List  Trigger                     Description
    // ============================================================================================================
    // 2026/01/10  SW         PMP15                                     Create Page
    // 
    ApplicationArea = All;
    Caption = 'New Sortation Detail Result';
    PageType = ListPart;
    SourceTable = "PMP15 SOR Unpack New-Det. Res";
    AutoSplitKey = true;
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Cur-SOR Det. Res. Line No."; Rec."Cur-SOR Det. Res. Line No.")
                {
                    ApplicationArea = All;
                    Caption = 'Cur-SOR Det. Res. Line No.';
                    ToolTip = 'Specifies the value of the Cur-SOR Det. Res. Line No. field.', Comment = '%';
                }
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                    Caption = 'Document No.';
                    ToolTip = 'Specifies the value of the Document No. field.', Comment = '%';
                    Editable = false;
                    Visible = false;
                }
                field("Line No."; Rec."Line No.")
                {
                    ApplicationArea = All;
                    Caption = 'Line No.';
                    ToolTip = 'Specifies the value of the Line No. field.', Comment = '%';
                    Editable = false;
                    Visible = false;
                }
                field("Sorted Item No."; Rec."Sorted Item No.")
                {
                    ApplicationArea = All;
                    Caption = 'Sorted Item No.';
                    ToolTip = 'Specifies the value of the Sorted Item No. field.', Comment = '%';
                    Editable = false;
                }
                field("Sorted Variant Code"; Rec."Sorted Variant Code")
                {
                    ApplicationArea = All;
                    Caption = 'Sorted Variant Code';
                    ToolTip = 'Specifies the value of the Sorted Variant Code field.', Comment = '%';
                    Editable = false;
                }
                field("Lot No."; Rec."Lot No.")
                {
                    ApplicationArea = All;
                    Caption = 'Lot No.';
                    ToolTip = 'Specifies the value of the Lot No. field.', Comment = '%';
                    Editable = false;
                }
                field("Package No."; Rec."Package No.")
                {
                    ApplicationArea = All;
                    Caption = 'Current Package No.';
                    ToolTip = 'Specifies the value of the Current Package No. field.', Comment = '%';
                    Editable = false;
                }
                field("New Package No."; Rec."New Package No.")
                {
                    ApplicationArea = All;
                    Caption = 'New Package No.';
                    ToolTip = 'Specifies the value of the New Package No. field.', Comment = '%';
                }
                field("Sub Merk 1"; Rec."Sub Merk 1")
                {
                    ApplicationArea = All;
                    Caption = 'New Sub Merk 1';
                    ToolTip = 'Specifies the value of the Sub Merk 1 field.', Comment = '%';
                    Editable = false;
                }
                field("Sub Merk 2"; Rec."Sub Merk 2")
                {
                    ApplicationArea = All;
                    Caption = 'New Sub Merk 2';
                    ToolTip = 'Specifies the value of the Sub Merk 2 field.', Comment = '%';
                }
                field("Sub Merk 3"; Rec."Sub Merk 3")
                {
                    ApplicationArea = All;
                    Caption = 'New Sub Merk 3';
                    ToolTip = 'Specifies the value of the Sub Merk 3 field.', Comment = '%';
                }
                field("Sub Merk 4"; Rec."Sub Merk 4")
                {
                    ApplicationArea = All;
                    Caption = 'New Sub Merk 4';
                    ToolTip = 'Specifies the value of the Sub Merk 4 field.', Comment = '%';
                }
                field("Sub Merk 5"; Rec."Sub Merk 5")
                {
                    ApplicationArea = All;
                    Caption = 'New Sub Merk 5';
                    ToolTip = 'Specifies the value of the Sub Merk 5 field.', Comment = '%';
                }
                field("L/R"; Rec."L/R")
                {
                    ApplicationArea = All;
                    Caption = 'L/R';
                    ToolTip = 'Specifies the value of the L/R field.', Comment = '%';
                }
                field("Qty. to Handle"; Rec."Qty. to Handle")
                {
                    ApplicationArea = All;
                    Caption = 'Qty. to Handle';
                    ToolTip = 'Specifies the value of the Qty. to Handle field.', Comment = '%';
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ApplicationArea = All;
                    Caption = 'Unit of Measure Code';
                    ToolTip = 'Specifies the value of the Unit of Measure Code field.', Comment = '%';
                    Editable = false;
                }



                #region BUSINESS CENTRAL (TIMESTAMP) SYSTEM FIELD
                field(SystemCreatedAt; Rec.SystemCreatedAt)
                {
                    ApplicationArea = All;
                    Caption = '';
                    ToolTip = 'Specifies the value of the SystemCreatedAt field.', Comment = '%';
                    Editable = false;
                    Visible = false;
                }
                field(SystemCreatedBy; Rec.SystemCreatedBy)
                {
                    ApplicationArea = All;
                    Caption = '';
                    ToolTip = 'Specifies the value of the SystemCreatedBy field.', Comment = '%';
                    Editable = false;
                    Visible = false;
                }
                field(SystemId; Rec.SystemId)
                {
                    ApplicationArea = All;
                    Caption = '';
                    ToolTip = 'Specifies the value of the SystemId field.', Comment = '%';
                    Editable = false;
                    Visible = false;
                }
                field(SystemModifiedAt; Rec.SystemModifiedAt)
                {
                    ApplicationArea = All;
                    Caption = '';
                    ToolTip = 'Specifies the value of the SystemModifiedAt field.', Comment = '%';
                    Editable = false;
                    Visible = false;
                }
                field(SystemModifiedBy; Rec.SystemModifiedBy)
                {
                    ApplicationArea = All;
                    Caption = '';
                    ToolTip = 'Specifies the value of the SystemModifiedBy field.', Comment = '%';
                    Editable = false;
                    Visible = false;
                }
                #endregion BUSINESS CENTRAL (TIMESTAMP) SYSTEM FIELD
            }
        }
    }
}
