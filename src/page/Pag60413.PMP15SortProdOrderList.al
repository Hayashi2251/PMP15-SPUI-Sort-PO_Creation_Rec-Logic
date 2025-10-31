page 60413 "PMP15 Sort-Prod.Order List"
{
    ApplicationArea = All;
    Caption = 'Sortation Production Order List';
    PageType = List;
    SourceTable = "Production Order";
    // CardPageId = "PMP15 Sortation PO Creation";
    // InsertAllowed = false;
    UsageCategory = Lists;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    Caption = 'No.';
                    ToolTip = 'Specifies the value of the No. field.';
                    trigger OnDrillDown()
                    var
                        SORProdOrderPage: Page "PMP15 Sortation Prod. Order";
                    // SORProdOrderPage: Page "PMP15 Sortation PO Creation";
                    begin
                        // SORProdOrderPage.SetProdOrder(Rec);
                        // SORProdOrderPage.SetRecfromProdOrder(Rec);
                        // =================================
                        SORProdOrderPage.SetRecord(Rec);
                        SORProdOrderPage.Run();
                    end;
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    Caption = 'Status';
                    ToolTip = 'Specifies the value of the Status field.';
                }
                field("Source No."; Rec."Source No.")
                {
                    ApplicationArea = All;
                    Caption = 'Sorted Item No.';
                    ToolTip = 'Specifies the value of the Sorted Item No. field.';
                }
                field("Variant Code"; Rec."Variant Code")
                {
                    ApplicationArea = All;
                    Caption = 'Sorted Variant Code';
                    ToolTip = 'Specifies the value of the Sorted Variant Code field.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Caption = 'Sorted Item Description';
                    ToolTip = 'Specifies the value of the Sorted Item Description field.';
                }
                field("PMP15 SOR Rework"; Rec."PMP15 SOR Rework")
                {
                    ApplicationArea = All;
                    Caption = 'Rework';
                    ToolTip = 'Specifies the value of the Rework field.';
                }
                field("PMP15 Lot No."; Rec."PMP15 Lot No.")
                {
                    ApplicationArea = All;
                    Caption = 'Lot No.';
                    ToolTip = 'Specifies the value of the Lot No. field.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    Caption = 'Quantity';
                    ToolTip = 'Specifies the value of the Quantity field.';
                }
                field(UoMCode; UoMCode)
                {
                    ApplicationArea = All;
                    Caption = 'Unit of Measure Code';
                    ToolTip = 'Specifies the value of the Unit of Measure Code field.';
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(SortPODeletion)
            {
                ApplicationArea = All;
                Caption = 'Delete';
                Image = "Invoicing-Delete";
                trigger OnAction()
                begin
                    Rec.Delete();
                end;
            }
            action(SortPOCreation)
            {
                ApplicationArea = All;
                Caption = 'Sort Prod Order Creation';
                Image = Document;
                trigger OnAction()
                begin
                    Page.Run(Page::"PMP15 Sortation PO Creation");
                end;
            }
            action(SortPORecording)
            {
                ApplicationArea = All;
                Caption = 'Sort Prod Order Recording';
                Image = CreateDocument;
                trigger OnAction()
                var
                    SORProdOrderRecordingPage: Page "PMP15 Sort-Prod.Ord Recording";
                begin
                    SORProdOrderRecordingPage.SetProdOrder(Rec);
                    // SORProdOrderRecordingPage.SetRecord(tempSORProdOrdRecord);
                    SORProdOrderRecordingPage.Run();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(SortPODeletion_Promoted; SortPODeletion) { }
                actionref(SortPOCreation_Promoted; SortPOCreation) { }
                actionref(SortPORecording_Promoted; SortPORecording) { }
            }
        }
    }
    var
        UoMCode: Code[10];
        ProdOrderLine: Record "Prod. Order Line";
        // tempSORProdOrdRecord: Record "PMP15 Sortation PO Recording" temporary;

    trigger OnOpenPage()
    var
        ExtCompanySetup: Record "PMP07 Extended Company Setup";
    begin
        ExtCompanySetup.Get();
        Rec.FilterGroup(2);
        Rec.SetRange("PMP04 Item Owner Internal", ExtCompanySetup."PMP15 SOR Item Owner Internal");
        Rec.SetRange("PMP15 Production Unit", Rec."PMP15 Production Unit"::"SOR-Sortation");
        Rec.FilterGroup(0);
    end;

    trigger OnAfterGetRecord()
    begin
        Clear(UoMCode);
        ProdOrderLine.Reset();
        ProdOrderLine.SetRange("Prod. Order No.", Rec."No.");
        ProdOrderLine.SetFilter("Item No.", '<>%1', '');
        if ProdOrderLine.FindFirst() then begin
            UoMCode := ProdOrderLine."Unit of Measure Code";
        end;
    end;
}
