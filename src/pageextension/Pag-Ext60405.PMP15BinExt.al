pageextension 60405 "PMP15 Bin Ext" extends Bins
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
    // 2025/09/12  SW         PMP15                                     Create Page Extension
    // 

    #region Layout
    layout
    {
        addlast(Control1)
        {
            field("PMP15 Bin Type"; Rec."PMP15 Bin Type")
            {
                ApplicationArea = All;
                Caption = 'Bin Type';
                trigger OnValidate()
                var
                    BinRec: Record Bin;
                begin
                    if (Rec.CountSORSteps() > 0) AND (Rec."PMP15 Bin Type" <> Rec."PMP15 Bin Type"::" ") then begin
                        Clear(Rec."PMP15 Bin Type");
                        BinRec.SetRange("PMP15 Bin Type", Rec."PMP15 Bin Type");
                        if BinRec.FindFirst() then;
                        Error('Bin Step-Types %1 already exist for this Bin, as in the Bin.%2 in %3 Location.', Rec."PMP15 Bin Type", BinRec.Code, BinRec."Location Code");
                    end;
                end;
            }
            field("PMP15 Previous Bin"; Rec."PMP15 Previous Bin")
            {
                ApplicationArea = All;
                Caption = 'Previous Bin';
            }
        }
    }
    #endregion Layout

    #region Actions
    actions { }
    #endregion Actions
}
