page 60412 "PMP15 Sort-Prod.Order. Subform"
{
    // *** ASK THIS REQUIREMENT, REF: New Page: Sortation Prod. Order, XLSX No. 323-325
    // INI MASIH BELUM SELESAI KARENA TIDAK MEMAHAMI FDD, 
    ApplicationArea = All;
    Caption = 'Sortation Production Order Subform';
    PageType = ListPart;
    SourceTable = "Prod. Order Component";

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    Caption = 'Unsorted Item No.';
                    ToolTip = 'Specifies the number of the item that is a component in the production order component list.';
                    Editable = false;
                }
                field("Variant Code"; Rec."Variant Code")
                {
                    ApplicationArea = All;
                    Caption = 'Unsorted Variant Code';
                    ToolTip = 'Specifies the variant of the item on the line.';
                    Editable = false;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Caption = 'Unsorted item Description';
                    ToolTip = 'Specifies a description of the item on the line.';
                    Editable = false;
                }
            }
        }
    }
}
