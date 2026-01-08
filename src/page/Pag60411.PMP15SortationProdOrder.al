page 60411 "PMP15 Sortation Prod. Order"
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
    Caption = 'Sortation Prod. Order';
    PageType = Document;
    RefreshOnActivate = true;
    SourceTable = "Production Order";

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
                    Caption = 'No.';
                    ToolTip = 'Specifies the value of the No. field.';
                    Editable = false;
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    Caption = 'Status';
                    ToolTip = 'Specifies the value of the Status field.';
                    Style = Strong;
                    Editable = false;
                }
                field("Sorted Item No."; Rec."Source No.")
                {
                    ApplicationArea = All;
                    Caption = 'Sorted Item No.';
                    ToolTip = 'Specifies the value of the Sorted Item No. field.';
                    Editable = false;
                }
                field("Sorted Variant Code"; Rec."Variant Code")
                {
                    ApplicationArea = All;
                    Caption = 'Sorted Variant Code';
                    ToolTip = 'Specifies the value of the Sorted Variant Code field.';
                    Editable = false;
                }
                field(Rework; Rec."PMP15 SOR Rework")
                {
                    ApplicationArea = All;
                    Caption = 'Rework';
                    ToolTip = 'Specifies the value of the Rework field.';
                    Editable = false;
                }
                field("Sorted Item Description"; Rec.Description)
                {
                    ApplicationArea = All;
                    Caption = 'Sorted Item Description';
                    ToolTip = 'Specifies the value of the Sorted Item Description field.';
                    Editable = false;
                }
                field(UnSORItemNo; UnSORItemNo)
                {
                    ApplicationArea = All;
                    Caption = 'Unsorted Item No.';
                    ToolTip = 'Specifies the value of the Unsorted Item No. field.';
                    Editable = false;
                }
                field(UnSORVariantCode; UnSORVariantCode)
                {
                    ApplicationArea = All;
                    Caption = 'Unsorted Variant Code';
                    ToolTip = 'Specifies the value of the Unsorted Variant Code field.';
                    Editable = false;
                }
                field(UnSORItemDesc; UnSORItemDesc)
                {
                    ApplicationArea = All;
                    Caption = 'Unsorted Item Description';
                    ToolTip = 'Specifies the value of the Unsorted Item Description field.';
                    Editable = false;
                }
                field("PMP15 RM Item No."; Rec."PMP15 RM Item No.")
                {
                    ApplicationArea = All;
                    Caption = 'RM Item No.';
                    ToolTip = 'Specifies the value of the RM Item No. field.';
                    Editable = false;
                }
                field("PMP15 RM Variant Code"; Rec."PMP15 RM Variant Code")
                {
                    ApplicationArea = All;
                    Caption = 'RM Variant Code';
                    ToolTip = 'Specifies the value of the RM Variant Code field.';
                    Editable = false;
                }
                field("PMP15 RM Item Description"; Rec."PMP15 RM Item Description")
                {
                    ApplicationArea = All;
                    Caption = 'RM Item Description';
                    ToolTip = 'Specifies the value of the RM Item Description field.';
                    Editable = false;
                }
                field("Lot No."; Rec."PMP15 Lot No.")
                {
                    ApplicationArea = All;
                    Caption = 'Lot No.';
                    ToolTip = 'Specifies the value of the Lot No. field.';
                    Editable = false;
                }
                //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/06 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                field("Tarre Weight"; Rec."PMP15 Tarre Weight (Kg)")
                {
                    ApplicationArea = All;
                    Caption = 'Tarre Weight';
                    ToolTip = 'Specifies the value of the Tarre Weight field.';
                    // Editable = false;
                }
                field("PMP15 Allowance Packing Weight"; Rec."PMP15 Allowance Packing Weight")
                {
                    ApplicationArea = All;
                    Caption = 'Allowance Packing Weight';
                    ToolTip = 'Specifies the value of the Allowance Packing Weight field.';
                    // Editable = false;
                }
                //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/06 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    Caption = 'Quantity';
                    ToolTip = 'Specifies the value of the Rework field.';
                    Editable = false;
                }
                field(UoMCode; UoMCode)
                {
                    ApplicationArea = All;
                    Caption = 'Unit of Measure Code';
                    ToolTip = 'Specifies the value of the Unit of Measure Code field.';
                    Editable = false;
                }
            }
            part(ProdOrderLines; "PMP15 Sort-Prod. Order Subform")
            {
                ApplicationArea = All;
                SubPageLink = "Prod. Order No." = field("No.");
                UpdatePropagation = Both;
                Visible = false;
            }
            // part(UnsortedItemLine; "PMP15 Sort-Prod.Order. Subform")
            // {
            //     ApplicationArea = All;
            //     SubPageLink = "Prod. Order No." = field("No."), "PMP15 Unsorted Item" = const(true);
            // }
        }
        area(factboxes)
        {
            systempart(Control1900383207; Links)
            {
                ApplicationArea = RecordLinks;
                Visible = false;
            }
            systempart(Control1905767507; Notes)
            {
                ApplicationArea = Notes;
                Visible = true;
            }
            part("Attached Documents List"; "Doc. Attachment List Factbox")
            {
                ApplicationArea = Manufacturing;
                Caption = 'Documents';
                UpdatePropagation = Both;
                SubPageLink = "Table ID" = const(Database::"Production Order"),
                              "No." = field("No.");
            }
        }
    }

    actions
    {
        area(Processing)
        {
            group("Set Status")
            {
                Caption = 'Status';
                Image = Status;
                action(Release)
                {
                    ApplicationArea = All;
                    Caption = 'Release';
                    Image = ReleaseDoc;
                    trigger OnAction()
                    begin
                        CurrPage.Update();
                        Status := SortProdOrdMgmt.SortChangeProdOrderStatus(Rec, NewStatus::Released, WorkDate(), true);
                        Message('The Production Order status has been successfully changed.');
                    end;
                }
                action(Complete)
                {
                    ApplicationArea = All;
                    Caption = 'Complete';
                    Image = Completed;
                    trigger OnAction()
                    begin
                        SortProdOrdMgmt.SortProdOrdCreationCompleted(Rec, InvDocHeader);
                    end;
                }
            }
            action("Inventory Shipment")
            {
                ApplicationArea = All;
                Caption = 'Inventory Shipment';
                Image = Inventory;
                Visible = InvtShip_Visibility;
                trigger OnAction()
                begin
                    InvDocHeader.SetRange("PMP15 Production Order No.", Rec."No.");
                    if InvDocHeader.FindFirst() then begin
                        InvShipmentPageDoc.SetRecord(InvDocHeader);
                        InvShipmentPageDoc.Run();
                    end;
                end;
            }
            action("Posted Inventory Shipment")
            {
                ApplicationArea = All;
                Caption = 'Posted Inventory Shipment';
                Image = PostedInventoryPick;
                Visible = PostedInvtShip_Visibility;
                trigger OnAction()
                begin
                    InvShipHeader.SetRange("PMP15 Production Order No.", Rec."No.");
                    if InvShipHeader.FindFirst() then begin
                        PstdInvShipPageDoc.SetRecord(InvShipHeader);
                        PstdInvShipPageDoc.Run();
                    end;
                end;
            }
            action("Change Status")
            {
                ApplicationArea = All;
                Caption = 'Change Status';
                Image = ChangeStatus;
                trigger OnAction()
                begin
                    CurrPage.Update();
                    CODEUNIT.Run(CODEUNIT::"Prod. Order Status Management", Rec);
                end;
            }
            action("Job Card")
            {
                ApplicationArea = All;
                Caption = 'Job Card';
                Image = Job;
                trigger OnAction()
                begin
                    ManuPrintReport.PrintProductionOrder(Rec, 0);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                group(Sortation_Status)
                {
                    Caption = 'Sortation Status';
                    ShowAs = SplitButton;
                    actionref(Release_Promoted; Release) { }
                    actionref(Complete_Promoted; Complete) { }
                }
                group(Category_Category5)
                {
                    Caption = 'Inventory Shipment';
                    actionref(InventoryShipment_Promoted; "Inventory Shipment") { }
                    actionref(PostedInventoryShipment_Promoted; "Posted Inventory Shipment") { }
                }
                actionref(ChangeStatus_Promoted; "Change Status") { }
                actionref(JobCard_Promoted; "Job Card") { }
            }
        }
    }

    var
        SortProdOrdMgmt: Codeunit "PMP15 Sortation PO Mgmt";
        ProdOrderStatusMgmt: Codeunit "Prod. Order Status Management";
        ManuPrintReport: Codeunit "Manu. Print Report";
        ProdOrdComp: Record "Prod. Order Component";
        ProdOrdLine: Record "Prod. Order Line";
        InvDocHeader: Record "Invt. Document Header";
        InvShipHeader: Record "Invt. Shipment Header"; // Posted Invt. Shipment
        InvShipmentPageDoc: Page "Invt. Shipment";
        PstdInvShipPageDoc: Page "Posted Invt. Shipment";
        UnSORItemNo: Code[20];
        UnSORItemDesc: Text;
        UoMCode, UnSORVariantCode : Code[10];
        Status, NewStatus : Enum "Production Order Status";
        NewPostingDate: Date;
        NewUpdateUnitCost, InvtShip_Visibility, PostedInvtShip_Visibility : Boolean;

    trigger OnAfterGetCurrRecord()
    begin
        InvDocHeader.SetRange("PMP15 Production Order No.", Rec."No.");
        InvtShip_Visibility := InvDocHeader.FindFirst();
        InvShipHeader.SetRange("PMP15 Production Order No.", Rec."No.");
        PostedInvtShip_Visibility := InvShipHeader.FindFirst();

        ProdOrdComp.Reset();
        ProdOrdComp.SetRange("Prod. Order No.", Rec."No.");
        ProdOrdComp.SetRange("PMP15 Unsorted Item", true);
        if ProdOrdComp.FindFirst() then begin
            UnSORItemNo := ProdOrdComp."Item No.";
            UnSORItemDesc := ProdOrdComp.Description;
            UnSORVariantCode := ProdOrdComp."Variant Code";
        end;

        ProdOrdLine.Reset();
        ProdOrdLine.SetRange("Prod. Order No.", Rec."No.");
        if ProdOrdLine.FindFirst() then begin
            UoMCode := ProdOrdLine."Unit of Measure Code";
        end;
    end;
}
