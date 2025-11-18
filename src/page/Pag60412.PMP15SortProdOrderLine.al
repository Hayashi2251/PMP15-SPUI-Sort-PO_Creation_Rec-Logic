page 60412 "PMP15 Sort-Prod. Order Subform"
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
    // 2025/09/12  SW         PMP15                                     Create Page
    // 
    ApplicationArea = All;
    Caption = 'Sortation Prod. Order Lines';
    PageType = ListPart;
    DeleteAllowed = true;
    LinksAllowed = true;
    InsertAllowed = false;
    ModifyAllowed = false;
    SourceTable = "Prod. Order Line";

    layout
    {
        area(Content)
        {
            repeater(Control1)
            {
                field("Line No."; Rec."Line No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Line No. field.', Comment = '%';
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of the item that is to be produced.';
                }
                field("Variant Code"; Rec."Variant Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the variant of the item on the line.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Description field on the item card. If you enter a variant code, the variant description is copied to this field instead.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the location code, if the produced items should be stored in a specific location.';
                }
                field("Bin Code"; Rec."Bin Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the bin that the produced item is posted to as output, and from where it can be taken to storage or cross-docked.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quantity to be produced if you manually fill in this line.';
                }
                field("Finished Quantity"; Rec."Finished Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how much of the quantity on this line has been produced.';
                }
                field("Remaining Quantity"; Rec."Remaining Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the difference between the finished and planned quantities, or zero if the finished quantity is greater than the remaining quantity.';
                }
                field("Scrap %"; Rec."Scrap %")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the percentage of the item that you expect to be scrapped in the production process.';
                }
                field("Production BOM No."; Rec."Production BOM No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of the production BOM that is the basis for creating the Prod. Order Component list for this line.';
                }
                field("Routing No."; Rec."Routing No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of the routing used as the basis for creating the production order routing for this line.';
                }
                field("Dimension Set ID"; Rec."Dimension Set ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Dimension Set ID field.', Comment = '%';
                }
                field("Shortcut Dimension 1 Code"; Rec."Shortcut Dimension 1 Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the code for Shortcut Dimension 1, which is one of two global dimension codes that you set up in the General Ledger Setup window.';
                }
                field("Shortcut Dimension 2 Code"; Rec."Shortcut Dimension 2 Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the code for Shortcut Dimension 2, which is one of two global dimension codes that you set up in the General Ledger Setup window.';
                }
                field("Starting Date"; Rec."Starting Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Starting Date field.', Comment = '%';
                }
                field("Starting Time"; Rec."Starting Time")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Starting Time field.', Comment = '%';
                }
                field("Ending Date"; Rec."Ending Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Ending Date field.', Comment = '%';
                }
                field("Ending Time"; Rec."Ending Time")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Ending Time field.', Comment = '%';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a value that is copied from the corresponding field on the production order header.';
                    Visible = false;
                }
            }
        }
    }

    trigger OnDeleteRecord(): Boolean
    var
        ProdOrderLineReserve: Codeunit "Prod. Order Line-Reserve";
    begin
        Commit();
        if not ProdOrderLineReserve.DeleteLineConfirm(Rec) then
            exit(false);
    end;
}
