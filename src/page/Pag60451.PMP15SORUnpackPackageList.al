page 60451 "PMP15 SOR Unpack Package List"
{
    ApplicationArea = All;
    Caption = 'Sortation Unpack Package List';
    PageType = List;
    Editable = false;
    CardPageId = "PMP15 SOR Unpack Pkg. Card";
    SourceTable = "PMP15 Sortation Unpack Package";
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    Caption = 'No.';
                    ToolTip = 'Specifies the value of the No. field.', Comment = '%';
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = All;
                    Caption = 'Posting Date';
                    ToolTip = 'Specifies the value of the Posting Date field.', Comment = '%';
                }
                field("Type"; Rec."Type")
                {
                    ApplicationArea = All;
                    Caption = 'Type';
                    ToolTip = 'Specifies the value of the Type field.', Comment = '%';
                }
                field("Sorted Item No."; Rec."Sorted Item No.")
                {
                    ApplicationArea = All;
                    Caption = 'Sorted Item No.';
                    ToolTip = 'Specifies the value of the Sorted Item No. field.', Comment = '%';
                }
                field("Sorted Variant Code"; Rec."Sorted Variant Code")
                {
                    ApplicationArea = All;
                    Caption = 'Sorted Variant Code';
                    ToolTip = 'Specifies the value of the Sorted Variant Code field.', Comment = '%';
                }
                field("Sorted Package No."; Rec."Sorted Package No.")
                {
                    ApplicationArea = All;
                    Caption = 'Sorted Package No.';
                    ToolTip = 'Specifies the value of the Sorted Package No. field.', Comment = '%';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    Caption = 'Location Code';
                    ToolTip = 'Specifies the value of the Location Code field.', Comment = '%';
                }
                field("Bin Code"; Rec."Bin Code")
                {
                    ApplicationArea = All;
                    Caption = 'Bin Code';
                    ToolTip = 'Specifies the value of the Bin Code field.', Comment = '%';
                }
                field("Total Current Quantity"; Rec."Total Current Quantity")
                {
                    ApplicationArea = All;
                    Caption = 'Total Current Quantity';
                    ToolTip = 'Specifies the value of the Total Current Quantity field.', Comment = '%';
                }
                field("Total New Quantity"; Rec."Total New Quantity")
                {
                    ApplicationArea = All;
                    Caption = 'Total New Quantity';
                    ToolTip = 'Specifies the value of the Total New Quantity field.', Comment = '%';
                }
                field("Sum New Quantity"; Rec."Sum New Quantity")
                {
                    ApplicationArea = All;
                    Caption = 'Sum New Quantity';
                    ToolTip = 'Specifies the value of the Sum New Quantity field.', Comment = '%';
                    Visible = false;
                }


                #region SYSTEM FIELD
                field(SystemCreatedAt; Rec.SystemCreatedAt)
                {
                    ApplicationArea = All;
                    Caption = 'SystemCreatedAt';
                    ToolTip = 'Specifies the value of the SystemCreatedAt field.', Comment = '%';
                    Visible = false;
                    Editable = false;
                }
                field(SystemCreatedBy; Rec.SystemCreatedBy)
                {
                    ApplicationArea = All;
                    Caption = 'SystemCreatedBy';
                    ToolTip = 'Specifies the value of the SystemCreatedBy field.', Comment = '%';
                    Visible = false;
                    Editable = false;
                }
                field(SystemId; Rec.SystemId)
                {
                    ApplicationArea = All;
                    Caption = 'SystemId';
                    ToolTip = 'Specifies the value of the SystemId field.', Comment = '%';
                    Visible = false;
                    Editable = false;
                }
                field(SystemModifiedAt; Rec.SystemModifiedAt)
                {
                    ApplicationArea = All;
                    Caption = 'SystemModifiedAt';
                    ToolTip = 'Specifies the value of the SystemModifiedAt field.', Comment = '%';
                    Visible = false;
                    Editable = false;
                }
                field(SystemModifiedBy; Rec.SystemModifiedBy)
                {
                    ApplicationArea = All;
                    Caption = 'SystemModifiedBy';
                    ToolTip = 'Specifies the value of the SystemModifiedBy field.', Comment = '%';
                    Visible = false;
                    Editable = false;
                }
                #endregion SYSTEM FIELD
            }
        }
    }
}
