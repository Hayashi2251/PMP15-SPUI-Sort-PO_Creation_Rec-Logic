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
    actions
    {
        // // LA TEMPORAIRE
        // addlast(processing)
        // {
        //     action(CheckPackageAbleToSell)
        //     {
        //         ApplicationArea = All;
        //         Caption = 'Check Able To Sell';
        //         Enabled = CheckPackageAbleToSell_Visibility;
        //         Visible = CheckPackageAbleToSell_Visibility;
        //         trigger OnAction()
        //         var
        //             SORMgmt: Codeunit "PMP15 Sortation PO Mgmt";
        //             SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary;
        //             SORProdOrdDetLine: Record "PMP15 Sortation Detail Quality";
        //         begin
        //             Clear(SORMgmt);
        //             SORProdOrdDetLine.Reset();

        //             SortProdOrderRec.Init();
        //             SortProdOrderRec."Entry No." := 1;
        //             SortProdOrderRec."Unsorted Item No." := Rec."PMP15 Unsorted Item No.";
        //             SortProdOrderRec."Unsorted Variant Code" := Rec."PMP15 Unsorted Variant Code";

        //             SORProdOrdDetLine.SetCurrentKey("Entry No.");
        //             SORProdOrdDetLine.SetRange("Item No.", Rec."Item No.");
        //             SORProdOrdDetLine.SetRange("Variant Code", Rec."Variant Code");
        //             SORProdOrdDetLine.SetRange("Package No.", Rec."Package No.");
        //             SORProdOrdDetLine.SetAscending("Entry No.", true);
        //             if SORProdOrdDetLine.FindLast() then begin
        //                 SORMgmt.CheckPkgNoInfoAbletoSell(SORProdOrdDetLine, SortProdOrderRec);
        //             end;

        //         end;
        //     }
        // }
    }
    #endregion Actions

    // var
    //     CheckPackageAbleToSell_Visibility: Boolean;
}
