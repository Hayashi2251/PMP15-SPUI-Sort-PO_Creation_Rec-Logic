pageextension 60409 "PMP15 Pkg No. Infor Card Ext" extends "Package No. Information Card"
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
        addafter(SubMerk)
        {
            group("Sortation Result")
            {
                Caption = 'Sortation Result';
                field("PMP15 Mixed"; Rec."PMP15 Mixed")
                {
                    ApplicationArea = All;
                    Caption = 'Mixed';
                    ToolTip = 'Specifies the value of the Mixed field.';
                }
                field("PMP15 Able to Sell"; Rec."PMP15 Able to Sell")
                {
                    ApplicationArea = All;
                    Caption = 'Able to Sell';
                    ToolTip = 'Specifies the value of the Able to Sell field.';
                }
            }
        }
        addlast(content)
        {
            group("Sortation Detail Result")
            {
                Caption = 'Sortation Detail Result';
                part(SortationDetailResult; "PMP15 Sort-Det. Result Subform")
                {
                    ApplicationArea = All;
                    SubPageLink = "Item No." = field("Item No."), "Variant Code" = field("Variant Code"), "Package No." = field("Package No.");
                }
            }
        }
    }
    #endregion Layout

    #region Actions
    actions { }
    #endregion Actions
}
