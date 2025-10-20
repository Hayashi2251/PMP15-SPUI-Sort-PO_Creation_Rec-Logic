page 60407 "PMP15 Sub Merk 3"
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
    // 2025/09/12  SW         PMP15         -                           Create Page
    // 
    ApplicationArea = All;
    Caption = 'Sub Merk 3';
    PageType = List;
    SourceTable = "PMP15 Sub Merk 3";
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Tobacco Type"; Rec."Tobacco Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Tobacco Type field.', Comment = '%';
                }
                field("Sub Merk 2 Code"; Rec."Sub Merk 2 Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Submerk 2 field.', Comment = '%';
                }
                field("Code"; Rec."Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Code field.', Comment = '%';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Description field.', Comment = '%';
                }
                field("Item Owner Internal"; Rec."Item Owner Internal")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Item Owner Internal field.', Comment = '%';
                }
                field(Group; Rec.Group)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Item Owner Internal field.', Comment = '%';
                }
                field(Ranking; Rec.Ranking)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Item Owner Internal field.', Comment = '%';
                }
            }
        }
    }
}
