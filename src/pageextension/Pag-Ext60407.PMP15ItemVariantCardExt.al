pageextension 60407 "PMP15 Item Variant Card Ext" extends "Item Variant Card"
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
    // 2025/09/12  SW         PMP15                                     Create Page Extension
    // 

    #region Layout
    layout
    {
        addlast(ItemVariant)
        {
            field("PMP15 Sub Merk 1"; Rec."PMP15 Sub Merk 1")
            {
                ApplicationArea = All;
                Caption = 'Sub Merk 1';
            }
        }
    }
    #endregion Layout

    #region Actions
    actions { }
    #endregion Actions
}
