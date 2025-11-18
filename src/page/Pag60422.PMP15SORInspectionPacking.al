page 60422 "PMP15 SOR Inspection Packing"
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
    Caption = 'SOR Inspection Packing';
    PageType = Document;
    RefreshOnActivate = true;
    SourceTable = "PMP15 SOR Inspection Pkg Headr";

    #region LAYOUTS
    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    Importance = Promoted;
                    Caption = 'No.';
                    Editable = false;
                    ToolTip = 'Specifies the value of the No. field.', Comment = '%';
                    trigger OnAssistEdit()
                    begin
                        if Rec.AssistEdit(xRec) then
                            CurrPage.Update();
                    end;
                }
                field("Document Status"; Rec."Document Status")
                {
                    ApplicationArea = All;
                    Caption = 'Status';
                    Importance = Promoted;
                    Editable = false;
                    ToolTip = 'Specifies the value of the Document Status field.', Comment = '%';
                }
                field("Created Date"; Rec."Created Date")
                {
                    ApplicationArea = All;
                    Caption = 'Created Date';
                    Importance = Additional;
                    Editable = false;
                    ToolTip = 'Specifies the value of the Created Date field.', Comment = '%';
                }
                field("Created By"; Rec."Created By")
                {
                    ApplicationArea = All;
                    Caption = 'Created By';
                    Importance = Additional;
                    Editable = false;
                    ToolTip = 'Specifies the value of the Created By field.', Comment = '%';
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = All;
                    Caption = 'Posting Date';
                    Importance = Promoted;
                    ToolTip = 'Specifies the value of the Posting Date field.', Comment = '%';
                }
                field("No. of Printed"; Rec."No. of Printed")
                {
                    ApplicationArea = All;
                    Caption = 'No. of Printed';
                    Importance = Additional;
                    Editable = false;
                    ToolTip = 'Specifies the value of the No. of Printed field.', Comment = '%';
                }
            }
            group(FilterGroup)
            {
                Caption = 'Filter';
                field("Sorted Item No."; Rec."Sorted Item No.")
                {
                    ApplicationArea = All;
                    Caption = 'Sorted Item No.';
                    ToolTip = 'Specifies the value of the Sorted Item No. field.', Comment = '%';
                    Editable = Rec."Document Status" <> Rec."Document Status"::Released;
                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Item: Record Item;
                        ProdItem: Record "PMP07 Production Item Type";
                        ProdItemFilter: array[7] of Text;
                    begin
                        Item.Reset();
                        ProdItem.Reset();
                        Clear(ProdItemFilter);

                        ProdItem.SetRange("Production Item Type", ProdItem."Production Item Type"::"Sortation-Sorted");
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

                        if Page.RunModal(Page::"Item List", Item) = Action::LookupOK then begin
                            Rec."Sorted Item No." := Item."No.";
                        end;
                    end;
                }
                field("Sorted Variant Code"; Rec."Sorted Variant Code")
                {
                    ApplicationArea = All;
                    Caption = 'Sorted Variant Code';
                    ToolTip = 'Specifies the value   of the Sorted Variant Code field.', Comment = '%';
                    Editable = Rec."Document Status" <> Rec."Document Status"::Released;
                }
                field("Lot No."; Rec."Lot No.")
                {
                    ApplicationArea = All;
                    Caption = 'Lot No.';
                    ToolTip = 'Specifies the value of the Lot No. field.', Comment = '%';
                    Editable = Rec."Document Status" <> Rec."Document Status"::Released;
                    trigger OnLookup(var Text: Text): Boolean
                    var
                        LotNoInfo: Record "Lot No. Information";
                    begin
                        LotNoInfo.Reset();
                        LotNoInfo.SetRange("Item No.", Rec."Sorted Item No.");
                        LotNoInfo.SetRange("Variant Code", Rec."Sorted Variant Code");
                        LotNoInfo.CalcFields(Inventory);
                        LotNoInfo.SetFilter(Inventory, '> 0');
                        if Page.RunModal(Page::"Lot No. Information List", LotNoInfo) = Action::LookupOK then begin
                            Rec."Lot No." := LotNoInfo."Lot No.";
                        end;
                    end;
                }
            }
            part(SORInspectPkgSubform; "PMP15 SOR Inspect. Pckg. Line")
            {
                ApplicationArea = All;
                Caption = 'Package No. Lists';
                UpdatePropagation = Both;
                SubPageLink = "Document No." = field("No.");
            }
        }
    }
    #endregion LAYOUTS

    #region ACTIONS
    actions
    {
        area(Processing)
        {
            action(GetPackagetoInspect)
            {
                ApplicationArea = All;
                Caption = 'Get Pakcage to Inspect';
                ToolTip = 'Executes the process to retrieve packages that are ready for inspection within the Sortation Inspection Packing Header document.';
                Image = GetBinContent;
                Enabled = Rec."Document Status" <> Rec."Document Status"::Released;
                trigger OnAction()
                begin
                    SortationMgmt.GetPackagetoInspect(Rec);
                end;
            }
            action(Print)
            {
                ApplicationArea = All;
                Caption = 'Print';
                Image = Print;
                ToolTip = 'Prints the Sortation Inspection Packing document or its related inspection report.';
                trigger OnAction()
                begin
                    // 
                end;
            }
            action(Reopen)
            {
                ApplicationArea = All;
                Caption = 'Re: Open';
                Image = ReOpen;
                ToolTip = 'Reopens the Sortation Inspection Packing document to allow modifications after it has been released.';
                Enabled = Rec."Document Status" = Rec."Document Status"::Released;
                trigger OnAction()
                begin
                    SortationMgmt.ReopenSORInspectionPkgDocument(Rec);
                    CurrPage.Update();
                    Message('The Document status is successfully re-opened.');
                end;
            }
            action(Release)
            {
                ApplicationArea = All;
                Caption = 'Release';
                Image = ReleaseDoc;
                ToolTip = 'Releases the Sortation Inspection Packing document, confirming that it is complete and ready for further processing.';
                Enabled = Rec."Document Status" = Rec."Document Status"::Open;
                trigger OnAction()
                begin
                    SortationMgmt.ReleaseSORInspectionPkgDocument(Rec);
                    CurrPage.Update();
                    Message('The Document is successfully released.');
                end;
            }
            action(Process)
            {
                ApplicationArea = All;
                Caption = 'Process';
                Image = Process;
                ToolTip = 'Processes the Sortation Inspection Packing document and executes the defined operations for item inspection and packaging workflow.';
                Enabled = (Rec."Document Status" = Rec."Document Status"::Released) OR (Rec."Document Status" = Rec."Document Status"::"Partially Processed");
                trigger OnAction()
                begin
                    // 
                end;
            }
        }
        area(Promoted)
        {
            actionref(GetPackagetoInspect_Promoted; GetPackagetoInspect) { }
            actionref(Print_Promoted; Print) { }
            actionref(Reopen_Promoted; Reopen) { }
            actionref(Release_Promoted; Release) { }
            actionref(Process_Promoted; Process) { }
        }
    }
    #endregion ACTIONS

    var
        ExtComSetup: Record "PMP07 Extended Company Setup";

    protected var
        PMPAppLogicMgmt: Codeunit "PMP02 App Logic Management";
        SortationMgmt: Codeunit "PMP15 Sortation PO Mgmt";

    trigger OnInit()
    begin
        ExtComSetup.Get();
        PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtComSetup.FieldNo("PMP15 SOR Inspection Pkg. Nos."));
        PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtComSetup.FieldNo("PMP15 Sort-Prod. Order Nos."));
        PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtComSetup.FieldNo("PMP15 SOR Location Code"));
        PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtComSetup.FieldNo("PMP15 SOR Item Owner Internal"));
    end;
}
