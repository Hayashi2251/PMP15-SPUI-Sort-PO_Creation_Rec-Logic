pageextension 60453 "PMP15 Item Card Ext" extends "Item Card"
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
    // 2026/01/06  SW         PMP15         -                           Create Page Extension
    // 

    #region Layout
    layout
    {
        addlast("Add. Item Info")
        {
            field("PMP15 Allowance Packing Weight"; Rec."PMP15 Allowance Packing Weight")
            {
                ApplicationArea = All;
                Caption = 'Allowance Packing Weight';
                ToolTip = 'Specifies the value of the Allowance Packing Weight field.';
            }
        }
    }
    #endregion Layout

    #region Actions
    actions { }
    #endregion Actions
}
