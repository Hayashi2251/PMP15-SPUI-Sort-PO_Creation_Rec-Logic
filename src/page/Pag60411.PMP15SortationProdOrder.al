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
    PageType = Card;
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
                field("Tarre Weight"; Rec."PMP15 Tarre Weight (Kg)")
                {
                    ApplicationArea = All;
                    Caption = 'Tarre Weight';
                    ToolTip = 'Specifies the value of the Tarre Weight field.';
                    Editable = false;
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    Caption = 'Rework';
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
            // part(UnsortedItemLine; "PMP15 Sort-Prod.Order. Subform")
            // {
            //     ApplicationArea = All;
            //     SubPageLink = "Prod. Order No." = field("No."), "PMP15 Unsorted Item" = const(true);
            // }
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
                        // 
                    end;
                }
                action(Complete)
                {
                    ApplicationArea = All;
                    Caption = 'Complete';
                    Image = Completed;
                    trigger OnAction()
                    begin
                        // 
                    end;
                }
            }
            action("Inventory Shipment")
            {
                ApplicationArea = All;
                Caption = 'Inventory Shipment';
                Image = Inventory;
                trigger OnAction()
                begin
                    // 
                end;
            }
            action("Change Status")
            {
                ApplicationArea = All;
                Caption = 'Change Status';
                Image = ChangeStatus;
                trigger OnAction()
                begin
                    // 
                end;
            }
            action("Job Card")
            {
                ApplicationArea = All;
                Caption = 'Job Card';
                Image = Job;
                trigger OnAction()
                begin
                    // 
                end;
            }
        }
    }

    var
        ProdOrdComp: Record "Prod. Order Component";
        ProdOrdLine: Record "Prod. Order Line";
        UnSORItemNo: Code[20];
        UnSORVariantCode: Code[10];
        UnSORItemDesc: Text;
        UoMCode: Code[10];

    trigger OnAfterGetCurrRecord()
    begin
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
