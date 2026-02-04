page 60423 "PMP15 SOR Inspection Pkg. List"
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
    // 2025/11/11  SW         PMP15                                     Create Page
    // 
    ApplicationArea = All;
    Caption = 'SOR Inspection Packing List';
    PageType = List;
    Editable = false;
    UsageCategory = Lists;
    CardPageId = "PMP15 SOR Inspection Packing";
    SourceTable = "PMP15 SOR Inspection Pkg Headr";
    AdditionalSearchTerms = 'Sortation, Inspection, Sort Inspect, Sort Package';

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
                field("Document Status"; Rec."Document Status")
                {
                    ApplicationArea = All;
                    Caption = 'Status';
                    ToolTip = 'Specifies the value of the Document Status field.', Comment = '%';
                }
                field("Created Date"; Rec."Created Date")
                {
                    ApplicationArea = All;
                    Caption = 'Created Date';
                    ToolTip = 'Specifies the value of the Created Date field.', Comment = '%';
                }
                field("Created By"; Rec."Created By")
                {
                    ApplicationArea = All;
                    Caption = 'Created By';
                    ToolTip = 'Specifies the value of the Created By field.', Comment = '%';
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = All;
                    Caption = 'Posting Date';
                    ToolTip = 'Specifies the value of the Posting Date field.', Comment = '%';
                }
                field("No. of Printed"; Rec."No. of Printed")
                {
                    ApplicationArea = All;
                    Caption = 'No. of Printed';
                    ToolTip = 'Specifies the value of the No. of Printed field.', Comment = '%';
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
                field("Lot No."; Rec."Lot No.")
                {
                    ApplicationArea = All;
                    Caption = 'Lot No.';
                    ToolTip = 'Specifies the value of the Lot No. field.', Comment = '%';
                }
                field("Has Rejected Line"; Rec."Has Rejected Line")
                {
                    ApplicationArea = All;
                    Caption = 'Has Rejected Line?';
                    Visible = false;
                    ToolTip = 'Specifies the value of the Has Rejected Line? field.', Comment = '%';
                }
                field("Total Inspection Line"; Rec."Total Inspection Line")
                {
                    ApplicationArea = All;
                    Caption = 'Total Line';
                    Visible = false;
                    ToolTip = 'Specifies the value of the Total Line field.', Comment = '%';
                }
                field("Total Rejected Line"; Rec."Total Rejected Line")
                {
                    ApplicationArea = All;
                    Caption = 'Total Rejected Line';
                    Visible = false;
                    ToolTip = 'Specifies the value of the Total Rejected Line field.', Comment = '%';
                }
                field("Total Rework Line"; Rec."Total Rework Line")
                {
                    ApplicationArea = All;
                    Caption = 'Total Rework Line';
                    Visible = false;
                    ToolTip = 'Specifies the value of the Total Rework Line field.', Comment = '%';
                }
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        Rec.CalcFields("Total Inspection Line", "Has Rejected Line", "Total Rejected Line", "Total Rework Line", "Total Hold Line");
    end;
}
