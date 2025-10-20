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
                Editable = false;
            }
            field("Sub Merk 2"; Rec."PMP15 Sub Merk 2")
            {
                ApplicationArea = All;
                Editable = false;
            }
            field("Sub Merk 3"; Rec."PMP15 Sub Merk 3")
            {
                ApplicationArea = All;
                Editable = false;
            }
            field("Sub Merk 4"; Rec."PMP15 Sub Merk 4")
            {
                ApplicationArea = All;
                Editable = false;
            }
            field("Sub Merk 5"; Rec."PMP15 Sub Merk 5")
            {
                ApplicationArea = All;
                Editable = false;
            }
            field("L/R"; Rec."PMP15 L/R")
            {
                ApplicationArea = All;
                Editable = false;
            }
            field("Return"; Rec."PMP15 Return")
            {
                ApplicationArea = All;
                Editable = false;
            }
            field("SOR Step"; Rec."PMP15 SOR Step")
            {
                ApplicationArea = All;
                Editable = false;
            }
            field("SOR Step Code"; Rec."PMP15 SOR Step Code")
            {
                ApplicationArea = All;
                Editable = false;
            }
            field("Tobacco Type"; Rec."PMP15 Tobacco Type")
            {
                ApplicationArea = All;
                Editable = false;
            }
            field("Rework"; Rec."PMP15 Rework")
            {
                ApplicationArea = All;
                Editable = false;
            }
            field("Variant Changes (From)"; Rec."PMP15 Variant Changes (From)")
            {
                ApplicationArea = All;
                Editable = false;
            }
            field("Variant Changes (To)"; Rec."PMP15 Variant Changes (To)")
            {
                ApplicationArea = All;
                Editable = false;
            }
        }
    }
    #endregion Layout

    #region Actions
    actions { }
    #endregion Actions
}
