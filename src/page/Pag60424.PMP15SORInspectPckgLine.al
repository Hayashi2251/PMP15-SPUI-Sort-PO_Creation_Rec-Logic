page 60424 "PMP15 SOR Inspect. Pckg. Line"
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
    Caption = 'SOR Inspect. Pckg. Subform';
    PageType = ListPart;
    SourceTable = "PMP15 SOR Inspection Pkg. Line";
    AutoSplitKey = true;
    DelayedInsert = true;
    LinksAllowed = false;
    MultipleNewLines = true;
    DeleteAllowed = false;

    #region LAYOUTS
    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Line No."; Rec."Line No.")
                {
                    ApplicationArea = All;
                    Caption = 'Line No.';
                    Visible = false;
                    ToolTip = 'Specifies the value of the Line No. field.', Comment = '%';
                }
                field(Select; Rec.Select)
                {
                    ApplicationArea = All;
                    Caption = 'Select';
                    ToolTip = 'Specifies the value of the Select field.', Comment = '%';
                }
                field("Sub Merk 1"; Rec."Sub Merk 1")
                {
                    ApplicationArea = All;
                    Caption = 'Sub Merk 1';
                    Editable = false;
                    ToolTip = 'Specifies the value of the Sub Merk 1 field.', Comment = '%';
                }
                field("Sub Merk 2"; Rec."Sub Merk 2")
                {
                    ApplicationArea = All;
                    Caption = 'Sub Merk 2';
                    Editable = false;
                    ToolTip = 'Specifies the value of the Sub Merk 2 field.', Comment = '%';
                }
                field("Sub Merk 3"; Rec."Sub Merk 3")
                {
                    ApplicationArea = All;
                    Caption = 'Sub Merk 3';
                    Editable = false;
                    ToolTip = 'Specifies the value of the Sub Merk 3 field.', Comment = '%';
                }
                field("Sub Merk 4"; Rec."Sub Merk 4")
                {
                    ApplicationArea = All;
                    Caption = 'Sub Merk 4';
                    Editable = false;
                    ToolTip = 'Specifies the value of the Sub Merk 4 field.', Comment = '%';
                }
                field("Sub Merk 5"; Rec."Sub Merk 5")
                {
                    ApplicationArea = All;
                    Caption = 'Sub Merk 5';
                    Editable = false;
                    ToolTip = 'Specifies the value of the Sub Merk 5 field.', Comment = '%';
                }
                field("L/R"; Rec."L/R")
                {
                    ApplicationArea = All;
                    Caption = 'L/R';
                    ToolTip = 'Specifies the value of the L/R field.', Comment = '%';
                }
                field("Lot No."; Rec."Lot No.")
                {
                    ApplicationArea = All;
                    Caption = 'Lot No.';
                    Editable = false;
                    ToolTip = 'Specifies the value of the Lot No. field.', Comment = '%';
                }
                field("Package No."; Rec."Package No.")
                {
                    ApplicationArea = All;
                    Caption = 'Package No.';
                    Editable = false;
                    ToolTip = 'Specifies the value of the Package No. field.', Comment = '%';
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    Caption = 'Quantity';
                    Editable = false;
                    ToolTip = 'Specifies the value of the Quantity field.', Comment = '%';
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ApplicationArea = All;
                    Caption = 'Unit of Measure Code';
                    Editable = false;
                    ToolTip = 'Specifies the value of the Unit of Measure Code field.', Comment = '%';
                }
                field(Result; Rec.Result)
                {
                    ApplicationArea = All;
                    Caption = 'Result';
                    ToolTip = 'Specifies the value of the Result field.', Comment = '%';
                }
                field("New Item Code"; Rec."New Item Code")
                {
                    ApplicationArea = All;
                    Caption = 'New Item Code';
                    Editable = Rec.Result = Rec.Result::"Item Change";
                    ToolTip = 'Specifies the value of the New Item Code field.', Comment = '%';
                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Item: Record Item;
                        ProdItem: Record "PMP07 Production Item Type";
                        ProdItemFilter: array[7] of Text;
                    begin
                        Item.Reset();
                        ProdItem.Reset();
                        Clear(ProdItemFilter);

                        ProdItem.SetRange("Production Item Type", ProdItem."Production Item Type"::"Sortation-Inspection");
                        if ProdItem.FindSet() then
                            repeat
                                ProdItemFilter[1] += PMPAppLogicMgmt.PMP02AddJoinStringwithPIPESeparator(ProdItemFilter[1], ProdItem."Item Group");
                                ProdItemFilter[2] += PMPAppLogicMgmt.PMP02AddJoinStringwithPIPESeparator(ProdItemFilter[2], ProdItem."Item Category Code");
                                ProdItemFilter[3] += PMPAppLogicMgmt.PMP02AddJoinStringwithPIPESeparator(ProdItemFilter[3], ProdItem."Item Class L1");
                                ProdItemFilter[4] += PMPAppLogicMgmt.PMP02AddJoinStringwithPIPESeparator(ProdItemFilter[4], ProdItem."Item Class L2");
                                ProdItemFilter[5] += PMPAppLogicMgmt.PMP02AddJoinStringwithPIPESeparator(ProdItemFilter[5], ProdItem."Item Type L1");
                                ProdItemFilter[6] += PMPAppLogicMgmt.PMP02AddJoinStringwithPIPESeparator(ProdItemFilter[6], ProdItem."Item Type L2");
                                ProdItemFilter[7] += PMPAppLogicMgmt.PMP02AddJoinStringwithPIPESeparator(ProdItemFilter[7], ProdItem."Item Type L3");
                            until ProdItem.Next() = 0;

                        Item.SetFilter("PMP04 Item Group", ProdItemFilter[1]);
                        Item.SetFilter("Item Category Code", ProdItemFilter[2]);
                        Item.SetFilter("PMP04 Item Class L1", ProdItemFilter[3]);
                        Item.SetFilter("PMP04 Item Class L2", ProdItemFilter[4]);
                        Item.SetFilter("PMP04 Item Type L1", ProdItemFilter[5]);
                        Item.SetFilter("PMP04 Item Type L2", ProdItemFilter[6]);
                        Item.SetFilter("PMP04 Item Type L3", ProdItemFilter[7]);
                        Item.SetFilter("PMP04 Item Owner Internal", ExtComSetup."PMP15 SOR Item Owner Internal");

                        if Page.RunModal(Page::"Item List", Item) = Action::LookupOK then begin
                            Rec."New Item Code" := Item."No.";
                        end;
                    end;
                }
                field(Standard; Rec.Standard)
                {
                    ApplicationArea = All;
                    Caption = 'Standard';
                    ToolTip = 'Specifies the value of the Standard field.', Comment = '%';
                }
                field("New Sub Merk 1"; Rec."New Sub Merk 1")
                {
                    ApplicationArea = All;
                    Caption = 'New Sub Merk 1';
                    Editable = Rec.Result = Rec.Result::"Item Change";
                    ToolTip = 'Specifies the value of the New Sub Merk 1 field.', Comment = '%';
                }
                field("New Sub Merk 2"; Rec."New Sub Merk 2")
                {
                    ApplicationArea = All;
                    Caption = 'New Sub Merk 2';
                    Editable = Rec.Result = Rec.Result::"Item Change";
                    ToolTip = 'Specifies the value of the New Sub Merk 2 field.', Comment = '%';
                }
                field("New Sub Merk 3"; Rec."New Sub Merk 3")
                {
                    ApplicationArea = All;
                    Caption = 'New Sub Merk 3';
                    Editable = Rec.Result = Rec.Result::"Item Change";
                    ToolTip = 'Specifies the value of the New Sub Merk 3 field.', Comment = '%';
                }
                field("New Sub Merk 4"; Rec."New Sub Merk 4")
                {
                    ApplicationArea = All;
                    Caption = 'New Sub Merk 4';
                    Editable = Rec.Result = Rec.Result::"Item Change";
                    ToolTip = 'Specifies the value of the New Sub Merk 4 field.', Comment = '%';
                }
                field("New Sub Merk 5"; Rec."New Sub Merk 5")
                {
                    ApplicationArea = All;
                    Caption = 'New Sub Merk 5';
                    Editable = Rec.Result = Rec.Result::"Item Change";
                    ToolTip = 'Specifies the value of the New Sub Merk 5 field.', Comment = '%';
                }
                field("New L/R"; Rec."New L/R")
                {
                    ApplicationArea = All;
                    Caption = 'L/R';
                    ToolTip = 'Specifies the value of the New L/R field.', Comment = '%';
                }
                field("From Bin Code"; Rec."From Bin Code")
                {
                    ApplicationArea = All;
                    Caption = 'From Bin Code';
                    Editable = false;
                    ToolTip = 'Specifies the value of the From Bin Code field.', Comment = '%';
                }
                field("To Bin Code"; Rec."To Bin Code")
                {
                    ApplicationArea = All;
                    Caption = 'To Bin Code';
                    ToolTip = 'Specifies the value of the To Bin Code field.', Comment = '%';
                }
                field("Prod. Order No."; Rec."Prod. Order No.")
                {
                    ApplicationArea = All;
                    Caption = 'Prod. Order No.';
                    Editable = false;
                    ToolTip = 'Specifies the value of the Prod. Order No. field.', Comment = '%';
                }
                field("Prod. Order Line No."; Rec."Prod. Order Line No.")
                {
                    ApplicationArea = All;
                    Caption = 'Prod. Order Line No.';
                    Editable = false;
                    ToolTip = 'Specifies the value of the Prod. Order Line No. field.', Comment = '%';
                }
                // field(Process; Rec.Process)
                // {
                //     ApplicationArea = All;
                //     Caption = 'Prod. Order Line No.';
                //     ToolTip = 'Specifies the value of the Process field.', Comment = '%';
                // }
                // field("Location Code"; Rec."Location Code")
                // {
                //     ApplicationArea = All;
                //     Caption = 'Process';
                //     ToolTip = 'Specifies the value of the Location Code field.', Comment = '%';
                // }
            }
        }
    }
    #endregion LAYOUTS

    #region ACTIONS
    actions
    {
        area(Processing)
        {
            action(DeleteLine)
            {
                ApplicationArea = All;
                Caption = 'Delete Line';
                Image = DeleteRow;
                ToolTip = '';
                Enabled = IsDocumentReleased;
                trigger OnAction()
                begin
                    Rec.Delete();
                end;
            }
            action(SelectAll)
            {
                ApplicationArea = All;
                Caption = 'Select All';
                Image = SelectMore;
                ToolTip = '';
                trigger OnAction()
                var
                    SORInpctPkgLine: Record "PMP15 SOR Inspection Pkg. Line";
                begin
                    SORInpctPkgLine.Reset();
                    SORInpctPkgLine.SetRange("Document No.", Rec."Document No.");
                    SORInpctPkgLine.ModifyAll(Select, true);
                end;
            }
            action(DeselectAll)
            {
                ApplicationArea = All;
                Caption = 'Deselect All';
                Image = DeleteAllBreakpoints;
                ToolTip = '';
                trigger OnAction()
                var
                    SORInpctPkgLine: Record "PMP15 SOR Inspection Pkg. Line";
                begin
                    SORInpctPkgLine.Reset();
                    SORInpctPkgLine.SetRange("Document No.", Rec."Document No.");
                    SORInpctPkgLine.ModifyAll(Select, false);
                end;
            }
        }
    }
    #endregion ACTIONS

    var
        ExtComSetup: Record "PMP07 Extended Company Setup";
        SORInspectPkgHeadr: Record "PMP15 SOR Inspection Pkg Headr";
        IsDocumentReleased: Boolean;

    protected var
        PMPAppLogicMgmt: Codeunit "PMP02 App Logic Management";
        SortationMgmt: Codeunit "PMP15 Sortation PO Mgmt";

    trigger OnInit()
    begin
        ExtComSetup.Get();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        SORInspectPkgHeadr.SetRange("No.", Rec."Document No.");
        if SORInspectPkgHeadr.FindFirst() then begin
            if SORInspectPkgHeadr."Document Status" = SORInspectPkgHeadr."Document Status"::Open then begin
                IsDocumentReleased := true;
            end else begin
                IsDocumentReleased := false;
            end;
        end;
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        Rec."Location Code" := ExtComSetup."PMP15 SOR Location Code";
    end;
}
