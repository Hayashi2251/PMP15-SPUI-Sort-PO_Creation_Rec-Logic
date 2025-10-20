codeunit 60400 "PMP15 Sortation PO Mgmt"
{
    // version PMP15 

    // List Modification
    // Version List       Name
    // ==================================================================================================
    // PMP15              PMP SPUI - Sort-PO Creation & Recording (Logic)

    // Codeunit
    // Date        Developer  Version List  Trigger              Description
    // ==================================================================================================
    // 2025/09/12  SW         PMP15         -                    Create codeunit

    // CODEUNIT FUNCTIONS
    // Date        Dev. Version List  Name                                                Description
    // =================================================================================================================
    // 2025/09/12  SW   PMP15         CodeunitFunctionNameCreatedByDevelopers             DescriptionOfTheCustomizedFunction

    trigger OnRun()
    begin
    end;

    var
        VersionManagement: Codeunit VersionManagement;

    #region SOR CREATION

    [EventSubscriber(ObjectType::Table, Database::"PMP15 Sortation PO Creation", OnAfterValidateEvent, "Sorted Item No.", false, false)]
    local procedure PMP15SortationPOCreation_OnAfterValidateEvent_SortedItemNo(CurrFieldNo: Integer; var Rec: Record "PMP15 Sortation PO Creation"; var xRec: Record "PMP15 Sortation PO Creation")
    var
        ItemRec: Record Item;
    begin
        if ItemRec.Get(Rec."Sorted Item No.") then begin
            Rec."Sorted Item Description" := ItemRec.Description;
            Rec."Unit of Measure Code" := ItemRec."Base Unit of Measure";
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"PMP15 Sortation PO Creation", OnAfterValidateEvent, "Sorted Variant Code", false, false)]
    local procedure PMP15SortationPOCreation_OnAfterValidateEvent_SortedVariantCode(CurrFieldNo: Integer; var Rec: Record "PMP15 Sortation PO Creation"; var xRec: Record "PMP15 Sortation PO Creation")
    var
        ExtCompanySetup: Record "PMP07 Extended Company Setup";
        ItemRec: Record Item;
        ProdItemType: Record "PMP07 Production Item Type";
        ItemVarRec: Record "Item Variant";
        StockkeepingUnit: Record "Stockkeeping Unit";
        ProdBOMHead: Record "Production BOM Header";
        ProdBOMLine: Record "Production BOM Line";
        ItemProdType: Record "PMP07 Production Item Type";
        ActiveVersionCode: Code[20];
    // IsFound: Boolean;
    begin
        ExtCompanySetup.Get();
        ItemVarRec.Reset();
        if Rec."Sorted Variant Code" <> '' then begin
            ItemVarRec.SetRange("Item No.", Rec."Sorted Item No.");
            ItemVarRec.SetRange(Code, Rec."Sorted Variant Code");
            if ItemVarRec.FindFirst() then
                Rec."Sorted Item Description" := ItemVarRec.Description;
        end;
        // =====================================================================================
        StockkeepingUnit.Reset();
        ProdBOMHead.Reset();
        ProdBOMLine.Reset();
        ProdItemType.Reset();
        ItemRec.Reset();
        Clear(ActiveVersionCode);

        StockkeepingUnit.SetRange("Item No.", Rec."Sorted Item No.");
        StockkeepingUnit.SetRange("Variant Code", Rec."Sorted Variant Code");
        if StockkeepingUnit.FindFirst() then begin
            // Get Production BOM Header & Active Version
            if not ProdBOMHead.Get(StockkeepingUnit."Production BOM No.") then
                exit;
            ActiveVersionCode := VersionManagement.GetBOMVersion(ProdBOMHead."No.", WorkDate(), true);
            // Filter BOM Line (type = Item, only)
            ProdBOMLine.SetRange("Production BOM No.", ProdBOMHead."No.");
            ProdBOMLine.SetRange("Version Code", ActiveVersionCode);
            ProdBOMLine.SetRange(Type, Enum::"Production BOM Line Type"::Item);
            // Get The Production Item Type for the unsorted item type.
            ProdItemType.SetRange("Production Item Type", Enum::"PMP09 Production Item Type"::"Sortation-Unsorted");
            if not ProdItemType.FindFirst() then
                exit;

            if ProdBOMLine.FindSet() then
                repeat
                    if ItemRec.Get(ProdBOMLine."No.") then
                        if (ItemRec."PMP04 Item Group" = ProdItemType."Item Group") and
                           (ItemRec."Item Category Code" = ProdItemType."Item Category Code") and
                           (ItemRec."PMP04 Item Class L1" = ProdItemType."Item Class L1") and
                           (ItemRec."PMP04 Item Class L2" = ProdItemType."Item Class L2") and
                           (ItemRec."PMP04 Item Type L1" = ProdItemType."Item Type L1") and
                           (ItemRec."PMP04 Item Type L2" = ProdItemType."Item Type L2") and
                           (ItemRec."PMP04 Item Type L3" = ProdItemType."Item Type L3") then begin

                            Rec."Unsorted Item No." := ProdBOMLine."No.";
                            Rec."Unsorted Variant Code" := ProdBOMLine."Variant Code";
                            Rec."Unsorted Item Description" := ProdBOMLine.Description;
                            exit;
                        end;
                until ProdBOMLine.Next() = 0;
        end;
        // =====================================================================================
        StockkeepingUnit.Reset();
        ProdBOMHead.Reset();
        ProdBOMLine.Reset();
        StockkeepingUnit.SetRange("Item No.", Rec."Unsorted Item No.");
        StockkeepingUnit.SetRange("Variant Code", Rec."Unsorted Variant Code");
        StockkeepingUnit.SetRange("Location Code", ExtCompanySetup."PMP15 SOR Location Code"); // Find by SOR Location Code first
        if not StockkeepingUnit.FindFirst() then begin
            // If not found, try to find first without Extended Company Setup SOR Location Code
            StockkeepingUnit.SetRange("Location Code", '');
            if not StockkeepingUnit.FindFirst() then
                exit; // There is no compatible SKU found, Exit
        end;
        // If found, proceed with the Prod BOM
        if ProdBOMHead.Get(StockkeepingUnit."Production BOM No.") then begin
            ActiveVersionCode := VersionManagement.GetBOMVersion(ProdBOMHead."No.", WorkDate(), true);
            ProdBOMLine.SetRange("Production BOM No.", ProdBOMHead."No.");
            ProdBOMLine.SetRange("Version Code", ActiveVersionCode);
            ProdBOMLine.SetRange(Type, ProdBOMLine.Type::Item);
            if ProdBOMLine.FindFirst() then begin
                Rec."RM Item No." := ProdBOMLine."No.";
                Rec."RM Variant Code" := ProdBOMLine."Variant Code";
                Rec."RM Item Description" := ProdBOMLine.Description;
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"PMP15 Sortation PO Creation", OnAfterValidateEvent, "Unsorted Item No.", false, false)]
    local procedure PMP15SortationPOCreation_OnAfterValidateEvent_UnsortedItemNo(CurrFieldNo: Integer; var Rec: Record "PMP15 Sortation PO Creation"; var xRec: Record "PMP15 Sortation PO Creation")
    var
        ItemRec: Record Item;
    begin
        if ItemRec.Get(Rec."Unsorted Item No.") then
            Rec."Unsorted Item Description" := ItemRec.Description;
    end;

    [EventSubscriber(ObjectType::Table, Database::"PMP15 Sortation PO Creation", OnAfterValidateEvent, "Lot No.", false, false)]
    local procedure PMP15SortationPOCreation_OnAfterValidateEvent_TarreWeight_Kgs_(CurrFieldNo: Integer; var Rec: Record "PMP15 Sortation PO Creation"; var xRec: Record "PMP15 Sortation PO Creation")
    var
        LotNoInfo: Record "Lot No. Information";
    begin
        LotNoInfo.SetRange("Item No.", Rec."Unsorted Item No.");
        LotNoInfo.SetRange("Variant Code", Rec."Unsorted Variant Code");
        LotNoInfo.SetRange("Lot No.", Rec."Lot No.");
        if LotNoInfo.FindFirst() then begin
            Rec."Tarre Weight (Kg)" := LotNoInfo."PMP14 Tarre Weight (Kgs)";
        end;
    end;

    // [EventSubscriber(ObjectType::Table, Database::"PMP15 Sortation PO Creation", OnAfterModifyEvent, '', false, false)]
    // local procedure PMP15SortationPOCreation_OnAfterModifyEvent_LotNo_(var Rec: Record "PMP15 Sortation PO Creation"; var xRec: Record "PMP15 Sortation PO Creation")
    // var
    //     LotNosByBinCode: Query "Lot Numbers by Bin";
    //     BinContent: Record "Bin Content";
    //     ExtCompanySetup: Record "PMP07 Extended Company Setup";
    //     Quantity: Integer;
    // begin
    //     Clear(Quantity);
    //     ExtCompanySetup.Get();
    //     BinContent.SetRange("Location Code", ExtCompanySetup."PMP15 SOR Location Code");
    //     BinContent.SetRange("Bin Code", Rec."Bin Code with 0 SOR Step");
    //     BinContent.SetRange("Item No.", Rec."Unsorted Item No.");
    //     BinContent.SetRange("Variant Code", Rec."Unsorted Variant Code");
    //     if BinContent.FindSet() then
    //         repeat
    //             LotNosByBinCode.SetRange(Item_No, BinContent."Item No.");
    //             LotNosByBinCode.SetRange(Variant_Code, BinContent."Variant Code");
    //             LotNosByBinCode.SetRange(Location_Code, BinContent."Location Code");
    //             LotNosByBinCode.SetFilter(Lot_No, '%1', Rec."Lot No.");
    //             LotNosByBinCode.Open();
    //             while LotNosByBinCode.Read() do begin
    //                 Quantity += LotNosByBinCode.Sum_Qty_Base;
    //             end;
    //         until BinContent.Next() = 0;
    //     Rec.Quantity := Quantity;
    // end;



    #endregion SOR CREATION




    #region SOR RECORDING

    procedure GetBinTypeBySortationStep(Step: Enum "PMP15 Sortation Step Enum"): Enum "PMP15 Bin Step-Type"
    var
        BinType: Enum "PMP15 Bin Step-Type";
    begin
        case Step of
            Step::"0":
                exit(BinType::"0");
            Step::"1":
                exit(BinType::"1");
            Step::"2":
                exit(BinType::"2");
            Step::"3":
                exit(BinType::"3");
            Step::"4":
                exit(BinType::"4");
            else
                Error('Unsupported Sortation Step %1', Format(Step));
        end;
    end;


    [EventSubscriber(ObjectType::Table, Database::"PMP15 Sortation PO Recording", OnAfterValidateEvent, "Sortation Prod. Order No.", false, false)]
    local procedure PMP15FillValOnLookup_OnAfterValidateEvent_SortationProdOrderNo(var Rec: Record "PMP15 Sortation PO Recording"; var xRec: Record "PMP15 Sortation PO Recording"; CurrFieldNo: Integer)
    var
        ProdOrder: Record "Production Order";
        ProdOrderLine: Record "Prod. Order Line";
        ProdOrderComp: Record "Prod. Order Component";
        ItemVariant: Record "Item Variant";
    begin
        ProdOrder.Reset();
        ProdOrderLine.Reset();
        ProdOrderComp.Reset();
        ItemVariant.Reset();

        ProdOrder.SetRange("No.", Rec."Sortation Prod. Order No.");
        if ProdOrder.FindFirst() then begin
            Rec."RM Item No." := ProdOrder."PMP15 RM Item No.";
            Rec."RM Variant Code" := ProdOrder."PMP15 RM Variant Code";
            Rec."Lot No." := ProdOrder."PMP15 Lot No.";
        end;

        ProdOrderLine.SetRange("Prod. Order No.", Rec."Sortation Prod. Order No.");
        if ProdOrderLine.FindFirst() then begin
            Rec."Sorted Item No." := ProdOrderLine."Item No.";
            Rec."Sorted Variant Code" := ProdOrderLine."Variant Code";
            ItemVariant.SetRange(Code, Rec."Sorted Variant Code");
            if ItemVariant.FindFirst() then begin
                Rec."Submerk 1" := ItemVariant."PMP15 Sub Merk 1";
            end;
        end;

        ProdOrderComp.SetRange("Prod. Order No.", Rec."Sortation Prod. Order No.");
        if ProdOrderComp.FindFirst() then begin
            Rec."Unsorted Item No." := ProdOrderComp."Item No.";
            Rec."Unsorted Variant Code" := ProdOrderComp."Variant Code";
            Rec."Location Code" := ProdOrderComp."Location Code";
        end;
    end;

    // [EventSubscriber(ObjectType::Table, Database::"PMP15 Sortation PO Recording", OnAfterValidateEvent, "Lot No.", false, false)]
    // local procedure PMP15AutoFillOnValidate_OnAfterValidateEvent_LotNo(var Rec: Record "PMP15 Sortation PO Recording"; var xRec: Record "PMP15 Sortation PO Recording"; CurrFieldNo: Integer)
    // var
    //     ProdOrder: Record "Production Order";
    // begin
    //     ProdOrder.SetRange("No.", Rec."Sortation Prod. Order No.");
    //     if ProdOrder.FindFirst() then begin
    //         Rec."Lot No." := ProdOrder."PMP15 Lot No.";
    //     end;
    // end;

    #endregion SOR RECORDING
}
