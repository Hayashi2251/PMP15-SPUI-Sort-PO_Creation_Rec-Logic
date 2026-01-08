page 60449 "PMP15 SOR Unpack Curr-Det. Res"
{
    // VERSION PMP15 

    // VERSION
    // Version List       Name
    // ============================================================================================================
    // PMP15              PMP SPUI - Sort-PO Creation & Recording (Logic)
    // 
    // PAGE
    // Date        Developer  Version List  Trigger                     Description
    // ============================================================================================================
    // 2026/01/06  SW         PMP15                                     Create Page
    // 
    ApplicationArea = All;
    Caption = 'Sortation Unpack Package Current Detail Result';
    PageType = ListPart;
    SourceTable = "PMP15 SOR Unpack Curr-Det. Res";

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                    Caption = 'Document No.';
                    ToolTip = 'Specifies the value of the Document No. field.', Comment = '%';
                    Editable = false;
                }
                field("Line No."; Rec."Line No.")
                {
                    ApplicationArea = All;
                    Caption = 'Line No.';
                    ToolTip = 'Specifies the value of the Line No. field.', Comment = '%';
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
                    Caption = 'Package No.';
                    ToolTip = 'Specifies the value of the Package No. field.', Comment = '%';
                    Editable = false;
                }
                field("Sub Merk 1"; Rec."Sub Merk 1")
                {
                    ApplicationArea = All;
                    Caption = 'Sub Merk 1';
                    ToolTip = 'Specifies the value of the Sub Merk 1 field.', Comment = '%';
                    Editable = false;
                }
                field("Sub Merk 2"; Rec."Sub Merk 2")
                {
                    ApplicationArea = All;
                    Caption = 'Sub Merk 2';
                    ToolTip = 'Specifies the value of the Sub Merk 2 field.', Comment = '%';
                    Editable = false;
                }
                field("Sub Merk 3"; Rec."Sub Merk 3")
                {
                    ApplicationArea = All;
                    Caption = 'Sub Merk 3';
                    ToolTip = 'Specifies the value of the Sub Merk 3 field.', Comment = '%';
                    Editable = false;
                }
                field("Sub Merk 4"; Rec."Sub Merk 4")
                {
                    ApplicationArea = All;
                    Caption = 'Sub Merk 4';
                    ToolTip = 'Specifies the value of the Sub Merk 4 field.', Comment = '%';
                    Editable = false;
                }
                field("Sub Merk 5"; Rec."Sub Merk 5")
                {
                    ApplicationArea = All;
                    Caption = 'Sub Merk 5';
                    ToolTip = 'Specifies the value of the Sub Merk 5 field.', Comment = '%';
                    Editable = false;
                }
                field("L/R"; Rec."L/R")
                {
                    ApplicationArea = All;
                    Caption = 'L/R';
                    ToolTip = 'Specifies the value of the L/R field.', Comment = '%';
                    Editable = false;
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    Caption = 'uantit';
                    ToolTip = 'Specifies the value of the Quantity field.', Comment = '%';
                    Editable = false;
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ApplicationArea = All;
                    Caption = 'Unit of Measure Code';
                    ToolTip = 'Specifies the value of the Unit of Measure Code field.', Comment = '%';
                    Editable = false;
                }


                field("Current Sorted Item No."; Rec."Current Sorted Item No.")
                {
                    ApplicationArea = All;
                    Caption = 'Current Sorted Item No.';
                    ToolTip = 'Specifies the value of the Current Sorted Item No. field.', Comment = '%';
                    Editable = false;
                    Visible = false;
                }
                field("Current Sorted Variant Code"; Rec."Current Sorted Variant Code")
                {
                    ApplicationArea = All;
                    Caption = 'Current Sorted Variant Code';
                    ToolTip = 'Specifies the value of the Current Sorted Variant Code field.', Comment = '%';
                    Editable = false;
                    Visible = false;
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
