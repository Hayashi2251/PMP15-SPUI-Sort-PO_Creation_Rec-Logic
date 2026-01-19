page 60408 "PMP15 Sub Merk 4"
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
    Caption = 'Sub Merk 4';
    PageType = List;
    SourceTable = "PMP15 Sub Merk";
    SourceTableView = where(Type = const("Sub Merk 4"));
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Code"; Rec."Code")
                {
                    ToolTip = 'Specifies the value of the Code field.', Comment = '%';
                }
                field(Description; Rec.Description)
                {
                    ToolTip = 'Specifies the value of the Description field.', Comment = '%';
                }
                field("Item Owner Internal"; Rec."Item Owner Internal")
                {
                    ToolTip = 'Specifies the value of the Item Owner Internal field.', Comment = '%';
                }
                field(Group; Rec.Group)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Item Owner Internal field.', Comment = '%';
                }
            }
        }
    }
}
