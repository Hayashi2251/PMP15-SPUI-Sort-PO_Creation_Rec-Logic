pageextension 60455 "PMP15 Purch Ret-Order Doc. Ext" extends "Purchase Return Order"
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
    // 2026/02/02  SW         PMP15         -                           Create Page Extension
    // 

    #region Layout
    layout { }
    #endregion Layout

    #region Actions
    actions
    {
        addlast(processing)
        {
            action(GetSORInspectPkgLine)
            {
                ApplicationArea = All;
                Caption = 'Get SOR Inspect. Pkg';
                Image = GetLines;
                trigger OnAction()
                begin
                    SortationMgmt.GetPackagetoInspectforPurchReturnOrder(Rec);
                end;
            }
        }

        addlast(Category_Process)
        {
            actionref(GetSORInspectPkgLine_Promoted; GetSORInspectPkgLine) { }
        }
    }
    #endregion Actions

    var
        ExtComSetup: Record "PMP07 Extended Company Setup";

    protected var
        PMPAppLogicMgmt: Codeunit "PMP02 App Logic Management";
        SortationMgmt: Codeunit "PMP15 Sortation PO Mgmt";
}
