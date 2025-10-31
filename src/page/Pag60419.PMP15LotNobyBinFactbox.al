page 60419 "PMP15 Lot No by Bin Factbox"
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
    Caption = 'Lot No by Bin Factbox';
    // PageType = ListPart;
    PageType = List;
    SourceTable = "Lot Bin Buffer";
    SourceTableTemporary = true;
    Editable = false;
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Bin Code"; Rec."Bin Code")
                {
                    ApplicationArea = All;
                    Caption = 'Bin Code';
                    ToolTip = 'Specifies the bin where the lot number exists.';
                }
                field("Lot No."; Rec."Lot No.")
                {
                    ApplicationArea = All;
                    Caption = 'Lot No.';
                    ToolTip = 'Specifies the lot number that exists in the bin.';
                }
                field("Qty. (Base)"; Rec."Qty. (Base)")
                {
                    ApplicationArea = All;
                    Caption = 'Qty (Base)';
                    ToolTip = 'Specifies how many items with the lot number exist in the bin.';
                }
            }
        }
    }

    /// <summary>Copies records from a temporary Lot Bin Buffer into the current record instance.</summary>
    /// <remarks>Iterates through all entries in the provided temporary record and inserts them into the main record.</remarks>
    /// <param name="tempRec">Temporary Lot Bin Buffer record to be copied into the current buffer.</param>
    procedure SetRecord(var tempRec: Record "Lot Bin Buffer" temporary)
    begin
        if tempRec.FindSet() then
            repeat
                Rec.Copy(tempRec);
                Rec.Insert();
            until tempRec.Next() = 0;
    end;

    /// <summary>Fills the temporary Lot Bin Buffer with lot and bin data for a specific item, variant, and location.</summary>
    /// <remarks>Retrieves lot information using the "Lot Numbers by Bin" query, aggregates quantities, and populates the temporary buffer for lookup display or processing.</remarks>
    /// <param name="ItemNo">Specifies the item number to retrieve lot and bin data for.</param>
    /// <param name="VariantCode">Specifies the item variant code to filter results.</param>
    /// <param name="LocationCode">Specifies the location code to narrow down the lot and bin search scope.</param>
    procedure FillTempTable(ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10])
    var
        LotNosByBinCode: Query "Lot Numbers by Bin";
        IsHandled: Boolean;
    begin
        IsHandled := false;
        OnBeforeFillTempTable(Rec, IsHandled);
        if IsHandled then
            exit;

        LotNosByBinCode.SetRange(Item_No, Rec.GetRangeMin("Item No."));
        LotNosByBinCode.SetRange(Variant_Code, Rec.GetRangeMin("Variant Code"));
        LotNosByBinCode.SetRange(Location_Code, Rec.GetRangeMin("Location Code"));
        LotNosByBinCode.SetFilter(Lot_No, '<>%1', '');
        OnFillTempTableOnAfterLotNosByBinCodeSetFilters(LotNosByBinCode);
        LotNosByBinCode.Open();

        Rec.DeleteAll();

        while LotNosByBinCode.Read() do begin
            Rec.Init();
            Rec."Item No." := LotNosByBinCode.Item_No;
            Rec."Variant Code" := LotNosByBinCode.Variant_Code;
            Rec."Zone Code" := LotNosByBinCode.Zone_Code;
            Rec."Bin Code" := LotNosByBinCode.Bin_Code;
            Rec."Location Code" := LotNosByBinCode.Location_Code;
            Rec."Lot No." := LotNosByBinCode.Lot_No;
            OnFillTempTableOnAfterPopulateLotNosByBinCodeFields(Rec, LotNosByBinCode);
            if Rec.Find() then begin
                Rec."Qty. (Base)" += LotNosByBinCode.Sum_Qty_Base;
                Rec.Modify();
            end else begin
                Rec."Qty. (Base)" := LotNosByBinCode.Sum_Qty_Base;
                Rec.Insert();
            end;
        end;
    end;

    [IntegrationEvent(false, false)]
    local procedure OnFillTempTableOnAfterLotNosByBinCodeSetFilters(var LotNosByBinCode: Query "Lot Numbers by Bin")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnFillTempTableOnAfterPopulateLotNosByBinCodeFields(var LotBinBuffer: record "Lot Bin Buffer"; var LotNosByBinCode: query "Lot Numbers by Bin")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeFillTempTable(var LotBinBuffer: Record "Lot Bin Buffer"; var IsHandled: Boolean)
    begin
    end;
}
