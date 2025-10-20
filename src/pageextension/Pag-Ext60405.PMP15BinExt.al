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
                begin
                    if Rec.CountSORSteps() > 0 then begin
                        Clear(Rec."PMP15 Bin Type");
                        Error('Bin Step-Types already exist for this Bin.');
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
