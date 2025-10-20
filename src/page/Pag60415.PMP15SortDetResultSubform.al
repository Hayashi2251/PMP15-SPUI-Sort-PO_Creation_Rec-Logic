page 60415 "PMP15 Sort-Det. Result Subform"
{
    ApplicationArea = All;
    Caption = 'Sortation Detail Result';
    PageType = ListPart;
    SourceTable = "PMP15 Sortation Detail Quality";

    layout
    {
        area(Content)
        {
            repeater(Control1)
            {
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Item No. field.', Comment = '%';
                    Editable = false;
                }
                field("Variant Code"; Rec."Variant Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Variant Code field.', Comment = '%';
                    Editable = false;
                }
                field("Package No."; Rec."Package No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Package No. field.', Comment = '%';
                    Editable = false;
                }
                field("Lot No."; Rec."Lot No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Lot No. field.', Comment = '%';
                    Editable = false;
                }
                field("Sub Merk 1"; Rec."Sub Merk 1")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Sub Merk 1 field.', Comment = '%';
                    Editable = false;
                }
                field("Sub Merk 2"; Rec."Sub Merk 2")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Sub Merk 2 field.', Comment = '%';
                    Editable = false;
                }
                field("Sub Merk 3"; Rec."Sub Merk 3")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Sub Merk 3 field.', Comment = '%';
                    Editable = false;
                }
                field("Sub Merk 4"; Rec."Sub Merk 4")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Sub Merk 4 field.', Comment = '%';
                    Editable = false;
                }
                field("Sub Merk 5"; Rec."Sub Merk 5")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Sub Merk 5 field.', Comment = '%';
                    Editable = false;
                }
                field("L/R"; Rec."L/R")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the L/R field.', Comment = '%';
                    Editable = false;
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Quantity field.', Comment = '%';
                    Editable = false;
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Unit of Measure Code field.', Comment = '%';
                    Editable = false;
                }
                field(Rework; Rec.Rework)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Rework field.', Comment = '%';
                    Editable = false;
                }
            }
        }
    }
}
