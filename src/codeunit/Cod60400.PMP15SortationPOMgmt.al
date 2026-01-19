codeunit 60400 "PMP15 Sortation PO Mgmt"
{
    Permissions =
        tabledata "Assembly Header" = RIMD,
        tabledata "Assembly Line" = RIMD;
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
        NoSeriesMgmt: Codeunit "No. Series";
        NoSeriesBatchMgmt: Codeunit "No. Series - Batch";
        AssemblyHeaderReserve: Codeunit "Assembly Header-Reserve";
        AssemblyLineReserve: Codeunit "Assembly Line-Reserve";
        ItemTrackingDataCollection: Codeunit "Item Tracking Data Collection";
        ItemJnlLineReserve: Codeunit "Item Jnl. Line-Reserve";
        PkgNoInfoMgmt: Codeunit "Package Info. Management";
        PMPAppLogicMgmt: Codeunit "PMP02 App Logic Management";
        // 
        ConfirmationPage: Page "PMP02 Confirmation Page";
        // 
        TempGlobalReservEntry: Record "Reservation Entry" temporary;
        TempGlobalEntrySummary: Record "Entry Summary" temporary;
        ExtCompanySetup: Record "PMP07 Extended Company Setup";
        ItemTrackingCode: Record "Item Tracking Code";
        RecItem: Record Item;
        Location: Record Location;
        CurrItemTrackingCode: Record "Item Tracking Code";
        // 
        LastReservEntryNo, LastSummaryEntryNo, LastTrackingSpecEntryNo : Integer;
        CurrBinCode: Code[20];
        FullGlobalDataSetExists: Boolean;
        SkipLot: Boolean;
        DirectTransfer: Boolean;
        HideValidationDialog: Boolean;
        // PartialGlobalDataSetExists: Boolean;
        PreviewModeErr: Label 'Preview mode.';



    #region SOR CREATION
    /// <summary> Updates the "Sorted Item Description" and "Unit of Measure Code" fields after validating the "Sorted Item No." by retrieving data from the Item table. </summary>
    [EventSubscriber(ObjectType::Table, Database::"PMP15 Sortation PO Creation", OnAfterValidateEvent, "Sorted Item No.", false, false)]
    local procedure PMP15SortationPOCreation_OnAfterValidateEvent_SortedItemNo(CurrFieldNo: Integer; var Rec: Record "PMP15 Sortation PO Creation"; var xRec: Record "PMP15 Sortation PO Creation")
    var
        ItemRec: Record Item;
    begin
        Clear(Rec."Sorted Item Description");
        Clear(Rec."Unit of Measure Code");
        Rec.Validate("Sorted Variant Code", '');
        Rec.Validate("Lot No.", '');
        if ItemRec.Get(Rec."Sorted Item No.") then begin
            Rec."Sorted Item Description" := ItemRec.Description;
            Rec."Unit of Measure Code" := ItemRec."Base Unit of Measure";
            Rec."PMP15 Allowance Packing Weight" := ItemRec."PMP15 Allowance Packing Weight";
        end;
    end;

    /// <summary> Updates related item, variant, and BOM-linked fields after validating the "Sorted Variant Code" by retrieving corresponding unsorted and raw material item data from SKU and production BOM structures. </summary>
    [EventSubscriber(ObjectType::Table, Database::"PMP15 Sortation PO Creation", OnAfterValidateEvent, "Sorted Variant Code", false, false)]
    local procedure PMP15SortationPOCreation_OnAfterValidateEvent_SortedVariantCode(CurrFieldNo: Integer; var Rec: Record "PMP15 Sortation PO Creation"; var xRec: Record "PMP15 Sortation PO Creation")
    var
        ProdBOMLineItemTypeQuery: Query "PMP15 ProdBOMLineItemTypeQuery";
        ExtCompanySetup: Record "PMP07 Extended Company Setup";
        ItemRec: Record Item;
        ProdItemType: Record "PMP07 Production Item Type";
        ItemVarRec: Record "Item Variant";
        StockkeepingUnit: Record "Stockkeeping Unit";
        ProdBOMHead: Record "Production BOM Header";
        ProdBOMLine: Record "Production BOM Line";
        ItemProdType: Record "PMP07 Production Item Type";
        ActiveVersionCode: Code[20];
        IsFound: Boolean;
    begin
        ExtCompanySetup.Get();
        ItemVarRec.Reset();
        // // Fill Sorted Item Description with Description on Item Variant.
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
        Clear(Rec."Unsorted Item No.");
        Clear(Rec."Unsorted Variant Code");
        Clear(Rec."Unsorted Item Description");
        Clear(Rec."RM Item No.");
        Clear(Rec."RM Variant Code");
        Clear(Rec."RM Item Description");
        // - Stockkeeping Unit with filter: Item No. = Sorted Item No. && Variant Code = Sorted Variant Code
        StockkeepingUnit.SetRange("Item No.", Rec."Sorted Item No.");
        StockkeepingUnit.SetRange("Variant Code", Rec."Sorted Variant Code");
        StockkeepingUnit.SetFilter("Production BOM No.", '<>%1', '');
        if StockkeepingUnit.FindFirst() then begin
            // Get Production BOM Header & Active Version
            if not ProdBOMHead.Get(StockkeepingUnit."Production BOM No.") then
                exit;

            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/07 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
            ActiveVersionCode := VersionManagement.GetBOMVersion(ProdBOMHead."No.", WorkDate(), true);

            // Filter BOM Line (type = Item, only)
            ProdBOMLine.SetRange("Production BOM No.", ProdBOMHead."No.");
            if ActiveVersionCode <> '' then begin
                ProdBOMLine.SetRange("Version Code", ActiveVersionCode);
            end;
            ProdBOMLine.SetRange(Type, Enum::"Production BOM Line Type"::Item);

            // ProdBOMLine.SetRange("Version Code", ActiveVersionCode); // v1
            // Get The Production Item Type for the unsorted item type.
            ProdItemType.SetRange("Production Item Type", Enum::"PMP09 Production Item Type"::"Sortation-Unsorted");
            if not ProdItemType.FindFirst() then
                exit;

            if ProdBOMLine.FindSet() then
                repeat
                    ProdBOMLineItemTypeQuery.SetRange(ProdBOMLineItemTypeQuery.ProdBOMH_No, ProdBOMLine."Production BOM No."); // PK1
                    ProdBOMLineItemTypeQuery.SetRange(ProdBOMLineItemTypeQuery.ProdBOML_VersionCode, ProdBOMLine."Version Code"); // PK2
                    ProdBOMLineItemTypeQuery.SetRange(ProdBOMLineItemTypeQuery.ProdBOML_Type, ProdBOMLine.Type);
                    ProdBOMLineItemTypeQuery.SetRange(ProdBOMLineItemTypeQuery.ProdBOML_LineNo, ProdBOMLine."Line No."); // PK3
                    ProdBOMLineItemTypeQuery.SetRange(ProdBOMLineItemTypeQuery.ProdBOML_No, ProdBOMLine."No.");
                    if ProdItemType."Item Group" <> '' then
                        ProdBOMLineItemTypeQuery.SetRange(ProdBOMLineItemTypeQuery.ITEM_PMP04ItemGroup, ProdItemType."Item Group");
                    if ProdItemType."Item Category Code" <> '' then
                        ProdBOMLineItemTypeQuery.SetRange(ProdBOMLineItemTypeQuery.ITEM_ItemCategoryCode, ProdItemType."Item Category Code");
                    if ProdItemType."Item Class L1" <> '' then
                        ProdBOMLineItemTypeQuery.SetRange(ProdBOMLineItemTypeQuery.ITEM_PMP04ItemClassL1, ProdItemType."Item Class L1");
                    if ProdItemType."Item Class L2" <> '' then
                        ProdBOMLineItemTypeQuery.SetRange(ProdBOMLineItemTypeQuery.ITEM_PMP04ItemClassL2, ProdItemType."Item Class L2");
                    if ProdItemType."Item Type L1" <> '' then
                        ProdBOMLineItemTypeQuery.SetRange(ProdBOMLineItemTypeQuery.ITEM_PMP04ItemTypeL1, ProdItemType."Item Type L1");
                    if ProdItemType."Item Type L2" <> '' then
                        ProdBOMLineItemTypeQuery.SetRange(ProdBOMLineItemTypeQuery.ITEM_PMP04ItemTypeL2, ProdItemType."Item Type L2");
                    if ProdItemType."Item Type L3" <> '' then
                        ProdBOMLineItemTypeQuery.SetRange(ProdBOMLineItemTypeQuery.ITEM_PMP04ItemTypeL3, ProdItemType."Item Type L3");
                    ProdBOMLineItemTypeQuery.Open();

                    if ProdBOMLineItemTypeQuery.Read() then begin
                        Rec."Unsorted Item No." := ProdBOMLine."No.";
                        Rec."Unsorted Variant Code" := ProdBOMLine."Variant Code";
                        Rec."Unsorted Item Description" := ProdBOMLine.Description;
                        IsFound := true;
                    end;

                    ProdBOMLineItemTypeQuery.Close();

                // v1 remakrs
                // if ItemRec.Get(ProdBOMLine."No.") then begin
                //     if (ItemRec."PMP04 Item Group" = ProdItemType."Item Group") then begin

                //     end;
                //     // YABAI
                //     if  and
                //        (ItemRec."Item Category Code" = ProdItemType."Item Category Code") and
                //        (ItemRec."PMP04 Item Class L1" = ProdItemType."Item Class L1") and
                //        (ItemRec."PMP04 Item Class L2" = ProdItemType."Item Class L2") and
                //        (ItemRec."PMP04 Item Type L1" = ProdItemType."Item Type L1") and
                //        (ItemRec."PMP04 Item Type L2" = ProdItemType."Item Type L2") and
                //        (ItemRec."PMP04 Item Type L3" = ProdItemType."Item Type L3") then begin
                //     end;
                // end;
                //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/07 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
                until (ProdBOMLine.Next() = 0) OR IsFound;
        end;
        // =====================================================================================
        StockkeepingUnit.Reset();
        ProdBOMHead.Reset();
        ProdBOMLine.Reset();
        StockkeepingUnit.SetRange("Item No.", Rec."Unsorted Item No.");
        StockkeepingUnit.SetRange("Variant Code", Rec."Unsorted Variant Code"); // YABAI
        StockkeepingUnit.SetRange("Location Code", ExtCompanySetup."PMP15 SOR Location Code"); // Find by SOR Location Code first
        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/07 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
        StockkeepingUnit.SetFilter("Production BOM No.", '<>%1', '');
        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/07 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
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
            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/07 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
            if ActiveVersionCode <> '' then begin
                ProdBOMLine.SetRange("Version Code", ActiveVersionCode);
            end;
            // ProdBOMLine.SetRange("Version Code", ActiveVersionCode);
            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/07 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
            ProdBOMLine.SetRange(Type, ProdBOMLine.Type::Item);
            if ProdBOMLine.FindFirst() then begin
                Rec."RM Item No." := ProdBOMLine."No.";
                Rec."RM Variant Code" := ProdBOMLine."Variant Code";
                Rec."RM Item Description" := ProdBOMLine.Description;
            end;
        end;
    end;

    /// <summary> Updates the "Unsorted Item Description" field after validating the "Unsorted Item No." by retrieving the item description from the Item table. </summary> 
    [EventSubscriber(ObjectType::Table, Database::"PMP15 Sortation PO Creation", OnAfterValidateEvent, "Unsorted Item No.", false, false)]
    local procedure PMP15SortationPOCreation_OnAfterValidateEvent_UnsortedItemNo(CurrFieldNo: Integer; var Rec: Record "PMP15 Sortation PO Creation"; var xRec: Record "PMP15 Sortation PO Creation")
    var
        ItemRec: Record Item;
    begin
        if ItemRec.Get(Rec."Unsorted Item No.") then
            Rec."Unsorted Item Description" := ItemRec.Description;
    end;

    /// <summary> Updates the "Tarre Weight (Kg)" field after validating the "Lot No." by retrieving the corresponding value from Lot No. Information. </summary>
    [EventSubscriber(ObjectType::Table, Database::"PMP15 Sortation PO Creation", OnAfterValidateEvent, "Lot No.", false, false)]
    local procedure PMP15SortationPOCreation_OnAfterValidateEvent_TarreWeight_Kgs_(CurrFieldNo: Integer; var Rec: Record "PMP15 Sortation PO Creation"; var xRec: Record "PMP15 Sortation PO Creation")
    var
        LotNoInfo: Record "Lot No. Information";
    begin
        Clear(Rec."Tarre Weight (Kg)");
        Clear(Rec.Quantity);
        // Based on the filter LotsByBin from the Page
        LotNoInfo.SetRange("Item No.", Rec."RM Item No.");
        LotNoInfo.SetRange("Variant Code", Rec."RM Variant Code");
        LotNoInfo.SetRange("Lot No.", Rec."Lot No.");
        if LotNoInfo.FindFirst() then begin
            Rec."Tarre Weight (Kg)" := LotNoInfo."PMP14 Tarre Weight (Kgs)";
        end;
    end;

    /// <summary> Synchronizes Crop and Tarre Weight fields on the Production Order based on the selected Lot No. when SOR Rework is enabled. </summary>
    [EventSubscriber(ObjectType::Table, Database::"Production Order", OnAfterValidateEvent, "PMP15 Lot No.", false, false)]
    local procedure PMP15ProdOrder_OnAfterValidateEvent_LotNo(var Rec: Record "Production Order"; var xRec: Record "Production Order"; CurrFieldNo: Integer)
    var
        LotNoInfoRec: Record "Lot No. Information";
        ProdOrdComp: Record "Prod. Order Component";
    begin
        if Rec."PMP15 SOR Rework" then begin
            LotNoInfoRec.Reset();
            ProdOrdComp.Reset();

            ProdOrdComp.SetRange("Prod. Order No.", Rec."No.");
            ProdOrdComp.SetRange("PMP15 Unsorted Item", true);
            if ProdOrdComp.FindFirst() then begin
                LotNoInfoRec.SetRange("Item No.", ProdOrdComp."Item No.");
                LotNoInfoRec.SetRange("Variant Code", ProdOrdComp."Variant Code");
                LotNoInfoRec.SetRange("Lot No.", Rec."PMP15 Lot No.");
                if LotNoInfoRec.FindFirst() then begin
                    Rec."PMP15 Crop" := LotNoInfoRec."PMP14 Crop";
                    Rec."PMP15 Tarre Weight (Kg)" := LotNoInfoRec."PMP14 Tarre Weight (Kgs)";
                end;
            end;
        end;
    end;

    /// <summary>Simulates the insertion of a production order record for validation before actual creation.</summary>
    /// <remarks>Initializes a temporary production order based on sortation data and extended company setup, assigns default values, and returns the success result of the simulated insert.</remarks>
    /// <param name="tempProdOrderRec">The temporary production order record to simulate insertion.</param>
    /// <param name="SortProdOrdCreation">The temporary sortation production order creation record used as the data source.</param>
    /// <returns>True if the simulated insert succeeds; otherwise, false.</returns>
    procedure SimulateInsertSuccess(var tempProdOrderRec: Record "Production Order" temporary; var SortProdOrdCreation: Record "PMP15 Sortation PO Creation" temporary) IsInsertSuccess: Boolean
    var
        LotNoInfoRec: Record "Lot No. Information";
    begin
        ExtCompanySetup.Get();
        LotNoInfoRec.Reset();

        tempProdOrderRec.DeleteAll();
        tempProdOrderRec.Reset();
        tempProdOrderRec.Init();
        tempProdOrderRec."No." := NoSeriesMgmt.PeekNextNo(ExtCompanySetup."PMP15 Sort-Prod. Order Nos.", WorkDate());
        tempProdOrderRec."No. Series" := ExtCompanySetup."PMP15 Sort-Prod. Order Nos.";
        tempProdOrderRec.Status := tempProdOrderRec.Status::"Firm Planned";
        tempProdOrderRec."Creation Date" := WorkDate();
        tempProdOrderRec."Last Date Modified" := WorkDate();
        tempProdOrderRec.Validate("Source Type", tempProdOrderRec."Source Type"::Item);
        tempProdOrderRec.Validate("Source No.", SortProdOrdCreation."Sorted Item No.");
        tempProdOrderRec.Validate("Variant Code", SortProdOrdCreation."Sorted Variant Code");
        tempProdOrderRec.Validate("Location Code", ExtCompanySetup."PMP15 SOR Location Code");
        tempProdOrderRec.Validate(Quantity, SortProdOrdCreation.Quantity);
        tempProdOrderRec.Validate("PMP15 RM Item No.", SortProdOrdCreation."RM Item No.");
        tempProdOrderRec.Validate("PMP15 RM Item Description", SortProdOrdCreation."RM Item Description");
        tempProdOrderRec.Validate("PMP15 RM Variant Code", SortProdOrdCreation."RM Variant Code");
        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/05 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
        // tempProdOrderRec."PMP15 Crop" := Date2DMY(WorkDate(), 3);
        // tempProdOrderRec."PMP15 Crop" := Format(Date2DMY(WorkDate(), 3));

        LotNoInfoRec.SetRange("Item No.", SortProdOrdCreation."Sorted Item No.");
        LotNoInfoRec.SetRange("Variant Code", SortProdOrdCreation."Sorted Variant Code");
        LotNoInfoRec.SetRange("Lot No.", SortProdOrdCreation."Lot No.");
        if LotNoInfoRec.FindFirst() then begin
            tempProdOrderRec."PMP15 Crop" := LotNoInfoRec."PMP14 Crop";
        end;
        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/05 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
        tempProdOrderRec.Validate("PMP15 Lot No.", SortProdOrdCreation."Lot No.");
        tempProdOrderRec."PMP15 Tarre Weight (Kg)" := SortProdOrdCreation."Tarre Weight (Kg)";
        tempProdOrderRec."PMP15 Production Unit" := tempProdOrderRec."PMP15 Production Unit"::"SOR-Sortation";
        tempProdOrderRec."PMP15 SOR Rework" := SortProdOrdCreation.Rework;
        tempProdOrderRec."PMP15 Reference No." := SortProdOrdCreation."Reference No.";
        tempProdOrderRec."PMP15 Reference Line No." := SortProdOrdCreation."Reference Line No.";
        tempProdOrderRec."PMP04 Item Owner Internal" := ExtCompanySetup."PMP15 SOR Item Owner Internal";
        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/06 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
        tempProdOrderRec."PMP15 Allowance Packing Weight" := SortProdOrdCreation."PMP15 Allowance Packing Weight";
        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/06 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
        exit(tempProdOrderRec.Insert());
    end;

    /// <summary> Refreshes a Production Order using default refresh parameters. </summary>
    /// <remarks> This procedure acts as a wrapper for the extended RunRefreshProdOrder method. It triggers the Refresh Production Order report with predefined settings to recalculate lines, routings, and components without showing validation dialogs or request pages. </remarks>
    /// <param name="ProdOrdRec"> The Production Order record to be refreshed. </param>
    procedure RunRefreshProdOrder(ProdOrdRec: Record "Production Order")
    begin
        RunRefreshProdOrder(ProdOrdRec, 1, true, true, true, false);
    end;

    /// <summary> Refreshes a Production Order with configurable refresh options. </summary>
    /// <remarks> This procedure executes the <b>Refresh Production Order</b> report for the specified Production Order and allows control over recalculation behavior, including lines, routings, components, and inbound requests. The process runs silently without displaying validation dialogs or request pages. If the Production Order does not exist, a user message is shown and the process is aborted. </remarks>
    /// <param name="ProdOrdRec"> The Production Order record identifying the document to refresh. </param>
    /// <param name="Direction2"> The refresh direction option passed to the Refresh Production Order report. </param>
    /// <param name="CalcLines2"> Specifies whether production order lines should be recalculated. </param>
    /// <param name="CalcRoutings2"> Specifies whether routings should be recalculated. </param>
    /// <param name="CalcComponents2"> Specifies whether components should be recalculated. </param>
    /// <param name="CreateInbRqst2"> Specifies whether inbound requests should be created during refresh. </param>
    /// <returns> <b>true</b> if the Production Order was found and refreshed successfully; otherwise, <b>false</b>. </returns>
    procedure RunRefreshProdOrder(ProdOrdRec: Record "Production Order"; Direction2: Option; CalcLines2: Boolean; CalcRoutings2: Boolean; CalcComponents2: Boolean; CreateInbRqst2: Boolean): Boolean
    var
        ProdOrder: Record "Production Order";
        RefreshProdOrder: Report "Refresh Production Order";
    begin
        ProdOrder.SetRange("No.", ProdOrdRec."No.");
        if ProdOrder.FindFirst() then begin
            RefreshProdOrder.SetTableView(ProdOrder);
            RefreshProdOrder.InitializeRequest(Direction2, CalcLines2, CalcRoutings2, CalcComponents2, CreateInbRqst2);
            RefreshProdOrder.SetHideValidationDialog(true);
            RefreshProdOrder.UseRequestPage(false);
            RefreshProdOrder.Run();
            exit(true);
        end else begin
            Message('There is no Production Order with the document number of %1', ProdOrdRec."No.");
            exit(false);
        end;
    end;

    /// <summary> Creates and finalizes a new Production Order for sortation based on a temporary Production Order template. </summary>
    /// <remarks> This procedure generates a new Production Order using data copied from a temporary record, assigns a new document number from the <b>Sort Production Order No. Series</b>, initializes key dates, and commits the record. After creation, it automatically runs the <b>Refresh Production Order</b> process to calculate lines, routings, and components. Depending on whether the Production Order is marked as <b>SOR Rework</b>, the procedure updates related Production Order Components by flagging them as unsorted items, aligning item numbers, variants, and quantities according to the provided sortation setup. </remarks>
    /// <param name="ProdOrder"> The Production Order record that will be created and finalized. </param>
    /// <param name="tempProdOrderRec"> A temporary Production Order record serving as the source template for the new document. </param> 
    /// <param name="SortProdOrdCreation"> A temporary Sortation Production Order Creation record containing unsorted item and variant information. </param>
    procedure SortProdOrdCreationPost(var ProdOrder: Record "Production Order"; var tempProdOrderRec: Record "Production Order" temporary; var SortProdOrdCreation: Record "PMP15 Sortation PO Creation" temporary)
    var
        ProdOrderLine: Record "Prod. Order Line";
        ProdOrderComp: Record "Prod. Order Component";
    begin
        ProdOrderLine.Reset();
        ProdOrderComp.Reset();
        // ==============================================
        ProdOrder.Init();
        ProdOrder.Copy(tempProdOrderRec);
        ProdOrder."No." := NoSeriesMgmt.GetNextNo(ExtCompanySetup."PMP15 Sort-Prod. Order Nos.", WorkDate());
        ProdOrder.Insert();
        ProdOrder.Validate("Starting Date", WorkDate());
        ProdOrder.Validate("Starting Date-Time", CurrentDateTime);
        ProdOrder.Validate("Ending Date-Time", CurrentDateTime);
        ProdOrder.Validate("Due Date", CalcDate('<+2D>', WorkDate()));
        ProdOrder.Modify();
        COMMIT();
        // ====================================================================
        // Run Refresh Production Order Function for the Released Prod. Order
        // RefreshProdOrder.InitializeRequest(1, true, true, true, false);
        // RefreshProdOrder.SetHideValidationDialog(true);
        // RefreshProdOrder.UseRequestPage(false);
        // RefreshProdOrder.Run();
        RunRefreshProdOrder(ProdOrder);
        // ====================================================================
        ProdOrderLine.SetRange("Prod. Order No.", ProdOrder."No.");
        ProdOrderLine.SetFilter("Item No.", '<>%1', '');
        if ProdOrder."PMP15 SOR Rework" then begin
            if ProdOrderLine.FindSet() then
                repeat
                    ProdOrderComp.SetRange("Prod. Order No.", ProdOrder."No.");
                    ProdOrderComp.SetRange("Prod. Order Line No.", ProdOrderLine."Line No.");
                    ProdOrderComp.SetRange("Variant Code", SortProdOrdCreation."Unsorted Variant Code");
                    ProdOrderComp.ModifyAll("PMP15 Unsorted Item", true);
                    ProdOrderComp.SetRange("PMP15 Unsorted Item", true);
                    ProdOrderComp.ModifyAll("Item No.", ProdOrderLine."Item No.");
                    ProdOrderComp.ModifyAll("Quantity per", 1);
                until ProdOrderLine.Next() = 0;
        end else begin
            if ProdOrderLine.FindFirst() then begin
                ProdOrderComp.SetRange("Prod. Order No.", ProdOrder."No.");
                ProdOrderComp.SetRange("Prod. Order Line No.", ProdOrderLine."Line No.");
                ProdOrderComp.SetRange("Item No.", SortProdOrdCreation."Unsorted Item No.");
                ProdOrderComp.SetRange("Variant Code", SortProdOrdCreation."Unsorted Variant Code");
                ProdOrderComp.ModifyAll("PMP15 Unsorted Item", true);
            end;
        end;
    end;

    /// <summary>Generates inventory document lines from bin content records.</summary>
    /// <remarks>Uses the Whse. Get Bin Content report to populate inventory shipment lines for the specified document.</remarks>
    /// <param name="BinContent">The bin content records to process.</param>
    /// <param name="InvDocLine">The inventory document line records to populate.</param>
    /// <param name="InvtDocHeader">The inventory document header associated with the shipment.</param>
    local procedure Generate_GetBinContent(var BinContent: Record "Bin Content"; var InvDocLine: Record "Invt. Document Line"; var InvtDocHeader: Record "Invt. Document Header")
    var
        GetBinContent: Report "Whse. Get Bin Content";
    // BinContentRec: Record "Bin Content";
    begin
        // BinContentRec.CopyFilters(BinContent);
        // GetBinContent.SetTableView(BinContentRec);
        GetBinContent.SetTableView(BinContent);
        GetBinContent.InitializeInvtShipmentLine(InvDocLine, InvtDocHeader);
        GetBinContent.RunModal();
    end;

    /// <summary>Completes the production order process for a sorted item.</summary>
    /// <remarks>Generates an inventory shipment document based on the sortation setup, validates Extended Company Setup fields, retrieves bin contents, and updates the production order as completed.</remarks>
    /// <param name="ProdOrder">The production order to complete.</param>
    /// <param name="InvDocHeader">The inventory document header record used for the shipment.</param>
    procedure SortProdOrdCreationCompleted(var ProdOrder: Record "Production Order"; var InvDocHeader: Record "Invt. Document Header")
    var
        ErrInfo: ErrorInfo;
        InvShipmentPageDoc: Page "Invt. Shipment";
        BinContent: Record "Bin Content";
        InvDocLine: Record "Invt. Document Line";
        ProdOrdComp: Record "Prod. Order Component";
        UnSORItemNo: Code[20];
        UnSORItemDesc: Text;
        UoMCode, UnSORVariantCode : Code[10];
        SORBinCode: array[7] of Code[20]; // -- Bin Code = Bin with SOR Step 0 + "|" + Bin with SOR Step 1 + "|" + Bin with SOR Step 2 + "|" + Bin with SOR Step 3 + "|" + Bin with SOR Step 4 + "|" + Previous Bin with SOR Step 0
    begin
        ExtCompanySetup.Get();
        Clear(SORBinCode);
        if Confirm('Do you want to complete Production Order No. %1 for the sorted item of %2 - %3 with Lot No. %4?', TRUE, ProdOrder."No.", ProdOrder."Source No.", ProdOrder."Variant Code", ProdOrder."PMP15 Lot No.") AND (ProdOrder."No." <> '') then begin
            PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Inv. Shipment Nos"));
            InvDocHeader.Init();
            InvDocHeader."Document Type" := InvDocHeader."Document Type"::Shipment; // add
            InvDocHeader."No. Series" := ExtCompanySetup."PMP15 SOR Inv. Shipment Nos";
            InvDocHeader."No." := NoSeriesMgmt.GetNextNo(InvDocHeader."No. Series", WorkDate());
            InvDocHeader.InitRecord();

            // InvDocHeader."Posting Description" := 'Shipment ' + InvDocHeader."No."; // add
            InvDocHeader."Location Code" := ProdOrder."Location Code";
            InvDocHeader.Validate("Document Date", WorkDate());
            InvDocHeader.Validate("Posting Date", WorkDate());
            // InvDocHeader."Document Date" := WorkDate(); // add
            // InvDocHeader."Posting Date" := WorkDate();
            InvDocHeader."PMP15 Production Order No." := ProdOrder."No.";
            InvDocHeader."PMP18 Reason Code" := ExtCompanySetup."PMP15 SOR Invt.Ship.Reason";
            InvDocHeader."PMP15 Marked" := true;
            InvDocHeader.Insert();
            InvDocHeader.Mark(true);
            // Commit();

            ProdOrdComp.Reset();
            ProdOrdComp.SetRange("Prod. Order No.", ProdOrder."No.");
            ProdOrdComp.SetRange("PMP15 Unsorted Item", true);
            if ProdOrdComp.FindFirst() then begin
                UnSORItemNo := ProdOrdComp."Item No.";
                UnSORItemDesc := ProdOrdComp.Description;
                UnSORVariantCode := ProdOrdComp."Variant Code";
            end;

            GetSORBinCodes(SORBinCode);
            BinContent.Reset();
            BinContent.SetRange("Location Code", InvDocHeader."Location Code");
            BinContent.SetFilter("Bin Code", '%1 | %2 | %3 | %4 | %5 | %6 | %7', SORBinCode[1], SORBinCode[2], SORBinCode[3], SORBinCode[4], SORBinCode[5], SORBinCode[6], SORBinCode[7]);
            if ProdOrder."PMP15 RM Item No." <> '' then
                BinContent.SetFilter("Item No.", '%1 | %2', ProdOrder."PMP15 RM Item No.", UnSORItemNo);
            if ProdOrder."PMP15 RM Variant Code" <> '' then
                BinContent.SetFilter("Variant Code", '%1 | %2', ProdOrder."PMP15 RM Variant Code", UnSORVariantCode);
            BinContent.SetFilter("Lot No. Filter", ProdOrder."PMP15 Lot No.");
            BinContent.SetAutoCalcFields(Quantity);
            BinContent.SetFilter(Quantity, '> 0');
            if BinContent.Count > 0 then begin
                Commit();
            end else begin
                InvDocHeader.MarkedOnly(true);
                InvDocHeader.Delete();
                exit
            end;

            InvDocLine.Reset();
            InvDocLine.SetRange("Document Type", InvDocLine."Document Type"::Shipment);
            InvDocLine.SetRange("Document No.", InvDocHeader."No.");
            if InvDocLine.Count > 0 then begin
                if Confirm('Existing inventory shipment lines were found. Do you want to delete them before running Get Bin Content?', true) then begin
                    InvDocLine.DeleteAll();
                    Commit();
                    Generate_GetBinContent(BinContent, InvDocLine, InvDocHeader);
                end else if ConfirmationPage.GetResult() = 'NO' then begin
                    if Confirm('If you continue without deleting the existing lines, the inventory shipment may contain inconsistent or duplicate data. Do you want to proceed?', true) then begin
                        Generate_GetBinContent(BinContent, InvDocLine, InvDocHeader);
                    end;
                end;
            end else begin
                Generate_GetBinContent(BinContent, InvDocLine, InvDocHeader);
            end;
            ProdOrder."PMP15 SOR Completed" := true;
            ProdOrder.Modify();

            InvShipmentPageDoc.SetRecord(InvDocHeader);
            InvShipmentPageDoc.Run();
        end;
    end;

    /// <summary>Changes the status of a production order.</summary>
    /// <remarks>Uses the Prod. Order Status Management codeunit to update status, posting date, and unit cost, then commits the changes.</remarks>
    /// <param name="ProdOrder">The production order record to update.</param>
    /// <param name="NewStatus">The new status to assign.</param>
    /// <param name="NewPostingDate">The posting date for the change.</param>
    /// <param name="NewUpdateUnitCost">Specifies whether to update unit cost.</param>
    /// <returns>The updated production order status.</returns>
    procedure SortChangeProdOrderStatus(var ProdOrder: Record "Production Order"; NewStatus: Enum "Production Order Status"; NewPostingDate: Date; NewUpdateUnitCost: Boolean) Status: Enum "Production Order Status"
    var
        ProdOrderStatusMgmt: Codeunit "Prod. Order Status Management";
    begin
        ProdOrderStatusMgmt.ChangeProdOrderStatus(ProdOrder, NewStatus, NewPostingDate, NewUpdateUnitCost);
        Commit();
        Status := ProdOrder.Status;
        exit(Status);
    end;

    /// <summary> Validates mandatory input fields before posting a Sortation Production Order. </summary>
    /// <remarks> This procedure ensures that all <b>critical sortation inputs</b> are properly populated before allowing the creation or posting of a Sortation Production Order. It prevents invalid processing by enforcing quantity validation and verifying that both <b>sorted</b> and <b>unsorted</b> item references are provided. If any required data is missing or invalid, the process is stopped with a clear error message to guide the user toward corrective action. </remarks>
    /// <param name="SortProdOrdCreation"> Temporary Sortation Production Order Creation record containing user input for quantity, sorted item, unsorted item, and raw material references. </param>
    procedure ValidateInputBeforePosting(var SortProdOrdCreation: Record "PMP15 Sortation PO Creation" temporary)
    begin
        if SortProdOrdCreation.Quantity = 0 then
            Error('Quantity cannot be empty. Please select an existing unsorted Lot No. before creating a Sortation Production Order.');

        if (SortProdOrdCreation."Sorted Item No." = '') or (SortProdOrdCreation."Sorted Variant Code" = '') then
            Error('Please complete both the Sorted Item No. and Sorted Variant Code fields before proceeding.');

        if (SortProdOrdCreation."Unsorted Item No." = '') or (SortProdOrdCreation."RM Item No." = '') then
            Error('Please complete both the Unsorted Item No. and RM Item No. fields before proceeding.');
    end;


    #endregion SOR CREATION

    #region SOR RECORDING
    /// <summary>Auto-populates related <b>sortation, raw material, lot, weight, and item details</b> when the Sortation Production Order No. is validated.</summary>
    [EventSubscriber(ObjectType::Table, Database::"PMP15 Sortation PO Recording", OnAfterValidateEvent, "Sortation Prod. Order No.", false, false)]
    local procedure PMP15FillValOnLookup_OnAfterValidateEvent_SortationProdOrderNo(var Rec: Record "PMP15 Sortation PO Recording"; var xRec: Record "PMP15 Sortation PO Recording"; CurrFieldNo: Integer)
    var
        ProdOrder: Record "Production Order";
        ProdOrderLine: Record "Prod. Order Line";
        ProdOrderComp: Record "Prod. Order Component";
        // ItemVariant: Record "Item Variant";
        ItemVariantRec: Record "Item Variant";
    begin
        ProdOrder.Reset();
        ProdOrderLine.Reset();
        ProdOrderComp.Reset();
        ItemVariantRec.Reset();

        ProdOrder.SetRange("No.", Rec."Sortation Prod. Order No.");
        if ProdOrder.FindFirst() then begin
            Rec.Rework := ProdOrder."PMP15 SOR Rework";
            Rec."RM Item No." := ProdOrder."PMP15 RM Item No.";
            Rec."RM Variant Code" := ProdOrder."PMP15 RM Variant Code";
            Rec."Lot No." := ProdOrder."PMP15 Lot No.";

            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
            Rec."Tarre Weight" := ProdOrder."PMP15 Tarre Weight (Kg)";
            Rec."Allowance Packing Weight" := ProdOrder."PMP15 Allowance Packing Weight";
            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
        end;

        ProdOrderLine.SetRange("Prod. Order No.", Rec."Sortation Prod. Order No.");
        if ProdOrderLine.FindFirst() then begin
            Rec."Sorted Item No." := ProdOrderLine."Item No.";
            Rec."Sorted Variant Code" := ProdOrderLine."Variant Code";

            Rec."Unit of Measure Code" := ProdOrderLine."Unit of Measure Code";
            // Rec.Validate("Sorted Variant Code", ProdOrderLine."Variant Code");
            ItemVariantRec.Reset();
            ItemVariantRec.SetRange("Item No.", Rec."Sorted Item No.");
            ItemVariantRec.SetRange(Code, Rec."Sorted Variant Code");
            if ItemVariantRec.FindFirst() then begin
                Rec."Submerk 1" := ItemVariantRec."PMP15 Sub Merk 1";
            end;
        end;

        ProdOrderComp.SetRange("Prod. Order No.", Rec."Sortation Prod. Order No.");
        if ProdOrderComp.FindFirst() then begin
            Rec."Unsorted Item No." := ProdOrderComp."Item No.";
            Rec."Unsorted Variant Code" := ProdOrderComp."Variant Code";
            Rec."Location Code" := ProdOrderComp."Location Code";
        end;
    end;

    // [EventSubscriber(ObjectType::Table, Database::"PMP15 Sortation PO Recording", OnAfterValidateEvent, "Sorted Variant Code", false, false)]
    // local procedure PMP15SetValue_OnAfterValidateEvent_SortedVariantCode(var Rec: Record "PMP15 Sortation PO Recording" temporary; var xRec: Record "PMP15 Sortation PO Recording" temporary; CurrFieldNo: Integer)
    // var
    //     ItemVariantRec: Record "Item Variant";
    // begin
    //     ItemVariantRec.Reset();
    //     ItemVariantRec.SetRange("Item No.", Rec."Sorted Item No.");
    //     ItemVariantRec.SetRange(Code, Rec."Sorted Variant Code");
    //     if ItemVariantRec.FindFirst() then begin
    //         Message('Dapat submerk 1 = %1', ItemVariantRec."PMP15 Sub Merk 1");
    //         Rec."Submerk 1" := ItemVariantRec."PMP15 Sub Merk 1";
    //         Rec.Modify();
    //     end;
    // end;

    // ASSEMBLY HEADER (ORDER) --> POSTED ASSEMBLY HEADER
    ///<summary>Copies the Sortation fields from Assembly Header into the User ID field of Posted Assembly Header before insert.</summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Assembly-Post", OnPostOnBeforePostedAssemblyHeaderInsert, '', false, false)]
    local procedure PMP15CopyPostingAssemblyHeaderPost_OnPostOnBeforePostedAssemblyHeaderInsert(AssemblyHeader: Record "Assembly Header"; var PostedAssemblyHeader: Record "Posted Assembly Header")
    begin
        PostedAssemblyHeader."PMP15 Prod. Order No." := AssemblyHeader."PMP15 Prod. Order No.";
        PostedAssemblyHeader."PMP15 Production Type" := AssemblyHeader."PMP15 Production Type";
        PostedAssemblyHeader."PMP15 SOR Step" := AssemblyHeader."PMP15 SOR Step";
        PostedAssemblyHeader."PMP15 SOR Step Code" := AssemblyHeader."PMP15 SOR Step Code";
        PostedAssemblyHeader."PMP15 Tobacco Type" := AssemblyHeader."PMP15 Tobacco Type";
        PostedAssemblyHeader."PMP15 Sub Merk 1" := AssemblyHeader."PMP15 Sub Merk 1";
        PostedAssemblyHeader."PMP15 Sub Merk 2" := AssemblyHeader."PMP15 Sub Merk 2";
        PostedAssemblyHeader."PMP15 Sub Merk 3" := AssemblyHeader."PMP15 Sub Merk 3";
        PostedAssemblyHeader."PMP15 Sub Merk 4" := AssemblyHeader."PMP15 Sub Merk 4";
        PostedAssemblyHeader."PMP15 Sub Merk 5" := AssemblyHeader."PMP15 Sub Merk 5";
        PostedAssemblyHeader."PMP15 L/R" := AssemblyHeader."PMP15 L/R";
        PostedAssemblyHeader."PMP15 Rework" := AssemblyHeader."PMP15 Rework";

        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
        PostedAssemblyHeader."PMP15 Sorted Item No." := AssemblyHeader."PMP15 Sorted Item No.";
        PostedAssemblyHeader."PMP15 Sorted Variant Code" := AssemblyHeader."PMP15 Sorted Variant Code";
        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
    end;

    // ASSEMBLY HEADER (ORDER) --> ITEM JOURNAL LINE (AS OUTPUT)
    ///<summary>Transfers the Sortation fields from Assembly Header into Item Journal Line after it is created <b>As the Output</b>.</summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Assembly-Post", OnAfterCreateItemJnlLineFromAssemblyHeader, '', false, false)]
    local procedure PMP15CopyPostatAssemblyHeadrtoItemJnlLine_OnAfterCreateItemJnlLineFromAssemblyHeader(var ItemJournalLine: Record "Item Journal Line"; AssemblyHeader: Record "Assembly Header")
    var
        LotNoInfoRec: Record "Lot No. Information";
        ProdOrderRec: Record "Production Order";
    begin
        LotNoInfoRec.Reset();
        ProdOrderRec.Reset();

        ProdOrderRec.SetRange(Status, ProdOrderRec.Status::Released);
        ProdOrderRec.SetRange("No.", AssemblyHeader."PMP15 Prod. Order No.");
        if ProdOrderRec.FindFirst() then begin
            ItemJournalLine."PMP15 Prod. Order No." := AssemblyHeader."PMP15 Prod. Order No.";
            ItemJournalLine."PMP15 Production Type" := AssemblyHeader."PMP15 Production Type";
            ItemJournalLine."PMP15 SOR Step" := AssemblyHeader."PMP15 SOR Step";
            ItemJournalLine."PMP15 SOR Step Code" := AssemblyHeader."PMP15 SOR Step Code";
            ItemJournalLine."PMP15 Tobacco Type" := AssemblyHeader."PMP15 Tobacco Type";
            ItemJournalLine."PMP15 Sub Merk 1" := AssemblyHeader."PMP15 Sub Merk 1";
            ItemJournalLine."PMP15 Sub Merk 2" := AssemblyHeader."PMP15 Sub Merk 2";
            ItemJournalLine."PMP15 Sub Merk 3" := AssemblyHeader."PMP15 Sub Merk 3";
            ItemJournalLine."PMP15 Sub Merk 4" := AssemblyHeader."PMP15 Sub Merk 4";
            ItemJournalLine."PMP15 Sub Merk 5" := AssemblyHeader."PMP15 Sub Merk 5";
            ItemJournalLine."PMP15 L/R" := AssemblyHeader."PMP15 L/R";
            ItemJournalLine."PMP15 Rework" := AssemblyHeader."PMP15 Rework";

            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
            ItemJournalLine."PMP15 Marked" := true;
            if LotNoInfoRec.Get(ProdOrderRec."PMP15 RM Item No.", ProdOrderRec."PMP15 RM Variant Code", AssemblyHeader."PMP15 Lot No.") then begin
                ItemJournalLine."PMP15 Crop" := LotNoInfoRec."PMP14 Crop";
                ItemJournalLine."PMP15 Cycle (Separately)" := LotNoInfoRec."PMP14 Cycle (Separately)";
                ItemJournalLine."Invoice No." := LotNoInfoRec."PMP14 Invoice No.";
                ItemJournalLine."PMP15 Delivery" := LotNoInfoRec."PMP14 Delivery";
                ItemJournalLine."PMP15 Cycle Code" := LotNoInfoRec."PMP14 Cycle Code";
                ItemJournalLine."PMP15 Output Item No." := AssemblyHeader."PMP15 Sorted Item No.";
                ItemJournalLine."PMP15 Output Variant Code" := AssemblyHeader."PMP15 Sorted Variant Code";
            end;
            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
        end;
    end;

    // ASSEMBLY Line (ORDER) --> ITEM JOURNAL LINE (AS CONSUMPTION)
    ///<summary>Transfers the Sortation fields from Assembly Line into Item Journal Line after it is created <b>As the Consumption</b> for the Item type.</summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Assembly-Post", OnBeforePostItemConsumption, '', false, false)]
    local procedure PMP15CopyPostatAssemblyHeadrtoItemJnlLine_OnBeforePostItemConsumption(var AssemblyHeader: Record "Assembly Header"; var AssemblyLine: Record "Assembly Line"; var ItemJournalLine: Record "Item Journal Line")
    var
        LotNoInfoRec: Record "Lot No. Information";
        ProdOrderRec: Record "Production Order";
    begin
        ProdOrderRec.SetRange(Status, ProdOrderRec.Status::Released);
        ProdOrderRec.SetRange("No.", AssemblyHeader."PMP15 Prod. Order No.");
        if ProdOrderRec.FindFirst() then begin
            ItemJournalLine."PMP15 Prod. Order No." := AssemblyHeader."PMP15 Prod. Order No.";
            ItemJournalLine."PMP15 Production Type" := AssemblyHeader."PMP15 Production Type";
            ItemJournalLine."PMP15 SOR Step" := AssemblyHeader."PMP15 SOR Step";
            ItemJournalLine."PMP15 SOR Step Code" := AssemblyHeader."PMP15 SOR Step Code";
            ItemJournalLine."PMP15 Tobacco Type" := AssemblyHeader."PMP15 Tobacco Type";
            ItemJournalLine."PMP15 Sub Merk 1" := AssemblyHeader."PMP15 Sub Merk 1";
            ItemJournalLine."PMP15 Sub Merk 2" := AssemblyHeader."PMP15 Sub Merk 2";
            ItemJournalLine."PMP15 Sub Merk 3" := AssemblyHeader."PMP15 Sub Merk 3";
            ItemJournalLine."PMP15 Sub Merk 4" := AssemblyHeader."PMP15 Sub Merk 4";
            ItemJournalLine."PMP15 Sub Merk 5" := AssemblyHeader."PMP15 Sub Merk 5";
            ItemJournalLine."PMP15 L/R" := AssemblyHeader."PMP15 L/R";
            ItemJournalLine."PMP15 Rework" := AssemblyHeader."PMP15 Rework";

            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
            ItemJournalLine."PMP15 Marked" := true;
            if LotNoInfoRec.Get(ItemJournalLine."Item No.", ItemJournalLine."Variant Code", AssemblyHeader."PMP15 Lot No.") then begin
                ItemJournalLine."PMP15 Crop" := LotNoInfoRec."PMP14 Crop";
                ItemJournalLine."PMP15 Cycle (Separately)" := LotNoInfoRec."PMP14 Cycle (Separately)";
                ItemJournalLine."Invoice No." := LotNoInfoRec."PMP14 Invoice No.";
                ItemJournalLine."PMP15 Delivery" := LotNoInfoRec."PMP14 Delivery";
                ItemJournalLine."PMP15 Cycle Code" := LotNoInfoRec."PMP14 Cycle Code";
                ItemJournalLine."PMP15 Output Item No." := AssemblyHeader."PMP15 Sorted Item No.";
                ItemJournalLine."PMP15 Output Variant Code" := AssemblyHeader."PMP15 Sorted Variant Code";
            end;
            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
        end;
    end;

    // ASSEMBLY Line (ORDER) --> ITEM JOURNAL LINE (AS CONSUMPTION)
    ///<summary>Transfers the Sortation fields from Assembly Line into Item Journal Line after it is created <b>As the Consumption</b> for the Resource type.</summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Assembly-Post", OnAfterCreateItemJnlLineFromAssemblyLine, '', false, false)]
    local procedure PMP15CopyPostatAssemblyHeadrtoItemJnlLine_OnAfterCreateItemJnlLineFromAssemblyLine(var ItemJournalLine: Record "Item Journal Line"; AssemblyLine: Record "Assembly Line")
    var
        LotNoInfoRec: Record "Lot No. Information";
        ProdOrderRec: Record "Production Order";
        AssemblyHeader: Record "Assembly Header";
    begin
        ProdOrderRec.Reset();
        AssemblyHeader.Reset();

        AssemblyHeader.SetRange("Document Type", AssemblyHeader."Document Type"::Order);
        AssemblyHeader.SetRange("No.", AssemblyLine."Document No.");
        if not AssemblyHeader.FindFirst() then exit;

        ProdOrderRec.SetRange(Status, ProdOrderRec.Status::Released);
        ProdOrderRec.SetRange("No.", AssemblyHeader."PMP15 Prod. Order No.");
        if ProdOrderRec.FindFirst() then begin
            ItemJournalLine."PMP15 Prod. Order No." := AssemblyHeader."PMP15 Prod. Order No.";
            ItemJournalLine."PMP15 Production Type" := AssemblyHeader."PMP15 Production Type";
            ItemJournalLine."PMP15 SOR Step" := AssemblyHeader."PMP15 SOR Step";
            ItemJournalLine."PMP15 SOR Step Code" := AssemblyHeader."PMP15 SOR Step Code";
            ItemJournalLine."PMP15 Tobacco Type" := AssemblyHeader."PMP15 Tobacco Type";
            ItemJournalLine."PMP15 Sub Merk 1" := AssemblyHeader."PMP15 Sub Merk 1";
            ItemJournalLine."PMP15 Sub Merk 2" := AssemblyHeader."PMP15 Sub Merk 2";
            ItemJournalLine."PMP15 Sub Merk 3" := AssemblyHeader."PMP15 Sub Merk 3";
            ItemJournalLine."PMP15 Sub Merk 4" := AssemblyHeader."PMP15 Sub Merk 4";
            ItemJournalLine."PMP15 Sub Merk 5" := AssemblyHeader."PMP15 Sub Merk 5";
            ItemJournalLine."PMP15 L/R" := AssemblyHeader."PMP15 L/R";
            ItemJournalLine."PMP15 Rework" := AssemblyHeader."PMP15 Rework";

            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
            ItemJournalLine."PMP15 Marked" := true;
            if LotNoInfoRec.Get(ItemJournalLine."Item No.", ItemJournalLine."Variant Code", AssemblyHeader."PMP15 Lot No.") then begin
                ItemJournalLine."PMP15 Crop" := LotNoInfoRec."PMP14 Crop";
                ItemJournalLine."PMP15 Cycle (Separately)" := LotNoInfoRec."PMP14 Cycle (Separately)";
                ItemJournalLine."Invoice No." := LotNoInfoRec."PMP14 Invoice No.";
                ItemJournalLine."PMP15 Delivery" := LotNoInfoRec."PMP14 Delivery";
                ItemJournalLine."PMP15 Cycle Code" := LotNoInfoRec."PMP14 Cycle Code";
                ItemJournalLine."PMP15 Output Item No." := AssemblyHeader."PMP15 Sorted Item No.";
                ItemJournalLine."PMP15 Output Variant Code" := AssemblyHeader."PMP15 Sorted Variant Code";
            end;
            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
        end;
    end;

    // ITEM JOURNAL LINE --> ITEM LEDGER ENTRY (ILE)
    ///<summary>Copies the Sortation fields from Item Journal Line into Item Ledger Entry after initialization.</summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", OnAfterInitItemLedgEntry, '', false, false)]
    local procedure PMP15CopyItemJnlLinetoILE_OnAfterInitItemLedgEntry(var ItemJournalLine: Record "Item Journal Line"; var NewItemLedgEntry: Record "Item Ledger Entry"; var ItemLedgEntryNo: Integer)
    begin
        NewItemLedgEntry."PMP15 Prod. Order No." := ItemJournalLine."PMP15 Prod. Order No.";
        NewItemLedgEntry."PMP15 Production Type" := ItemJournalLine."PMP15 Production Type";
        NewItemLedgEntry."PMP15 SOR Step" := ItemJournalLine."PMP15 SOR Step";
        NewItemLedgEntry."PMP15 SOR Step Code" := ItemJournalLine."PMP15 SOR Step Code";
        NewItemLedgEntry."PMP15 Return" := ItemJournalLine."PMP15 Return";
        NewItemLedgEntry."PMP15 Return to Result Step" := ItemJournalLine."PMP15 Return to Result Step";
        NewItemLedgEntry."PMP15 Return to Result Code" := ItemJournalLine."PMP15 Return to Result Code";
        NewItemLedgEntry."PMP15 Tobacco Type" := ItemJournalLine."PMP15 Tobacco Type";
        NewItemLedgEntry."PMP15 Sub Merk 1" := ItemJournalLine."PMP15 Sub Merk 1";
        NewItemLedgEntry."PMP15 Sub Merk 2" := ItemJournalLine."PMP15 Sub Merk 2";
        NewItemLedgEntry."PMP15 Sub Merk 3" := ItemJournalLine."PMP15 Sub Merk 3";
        NewItemLedgEntry."PMP15 Sub Merk 4" := ItemJournalLine."PMP15 Sub Merk 4";
        NewItemLedgEntry."PMP15 Sub Merk 5" := ItemJournalLine."PMP15 Sub Merk 5";
        NewItemLedgEntry."PMP15 L/R" := ItemJournalLine."PMP15 L/R";
        NewItemLedgEntry."PMP15 Rework" := ItemJournalLine."PMP15 Rework";

        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
        NewItemLedgEntry."PMP15 Variant Changes (From)" := ItemJournalLine."PMP15 Variant Changes (From)";
        NewItemLedgEntry."PMP15 Variant Changes (To)" := ItemJournalLine."PMP15 Variant Changes (To)";
        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
    end;

    // ITEM JOURNAL LINE --> WAREHOUSE JOURNAL LINE to WAREHOUSE ENTRY right after posting ILE.
    ///<summary>Copies the Sortations fields from Item Journal Line into Warehouse Journal Line after initialization.</summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"WMS Management", OnInitWhseJnlLineCopyFromItemJnlLine, '', false, false)]
    local procedure PMP15CopyItemJnlLinetoWhsJnlLine_OnInitWhseJnlLineCopyFromItemJnlLine(var WarehouseJournalLine: Record "Warehouse Journal Line"; ItemJournalLine: Record "Item Journal Line")
    var
        BinRec: Record Bin;
    begin
        if ItemJournalLine."PMP15 Marked" then begin
            BinRec.Reset();
            WarehouseJournalLine."PMP15 Prod. Order No." := ItemJournalLine."PMP15 Prod. Order No.";
            WarehouseJournalLine."PMP15 Production Type" := ItemJournalLine."PMP15 Production Type";
            WarehouseJournalLine."PMP15 SOR Step" := ItemJournalLine."PMP15 SOR Step";
            WarehouseJournalLine."PMP15 SOR Step Code" := ItemJournalLine."PMP15 SOR Step Code";
            WarehouseJournalLine."PMP15 Return" := ItemJournalLine."PMP15 Return";
            WarehouseJournalLine."PMP15 Return to Result Step" := ItemJournalLine."PMP15 Return to Result Step";
            WarehouseJournalLine."PMP15 Return to Result Code" := ItemJournalLine."PMP15 Return to Result Code";
            WarehouseJournalLine."PMP15 Tobacco Type" := ItemJournalLine."PMP15 Tobacco Type";
            WarehouseJournalLine."PMP15 Sub Merk 1" := ItemJournalLine."PMP15 Sub Merk 1";
            WarehouseJournalLine."PMP15 Sub Merk 2" := ItemJournalLine."PMP15 Sub Merk 2";
            WarehouseJournalLine."PMP15 Sub Merk 3" := ItemJournalLine."PMP15 Sub Merk 3";
            WarehouseJournalLine."PMP15 Sub Merk 4" := ItemJournalLine."PMP15 Sub Merk 4";
            WarehouseJournalLine."PMP15 Sub Merk 5" := ItemJournalLine."PMP15 Sub Merk 5";
            WarehouseJournalLine."PMP15 L/R" := ItemJournalLine."PMP15 L/R";
            WarehouseJournalLine."PMP15 Rework" := ItemJournalLine."PMP15 Rework";

            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
            WarehouseJournalLine."PMP15 Variant Changes (From)" := ItemJournalLine."PMP15 Variant Changes (From)";
            WarehouseJournalLine."PMP15 Variant Changes (To)" := ItemJournalLine."PMP15 Variant Changes (To)";
            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}

            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
            WarehouseJournalLine."PMP15 Crop" := ItemJournalLine."PMP15 Crop";
            WarehouseJournalLine."PMP15 Cycle (Separately)" := ItemJournalLine."PMP15 Cycle (Separately)";
            WarehouseJournalLine."PMP15 Invoice No." := ItemJournalLine."Invoice No.";
            WarehouseJournalLine."PMP15 Delivery" := ItemJournalLine."PMP15 Delivery";
            WarehouseJournalLine."PMP15 Cycle Code" := ItemJournalLine."PMP15 Cycle Code";
            WarehouseJournalLine."PMP15 Output Item No." := ItemJournalLine."PMP15 Output Item No.";
            WarehouseJournalLine."PMP15 Output Variant Code" := ItemJournalLine."PMP15 Output Variant Code";

            // WarehouseJournalLine."PMP15 Bin SOR Step" := ItemJournalLine."PMP15 Bin SOR Step";
            BinRec.SetRange("Location Code", WarehouseJournalLine."Location Code");
            BinRec.SetRange(Code, WarehouseJournalLine."Bin Code");
            if BinRec.FindFirst() then begin
                WarehouseJournalLine."PMP15 Bin SOR Step" := BinRec."PMP15 Bin Type";
            end;
            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
        end;
    end;

    // WAREHOUSE JOURNAL LINE --> WAREHOUSE ENTRY
    ///<summary>Copies the Sortations fields from Warehouse Journal Line into Warehouse Entry after insert.</summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Whse. Jnl.-Register Line", OnAfterInsertWhseEntry, '', false, false)]
    local procedure PMP18CopyWhseJnlLinetoWE_OnAfterInsertWhseEntry(var WarehouseEntry: Record "Warehouse Entry"; var WarehouseJournalLine: Record "Warehouse Journal Line")
    begin
        WarehouseEntry."PMP15 Prod. Order No." := WarehouseJournalLine."PMP15 Prod. Order No.";
        WarehouseEntry."PMP15 Production Type" := WarehouseJournalLine."PMP15 Production Type";
        WarehouseEntry."PMP15 SOR Step" := WarehouseJournalLine."PMP15 SOR Step";
        WarehouseEntry."PMP15 SOR Step Code" := WarehouseJournalLine."PMP15 SOR Step Code";
        WarehouseEntry."PMP15 Return" := WarehouseJournalLine."PMP15 Return";
        WarehouseEntry."PMP15 Return to Result Step" := WarehouseJournalLine."PMP15 Return to Result Step";
        WarehouseEntry."PMP15 Return to Result Code" := WarehouseJournalLine."PMP15 Return to Result Code";
        WarehouseEntry."PMP15 Tobacco Type" := WarehouseJournalLine."PMP15 Tobacco Type";
        WarehouseEntry."PMP15 Sub Merk 1" := WarehouseJournalLine."PMP15 Sub Merk 1";
        WarehouseEntry."PMP15 Sub Merk 2" := WarehouseJournalLine."PMP15 Sub Merk 2";
        WarehouseEntry."PMP15 Sub Merk 3" := WarehouseJournalLine."PMP15 Sub Merk 3";
        WarehouseEntry."PMP15 Sub Merk 4" := WarehouseJournalLine."PMP15 Sub Merk 4";
        WarehouseEntry."PMP15 Sub Merk 5" := WarehouseJournalLine."PMP15 Sub Merk 5";
        WarehouseEntry."PMP15 L/R" := WarehouseJournalLine."PMP15 L/R";
        WarehouseEntry."PMP15 Rework" := WarehouseJournalLine."PMP15 Rework";

        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
        WarehouseEntry."PMP15 Variant Changes (From)" := WarehouseJournalLine."PMP15 Variant Changes (From)";
        WarehouseEntry."PMP15 Variant Changes (To)" := WarehouseJournalLine."PMP15 Variant Changes (To)";
        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}

        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
        WarehouseEntry."PMP15 Crop" := WarehouseJournalLine."PMP15 Crop";
        WarehouseEntry."PMP15 Cycle (Separately)" := WarehouseJournalLine."PMP15 Cycle (Separately)";
        WarehouseEntry."PMP15 Invoice No." := WarehouseJournalLine."PMP15 Invoice No.";
        WarehouseEntry."PMP15 Delivery" := WarehouseJournalLine."PMP15 Delivery";
        WarehouseEntry."PMP15 Cycle Code" := WarehouseJournalLine."PMP15 Cycle Code";
        WarehouseEntry."PMP15 Output Item No." := WarehouseJournalLine."PMP15 Output Item No.";
        WarehouseEntry."PMP15 Output Variant Code" := WarehouseJournalLine."PMP15 Output Variant Code";
        WarehouseEntry."PMP15 Bin SOR Step" := WarehouseJournalLine."PMP15 Bin SOR Step";
        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
        WarehouseEntry.Modify();
    end;

    // ITEM JOURNAL LINE --> WAREHOUSE JOURNAL LINE (ITEM JOURNAL POSTING)
    /// <summary>Copies <b>PMP15 production, rework, variant change, and traceability fields</b> from the Item Journal Line to the Warehouse Journal Line after creation.</summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"WMS Management", OnAfterCreateWhseJnlLine, '', false, false)]
    local procedure PMP15CopyWhseJnlLinefromItemJnlLine_OnAfterCreateWhseJnlLine(var WhseJournalLine: Record "Warehouse Journal Line"; ItemJournalLine: Record "Item Journal Line"; ToTransfer: Boolean)
    var
        BinRec: Record Bin;
    begin
        BinRec.Reset();

        WhseJournalLine."PMP15 Prod. Order No." := ItemJournalLine."PMP15 Prod. Order No.";
        WhseJournalLine."PMP15 Production Type" := ItemJournalLine."PMP15 Production Type";
        WhseJournalLine."PMP15 Sub Merk 1" := ItemJournalLine."PMP15 Sub Merk 1";
        WhseJournalLine."PMP15 Sub Merk 2" := ItemJournalLine."PMP15 Sub Merk 2";
        WhseJournalLine."PMP15 Sub Merk 3" := ItemJournalLine."PMP15 Sub Merk 3";
        WhseJournalLine."PMP15 Sub Merk 4" := ItemJournalLine."PMP15 Sub Merk 4";
        WhseJournalLine."PMP15 Sub Merk 5" := ItemJournalLine."PMP15 Sub Merk 5";
        WhseJournalLine."PMP15 L/R" := ItemJournalLine."PMP15 L/R";
        WhseJournalLine."PMP15 Return" := ItemJournalLine."PMP15 Return";
        WhseJournalLine."PMP15 Return to Result Step" := ItemJournalLine."PMP15 Return to Result Step";
        WhseJournalLine."PMP15 Return to Result Code" := ItemJournalLine."PMP15 Return to Result Code";
        WhseJournalLine."PMP15 SOR Step" := ItemJournalLine."PMP15 SOR Step";
        WhseJournalLine."PMP15 SOR Step Code" := ItemJournalLine."PMP15 SOR Step Code";
        WhseJournalLine."PMP15 Tobacco Type" := ItemJournalLine."PMP15 Tobacco Type";
        WhseJournalLine."PMP15 Rework" := ItemJournalLine."PMP15 Rework";

        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
        WhseJournalLine."PMP15 Variant Changes (From)" := ItemJournalLine."PMP15 Variant Changes (From)";
        WhseJournalLine."PMP15 Variant Changes (To)" := ItemJournalLine."PMP15 Variant Changes (To)";
        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}

        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
        WhseJournalLine."PMP15 Crop" := ItemJournalLine."PMP15 Crop";
        WhseJournalLine."PMP15 Cycle (Separately)" := ItemJournalLine."PMP15 Cycle (Separately)";
        WhseJournalLine."PMP15 Invoice No." := ItemJournalLine."Invoice No.";
        WhseJournalLine."PMP15 Delivery" := ItemJournalLine."PMP15 Delivery";
        WhseJournalLine."PMP15 Cycle Code" := ItemJournalLine."PMP15 Cycle Code";
        WhseJournalLine."PMP15 Output Item No." := ItemJournalLine."PMP15 Output Item No.";
        WhseJournalLine."PMP15 Output Variant Code" := ItemJournalLine."PMP15 Output Variant Code";
        WhseJournalLine."PMP15 Bin SOR Step" := ItemJournalLine."PMP15 Bin SOR Step";
        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
    end;

    // WAREHOUSE JOURNAL LINE --> WAREHOUSE ENTRY (ITEM JOURNAL POSTING)
    /// <summary>Initializes the Warehouse Entry by copying <b>PMP15 production, rework, variant change, and traceability fields</b> from the Warehouse Journal Line during warehouse entry creation.</summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Whse. Jnl.-Register Line", OnInitWhseEntryCopyFromWhseJnlLine, '', false, false)]
    local procedure PMP15SetWhseEntryfromWhseJnlLine_OnInitWhseEntryCopyFromWhseJnlLine(var WarehouseEntry: Record "Warehouse Entry"; var WarehouseJournalLine: Record "Warehouse Journal Line"; OnMovement: Boolean; Sign: Integer; Location: Record Location; BinCode: Code[20]; var IsHandled: Boolean)
    begin
        WarehouseEntry."PMP15 Prod. Order No." := WarehouseJournalLine."PMP15 Prod. Order No.";
        WarehouseEntry."PMP15 Production Type" := WarehouseJournalLine."PMP15 Production Type";
        WarehouseEntry."PMP15 Sub Merk 1" := WarehouseJournalLine."PMP15 Sub Merk 1";
        WarehouseEntry."PMP15 Sub Merk 2" := WarehouseJournalLine."PMP15 Sub Merk 2";
        WarehouseEntry."PMP15 Sub Merk 3" := WarehouseJournalLine."PMP15 Sub Merk 3";
        WarehouseEntry."PMP15 Sub Merk 4" := WarehouseJournalLine."PMP15 Sub Merk 4";
        WarehouseEntry."PMP15 Sub Merk 5" := WarehouseJournalLine."PMP15 Sub Merk 5";
        WarehouseEntry."PMP15 L/R" := WarehouseJournalLine."PMP15 L/R";
        WarehouseEntry."PMP15 Return" := WarehouseJournalLine."PMP15 Return";
        WarehouseEntry."PMP15 Return to Result Step" := WarehouseJournalLine."PMP15 Return to Result Step";
        WarehouseEntry."PMP15 Return to Result Code" := WarehouseJournalLine."PMP15 Return to Result Code";
        WarehouseEntry."PMP15 SOR Step" := WarehouseJournalLine."PMP15 SOR Step";
        WarehouseEntry."PMP15 SOR Step Code" := WarehouseJournalLine."PMP15 SOR Step Code";
        WarehouseEntry."PMP15 Tobacco Type" := WarehouseJournalLine."PMP15 Tobacco Type";
        WarehouseEntry."PMP15 Rework" := WarehouseJournalLine."PMP15 Rework";

        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
        WarehouseEntry."PMP15 Variant Changes (From)" := WarehouseJournalLine."PMP15 Variant Changes (From)";
        WarehouseEntry."PMP15 Variant Changes (To)" := WarehouseJournalLine."PMP15 Variant Changes (To)";
        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - FINSIH >>>>>>>>>>>>>>>>>>>>>>>>>>}

        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
        WarehouseEntry."PMP15 Crop" := WarehouseJournalLine."PMP15 Crop";
        WarehouseEntry."PMP15 Cycle (Separately)" := WarehouseJournalLine."PMP15 Cycle (Separately)";
        WarehouseEntry."PMP15 Invoice No." := WarehouseJournalLine."PMP15 Invoice No.";
        WarehouseEntry."PMP15 Delivery" := WarehouseJournalLine."PMP15 Delivery";
        WarehouseEntry."PMP15 Cycle Code" := WarehouseJournalLine."PMP15 Cycle Code";
        WarehouseEntry."PMP15 Output Item No." := WarehouseJournalLine."PMP15 Output Item No.";
        WarehouseEntry."PMP15 Output Variant Code" := WarehouseJournalLine."PMP15 Output Variant Code";
        WarehouseEntry."PMP15 Bin SOR Step" := WarehouseJournalLine."PMP15 Bin SOR Step";
        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
    end;

    // ITEM JOURNAL LINE --> ITEM LEDGER ENTRY (ITEM JOURNAL POSTING)
    /// <summary>Copies <b>PMP15 production, rework, and variant change traceability fields</b> from the Item Journal Line to the newly created Item Ledger Entry after initialization.</summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", OnAfterInitItemLedgEntry, '', false, false)]
    local procedure PMP15SetItemLedEntryfromItemJnlLine_OnAfterInitItemLedgEntry(var NewItemLedgEntry: Record "Item Ledger Entry"; var ItemJournalLine: Record "Item Journal Line"; var ItemLedgEntryNo: Integer)
    begin
        NewItemLedgEntry."PMP15 Prod. Order No." := ItemJournalLine."PMP15 Prod. Order No.";
        NewItemLedgEntry."PMP15 Production Type" := ItemJournalLine."PMP15 Production Type";
        NewItemLedgEntry."PMP15 Sub Merk 1" := ItemJournalLine."PMP15 Sub Merk 1";
        NewItemLedgEntry."PMP15 Sub Merk 2" := ItemJournalLine."PMP15 Sub Merk 2";
        NewItemLedgEntry."PMP15 Sub Merk 3" := ItemJournalLine."PMP15 Sub Merk 3";
        NewItemLedgEntry."PMP15 Sub Merk 4" := ItemJournalLine."PMP15 Sub Merk 4";
        NewItemLedgEntry."PMP15 Sub Merk 5" := ItemJournalLine."PMP15 Sub Merk 5";
        NewItemLedgEntry."PMP15 L/R" := ItemJournalLine."PMP15 L/R";
        NewItemLedgEntry."PMP15 Return" := ItemJournalLine."PMP15 Return";
        NewItemLedgEntry."PMP15 Return to Result Step" := ItemJournalLine."PMP15 Return to Result Step";
        NewItemLedgEntry."PMP15 Return to Result Code" := ItemJournalLine."PMP15 Return to Result Code";
        NewItemLedgEntry."PMP15 SOR Step" := ItemJournalLine."PMP15 SOR Step";
        NewItemLedgEntry."PMP15 SOR Step Code" := ItemJournalLine."PMP15 SOR Step Code";
        NewItemLedgEntry."PMP15 Tobacco Type" := ItemJournalLine."PMP15 Tobacco Type";
        NewItemLedgEntry."PMP15 Rework" := ItemJournalLine."PMP15 Rework";

        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
        NewItemLedgEntry."PMP15 Variant Changes (From)" := ItemJournalLine."PMP15 Variant Changes (From)";
        NewItemLedgEntry."PMP15 Variant Changes (To)" := ItemJournalLine."PMP15 Variant Changes (To)";
        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
    end;

    /// <summary>Creates an Assembly Header document based on Sortation Order Recording data.</summary>
    /// <remarks>This procedure initializes and populates the Assembly Header fields using Sortation Order information and company setup configuration, then inserts the record.</remarks>
    /// <param name="AssemblyHeader">The Assembly Header record to be created and inserted.</param>
    /// <param name="ProdOrder">The related Production Order record.</param>
    /// <param name="SortProdOrderRec">The temporary Sortation Production Order Recording used as source data.</param>
    /// <param name="SORStep_Step">The Sortation Step Enum value applied to the Assembly Header.</param>
    procedure CreateAssemblyHeadfromSORRecording(var AssemblyHeader: Record "Assembly Header"; var ProdOrder: Record "Production Order"; SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary; SORStep_Step: Enum "PMP15 Sortation Step Enum")
    var
        LotNoInfo: Record "Lot No. Information";
        SORStepEnum: Enum "PMP15 Sortation Step Enum";
        SORStepCode: Code[20];
    begin
        LotNoInfo.Reset();
        ExtCompanySetup.Get();
        // 
        AssemblyHeader.Init();
        AssemblyHeader."Document Type" := AssemblyHeader."Document Type"::Order;
        AssemblyHeader."No." := NoSeriesMgmt.GetNextNo(ExtCompanySetup."PMP15 SOR Assembly Order Nos", WorkDate());
        AssemblyHeader.Validate("No. Series", ExtCompanySetup."PMP15 SOR Assembly Order Nos");
        AssemblyHeader.Validate("Posting No. Series", ExtCompanySetup."PMP15 SOR Pstd-Asmbly Ord. Nos");

        AssemblyHeader.InitRecord();

        // AssemblyHeader."Creation Date" := WorkDate();
        // if AssemblyHeader."Due Date" = 0D then
        //     AssemblyHeader."Due Date" := WorkDate();
        // AssemblyHeader."Posting Date" := WorkDate();
        // if AssemblyHeader."Starting Date" = 0D then
        //     AssemblyHeader."Starting Date" := WorkDate();
        // if AssemblyHeader."Ending Date" = 0D then
        //     AssemblyHeader."Ending Date" := WorkDate();
        // AssemblyHeader."Posting Date" := WorkDate();
        // AssemblyHeader."Due Date" := WorkDate();
        // AssemblyHeader."Ending Date" := WorkDate() - 1;
        // AssemblyHeader."Starting Date" := WorkDate() - 2;
        // AssemblyHeader.Validate("Posting Date", WorkDate());
        // AssemblyHeader.Validate("Due Date", WorkDate());

        AssemblyHeader.Validate("Item No.", SortProdOrderRec."Unsorted Item No.");
        AssemblyHeader.Validate("Variant Code", SortProdOrderRec."Unsorted Variant Code");
        AssemblyHeader.Validate("Location Code", SortProdOrderRec."Location Code");
        AssemblyHeader.Validate("Bin Code", SortProdOrderRec."To Bin Code");
        // AssemblyHeader.Validate(Quantity, SortProdOrderRec.Quantity);
        AssemblyHeader.Quantity := SortProdOrderRec.Quantity;
        AssemblyHeader.Validate("Unit of Measure Code", SortProdOrderRec."Unit of Measure Code");
        AssemblyHeader."PMP15 Prod. Order No." := SortProdOrderRec."Sortation Prod. Order No.";
        AssemblyHeader."PMP15 Production Type" := AssemblyHeader."PMP15 Production Type"::"SOR-Sortation";
        AssemblyHeader."PMP15 SOR Step" := SORStep_Step;
        SplitSORStepCodeMaster(SortProdOrderRec."Sortation Step", SORStepEnum, SORStepCode);
        AssemblyHeader."PMP15 SOR Step Code" := SORStepCode;
        AssemblyHeader."PMP15 Tobacco Type" := SortProdOrderRec."Tobacco Type";
        AssemblyHeader."PMP15 Sub Merk 1" := SortProdOrderRec."Submerk 1";
        AssemblyHeader."PMP15 Sub Merk 2" := SortProdOrderRec."Submerk 2";
        AssemblyHeader."PMP15 Sub Merk 3" := SortProdOrderRec."Submerk 3";
        AssemblyHeader."PMP15 Sub Merk 4" := SortProdOrderRec."Submerk 4";
        AssemblyHeader."PMP15 Sub Merk 5" := SortProdOrderRec."Submerk 5";
        AssemblyHeader."PMP15 L/R" := SortProdOrderRec."L/R";
        AssemblyHeader."PMP15 Rework" := SortProdOrderRec.Rework;


        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
        AssemblyHeader."PMP15 Sorted Item No." := SortProdOrderRec."Sorted Item No.";
        AssemblyHeader."PMP15 Sorted Variant Code" := SortProdOrderRec."Sorted Variant Code";
        if LotNoInformationIsExist(LotNoInfo, AssemblyHeader."Item No.", AssemblyHeader."Variant Code", SortProdOrderRec."Lot No.") then begin
            AssemblyHeader."PMP15 Lot No." := LotNoInfo."Lot No.";
        end else begin
            AssemblyHeader."PMP15 Lot No." := SortProdOrderRec."Lot No.";
            LotNoInfo.SetRange("Item No.", SortProdOrderRec."RM Item No.");
            LotNoInfo.SetRange("Variant Code", SortProdOrderRec."RM Variant Code");
            LotNoInfo.SetRange("Lot No.", SortProdOrderRec."Lot No.");
            if LotNoInfo.FindFirst() then begin
                CreateNewLotNoInformationfromOldLotNoInfo(LotNoInfo, AssemblyHeader."Item No.", AssemblyHeader."Variant Code", SortProdOrderRec."Lot No.");
            end else begin
                Error('No Lot No. Information available for receiving the Assembly Order output for Raw Material %1 - %2 during the creation of a new Lot No %3. Information record. Please review the current lot availability for the specified raw material.', SortProdOrderRec."RM Item No.", SortProdOrderRec."RM Variant Code", SortProdOrderRec."Lot No.");
            end;
        end;
        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
        AssemblyHeader.Insert();
    end;

    /// <summary>Creates an Assembly Line document based on Sortation Order Recording data.</summary>
    /// <remarks>This procedure initializes and populates the Assembly Line fields using related item and bin information, then inserts the line into the Assembly Order.</remarks>
    /// <param name="AssemblyLine">The Assembly Line record to be created and inserted.</param>
    /// <param name="AssemblyHeader">The parent Assembly Header to which the line will be linked.</param>
    /// <param name="ProdOrder">The related Production Order record.</param>
    /// <param name="SortProdOrderRec">The temporary Sortation Production Order Recording used as source data.</param>
    procedure CreateAssemblyLinefromSORRecording(var AssemblyLine: Record "Assembly Line"; var AssemblyHeader: Record "Assembly Header"; var ProdOrder: Record "Production Order"; SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary)
    var
        AsmLine: Record "Assembly Line";
        LastLineNo: Integer;
    begin
        AssemblyLine.Reset();
        AsmLine.Reset();
        Clear(LastLineNo);
        AsmLine.SetRange("Document No.", AssemblyHeader."No.");
        if AsmLine.FindLast() then begin
            LastLineNo := AsmLine."Line No.";
        end;

        if LastLineNo mod 10000 > 0 then begin
            LastLineNo += LastLineNo mod 10000;
        end else begin
            LastLineNo += 10000;
        end;

        AssemblyLine.Init();
        AssemblyLine.Validate("Document Type", AssemblyHeader."Document Type");
        AssemblyLine.Validate("Document No.", AssemblyHeader."No.");
        AssemblyLine.Validate("Line No.", LastLineNo);
        AssemblyLine.Validate(Type, AssemblyLine.Type::Item);
        AssemblyLine.Validate("No.", SortProdOrderRec."RM Item No.");
        AssemblyLine.Validate("Variant Code", SortProdOrderRec."RM Variant Code");
        AssemblyLine.Validate("Location Code", SortProdOrderRec."Location Code");
        AssemblyLine.Validate("Bin Code", SortProdOrderRec."From Bin Code");
        AssemblyLine.Validate("Quantity per", 1);
        AssemblyLine.Insert();
    end;

    /// <summary>Transfers item ledger tracking information into a temporary tracking specification record.</summary>
    /// <remarks>This procedure processes Item Ledger Entries containing tracking data and creates temporary reservation entries along with an entry summary for further tracking handling.</remarks>
    /// <param name="ItemLedgEntry">The Item Ledger Entry record to be evaluated and transferred.</param>
    /// <param name="TrackingSpecification">The temporary Tracking Specification record used to store processed tracking details.</param>
    procedure TransferItemLedgToTempRec(var ItemLedgEntry: Record "Item Ledger Entry"; var TrackingSpecification: Record "Tracking Specification" temporary)
    var
        IsHandled: Boolean;
    begin
        ItemLedgEntry.SetLoadFields(
          "Entry No.", "Item No.", "Variant Code", Positive, "Location Code", "Serial No.", "Lot No.", "Package No.",
          "Remaining Quantity", "Warranty Date", "Expiration Date");

        if ItemLedgEntry.FindSet() then
            repeat
                if ItemLedgEntry.TrackingExists() and
                   not TempGlobalReservEntry.Get(-ItemLedgEntry."Entry No.", ItemLedgEntry.Positive)
                then begin
                    TempGlobalReservEntry.Init();
                    TempGlobalReservEntry."Entry No." := -ItemLedgEntry."Entry No.";
                    TempGlobalReservEntry."Reservation Status" := TempGlobalReservEntry."Reservation Status"::Surplus;
                    TempGlobalReservEntry.Positive := ItemLedgEntry.Positive;
                    TempGlobalReservEntry."Item No." := ItemLedgEntry."Item No.";
                    TempGlobalReservEntry."Variant Code" := ItemLedgEntry."Variant Code";
                    TempGlobalReservEntry."Location Code" := ItemLedgEntry."Location Code";
                    TempGlobalReservEntry."Quantity (Base)" := ItemLedgEntry."Remaining Quantity";
                    TempGlobalReservEntry."Source Type" := Database::"Item Ledger Entry";
                    TempGlobalReservEntry."Source Ref. No." := ItemLedgEntry."Entry No.";
                    TempGlobalEntrySummary."Package No." := ItemLedgEntry."Package No.";
                    TempGlobalReservEntry.CopyTrackingFromItemLedgEntry(ItemLedgEntry);
                    if TempGlobalReservEntry.Positive then begin
                        TempGlobalReservEntry."Warranty Date" := ItemLedgEntry."Warranty Date";
                        TempGlobalReservEntry."Expiration Date" := ItemLedgEntry."Expiration Date";
                        TempGlobalReservEntry."Expected Receipt Date" := 0D
                    end else
                        TempGlobalReservEntry."Shipment Date" := DMY2Date(31, 12, 9999);

                    IsHandled := false;
                    if not IsHandled then begin
                        TempGlobalReservEntry.Insert();
                        CreateEntrySummary(TrackingSpecification, TempGlobalReservEntry);
                    end;
                end;
            until ItemLedgEntry.Next() = 0;
    end;

    ///<summary>Creates or updates entry summary records based on the provided tracking specification and reservation entry.</summary>
    local procedure CreateEntrySummary(TrackingSpecification: Record "Tracking Specification" temporary; TempReservEntry: Record "Reservation Entry" temporary)
    begin
        CreateEntrySummary2(TrackingSpecification, TempReservEntry, true);
        CreateEntrySummary2(TrackingSpecification, TempReservEntry, false);
    end;

    ///<summary>Updates the bin content quantity in the entry summary based on related warehouse entries.</summary>
    local procedure UpdateBinContent(var TempEntrySummary: Record "Entry Summary" temporary)
    var
        WarehouseEntry: Record "Warehouse Entry";
        WhseItemTrackingSetup: Record "Item Tracking Setup";
        IsHandled: Boolean;
    begin
        if CurrBinCode = '' then
            exit;

        CurrItemTrackingCode.TestField(Code);

        WarehouseEntry.Reset();
        WarehouseEntry.SetCurrentKey(
          "Item No.", "Bin Code", "Location Code", "Variant Code",
          "Unit of Measure Code", "Lot No.", "Serial No.", "Package No.");
        WarehouseEntry.SetRange("Item No.", TempGlobalReservEntry."Item No.");
        WarehouseEntry.SetRange("Bin Code", CurrBinCode);
        WarehouseEntry.SetRange("Location Code", TempGlobalReservEntry."Location Code");
        WarehouseEntry.SetRange("Variant Code", TempGlobalReservEntry."Variant Code");
        WhseItemTrackingSetup.CopyTrackingFromItemTrackingCodeWarehouseTracking(CurrItemTrackingCode);
        WhseItemTrackingSetup.CopyTrackingFromEntrySummary(TempEntrySummary);
        WarehouseEntry.SetTrackingFilterFromItemTrackingSetupIfRequiredIfNotBlank(WhseItemTrackingSetup);

        WarehouseEntry.CalcSums("Qty. (Base)");

        TempEntrySummary."Bin Content" := WarehouseEntry."Qty. (Base)";
    end;

    ///<summary>Builds or aggregates entry summary data for serial or non-serial tracked items derived from reservation entry details.</summary>
    local procedure CreateEntrySummary2(TempTrackingSpecification: Record "Tracking Specification" temporary; TempReservEntry: Record "Reservation Entry" temporary; SerialNoLookup: Boolean)
    var
        LateBindingManagement: Codeunit "Late Binding Management";
        DoInsert: Boolean;
    begin
        TempGlobalEntrySummary.Reset();
        TempGlobalEntrySummary.SetTrackingKey();

        if SerialNoLookup then begin
            if TempReservEntry."Serial No." = '' then
                exit;

            TempGlobalEntrySummary.SetTrackingFilterFromReservEntry(TempReservEntry);
        end else begin
            if not TempReservEntry.NonSerialTrackingExists() then
                exit;

            TempGlobalEntrySummary.SetRange("Serial No.", '');
            TempGlobalEntrySummary.SetNonSerialTrackingFilterFromReservEntry(TempReservEntry);
            if TempReservEntry."Serial No." <> '' then
                TempGlobalEntrySummary.SetRange("Table ID", 0)
            else
                TempGlobalEntrySummary.SetFilter("Table ID", '<>%1', 0);
        end;

        // If no summary exists, create new record
        if not TempGlobalEntrySummary.FindFirst() then begin
            TempGlobalEntrySummary.Init();
            TempGlobalEntrySummary."Entry No." := LastSummaryEntryNo + 1;
            LastSummaryEntryNo := TempGlobalEntrySummary."Entry No.";

            if not SerialNoLookup and (TempReservEntry."Serial No." <> '') then
                TempGlobalEntrySummary."Table ID" := 0 // Mark as summation
            else
                TempGlobalEntrySummary."Table ID" := TempReservEntry."Source Type";
            if SerialNoLookup then
                TempGlobalEntrySummary."Serial No." := TempReservEntry."Serial No."
            else
                TempGlobalEntrySummary."Serial No." := '';
            TempGlobalEntrySummary."Lot No." := TempReservEntry."Lot No.";
            TempGlobalEntrySummary."Package No." := TempReservEntry."Package No.";
            TempGlobalEntrySummary."Non Serial Tracking" := TempGlobalEntrySummary.HasNonSerialTracking();
            TempGlobalEntrySummary."Bin Active" := CurrBinCode <> '';
            UpdateBinContent(TempGlobalEntrySummary);

            DoInsert := true;
        end;

        // Sum up values
        if TempReservEntry.Positive then begin
            TempGlobalEntrySummary."Warranty Date" := TempReservEntry."Warranty Date";
            TempGlobalEntrySummary."Expiration Date" := TempReservEntry."Expiration Date";
            if TempReservEntry."Entry No." < 0 then begin // The record represents an Item ledger entry
                TempGlobalEntrySummary."Non-specific Reserved Qty." +=
                  LateBindingManagement.NonSpecificReservedQtyExceptForSource(-TempReservEntry."Entry No.", TempTrackingSpecification);
                TempGlobalEntrySummary."Total Quantity" += TempReservEntry."Quantity (Base)";
            end;
            if TempReservEntry."Reservation Status" = TempReservEntry."Reservation Status"::Reservation then
                TempGlobalEntrySummary."Total Reserved Quantity" += TempReservEntry."Quantity (Base)";
        end else begin
            TempGlobalEntrySummary."Total Requested Quantity" -= TempReservEntry."Quantity (Base)";
            if TempReservEntry.HasSamePointerWithSpec(TempTrackingSpecification) then begin
                if TempReservEntry."Reservation Status" = TempReservEntry."Reservation Status"::Reservation then
                    TempGlobalEntrySummary."Current Reserved Quantity" -= TempReservEntry."Quantity (Base)";
                if TempReservEntry."Entry No." > 0 then // The record represents a reservation entry
                    TempGlobalEntrySummary."Current Requested Quantity" -= TempReservEntry."Quantity (Base)";
            end;
        end;

        // Update available quantity on the record
        TempGlobalEntrySummary.UpdateAvailable();
        if DoInsert then
            TempGlobalEntrySummary.Insert()
        else
            TempGlobalEntrySummary.Modify();
    end;

    ///<summary>Collects tracking source data from item ledger and reservation entries to initialize temporary tracking structures.</summary>
    local procedure RetrieveLookupData(var TempTrackingSpecification: Record "Tracking Specification" temporary; FullDataSet: Boolean)
    var
        ItemLedgEntry: Record "Item Ledger Entry";
        ReservEntry: Record "Reservation Entry";
        TempReservEntry: Record "Reservation Entry" temporary;
        TempTrackingSpecification2: Record "Tracking Specification" temporary;
        LotNo, PackageNo : Code[50];
    begin
        // Reset Item Tracking Line Generator
        LastSummaryEntryNo := 0;
        // LastReservEntryNo := 2147483647;
        TempTrackingSpecification2 := TempTrackingSpecification;
        TempGlobalReservEntry.Reset();
        TempGlobalReservEntry.DeleteAll();
        TempGlobalEntrySummary.Reset();
        TempGlobalEntrySummary.DeleteAll();

        ItemLedgEntry.Reset();
        ItemLedgEntry.SetCurrentKey("Item No.", Open, "Variant Code", Positive, "Location Code", "Posting Date", "Entry No.");
        ItemLedgEntry.SetRange("Item No.", TempTrackingSpecification."Item No.");
        ItemLedgEntry.SetRange("Variant Code", TempTrackingSpecification."Variant Code");
        ItemLedgEntry.SetRange(Open, true);
        ItemLedgEntry.SetRange("Location Code", TempTrackingSpecification."Location Code");

        LotNo := '';
        PackageNo := '';
        TransferItemLedgToTempRec(ItemLedgEntry, TempTrackingSpecification);

        TempGlobalEntrySummary.Reset();
        TempTrackingSpecification := TempTrackingSpecification2;
    end;

    // ASSEMBLY HEADER (DOCUMENT)
    /// <summary>Generates item tracking details for the specified Assembly Header based on Sortation Order Recording data.</summary>
    /// <remarks>This procedure initializes tracking specification values using the Assembly Header context and creates associated lot and package tracking entries when applicable.</remarks>
    /// <param name="AssemblyHeader">The Assembly Header record for which the tracking specification will be generated.</param>
    /// <param name="ProdOrder">The related Production Order record.</param>
    /// <param name="SortProdOrderRec">The temporary Sortation Production Order Recording containing lot and package details.</param>
    procedure GenerateItemReservEntryAssemblyHeader(var AssemblyHeader: Record "Assembly Header"; var ProdOrder: Record "Production Order"; SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary)
    var
        Item: Record Item;
        ItemTrackingSetup: Record "Item Tracking Setup";
        RecReservEntry: Record "Reservation Entry";
        TempRecReservEntry: Record "Reservation Entry" temporary;
        TrackingSpecification: Record "Tracking Specification";
        TempTrackingSpecification: Record "Tracking Specification" temporary;
        CreateReserveMgmt: Codeunit "Create Reserv. Entry";
        // 
        TypeHelper: Codeunit "Type Helper";
        SourceTrackingSpecification: Record "Tracking Specification";
        ItemTrackingLine: Page "Item Tracking Lines";
        RecRef: RecordRef;
        ChangeType: Option Insert,Modify,FullDelete,PartDelete,ModifyAll;
    begin
        if AssemblyHeader.ReservEntryExist() then
            Error('Item tracking information already exists for this Assembly Order (%1). Please remove the existing tracking before proceeding.', AssemblyHeader."No.");

        Item.SetLoadFields("Item Tracking Code");
        if not Item.Get(AssemblyHeader."Item No.") then
            Error('The specified Item No. "%1" could not be found. Please verify that the item exists in the system.', AssemblyHeader."Item No.");

        RecRef.GetTable(Item);
        if Item."Item Tracking Code" = '' then
            PMPAppLogicMgmt.ErrorRecordRefwithAction(RecRef, Item.FieldNo(Description), Page::"Item Card", 'Empty Field', StrSubstNo('The Item "%1" does not have an assigned Item Tracking Code. Please configure the Item Tracking Code in the Item Card before continuing.', AssemblyHeader."Item No."));
        GetItemTrackingCode(Item."No.");

        AssemblyHeaderReserve.InitFromAsmHeader(TempTrackingSpecification, AssemblyHeader);
        TempTrackingSpecification.Insert();

        RetrieveLookupData(TempTrackingSpecification, true);
        TempTrackingSpecification.Delete();

        AssemblyHeaderReserve.InitFromAsmHeader(SourceTrackingSpecification, AssemblyHeader);
        SourceTrackingSpecification."Bin Code" := AssemblyHeader."Bin Code";
        ItemTrackingLine.SetSourceSpec(SourceTrackingSpecification, 0D);

        TempTrackingSpecification.Init;
        TempTrackingSpecification.TransferFields(SourceTrackingSpecification);
        TempTrackingSpecification.SetItemData(SourceTrackingSpecification."Item No.", SourceTrackingSpecification.Description, SourceTrackingSpecification."Location Code", SourceTrackingSpecification."Variant Code", SourceTrackingSpecification."Bin Code", SourceTrackingSpecification."Qty. per Unit of Measure");
        TempTrackingSpecification.Validate("Item No.", SourceTrackingSpecification."Item No.");
        TempTrackingSpecification.Validate("Location Code", SourceTrackingSpecification."Location Code");
        TempTrackingSpecification.Validate("Creation Date", DT2Date(TypeHelper.GetCurrentDateTimeInUserTimeZone()));
        TempTrackingSpecification.Validate("Source Type", SourceTrackingSpecification."Source Type");
        TempTrackingSpecification.Validate("Source Subtype", SourceTrackingSpecification."Source Subtype");
        TempTrackingSpecification.Validate("Source ID", SourceTrackingSpecification."Source ID");
        TempTrackingSpecification.Validate("Source Batch Name", SourceTrackingSpecification."Source Batch Name");
        TempTrackingSpecification.Validate("Source Prod. Order Line", SourceTrackingSpecification."Source Prod. Order Line");
        TempTrackingSpecification.Validate("Source Ref. No.", SourceTrackingSpecification."Source Ref. No.");

        TempGlobalEntrySummary.Reset();
        if ItemTrackingCode."Lot Specific Tracking" then
            TempGlobalEntrySummary.SetRange("Lot No.", SortProdOrderRec."Lot No.");
        if ItemTrackingCode."Package Specific Tracking" then
            TempGlobalEntrySummary.SetRange("Package No.", SortProdOrderRec."Package No.");
        if TempGlobalEntrySummary.FindSet() then begin
            if (TempGlobalEntrySummary."Serial No." <> '') AND ItemTrackingCode."SN Specific Tracking" then
                TempTrackingSpecification.Validate("Serial No.", TempGlobalEntrySummary."Serial No.");
            if (TempGlobalEntrySummary."Lot No." <> '') AND ItemTrackingCode."Lot Specific Tracking" then
                TempTrackingSpecification.Validate("Lot No.", TempGlobalEntrySummary."Lot No.");
            if (TempGlobalEntrySummary."Package No." <> '') AND ItemTrackingCode."Package Specific Tracking" then
                TempTrackingSpecification.Validate("Package No.", TempGlobalEntrySummary."Package No.");
        end else begin
            if ItemTrackingCode."Lot Specific Tracking" then
                TempTrackingSpecification.Validate("Lot No.", SortProdOrderRec."Lot No.");
            if ItemTrackingCode."Package Specific Tracking" then
                TempTrackingSpecification.Validate("Package No.", SortProdOrderRec."Package No.");
        end;
        TempTrackingSpecification.Validate("Quantity (Base)", AssemblyHeader."Quantity (Base)");
        TempTrackingSpecification.Validate("Qty. to Handle (Base)", AssemblyHeader."Quantity (Base)");
        TempTrackingSpecification.Validate("Qty. to Invoice (Base)", AssemblyHeader."Quantity (Base)");

        ItemTrackingLine.RegisterChange(TempTrackingSpecification, TempTrackingSpecification, ChangeType::Insert, false);
    end;

    // ASSEMBLY LINE (SUBFORM)
    /// <summary>Generates item tracking details for a specific Assembly Line based on Sortation Order Recording data.</summary>
    /// <remarks>This procedure initializes tracking specification values using the Assembly Line context and creates lot tracking entries when applicable.</remarks>
    /// <param name="AssemblyLine">The Assembly Line record for which the tracking specification will be generated.</param>
    /// <param name="ProdOrder">The related Production Order record.</param>
    /// <param name="SortProdOrderRec">The temporary Sortation Production Order Recording containing lot information.</param>
    procedure GenerateItemTrackingAssemblyLine(var AssemblyLine: Record "Assembly Line"; var ProdOrder: Record "Production Order"; SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary)
    var
        Item: Record Item;
        ItemTrackingSetup: Record "Item Tracking Setup";
        RecReservEntry: Record "Reservation Entry";
        TempRecReservEntry: Record "Reservation Entry" temporary;
        TrackingSpecification: Record "Tracking Specification";
        TempTrackingSpecification: Record "Tracking Specification" temporary;
        PackageNoInfo: Record "Package No. Information";
        // 
        RecRef: RecordRef;
    begin
        if AssemblyLine.ReservEntryExist() then
            Error('Item tracking information already exists for this Assembly Line (Line No. %1, Doc. No. %2). Please remove the existing tracking before proceeding.', AssemblyLine."Line No.", AssemblyLine."Document No.");

        Item.SetLoadFields("Item Tracking Code");
        if not Item.Get(AssemblyLine."No.") then
            Error('The specified Item No. "%1" could not be found. Please verify that the item exists in the system.', AssemblyLine."No.");

        RecRef.GetTable(Item);
        if Item."Item Tracking Code" = '' then
            PMPAppLogicMgmt.ErrorRecordRefwithAction(RecRef, Item.FieldNo(Description), Page::"Item Card", 'Empty Field', StrSubstNo('The Item "%1" does not have an assigned Item Tracking Code. Please configure the Item Tracking Code in the Item Card before continuing.', Item."No."));
        GetItemTrackingCode(Item."No.");

        if AssemblyLineReserve.ReservEntryExist(AssemblyLine) then
            Error(
                'Reservation entries already exist for Item "%1" in this Assembly Line. Please cancel or delete the existing reservations before performing this action.', AssemblyLine."No.");

        AssemblyLineReserve.InitFromAsmLine(TempTrackingSpecification, AssemblyLine);
        TempTrackingSpecification.Insert();

        RetrieveLookupData(TempTrackingSpecification, true);
        TempTrackingSpecification.Delete();
        TempGlobalEntrySummary.Reset();
        if ItemTrackingCode."Lot Specific Tracking" then
            TempGlobalEntrySummary.SetRange("Lot No.", SortProdOrderRec."Lot No.");
        if ItemTrackingCode."Package Specific Tracking" then
            TempGlobalEntrySummary.SetRange("Package No.", SortProdOrderRec."Package No.");
        if TempGlobalEntrySummary.FindFirst() then begin
            InsertReservEntryRecfromTempTrackSpecASMLINE(AssemblyLine, SortProdOrderRec, RecReservEntry, TempTrackingSpecification, TempGlobalEntrySummary."Lot No.", TempGlobalEntrySummary."Package No.");
        end else begin
            PackageNoInfo.SetAutoCalcFields();
            PackageNoInfo.SetRange("Item No.", AssemblyLine."No.");
            PackageNoInfo.SetFilter("Variant Code", AssemblyLine."Variant Code");
            PackageNoInfo.SetFilter("Package No.", SortProdOrderRec."Package No.");
            // PackageNoInfo.SetFilter("PMP04 Bin Code", AssemblyLine."Bin Code");
            PackageNoInfo.SetRange(Inventory, 0);
            if PackageNoInfo.FindFirst() then
                InsertReservEntryRecfromTempTrackSpecASMLINE(AssemblyLine, SortProdOrderRec, RecReservEntry, TempTrackingSpecification, PackageNoInfo."PMP04 Lot No.", PackageNoInfo."Package No.")
            else begin
                InsertReservEntryRecfromTempTrackSpecASMLINE(AssemblyLine, SortProdOrderRec, RecReservEntry, TempTrackingSpecification, SortProdOrderRec."Lot No.", SortProdOrderRec."Package No.")
            end;
        end;
    end;

    /// <summary>Creates and registers a <b>reservation entry tracking specification</b> for an Assembly Line, applying <b>lot and package tracking</b> based on Item Tracking Code configuration.</summary>
    local procedure InsertReservEntryRecfromTempTrackSpecASMLINE(var AssemblyLine: Record "Assembly Line"; SortProdOrderRec: Record "PMP15 Sortation PO Recording"; var RecReservEntry: Record "Reservation Entry"; TempTrackingSpecification: Record "Tracking Specification" temporary; LotNo: Code[50]; PackageNo: Code[50])
    var
        TypeHelper: Codeunit "Type Helper";
        SourceTrackingSpecification: Record "Tracking Specification";
        ItemTrackingLine: Page "Item Tracking Lines";
        RecRef: RecordRef;
        ChangeType: Option Insert,Modify,FullDelete,PartDelete,ModifyAll;
    begin
        AssemblyLineReserve.InitFromAsmLine(SourceTrackingSpecification, AssemblyLine);
        ItemTrackingLine.SetSourceSpec(SourceTrackingSpecification, 0D);

        TempTrackingSpecification.Init;
        TempTrackingSpecification.TransferFields(SourceTrackingSpecification);
        TempTrackingSpecification.SetItemData(SourceTrackingSpecification."Item No.", SourceTrackingSpecification.Description, SourceTrackingSpecification."Location Code", SourceTrackingSpecification."Variant Code", SourceTrackingSpecification."Bin Code", SourceTrackingSpecification."Qty. per Unit of Measure");
        TempTrackingSpecification.Validate("Item No.", SourceTrackingSpecification."Item No.");
        TempTrackingSpecification.Validate("Location Code", SourceTrackingSpecification."Location Code");
        // TempTrackingSpecification.Validate("Creation Date", Today);
        TempTrackingSpecification.Validate("Creation Date", DT2Date(TypeHelper.GetCurrentDateTimeInUserTimeZone()));
        TempTrackingSpecification.Validate("Source Type", SourceTrackingSpecification."Source Type");
        TempTrackingSpecification.Validate("Source Subtype", SourceTrackingSpecification."Source Subtype");
        TempTrackingSpecification.Validate("Source ID", SourceTrackingSpecification."Source ID");
        TempTrackingSpecification.Validate("Source Batch Name", SourceTrackingSpecification."Source Batch Name");
        TempTrackingSpecification.Validate("Source Prod. Order Line", SourceTrackingSpecification."Source Prod. Order Line");
        TempTrackingSpecification.Validate("Source Ref. No.", SourceTrackingSpecification."Source Ref. No.");

        if (LotNo <> '') AND ItemTrackingCode."Lot Specific Tracking" then
            TempTrackingSpecification.Validate("Lot No.", LotNo);
        if (PackageNo <> '') AND ItemTrackingCode."Package Specific Tracking" then
            TempTrackingSpecification.Validate("Package No.", PackageNo);

        TempTrackingSpecification.Validate("Quantity (Base)", AssemblyLine."Quantity (Base)");
        TempTrackingSpecification.Validate("Qty. to Handle (Base)", AssemblyLine."Quantity (Base)");
        TempTrackingSpecification.Validate("Qty. to Invoice (Base)", AssemblyLine."Quantity (Base)");
        ItemTrackingLine.RegisterChange(TempTrackingSpecification, TempTrackingSpecification, ChangeType::Insert, false);
        // AssemblyLineReserve.InitFromAsmLine(TempTrackingSpecification, AssemblyLine);
        // TempTrackingSpecification."Lot No." := SortProdOrderRec."Lot No.";
        // TempTrackingSpecification."Entry No." := NextTrackingSpecEntryNo;
        // TempTrackingSpecification.Validate("Bin Code", AssemblyLine."Bin Code");
        // TempTrackingSpecification.Validate("Lot No.", LotNo);
        // TempTrackingSpecification.Validate("Package No.", PackageNo);
        // TempTrackingSpecification.Positive := true;
        // TempTrackingSpecification."Creation Date" := Today();
        // TempTrackingSpecification.Insert();

        // CreateReservEntryFrom(RecReservEntry, TempTrackingSpecification);
        // RecReservEntry."Entry No." := NextReservEntryNo();
        // RecReservEntry."Reservation Status" := RecReservEntry."Reservation Status"::Surplus;
        // RecReservEntry.Insert();
    end;

    // ASSEMBLY LINE (SUBFORM) FROM THE DOCUMENT (ITERATING)
    /// <summary>Generates item tracking details for all Assembly Lines within the specified Assembly Header document.</summary>
    /// <remarks>This procedure iterates through Assembly Lines linked to the given Assembly Header and applies item tracking generation for each line.</remarks>
    /// <param name="AssemblyHeader">The Assembly Header document that contains the Assembly Lines to be processed.</param>
    /// <param name="ProdOrder">The related Production Order record.</param>
    /// <param name="SortProdOrderRec">The temporary Sortation Production Order Recording containing lot information.</param>
    procedure GenerateItemTrackingAssemblyLine(AssemblyHeader: Record "Assembly Header"; var ProdOrder: Record "Production Order"; SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary)
    var
        TrackingSpecification: Record "Tracking Specification";
        TempTrackingSpecification: Record "Tracking Specification" temporary;
        LotNoInfoList: Record "Lot No. Information";
        AssemblyLine: Record "Assembly Line";
    begin
        AssemblyLine.Reset();
        AssemblyLine.SetRange("Document No.", AssemblyHeader."No.");
        AssemblyLine.SetRange("Document Type", AssemblyHeader."Document Type");
        if AssemblyLine.FindSet() then begin
            GenerateItemTrackingAssemblyLine(AssemblyLine, ProdOrder, SortProdOrderRec);
        end;
    end;

    /// <summary>Deletes <b>all Assembly Lines</b> associated with the specified <b>Assembly Document</b> (Document No. and Document Type).</summary>
    local procedure DeleteAllAssemblyLineinDocumentOrder(AssemblyHeader: Record "Assembly Header")
    var
        AssemblyLine: Record "Assembly Line";
    begin
        AssemblyLine.Reset();
        AssemblyLine.SetRange("Document No.", AssemblyHeader."No.");
        AssemblyLine.SetRange("Document Type", AssemblyHeader."Document Type");
        AssemblyLine.DeleteAll(true);
    end;

    /// <summary>Overload procedure that initializes a test insertion of an Item Journal Line for a Sortation Order without specifying the Item Ledger Entry Type.</summary>
    /// <remarks>Delegates to the main <c>Test_InsertItemJnlLine</c> procedure with a default blank entry type to simplify initial test calls.</remarks>
    /// <param name="ItemJnlLine">Target Item Journal Line record for testing insertion.</param>
    /// <param name="tempItemJnlLine">Temporary Item Journal Line source used during the test process.</param>
    /// <param name="SortProdOrderRec">Temporary Sortation Production Order Recording containing sortation details.</param>
    /// <param name="SORStep_Step">Sortation Step enum that identifies the current stage of sortation.</param>
    /// <returns><c>true</c> if the test insertion process completes successfully; otherwise, <c>false</c>.</returns>
    procedure Test_InsertItemJnlLine(ItemJnlLine: Record "Item Journal Line"; var tempItemJnlLine: Record "Item Journal Line" temporary; var SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary; SORStep_Step: Enum "PMP15 Sortation Step Enum"): Boolean
    var
        ProdOrdLine: Record "Prod. Order Line";
        ProdOrdRoutingLine: Record "Prod. Order Routing Line";
        ProdOrdComp: Record "Prod. Order Component";
    begin
        exit(Test_InsertItemJnlLine(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine."Entry Type"::" "));
    end;

    /// <summary>Overload procedure that performs a test insertion of an Item Journal Line for a Sortation Order with a specified Item Ledger Entry Type.</summary>
    /// <remarks>Serves as an intermediate overload, passing parameters to the main test insertion procedure including the defined entry type for more granular control.</remarks>
    /// <param name="ItemJnlLine">Target Item Journal Line record for testing insertion.</param>
    /// <param name="tempItemJnlLine">Temporary Item Journal Line source used during the test process.</param>
    /// <param name="SortProdOrderRec">Temporary Sortation Production Order Recording containing process details.</param>
    /// <param name="SORStep_Step">Sortation Step enum identifying the current sortation stage.</param>
    /// <param name="IJLEntryType">Specifies the Item Ledger Entry Type to use in the test (Output, Consumption, Transfer, etc.).</param>
    /// <returns><c>true</c> if the test insertion process completes successfully; otherwise, <c>false</c>.</returns>
    procedure Test_InsertItemJnlLine(ItemJnlLine: Record "Item Journal Line"; var tempItemJnlLine: Record "Item Journal Line" temporary; var SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary; SORStep_Step: Enum "PMP15 Sortation Step Enum"; IJLEntryType: Enum "Item Ledger Entry Type"): Boolean
    var
        ProdOrdLine: Record "Prod. Order Line";
        ProdOrdRoutingLine: Record "Prod. Order Routing Line";
        ProdOrdComp: Record "Prod. Order Component";
    begin
        exit(Test_InsertItemJnlLine(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step, IJLEntryType, ProdOrdLine, ProdOrdRoutingLine, ProdOrdComp));
    end;

    // ONE OF THE MOST IMPORTANT FUNCTION IN THIS CODEUNIT
    /// <summary>Creates and inserts a new Item Journal Line for Sortation Order Reclassification based on the given temporary journal, production order, and sortation step.</summary>
    /// <remarks>Determines the next journal line number, validates item and production data, and inserts the appropriate journal entry depending on sortation step and tobacco type (Wrapper, PW, or Filler).</remarks>
    /// <param name="ItemJnlLine">Target Item Journal Line record for insertion.</param>
    /// <param name="tempItemJnlLine">Temporary Item Journal Line source record.</param>
    /// <param name="SortProdOrderRec">Temporary Sortation Production Order Recording containing process context.</param>
    /// <param name="SORStep_Step">Sortation Step enum defining the current sortation stage.</param>
    /// <param name="IJLEntryType">Specifies the Item Ledger Entry Type (Output, Consumption, Transfer, etc.).</param>
    /// <param name="PrOL">Production Order Line record related to the journal entry.</param>
    /// <param name="PrORL">Production Order Routing Line record associated with the process.</param>
    /// <param name="PrOComp">Production Order Component record representing the material component.</param>
    /// <returns><c>true</c> if the journal line was successfully inserted; otherwise, <c>false</c>.</returns>
    procedure Test_InsertItemJnlLine(var ItemJnlLine: Record "Item Journal Line"; var tempItemJnlLine: Record "Item Journal Line" temporary; var SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary; SORStep_Step: Enum "PMP15 Sortation Step Enum"; IJLEntryType: Enum "Item Ledger Entry Type"; PrOL: Record "Prod. Order Line"; PrORL: Record "Prod. Order Routing Line"; PrOComp: Record "Prod. Order Component"): Boolean
    var
        IJL: Record "Item Journal Line";
        Item: Record Item;
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ExtCompanySetup: Record "PMP07 Extended Company Setup";
        ProdOrderRec: Record "Production Order";
        ProdOrdLine: Record "Prod. Order Line";
        ProdOrdComp: Record "Prod. Order Component";
        ProdOrdRoutingLine: Record "Prod. Order Routing Line";
        LotNoInfoRec: Record "Lot No. Information";
        OldLotNoInfoRec: Record "Lot No. Information";
        BinContent: Record "Bin Content";
        BinRec: Record Bin;
        SORPackageNo: Code[50];
        LastLineNo: Integer;
        SORCrop: Text[50];
        IsInsertSortation: Boolean;
    begin
        BinRec.Reset();
        BinContent.Reset();
        ExtCompanySetup.Reset();
        IJL.Reset();
        ItemJnlTemplate.Reset();
        ItemJnlBatch.Reset();
        Item.Reset();
        LotNoInfoRec.Reset();
        OldLotNoInfoRec.Reset();
        ProdOrderRec.Reset();
        ProdOrdLine.Reset();
        ProdOrdComp.Reset();
        ProdOrdRoutingLine.Reset();
        Clear(IsInsertSortation);
        Clear(SORPackageNo);
        Clear(SORCrop);

        ExtCompanySetup.Get();

        if IJLEntryType = IJLEntryType::Consumption then begin
            IJL.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Output Jnl. Template");
            IJL.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Output Jnl. Batch");
            if IJL.FindLast() then
                LastLineNo := IJL."Line No.";
        end else if IJLEntryType = IJLEntryType::Output then begin
            IJL.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Template");
            IJL.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch");
            if IJL.FindLast() then
                LastLineNo := IJL."Line No.";
        end else begin
            IJL.SetRange("Journal Template Name", ItemJnlLine."Journal Template Name");
            IJL.SetRange("Journal Batch Name", ItemJnlLine."Journal Batch Name");
            if IJL.FindLast() then
                LastLineNo := IJL."Line No.";
        end;

        if LastLineNo mod 10000 > 0 then
            LastLineNo += LastLineNo mod 10000
        else
            LastLineNo += 10000;

        if (SORStep_Step = SORStep_Step::"1") OR (SORStep_Step = SORStep_Step::"2") OR (SORStep_Step = SORStep_Step::"3") then begin
            #region TestItemJnlLine STEP 1-3
            // SORTATION STEP FROM 0 TO 3, AS THE POSTING USING ITEM RECLASSIFICATION JOURNAL
            if Item.Get(SortProdOrderRec."Unsorted Item No.") then begin
                tempItemJnlLine.Init();
                tempItemJnlLine."Journal Template Name" := ExtCompanySetup."PMP15SORItemReclass.Jnl.Tmpt.";
                tempItemJnlLine."Journal Batch Name" := ExtCompanySetup."PMP15SORItemReclass.Jnl.Batch";
                tempItemJnlLine."Line No." := LastLineNo;
                if ItemJnlTemplate.Get(ExtCompanySetup."PMP15SORItemReclass.Jnl.Tmpt.") then begin
                    tempItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
                end;
                // tempItemJnlLine."Source Code" := 'RECLASSJNL';
                if ItemJnlBatch.Get(ExtCompanySetup."PMP15SORItemReclass.Jnl.Tmpt.", ExtCompanySetup."PMP15SORItemReclass.Jnl.Batch") then begin
                    if ItemJnlBatch."No. Series" <> '' then begin
                        tempItemJnlLine."Document No." := NoSeriesBatchMgmt.PeekNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                    end;
                end;
                tempItemJnlLine.Validate("Posting Date", SortProdOrderRec."Posting Date");
                tempItemJnlLine.Validate("Entry Type", tempItemJnlLine."Entry Type"::Transfer);
                tempItemJnlLine.Validate("Item No.", Item."No.");
                tempItemJnlLine.Description := Item.Description;
                tempItemJnlLine.Validate("Variant Code", SortProdOrderRec."Unsorted Variant Code");
                tempItemJnlLine.Validate("Location Code", SortProdOrderRec."Location Code");
                tempItemJnlLine.Validate(Quantity, SortProdOrderRec.Quantity);
                tempItemJnlLine.Validate("Bin Code", SortProdOrderRec."From Bin Code");
                tempItemJnlLine.Validate("New Bin Code", SortProdOrderRec."To Bin Code");

                // tempItemJnlLine."Lot No." := SortProdOrderRec."Lot No.";
                // tempItemJnlLine.Validate("New Lot No.", SortProdOrderRec."Lot No.");
                tempItemJnlLine.Validate("Unit of Measure Code", SortProdOrderRec."Unit of Measure Code");

                //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                // LotNoInfoRec.Get(tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SortProdOrderRec."Lot No.");
                if not LotNoInformationIsExist(LotNoInfoRec, tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SortProdOrderRec."Lot No.") then begin
                    OldLotNoInfoRec.SetRange("Item No.", SortProdOrderRec."Unsorted Item No.");
                    OldLotNoInfoRec.SetRange("Variant Code", SortProdOrderRec."Unsorted Variant Code");
                    OldLotNoInfoRec.SetRange("Lot No.", SortProdOrderRec."Lot No.");
                    if OldLotNoInfoRec.FindFirst() then begin
                        LotNoInfoRec := CreateNewLotNoInformationfromOldLotNoInfo(OldLotNoInfoRec, tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SortProdOrderRec."Lot No.");
                    end else begin
                        Error('No Lot No. Information available for the Item Reclass for the Unsorted Item %1 - %2 during the creation of a new Lot No %3. Information record. Please review the current lot availability for the specified raw material.', SortProdOrderRec."Unsorted Item No.", SortProdOrderRec."Unsorted Variant Code", SortProdOrderRec."Lot No.");
                    end;
                end;

                tempItemJnlLine."PMP15 Crop" := LotNoInfoRec."PMP14 Crop";
                tempItemJnlLine."PMP15 Cycle (Separately)" := LotNoInfoRec."PMP14 Cycle (Separately)";
                tempItemJnlLine."Invoice No." := LotNoInfoRec."PMP14 Invoice No.";
                tempItemJnlLine."PMP15 Delivery" := LotNoInfoRec."PMP14 Delivery";
                tempItemJnlLine."PMP15 Cycle Code" := LotNoInfoRec."PMP14 Cycle Code";
                tempItemJnlLine."PMP15 Output Item No." := SortProdOrderRec."Sorted Item No.";
                tempItemJnlLine."PMP15 Output Variant Code" := SortProdOrderRec."Sorted Variant Code";
                //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}

                IsInsertSortation := true;
            end else
                Error('There is no existing Item no. of %1 in the table', SortProdOrderRec."Unsorted Item No.");
            #endregion TestItemJnlLine STEP 0-3
        end else if (SORStep_Step = SORStep_Step::"4") AND (SortProdOrderRec."Tobacco Type" = SortProdOrderRec."Tobacco Type"::Wrapper) AND (SortProdOrderRec."Variant Changes" = '') then begin
            #region TestItemJnlLine STEP 4 - WRAPPER
            // WRAPPER SECTION
            if IJLEntryType = IJLEntryType::Consumption then begin
                ProdOrderRec.SetRange("No.", SortProdOrderRec."Sortation Prod. Order No.");
                if not ProdOrderRec.FindFirst() then
                    Error('Production Order No. must not be blank. Please specify a valid Production Order No. before continuing.');

                // if Item.Get(SortProdOrderRec."Sorted Item No.") then begin
                tempItemJnlLine.Init();
                tempItemJnlLine."Journal Template Name" := ExtCompanySetup."PMP15 SOR Consum.Jnl. Template";
                tempItemJnlLine."Journal Batch Name" := ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch";
                tempItemJnlLine."Line No." := LastLineNo;
                if ItemJnlTemplate.Get(ExtCompanySetup."PMP15 SOR Consum.Jnl. Template") then begin
                    tempItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
                end;
                // tempItemJnlLine."Source Code" := 'CONSUMPJNL';
                tempItemJnlLine."Source Type" := tempItemJnlLine."Source Type"::Item;
                if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Consum.Jnl. Template", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch") then begin
                    if ItemJnlBatch."No. Series" <> '' then begin
                        tempItemJnlLine."Document No." := NoSeriesBatchMgmt.PeekNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                    end;
                end;
                tempItemJnlLine.Validate("Posting Date", SortProdOrderRec."Posting Date");
                tempItemJnlLine.Validate("Entry Type", tempItemJnlLine."Entry Type"::Consumption);
                tempItemJnlLine.Validate("Order Type", tempItemJnlLine."Order Type"::Production);
                tempItemJnlLine.Validate("Order No.", SortProdOrderRec."Sortation Prod. Order No.");

                ProdOrdComp.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                ProdOrdComp.SetRange("PMP15 Unsorted Item", true);
                if ProdOrdComp.FindFirst() then begin
                    tempItemJnlLine.Validate("Item No.", ProdOrdComp."Item No.");
                    tempItemJnlLine.Validate("Variant Code", ProdOrdComp."Variant Code");
                    tempItemJnlLine.Validate("Prod. Order Comp. Line No.", ProdOrdComp."Line No.");
                end;

                ProdOrdLine.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                ProdOrdLine.SetRange("Item No.", SortProdOrderRec."Sorted Item No.");
                ProdOrdLine.SetFilter("Variant Code", SortProdOrderRec."Sorted Variant Code");
                if ProdOrdLine.FindFirst() then begin
                    tempItemJnlLine.Validate("Order Line No.", ProdOrdLine."Line No.");
                    tempItemJnlLine.Validate("Location Code", ProdOrdLine."Location Code");
                end;

                tempItemJnlLine.Validate(Quantity, SortProdOrderRec.Quantity);
                tempItemJnlLine.Validate("Unit of Measure Code", SortProdOrderRec."Unit of Measure Code");
                tempItemJnlLine."Work Shift Code" := SortProdOrderRec."Work Shift Code";
                tempItemJnlLine."Bin Code" := SortProdOrderRec."From Bin Code";
                // tempItemJnlLine.Validate("Lot No.", SortProdOrderRec."Lot No.");

                //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                if LotNoInfoRec.Get(tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SortProdOrderRec."Lot No.") then begin
                    tempItemJnlLine."PMP15 Crop" := LotNoInfoRec."PMP14 Crop";
                    tempItemJnlLine."PMP15 Cycle (Separately)" := LotNoInfoRec."PMP14 Cycle (Separately)";
                    tempItemJnlLine."Invoice No." := LotNoInfoRec."PMP14 Invoice No.";
                    tempItemJnlLine."PMP15 Delivery" := LotNoInfoRec."PMP14 Delivery";
                    tempItemJnlLine."PMP15 Cycle Code" := LotNoInfoRec."PMP14 Cycle Code";
                    tempItemJnlLine."PMP15 Output Item No." := SortProdOrderRec."Sorted Item No.";
                    tempItemJnlLine."PMP15 Output Variant Code" := SortProdOrderRec."Sorted Variant Code";
                end;


                tempItemJnlLine."PMP15 Marked" := true;
                //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}

                IsInsertSortation := true;

                // // STOP & CUT IT HERE TO INSERT THE RELATED ITEM JOURNAL LINE
                // if tempItemJnlLine.Insert() then
                //     exit(true)
                // else
                //     exit(false);
                // end;
            end else begin
                ProdOrderRec.SetRange("No.", SortProdOrderRec."Sortation Prod. Order No.");
                if not ProdOrderRec.FindFirst() then
                    Error('Production Order No. must not be blank. Please specify a valid Production Order No. before continuing.');

                if Item.Get(SortProdOrderRec."Sorted Item No.") then begin
                    tempItemJnlLine.Init();
                    tempItemJnlLine."Journal Template Name" := ExtCompanySetup."PMP15 SOR Output Jnl. Template";
                    tempItemJnlLine."Journal Batch Name" := ExtCompanySetup."PMP15 SOR Output Jnl. Batch";
                    tempItemJnlLine."Line No." := LastLineNo;
                    if ItemJnlTemplate.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template") then begin
                        tempItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
                    end;
                    // tempItemJnlLine."Source Code" := 'POINOUTJNL';
                    if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template", ExtCompanySetup."PMP15 SOR Output Jnl. Batch") then begin
                        if ItemJnlBatch."No. Series" <> '' then begin
                            tempItemJnlLine."Document No." := NoSeriesBatchMgmt.PeekNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                        end;
                    end;
                    tempItemJnlLine.Validate("Posting Date", SortProdOrderRec."Posting Date");
                    tempItemJnlLine.Validate("Entry Type", tempItemJnlLine."Entry Type"::Output);
                    tempItemJnlLine.Validate("Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                    tempItemJnlLine.Validate("Order Type", tempItemJnlLine."Order Type"::Production);
                    tempItemJnlLine.Validate("Item No.", Item."No.");
                    tempItemJnlLine.Description := Item.Description;
                    tempItemJnlLine.Validate("Variant Code", SortProdOrderRec."Sorted Variant Code");
                    tempItemJnlLine.Validate("Output Quantity", SortProdOrderRec.Quantity);
                    tempItemJnlLine.Validate("Unit of Measure Code", SortProdOrderRec."Unit of Measure Code");

                    ProdOrdLine.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                    ProdOrdLine.SetRange("Item No.", Item."No.");
                    ProdOrdLine.SetFilter("Variant Code", SortProdOrderRec."Sorted Variant Code");
                    if ProdOrdLine.FindFirst() then begin
                        tempItemJnlLine.Validate("Location Code", ProdOrdLine."Location Code");
                        tempItemJnlLine.Validate("Order Line No.", ProdOrdLine."Line No.");
                    end;

                    if tempItemJnlLine."Order Line No." <> 0 then begin
                        ProdOrdRoutingLine.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                        ProdOrdRoutingLine.SetRange("Routing Reference No.", tempItemJnlLine."Order Line No.");
                        if ProdOrdRoutingLine.FindLast() then begin
                            tempItemJnlLine.Validate("Operation No.", ProdOrdRoutingLine."Operation No.");
                        end;
                    end;
                    tempItemJnlLine."Work Shift Code" := SortProdOrderRec."Work Shift Code";
                    tempItemJnlLine.Validate("Bin Code", SortProdOrderRec."To Bin Code");

                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/15 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/05 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                    if not LotNoInformationIsExist(LotNoInfoRec, tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SortProdOrderRec."Lot No.") then begin
                        OldLotNoInfoRec.SetRange("Item No.", SortProdOrderRec."Unsorted Item No.");
                        OldLotNoInfoRec.SetRange("Variant Code", SortProdOrderRec."Unsorted Variant Code");
                        OldLotNoInfoRec.SetRange("Lot No.", SortProdOrderRec."Lot No.");
                        if OldLotNoInfoRec.FindFirst() then begin
                            LotNoInfoRec := CreateNewLotNoInformationfromOldLotNoInfo(OldLotNoInfoRec, tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SortProdOrderRec."Lot No.");
                        end else begin
                            Error('No Lot No. Information available for the Output Journal for the Unsorted Item %1 - %2 during the creation of a new Lot No %3. Information record with the Tobacco Type of %4. Please review the current lot availability for the specified raw material.', SortProdOrderRec."Unsorted Item No.", SortProdOrderRec."Unsorted Variant Code", SortProdOrderRec."Lot No.", SortProdOrderRec."Tobacco Type");
                        end;
                    end;
                    tempItemJnlLine."Lot No." := LotNoInfoRec."Lot No.";
                    tempItemJnlLine."PMP15 Crop" := LotNoInfoRec."PMP14 Crop";
                    tempItemJnlLine."PMP15 Cycle (Separately)" := LotNoInfoRec."PMP14 Cycle (Separately)";
                    tempItemJnlLine."Invoice No." := LotNoInfoRec."PMP14 Invoice No.";
                    tempItemJnlLine."PMP15 Delivery" := LotNoInfoRec."PMP14 Delivery";
                    tempItemJnlLine."PMP15 Cycle Code" := LotNoInfoRec."PMP14 Cycle Code";
                    tempItemJnlLine."PMP15 Output Item No." := SortProdOrderRec."Sorted Item No.";
                    tempItemJnlLine."PMP15 Output Variant Code" := SortProdOrderRec."Sorted Variant Code";

                    // if (SortProdOrderRec."Package No." <> '') OR (SortProdOrderRec."Package No." <> ' ') then
                    if PackageNoIsExist(tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SortProdOrderRec."Package No.") then
                        tempItemJnlLine.Validate("Package No.", SortProdOrderRec."Package No.")
                    else begin
                        if Item."PMP04 Package Nos" = '' then begin
                            Validate_TestInsertItemJnlLine_ITEMPMP04PackageNos(NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos"), Item."No.");
                        end;
                        if NoSeriesMgmt.PeekNextNo(Item."PMP04 Package Nos") <> '' then
                            // if ProdOrderRec."PMP15 Crop" = 0 then begin
                            if ProdOrderRec."PMP15 Crop" = '' then begin
                                LotNoInfoRec.Reset();
                                LotNoInfoRec.SetRange("Item No.", ItemJnlLine."Item No.");
                                LotNoInfoRec.SetRange("Variant Code", ItemJnlLine."Variant Code");
                                LotNoInfoRec.SetRange("Lot No.", SortProdOrderRec."Lot No.");
                                if LotNoInfoRec.FindFirst() AND (LotNoInfoRec."PMP14 Crop" <> '') then begin
                                    SORCrop := LotNoInfoRec."PMP14 Crop";
                                end else begin
                                    SORCrop := Format(Date2DMY(WorkDate(), 3));
                                end;
                                SORPackageNo := COPYSTR(Format(SORCrop), STRLEN(Format(SORCrop)) - 1, 2) + NoSeriesMgmt.GetNextNo(Item."PMP04 Package Nos");
                            end else
                                SORPackageNo := COPYSTR(Format(ProdOrderRec."PMP15 Crop"), STRLEN(Format(ProdOrderRec."PMP15 Crop")) - 1, 2) + NoSeriesMgmt.GetNextNo(Item."PMP04 Package Nos");
                        tempItemJnlLine.Validate("Package No.", SORPackageNo);

                        CreateNewPackagefromItemJnlLineOutput(tempItemJnlLine, SortProdOrderRec);
                    end;
                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/05 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}

                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/15 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
                end;

                IsInsertSortation := true;
            end;
            #endregion TestItemJnlLine STEP 4 - WRAPPER
        end else if (SORStep_Step = SORStep_Step::"4") AND (SortProdOrderRec."Tobacco Type" = SortProdOrderRec."Tobacco Type"::PW) AND (SortProdOrderRec."Variant Changes" = '') then begin
            #region TestItemJnlLine STEP 4 - PW
            // SORTATION PW SECTION
            if IJLEntryType = IJLEntryType::Consumption then begin
                ProdOrderRec.SetRange("No.", SortProdOrderRec."Sortation Prod. Order No.");
                if ProdOrderRec.FindFirst() then begin
                    if Item.Get(SortProdOrderRec."Unsorted Item No.") then begin
                        tempItemJnlLine.Init();
                        tempItemJnlLine."Journal Template Name" := ExtCompanySetup."PMP15 SOR Consum.Jnl. Template";
                        tempItemJnlLine."Journal Batch Name" := ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch";
                        tempItemJnlLine."Line No." := LastLineNo;
                        if ItemJnlTemplate.Get(ExtCompanySetup."PMP15 SOR Consum.Jnl. Template") then begin
                            tempItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
                        end;
                        // tempItemJnlLine."Source Code" := 'CONSUMPJNL';
                        tempItemJnlLine."Source Type" := tempItemJnlLine."Source Type"::Item;
                        if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Consum.Jnl. Template", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch") then begin
                            if ItemJnlBatch."No. Series" <> '' then begin
                                tempItemJnlLine."Document No." := NoSeriesBatchMgmt.PeekNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                            end;
                        end;
                        tempItemJnlLine.Validate("Posting Date", SortProdOrderRec."Posting Date");
                        tempItemJnlLine.Validate("Entry Type", tempItemJnlLine."Entry Type"::Consumption);
                        tempItemJnlLine.Validate("Order Type", tempItemJnlLine."Order Type"::Production);
                        tempItemJnlLine.Validate("Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                        tempItemJnlLine.Validate("Order Line No.", PrOL."Line No."); // Related to the PW Item
                        tempItemJnlLine.Validate("Item No.", Item."No.");
                        tempItemJnlLine.Description := Item.Description;
                        tempItemJnlLine.Validate("Variant Code", SortProdOrderRec."Unsorted Variant Code");
                        // tempItemJnlLine.Validate("Variant Code", PrOComp."Variant Code");
                        tempItemJnlLine.Validate("Quantity", SortProdOrderRec.Quantity);
                        tempItemJnlLine.Validate("Unit of Measure Code", SortProdOrderRec."Unit of Measure Code");
                        tempItemJnlLine.Validate("Location Code", PrOL."Location Code");
                        // tempItemJnlLine.Validate("Operation No.", PrORL."Operation No.");
                        // tempItemJnlLine.Validate("Operation No.", ProdOrdRoutingLine."Operation No.");
                        tempItemJnlLine."Work Shift Code" := SortProdOrderRec."Work Shift Code";
                        // tempItemJnlLine."Bin Code" := SortProdOrderRec."From Bin Code";
                        // VALIDATE BEFORE SETTING BIN CODE
                        ValidateBinContentIsExistforItemJnlLine(BinContent, tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", tempItemJnlLine."Location Code");
                        BinContent.SetRange("Bin Code", SortProdOrderRec."From Bin Code");
                        if BinContent.FindFirst() then
                            tempItemJnlLine."Bin Code" := SortProdOrderRec."From Bin Code"
                        else
                            Error('The Bin Code %1 is not available in the Bin Content with the Item of %2 %3, on %4 Location. Please make sure the related From Bin Code is available in the Bin Content.', SortProdOrderRec."From Bin Code", tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", tempItemJnlLine."Location Code");

                        tempItemJnlLine."Lot No." := SortProdOrderRec."Lot No.";

                        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                        if LotNoInfoRec.Get(tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", tempItemJnlLine."Lot No.") then begin
                            tempItemJnlLine."PMP15 Crop" := LotNoInfoRec."PMP14 Crop";
                            tempItemJnlLine."PMP15 Cycle (Separately)" := LotNoInfoRec."PMP14 Cycle (Separately)";
                            tempItemJnlLine."Invoice No." := LotNoInfoRec."PMP14 Invoice No.";
                            tempItemJnlLine."PMP15 Delivery" := LotNoInfoRec."PMP14 Delivery";
                            tempItemJnlLine."PMP15 Cycle Code" := LotNoInfoRec."PMP14 Cycle Code";
                            tempItemJnlLine."PMP15 Output Item No." := SortProdOrderRec."Sorted Item No.";
                            tempItemJnlLine."PMP15 Output Variant Code" := SortProdOrderRec."Sorted Variant Code";
                        end;
                        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}

                        tempItemJnlLine."PMP15 Marked" := true;

                        IsInsertSortation := true;

                        // if tempItemJnlLine.Insert() then
                        //     exit(true)
                        // else
                        //     exit(false);
                    end;
                end;
            end else begin
                ProdOrderRec.SetRange("No.", SortProdOrderRec."Sortation Prod. Order No.");
                if ProdOrderRec.FindFirst() then begin
                    ProdOrdRoutingLine.SetRange(Status, ProdOrderRec.Status);
                    ProdOrdRoutingLine.SetRange("Prod. Order No.", ProdOrderRec."No.");
                    ProdOrdRoutingLine.SetRange("Routing Reference No.", PrOL."Line No.");
                    if not ProdOrdRoutingLine.FindFirst() then exit;

                    tempItemJnlLine.Init();
                    tempItemJnlLine."Journal Template Name" := ExtCompanySetup."PMP15 SOR Output Jnl. Template";
                    tempItemJnlLine."Journal Batch Name" := ExtCompanySetup."PMP15 SOR Output Jnl. Batch";
                    tempItemJnlLine."Line No." := LastLineNo;
                    if ItemJnlTemplate.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template") then begin
                        tempItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
                    end;
                    // tempItemJnlLine."Source Code" := 'POINOUTJNL';
                    if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template", ExtCompanySetup."PMP15 SOR Output Jnl. Batch") then begin
                        if ItemJnlBatch."No. Series" <> '' then begin
                            tempItemJnlLine."Document No." := NoSeriesBatchMgmt.PeekNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                        end;
                    end;
                    tempItemJnlLine.Validate("Posting Date", SortProdOrderRec."Posting Date");
                    tempItemJnlLine.Validate("Entry Type", tempItemJnlLine."Entry Type"::Output);
                    tempItemJnlLine.Validate("Order Type", tempItemJnlLine."Order Type"::Production);
                    tempItemJnlLine.Validate("Order No.", PrOL."Prod. Order No."); // Related to the PW Item
                    tempItemJnlLine.Validate("Order Line No.", PrOL."Line No."); // Related to the PW Item
                    if Item.Get(PrOL."Item No.") then begin
                        tempItemJnlLine.Validate("Item No.", Item."No.");
                        tempItemJnlLine.Description := Item.Description;
                    end;
                    tempItemJnlLine.Validate("Variant Code", PrOL."Variant Code");
                    tempItemJnlLine.Validate("Output Quantity", SortProdOrderRec.Quantity);
                    tempItemJnlLine.Validate("Unit of Measure Code", SortProdOrderRec."Unit of Measure Code");
                    tempItemJnlLine.Validate("Location Code", PrOL."Location Code");
                    tempItemJnlLine."Operation No." := ProdOrdRoutingLine."Operation No.";
                    tempItemJnlLine.Type := ProdOrdRoutingLine.Type;
                    tempItemJnlLine.Validate("No.", ProdOrdRoutingLine."No.");
                    tempItemJnlLine."Work Shift Code" := SortProdOrderRec."Work Shift Code";
                    // tempItemJnlLine.Validate("Bin Code", SortProdOrderRec."To Bin Code");
                    // VALIDATE BEFORE SETTING BIN CODE
                    ValidateBinContentIsExistforItemJnlLine(BinContent, tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", tempItemJnlLine."Location Code");
                    BinContent.SetRange("Bin Code", SortProdOrderRec."To Bin Code");
                    if BinContent.FindFirst() then
                        tempItemJnlLine.Validate("Bin Code", SortProdOrderRec."To Bin Code")
                    else
                        Error('The Bin Code %1 is not available in the Bin Content with the Item of %2 %3, on %4 Location. Please make sure the related To Bin Code is available in the Bin Content.', SortProdOrderRec."To Bin Code", tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", tempItemJnlLine."Location Code");

                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/05 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/15 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                    if not LotNoInformationIsExist(LotNoInfoRec, tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SortProdOrderRec."Lot No.") then begin
                        OldLotNoInfoRec.SetRange("Item No.", SortProdOrderRec."Unsorted Item No.");
                        OldLotNoInfoRec.SetRange("Variant Code", SortProdOrderRec."Unsorted Variant Code");
                        OldLotNoInfoRec.SetRange("Lot No.", SortProdOrderRec."Lot No.");
                        if OldLotNoInfoRec.FindFirst() then begin
                            LotNoInfoRec := CreateNewLotNoInformationfromOldLotNoInfo(OldLotNoInfoRec, tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SortProdOrderRec."Lot No.");
                        end else begin
                            Error('No Lot No. Information available for the Output Journal for the Sorted Item %1 - %2 during the creation of a new Lot No %3. Information record with the Tobacco Type of %4. Please review the current lot availability for the specified unsorted item.', SortProdOrderRec."Unsorted Item No.", SortProdOrderRec."Unsorted Variant Code", SortProdOrderRec."Lot No.", SortProdOrderRec."Tobacco Type");
                        end;
                    end;
                    tempItemJnlLine."Lot No." := LotNoInfoRec."Lot No.";
                    tempItemJnlLine."PMP15 Crop" := LotNoInfoRec."PMP14 Crop";
                    tempItemJnlLine."PMP15 Cycle (Separately)" := LotNoInfoRec."PMP14 Cycle (Separately)";
                    tempItemJnlLine."Invoice No." := LotNoInfoRec."PMP14 Invoice No.";
                    tempItemJnlLine."PMP15 Delivery" := LotNoInfoRec."PMP14 Delivery";
                    tempItemJnlLine."PMP15 Cycle Code" := LotNoInfoRec."PMP14 Cycle Code";
                    tempItemJnlLine."PMP15 Output Item No." := SortProdOrderRec."Sorted Item No.";
                    tempItemJnlLine."PMP15 Output Variant Code" := SortProdOrderRec."Sorted Variant Code";

                    if PackageNoIsExist(tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SortProdOrderRec."Package No.") then
                        tempItemJnlLine.Validate("Package No.", SortProdOrderRec."Package No.")
                    else begin
                        if Item."PMP04 Package Nos" = '' then begin
                            Validate_TestInsertItemJnlLine_ITEMPMP04PackageNos(NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos"), Item."No.");
                        end;
                        if NoSeriesMgmt.PeekNextNo(Item."PMP04 Package Nos") <> '' then
                            // if ProdOrderRec."PMP15 Crop" = 0 then begin
                            if ProdOrderRec."PMP15 Crop" = '' then begin
                                LotNoInfoRec.Reset();
                                LotNoInfoRec.SetRange("Item No.", ItemJnlLine."Item No.");
                                LotNoInfoRec.SetRange("Variant Code", ItemJnlLine."Variant Code");
                                LotNoInfoRec.SetRange("Lot No.", SortProdOrderRec."Lot No.");
                                if LotNoInfoRec.FindFirst() AND (LotNoInfoRec."PMP14 Crop" <> '') then begin
                                    SORCrop := LotNoInfoRec."PMP14 Crop";
                                end else begin
                                    SORCrop := Format(Date2DMY(WorkDate(), 3));
                                end;
                                SORPackageNo := COPYSTR(Format(SORCrop), STRLEN(Format(SORCrop)) - 1, 2) + NoSeriesMgmt.GetNextNo(Item."PMP04 Package Nos");
                            end else
                                SORPackageNo := COPYSTR(Format(ProdOrderRec."PMP15 Crop"), STRLEN(Format(ProdOrderRec."PMP15 Crop")) - 1, 2) + NoSeriesMgmt.GetNextNo(Item."PMP04 Package Nos");
                        tempItemJnlLine.Validate("Package No.", SORPackageNo);
                        CreateNewPackagefromItemJnlLineOutput(tempItemJnlLine, SortProdOrderRec);
                    end;
                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/05 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}

                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/15 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}

                    IsInsertSortation := true;
                end;
            end;
            #endregion TestItemJnlLine STEP 4 - PW
        end else if (SORStep_Step = SORStep_Step::"4") AND (SortProdOrderRec."Tobacco Type" = SortProdOrderRec."Tobacco Type"::Filler) AND (SortProdOrderRec."Variant Changes" = '') AND (SortProdOrderRec."Variant Changes" = '') then begin
            #region TestItemJnlLine STEP 4 - FILLER
            // SORTATION FILLER SECTION
            if IJLEntryType = IJLEntryType::Consumption then begin
                ProdOrderRec.SetRange("No.", SortProdOrderRec."Sortation Prod. Order No.");
                if ProdOrderRec.FindFirst() then begin
                    // if Item.Get(PrOComp."Item No.") then begin
                    tempItemJnlLine.Init();
                    tempItemJnlLine."Journal Template Name" := ExtCompanySetup."PMP15 SOR Consum.Jnl. Template";
                    tempItemJnlLine."Journal Batch Name" := ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch";
                    tempItemJnlLine."Line No." := LastLineNo;
                    if ItemJnlTemplate.Get(ExtCompanySetup."PMP15 SOR Consum.Jnl. Template") then begin
                        tempItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
                    end;
                    // tempItemJnlLine."Source Code" := 'CONSUMPJNL';
                    tempItemJnlLine."Source Type" := tempItemJnlLine."Source Type"::Item;
                    if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Consum.Jnl. Template", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch") then begin
                        if ItemJnlBatch."No. Series" <> '' then begin
                            tempItemJnlLine."Document No." := NoSeriesBatchMgmt.PeekNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                        end;
                    end;
                    tempItemJnlLine.Validate("Posting Date", SortProdOrderRec."Posting Date");
                    tempItemJnlLine.Validate("Entry Type", tempItemJnlLine."Entry Type"::Consumption);
                    tempItemJnlLine.Validate("Order Type", tempItemJnlLine."Order Type"::Production);
                    tempItemJnlLine.Validate("Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                    tempItemJnlLine.Validate("Order Line No.", PrOL."Line No.");

                    ProdOrdComp.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                    ProdOrdComp.SetRange("PMP15 Unsorted Item", true);
                    if ProdOrdComp.FindFirst() then begin
                        tempItemJnlLine.Validate("Item No.", ProdOrdComp."Item No.");
                        tempItemJnlLine.Validate("Variant Code", ProdOrdComp."Variant Code");
                        Item.Get(tempItemJnlLine."Item No.");
                        tempItemJnlLine.Description := Item.Description;
                        // tempItemJnlLine.Validate("Prod. Order Comp. Line No.", ProdOrdComp."Line No.");
                    end;

                    // tempItemJnlLine.Validate("Item No.", Item."No.");
                    // tempItemJnlLine.Validate("Variant Code", SortProdOrderRec."Unsorted Variant Code");
                    // tempItemJnlLine.Validate("Variant Code", PrOComp."Variant Code");
                    tempItemJnlLine.Validate("Location Code", PrOL."Location Code");
                    tempItemJnlLine."Work Shift Code" := SortProdOrderRec."Work Shift Code";
                    tempItemJnlLine.Validate("Quantity", SortProdOrderRec.Quantity);
                    tempItemJnlLine.Validate("Unit of Measure Code", SortProdOrderRec."Unit of Measure Code");
                    // tempItemJnlLine."Bin Code" := SortProdOrderRec."From Bin Code";
                    // VALIDATE BEFORE SETTING BIN CODE
                    ValidateBinContentIsExistforItemJnlLine(BinContent, tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", tempItemJnlLine."Location Code");
                    BinContent.SetRange("Bin Code", SortProdOrderRec."From Bin Code");
                    if BinContent.FindFirst() then
                        tempItemJnlLine.Validate("Bin Code", SortProdOrderRec."From Bin Code")
                    else
                        Error('The Bin Code %1 is not available in the Bin Content with the Item of %2 %3, on %4 Location. Please make sure the related From Bin Code is available in the Bin Content.', SortProdOrderRec."From Bin Code", tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", tempItemJnlLine."Location Code");

                    tempItemJnlLine."Lot No." := SortProdOrderRec."Lot No.";

                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                    if LotNoInfoRec.Get(tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", tempItemJnlLine."Lot No.") then begin
                        tempItemJnlLine."PMP15 Crop" := LotNoInfoRec."PMP14 Crop";
                        tempItemJnlLine."PMP15 Cycle (Separately)" := LotNoInfoRec."PMP14 Cycle (Separately)";
                        tempItemJnlLine."Invoice No." := LotNoInfoRec."PMP14 Invoice No.";
                        tempItemJnlLine."PMP15 Delivery" := LotNoInfoRec."PMP14 Delivery";
                        tempItemJnlLine."PMP15 Cycle Code" := LotNoInfoRec."PMP14 Cycle Code";
                        tempItemJnlLine."PMP15 Output Item No." := SortProdOrderRec."Sorted Item No.";
                        tempItemJnlLine."PMP15 Output Variant Code" := SortProdOrderRec."Sorted Variant Code";
                    end;
                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}

                    tempItemJnlLine."PMP15 Marked" := true;

                    IsInsertSortation := true;

                    // if tempItemJnlLine.Insert() then
                    //     exit(true)
                    // else
                    //     exit(false);
                    // end;
                end;
            end else begin
                ProdOrderRec.SetRange("No.", SortProdOrderRec."Sortation Prod. Order No.");
                if ProdOrderRec.FindFirst() then begin
                    ProdOrdRoutingLine.SetRange(Status, ProdOrderRec.Status);
                    ProdOrdRoutingLine.SetRange("Prod. Order No.", ProdOrderRec."No.");
                    ProdOrdRoutingLine.SetRange("Routing Reference No.", PrOL."Line No.");
                    if not ProdOrdRoutingLine.FindFirst() then exit;

                    tempItemJnlLine.Init();
                    tempItemJnlLine."Journal Template Name" := ExtCompanySetup."PMP15 SOR Output Jnl. Template";
                    tempItemJnlLine."Journal Batch Name" := ExtCompanySetup."PMP15 SOR Output Jnl. Batch";
                    tempItemJnlLine."Line No." := LastLineNo;
                    if ItemJnlTemplate.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template") then begin
                        tempItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
                    end;
                    // tempItemJnlLine."Source Code" := 'POINOUTJNL';
                    if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template", ExtCompanySetup."PMP15 SOR Output Jnl. Batch") then begin
                        if ItemJnlBatch."No. Series" <> '' then begin
                            tempItemJnlLine."Document No." := NoSeriesBatchMgmt.PeekNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                        end;
                    end;
                    tempItemJnlLine.Validate("Posting Date", SortProdOrderRec."Posting Date");
                    tempItemJnlLine.Validate("Entry Type", tempItemJnlLine."Entry Type"::Output);
                    tempItemJnlLine.Validate("Order Type", tempItemJnlLine."Order Type"::Production);
                    tempItemJnlLine.Validate("Order No.", PrOL."Prod. Order No."); // Related to the Filler Item
                    tempItemJnlLine.Validate("Order Line No.", PrOL."Line No."); // Related to the Filler Item
                    if Item.Get(PrOL."Item No.") then begin
                        tempItemJnlLine.Validate("Item No.", Item."No.");
                        tempItemJnlLine.Description := Item.Description;
                    end;
                    tempItemJnlLine.Validate("Variant Code", PrOL."Variant Code");
                    tempItemJnlLine.Validate("Output Quantity", SortProdOrderRec.Quantity);
                    tempItemJnlLine.Validate("Unit of Measure Code", SortProdOrderRec."Unit of Measure Code");
                    tempItemJnlLine.Validate("Location Code", PrOL."Location Code");
                    tempItemJnlLine.Validate("Operation No.", ProdOrdRoutingLine."Operation No.");
                    tempItemJnlLine.Type := ProdOrdRoutingLine.Type;
                    tempItemJnlLine.Validate("No.", ProdOrdRoutingLine."No.");
                    tempItemJnlLine."Work Shift Code" := SortProdOrderRec."Work Shift Code";

                    // VALIDATE BEFORE SETTING BIN CODE
                    ValidateBinContentIsExistforItemJnlLine(BinContent, tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", tempItemJnlLine."Location Code");
                    BinContent.SetRange("Bin Code", SortProdOrderRec."To Bin Code");
                    if BinContent.FindFirst() then
                        tempItemJnlLine.Validate("Bin Code", SortProdOrderRec."To Bin Code")
                    else
                        Error('The Bin Code %1 is not available in the Bin Content with the Item of %2 %3, on %4 Location. Please make sure the related To Bin Code is available in the Bin Content.', SortProdOrderRec."To Bin Code", tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", tempItemJnlLine."Location Code");
                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/10 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                    if not LotNoInformationIsExist(LotNoInfoRec, tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SortProdOrderRec."Lot No.") then begin
                        ProdOrdComp.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                        ProdOrdComp.SetRange("PMP15 Unsorted Item", true);
                        if ProdOrdComp.FindFirst() then begin
                            OldLotNoInfoRec.SetRange("Item No.", ProdOrdComp."Item No.");
                            OldLotNoInfoRec.SetRange("Variant Code", ProdOrdComp."Variant Code");
                            OldLotNoInfoRec.SetRange("Lot No.", SortProdOrderRec."Lot No.");
                            if OldLotNoInfoRec.FindFirst() then begin
                                LotNoInfoRec := CreateNewLotNoInformationfromOldLotNoInfo(OldLotNoInfoRec, tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SortProdOrderRec."Lot No.");
                            end
                        end else begin
                            Error('No Lot No. Information available for the Output Journal for the Sorted Item %1 - %2 during the creation of a new Lot No %3. Information record with the Tobacco Type of %4. Please review the current lot availability for the specified unsorted item.', SortProdOrderRec."Unsorted Item No.", SortProdOrderRec."Unsorted Variant Code", SortProdOrderRec."Lot No.", SortProdOrderRec."Tobacco Type");
                        end;
                    end;
                    tempItemJnlLine."Lot No." := LotNoInfoRec."Lot No.";
                    tempItemJnlLine."PMP15 Crop" := LotNoInfoRec."PMP14 Crop";
                    tempItemJnlLine."PMP15 Cycle (Separately)" := LotNoInfoRec."PMP14 Cycle (Separately)";
                    tempItemJnlLine."Invoice No." := LotNoInfoRec."PMP14 Invoice No.";
                    tempItemJnlLine."PMP15 Delivery" := LotNoInfoRec."PMP14 Delivery";
                    tempItemJnlLine."PMP15 Cycle Code" := LotNoInfoRec."PMP14 Cycle Code";
                    tempItemJnlLine."PMP15 Output Item No." := SortProdOrderRec."Sorted Item No.";
                    tempItemJnlLine."PMP15 Output Variant Code" := SortProdOrderRec."Sorted Variant Code";

                    if PackageNoIsExist(tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SortProdOrderRec."Package No.") then
                        tempItemJnlLine.Validate("Package No.", SortProdOrderRec."Package No.")
                    else begin
                        if Item."PMP04 Package Nos" = '' then begin
                            Validate_TestInsertItemJnlLine_ITEMPMP04PackageNos(NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos"), Item."No.");
                        end;
                        if NoSeriesMgmt.PeekNextNo(Item."PMP04 Package Nos") <> '' then
                            // if ProdOrderRec."PMP15 Crop" = 0 then begin
                            if ProdOrderRec."PMP15 Crop" = '' then begin
                                LotNoInfoRec.Reset();
                                LotNoInfoRec.SetRange("Item No.", ItemJnlLine."Item No.");
                                LotNoInfoRec.SetRange("Variant Code", ItemJnlLine."Variant Code");
                                LotNoInfoRec.SetRange("Lot No.", SortProdOrderRec."Lot No.");
                                if LotNoInfoRec.FindFirst() AND (LotNoInfoRec."PMP14 Crop" <> '') then begin
                                    SORCrop := LotNoInfoRec."PMP14 Crop";
                                end else begin
                                    SORCrop := Format(Date2DMY(WorkDate(), 3));
                                end;
                                SORPackageNo := COPYSTR(Format(SORCrop), STRLEN(Format(SORCrop)) - 1, 2) + NoSeriesMgmt.GetNextNo(Item."PMP04 Package Nos");
                            end else
                                SORPackageNo := COPYSTR(Format(ProdOrderRec."PMP15 Crop"), STRLEN(Format(ProdOrderRec."PMP15 Crop")) - 1, 2) + NoSeriesMgmt.GetNextNo(Item."PMP04 Package Nos");
                        tempItemJnlLine.Validate("Package No.", SORPackageNo);

                        CreateNewPackagefromItemJnlLineOutput(tempItemJnlLine, SortProdOrderRec);
                    end;
                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/10 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
                    IsInsertSortation := true;
                end;
            end;
            #endregion TestItemJnlLine STEP 4 - FILLER
        end else if (SORStep_Step = SORStep_Step::"4") AND (SortProdOrderRec."Variant Changes" <> '') then begin
            #region TestItemJnlLine STEP 4 - VARIANT CHANGES
            // SORTATION PRODUCTION ORDER - VARIANT CHANGES SECTION
            if IJLEntryType = IJLEntryType::Consumption then begin
                ProdOrderRec.SetRange("No.", SortProdOrderRec."Sortation Prod. Order No.");
                if ProdOrderRec.FindFirst() then begin
                    // if Item.Get(ProdOrdComp."Item No.") then begin 
                    tempItemJnlLine.Init();
                    tempItemJnlLine."Journal Template Name" := ExtCompanySetup."PMP15 SOR Consum.Jnl. Template";
                    tempItemJnlLine."Journal Batch Name" := ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch";
                    tempItemJnlLine."Line No." := LastLineNo;
                    if ItemJnlTemplate.Get(ExtCompanySetup."PMP15 SOR Consum.Jnl. Template") then begin
                        tempItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
                    end;
                    // tempItemJnlLine."Source Code" := 'CONSUMPJNL';
                    tempItemJnlLine."Source Type" := tempItemJnlLine."Source Type"::Item;
                    if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Consum.Jnl. Template", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch") then begin
                        if ItemJnlBatch."No. Series" <> '' then begin
                            tempItemJnlLine."Document No." := NoSeriesBatchMgmt.PeekNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                        end;
                    end;
                    tempItemJnlLine.Validate("Posting Date", SortProdOrderRec."Posting Date");
                    tempItemJnlLine.Validate("Entry Type", tempItemJnlLine."Entry Type"::Consumption);
                    tempItemJnlLine.Validate("Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                    tempItemJnlLine.Validate("Order Line No.", PrOL."Line No."); // Doesn't related to the Chosen Item
                    tempItemJnlLine.Validate("Order Type", tempItemJnlLine."Order Type"::Production);

                    ProdOrdComp.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                    ProdOrdComp.SetRange("PMP15 Unsorted Item", true);
                    if ProdOrdComp.FindFirst() then begin
                        tempItemJnlLine.Validate("Item No.", ProdOrdComp."Item No.");
                        tempItemJnlLine.Validate("Variant Code", ProdOrdComp."Variant Code");
                        Item.Get(tempItemJnlLine."Item No.");
                        tempItemJnlLine.Description := Item.Description;
                        // tempItemJnlLine.Validate("Prod. Order Comp. Line No.", ProdOrdComp."Line No.");
                    end;

                    // tempItemJnlLine.Validate("Item No.", Item."No.");
                    // tempItemJnlLine.Description := Item.Description;
                    // tempItemJnlLine.Validate("Variant Code", SortProdOrderRec."Unsorted Variant Code");
                    tempItemJnlLine.Validate("Location Code", PrOL."Location Code");
                    tempItemJnlLine."Work Shift Code" := SortProdOrderRec."Work Shift Code";
                    tempItemJnlLine.Validate("Quantity", SortProdOrderRec.Quantity);
                    tempItemJnlLine.Validate("Unit of Measure Code", SortProdOrderRec."Unit of Measure Code");
                    tempItemJnlLine.Validate("Bin Code", SortProdOrderRec."From Bin Code");
                    tempItemJnlLine.Validate("Lot No.", SortProdOrderRec."Lot No.");

                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                    // SETTING VARIANT CHANGES
                    tempItemJnlLine."PMP15 Variant Changes (From)" := SortProdOrderRec."Sorted Variant Code";
                    tempItemJnlLine."PMP15 Variant Changes (To)" := PrOL."Variant Code";
                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}

                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                    LotNoInfoRec.Get(tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", tempItemJnlLine."Lot No.");

                    tempItemJnlLine."PMP15 Crop" := LotNoInfoRec."PMP14 Crop";
                    tempItemJnlLine."PMP15 Cycle (Separately)" := LotNoInfoRec."PMP14 Cycle (Separately)";
                    tempItemJnlLine."Invoice No." := LotNoInfoRec."PMP14 Invoice No.";
                    tempItemJnlLine."PMP15 Delivery" := LotNoInfoRec."PMP14 Delivery";
                    tempItemJnlLine."PMP15 Cycle Code" := LotNoInfoRec."PMP14 Cycle Code";
                    tempItemJnlLine."PMP15 Output Item No." := SortProdOrderRec."Sorted Item No.";
                    tempItemJnlLine."PMP15 Output Variant Code" := SortProdOrderRec."Variant Changes";
                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/09 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}

                    tempItemJnlLine."PMP15 Marked" := true;

                    IsInsertSortation := true;

                    // if tempItemJnlLine.Insert() then
                    //     exit(true)
                    // else
                    //     exit(false);
                    // end;
                end;
            end else begin
                ProdOrderRec.SetRange("No.", SortProdOrderRec."Sortation Prod. Order No.");
                if ProdOrderRec.FindFirst() then begin
                    ProdOrdRoutingLine.SetRange(Status, ProdOrderRec.Status);
                    ProdOrdRoutingLine.SetRange("Prod. Order No.", ProdOrderRec."No.");
                    ProdOrdRoutingLine.SetRange("Routing Reference No.", PrOL."Line No.");
                    if not ProdOrdRoutingLine.FindFirst() then exit;

                    tempItemJnlLine.Init();
                    tempItemJnlLine."Journal Template Name" := ExtCompanySetup."PMP15 SOR Output Jnl. Template";
                    tempItemJnlLine."Journal Batch Name" := ExtCompanySetup."PMP15 SOR Output Jnl. Batch";
                    tempItemJnlLine."Line No." := LastLineNo;
                    if ItemJnlTemplate.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template") then begin
                        tempItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
                    end;
                    // tempItemJnlLine."Source Code" := 'POINOUTJNL';
                    if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template", ExtCompanySetup."PMP15 SOR Output Jnl. Batch") then begin
                        if ItemJnlBatch."No. Series" <> '' then begin
                            tempItemJnlLine."Document No." := NoSeriesBatchMgmt.PeekNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                        end;
                    end;
                    tempItemJnlLine.Validate("Posting Date", SortProdOrderRec."Posting Date");
                    tempItemJnlLine.Validate("Entry Type", tempItemJnlLine."Entry Type"::Output);
                    tempItemJnlLine.Validate("Order Type", tempItemJnlLine."Order Type"::Production);
                    tempItemJnlLine.Validate("Order No.", PrOL."Prod. Order No."); // Related to the Filler Item
                    tempItemJnlLine.Validate("Order Line No.", PrOL."Line No."); // Related to the Filler Item
                    if Item.Get(PrOL."Item No.") then begin
                        tempItemJnlLine.Validate("Item No.", Item."No.");
                        tempItemJnlLine.Description := Item.Description;
                    end;
                    tempItemJnlLine.Validate("Variant Code", PrOL."Variant Code");
                    tempItemJnlLine.Validate("Output Quantity", SortProdOrderRec.Quantity);
                    tempItemJnlLine.Validate("Unit of Measure Code", SortProdOrderRec."Unit of Measure Code");
                    tempItemJnlLine.Validate("Location Code", PrOL."Location Code");
                    tempItemJnlLine.Validate("Operation No.", ProdOrdRoutingLine."Operation No.");
                    tempItemJnlLine.Type := ProdOrdRoutingLine.Type;
                    tempItemJnlLine.Validate("No.", ProdOrdRoutingLine."No.");
                    tempItemJnlLine."Work Shift Code" := SortProdOrderRec."Work Shift Code";

                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                    // SETTING VARIANT CHANGES
                    tempItemJnlLine."PMP15 Variant Changes (From)" := SortProdOrderRec."Sorted Variant Code";
                    tempItemJnlLine."PMP15 Variant Changes (To)" := PrOL."Variant Code";

                    tempItemJnlLine."PMP15 Sub Merk 1" := GetSubmerk1fromItemNVariant(tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code");
                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}

                    // VALIDATE BEFORE SETTING BIN CODE
                    ValidateBinContentIsExistforItemJnlLine(BinContent, tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", tempItemJnlLine."Location Code");
                    BinContent.SetRange("Bin Code", SortProdOrderRec."To Bin Code");
                    if BinContent.FindFirst() then
                        tempItemJnlLine.Validate("Bin Code", SortProdOrderRec."To Bin Code")
                    else
                        Error('The Bin Code %1 is not available in the Bin Content with the Item of %2 %3, on %4 Location. Please make sure the related To Bin Code is available in the Bin Content.', SortProdOrderRec."To Bin Code", tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", tempItemJnlLine."Location Code");
                    // tempItemJnlLine.Validate("Bin Code", SortProdOrderRec."To Bin Code");
                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/05 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                    if not LotNoInformationIsExist(LotNoInfoRec, tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SortProdOrderRec."Lot No.") then begin
                        ProdOrdComp.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                        ProdOrdComp.SetRange("PMP15 Unsorted Item", true);
                        if ProdOrdComp.FindFirst() then begin
                            OldLotNoInfoRec.SetRange("Item No.", ProdOrdComp."Item No.");
                            OldLotNoInfoRec.SetRange("Variant Code", ProdOrdComp."Variant Code");
                            OldLotNoInfoRec.SetRange("Lot No.", SortProdOrderRec."Lot No.");
                            if OldLotNoInfoRec.FindFirst() then begin
                                LotNoInfoRec := CreateNewLotNoInformationfromOldLotNoInfo(OldLotNoInfoRec, tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SortProdOrderRec."Lot No.");
                            end
                        end else begin
                            Error('No Lot No. Information available for the Output Journal for the Sorted Item %1 - %2 during the creation of a new Lot No %3. Information record with the Tobacco Type of %4. Please review the current lot availability for the specified unsorted item.', SortProdOrderRec."Unsorted Item No.", SortProdOrderRec."Unsorted Variant Code", SortProdOrderRec."Lot No.", SortProdOrderRec."Tobacco Type");
                        end;
                    end;
                    tempItemJnlLine."Lot No." := LotNoInfoRec."Lot No.";
                    tempItemJnlLine."PMP15 Crop" := LotNoInfoRec."PMP14 Crop";
                    tempItemJnlLine."PMP15 Cycle (Separately)" := LotNoInfoRec."PMP14 Cycle (Separately)";
                    tempItemJnlLine."Invoice No." := LotNoInfoRec."PMP14 Invoice No.";
                    tempItemJnlLine."PMP15 Delivery" := LotNoInfoRec."PMP14 Delivery";
                    tempItemJnlLine."PMP15 Cycle Code" := LotNoInfoRec."PMP14 Cycle Code";
                    tempItemJnlLine."PMP15 Output Item No." := SortProdOrderRec."Sorted Item No.";
                    tempItemJnlLine."PMP15 Output Variant Code" := SortProdOrderRec."Variant Changes";

                    if PackageNoIsExist(tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SortProdOrderRec."Package No.") then
                        tempItemJnlLine.Validate("Package No.", SortProdOrderRec."Package No.")
                    else begin
                        if Item."PMP04 Package Nos" = '' then begin
                            Validate_TestInsertItemJnlLine_ITEMPMP04PackageNos(NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos"), Item."No.");
                        end;
                        if NoSeriesMgmt.PeekNextNo(Item."PMP04 Package Nos") <> '' then
                            // if ProdOrderRec."PMP15 Crop" = 0 then begin
                            if ProdOrderRec."PMP15 Crop" = '' then begin
                                LotNoInfoRec.Reset();
                                LotNoInfoRec.SetRange("Item No.", ItemJnlLine."Item No.");
                                LotNoInfoRec.SetRange("Variant Code", ItemJnlLine."Variant Code");
                                LotNoInfoRec.SetRange("Lot No.", SortProdOrderRec."Lot No.");
                                if LotNoInfoRec.FindFirst() AND (LotNoInfoRec."PMP14 Crop" <> '') then begin
                                    SORCrop := LotNoInfoRec."PMP14 Crop";
                                end else begin
                                    SORCrop := Format(Date2DMY(WorkDate(), 3));
                                end;
                                SORPackageNo := COPYSTR(Format(SORCrop), STRLEN(Format(SORCrop)) - 1, 2) + NoSeriesMgmt.GetNextNo(Item."PMP04 Package Nos");
                            end else
                                SORPackageNo := COPYSTR(Format(ProdOrderRec."PMP15 Crop"), STRLEN(Format(ProdOrderRec."PMP15 Crop")) - 1, 2) + NoSeriesMgmt.GetNextNo(Item."PMP04 Package Nos");
                        tempItemJnlLine.Validate("Package No.", SORPackageNo);

                        CreateNewPackagefromItemJnlLineOutput(tempItemJnlLine, SortProdOrderRec);
                    end;
                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/05 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
                    IsInsertSortation := true;
                end;
            end;
            #endregion TestItemJnlLine STEP 4 - VARIANT CHANGES
        end;

        if IsInsertSortation then begin
            tempItemJnlLine."PMP15 Prod. Order No." := SortProdOrderRec."Sortation Prod. Order No.";
            tempItemJnlLine."PMP15 Production Type" := tempItemJnlLine."PMP15 Production Type"::"SOR-Sortation";
            if tempItemJnlLine."PMP15 Sub Merk 1" = '' then
                tempItemJnlLine."PMP15 Sub Merk 1" := SortProdOrderRec."Submerk 1";
            tempItemJnlLine."PMP15 Sub Merk 2" := SortProdOrderRec."Submerk 2";
            tempItemJnlLine."PMP15 Sub Merk 3" := SortProdOrderRec."Submerk 3";
            tempItemJnlLine."PMP15 Sub Merk 4" := SortProdOrderRec."Submerk 4";
            tempItemJnlLine."PMP15 Sub Merk 5" := SortProdOrderRec."Submerk 5";
            tempItemJnlLine."PMP15 L/R" := SortProdOrderRec."L/R";
            tempItemJnlLine."PMP15 Return to Result Step" := SortProdOrderRec."SORStep Return Step";
            tempItemJnlLine."PMP15 Return to Result Code" := SortProdOrderRec."SORStep Return Code";
            if (SortProdOrderRec."SORStep Return Step" <> SortProdOrderRec."SORStep Return Step"::" ") AND (SortProdOrderRec."SORStep Return Code" <> '') then
                tempItemJnlLine."PMP15 Return" := true
            else
                tempItemJnlLine."PMP15 Return" := false;
            tempItemJnlLine."PMP15 SOR Step" := SortProdOrderRec."SORStep Step";
            tempItemJnlLine."PMP15 SOR Step Code" := SortProdOrderRec."SORStep Code";
            tempItemJnlLine."PMP15 Tobacco Type" := SortProdOrderRec."Tobacco Type";
            tempItemJnlLine."PMP15 Rework" := SortProdOrderRec.Rework;
            tempItemJnlLine."PMP15 Marked" := true;

            if SortProdOrderRec."Package No." = '' then begin
                SortProdOrderRec."Package No." := tempItemJnlLine."Package No.";
            end;

            if tempItemJnlLine.Insert() then
                exit(true)
            else
                exit(false);
        end;
    end;

    ///<summary>Creates and inserts a Reservation Entry from temporary tracking and journal line data based on sortation and tracking specifications.</summary>
    local procedure InsertReservEntryRecfromTempTrackSpecIJL(var RecReservEntry: Record "Reservation Entry"; var TempTrackingSpecification: Record "Tracking Specification" temporary; var RecItemJnlLine: Record "Item Journal Line"; SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary; SerLotPkgArr: array[3] of Code[50])
    var
        TypeHelper: Codeunit "Type Helper";
        SourceTrackingSpecification: Record "Tracking Specification";
        Item: Record Item;
        ItemTrackingLine: Page "Item Tracking Lines";
        RecRef: RecordRef;
        RunMode: Enum "Item Tracking Run Mode";
        ChangeType: Option Insert,Modify,FullDelete,PartDelete,ModifyAll;
    begin
        Item.Get(RecItemJnlLine."Item No.");
        RecRef.GetTable(Item);
        if Item."Item Tracking Code" = '' then
            PMPAppLogicMgmt.ErrorRecordRefwithAction(RecRef, Item.FieldNo("Item Tracking Code"), Page::"Item Card", 'Empty Field', StrSubstNo('The Item "%1" does not have an assigned Item Tracking Code. Please configure the Item Tracking Code in the Item Card before continuing.', Item."No."));

        ItemJnlLineReserve.InitFromItemJnlLine(SourceTrackingSpecification, RecItemJnlLine);
        ItemTrackingLine.SetSourceSpec(SourceTrackingSpecification, 0D);
        if RecItemJnlLine."Entry Type" = RecItemJnlLine."Entry Type"::Transfer then begin
            ItemTrackingLine.SetRunMode(RunMode::Reclass);
        end;

        TempTrackingSpecification.Init;
        TempTrackingSpecification.TransferFields(SourceTrackingSpecification);
        TempTrackingSpecification.SetItemData(SourceTrackingSpecification."Item No.", SourceTrackingSpecification.Description, SourceTrackingSpecification."Location Code", SourceTrackingSpecification."Variant Code", SourceTrackingSpecification."Bin Code", SourceTrackingSpecification."Qty. per Unit of Measure");
        TempTrackingSpecification.Validate("Item No.", SourceTrackingSpecification."Item No.");
        TempTrackingSpecification.Validate("Location Code", SourceTrackingSpecification."Location Code");
        // TempTrackingSpecification.Validate("Creation Date", Today);
        TempTrackingSpecification.Validate("Creation Date", DT2Date(TypeHelper.GetCurrentDateTimeInUserTimeZone()));
        TempTrackingSpecification.Validate("Source Type", SourceTrackingSpecification."Source Type");
        TempTrackingSpecification.Validate("Source Subtype", SourceTrackingSpecification."Source Subtype");
        TempTrackingSpecification.Validate("Source ID", SourceTrackingSpecification."Source ID");
        TempTrackingSpecification.Validate("Source Batch Name", SourceTrackingSpecification."Source Batch Name");
        TempTrackingSpecification.Validate("Source Prod. Order Line", SourceTrackingSpecification."Source Prod. Order Line");
        TempTrackingSpecification.Validate("Source Ref. No.", SourceTrackingSpecification."Source Ref. No.");
        if SortProdOrderRec."SORStep Step" in [SortProdOrderRec."SORStep Step"::"1", SortProdOrderRec."SORStep Step"::"2", SortProdOrderRec."SORStep Step"::"3"] then begin
            TempTrackingSpecification.Validate("Bin Code", RecItemJnlLine."Bin Code");
            if SerLotPkgArr[1] <> '' then
                TempTrackingSpecification.Validate("Serial No.", SerLotPkgArr[1]);
            if SerLotPkgArr[2] <> '' then
                TempTrackingSpecification.Validate("Lot No.", SerLotPkgArr[2]);
            // TempTrackingSpecification.Validate("New Lot No.", SerLotPkgArr[2]);
            if SerLotPkgArr[3] <> '' then
                TempTrackingSpecification.Validate("Package No.", SerLotPkgArr[3]);
            TempTrackingSpecification.Positive := true;
        end else if (RecItemJnlLine."Entry Type" = RecItemJnlLine."Entry Type"::Output) then begin
            TempTrackingSpecification.Positive := true;
            TempTrackingSpecification.Validate("Bin Code", RecItemJnlLine."Bin Code");
            TempTrackingSpecification.Validate("Serial No.", SerLotPkgArr[1]);
            TempTrackingSpecification.Validate("Lot No.", SerLotPkgArr[2]);
            TempTrackingSpecification.Validate("Package No.", SerLotPkgArr[3]);
        end else begin
            TempTrackingSpecification.Validate("Bin Code", RecItemJnlLine."Bin Code");
            TempTrackingSpecification.Validate("Serial No.", SerLotPkgArr[1]);
            TempTrackingSpecification.Validate("Lot No.", SerLotPkgArr[2]);
            TempTrackingSpecification.Validate("Package No.", SerLotPkgArr[3]);
            TempTrackingSpecification.Positive := true;
        end;
        TempTrackingSpecification.Validate("Quantity (Base)", RecItemJnlLine."Quantity (Base)");
        TempTrackingSpecification.Validate("Qty. to Handle (Base)", RecItemJnlLine."Quantity (Base)");
        TempTrackingSpecification.Validate("Qty. to Invoice (Base)", RecItemJnlLine."Quantity (Base)");
        ItemTrackingLine.RegisterChange(TempTrackingSpecification, TempTrackingSpecification, ChangeType::Insert, false);
    end;

    // ONE OF THE MOST IMPORTANT FUNCTION IN THIS CODEUNIT
    /// <summary>Generates reservation entries for the given Item Journal Line using package and tracking information.</summary>
    /// <remarks>Prevents duplicate tracking entries and ensures journal line consistency with package data and item tracking setup.</remarks>
    /// <param name="RecItemJnlLine">Record variable for Item Journal Line to generate reservation entries for.</param>
    /// <param name="SortProdOrderRec">Temporary record of Sortation Production Order used for validation and linkage.</param>
    procedure GenerateRecReserveEntryItemJnlLine(var RecItemJnlLine: Record "Item Journal Line"; SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary)
    var
        Item: Record Item;
        RecReservEntry: Record "Reservation Entry";
        TrackingSpecification: Record "Tracking Specification";
        TempTrackingSpecification: Record "Tracking Specification" temporary;
        PackageNoInfo: Record "Package No. Information";
        SerLotPkgArr: array[3] of Code[50];
    begin
        Clear(SerLotPkgArr);

        if RecItemJnlLine.ReservEntryExist() then
            Error('Item tracking information already exists for this reclassification journal line. Please remove the existing tracking before proceeding.');

        Item.SetLoadFields("Item Tracking Code");
        if not Item.Get(RecItemJnlLine."Item No.") then
            Error('The specified Item No. "%1" could not be found. Please verify that the item exists in the system.', RecItemJnlLine."Item No.");

        if Item."Item Tracking Code" = '' then
            Error('The Item "%1" does not have an assigned Item Tracking Code. Please configure the Item Tracking Code in the Item Card before continuing.', RecItemJnlLine."Item No.");

        if ItemJnlLineReserve.ReservEntryExist(RecItemJnlLine) then
            Error(
                'Reservation entries already exist for Item "%1" in this reclassification journal line. Please cancel or delete the existing reservations before performing this action.', RecItemJnlLine."Item No.");

        ItemJnlLineReserve.InitFromItemJnlLine(TempTrackingSpecification, RecItemJnlLine);
        TempTrackingSpecification.Insert();

        RetrieveLookupData(TempTrackingSpecification, true);
        TempTrackingSpecification.Delete();
        TempGlobalEntrySummary.Reset();
        // TempGlobalEntrySummary.SetFilter("Lot No.", RecItemJnlLine."Lot No.");
        if RecItemJnlLine."Lot No." <> '' then
            TempGlobalEntrySummary.SetFilter("Lot No.", RecItemJnlLine."Lot No.")
        else
            TempGlobalEntrySummary.SetFilter("Lot No.", SortProdOrderRec."Lot No.");
        TempGlobalEntrySummary.SetFilter("Package No.", RecItemJnlLine."Package No.");
        if TempGlobalEntrySummary.FindFirst() then begin
            SerLotPkgArr[1] := TempGlobalEntrySummary."Serial No.";
            SerLotPkgArr[2] := TempGlobalEntrySummary."Lot No.";
            SerLotPkgArr[3] := TempGlobalEntrySummary."Package No.";
            InsertReservEntryRecfromTempTrackSpecIJL(RecReservEntry, TempTrackingSpecification, RecItemJnlLine, SortProdOrderRec, SerLotPkgArr);
        end else begin
            PackageNoInfo.SetAutoCalcFields("PMP04 Bin Code", "PMP04 Lot No.");
            PackageNoInfo.SetRange("Item No.", RecItemJnlLine."Item No.");
            PackageNoInfo.SetFilter("Variant Code", RecItemJnlLine."Variant Code");
            PackageNoInfo.SetFilter("Package No.", RecItemJnlLine."Package No.");
            // PackageNoInfo.SetFilter("PMP04 Bin Code", RecItemJnlLine."Bin Code");
            PackageNoInfo.SetRange(Inventory, 0);
            if PackageNoInfo.FindFirst() then begin
                // SerLotPkgArr[1] := PackageNoInfo."PMP04 Bin Code";
                SerLotPkgArr[2] := PackageNoInfo."PMP04 Lot No.";
                SerLotPkgArr[3] := PackageNoInfo."Package No.";

                if SerLotPkgArr[2] = '' then begin
                    SerLotPkgArr[2] := SortProdOrderRec."Lot No.";
                end;
                InsertReservEntryRecfromTempTrackSpecIJL(RecReservEntry, TempTrackingSpecification, RecItemJnlLine, SortProdOrderRec, SerLotPkgArr);
            end else begin
                SerLotPkgArr[2] := SortProdOrderRec."Lot No.";
                SerLotPkgArr[3] := SortProdOrderRec."Package No.";
                InsertReservEntryRecfromTempTrackSpecIJL(RecReservEntry, TempTrackingSpecification, RecItemJnlLine, SortProdOrderRec, SerLotPkgArr);
            end;
        end;
    end;

    /// <summary>Creates a new Reservation Entry based on data from a Tracking Specification record.</summary>
    /// <remarks>Copies tracking and source data, sets expiration and warranty dates, and records creation metadata for audit compliance.</remarks>
    /// <param name="RecReservEntry">Record variable for the Reservation Entry to be created.</param>
    /// <param name="FromTrackingSpecification">Record variable of Tracking Specification providing the source data.</param>
    procedure CreateReservEntryFrom(var RecReservEntry: Record "Reservation Entry"; var FromTrackingSpecification: Record "Tracking Specification")
    var
        UOMMgt: Codeunit "Unit of Measure Management";
    begin
        RecReservEntry.Init();
        RecReservEntry.SetItemData(FromTrackingSpecification."Item No.",
         FromTrackingSpecification.Description,
         FromTrackingSpecification."Location Code",
         FromTrackingSpecification."Variant Code",
         0);
        RecReservEntry.Validate("Qty. per Unit of Measure", FromTrackingSpecification."Qty. per Unit of Measure");
        RecReservEntry.Validate("Quantity (Base)", Abs(FromTrackingSpecification."Quantity (Base)"));
        RecReservEntry.SetSource(FromTrackingSpecification."Source Type",
         FromTrackingSpecification."Source Subtype",
         FromTrackingSpecification."Source ID",
         FromTrackingSpecification."Source Ref. No.",
         FromTrackingSpecification."Source Batch Name",
         FromTrackingSpecification."Source Prod. Order Line");

        RecReservEntry.CopyTrackingFromSpec(FromTrackingSpecification);
        RecReservEntry.CopyNewTrackingFromTrackingSpec(FromTrackingSpecification);
        RecReservEntry.Validate("Package No.", FromTrackingSpecification."Package No.");
        RecReservEntry.Validate("New Package No.", FromTrackingSpecification."New Package No.");

        GetItemTrackingCode(RecReservEntry."Item No.");
        GetRecReservEntryItemTrackingEnum(RecReservEntry, RecReservEntry."Lot No.", RecReservEntry."Serial No.", RecReservEntry."Package No.");
        SetExpirationDateReservationEntry(RecReservEntry, ItemTrackingCode);
        RecReservEntry."Created By" := UserId;
        RecReservEntry."Creation Date" := Today();
    end;

    ///<summary>Determines and assigns the appropriate item tracking type to the reservation entry based on the presence of lot, serial, and package numbers.</summary>
    local procedure GetRecReservEntryItemTrackingEnum(var RecReservEntry: Record "Reservation Entry"; LotNo: Code[50]; SerialNo: Code[50]; PackageNo: Code[50])
    var
        myInt: Integer;
    begin
        if (LotNo <> '') and (SerialNo <> '') and (PackageNo <> '') then
            RecReservEntry."Item Tracking" := RecReservEntry."Item Tracking"::"Lot and Serial and Package No.";
        if (LotNo <> '') and (SerialNo <> '') and (PackageNo = '') then
            RecReservEntry."Item Tracking" := RecReservEntry."Item Tracking"::"Lot and Serial No.";
        if (LotNo <> '') and (SerialNo = '') and (PackageNo <> '') then
            RecReservEntry."Item Tracking" := RecReservEntry."Item Tracking"::"Lot and Package No.";
        if (LotNo <> '') and (SerialNo = '') and (PackageNo = '') then
            RecReservEntry."Item Tracking" := RecReservEntry."Item Tracking"::"Lot No.";
        if (LotNo = '') and (SerialNo <> '') and (PackageNo <> '') then
            RecReservEntry."Item Tracking" := RecReservEntry."Item Tracking"::"Serial and Package No.";
        if (LotNo = '') and (SerialNo <> '') and (PackageNo = '') then
            RecReservEntry."Item Tracking" := RecReservEntry."Item Tracking"::"Serial No.";
        if (LotNo = '') and (SerialNo = '') and (PackageNo <> '') then
            RecReservEntry."Item Tracking" := RecReservEntry."Item Tracking"::"Package No.";
        if (LotNo = '') and (SerialNo = '') and (PackageNo = '') then
            RecReservEntry."Item Tracking" := RecReservEntry."Item Tracking"::None;
    end;

    /// <summary>Sets expiration and warranty dates for the reservation entry based on item tracking configuration.</summary>
    /// <remarks>Ensures correct assignment of expiration and warranty dates in alignment with the item tracking setup.</remarks>
    /// <param name="RecReservEntry">Record variable for Reservation Entry to be updated.</param>
    /// <param name="ItemTrackingCode">Record variable for Item Tracking Code used to determine expiration settings.</param>
    procedure SetExpirationDateReservationEntry(var RecReservEntry: Record "Reservation Entry"; var ItemTrackingCode: Record "Item Tracking Code")
    var
        ExpDate: Date;
        EntriesExist: Boolean;
        ItemTrackingMgt: Codeunit "Item Tracking Management";
        ItemTrackingSetup: Record "Item Tracking Setup";
    begin
        RecReservEntry."Expiration Date" := 0D;

        if ItemTrackingCode."Use Expiration Dates" then begin
            ExpDate := ItemTrackingMgt.ExistingExpirationDate(RecReservEntry."Item No.",
            RecReservEntry."Variant Code", ItemTrackingSetup, false, EntriesExist);
            if EntriesExist then begin
                RecReservEntry."Expiration Date" := ExpDate;
            end;
        end;

        RecReservEntry."New Expiration Date" := RecReservEntry."Expiration Date";
        RecReservEntry."Warranty Date" := ItemTrackingMgt.ExistingWarrantyDate(
            RecReservEntry."Item No.", RecReservEntry."Variant Code",
            ItemTrackingSetup, EntriesExist);
    end;

    /// <summary>Creates and inserts a new Item Journal Line from the temporary source based on the provided Sortation Production Order and step.</summary>
    /// <remarks>Overload procedure that initializes the journal insertion process with a default entry type before delegating to the main insertion logic.</remarks>
    /// <param name="ItemJnlLine">Destination Item Journal Line record to insert.</param>
    /// <param name="tempItemJnlLine">Temporary Item Journal Line record containing source data.</param>
    /// <param name="SortProdOrderRec">Temporary Sortation Production Order record used for reference during insertion.</param>
    /// <param name="SORStep_Step">Enum value specifying the current Sortation Step.</param>
    procedure InsertItemJnlLinefromTemp(var ItemJnlLine: Record "Item Journal Line"; var tempItemJnlLine: Record "Item Journal Line" temporary; SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary; SORStep_Step: Enum "PMP15 Sortation Step Enum")
    begin
        InsertItemJnlLinefromTemp(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine."Entry Type"::" ");
    end;

    // ONE OF THE MOST IMPORTANT FUNCTION IN THIS CODEUNIT
    /// <summary>Inserts a new Item Journal Line using data from a temporary journal line and Sortation Production Order details.</summary>
    /// <remarks>Handles setup, data mapping, and insertion of journal lines based on the specified item ledger entry type and sortation step.</remarks>
    /// <param name="ItemJnlLine">Target Item Journal Line record where the new line will be inserted.</param>
    /// <param name="tempItemJnlLine">Temporary Item Journal Line serving as the data source.</param>
    /// <param name="SortProdOrderRec">Temporary Sortation Production Order record for item and process reference.</param>
    /// <param name="SORStep_Step">Enum value indicating the current Sortation Step being processed.</param>
    /// <param name="IJLEntryType">Enum value defining the Item Ledger Entry Type for the journal entry.</param>
    procedure InsertItemJnlLinefromTemp(var ItemJnlLine: Record "Item Journal Line"; var tempItemJnlLine: Record "Item Journal Line" temporary; SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary; SORStep_Step: Enum "PMP15 Sortation Step Enum"; IJLEntryType: Enum "Item Ledger Entry Type")
    var
        ExtCompanySetup: Record "PMP07 Extended Company Setup";
        ItemJnlBatch: Record "Item Journal Batch";
        NoSeriesMgmt: Codeunit "No. Series - Batch";
    begin
        ExtCompanySetup.Get();
        ItemJnlBatch.Reset();

        case SORStep_Step of
            SORStep_Step::"1", SORStep_Step::"2", SORStep_Step::"3":
                begin
                    ItemJnlLine.Init();
                    ItemJnlLine := tempItemJnlLine;
                    if ItemJnlBatch.Get(ExtCompanySetup."PMP15SORItemReclass.Jnl.Tmpt.", ExtCompanySetup."PMP15SORItemReclass.Jnl.Batch") then begin
                        if ItemJnlBatch."No. Series" <> '' then begin
                            ItemJnlLine."Document No." := NoSeriesMgmt.GetNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                        end;
                    end;
                end;
            SORStep_Step::"4":
                begin
                    case SortProdOrderRec."Tobacco Type" of
                        SortProdOrderRec."Tobacco Type"::Wrapper:
                            begin
                                if IJLEntryType = IJLEntryType::Consumption then begin
                                    ItemJnlLine.Init();
                                    ItemJnlLine := tempItemJnlLine;
                                    if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Consum.Jnl. Template", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch") then begin
                                        if ItemJnlBatch."No. Series" <> '' then begin
                                            ItemJnlLine."Document No." := NoSeriesMgmt.GetNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                                        end;
                                    end;
                                end else begin
                                    ItemJnlLine.Init();
                                    ItemJnlLine := tempItemJnlLine;
                                    if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template", ExtCompanySetup."PMP15 SOR Output Jnl. Batch") then begin
                                        if ItemJnlBatch."No. Series" <> '' then begin
                                            ItemJnlLine."Document No." := NoSeriesMgmt.GetNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                                        end;
                                    end;
                                end;
                            end;
                        SortProdOrderRec."Tobacco Type"::PW:
                            begin
                                if IJLEntryType = IJLEntryType::Consumption then begin
                                    ItemJnlLine.Init();
                                    ItemJnlLine := tempItemJnlLine;
                                    if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Consum.Jnl. Template", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch") then begin
                                        if ItemJnlBatch."No. Series" <> '' then begin
                                            ItemJnlLine."Document No." := NoSeriesMgmt.GetNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                                        end;
                                    end;
                                end else begin
                                    ItemJnlLine.Init();
                                    ItemJnlLine := tempItemJnlLine;
                                    if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template", ExtCompanySetup."PMP15 SOR Output Jnl. Batch") then begin
                                        if ItemJnlBatch."No. Series" <> '' then begin
                                            ItemJnlLine."Document No." := NoSeriesMgmt.GetNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                                        end;
                                    end;
                                end;
                            end;
                        SortProdOrderRec."Tobacco Type"::Filler:
                            begin
                                if IJLEntryType = IJLEntryType::Consumption then begin
                                    ItemJnlLine.Init();
                                    ItemJnlLine := tempItemJnlLine;
                                    if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Consum.Jnl. Template", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch") then begin
                                        if ItemJnlBatch."No. Series" <> '' then begin
                                            ItemJnlLine."Document No." := NoSeriesMgmt.GetNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                                        end;
                                    end;
                                end else begin
                                    ItemJnlLine.Init();
                                    ItemJnlLine := tempItemJnlLine;
                                    if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template", ExtCompanySetup."PMP15 SOR Output Jnl. Batch") then begin
                                        if ItemJnlBatch."No. Series" <> '' then begin
                                            ItemJnlLine."Document No." := NoSeriesMgmt.GetNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                                        end;
                                    end;
                                end;
                            end;
                    // SortProdOrderRec."Tobacco Type"::"Raw Material":
                    //     begin
                    //         // 
                    //     end;
                    end;
                end;
            else
                if (SORStep_Step = SORStep_Step::"4") AND (SortProdOrderRec."Variant Changes" <> '') then begin
                    if IJLEntryType = IJLEntryType::Consumption then begin
                        ItemJnlLine.Init();
                        ItemJnlLine := tempItemJnlLine;
                        if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Consum.Jnl. Template", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch") then begin
                            if ItemJnlBatch."No. Series" <> '' then begin
                                ItemJnlLine."Document No." := NoSeriesMgmt.GetNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                            end;
                        end;
                    end else begin
                        ItemJnlLine.Init();
                        ItemJnlLine := tempItemJnlLine;
                        if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template", ExtCompanySetup."PMP15 SOR Output Jnl. Batch") then begin
                            if ItemJnlBatch."No. Series" <> '' then begin
                                ItemJnlLine."Document No." := NoSeriesMgmt.GetNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                            end;
                        end;
                    end;
                end;

        end;
        ItemJnlLine.Insert();
        ItemJnlLine.Mark(true);
    end;

    /// <summary>Inserts a new Sortation Detail Result record based on the Item Journal Line and validates its relationship to the Sortation Production Order.</summary>
    /// <remarks>Also checks package information eligibility for sale and updates related Package No. Information fields accordingly.</remarks>
    /// <param name="ItemJnlLine">Item Journal Line record containing item and tracking details.</param>
    /// <param name="SortProdOrderRec">Temporary Sortation Production Order record for validation and linkage.</param>
    procedure InsertSORDetailResultfromItemJnlLine(var ItemJnlLine: Record "Item Journal Line"; SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary)
    var
        SORProdOrdDetLine: Record "PMP15 Sortation Detail Quality";
        NextLineNo: Integer;
    begin
        SORProdOrdDetLine.Reset();
        SORProdOrdDetLine.SetCurrentKey("Item No.", "Variant Code", "Package No.", "Sub Merk 1", "Sub Merk 2", "Sub Merk 3", "Sub Merk 4", "Sub Merk 5");
        SORProdOrdDetLine.SetRange("Item No.", ItemJnlLine."Item No.");
        SORProdOrdDetLine.SetRange("Variant Code", ItemJnlLine."Variant Code");
        SORProdOrdDetLine.SetRange("Package No.", ItemJnlLine."Package No.");
        SORProdOrdDetLine.SetRange("Sub Merk 1", ItemJnlLine."PMP15 Sub Merk 1");
        SORProdOrdDetLine.SetRange("Sub Merk 2", ItemJnlLine."PMP15 Sub Merk 2");
        SORProdOrdDetLine.SetRange("Sub Merk 3", ItemJnlLine."PMP15 Sub Merk 3");
        SORProdOrdDetLine.SetRange("Sub Merk 4", ItemJnlLine."PMP15 Sub Merk 4");
        SORProdOrdDetLine.SetRange("Sub Merk 5", ItemJnlLine."PMP15 Sub Merk 5");
        if SORProdOrdDetLine.FindLast() then begin
            if ItemJnlLine."Entry Type" = ItemJnlLine."Entry Type"::Output then
                SORProdOrdDetLine.Quantity += ItemJnlLine."Output Quantity";
            if ItemJnlLine."Entry Type" in [ItemJnlLine."Entry Type"::Consumption, ItemJnlLine."Entry Type"::Transfer] then
                SORProdOrdDetLine.Quantity += ItemJnlLine.Quantity;
            SORProdOrdDetLine.Modify();
        end else begin
            SORProdOrdDetLine.Reset();
            SORProdOrdDetLine.LockTable();
            SORProdOrdDetLine.SetRange("Item No.", ItemJnlLine."Item No.");
            SORProdOrdDetLine.SetRange("Variant Code", ItemJnlLine."Variant Code");
            SORProdOrdDetLine.SetRange("Package No.", ItemJnlLine."Package No.");
            if SORProdOrdDetLine.FindLast() then
                NextLineNo := SORProdOrdDetLine."Entry No." + 10000
            else
                NextLineNo := 10000;

            SORProdOrdDetLine.Init();
            SORProdOrdDetLine.Validate("Item No.", ItemJnlLine."Item No.");
            SORProdOrdDetLine.Validate("Variant Code", ItemJnlLine."Variant Code");
            SORProdOrdDetLine.Validate("Package No.", ItemJnlLine."Package No.");
            SORProdOrdDetLine."Entry No." := NextLineNo;
            SORProdOrdDetLine.Validate("Lot No.", ItemJnlLine."Lot No.");
            SORProdOrdDetLine.Validate("Sub Merk 1", ItemJnlLine."PMP15 Sub Merk 1");
            SORProdOrdDetLine.Validate("Sub Merk 2", ItemJnlLine."PMP15 Sub Merk 2");
            SORProdOrdDetLine.Validate("Sub Merk 3", ItemJnlLine."PMP15 Sub Merk 3");
            SORProdOrdDetLine.Validate("Sub Merk 4", ItemJnlLine."PMP15 Sub Merk 4");
            SORProdOrdDetLine.Validate("Sub Merk 5", ItemJnlLine."PMP15 Sub Merk 5");
            SORProdOrdDetLine.Validate("L/R", ItemJnlLine."PMP15 L/R");
            // SORProdOrdDetLine.Validate(Quantity, ItemJnlLine.Quantity);
            if ItemJnlLine."Entry Type" = ItemJnlLine."Entry Type"::Output then
                SORProdOrdDetLine.Validate(Quantity, ItemJnlLine."Output Quantity");
            if ItemJnlLine."Entry Type" in [ItemJnlLine."Entry Type"::Consumption, ItemJnlLine."Entry Type"::Transfer] then
                SORProdOrdDetLine.Validate(Quantity, ItemJnlLine.Quantity);
            SORProdOrdDetLine.Validate("Unit of Measure Code", ItemJnlLine."Unit of Measure Code");
            SORProdOrdDetLine.Validate(Rework, ItemJnlLine."PMP15 Rework");
            SORProdOrdDetLine.Validate("Tobacco Type", ItemJnlLine."PMP15 Tobacco Type");
            SORProdOrdDetLine.Insert();
        end;
        // Commit();

        CheckPkgNoInfoAbletoSell(SORProdOrdDetLine, SortProdOrderRec);
    end;

    /// <summary>Validates and updates Package No. Information to determine if the package can be sold and whether it is mixed.</summary>
    /// <remarks>Performs checks on sub-merk group consistency, sub-merk range gap, and quantity thresholds to update selling eligibility and mixed status.</remarks>
    /// <param name="SORProdOrdDetLine">Sortation Detail Quality record representing the current sortation result.</param>
    /// <param name="SortProdOrderRec">Temporary Sortation Production Order record providing reference data for updates.</param>
    procedure CheckPkgNoInfoAbletoSell(var SORProdOrdDetLine: Record "PMP15 Sortation Detail Quality"; SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary)
    var
        PkgNoInfoList: Record "Package No. Information";
        SDR: Record "PMP15 Sortation Detail Quality";
        SubmerkGroups, SubmerkCodes : array[5] of Code[50];
        IsAbletoSell, IsMixed : Boolean;
        BiggestCode, SmallestCode : Integer;
    begin
        PkgNoInfoList.Reset();
        SDR.Reset();
        Clear(SubmerkGroups);
        Clear(SubmerkCodes);
        Clear(IsAbletoSell);
        Clear(IsMixed);

        PkgNoInfoList.SetRange("Item No.", SORProdOrdDetLine."Item No.");
        PkgNoInfoList.SetRange("Variant Code", SORProdOrdDetLine."Variant Code");
        PkgNoInfoList.SetRange("Package No.", SORProdOrdDetLine."Package No.");
        if PkgNoInfoList.FindFirst() then begin
            #region IS ABLE TO SELL
            // Persyaratan 1 & 2 ITERATIVE

            SDR.Reset();
            SDR.SetRange("Item No.", PkgNoInfoList."Item No.");
            SDR.SetRange("Variant Code", PkgNoInfoList."Variant Code");
            SDR.SetRange("Package No.", PkgNoInfoList."Package No.");
            if SDR.FindSet() then
                repeat
                    GetSubmerkGROUPfromSORPrdOrdDetLine(SubmerkGroups, SDR); // To be used in "IS ABLE TO SELL" region
                    // If there is combination of Sub Merk 2 & Sub Merk 3 on SDR that has different Group (Group field is available on Sub Merk 3 Table) then field able to sell on PANI will be false.
                    IsAbletoSell := SubmerkGroups[2] = SubmerkGroups[3];

                    // Then check combination of Sub Merk 4 on SDR if there is SDR that has different Group (Group field is available on Sub Merk 4 table) then field able to sell on PANI will be false.
                    if IsAbletoSell then begin
                        IsAbletoSell := IsAbletoSell AND
                            (SubmerkGroups[3] = SubmerkGroups[4]) AND
                            (SubmerkGroups[2] = SubmerkGroups[4]);
                    end;
                until (SDR.Next() = 0) OR not IsAbletoSell;

            // if IsAbletoSell then begin
            //     SDR.SetCurrentKey("Sub Merk 5", "Item No.", "Variant Code", "Package No.");
            //     SDR.SetRange("Item No.", PkgNoInfoList."Item No.");
            //     SDR.SetRange("Variant Code", PkgNoInfoList."Variant Code");
            //     SDR.SetRange("Package No.", PkgNoInfoList."Package No.");
            //     SDR.SetAscending("Sub Merk 5", true);
            //     if SDR.FindLast() then
            //         SetSubmerkCodes(SubmerkCodes, SDR."Sub Merk 1", SDR."Sub Merk 2", SDR."Sub Merk 3", SDR."Sub Merk 4", SDR."Sub Merk 5");
            //     GetMinMaxSubMerkFromList(SubmerkCodes, SmallestCode, BiggestCode);
            //     IsAbletoSell := IsAbletoSell AND ((BiggestCode - SmallestCode) > 1);
            // end;
            // 
            // if IsAbletoSell then begin
            //     SDR.Reset();
            //     SDR.SetRange("Item No.", PkgNoInfoList."Item No.");
            //     SDR.SetRange("Variant Code", PkgNoInfoList."Variant Code");
            //     SDR.SetRange("Package No.", PkgNoInfoList."Package No.");
            //     IsAbletoSell := IsAbletoSell AND CheckQtySDRIsBiggerThan(SDR, 35);
            // end;

            // Then check combination of Sub Merk 5 on Sortation Detail Result if the biggest - the lowest > 1 then field able to sell on Package No. Information will be false.
            if IsAbletoSell then begin
                SDR.Reset();
                SDR.SetRange("Item No.", PkgNoInfoList."Item No.");
                SDR.SetRange("Variant Code", PkgNoInfoList."Variant Code");
                SDR.SetRange("Package No.", PkgNoInfoList."Package No.");
                if SDR.Count > 1 then begin
                    IsAbletoSell := IsAbletoSell AND not (CalcSubmerk5MinMaxDifference(SORProdOrdDetLine) > 1);

                    // if CalcSubmerk5MinMaxDifference(SORProdOrdDetLine) > 1 then
                    //     IsAbletoSell := false
                    // else
                    //     IsAbletoSell := true;
                end;
            end;

            // If not, then check total quantity on Sortation Detail Result >= 35 if yes then set field able to sell on Package No. Information to True. If not, then set to False.
            if IsAbletoSell then begin
                SDR.Reset();
                SDR.SetCurrentKey("Item No.", "Variant Code", "Package No.");
                SDR.SetRange("Item No.", SORProdOrdDetLine."Item No.");
                SDR.SetRange("Variant Code", SORProdOrdDetLine."Variant Code");
                SDR.SetRange("Package No.", SORProdOrdDetLine."Package No.");
                SDR.CalcSums(Quantity);
                IsAbletoSell := IsAbletoSell AND (SDR.Quantity > 35);
                // if SDR.Quantity < 35 then
                //     IsAbletoSell := false;
            end;
            #endregion IS ABLE TO SELL

            #region MIXED
            // b) If there is different of Sub Merk 1, Sub Merk 2, Sub Merk 3, Sub Merk 4, Sub Merk 5 on Sortation Detail Result then set field Mixed to be True. If all the same then set field Mixed to be False
            if SDR.FindSet() then
                repeat
                    if (SORProdOrdDetLine."Sub Merk 1" <> SDR."Sub Merk 1") or
                    (SORProdOrdDetLine."Sub Merk 2" <> SDR."Sub Merk 2") or
                    (SORProdOrdDetLine."Sub Merk 3" <> SDR."Sub Merk 3") or
                    (SORProdOrdDetLine."Sub Merk 4" <> SDR."Sub Merk 4") or
                    (SORProdOrdDetLine."Sub Merk 5" <> SDR."Sub Merk 5") then begin
                        IsMixed := true;
                    end;
                until (SDR.Next() = 0) OR IsMixed;
            #endregion MIXED

            Clear(SubmerkCodes);
            GetSubmerkforBiggestRank(SubmerkCodes, PkgNoInfoList."Item No.", PkgNoInfoList."Variant Code", PkgNoInfoList."Package No.");

            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
            // net weight = sum (quantity pada sor detail result)
            // gross weight = sum (quantity pada sor detail result) + tarre weight dari prod. order recording + allowance packing  weight dari prod. order recording
            SDR.Reset();
            SDR.SetCurrentKey("Item No.", "Variant Code", "Package No.");
            SDR.SetRange("Item No.", SORProdOrdDetLine."Item No.");
            SDR.SetRange("Variant Code", SORProdOrdDetLine."Variant Code");
            SDR.SetRange("Package No.", SORProdOrdDetLine."Package No.");
            SDR.CalcSums(Quantity);
            PkgNoInfoList."PMP04 Nett Weight (Kgs)" := SDR.Quantity;
            PkgNoInfoList."PMP04 Gross Weight (Kgs)" := PkgNoInfoList."PMP04 Nett Weight (Kgs)" + SortProdOrderRec."Tarre Weight" + SortProdOrderRec."Allowance Packing Weight";

            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}

            PkgNoInfoList."PMP04 Bale Number" := PkgNoInfoList."Package No.";
            PkgNoInfoList."PMP15 Able to Sell" := IsAbletoSell;
            PkgNoInfoList."PMP15 Mixed" := IsMixed;
            PkgNoInfoList."PMP04 Sub Merk 1" := SubmerkCodes[1];
            PkgNoInfoList."PMP04 Sub Merk 2" := SubmerkCodes[2];
            PkgNoInfoList."PMP04 Sub Merk 3" := SubmerkCodes[3];
            PkgNoInfoList."PMP04 Sub Merk 4" := SubmerkCodes[4];
            PkgNoInfoList."PMP04 Sub Merk 5" := SubmerkCodes[5];
            PkgNoInfoList."PMP15 Unsorted Item No." := SortProdOrderRec."Unsorted Item No.";
            PkgNoInfoList."PMP15 Unsorted Variant Code" := SortProdOrderRec."Unsorted Variant Code";
            PkgNoInfoList.Modify();
        end;
    end;

    /// <summary>Calculates difference between max and min numeric values found in "PMP04 Sub Merk 5" for all SDR records with same Item/Variant/Package.</summary>
    /// <param name="SDRRec">The source "PMP15 Sortation Detail Quality" record used to identify group.</param>
    local procedure CalcSubmerk5MinMaxDifference(var SDRRec: Record "PMP15 Sortation Detail Quality") Difference: Integer
    var
        SDR: Record "PMP15 Sortation Detail Quality";
        ConvertedVal: Integer;
        HasNumber: Boolean;
        MinVal: Integer;
        MaxVal: Integer;
    begin
        HasNumber := false;
        MinVal := 0;
        MaxVal := 0;

        SDR.Reset();
        SDR.SetRange("Item No.", SDRRec."Item No.");
        SDR.SetRange("Variant Code", SDRRec."Variant Code");
        SDR.SetRange("Package No.", SDRRec."Package No.");

        if SDR.FindSet() then
            repeat
                if SDR."Sub Merk 5" <> '' then begin
                    if Evaluate(ConvertedVal, SDR."Sub Merk 5") then begin
                        if not HasNumber then begin
                            MinVal := ConvertedVal;
                            MaxVal := ConvertedVal;
                            HasNumber := true;
                        end else begin
                            if ConvertedVal < MinVal then
                                MinVal := ConvertedVal;
                            if ConvertedVal > MaxVal then
                                MaxVal := ConvertedVal;
                        end;
                    end;
                end;
            until SDR.Next() = 0;

        if not HasNumber then
            exit(0);

        Difference := MaxVal - MinVal;
        exit(Difference);
    end;
    // ...existing code...

    /// <summary>Creates new Sortation Production Order Lines and initializes related routing lines.</summary>
    /// <remarks> Generates new production order lines based on Sortation data, copying key fields such as item, variant, quantity, and routing info.  Also supports creating a new routing line with default time values to maintain process consistency. </remarks>
    /// <param name="ProdOrdLine2">The production order line record to be created and inserted.</param>
    /// <param name="SortProdOrderRec">The temporary Sortation Production Order Recording containing reference and quantity information.</param>
    /// <param name="CHOSENItem">The production order component providing item and variant data (only for the first overload).</param>
    /// <param name="ProdOrdLine">The reference production order line providing location, bin, and routing data.</param>
    procedure CreateNewSORProdOrdLine(var ProdOrdLine2: Record "Prod. Order Line"; SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary; CHOSENItem: Record "Prod. Order Component"; ProdOrdLine: Record "Prod. Order Line")
    var
        PrOL: Record "Prod. Order Line";
        LastLineNo: Integer;
    begin
        PrOL.Reset();
        Clear(LastLineNo);

        PrOL.SetRange(Status, PrOL.Status::Released);
        PrOL.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
        if PrOL.FindLast() then begin
            LastLineNo := PrOL."Line No.";
        end;

        if LastLineNo mod 10000 > 0 then begin
            LastLineNo += LastLineNo mod 10000;
        end else begin
            LastLineNo += 10000;
        end;

        ProdOrdLine2.Reset();
        ProdOrdLine2.Init();
        ProdOrdLine2.Status := ProdOrdLine.Status::Released;
        ProdOrdLine2."Prod. Order No." := SortProdOrderRec."Sortation Prod. Order No.";
        ProdOrdLine2."Line No." := LastLineNo;
        ProdOrdLine2.Validate("Item No.", CHOSENItem."Item No.");
        ProdOrdLine2.Validate("Variant Code", CHOSENItem."Variant Code");
        ProdOrdLine2.Validate("Location Code", ProdOrdLine."Location Code");
        ProdOrdLine2."Bin Code" := ProdOrdLine."Bin Code";
        ProdOrdLine2.Validate(Quantity, SortProdOrderRec.Quantity);
        ProdOrdLine2.Validate("Unit of Measure Code", SortProdOrderRec."Unit of Measure Code");
        ProdOrdLine2.Validate("Routing No.", ProdOrdLine."Routing No.");
        ProdOrdLine2.Insert();
    end;

    /// <param name="ProdOrdLine2">The production order line record to be created and inserted.</param>
    /// <param name="SortProdOrderRec">The temporary Sortation Production Order Recording containing reference and quantity information.</param>
    /// <param name="ProdOrdLine">The reference production order line providing location, bin, and routing data.</param>
    procedure CreateNewSORProdOrdLine(var ProdOrdLine2: Record "Prod. Order Line"; SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary; ProdOrdLine: Record "Prod. Order Line")
    var
        PrOL: Record "Prod. Order Line";
        LastLineNo: Integer;
    begin
        PrOL.Reset();
        Clear(LastLineNo);

        PrOL.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
        if PrOL.FindLast() then begin
            LastLineNo := PrOL."Line No.";
        end;

        if LastLineNo mod 10000 > 0 then begin
            LastLineNo += LastLineNo mod 10000;
        end else begin
            LastLineNo += 10000;
        end;

        ProdOrdLine2.Init();
        ProdOrdLine2.Status := ProdOrdLine2.Status::Released;
        ProdOrdLine2."Prod. Order No." := SortProdOrderRec."Sortation Prod. Order No.";
        ProdOrdLine2."Line No." := LastLineNo;
        ProdOrdLine2.Validate("Item No.", SortProdOrderRec."Sorted Item No.");
        ProdOrdLine2.Validate("Variant Code", SortProdOrderRec."Variant Changes");
        ProdOrdLine2.Validate("Location Code", ProdOrdLine."Location Code");
        ProdOrdLine2."Bin Code" := ProdOrdLine."Bin Code";
        ProdOrdLine2.Validate(Quantity, SortProdOrderRec.Quantity);
        ProdOrdLine2.Validate("Unit of Measure Code", SortProdOrderRec."Unit of Measure Code");
        ProdOrdLine2.Validate("Routing No.", ProdOrdLine."Routing No.");
        ProdOrdLine2.Insert();
    end;

    /// <summary>Creates a new Production Order Routing Line from an existing Production Order Line.</summary>
    /// <remarks> Initializes and inserts a routing line linked to the source production order line with zeroed time values. </remarks>
    /// <param name="ProdOrdRoutLine">The production order routing line to be created and inserted.</param>
    /// <param name="ProdOrdLine">The reference production order line providing base data.</param>
    procedure CreateNEwProdOrdRoutingLinefromProdOrdLine(var ProdOrdRoutLine2: Record "Prod. Order Routing Line"; ProdOrdLine2: Record "Prod. Order Line"; ProdOrdLine1: Record "Prod. Order Line")
    var
        ProdOrdRoutLine1: Record "Prod. Order Routing Line";
    begin
        ProdOrdRoutLine1.Reset();
        ProdOrdRoutLine1.SetRange("Prod. Order No.", ProdOrdLine1."Prod. Order No.");
        ProdOrdRoutLine1.SetRange(Status, ProdOrdLine1.Status);
        ProdOrdRoutLine1.SetRange("Routing Reference No.", ProdOrdLine1."Routing Reference No.");
        ProdOrdRoutLine1.SetRange("Routing No.", ProdOrdLine1."Routing No.");
        if ProdOrdRoutLine1.FindFirst() then begin
            ProdOrdRoutLine2.Init();
            ProdOrdRoutLine2.Status := ProdOrdLine2.Status;
            ProdOrdRoutLine2."Routing No." := ProdOrdRoutLine1."Routing No.";
            ProdOrdRoutLine2."Prod. Order No." := ProdOrdLine2."Prod. Order No.";
            ProdOrdRoutLine2."Routing Reference No." := ProdOrdLine2."Line No.";
            ProdOrdRoutLine2."Operation No." := ProdOrdRoutLine1."Operation No.";
            ProdOrdRoutLine2.Type := ProdOrdRoutLine1.Type;
            ProdOrdRoutLine2."No." := ProdOrdRoutLine1."No.";
            ProdOrdRoutLine2.Description := ProdOrdRoutLine1.Description;
            ProdOrdRoutLine2."Run Time" := 0;
            ProdOrdRoutLine2."Setup Time" := 0;
            ProdOrdRoutLine2."Wait Time" := 0;
            ProdOrdRoutLine2."Move Time" := 0;
            ProdOrdRoutLine2.Insert();
        end;

    end;

    ///<summary>Checks if an existing Assembly Order with matching item, variant, location, date, and production details already exists, returning true if found.</summary>
    local procedure IsASOFoundExisting(var AssemblyHeader: Record "Assembly Header"): Boolean
    var
        ASO: Record "Assembly Header";
    begin
        ASO.Reset();
        ASO.SetRange("Document Type", AssemblyHeader."Document Type");
        ASO.SetRange("Item No.", AssemblyHeader."Item No.");
        ASO.SetFilter("Variant Code", AssemblyHeader."Variant Code");
        ASO.SetRange("Location Code", AssemblyHeader."Location Code");
        ASO.SetRange("Due Date", AssemblyHeader."Due Date");
        ASO.SetRange("Posting Date", AssemblyHeader."Posting Date");
        ASO.SetRange("PMP15 Prod. Order No.", AssemblyHeader."PMP15 Prod. Order No.");
        ASO.SetRange("PMP15 Production Type", AssemblyHeader."PMP15 Production Type");
        ASO.SetFilter("PMP15 Sub Merk 1", AssemblyHeader."PMP15 Sub Merk 1");
        ASO.SetFilter("PMP15 Sub Merk 2", AssemblyHeader."PMP15 Sub Merk 2");
        ASO.SetFilter("PMP15 Sub Merk 3", AssemblyHeader."PMP15 Sub Merk 3");
        ASO.SetRange("PMP15 Rework", AssemblyHeader."PMP15 Rework");
        if ASO.Count > 1 then begin
            ASO.FindFirst();
            AssemblyHeader := ASO;
            exit(true);
        end else
            exit(false);
    end;

    // ONE OF THE MOST IMPORTANT FUNCTION IN THIS CODEUNIT
    /// <summary>Processes and posts a Sortation Production Order recording according to the specified Sortation Step.</summary>
    /// <remarks>This procedure orchestrates end-to-end handling of a single Sortation Production Order record for the provided step. Behaviour per step: Step "0" creates an Assembly Order and associated lines, generates reservations and tracking, and posts the assembly; Steps "1"–"3" prepare and post item reclassification journals; Step "4" handles output and consumption journals and additional logic for tobacco types (Wrapper, PW, Filler or variant-changed items), including creation of production order lines/routings when required. The procedure performs data lookups, validation, temporary record preparation, insert/commit operations, posting via codeunits/pages, and raises descriptive errors on validation or processing failures. It depends on company setup configuration and multiple helper procedures (for creating assembly records, generating journals, posting routines, and creating SOR detail results). Side effects include inserts, modifications, journal postings, commits, user messages and error conditions; callers should ensure transactional expectations and handle exceptions as appropriate.</remarks>
    /// <param name="ProdOrder">The Production Order record that is the source or target of the sortation processing.</param>
    /// <param name="SortProdOrderRec">Temporary PMP15 Sortation Production Order Recording that contains the sortation details to be processed.</param>
    /// <param name="SORStep_Step">The Sortation Step Enum value indicating which processing branch to execute.</param>
    // LA TEMPORAIRE | parameter IsSuppressCommit should be removed in Proudction
    procedure SortProdOrdRecordingPost(var ProdOrder: Record "Production Order"; var SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary; SORStep_Step: Enum "PMP15 Sortation Step Enum"; IsSuppressCommit: Boolean)
    var
        AssemblyPostMgmt: Codeunit "Assembly-Post";
        SORStepEnum: Enum "PMP15 Sortation Step Enum";
        ProdCompItemTypeQuery: Query "PMP15Prod-Comp. ItemType Query";
        ExtCompanySetup: Record "PMP07 Extended Company Setup";
        AssemblyHeader: Record "Assembly Header";       // ASSEMBLY
        AssemblyLine: Record "Assembly Line";           // ASSEMBLY
        tempItemJnlLine: Record "Item Journal Line" temporary;  // ITEM JOURNAL LINE
        ItemJnlLine: Record "Item Journal Line";                // ITEM JOURNAL LINE
        ItemJnlLine2: Record "Item Journal Line";
        ProdOrdLine: Record "Prod. Order Line";         // PRODUCTION ORDER LINE
        ProdOrdLine2: Record "Prod. Order Line";        // ------ IDEN ------
        ProdOrdComp: Record "Prod. Order Component";    // PRODUCTION ORDER COMPONENT LINE
        PWItem: Record "Prod. Order Component";         // PW ITEM
        FILLERItem: Record "Prod. Order Component";     // FILLER ITEM
        ProdOrdRoutLine: Record "Prod. Order Routing Line";
        ItemProdType: Record "PMP07 Production Item Type";
        Item: Record Item;
        IsSuccessInsertItemJnlLine, IsPWItemFound, IsFILLERItemFound : Boolean;
    begin
        ExtCompanySetup.Get();
        AssemblyHeader.Reset();
        AssemblyLine.Reset();
        tempItemJnlLine.DeleteAll();
        tempItemJnlLine.Reset();
        ItemJnlLine.Reset();
        ItemJnlLine2.Reset();
        ProdOrdLine.Reset();
        ProdOrdComp.Reset();
        PWItem.Reset();
        FILLERItem.Reset();
        ProdOrdRoutLine.Reset();
        ItemProdType.Reset();
        Item.Reset();
        Clear(IsSuccessInsertItemJnlLine);
        Clear(IsPWItemFound);
        Clear(IsFILLERItemFound);

        case SORStep_Step of
            SORStep_Step::"0":
                begin
                    #region SOR REC POST | STEP 0
                    GetProdOrderCropfromPkgNoInfo(ProdOrder, SortProdOrderRec."Package No.");
                    CreateAssemblyHeadfromSORRecording(AssemblyHeader, ProdOrder, SortProdOrderRec, SORStep_Step);
                    if IsASOFoundExisting(AssemblyHeader) then begin
                        DeleteAllAssemblyLineinDocumentOrder(AssemblyHeader);
                    end;
                    CreateAssemblyLinefromSORRecording(AssemblyLine, AssemblyHeader, ProdOrder, SortProdOrderRec);

                    GenerateItemReservEntryAssemblyHeader(AssemblyHeader, ProdOrder, SortProdOrderRec);
                    GenerateItemTrackingAssemblyLine(AssemblyHeader, ProdOrder, SortProdOrderRec);
                    // Commit(); //
                    // Error('HALT');

                    AssemblyPostMgmt.Run(AssemblyHeader);
                    // if AssemblyPostMgmt.Run(AssemblyHeader) then
                    Message('The sortation production order posting in the %1-Step for Assembly Item %2  is successfully posted.', SORStep_Step, SortProdOrderRec."Unsorted Item No.")
                    // else
                    // Message('The sortation production order posting in the %1-Step for Assembly Item %2  is failed to posting.', SORStep_Step, SortProdOrderRec."Unsorted Item No.");
                    #endregion SOR REC POST | STEP 0
                end;
            SORStep_Step::"1", SORStep_Step::"2", SORStep_Step::"3":
                begin
                    #region SOR REC POST | STEP 1-3
                    ItemJnlLine.SetRange("Journal Template Name", ExtCompanySetup."PMP15SORItemReclass.Jnl.Tmpt.");
                    ItemJnlLine.SetRange("Journal Batch Name", ExtCompanySetup."PMP15SORItemReclass.Jnl.Batch");
                    ItemJnlLine.SetRange("PMP15 Marked", true);
                    if ItemJnlLine.FindLast() OR (ItemJnlLine.Count = 0) then begin // As Validation before insertion
                        IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step);
                    end;
                    if IsSuccessInsertItemJnlLine then begin
                        InsertItemJnlLinefromTemp(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step);
                        GenerateRecReserveEntryItemJnlLine(ItemJnlLine, SortProdOrderRec);
                        // Commit(); //
                    end;
                    ItemJnlLine.MarkedOnly(true);
                    PostItemReclassJnlSOR(SortProdOrderRec, ItemJnlLine);
                    #endregion SOR REC POST | STEP 1-3
                end;
            SORStep_Step::"4":
                begin
                    if SortProdOrderRec."Variant Changes" = '' then begin
                        case SortProdOrderRec."Tobacco Type" of
                            SortProdOrderRec."Tobacco Type"::Wrapper:
                                begin
                                    #region SOR REC POST | STEP 4 WRAPPER
                                    // OUTPUT JOURNAL
                                    ItemJnlLine.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Output Jnl. Template");
                                    ItemJnlLine.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Output Jnl. Batch");
                                    ItemJnlLine.SetRange("PMP15 Marked", true);
                                    if ItemJnlLine.FindLast() OR (ItemJnlLine.Count = 0) then begin // As Validation before insertion
                                        IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine."Entry Type"::Output);
                                    end;
                                    if IsSuccessInsertItemJnlLine then begin
                                        ItemJnlLine.Reset();
                                        InsertItemJnlLinefromTemp(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step);
                                        GenerateRecReserveEntryItemJnlLine(ItemJnlLine, SortProdOrderRec);
                                        // Commit(); //
                                        // ItemJnlLine2 := ItemJnlLine;
                                        // ItemJnlLine.PostingItemJnlFromProduction(false);
                                        // InsertSORDetailResultfromItemJnlLine(ItemJnlLine, SortProdOrderRec);

                                        Clear(IsSuccessInsertItemJnlLine);
                                        // ItemJnlLine2.Reset();
                                        tempItemJnlLine.DeleteAll();
                                    end else
                                        Error('Failed to creating the Output Journal before posting.');

                                    // CONSUMPTION JOURNAL
                                    ItemJnlLine2.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Template");
                                    ItemJnlLine2.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch");
                                    ItemJnlLine2.SetRange("PMP15 Marked", true);
                                    if ItemJnlLine2.FindLast() OR (ItemJnlLine2.Count = 0) then begin // As Validation before insertion
                                        IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine2, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine2."Entry Type"::Consumption);
                                        // IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine2."Entry Type"::Consumption);
                                    end;
                                    if IsSuccessInsertItemJnlLine then begin
                                        ItemJnlLine2.Reset();
                                        InsertItemJnlLinefromTemp(ItemJnlLine2, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine2."Entry Type"::Consumption);
                                        GenerateRecReserveEntryItemJnlLine(ItemJnlLine2, SortProdOrderRec);
                                        // InsertItemJnlLinefromTemp(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine."Entry Type"::Consumption);
                                        // GenerateRecReserveEntryItemJnlLine(ItemJnlLine, SortProdOrderRec);
                                        if PreviewPostingItemJournalLine(ItemJnlLine, ItemJnlLine2) then begin
                                            // DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine);
                                            InsertSORDetailResultfromItemJnlLine(ItemJnlLine, SortProdOrderRec);
                                            SortProdOrderRec."Package No." := ItemJnlLine."Package No.";
                                            PostOUTPUTandthenCONSUMPItemJnlLineforSORProdRecording(ItemJnlLine, ItemJnlLine2);
                                            Message('The sortation production order posting in the %1-th Step for %2 Tobacco Type is successfully posted.', SORStep_Step, SortProdOrderRec."Tobacco Type");
                                        end else begin
                                            DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine);
                                            DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine2);
                                        end;
                                        DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine);
                                        DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine2);
                                    end else
                                        Error('Failed to creating the Consumption Journal after posting the Output Journal.');
                                    #endregion SOR REC POST | STEP 4 WRAPPER
                                end;
                            SortProdOrderRec."Tobacco Type"::PW:
                                begin
                                    #region SOR REC POST | STEP 4 PW
                                    ProdOrdLine.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                                    ProdOrdLine.SetRange("Item No.", SortProdOrderRec."Sorted Item No.");
                                    ProdOrdLine.SetFilter("Variant Code", SortProdOrderRec."Sorted Variant Code");
                                    if ProdOrdLine.FindFirst() then begin
                                        ItemProdType.SetRange("Production Item Type", ItemProdType."Production Item Type"::"Sortation-Sorted PW");
                                        if not ItemProdType.FindFirst() then
                                            Error('No Item Production Type configuration was found for Production Item Type "%1". Please ensure that the Item Production Type master data has been properly maintained for Sortation processing.', ItemProdType."Production Item Type"::"Sortation-Sorted PW");


                                        ProdOrdComp.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                                        ProdOrdComp.SetRange("Prod. Order Line No.", ProdOrdLine."Line No.");
                                        if ProdOrdComp.FindSet() then
                                            repeat
                                                ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.POCOMP_Status, ProdOrdComp.Status); // PK1
                                                ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.POCOMP_ProdOrderNo, ProdOrdComp."Prod. Order No."); // PK2
                                                ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.POCOMP_ProdOrderLineNo, ProdOrdComp."Prod. Order Line No."); // PK3
                                                ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.POCOMP_LineNo, ProdOrdComp."Line No."); // PK4
                                                ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.POCOMP_ItemNo, ProdOrdComp."Item No.");
                                                ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.POCOMP_LocationCode, ProdOrdComp."Location Code");
                                                if ItemProdType."Item Group" <> '' then
                                                    ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.ITEM_PMP04ItemGroup, ItemProdType."Item Group");
                                                if ItemProdType."Item Category Code" <> '' then
                                                    ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.ITEM_ItemCategoryCode, ItemProdType."Item Category Code");
                                                if ItemProdType."Item Class L1" <> '' then
                                                    ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.ITEM_PMP04ItemClassL1, ItemProdType."Item Class L1");
                                                if ItemProdType."Item Class L2" <> '' then
                                                    ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.ITEM_PMP04ItemClassL2, ItemProdType."Item Class L2");
                                                if ItemProdType."Item Type L1" <> '' then
                                                    ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.ITEM_PMP04ItemTypeL1, ItemProdType."Item Type L1");
                                                if ItemProdType."Item Type L2" <> '' then
                                                    ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.ITEM_PMP04ItemTypeL2, ItemProdType."Item Type L2");
                                                if ItemProdType."Item Type L3" <> '' then
                                                    ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.ITEM_PMP04ItemTypeL3, ItemProdType."Item Type L3");
                                                ProdCompItemTypeQuery.Open();

                                                if ProdCompItemTypeQuery.Read() then begin
                                                    PWItem := ProdOrdComp;
                                                    IsPWItemFound := true;
                                                end;

                                                ProdCompItemTypeQuery.Close();

                                            //         if Item.Get(ProdOrdComp."Item No.") then begin
                                            //             if (Item."PMP04 Item Group" = ItemProdType."Item Group") and (Item."Item Category Code" = ItemProdType."Item Category Code") and (Item."PMP04 Item Class L1" = ItemProdType."Item Class L1") and (Item."PMP04 Item Class L2" = ItemProdType."Item Class L2") and (Item."PMP04 Item Type L1" = ItemProdType."Item Type L1") and (Item."PMP04 Item Type L2" = ItemProdType."Item Type L2") and (Item."PMP04 Item Type L3" = ItemProdType."Item Type L3") then begin
                                            //                 PWItem := ProdOrdComp;
                                            //                 IsPWItemFound := true;
                                            //             end;
                                            //         end;
                                            until (ProdOrdComp.Next() = 0) OR IsPWItemFound;
                                    end;

                                    if IsPWItemFound then begin
                                        ProdOrdLine2.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                                        ProdOrdLine2.SetRange("Item No.", PWItem."Item No.");
                                        ProdOrdLine2.SetRange("Variant Code", PWItem."Variant Code");
                                        if ProdOrdLine2.FindFirst() then begin
                                            // If found then go to step 5)
                                            // SKIP OR DO NOTHING
                                        end else begin
                                            // If not found then go to step 3)
                                            CreateNewSORProdOrdLine(ProdOrdLine2, SortProdOrderRec, PWItem, ProdOrdLine);
                                            CreateNEwProdOrdRoutingLinefromProdOrdLine(ProdOrdRoutLine, ProdOrdLine2, ProdOrdLine);
                                        end;
                                    end else
                                        Error('Failed to identify a valid PW Item for the current Sortation process. Item : %1 (%2) | Production Order : %3 | Please ensure that the correct PW Item is configured in the Production Order Component lines and meets the required classification rules defined in the Item Production Type.', SortProdOrderRec."Sorted Item No.", SortProdOrderRec."Sorted Variant Code", SortProdOrderRec."Sortation Prod. Order No.");

                                    // OUTPUT JOURNAL
                                    ItemJnlLine.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Output Jnl. Template");
                                    ItemJnlLine.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Output Jnl. Batch");
                                    ItemJnlLine.SetRange("PMP15 Marked", true);
                                    if ItemJnlLine.FindLast() OR (ItemJnlLine.Count = 0) then begin // As Validation before insertion
                                        IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine."Entry Type"::Output, ProdOrdLine2, ProdOrdRoutLine, PWItem);
                                    end;
                                    if IsSuccessInsertItemJnlLine then begin
                                        ItemJnlLine.Reset();
                                        InsertItemJnlLinefromTemp(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step);
                                        GenerateRecReserveEntryItemJnlLine(ItemJnlLine, SortProdOrderRec);
                                        // ItemJnlLine2 := ItemJnlLine;
                                        // ItemJnlLine.PostingItemJnlFromProduction(false);
                                        // InsertSORDetailResultfromItemJnlLine(ItemJnlLine, SortProdOrderRec);

                                        Clear(IsSuccessInsertItemJnlLine);
                                        ItemJnlLine2.Reset();
                                        tempItemJnlLine.DeleteAll();
                                    end else
                                        Error('Failed to creating the Output Journal before posting.');

                                    // CONSUMPTION JOURNAL
                                    ItemJnlLine2.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Template");
                                    ItemJnlLine2.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch");
                                    ItemJnlLine2.SetRange("PMP15 Marked", true);
                                    if ItemJnlLine2.FindLast() OR (ItemJnlLine2.Count = 0) then begin // As Validation before insertion
                                        IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine2, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine2."Entry Type"::Consumption, ProdOrdLine2, ProdOrdRoutLine, PWItem);
                                        // IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine2, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine2."Entry Type"::Consumption, ProdOrdLine2, ProdOrdRoutLine, FILLERItem);
                                    end;
                                    if IsSuccessInsertItemJnlLine then begin
                                        ItemJnlLine2.Reset();
                                        InsertItemJnlLinefromTemp(ItemJnlLine2, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine2."Entry Type"::Consumption);
                                        GenerateRecReserveEntryItemJnlLine(ItemJnlLine2, SortProdOrderRec);
                                        // ItemJnlLine2.PostingItemJnlFromProduction(false);

                                        if IsSuppressCommit then begin
                                            Commit();
                                            Error('Der Prozess ist angehalten. Bitte prüfen Sie das Output- und Verbrauchs-journal, um die zu überprüfen.');
                                        end;
                                        if PreviewPostingItemJournalLine(ItemJnlLine, ItemJnlLine2) then begin
                                            InsertSORDetailResultfromItemJnlLine(ItemJnlLine, SortProdOrderRec);
                                            SortProdOrderRec."Package No." := ItemJnlLine."Package No.";
                                            PostOUTPUTandthenCONSUMPItemJnlLineforSORProdRecording(ItemJnlLine, ItemJnlLine2);
                                        end else begin
                                            DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine);
                                            DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine2);
                                        end;
                                        DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine);
                                        DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine2);
                                        Message('The sortation production order posting in the %1-th Step for %2 Tobacco Type is successfully posted.', SORStep_Step, SortProdOrderRec."Tobacco Type");
                                    end else
                                        Error('Failed to creating the Consumption Journal after posting the Output Journal.');
                                    #endregion SOR REC POST | STEP 4 PW
                                end;
                            SortProdOrderRec."Tobacco Type"::Filler:
                                begin
                                    #region SOR REC POST | STEP 4 FILLER
                                    ProdOrdLine.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                                    ProdOrdLine.SetRange("Item No.", SortProdOrderRec."Sorted Item No.");
                                    ProdOrdLine.SetFilter("Variant Code", SortProdOrderRec."Sorted Variant Code");
                                    if ProdOrdLine.FindFirst() then begin
                                        ItemProdType.SetRange("Production Item Type", ItemProdType."Production Item Type"::"Sortation-Filler");
                                        if not ItemProdType.FindFirst() then
                                            Error('No Item Production Type configuration was found for Production Item Type "%1". Please ensure that the Item Production Type master data has been properly maintained for Sortation processing.', ItemProdType."Production Item Type"::"Sortation-Filler");

                                        ProdOrdComp.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                                        ProdOrdComp.SetRange("Prod. Order Line No.", ProdOrdLine."Line No.");
                                        if ProdOrdComp.FindSet() then
                                            repeat
                                                // if Item.Get(ProdOrdComp."Item No.") then begin
                                                //     if (Item."PMP04 Item Group" = ItemProdType."Item Group") and (Item."Item Category Code" = ItemProdType."Item Category Code") and (Item."PMP04 Item Class L1" = ItemProdType."Item Class L1") and (Item."PMP04 Item Class L2" = ItemProdType."Item Class L2") and (Item."PMP04 Item Type L1" = ItemProdType."Item Type L1") and (Item."PMP04 Item Type L2" = ItemProdType."Item Type L2") and (Item."PMP04 Item Type L3" = ItemProdType."Item Type L3") then begin
                                                //         FILLERItem := ProdOrdComp;
                                                //         IsFILLERItemFound := true;
                                                //     end;
                                                // end;

                                                ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.POCOMP_Status, ProdOrdComp.Status); // PK1
                                                ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.POCOMP_ProdOrderNo, ProdOrdComp."Prod. Order No."); // PK2
                                                ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.POCOMP_ProdOrderLineNo, ProdOrdComp."Prod. Order Line No."); // PK3
                                                ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.POCOMP_LineNo, ProdOrdComp."Line No."); // PK4
                                                ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.POCOMP_ItemNo, ProdOrdComp."Item No.");
                                                ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.POCOMP_LocationCode, ProdOrdComp."Location Code");
                                                if ItemProdType."Item Group" <> '' then
                                                    ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.ITEM_PMP04ItemGroup, ItemProdType."Item Group");
                                                if ItemProdType."Item Category Code" <> '' then
                                                    ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.ITEM_ItemCategoryCode, ItemProdType."Item Category Code");
                                                if ItemProdType."Item Class L1" <> '' then
                                                    ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.ITEM_PMP04ItemClassL1, ItemProdType."Item Class L1");
                                                if ItemProdType."Item Class L2" <> '' then
                                                    ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.ITEM_PMP04ItemClassL2, ItemProdType."Item Class L2");
                                                if ItemProdType."Item Type L1" <> '' then
                                                    ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.ITEM_PMP04ItemTypeL1, ItemProdType."Item Type L1");
                                                if ItemProdType."Item Type L2" <> '' then
                                                    ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.ITEM_PMP04ItemTypeL2, ItemProdType."Item Type L2");
                                                if ItemProdType."Item Type L3" <> '' then
                                                    ProdCompItemTypeQuery.SetRange(ProdCompItemTypeQuery.ITEM_PMP04ItemTypeL3, ItemProdType."Item Type L3");
                                                ProdCompItemTypeQuery.Open();

                                                if ProdCompItemTypeQuery.Read() then begin
                                                    FILLERItem := ProdOrdComp;
                                                    IsFILLERItemFound := true;
                                                end;

                                                ProdCompItemTypeQuery.Close();
                                            until (ProdOrdComp.Next() = 0) OR IsFILLERItemFound;
                                    end;

                                    if IsFILLERItemFound then begin
                                        ProdOrdLine2.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                                        ProdOrdLine2.SetRange("Item No.", FILLERItem."Item No.");
                                        ProdOrdLine2.SetRange("Variant Code", FILLERItem."Variant Code");
                                        if ProdOrdLine2.FindFirst() then begin
                                            // If found then go to step 5)
                                        end else begin
                                            // If not found then go to step 3)
                                            CreateNewSORProdOrdLine(ProdOrdLine2, SortProdOrderRec, FILLERItem, ProdOrdLine);
                                            CreateNEwProdOrdRoutingLinefromProdOrdLine(ProdOrdRoutLine, ProdOrdLine2, ProdOrdLine);
                                        end;
                                    end else
                                        Error('Failed to identify a valid Filler Item for the current Sortation process. Item : %1 (%2) | Production Order : %3 | Please ensure that the correct Filler Item is configured in the Production Order Component lines and meets the required classification rules defined in the Item Production Type.', SortProdOrderRec."Sorted Item No.", SortProdOrderRec."Sorted Variant Code", SortProdOrderRec."Sortation Prod. Order No.");

                                    // OUTPUT JOURNAL
                                    ItemJnlLine.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Output Jnl. Template");
                                    ItemJnlLine.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Output Jnl. Batch");
                                    ItemJnlLine.SetRange("PMP15 Marked", true);
                                    if ItemJnlLine.FindLast() OR (ItemJnlLine.Count = 0) then begin // As Validation before insertion
                                        IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine."Entry Type"::Output, ProdOrdLine2, ProdOrdRoutLine, FILLERItem);
                                    end;
                                    if IsSuccessInsertItemJnlLine then begin
                                        ItemJnlLine.Reset();
                                        InsertItemJnlLinefromTemp(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step);
                                        GenerateRecReserveEntryItemJnlLine(ItemJnlLine, SortProdOrderRec);
                                        // ItemJnlLine2 := ItemJnlLine;
                                        // ItemJnlLine.PostingItemJnlFromProduction(false);
                                        // InsertSORDetailResultfromItemJnlLine(ItemJnlLine, SortProdOrderRec);

                                        Clear(IsSuccessInsertItemJnlLine);
                                        ItemJnlLine2.Reset();
                                        tempItemJnlLine.DeleteAll();
                                    end else
                                        Error('Failed to creating the Output Journal before posting.');

                                    // CONSUMPTION JOURNAL
                                    ItemJnlLine2.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Template");
                                    ItemJnlLine2.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch");
                                    ItemJnlLine2.SetRange("PMP15 Marked", true);
                                    if ItemJnlLine2.FindLast() OR (ItemJnlLine2.Count = 0) then begin // As Validation before insertion
                                        IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine2, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine2."Entry Type"::Consumption, ProdOrdLine2, ProdOrdRoutLine, FILLERItem);
                                    end;
                                    if IsSuccessInsertItemJnlLine then begin
                                        ItemJnlLine2.Reset();
                                        InsertItemJnlLinefromTemp(ItemJnlLine2, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine2."Entry Type"::Consumption);
                                        GenerateRecReserveEntryItemJnlLine(ItemJnlLine2, SortProdOrderRec);
                                        // ItemJnlLine2.PostingItemJnlFromProduction(false);

                                        if IsSuppressCommit then begin
                                            Commit();
                                            Error('Der Prozess ist angehalten. Bitte prüfen Sie das Output- und Verbrauchs-journal, um die zu überprüfen.');
                                        end;
                                        if PreviewPostingItemJournalLine(ItemJnlLine, ItemJnlLine2) then begin
                                            // DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine);
                                            InsertSORDetailResultfromItemJnlLine(ItemJnlLine, SortProdOrderRec);
                                            SortProdOrderRec."Package No." := ItemJnlLine."Package No.";
                                            PostOUTPUTandthenCONSUMPItemJnlLineforSORProdRecording(ItemJnlLine, ItemJnlLine2);
                                        end else begin
                                            DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine);
                                            DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine2);
                                        end;
                                        DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine);
                                        DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine2);
                                        Message('The sortation production order posting in the %1-th Step for %2 Tobacco Type is successfully posted.', SORStep_Step, SortProdOrderRec."Tobacco Type");
                                    end else
                                        Error('Failed to creating the Consumption Journal after posting the Output Journal.');
                                    #endregion SOR REC POST | STEP 4 FILLER
                                end;
                        end;
                    end else begin
                        #region SOR REC POST | STEP 4 VARIANT CHANGES
                        // Jadi fungsi ini mengenai membuat prod ord line dibawah dengan variant yang berbeda, dan copas dari yang sorted item.
                        ProdOrdLine2.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                        ProdOrdLine2.SetRange("Item No.", SortProdOrderRec."Sorted Item No.");
                        ProdOrdLine2.SetFilter("Variant Code", SortProdOrderRec."Variant Changes");
                        if ProdOrdLine2.FindFirst() then begin
                            // If found then go to step 5)
                        end else begin
                            // If not found then go to step 3)
                            ProdOrdLine.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                            ProdOrdLine.SetRange("Item No.", SortProdOrderRec."Sorted Item No.");
                            ProdOrdLine.SetFilter("Variant Code", SortProdOrderRec."Sorted Variant Code");
                            if ProdOrdLine.FindFirst() then begin
                                CreateNewSORProdOrdLine(ProdOrdLine2, SortProdOrderRec, ProdOrdLine);
                                CreateNEwProdOrdRoutingLinefromProdOrdLine(ProdOrdRoutLine, ProdOrdLine2, ProdOrdLine);
                            end;
                        end;

                        // OUTPUT JOURNAL
                        ItemJnlLine.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Output Jnl. Template");
                        ItemJnlLine.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Output Jnl. Batch");
                        ItemJnlLine.SetRange("PMP15 Marked", true);
                        if ItemJnlLine.FindLast() OR (ItemJnlLine.Count = 0) then begin // As Validation before insertion
                            IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine."Entry Type"::Output, ProdOrdLine2, ProdOrdRoutLine, ProdOrdComp); // FYI, the Production Order Component is not utlized here, so just let it be here.
                        end;
                        if IsSuccessInsertItemJnlLine then begin
                            ItemJnlLine.Reset();
                            InsertItemJnlLinefromTemp(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step);
                            GenerateRecReserveEntryItemJnlLine(ItemJnlLine, SortProdOrderRec);
                            // ItemJnlLine2 := ItemJnlLine;
                            // ItemJnlLine.PostingItemJnlFromProduction(false);
                            // InsertSORDetailResultfromItemJnlLine(ItemJnlLine, SortProdOrderRec);

                            Clear(IsSuccessInsertItemJnlLine);
                            ItemJnlLine2.Reset();
                            tempItemJnlLine.DeleteAll();
                        end else
                            Error('Failed to creating the Output Journal before posting.');

                        // CONSUMPTION JOURNAL
                        ItemJnlLine2.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Template");
                        ItemJnlLine2.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch");
                        ItemJnlLine2.SetRange("PMP15 Marked", true);
                        if ItemJnlLine2.FindLast() OR (ItemJnlLine2.Count = 0) then begin // As Validation before insertion
                            IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine2, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine2."Entry Type"::Consumption, ProdOrdLine2, ProdOrdRoutLine, ProdOrdComp);
                        end;
                        if IsSuccessInsertItemJnlLine then begin
                            ItemJnlLine2.Reset();
                            InsertItemJnlLinefromTemp(ItemJnlLine2, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine2."Entry Type"::Consumption);
                            GenerateRecReserveEntryItemJnlLine(ItemJnlLine2, SortProdOrderRec);
                            // ItemJnlLine2.PostingItemJnlFromProduction(false);

                            if IsSuppressCommit then begin
                                Commit();
                                Error('Der Prozess ist angehalten. Bitte prüfen Sie das Output- und Verbrauchs-journal, um die zu überprüfen.');
                            end;
                            if PreviewPostingItemJournalLine(ItemJnlLine, ItemJnlLine2) then begin
                                // DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine);
                                InsertSORDetailResultfromItemJnlLine(ItemJnlLine, SortProdOrderRec);
                                SortProdOrderRec."Package No." := ItemJnlLine."Package No.";
                                PostOUTPUTandthenCONSUMPItemJnlLineforSORProdRecording(ItemJnlLine, ItemJnlLine2);
                            end else begin
                                DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine);
                                DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine2);
                            end;
                            DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine);
                            DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine2);
                            Message('The sortation production order posting in the %1-th Step for %2 Tobacco Type is successfully posted.', SORStep_Step, SortProdOrderRec."Tobacco Type");
                        end else
                            Error('Failed to creating the Consumption Journal after posting the Output Journal.');
                        #endregion SOR REC POST | STEP 4 VARIANT CHANGES
                    end;
                end;
            else
                Error('There is no valid Step detected (Current Step: "%1" for Tobacco Type "%2").', SORStep_Step, SortProdOrderRec."Tobacco Type"); // NUR TEMPORÄR, NIX DAUERLÖSUNG!!!
        end;
    end;

    /// <summary>Posts the Sortation Reclassification Item Journal.</summary>
    /// <remarks>This procedure executes the posting of the Item Journal Line that was prepared for Sortation Reclassification using the standard <c>Item Jnl.-Post</c> codeunit. Upon successful execution, it displays a confirmation message; otherwise, it notifies the user that posting has failed. The posting action finalizes stock movements defined in the journal lines related to the Sortation process.</remarks>
    /// <param name="ItemJnlLine">The Item Journal Line record containing the Sortation Reclassification transaction data to be posted.</param>
    /// <param name="SortProdOrderRec">The temporary Sortation Production Order Recording that provides contextual information for the posting process.</param>
    procedure PostItemReclassJnlSOR(var SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary; var ItemJnlLine: Record "Item Journal Line")
    var
        ItemJnlBatchPostMgmt: Codeunit "Item Jnl.-Post Batch";
        ItemJnlPostLineMgmt: Codeunit "Item Jnl.-Post Line";
    begin
        ItemJnlBatchPostMgmt.SetSuppressCommit(true);
        ItemJnlBatchPostMgmt.Run(ItemJnlLine);

        Message('The Reclassification Journal is successfully posted.')
    end;

    /// <summary>Posts <b>OUTPUT</b> Item Journal Lines first, then posts the corresponding <b>CONSUMPTION</b> Item Journal Lines for <b>SOR Production Recording</b>.</summary>
    local procedure PostOUTPUTandthenCONSUMPItemJnlLineforSORProdRecording(var ItemJnlLine: Record "Item Journal Line"; var ItemJnlLine2: Record "Item Journal Line")
    var
        ItemJnlPostMgmt: Codeunit "Item Jnl.-Post";
        ItemJnlBatchPostMgmt: Codeunit "Item Jnl.-Post Batch";
        ItemJnlPostLineMgmt: Codeunit "Item Jnl.-Post Line";
    begin
        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/14 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
        // Error('ItemJnlLine.GetFilters() = %1', ItemJnlLine.GetFilters());
        // ItemJnlLine.MarkedOnly(true);
        // if ItemJnlLine.FindSet() then
        //     repeat
        // ItemJnlPostMgmt.SetPreviewMode(true);
        // ItemJnlPostMgmt.Run(ItemJnlLine);
        // ItemJnlLine.PostingItemJnlFromProduction(false);

        // ItemJnlPostLineMgmt.Run(ItemJnlLine);
        //     ItemJnlBatchPostMgmt.SetSuppressCommit(true);
        //     ItemJnlBatchPostMgmt.Run(ItemJnlLine);
        // until ItemJnlLine.Next() = 0;

        ItemJnlLine.MarkedOnly(true);
        // ItemJnlBatchPostMgmt.SetSuppressCommit(true);
        ItemJnlBatchPostMgmt.Run(ItemJnlLine);

        ItemJnlLine2.MarkedOnly(true);
        // ItemJnlBatchPostMgmt.SetSuppressCommit(true);
        ItemJnlBatchPostMgmt.Run(ItemJnlLine2);
        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/14 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
    end;

    #endregion SOR RECORDING



    #region SOR INSPECTION PACKING LIST
    /// <summary>Initializes numbering, dates, and default setup values before inserting a <b>SOR Inspection Package Header</b>.</summary>
    [EventSubscriber(ObjectType::Table, Database::"PMP15 SOR Inspection Pkg Headr", OnBeforeInsertEvent, '', false, false)]
    local procedure PMP15SetInitValBeforeInsert_OnBeforeInsertEvent(var Rec: Record "PMP15 SOR Inspection Pkg Headr"; RunTrigger: Boolean)
    var
        IsHandled: Boolean;
        ExtComSetup: Record "PMP07 Extended Company Setup";
    begin
        IsHandled := false;
        OnBeforeInsert(Rec, IsHandled);
        if IsHandled then
            exit;

        if Rec."No." = '' then begin
            ExtComSetup.Get();
            PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Location Code"));
            PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Inspection Pkg. Nos."));
            CheckProductionItemTypeforSortationInspectionisExist();

            Rec."No. Series" := ExtComSetup."PMP15 SOR Inspection Pkg. Nos.";
            Rec."No." := NoSeriesMgmt.GetNextNo(Rec."No. Series");
        end;
        Rec."Created Date" := WorkDate();
        Rec."Created By" := UserId();
        Rec."Posting Date" := WorkDate();
    end;

    ///<summary>Automatically assigns the New Item Code & Location Code on a new Sortation Inspection Package Line based on the related Inspection Header.</summary>
    [EventSubscriber(ObjectType::Table, Database::"PMP15 SOR Inspection Pkg. Line", OnAfterInsertEvent, '', false, false)]
    local procedure PMP15SetValAfterInsert_OnAfterInsertEvent(var Rec: Record "PMP15 SOR Inspection Pkg. Line"; RunTrigger: Boolean)
    begin
        ExtCompanySetup.Get();

        Rec.Validate(Result);

        if Rec."Location Code" = '' then begin
            ExtCompanySetup.Get();
            Rec."Location Code" := ExtCompanySetup."PMP15 SOR Location Code";
        end;
        Rec.Modify();
    end;

    /// <summary>Resets <b>Sorted Variant Code</b> and clears <b>Lot No.</b> when the Sorted Item No. changes or is cleared.</summary>
    [EventSubscriber(ObjectType::Table, Database::"PMP15 SOR Inspection Pkg Headr", OnAfterValidateEvent, "Sorted Item No.", false, false)]
    local procedure PMP15SetValue_OnAfterValidateEvent_SortedItemNo(var Rec: Record "PMP15 SOR Inspection Pkg Headr"; var xRec: Record "PMP15 SOR Inspection Pkg Headr"; CurrFieldNo: Integer)
    begin
        if (Rec."Sorted Item No." <> xRec."Sorted Item No.") OR (Rec."Sorted Item No." = '') then begin
            Rec.Validate("Sorted Variant Code", '');
            Clear(Rec."Lot No.");
        end;
    end;

    /// <summary>Clears <b>Lot No.</b> when the Sorted Variant Code is changed to ensure data consistency.</summary>
    [EventSubscriber(ObjectType::Table, Database::"PMP15 SOR Inspection Pkg Headr", OnAfterValidateEvent, "Sorted Variant Code", false, false)]
    local procedure PMP15SetValue_OnAfterValidateEvent_SortedVariantCode(var Rec: Record "PMP15 SOR Inspection Pkg Headr"; var xRec: Record "PMP15 SOR Inspection Pkg Headr"; CurrFieldNo: Integer)
    begin
        if (Rec."Sorted Variant Code" <> xRec."Sorted Variant Code") AND (Rec."Sorted Variant Code" <> '') then begin
            Clear(Rec."Lot No.");
        end;
    end;

    ///<summary>Sets the appropriate destination Bin Code based on the inspection Result value.</summary>
    [EventSubscriber(ObjectType::Table, Database::"PMP15 SOR Inspection Pkg. Line", OnAfterValidateEvent, Result, false, false)]
    local procedure PMP15ValidateResult_OnAfterValidateEvent_Result(var Rec: Record "PMP15 SOR Inspection Pkg. Line"; var xRec: Record "PMP15 SOR Inspection Pkg. Line"; CurrFieldNo: Integer)
    var
        BinRec: Record Bin;
        PackageNoInfor: Record "Package No. Information";
    begin
        BinRec.Reset();
        PackageNoInfor.Reset();

        case Rec.Result of
            Rec.Result::" ", Rec.Result::Accepted, Rec.Result::"Item Change":
                begin
                    BinRec.SetRange("PMP15 Bin Type", BinRec."PMP15 Bin Type"::Inspection);
                    if BinRec.FindFirst() then begin
                        Rec."To Bin Code" := BinRec.Code;
                    end;
                    Rec."New Sub Merk 1" := Rec."Sub Merk 1";
                    Rec."New Sub Merk 2" := Rec."Sub Merk 2";
                    Rec."New Sub Merk 3" := Rec."Sub Merk 3";
                    Rec."New Sub Merk 4" := Rec."Sub Merk 4";
                    Rec."New Sub Merk 5" := Rec."Sub Merk 5";
                    Rec."L/R" := Rec."New L/R";
                end;
            Rec.Result::Rework:
                begin
                    // LA TEMPORAIRE
                    // JIKA MEMILIH REWORK MAKA OTOMATIS SET NEW ITEM NO := UNSORTED ITEM | STANDARD := UNSORTED VARIANT CODE.
                    PackageNoInfor.SetRange("Item No.", Rec."Sorted Item No.");
                    PackageNoInfor.SetRange("Variant Code", Rec."Sorted Variant Code");
                    PackageNoInfor.SetRange("Package No.", Rec."Package No.");
                    PackageNoInfor.SetFilter("PMP04 Lot No.", Rec."Lot No.");
                    PackageNoInfor.SetRange("PMP15 Able to Sell", true);
                    PackageNoInfor.SetRange("PMP15 SOR Inspection Pckg. No.", Rec."Document No.");
                    if PackageNoInfor.FindFirst() then begin
                        Rec."New Item Code" := PackageNoInfor."PMP15 Unsorted Item No.";
                        Rec.Standard := PackageNoInfor."PMP15 Unsorted Variant Code";
                    end;

                    BinRec.SetRange("PMP15 Bin Type", BinRec."PMP15 Bin Type"::"3");
                    if BinRec.FindFirst() then begin
                        Rec."To Bin Code" := BinRec.Code;
                    end;
                end;
        end;
    end;

    /// <summary>Clears the linked <b>SOR Inspection Package No.</b> from Package No. Information before deleting an inspection line to maintain data integrity.</summary>
    [EventSubscriber(ObjectType::Table, Database::"PMP15 SOR Inspection Pkg. Line", OnBeforeDeleteEvent, '', false, false)]
    local procedure PMP15ValidateBeforeDeletion_OnBeforeDeleteEvent(var Rec: Record "PMP15 SOR Inspection Pkg. Line"; RunTrigger: Boolean)
    var
        PackageNoInfor: Record "Package No. Information";
        SORInspectHeadr: Record "PMP15 SOR Inspection Pkg Headr";
    begin
        SORInspectHeadr.Reset();
        PackageNoInfor.Reset();
        SORInspectHeadr.SetRange("No.", Rec."Document No.");
        if SORInspectHeadr.FindFirst() then begin
            PackageNoInfor.SetRange("PMP15 SOR Inspection Pckg. No.", Rec."Document No.");
            PackageNoInfor.SetRange("Package No.", Rec."Package No.");
            PackageNoInfor.SetRange("Item No.", Rec."Sorted Item No.");
            PackageNoInfor.SetFilter("Variant Code", Rec."Package Variant Code");
            // PackageNoInfor.SetRange("PMP15 Able to Sell", true);
            if PackageNoInfor.FindFirst() then begin
                Clear(PackageNoInfor."PMP15 SOR Inspection Pckg. No.");
                PackageNoInfor.Modify();
            end;
        end;
    end;

    // ONE OF THE MOST IMPORTANT FUNCTION IN THIS CODEUNIT
    /// <summary>Retrieves and assigns a package for inspection based on the current Sortation Inspection Package Header.</summary>
    /// <remarks>Validates setup and inspection inputs, filters available package data, and populates the inspection package line with relevant item and bin information.</remarks>
    /// <param name="SORInspectHeadr">The Sortation Inspection Package Header record to use as a reference for package retrieval and assignment.</param>
    procedure GetPackagetoInspect(var SORInspectHeadr: Record "PMP15 SOR Inspection Pkg Headr")
    var
        SORInspectPkgLine: Record "PMP15 SOR Inspection Pkg. Line";
        PackageNoInfor: Record "Package No. Information";
        BinContent: Record "Bin Content";
        BinRec: Record Bin;
        ProdItemTypeRec: Record "PMP07 Production Item Type";
        SortedItemRec, Item : Record Item;
        ItemVariantRec: Record "Item Variant";
        LastLineNo: Integer;
        PackNoInfoListPage: Page "Package No. Information List";
    begin
        SORInspectPkgLine.Reset();
        PackageNoInfor.Reset();
        BinRec.Reset();
        ProdItemTypeRec.Reset();
        ExtCompanySetup.Get();
        PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Location Code"));
        ValidateSORInspectInputs(SORInspectHeadr);
        SortedItemRec.Get(SORInspectHeadr."Sorted Item No.");

        SORInspectPkgLine.SetRange("Document No.", SORInspectHeadr."No.");
        if SORInspectPkgLine.FindLast() then begin
            LastLineNo := SORInspectPkgLine."Line No.";
        end;
        if LastLineNo mod 10000 > 0 then
            LastLineNo += LastLineNo mod 10000
        else
            LastLineNo += 10000;

        PackageNoInfor.SetRange("Item No.", SORInspectHeadr."Sorted Item No.");
        PackageNoInfor.SetFilter("Variant Code", SORInspectHeadr."Sorted Variant Code");
        PackageNoInfor.SetFilter("PMP04 Lot No.", SORInspectHeadr."Lot No.");
        PackageNoInfor.SetRange("PMP15 Able to Sell", true);
        PackageNoInfor.SetFilter("PMP15 SOR Inspection Pckg. No.", '%1', '');
        PackageNoInfor.CalcFields(Inventory);
        PackageNoInfor.SetFilter(Inventory, '> 0');

        OnAfterSORInpctPkgLineSetFiltersofPackageNoInfo(SORInspectHeadr, PackageNoInfor);

        // SORInspectPkgLine.Reset();
        Clear(PackNoInfoListPage);
        PackNoInfoListPage.LookupMode(true);
        PackNoInfoListPage.SetTableView(PackageNoInfor);
        // if Page.RunModal(Page::"Package No. Information List", PackageNoInfor) = Action::LookupOK then begin
        if PackNoInfoListPage.RunModal() = Action::LookupOK then begin
            Clear(PackageNoInfor);
            PackageNoInfor.Reset();
            PackNoInfoListPage.SetSelectionFilter(PackageNoInfor);
            if PackageNoInfor.FindSet() then begin
                repeat
                    PackageNoInfor.CalcFields(Inventory, "PMP04 Bin Code", "PMP04 Lot No.");
                    SORInspectPkgLine.Init();
                    SORInspectPkgLine."Document No." := SORInspectHeadr."No.";
                    SORInspectPkgLine."Line No." := LastLineNo;
                    SORInspectPkgLine.Select := true;
                    // 
                    SORInspectPkgLine."Sorted Item No." := PackageNoInfor."Item No.";
                    SORInspectPkgLine."Sorted Variant Code" := PackageNoInfor."Variant Code";
                    // 
                    SORInspectPkgLine."Sub Merk 1" := PackageNoInfor."PMP04 Sub Merk 1";
                    SORInspectPkgLine."Sub Merk 2" := PackageNoInfor."PMP04 Sub Merk 2";
                    SORInspectPkgLine."Sub Merk 3" := PackageNoInfor."PMP04 Sub Merk 3";
                    SORInspectPkgLine."Sub Merk 4" := PackageNoInfor."PMP04 Sub Merk 4";
                    SORInspectPkgLine."Sub Merk 5" := PackageNoInfor."PMP04 Sub Merk 5";
                    SORInspectPkgLine."L/R" := ConvertLREnumfromCodes(PackageNoInfor."PMP04 L/R");
                    SORInspectPkgLine."Lot No." := PackageNoInfor."PMP04 Lot No.";
                    SORInspectPkgLine."Package No." := PackageNoInfor."Package No.";
                    SORInspectPkgLine."Package Variant Code" := PackageNoInfor."Variant Code";

                    BinContent.Reset();
                    BinContent.SetFilter("Lot No. Filter", SORInspectPkgLine."Lot No.");
                    BinContent.SetFilter("Package No. Filter", SORInspectPkgLine."Package No.");
                    BinContent.SetRange("Item No.", SORInspectPkgLine."Sorted Item No.");
                    BinContent.SetFilter("Variant Code", SORInspectPkgLine."Sorted Variant Code");
                    BinContent.SetRange("Location Code", ExtCompanySetup."PMP15 SOR Location Code");
                    BinContent.SetAutoCalcFields("Quantity (Base)");
                    BinContent.SetFilter("Quantity (Base)", '>0');
                    if BinContent.FindFirst() then begin
                        SORInspectPkgLine.Quantity := BinContent."Quantity (Base)";
                        SORInspectPkgLine."From Bin Code" := BinContent."Bin Code";
                    end;

                    // If Result = Blank/ Accepted/ Item Changes then SOR Step = Inspection | If Result = Rework then SOR Step (Bin Type) = 1 Change to SOR Step/ SOR Bin Type = 3
                    if SORInspectPkgLine.Result in [SORInspectPkgLine.Result::" ", SORInspectPkgLine.Result::Accepted, SORInspectPkgLine.Result::"Item Change"] then begin
                        BinRec.Reset();
                        BinRec.SetRange("PMP15 Bin Type", BinRec."PMP15 Bin Type"::Inspection);
                        if BinRec.FindFirst() then begin
                            SORInspectPkgLine."To Bin Code" := BinRec.Code;
                        end;
                    end else if SORInspectPkgLine.Result in [SORInspectPkgLine.Result::Rework] then begin
                        BinRec.Reset();
                        BinRec.SetRange("PMP15 Bin Type", BinRec."PMP15 Bin Type"::"3");
                        if BinRec.FindFirst() then begin
                            SORInspectPkgLine."To Bin Code" := BinRec.Code;
                        end;
                    end;

                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/16 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                    Item.Reset();
                    ProdItemTypeRec.SetRange("Production Item Type", Enum::"PMP09 Production Item Type"::"Sortation-Inspection");
                    if not ProdItemTypeRec.FindFirst() then
                        CheckProductionItemTypeforSortationInspectionisExist();

                    if ProdItemTypeRec."Item Category Code" <> '' then
                        Item.SetRange("Item Category Code", ProdItemTypeRec."Item Category Code");
                    if ProdItemTypeRec."Item Group" <> '' then
                        Item.SetRange("PMP04 Item Group", ProdItemTypeRec."Item Group");
                    if ProdItemTypeRec."Item Type L1" <> '' then
                        Item.SetRange("PMP04 Item Type L1", ProdItemTypeRec."Item Type L1");
                    if ProdItemTypeRec."Item Type L2" <> '' then
                        Item.SetRange("PMP04 Item Type L2", ProdItemTypeRec."Item Type L2");
                    if ProdItemTypeRec."Item Type L3" <> '' then
                        Item.SetRange("PMP04 Item Type L3", ProdItemTypeRec."Item Type L3");
                    if ProdItemTypeRec."Item Class L1" <> '' then
                        Item.SetRange("PMP04 Item Class L1", ProdItemTypeRec."Item Class L1");
                    if ProdItemTypeRec."Item Class L2" <> '' then
                        Item.SetRange("PMP04 Item Class L2", ProdItemTypeRec."Item Class L2");
                    Item.SetRange("PMP04 Item Owner Internal", ExtCompanySetup."PMP15 SOR Item Owner Internal");

                    if not Item.FindFirst() then begin
                        Item.SetRange("Item Category Code", SortedItemRec."Item Category Code");
                        Item.SetRange("PMP04 Item Type L1", SortedItemRec."PMP04 Item Type L1");
                        if Item.FindFirst() then begin
                            SORInspectPkgLine."New Item Code" := Item."No.";
                        end else
                            Error('The default value for the Production Item Type from Sortation-Inspection could not be found for the Item Category Code and Item Type L1 of the Sorted Item No. %1.', SORInspectHeadr."Sorted Item No.");
                    end else
                        SORInspectPkgLine."New Item Code" := Item."No.";

                    if SORInspectPkgLine."New Item Code" <> '' then begin
                        SORInspectPkgLine."Unit of Measure Code" := Item."Base Unit of Measure";
                    end;
                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/16 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}

                    // Item.Reset();
                    // if Item.Get(PackageNoInfor."Item No.") then begin
                    //     SORInspectPkgLine."Unit of Measure Code" := Item."Base Unit of Measure";
                    //     SORInspectPkgLine."New Item Code" := Item."No.";
                    //     // ItemVariantRec.Reset();
                    //     // ItemVariantRec.SetRange("Item No.", Item."No.");
                    //     // if ItemVariantRec.FindFirst() then
                    //     //     SORInspectPkgLine.Standard := ItemVariantRec.Code;
                    // end else
                    //     Error('The Item is not found for the Package No Information you choose.');

                    SORInspectPkgLine."New Sub Merk 1" := SORInspectPkgLine."Sub Merk 1";
                    SORInspectPkgLine."New Sub Merk 2" := SORInspectPkgLine."Sub Merk 2";
                    SORInspectPkgLine."New Sub Merk 3" := SORInspectPkgLine."Sub Merk 3";
                    SORInspectPkgLine."New Sub Merk 4" := SORInspectPkgLine."Sub Merk 4";
                    SORInspectPkgLine."New Sub Merk 5" := SORInspectPkgLine."Sub Merk 5";
                    SORInspectPkgLine."New L/R" := SORInspectPkgLine."New L/R";
                    SORInspectPkgLine.Validate(Result); // Validate Bin Code
                    SORInspectPkgLine.Insert();
                    LastLineNo += 10000;

                    PackageNoInfor."PMP15 SOR Inspection Pckg. No." := SORInspectHeadr."No.";
                    PackageNoInfor.Modify();
                until PackageNoInfor.Next() = 0;
            end;
        end;
    end;

    /// <summary>Releases the Sortation Inspection Packing List document if it is in Open status.</summary>
    /// <remarks>Validates that at least one line exists before changing the document status to Released.</remarks>
    /// <param name="SORInspectHeadr">Record variable representing the Sortation Inspection Package Header to be released.</param>
    procedure ReleaseSORInspectionPkgDocument(var SORInspectHeadr: Record "PMP15 SOR Inspection Pkg Headr")
    var
        SORInspectPkgLine: Record "PMP15 SOR Inspection Pkg. Line";
    begin
        SORInspectPkgLine.Reset();
        if SORInspectHeadr."Document Status" = SORInspectHeadr."Document Status"::Open then begin
            SORInspectPkgLine.SetRange("Document No.", SORInspectHeadr."No.");
            if SORInspectPkgLine.Count = 0 then begin
                Error('When releasing the document, Sortation Inspection Packing List Line cannot be empty.');
            end;
            SORInspectHeadr."Document Status" := SORInspectHeadr."Document Status"::Released;
            // SORInspectHeadr.Modify();
        end;
    end;

    /// <summary>Reopens a Sortation Inspection Packing List document that is in Released or Partially Processed status.</summary>
    /// <remarks>Changes the document status back to Open if it meets reopening criteria, otherwise throws an error.</remarks>
    /// <param name="SORInspectHeadr">Record variable representing the Sortation Inspection Package Header to be reopened.</param>
    procedure ReopenSORInspectionPkgDocument(var SORInspectHeadr: Record "PMP15 SOR Inspection Pkg Headr")
    var
        SORInspectPkgLineRec: Record "PMP15 SOR Inspection Pkg. Line";
        CanBeOpen: Boolean;
    begin
        Clear(CanBeOpen);
        if SORInspectHeadr."Document Status" in [SORInspectHeadr."Document Status"::Released, SORInspectHeadr."Document Status"::"Partially Processed"] then
            CanBeOpen := true
        else
            Error('The Document is already in "%1" status', SORInspectHeadr."Document Status");

        if CanBeOpen then begin
            SORInspectHeadr."Document Status" := SORInspectHeadr."Document Status"::Open;
            // SORInspectHeadr.Modify();
        end;
    end;

    /// <summary>Validates <b>SOR Inspection Package Lines</b> by enforcing item variant rules and ensuring at least one valid <b>inspection result</b> exists before posting.</summary>
    local procedure ValidateSORInspectPkgLineforItemVariantCheck(SORInspectHeadr: Record "PMP15 SOR Inspection Pkg Headr")
    var
        SORInspectPkgLineRec: Record "PMP15 SOR Inspection Pkg. Line";
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        IsAllResultBlank: Boolean;
    begin
        IsAllResultBlank := true;
        SORInspectPkgLineRec.Reset();
        SORInspectPkgLineRec.SetRange("Document No.", SORInspectHeadr."No.");
        if SORInspectPkgLineRec.FindSet() then
            repeat
                Item.Reset();
                ItemVariant.Reset();

                if (SORInspectPkgLineRec.Result in [SORInspectPkgLineRec.Result::Accepted, SORInspectPkgLineRec.Result::"Item Change", SORInspectPkgLineRec.Result::Rework]) then begin
                    Clear(IsAllResultBlank);
                end;

                if Item.Get(SORInspectPkgLineRec."New Item Code") then begin
                    ItemVariant.SetRange("Item No.", Item."No.");
                    if ItemVariant.Count > 0 then begin
                        if SORInspectPkgLineRec.Standard = '' then begin
                            Error('The "Standard" field must be populated because the new item code %1 has item variants defined.', SORInspectPkgLineRec."New Item Code");
                        end;
                    end;
                end;
            until SORInspectPkgLineRec.Next() = 0;

        if IsAllResultBlank then begin
            Error('The Inspection Line is data invalid. Please make sure to fix the Result status, Standard field, and others before posting.');
        end;
    end;

    /// <summary>Retrieves the related <b>Production Order</b> associated with the specified <b>SOR Inspection Package Header</b> based on SOR completion criteria.</summary>
    local procedure GetProdOrdwithSORInspectPkgListNo(SORInspectHeadr: Record "PMP15 SOR Inspection Pkg Headr"; var ProdOrder: Record "Production Order")
    var
        recProductionOrder: Record "Production Order";
    begin
        recProductionOrder.Reset();
        recProductionOrder.SetRange("PMP15 SOR Completed");
    end;

    /// <summary> <b>Simulates</b> the creation of a <b>Sortation Production Order</b> in a temporary record based on the provided <b>SOR Inspection Package Header</b>. </summary>
    /// <remarks> This procedure checks whether at least one SOR Inspection Package Line contains a valid <b>Lot No.</b>. When found, it initializes and prepares a temporary Production Order using the configured <b>Sort-Prod. Order No. Series</b>, assigns core dates, location, item, variant, and SOR-related fields, and links it to the originating <b>SOR Inspection Package</b>. No actual database posting occurs; the operation is intended to <b>validate feasibility</b> and preview whether an insert would succeed before performing the real transaction. </remarks>
    /// <param name="tempProdOrderRec">Temporary Production Order record used to simulate the insert.</param>
    /// <param name="SORInspectHeader">SOR Inspection Package Header that provides source item, variant, lot, and linkage context.</param>
    /// <returns> Returns <b>true</b> if the temporary Production Order is successfully inserted; otherwise, returns <b>false</b>. </returns>
    procedure SimulateInsertSuccess(var tempProdOrderRec: Record "Production Order" temporary; var SORInspectHeader: Record "PMP15 SOR Inspection Pkg Headr") IsInsertSuccess: Boolean
    var
        SORInspectPkgLine: Record "PMP15 SOR Inspection Pkg. Line";
    begin
        ExtCompanySetup.Get();
        SORInspectPkgLine.Reset();
        tempProdOrderRec.DeleteAll();
        tempProdOrderRec.Reset();

        SORInspectPkgLine.SetRange("Document No.", SORInspectHeader."No.");
        SORInspectPkgLine.SetFilter("Lot No.", '<> %1', '');
        if SORInspectPkgLine.FindFirst() then begin
            tempProdOrderRec.Init();
            tempProdOrderRec.InitRecord();
            tempProdOrderRec."No. Series" := ExtCompanySetup."PMP15 Sort-Prod. Order Nos.";
            tempProdOrderRec."No." := NoSeriesMgmt.PeekNextNo(ExtCompanySetup."PMP15 Sort-Prod. Order Nos.", WorkDate());
            tempProdOrderRec.Status := tempProdOrderRec.Status::"Firm Planned";
            tempProdOrderRec.Validate("Due Date", WorkDate());
            tempProdOrderRec."Creation Date" := WorkDate();
            tempProdOrderRec."Starting Date" := WorkDate();
            tempProdOrderRec."Last Date Modified" := WorkDate();
            tempProdOrderRec.Validate("Source Type", tempProdOrderRec."Source Type"::Item);
            tempProdOrderRec.Validate("Source No.", SORInspectHeader."Sorted Item No.");
            tempProdOrderRec.Validate("Variant Code", SORInspectHeader."Sorted Variant Code");
            tempProdOrderRec.Validate("Location Code", ExtCompanySetup."PMP15 SOR Location Code");
            tempProdOrderRec.Validate("PMP15 Lot No.", SORInspectPkgLine."Lot No.");
            // tempProdOrderRec.Validate(Quantity, SortProdOrdCreation.Quantity);
            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/05 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
            // tempProdOrderRec."PMP15 Crop" := Date2DMY(WorkDate(), 3);
            tempProdOrderRec."PMP15 Crop" := Format(Date2DMY(WorkDate(), 3));
            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/05 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
            tempProdOrderRec."PMP15 SOR Inspection Pkg. No." := SORInspectHeader."No.";
            tempProdOrderRec."PMP04 Item Owner Internal" := ExtCompanySetup."PMP15 SOR Item Owner Internal";
            exit(tempProdOrderRec.Insert());
        end;
    end;

    /// <summary>Inserts a new <b>Production Order</b> from a temporary record by assigning the next <b>Sort-Prod. Order No.</b> and linking it to the related <b>SOR Inspection Package</b>.</summary>
    local procedure InsertProdOrderfromTemp(tempProdOrderRec: Record "Production Order" temporary; var ProdOrderRec: Record "Production Order")
    var
    begin
        ProdOrderRec.Init();
        ProdOrderRec.Copy(tempProdOrderRec);
        ProdOrderRec."No." := NoSeriesMgmt.GetNextNo(ExtCompanySetup."PMP15 Sort-Prod. Order Nos.", WorkDate());
        ProdOrderRec."PMP15 SOR Inspection Pkg. No." := tempProdOrderRec."PMP15 SOR Inspection Pkg. No.";
        // ProdOrderRec.Validate("Starting Date", WorkDate());
        // ProdOrderRec.Validate("Starting Date-Time", CurrentDateTime);
        // ProdOrderRec.Validate("Ending Date-Time", CurrentDateTime);
        // ProdOrderRec.Validate("Due Date", CalcDate('<+2D>', WorkDate()));
        ProdOrderRec.Insert(true);
        ProdOrderRec.Mark(true);
    end;

    /// <summary> Returns the <b>next available Line No.</b> for a given <b>Production Order</b> by evaluating the last existing Production Order Line. </summary>
    /// <param name="Status">Specifies the <b>Production Order Status</b> used to identify the correct document context.</param>
    /// <param name="ProdOrderNo">Specifies the <b>Production Order No.</b> from which the last line is evaluated.</param>
    /// <returns>An <b>Integer</b> representing the next Line No.; returns <b>10000</b> when no existing lines are found.</returns>
    /// <remarks> This procedure retrieves the Production Order header to ensure validity, then locates the last related Production Order Line and increments its Line No. by <b>10000</b> to maintain standard line spacing. </remarks>
    procedure GetLastProdOrdLinefromProdOrdHeader(Status: Enum "Production Order Status"; ProdOrderNo: Code[20]): Integer
    var
        ProdOrderRec: Record "Production Order";
        ProdOrdLineRec: Record "Prod. Order Line";
    begin
        ProdOrderRec.Get(Status, ProdOrderNo);
        ProdOrdLineRec.SetRange(Status, Status);
        ProdOrdLineRec.SetRange("Prod. Order No.", ProdOrderNo);
        if ProdOrdLineRec.Find('+') then
            exit(ProdOrdLineRec."Line No." + 10000)
        else
            exit(10000);
    end;

    /// <summary> Creates and prepares a <b>temporary Item Journal Line</b> for <b>SOR Inspection</b> processing, supporting both <b>Output</b> and <b>Consumption</b> entry types. </summary>
    /// <remarks> This procedure dynamically determines the <b>next Line No.</b>, assigns the correct <b>Journal Template</b> OR <b>Batch</b> from Extended Company Setup, and populates all mandatory fields based on the entry type. For <b>Output</b>, it validates bin availability, ensures <b>Lot No. Information</b> exists (or creates it from an existing lot), and transfers inspection-derived attributes such as <b>Sub Merk</b>, <b>L/R</b>, crop, cycle, and delivery details. For <b>Consumption</b>, it consumes the inspected item using the source lot, package, and bin while preserving the same traceability attributes. The created line is marked as <b>PMP15 Marked</b>, linked to the <b>Production Order</b>, and tagged with the <b>SOR-Inspection</b> production type to ensure correct downstream posting behavior. </remarks>
    /// <param name="ItemJnlLine">Base Item Journal Line used as a reference for template and batch context.</param>
    /// <param name="tempItemJnlLine">Temporary Item Journal Line that will be fully populated and inserted.</param>
    /// <param name="SORInspectHeadr">SOR Inspection Package Header providing posting date and inspection context.</param>
    /// <param name="SORInspectPkgLineRec">SOR Inspection Package Line supplying item, lot, bin, and inspection result details.</param>
    /// <param name="ProdOrderRec">Related <b>Production Order</b> used to derive routing and operational context.</param>
    /// <param name="ProdOrdLineRec">Production Order Line supplying output item, quantity, and location data.</param>
    /// <param name="IJLEntryType">Specifies whether the journal line is created as <b>Output</b> or <b>Consumption</b>.</param>
    /// <returns><b>True</b> if the temporary Item Journal Line is successfully created and inserted; otherwise, <b>false</b>.</returns>
    local procedure Test_InsertItemJnlLineInspect(var ItemJnlLine: Record "Item Journal Line"; var tempItemJnlLine: Record "Item Journal Line" temporary; var SORInspectHeadr: Record "PMP15 SOR Inspection Pkg Headr"; SORInspectPkgLineRec: Record "PMP15 SOR Inspection Pkg. Line"; ProdOrderRec: Record "Production Order"; ProdOrdLineRec: Record "Prod. Order Line"; IJLEntryType: Enum "Item Ledger Entry Type"): Boolean
    var
        IJL: Record "Item Journal Line";
        Item: Record Item;
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ProdOrdRoutingLine: Record "Prod. Order Routing Line";
        OldLotNoInfoRec: Record "Lot No. Information";
        LotNoInfoRec: Record "Lot No. Information";
        BinContent: Record "Bin Content";
        LastLineNo: Integer;
    begin
        ExtCompanySetup.Get();
        IJL.Reset();
        ItemJnlTemplate.Reset();
        ItemJnlBatch.Reset();
        Item.Reset();
        ProdOrdRoutingLine.Reset();
        LotNoInfoRec.Reset();
        OldLotNoInfoRec.Reset();
        BinContent.Reset();
        Clear(LastLineNo);

        IJL.SetRange("Journal Template Name", ItemJnlLine."Journal Template Name");
        IJL.SetRange("Journal Batch Name", ItemJnlLine."Journal Batch Name");
        if IJL.FindLast() then
            LastLineNo := IJL."Line No.";

        if LastLineNo mod 10000 > 0 then
            LastLineNo += LastLineNo mod 10000
        else
            LastLineNo += 10000;


        tempItemJnlLine.Init();
        if IJLEntryType = IJLEntryType::Output then begin
            #region OUTPUT JOURNAL INSPECTION
            if Item.Get(ProdOrdLineRec."Item No.") then begin
                tempItemJnlLine."Journal Template Name" := ExtCompanySetup."PMP15 SOR Output Jnl. Template";
                tempItemJnlLine."Journal Batch Name" := ExtCompanySetup."PMP15 SOR Output Jnl. Batch";
                tempItemJnlLine."Line No." := LastLineNo;
                if ItemJnlTemplate.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template") then begin
                    tempItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
                end;
                // tempItemJnlLine."Source Code" := 'POINOUTJNL';
                if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template", ExtCompanySetup."PMP15 SOR Output Jnl. Batch") then begin
                    if ItemJnlBatch."No. Series" <> '' then begin
                        tempItemJnlLine."Document No." := NoSeriesBatchMgmt.PeekNextNo(ItemJnlBatch."No. Series", SORInspectHeadr."Posting Date");
                    end;
                end;
                tempItemJnlLine.Validate("Posting Date", SORInspectHeadr."Posting Date");
                tempItemJnlLine.Validate("Entry Type", tempItemJnlLine."Entry Type"::Output);
                tempItemJnlLine.Validate("Order No.", SORInspectPkgLineRec."Prod. Order No.");
                tempItemJnlLine.Validate("Order Type", tempItemJnlLine."Order Type"::Production);
                tempItemJnlLine.Validate("Item No.", Item."No.");
                tempItemJnlLine.Description := Item.Description;
                tempItemJnlLine.Validate("Variant Code", ProdOrdLineRec."Variant Code");
                tempItemJnlLine.Validate("Output Quantity", ProdOrdLineRec.Quantity);
                tempItemJnlLine.Validate("Unit of Measure Code", ProdOrdLineRec."Unit of Measure Code");
                tempItemJnlLine.Validate("Location Code", ProdOrdLineRec."Location Code");
                tempItemJnlLine.Validate("Order Line No.", ProdOrdLineRec."Line No.");

                ProdOrdRoutingLine.SetRange("Prod. Order No.", ProdOrderRec."No.");
                ProdOrdRoutingLine.SetRange("Routing Reference No.", tempItemJnlLine."Order Line No.");
                if ProdOrdRoutingLine.FindLast() then begin
                    tempItemJnlLine.Validate("Operation No.", ProdOrdRoutingLine."Operation No.");
                end;

                // VALIDATE BEFORE SETTING BIN CODE
                ValidateBinContentIsExistforItemJnlLine(BinContent, tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", tempItemJnlLine."Location Code");
                BinContent.SetRange("Bin Code", SORInspectPkgLineRec."To Bin Code");
                if BinContent.FindFirst() then
                    tempItemJnlLine.Validate("Bin Code", SORInspectPkgLineRec."To Bin Code")
                else
                    Error('The Bin Code %1 is not available in the Bin Content with the Item of %2 %3, on %4 Location. Please make sure the related To Bin Code is available in the Bin Content.', SORInspectPkgLineRec."To Bin Code", tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", tempItemJnlLine."Location Code");
                // tempItemJnlLine.Validate("Bin Code", ProdOrdLineRec."Bin Code");

                // SETTING LOT NO INFORMATION
                if not LotNoInformationIsExist(LotNoInfoRec, tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SORInspectPkgLineRec."Lot No.") then begin
                    OldLotNoInfoRec.SetRange("Item No.", SORInspectPkgLineRec."Sorted Item No.");
                    OldLotNoInfoRec.SetRange("Variant Code", SORInspectPkgLineRec."Sorted Variant Code");
                    OldLotNoInfoRec.SetRange("Lot No.", SORInspectPkgLineRec."Lot No.");
                    if OldLotNoInfoRec.FindFirst() then begin
                        LotNoInfoRec := CreateNewLotNoInformationfromOldLotNoInfo(OldLotNoInfoRec, tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SORInspectPkgLineRec."Lot No.");
                    end else begin
                        Error('No Lot No. Information available for the Output Journal for the Sorted Item %1 - %2 during the creation of a new Lot No %3. Information record. Please review the current lot availability for the specified sorted item.', SORInspectPkgLineRec."Sorted Item No.", SORInspectPkgLineRec."Sorted Variant Code", SORInspectPkgLineRec."Lot No.");
                    end;
                end;
                tempItemJnlLine."Lot No." := LotNoInfoRec."Lot No.";
                tempItemJnlLine."PMP15 Crop" := LotNoInfoRec."PMP14 Crop";
                tempItemJnlLine."PMP15 Cycle (Separately)" := LotNoInfoRec."PMP14 Cycle (Separately)";
                tempItemJnlLine."Invoice No." := LotNoInfoRec."PMP14 Invoice No.";
                tempItemJnlLine."PMP15 Delivery" := LotNoInfoRec."PMP14 Delivery";
                tempItemJnlLine."PMP15 Cycle Code" := LotNoInfoRec."PMP14 Cycle Code";
                tempItemJnlLine."PMP15 Output Item No." := tempItemJnlLine."Item No.";
                tempItemJnlLine."PMP15 Output Variant Code" := tempItemJnlLine
                ."Variant Code";

                tempItemJnlLine."PMP15 Sub Merk 1" := SORInspectPkgLineRec."New Sub Merk 1";
                tempItemJnlLine."PMP15 Sub Merk 2" := SORInspectPkgLineRec."New Sub Merk 2";
                tempItemJnlLine."PMP15 Sub Merk 3" := SORInspectPkgLineRec."New Sub Merk 3";
                tempItemJnlLine."PMP15 Sub Merk 4" := SORInspectPkgLineRec."New Sub Merk 4";
                tempItemJnlLine."PMP15 Sub Merk 5" := SORInspectPkgLineRec."New Sub Merk 5";
                tempItemJnlLine."PMP15 L/R" := SORInspectPkgLineRec."New L/R";
            end;
            #endregion OUTPUT JOURNAL INSPECTION
        end else if IJLEntryType = IJLEntryType::Consumption then begin
            #region CONSUMPTION JOURNAL INSPECTION
            if Item.Get(SORInspectPkgLineRec."Sorted Item No.") then begin
                tempItemJnlLine."Journal Template Name" := ExtCompanySetup."PMP15 SOR Consum.Jnl. Template";
                tempItemJnlLine."Journal Batch Name" := ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch";
                tempItemJnlLine."Line No." := LastLineNo;
                if ItemJnlTemplate.Get(tempItemJnlLine."Journal Template Name") then begin
                    tempItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
                end;
                tempItemJnlLine."Source Type" := tempItemJnlLine."Source Type"::Item;
                tempItemJnlLine."Source No." := Item."No.";
                if ItemJnlBatch.Get(tempItemJnlLine."Journal Template Name", tempItemJnlLine."Journal Batch Name") then begin
                    if ItemJnlBatch."No. Series" <> '' then begin
                        tempItemJnlLine."Document No." := NoSeriesBatchMgmt.PeekNextNo(ItemJnlBatch."No. Series", SORInspectHeadr."Posting Date");
                    end;
                end;
                tempItemJnlLine.Validate("Posting Date", WorkDate());
                tempItemJnlLine.Validate("Entry Type", tempItemJnlLine."Entry Type"::Consumption);
                tempItemJnlLine.Validate("Order No.", SORInspectPkgLineRec."Prod. Order No.");
                tempItemJnlLine.Validate("Order Type", tempItemJnlLine."Order Type"::Production);
                tempItemJnlLine.Validate("Item No.", Item."No.");
                tempItemJnlLine.Validate("Source No.", Item."No.");
                tempItemJnlLine.Description := Item.Description;
                tempItemJnlLine.Validate("Variant Code", SORInspectPkgLineRec."Sorted Variant Code");
                tempItemJnlLine.Validate(Quantity, SORInspectPkgLineRec.Quantity);
                tempItemJnlLine.Validate("Unit of Measure Code", SORInspectPkgLineRec."Unit of Measure Code");
                tempItemJnlLine.Validate("Location Code", ExtCompanySetup."PMP15 SOR Location Code");
                tempItemJnlLine."Order Line No." := SORInspectPkgLineRec."Line No.";
                ProdOrdRoutingLine.SetRange("Prod. Order No.", ProdOrderRec."No.");
                ProdOrdRoutingLine.SetRange("Routing Reference No.", tempItemJnlLine."Order Line No.");
                tempItemJnlLine."Lot No." := SORInspectPkgLineRec."Lot No.";
                tempItemJnlLine."Package No." := SORInspectPkgLineRec."Package No.";
                tempItemJnlLine."Bin Code" := SORInspectPkgLineRec."From Bin Code";

                //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                LotNoInfoRec.Get(tempItemJnlLine."Item No.", tempItemJnlLine."Variant Code", SORInspectPkgLineRec."Lot No.");

                tempItemJnlLine."PMP15 Crop" := LotNoInfoRec."PMP14 Crop";
                tempItemJnlLine."PMP15 Cycle (Separately)" := LotNoInfoRec."PMP14 Cycle (Separately)";
                tempItemJnlLine."Invoice No." := LotNoInfoRec."PMP14 Invoice No.";
                tempItemJnlLine."PMP15 Delivery" := LotNoInfoRec."PMP14 Delivery";
                tempItemJnlLine."PMP15 Cycle Code" := LotNoInfoRec."PMP14 Cycle Code";
                tempItemJnlLine."PMP15 Output Item No." := SORInspectPkgLineRec."Sorted Item No.";
                tempItemJnlLine."PMP15 Output Variant Code" := SORInspectPkgLineRec."Sorted Variant Code";

                tempItemJnlLine."PMP15 Sub Merk 1" := SORInspectPkgLineRec."Sub Merk 1";
                tempItemJnlLine."PMP15 Sub Merk 2" := SORInspectPkgLineRec."Sub Merk 2";
                tempItemJnlLine."PMP15 Sub Merk 3" := SORInspectPkgLineRec."Sub Merk 3";
                tempItemJnlLine."PMP15 Sub Merk 4" := SORInspectPkgLineRec."Sub Merk 4";
                tempItemJnlLine."PMP15 Sub Merk 5" := SORInspectPkgLineRec."Sub Merk 5";
                tempItemJnlLine."PMP15 L/R" := SORInspectPkgLineRec."L/R";
                //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
            end;
            #endregion CONSUMPTION JOURNAL INSPECTION
        end;
        tempItemJnlLine."PMP15 Marked" := true;
        tempItemJnlLine."PMP15 Prod. Order No." := SORInspectPkgLineRec."Prod. Order No.";
        tempItemJnlLine."PMP15 Production Type" := tempItemJnlLine."PMP15 Production Type"::"SOR-Inspection";

        if tempItemJnlLine.Insert() then
            exit(true)
        else
            exit(false);
    end;

    /// <summary> Inserts an Item Journal Line from a temporary inspection journal line into the actual Item Journal, assigning the correct document number based on the entry type and ensuring no duplicate line exists. </summary>
    /// <remarks> This procedure:Copies data from a temporary inspection journal line into a live Item Journal Line.Assigns a new document number based on the configured journal batch No. Series.Removes any existing Item Journal Line with the same template, batch, and line number to prevent duplication.Inserts and marks the new Item Journal Line for further processing. </remarks>
    /// <param name="ItemJnlLine">The target Item Journal Line record that will be initialized and populated from the temporary record.</param>
    /// <param name="tempItemJnlLine"> A temporary Item Journal Line containing pre-validated inspection data to be transferred. </param> 
    /// <param name="SORInspectHeadr"> The SOR Inspection Package Header used to determine posting context such as posting date. </param> 
    /// <param name="IJLEntryType"> Specifies whether the journal line is created as a Consumption or Output entry, determining the journal template, batch, and document number series used. </param>
    local procedure InsertItemJnlLinefromTempInspect(var ItemJnlLine: Record "Item Journal Line"; var tempItemJnlLine: Record "Item Journal Line" temporary; var SORInspectHeadr: Record "PMP15 SOR Inspection Pkg Headr"; IJLEntryType: Enum "Item Ledger Entry Type")
    var
        ItemJnlBatch: Record "Item Journal Batch";
        IJL: Record "Item Journal Line";
    begin
        ItemJnlBatch.Reset();
        IJL.Reset();
        ExtCompanySetup.Get();

        if IJLEntryType = IJLEntryType::Consumption then begin
            ItemJnlLine.Init();
            ItemJnlLine := tempItemJnlLine;
            if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Consum.Jnl. Template", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch") then begin
                if ItemJnlBatch."No. Series" <> '' then begin
                    ItemJnlLine."Document No." := NoSeriesBatchMgmt.GetNextNo(ItemJnlBatch."No. Series", SORInspectHeadr."Posting Date");
                end;
            end;
        end else if IJLEntryType = IJLEntryType::Output then begin
            ItemJnlLine.Init();
            ItemJnlLine := tempItemJnlLine;
            if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template", ExtCompanySetup."PMP15 SOR Output Jnl. Batch") then begin
                if ItemJnlBatch."No. Series" <> '' then begin
                    ItemJnlLine."Document No." := NoSeriesBatchMgmt.GetNextNo(ItemJnlBatch."No. Series", SORInspectHeadr."Posting Date");
                end;
            end;
        end;

        IJL.SetRange("Journal Template Name", ItemJnlLine."Journal Template Name");
        IJL.SetRange("Journal Batch Name", ItemJnlLine."Journal Batch Name");
        IJL.SetRange("Line No.", ItemJnlLine."Line No.");
        if IJL.FindFirst() then begin
            IJL.Delete(true);
        end;

        ItemJnlLine.Insert();
        ItemJnlLine.Mark(true);
    end;

    /// <summary>Creates and inserts production order lines from selected SOR inspection packing lines based on inspection results, and links them back to the originating inspection records.</summary>
    local procedure CreateNewProdOrderSortationInspectionPackingLine(var SORInspectHeadr: Record "PMP15 SOR Inspection Pkg Headr"; var ProdOrderRec: Record "Production Order"; intLastLineNo: Integer)
    var
        SORInspectPkgLineRec: Record "PMP15 SOR Inspection Pkg. Line";
        PackageNoInfor: Record "Package No. Information";
        ProdOrdLineRec: Record "Prod. Order Line";
        ItemRec: Record Item;
    begin
        SORInspectPkgLineRec.SetFilter("Prod. Order No.", '%1', '');
        SORInspectPkgLineRec.SetRange("Document No.", SORInspectHeadr."No.");
        SORInspectPkgLineRec.SetRange(Select, true);
        SORInspectPkgLineRec.SetRange(Process, false);
        if SORInspectPkgLineRec.FindSet() then
            repeat
                PackageNoInfor.Reset();
                // ItemVariantRec.Reset();
                if SORInspectPkgLineRec.Result in [SORInspectPkgLineRec.Result::Accepted, SORInspectPkgLineRec.Result::"Item Change", SORInspectPkgLineRec.Result::Rework] then begin
                    ProdOrdLineRec.Init();
                    ItemRec.Get(SORInspectPkgLineRec."New Item Code");
                    ProdOrdLineRec.Status := ProdOrderRec.Status;
                    ProdOrdLineRec."Prod. Order No." := ProdOrderRec."No.";
                    ProdOrdLineRec."Line No." := intLastLineNo;
                    // ProdOrdLineRec."Routing Reference No." := ProdOrdLineRec."Line No.";
                    if SORInspectPkgLineRec.Result in [SORInspectPkgLineRec.Result::Accepted, SORInspectPkgLineRec.Result::"Item Change"] then begin
                        ProdOrdLineRec.Validate("Item No.", SORInspectPkgLineRec."New Item Code");
                        ProdOrdLineRec."Location Code" := ExtCompanySetup."PMP15 SOR Location Code";
                        ProdOrdLineRec.Validate("Variant Code", SORInspectPkgLineRec.Standard);
                        // ProdOrdLineRec.Validate("Bin Code", SORInspectPkgLineRec."To Bin Code");
                        ProdOrdLineRec."Bin Code" := SORInspectPkgLineRec."To Bin Code";
                        ProdOrdLineRec.Validate(Quantity, SORInspectPkgLineRec.Quantity);
                        ProdOrdLineRec.Validate("Unit of Measure Code", SORInspectPkgLineRec."Unit of Measure Code");
                    end else if SORInspectPkgLineRec.Result = SORInspectPkgLineRec.Result::Rework then begin
                        // reference GetPackagetoInspect
                        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                        ProdOrdLineRec.Validate("Item No.", SORInspectPkgLineRec."New Item Code");
                        ProdOrdLineRec."Location Code" := ExtCompanySetup."PMP15 SOR Location Code";
                        ProdOrdLineRec.Validate("Variant Code", SORInspectPkgLineRec.Standard);
                        ProdOrdLineRec.Validate("Bin Code", SORInspectPkgLineRec."To Bin Code");
                        ProdOrdLineRec.Validate(Quantity, SORInspectPkgLineRec.Quantity);
                        ProdOrdLineRec.Validate("Unit of Measure Code", SORInspectPkgLineRec."Unit of Measure Code");

                        // PackageNoInfor.SetRange("Item No.", SORInspectPkgLineRec."Sorted Item No.");
                        // PackageNoInfor.SetRange("Variant Code", SORInspectHeadr."Sorted Variant Code");
                        // PackageNoInfor.SetRange("Package No.", SORInspectPkgLineRec."Package No.");
                        // PackageNoInfor.SetFilter("PMP04 Lot No.", SORInspectPkgLineRec."Lot No.");
                        // PackageNoInfor.SetRange("PMP15 Able to Sell", true);
                        // PackageNoInfor.SetRange("PMP15 SOR Inspection Pckg. No.", SORInspectHeadr."No.");
                        // if PackageNoInfor.FindFirst() then begin
                        //     // ProdOrdLineRec.Validate("Item No.", PackageNoInfor."PMP15 Unsorted Item No."); // Before
                        //     // ProdOrdLineRec.Validate("Variant Code", PackageNoInfor."PMP15 Unsorted Variant Code"); // Before
                        // end;
                        //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/17 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
                    end;
                    ProdOrdLineRec."Scrap %" := ItemRec."Scrap %";
                    ProdOrdLineRec."Due Date" := ProdOrderRec."Due Date";
                    ProdOrdLineRec."Starting Date" := ProdOrderRec."Starting Date";
                    ProdOrdLineRec."Starting Time" := ProdOrderRec."Starting Time";
                    ProdOrdLineRec."Ending Date" := ProdOrderRec."Ending Date";
                    ProdOrdLineRec."Ending Time" := ProdOrderRec."Ending Time";
                    ProdOrdLineRec."Planning Level Code" := 0;
                    ProdOrdLineRec."Inventory Posting Group" := ItemRec."Inventory Posting Group";
                    ProdOrdLineRec.UpdateDatetime();
                    ProdOrdLineRec.Validate("Unit Cost");
                    ProdOrdLineRec.Insert();
                    intLastLineNo += 10000;

                    SORInspectPkgLineRec."Prod. Order No." := ProdOrderRec."No.";
                    SORInspectPkgLineRec."Prod. Order Line No." := ProdOrdLineRec."Line No.";
                    SORInspectPkgLineRec.Modify();
                end;
            until SORInspectPkgLineRec.Next() = 0;
    end;

    // ONE OF THE MOST IMPORTANT FUNCTION IN THIS CODEUNIT
    /// <summary> Processes a list of items from a Sortation (SOR) Inspection Package. This critical procedure manages the workflow from inspection to <b>inventory posting</b>, including <b>production order creation</b>, <b>journal posting</b>, and handling of rework/rejected items. </summary>
    /// <remarks> Orchestrates multiple complex operations:
    /// 1. Validates inspection package lines for item variant consistency
    /// 2. Creates/retrieves production orders for inspection process
    /// 3. Generates production order lines for selected inspection items
    /// 4. Posts output/consumption journals based on inspection results (Accepted/Item Change/Rework)
    /// 5. Manages rework by creating new sortation production orders
    /// 6. Updates inspection package status upon completion
    /// Handles different inspection results:
    /// - Accepted/Item Change/Rework: Posts output and consumption journals
    /// - Rework: Additionally creates new production orders for re-processing
    /// - Rejected: Marks items as processed without journal posting
    ///  Requires proper setup of SOR journal templates/batches in extension company setup. </remarks>
    /// <param name="SORInspectHeadr">The header record of the SOR Inspection Package to be processed. Passed by reference and updated with final document status upon completion.</param>
    /// <param name="IsSuppressCommit">Controls commit behavior during journal posting. TRUE: Suppresses commits for manual journal review before posting FALSE: Proceeds with normal commit flow after journal creation</param>
    procedure ProcessSORInpectPkgList(var SORInspectHeadr: Record "PMP15 SOR Inspection Pkg Headr"; IsSuppressCommit: Boolean)
    var
        ProdOrderStatusMgmt: Codeunit "Prod. Order Status Management";
        SORInspectPkgLineRec: Record "PMP15 SOR Inspection Pkg. Line";
        // ItemRec: Record Item;
        // ItemVariantRec: Record "Item Variant";
        // PackageNoInfor: Record "Package No. Information";
        ProdOrderRec2: Record "Production Order";
        ProdOrderRec: Record "Production Order";                // PRODUCTION ORDER (HEADER)
        tempProdOrderRec: Record "Production Order" temporary;  // PRODUCTION ORDER (HEADER) TEMP
        ProdOrdLineRec: Record "Prod. Order Line";              // PRODUCTION ORDER (LINE)
        tempItemJnlLine: Record "Item Journal Line" temporary;  // ITEM JOURNAL LINE
        ItemJnlLine: Record "Item Journal Line";                // ITEM JOURNAL LINE
        ItemJnlLine2: Record "Item Journal Line";               // ------ IDEN ------
        SORProdOrdCreationRec: Record "PMP15 Sortation PO Creation" temporary;
        NewStatus: Enum "Production Order Status";
        intLastLineNo: Integer;
        IsSuccessInsertItemJnlLine, IsExistingProdOrderNoFound : Boolean;
    begin
        Clear(intLastLineNo);
        Clear(IsSuccessInsertItemJnlLine);
        Clear(IsExistingProdOrderNoFound);
        SORInspectPkgLineRec.Reset();
        ProdOrderRec.Reset();
        ProdOrderRec2.Reset();
        ProdOrdLineRec.Reset();
        tempItemJnlLine.Reset();
        ItemJnlLine.Reset();
        ItemJnlLine2.Reset();
        tempProdOrderRec.DeleteAll();
        tempItemJnlLine.DeleteAll();
        SORProdOrdCreationRec.DeleteAll();
        ValidateSORInspectPkgLineforItemVariantCheck(SORInspectHeadr);

        #region GET PRODUCTION ORDER
        // ProdOrderRec.SetRange("PMP15 SOR Inspection Pkg. No.", SORInspectHeadr."No.");
        // ProdOrderRec.SetRange(Status, ProdOrderRec.Status::Released);
        // if not ProdOrderRec.FindFirst() then
        //     if SimulateInsertSuccess(tempProdOrderRec, SORInspectHeadr) then
        //         InsertProdOrderfromTemp(tempProdOrderRec, ProdOrderRec); // C.1.1

        IsExistingProdOrderNoFound := IsInspectionProductionOrderisExist(SORInspectHeadr, ProdOrderRec); // if found, marked
        if not IsExistingProdOrderNoFound then begin
            if SimulateInsertSuccess(tempProdOrderRec, SORInspectHeadr) then // marked
                InsertProdOrderfromTemp(tempProdOrderRec, ProdOrderRec); // C.1.1

            intLastLineNo := GetLastProdOrdLinefromProdOrdHeader(ProdOrderRec.Status, ProdOrderRec."No.");

        end;
        #endregion GET PRODUCTION ORDER

        #region CREATE PRODUCTION ORDER LINE
        CreateNewProdOrderSortationInspectionPackingLine(SORInspectHeadr, ProdOrderRec, intLastLineNo);
        #endregion CREATE PRODUCTION ORDER LINE

        Commit();
        // c.1.5  Run Refresh Production Order Function for the Released Prod. Order
        if RunRefreshProdOrder(ProdOrderRec, 1, false, true, false, false) then begin
            // 
        end else if (ProdOrderRec.Status in [ProdOrderRec.Status::Planned, ProdOrderRec.Status::"Firm Planned", ProdOrderRec.Status::Simulated]) then begin
            ProdOrderRec.MarkedOnly(true);
            ProdOrderRec.DeleteAll();
        end;

        // Change the status of the related production order to released. Sinc
        if ProdOrderRec.Status <> ProdOrderRec.Status::Released then begin
            ProdOrderStatusMgmt.ChangeProdOrderStatus(ProdOrderRec, NewStatus::Released, WorkDate(), true);
            Commit();
            ProdOrderRec.Mark(true);
        end;

        ProdOrdLineRec.Reset();
        SORInspectPkgLineRec.Reset();
        SORInspectPkgLineRec.SetRange("Document No.", SORInspectHeadr."No.");
        SORInspectPkgLineRec.SetRange(Select, true);
        SORInspectPkgLineRec.SetRange(Process, false);
        if SORInspectPkgLineRec.FindSet() then
            repeat
                ProdOrderRec.SetRange(Status, ProdOrderRec.Status::Released);
                ProdOrderRec.SetRange("No.", SORInspectPkgLineRec."Prod. Order No.");
                if ProdOrderRec.FindFirst() then begin end;
                if SORInspectPkgLineRec.Result in [SORInspectPkgLineRec.Result::Accepted, SORInspectPkgLineRec.Result::"Item Change", SORInspectPkgLineRec.Result::Rework] then begin
                    if ProdOrdLineRec.Get(ProdOrderRec.Status, SORInspectPkgLineRec."Prod. Order No.", SORInspectPkgLineRec."Prod. Order Line No.") then begin
                        // OUTPUT JOURNAL
                        ItemJnlLine.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Output Jnl. Template");
                        ItemJnlLine.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Output Jnl. Batch");
                        ItemJnlLine.SetRange("PMP15 Marked", true);
                        if ItemJnlLine.FindLast() OR (ItemJnlLine.Count = 0) then begin // As Validation before insertion
                            IsSuccessInsertItemJnlLine := Test_InsertItemJnlLineInspect(ItemJnlLine, tempItemJnlLine, SORInspectHeadr, SORInspectPkgLineRec, ProdOrderRec, ProdOrdLineRec, ItemJnlLine."Entry Type"::Output);
                        end;
                        if IsSuccessInsertItemJnlLine then begin
                            ItemJnlLine.Reset();
                            InsertItemJnlLinefromTempInspect(ItemJnlLine, tempItemJnlLine, SORInspectHeadr, ItemJnlLine."Entry Type"::Output);
                            GenerateRecReserveEntryItemJnlLineInspect(ItemJnlLine, SORInspectHeadr, SORInspectPkgLineRec);
                            // ItemJnlLine2 := ItemJnlLine;
                            // ItemJnlLine.PostingItemJnlFromProduction(false);
                            // Commit();

                            Clear(IsSuccessInsertItemJnlLine);
                            // ItemJnlLine2.Reset();
                            tempItemJnlLine.DeleteAll();
                        end else
                            Error('Failed to creating the Output Journal before posting.');

                        // CONSUMPTION JOURNAL
                        ItemJnlLine2.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Template");
                        ItemJnlLine2.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch");
                        ItemJnlLine2.SetRange("PMP15 Marked", true);
                        if ItemJnlLine2.FindLast() OR (ItemJnlLine2.Count = 0) then begin // As Validation before insertion
                            IsSuccessInsertItemJnlLine := Test_InsertItemJnlLineInspect(ItemJnlLine2, tempItemJnlLine, SORInspectHeadr, SORInspectPkgLineRec, ProdOrderRec, ProdOrdLineRec, ItemJnlLine."Entry Type"::Consumption);
                        end;
                        if IsSuccessInsertItemJnlLine then begin
                            ItemJnlLine2.Reset();
                            InsertItemJnlLinefromTempInspect(ItemJnlLine2, tempItemJnlLine, SORInspectHeadr, ItemJnlLine2."Entry Type"::Consumption);
                            GenerateRecReserveEntryItemJnlLineInspect(ItemJnlLine2, SORInspectHeadr, SORInspectPkgLineRec);
                            // ItemJnlLine2.PostingItemJnlFromProduction(false);

                            if not IsSuppressCommit then begin
                                Commit();
                                Error('Der Prozess ist angehalten. Bitte prüfen Sie das Output- und Verbrauchs-journal, um die zu überprüfen.');
                            end;
                            if PreviewPostingItemJournalLine(ItemJnlLine, ItemJnlLine2) then begin
                                PostOUTPUTandthenCONSUMPItemJnlLineforSORInspection(ItemJnlLine, ItemJnlLine2);
                            end else begin
                                DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine);
                                DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine2);
                            end;
                        end else
                            Error('Failed to creating the Consumption Journal after posting the Output Journal.');

                        SORInspectPkgLineRec.Process := true;
                        SORInspectPkgLineRec.Modify();

                        if SORInspectPkgLineRec.Result = SORInspectPkgLineRec.Result::Rework then begin
                            // CREATE NEW SOR PROD ORDER CREATION
                            tempProdOrderRec.DeleteAll();
                            if NewSORProdOrderCreation(SORProdOrdCreationRec, SORInspectHeadr, SORInspectPkgLineRec) then begin
                                ValidateInputBeforePosting(SORProdOrdCreationRec);
                                if SimulateInsertSuccess(tempProdOrderRec, SORProdOrdCreationRec) then begin
                                    SortProdOrdCreationPost(ProdOrderRec2, tempProdOrderRec, SORProdOrdCreationRec);
                                end else begin
                                    Error('Failed to create the Sortation Production Order during the creation process. %1', GetLastErrorText());
                                end;
                            end;
                        end;
                    end;
                end else if SORInspectPkgLineRec.Result = SORInspectPkgLineRec.Result::Rejected then begin
                    SORInspectPkgLineRec.Process := true;
                    SORInspectPkgLineRec.Modify();
                end;
            until SORInspectPkgLineRec.Next() = 0;
        Message('The sortation inspection process posting (No. %1) for the sorted item (%2) is successfully posted.', SORInspectHeadr."No.", SORInspectHeadr."Sorted Item No.");

        SORInspectHeadr."Document Status" := CheckStatusofSORInspectHeaderAfterPosting(SORInspectHeadr);
        SORInspectHeadr.Modify();
    end;

    /// <summary><b>Determines</b> and returns the <b>document status</b> (Partially Processed/Fully Processed) of an SOR Inspection Package header based on whether all its <b>lines</b> have been <b>processed</b>.</summary>
    local procedure CheckStatusofSORInspectHeaderAfterPosting(var SORInspectHeadr: Record "PMP15 SOR Inspection Pkg Headr"): enum "PMP15 SOR Inspection Doc. Type"
    var
        SORInspectPkgLine: Record "PMP15 SOR Inspection Pkg. Line";
    begin
        SORInspectPkgLine.Reset();
        SORInspectPkgLine.SetRange("Document No.", SORInspectHeadr."No.");
        SORInspectPkgLine.SetRange(Process, false);
        if SORInspectPkgLine.Count > 0 then
            exit(SORInspectHeadr."Document Status"::"Partially Processed")
        else
            exit(SORInspectHeadr."Document Status"::"Fully Processed");
    end;

    /// <summary><b>Creates a new temporary sortation production order creation record for rework</b> scenarios by initializing it with data from the inspection line and validating required company setup fields.</summary>
    local procedure NewSORProdOrderCreation(var SORProdOrdCreationRec: Record "PMP15 Sortation PO Creation" temporary; var SORInspectHeadr: Record "PMP15 SOR Inspection Pkg Headr"; SORInspectPkgLineRec: Record "PMP15 SOR Inspection Pkg. Line"): Boolean
    var
        Status: Enum "Production Order Status";
        ProdOrderRec: Record "Production Order";
    begin
        SORProdOrdCreationRec.DeleteAll();
        Clear(Status);
        ProdOrderRec.Reset();
        ExtCompanySetup.Get();
        PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Item Owner Internal"));
        PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 Sort-Prod. Order Nos."));
        PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Location Code"));

        ProdOrderRec.SetRange("Source No.", SORInspectPkgLineRec."Sorted Item No.");
        ProdOrderRec.SetRange("Variant Code", SORInspectPkgLineRec."Sorted Variant Code");
        ProdOrderRec.SetRange("Location Code", SORInspectPkgLineRec."Location Code");
        ProdOrderRec.SetRange("PMP15 SOR Inspection Pkg. No.", SORInspectHeadr."No.");
        if ProdOrderRec.FindFirst() then begin
            exit(false);
        end;

        SORProdOrdCreationRec.Init();
        SORProdOrdCreationRec.Validate(Rework, true);
        // SORProdOrdCreationRec.Validate("Sorted Item No.", SORInspectHeadr."Sorted Item No.");
        // SORProdOrdCreationRec.Validate("Sorted Variant Code", SORInspectHeadr."Sorted Variant Code");
        SORProdOrdCreationRec.Validate("Sorted Item No.", SORInspectPkgLineRec."Sorted Item No.");
        SORProdOrdCreationRec.Validate("Sorted Variant Code", SORInspectPkgLineRec."Sorted Variant Code");
        SORProdOrdCreationRec.Validate("Lot No.", SORInspectPkgLineRec."Lot No.");
        SORProdOrdCreationRec.Validate(Quantity, SORInspectPkgLineRec.Quantity);
        SORProdOrdCreationRec.Validate("Reference No.", SORInspectPkgLineRec."Prod. Order No.");
        SORProdOrdCreationRec.Validate("Reference Line No.", SORInspectPkgLineRec."Prod. Order Line No.");
        SORProdOrdCreationRec."PMP15 Item Owner Internal" := ExtCompanySetup."PMP15 SOR Item Owner Internal";
        Status := Status::"Firm Planned";
        exit(SORProdOrdCreationRec.Insert());
    end;

    /// <summary>Checks if a <b>Released Production Order</b> already exists for any line in the specified SOR Inspection Package, returning TRUE and populating ProdOrderRec if found.</summary>
    local procedure IsInspectionProductionOrderisExist(var SORInspectHeadr: Record "PMP15 SOR Inspection Pkg Headr"; var ProdOrderRec: Record "Production Order"): Boolean
    var
        ReleasedProdOrderRec: Record "Production Order";
        SORInspectPkgLine: Record "PMP15 SOR Inspection Pkg. Line";
        IsExistingProdOrderNoFound: Boolean;
    begin
        Clear(IsExistingProdOrderNoFound);
        SORInspectPkgLine.Reset();

        SORInspectPkgLine.SetRange("Document No.", SORInspectHeadr."No.");
        if SORInspectPkgLine.FindSet() then
            repeat
                ReleasedProdOrderRec.Reset();
                ReleasedProdOrderRec.SetRange(Status, ReleasedProdOrderRec.Status::Released);
                ReleasedProdOrderRec.SetRange("No.", SORInspectPkgLine."Prod. Order No.");
                if ReleasedProdOrderRec.FindFirst() then begin
                    IsExistingProdOrderNoFound := true;
                    ProdOrderRec := ReleasedProdOrderRec;
                    ProdOrderRec.Mark(true);
                    exit(true);
                end;
            until (SORInspectPkgLine.Next() = 0) OR IsExistingProdOrderNoFound;
        exit(false);
    end;

    /// <summary>Generates <b>Reservation Entries</b> for Item Journal Lines during SOR inspection posting based on <b>Item Tracking Code</b> settings and available package/lot information.</summary>
    /// <remarks>Creates reservation entries for OUTPUT or CONSUMPTION journal lines by first validating the item and its tracking code, then sourcing lot/package data from a temporary summary table, package inventory, or the inspection line itself, before finally inserting the reservation record.</remarks>
    /// <param name="RecItemJnlLine">The Item Journal Line record for which to generate reservation entries. Passed by reference as it may be modified.</param>
    /// <param name="SORInspectHeadr">SOR Inspection Package Header containing lot number and document context.</param>
    /// <param name="SORInspectPkgLineRec">SOR Inspection Package Line with package number, quantity, and item details.</param>
    procedure GenerateRecReserveEntryItemJnlLineInspect(var RecItemJnlLine: Record "Item Journal Line"; SORInspectHeadr: Record "PMP15 SOR Inspection Pkg Headr"; SORInspectPkgLineRec: Record "PMP15 SOR Inspection Pkg. Line")
    var
        Item: Record Item;
        RecReservEntry: Record "Reservation Entry";
        TrackingSpecification: Record "Tracking Specification";
        TempTrackingSpecification: Record "Tracking Specification" temporary;
        PackageNoInfo: Record "Package No. Information";
        SerLotPkgArr: array[3] of Code[50];
    begin
        Clear(SerLotPkgArr);
        ItemTrackingCode.Reset();

        // if RecItemJnlLine.ReservEntryExist() then
        //     Error('Item tracking information already exists for this reclassification journal line. Please remove the existing tracking before proceeding.');

        Item.SetLoadFields("Item Tracking Code");
        if not Item.Get(RecItemJnlLine."Item No.") then
            Error('The specified Item No. "%1" could not be found. Please verify that the item exists in the system.', RecItemJnlLine."Item No.");

        if Item."Item Tracking Code" = '' then
            Error('The Item "%1" does not have an assigned Item Tracking Code. Please configure the Item Tracking Code in the Item Card before continuing.', RecItemJnlLine."Item No.");

        if ItemJnlLineReserve.ReservEntryExist(RecItemJnlLine) then
            Error('Reservation entries already exist for Item "%1" in this reclassification journal line. Please cancel or delete the existing reservations before performing this action.', RecItemJnlLine."Item No.");

        ItemTrackingCode.Get(Item."Item Tracking Code");

        if RecItemJnlLine."Entry Type" = RecItemJnlLine."Entry Type"::Output then begin
            // SerLotPkgArr[1] := '';
            // if ItemTrackingCode."Lot Specific Tracking" then
            //     SerLotPkgArr[2] := SORInspectHeadr."Lot No."
            // else if ItemTrackingCode."Package Specific Tracking" then
            //     SerLotPkgArr[3] := SORInspectPkgLineRec."Package No.";

            // InsertReservEntryRecfromTempTrackSpecIJL(RecReservEntry, TempTrackingSpecification, RecItemJnlLine, SORInspectHeadr, SORInspectPkgLineRec, SerLotPkgArr);

            ItemJnlLineReserve.InitFromItemJnlLine(TempTrackingSpecification, RecItemJnlLine);
            TempTrackingSpecification.Insert();
            RetrieveLookupData(TempTrackingSpecification, true);
            TempTrackingSpecification.Delete();
            TempGlobalEntrySummary.Reset();
            TempGlobalEntrySummary.SetFilter("Lot No.", SORInspectHeadr."Lot No.");
            TempGlobalEntrySummary.SetFilter("Package No.", SORInspectPkgLineRec."Package No.");
            if TempGlobalEntrySummary.FindSet() then begin
                SerLotPkgArr[1] := '';
                if ItemTrackingCode."Lot Specific Tracking" then
                    SerLotPkgArr[2] := TempGlobalEntrySummary."Lot No.";
                if ItemTrackingCode."Package Specific Tracking" then
                    SerLotPkgArr[3] := TempGlobalEntrySummary."Package No.";
                InsertReservEntryRecfromTempTrackSpecIJL(RecReservEntry, TempTrackingSpecification, RecItemJnlLine, SORInspectHeadr, SORInspectPkgLineRec, SerLotPkgArr);
            end else begin
                PackageNoInfo.SetAutoCalcFields("PMP04 Bin Code", Inventory, "PMP04 Lot No.");
                PackageNoInfo.SetRange("Item No.", RecItemJnlLine."Item No.");
                PackageNoInfo.SetRange("PMP04 Lot No.", SORInspectHeadr."Lot No.");
                PackageNoInfo.SetFilter("Variant Code", RecItemJnlLine."Variant Code");
                PackageNoInfo.SetFilter("PMP04 Bin Code", RecItemJnlLine."Bin Code");
                if PackageNoInfo.FindFirst() then begin
                    SerLotPkgArr[1] := '';
                    if ItemTrackingCode."Lot Specific Tracking" then
                        SerLotPkgArr[2] := PackageNoInfo."PMP04 Lot No.";
                    if ItemTrackingCode."Package Specific Tracking" then
                        SerLotPkgArr[3] := PackageNoInfo."Package No.";
                    InsertReservEntryRecfromTempTrackSpecIJL(RecReservEntry, TempTrackingSpecification, RecItemJnlLine, SORInspectHeadr, SORInspectPkgLineRec, SerLotPkgArr);
                end else begin
                    if ItemTrackingCode."Lot Specific Tracking" then
                        SerLotPkgArr[2] := SORInspectPkgLineRec."Lot No.";
                    if ItemTrackingCode."Package Specific Tracking" then
                        SerLotPkgArr[3] := SORInspectPkgLineRec."Package No.";
                    InsertReservEntryRecfromTempTrackSpecIJL(RecReservEntry, TempTrackingSpecification, RecItemJnlLine, SORInspectHeadr, SORInspectPkgLineRec, SerLotPkgArr);
                end;
            end;
        end else if RecItemJnlLine."Entry Type" = RecItemJnlLine."Entry Type"::Consumption then begin
            ItemJnlLineReserve.InitFromItemJnlLine(TempTrackingSpecification, RecItemJnlLine);
            TempTrackingSpecification.Insert();
            RetrieveLookupData(TempTrackingSpecification, true);
            TempTrackingSpecification.Delete();
            TempGlobalEntrySummary.Reset();
            TempGlobalEntrySummary.SetFilter("Lot No.", SORInspectHeadr."Lot No.");
            TempGlobalEntrySummary.SetFilter("Package No.", RecItemJnlLine."Package No.");
            if TempGlobalEntrySummary.FindSet() then begin
                // SerLotPkgArr[1] := TempGlobalEntrySummary."Serial No.";
                SerLotPkgArr[1] := '';
                if ItemTrackingCode."Lot Specific Tracking" then
                    SerLotPkgArr[2] := TempGlobalEntrySummary."Lot No.";
                if ItemTrackingCode."Package Specific Tracking" then
                    SerLotPkgArr[3] := TempGlobalEntrySummary."Package No.";
                InsertReservEntryRecfromTempTrackSpecIJL(RecReservEntry, TempTrackingSpecification, RecItemJnlLine, SORInspectHeadr, SORInspectPkgLineRec, SerLotPkgArr);
            end else begin
                PackageNoInfo.SetAutoCalcFields("PMP04 Bin Code", Inventory, "PMP04 Lot No.");
                PackageNoInfo.SetRange("Item No.", RecItemJnlLine."Item No.");
                PackageNoInfo.SetRange("PMP04 Lot No.", SORInspectHeadr."Lot No.");
                PackageNoInfo.SetFilter("Variant Code", RecItemJnlLine."Variant Code");
                PackageNoInfo.SetFilter("PMP04 Bin Code", RecItemJnlLine."Bin Code");
                // PackageNoInfo.SetFilter("PMP04 Bin Code", RecItemJnlLine."Bin Code");
                if PackageNoInfo.FindFirst() then begin
                    SerLotPkgArr[1] := '';
                    if ItemTrackingCode."Lot Specific Tracking" then
                        SerLotPkgArr[2] := PackageNoInfo."PMP04 Lot No.";
                    if ItemTrackingCode."Package Specific Tracking" then
                        SerLotPkgArr[3] := PackageNoInfo."Package No.";
                    InsertReservEntryRecfromTempTrackSpecIJL(RecReservEntry, TempTrackingSpecification, RecItemJnlLine, SORInspectHeadr, SORInspectPkgLineRec, SerLotPkgArr);
                end;
            end;
        end;
    end;

    /// <summary>Inserts a new <b>Reservation Entry</b> by preparing a <b>Tracking Specification</b> from an Item Journal Line and registering the change with serial/lot/package tracking data from the provided array.</summary>
    local procedure InsertReservEntryRecfromTempTrackSpecIJL(var RecReservEntry: Record "Reservation Entry"; var TempTrackingSpecification: Record "Tracking Specification" temporary; var RecItemJnlLine: Record "Item Journal Line"; SORInspectHeadr: Record "PMP15 SOR Inspection Pkg Headr"; SORInspectPkgLineRec: Record "PMP15 SOR Inspection Pkg. Line"; SerLotPkgArr: array[3] of Code[50])
    var
        SourceTrackingSpecification: Record "Tracking Specification";
        ChangeType: Option Insert,Modify,FullDelete,PartDelete,ModifyAll;
        ItemTrackingLine: Page "Item Tracking Lines";
        TypeHelper: Codeunit "Type Helper";
        Item: Record Item;
        RecRef: RecordRef;
    begin
        Item.Get(RecItemJnlLine."Item No.");
        RecRef.GetTable(Item);
        if Item."Item Tracking Code" = '' then
            PMPAppLogicMgmt.ErrorRecordRefwithAction(RecRef, Item.FieldNo(Description), Page::"Item Card", 'Empty Field', StrSubstNo('The Item "%1" does not have an assigned Item Tracking Code. Please configure the Item Tracking Code in the Item Card before continuing.', Item."No."));

        ItemJnlLineReserve.InitFromItemJnlLine(SourceTrackingSpecification, RecItemJnlLine);
        ItemTrackingLine.SetSourceSpec(SourceTrackingSpecification, 0D);

        TempTrackingSpecification.Init;
        TempTrackingSpecification.TransferFields(SourceTrackingSpecification);
        TempTrackingSpecification.SetItemData(SourceTrackingSpecification."Item No.", SourceTrackingSpecification.Description, SourceTrackingSpecification."Location Code", SourceTrackingSpecification."Variant Code", SourceTrackingSpecification."Bin Code", SourceTrackingSpecification."Qty. per Unit of Measure");
        TempTrackingSpecification.Validate("Item No.", SourceTrackingSpecification."Item No.");
        TempTrackingSpecification.Validate("Location Code", SourceTrackingSpecification."Location Code");
        TempTrackingSpecification.Validate("Creation Date", DT2Date(TypeHelper.GetCurrentDateTimeInUserTimeZone()));
        TempTrackingSpecification.Validate("Source Type", SourceTrackingSpecification."Source Type");
        TempTrackingSpecification.Validate("Source Subtype", SourceTrackingSpecification."Source Subtype");
        TempTrackingSpecification.Validate("Source ID", SourceTrackingSpecification."Source ID");
        TempTrackingSpecification.Validate("Source Batch Name", SourceTrackingSpecification."Source Batch Name");
        TempTrackingSpecification.Validate("Source Prod. Order Line", SourceTrackingSpecification."Source Prod. Order Line");
        TempTrackingSpecification.Validate("Source Ref. No.", SourceTrackingSpecification."Source Ref. No.");

        if SerLotPkgArr[1] <> '' then
            TempTrackingSpecification.Validate("Serial No.", SerLotPkgArr[1]);
        if SerLotPkgArr[2] <> '' then
            TempTrackingSpecification.Validate("Lot No.", SerLotPkgArr[2]);
        if SerLotPkgArr[3] <> '' then
            TempTrackingSpecification.Validate("Package No.", SerLotPkgArr[3]);

        TempTrackingSpecification.Validate("Quantity (Base)", RecItemJnlLine."Quantity (Base)");
        TempTrackingSpecification.Validate("Qty. to Handle (Base)", RecItemJnlLine."Quantity (Base)");
        TempTrackingSpecification.Validate("Qty. to Invoice (Base)", RecItemJnlLine."Quantity (Base)");
        ItemTrackingLine.RegisterChange(TempTrackingSpecification, TempTrackingSpecification, ChangeType::Insert, false);
    end;

    /// <summary>Posts the <b>marked OUTPUT journal lines</b> first, then the <b>marked CONSUMPTION journal lines</b>, and finally deletes all posted lines from both journal batches.</summary>
    local procedure PostOUTPUTandthenCONSUMPItemJnlLineforSORInspection(var ItemJnlLine: Record "Item Journal Line"; var ItemJnlLine2: Record "Item Journal Line")
    var
        ItemJnlPostMgmt: Codeunit "Item Jnl.-Post";
        ItemJnlBatchPostMgmt: Codeunit "Item Jnl.-Post Batch";
        ItemJnlPostLineMgmt: Codeunit "Item Jnl.-Post Line";
    begin
        ItemJnlLine.MarkedOnly(true);
        ItemJnlBatchPostMgmt.Run(ItemJnlLine);

        ItemJnlLine2.MarkedOnly(true);
        ItemJnlBatchPostMgmt.Run(ItemJnlLine2);

        DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine);
        DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(ItemJnlLine2);
    end;


    #endregion SOR INSPECTION PACKING LIST

    #region SOR UNPACK PACKAGE
    // 
    #endregion SOR UNPACK PACKAGE

    #region HELPER
    /// <summary>Converts a value from the "PMP15 Sortation Step Enum" to the corresponding "PMP15 Bin Step-Type" enum.</summary>
    /// <remarks>Maps each sortation step (0–4) to its matching bin step-type value. Raises an error if the specified step is not supported.</remarks>
    /// <param name="Step">The sortation step enum value to convert.</param>
    /// <returns>The corresponding bin step-type enum value.</returns>
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

    /// <summary>Converts a text input into the corresponding Sortation Step enum value.</summary>
    /// <remarks>Handles conversion from text representation ('0'–'4', or 'X' for blank) to the PMP15 Sortation Step Enum. Throws an error if the input value is invalid.</remarks>
    /// <param name="Word1">Text containing the sortation step value.</param>
    /// <returns>The corresponding enum value of type "PMP15 Sortation Step Enum".</returns>
    procedure ConvertTexttoSORStepEnum(Word1: Text): Enum "PMP15 Sortation Step Enum"
    var
        StepEnum: Enum "PMP15 Sortation Step Enum";
    begin
        case Word1 of
            'X':
                StepEnum := StepEnum::" ";
            '0':
                StepEnum := StepEnum::"0";
            '1':
                StepEnum := StepEnum::"1";
            '2':
                StepEnum := StepEnum::"2";
            '3':
                StepEnum := StepEnum::"3";
            '4':
                StepEnum := StepEnum::"4";
            else
                Error('Invalid Sortation Step value: %1', Word1);
        end;
        exit(StepEnum);
    end;

    /// <summary>Retrieves SOR bin codes based on predefined bin types and relationships.</summary>
    /// <remarks>Finds bins for SOR steps 0–4 and identifies the previous bin linked to step 0.</remarks>
    /// <param name="SORBinCode">An array used to store the retrieved SOR bin codes.</param>
    local procedure GetSORBinCodes(var SORBinCode: array[7] of Code[20])
    var
        Bins: Record Bin;
    begin
        Bins.Reset();
        Bins.SetRange("PMP15 Bin Type", Bins."PMP15 Bin Type"::"0");
        if Bins.FindFirst() then begin
            SORBinCode[1] := Bins.Code;
            SORBinCode[6] := Bins."PMP15 Previous Bin";
        end;
        Bins.SetRange("PMP15 Bin Type", Bins."PMP15 Bin Type"::"1");
        if Bins.FindFirst() then begin
            SORBinCode[2] := Bins.Code;
        end;
        Bins.SetRange("PMP15 Bin Type", Bins."PMP15 Bin Type"::"2");
        if Bins.FindFirst() then begin
            SORBinCode[3] := Bins.Code;
        end;
        Bins.SetRange("PMP15 Bin Type", Bins."PMP15 Bin Type"::"3");
        if Bins.FindFirst() then begin
            SORBinCode[4] := Bins.Code;
        end;
        Bins.SetRange("PMP15 Bin Type", Bins."PMP15 Bin Type"::"4");
        if Bins.FindFirst() then begin
            SORBinCode[5] := Bins.Code;
        end;
        Bins.SetRange("PMP15 Bin Type", Bins."PMP15 Bin Type"::Filler);
        if Bins.FindFirst() then begin
            SORBinCode[7] := Bins.Code;
        end;
        // Bins.SetRange("PMP15 Previous Bin", SORBinCode[1]);
        // if Bins.FindFirst() then begin
        //     SORBinCode[6] := Bins.Code;
        // end;
    end;

    /// <summary>Splits a Sortation Step master code into its step and code parts.</summary>
    /// <remarks>Extracts the first segment (before the first dash) and converts it into a Sortation Step enum. The remaining part is stored as a code value.</remarks>
    /// <param name="InputText">Full sortation step code in text format.</param>
    /// <param name="Part1">Output parameter returning the Sortation Step enum derived from the first segment.</param>
    /// <param name="Part2">Output parameter returning the remaining code after the first dash.</param>
    procedure SplitSORStepCodeMaster(InputText: Text; var Part1: Enum "PMP15 Sortation Step Enum"; var Part2: Code[50])
    var
        DashPos: Integer;
    begin
        DashPos := StrPos(InputText, '-');
        if DashPos > 0 then begin
            Part1 := ConvertTexttoSORStepEnum(CopyStr(InputText, 1, DashPos - 1));
            Part2 := CopyStr(InputText, DashPos + 1, MaxStrLen(Part2));
        end else begin
            Part1 := Part1::" ";
            Part2 := InputText;
        end;
    end;

    ///<summary>Retrieves and loads the location record corresponding to the provided location code, or clears it if the code is blank.</summary>
    local procedure GetLocation(LocationCode: Code[10])
    begin
        if LocationCode = '' then
            Clear(Location)
        else
            if Location.Code <> LocationCode then
                Location.Get(LocationCode);
    end;

    /// <summary>Generates the next available reservation entry number.</summary>
    /// <remarks>This procedure increments the internal counter for reservation entries. If not initialized, it retrieves the latest existing reservation entry number before incrementing.</remarks>
    /// <returns>The newly generated reservation entry number.</returns>
    procedure NextReservEntryNo(): Integer
    var
        ReserveEntry: Record "Reservation Entry";
    begin
        ReserveEntry.Reset();
        if LastReservEntryNo = 0 then
            if ReserveEntry.FindLast() then
                LastReservEntryNo := ReserveEntry."Entry No.";
        LastReservEntryNo += 1;
        exit(LastReservEntryNo);
    end;

    /// <summary>Generates the next available entry number for the Tracking Specification table.</summary>
    /// <remarks>This procedure retrieves the latest Tracking Specification entry number if not initialized, increments it by one, and returns the new value.</remarks>
    /// <returns>The newly generated tracking specification entry number.</returns>
    procedure NextTrackingSpecEntryNo(): Integer
    var
        TrackSpec: Record "Tracking Specification";
    begin
        TrackSpec.Reset();
        if LastTrackingSpecEntryNo = 0 then
            if TrackSpec.FindLast() then
                LastTrackingSpecEntryNo := TrackSpec."Entry No.";
        LastTrackingSpecEntryNo += 1;
        exit(LastTrackingSpecEntryNo);
    end;

    /// <summary>Retrieves and loads the item tracking code for the specified item number.</summary>
    /// <remarks>This procedure obtains the item record, verifies the presence of an item tracking code, and loads the corresponding Item Tracking Code record if different from the current one.</remarks>
    /// <param name="ItemNo">The item number used to identify and load the related item tracking code.</param>
    procedure GetItemTrackingCode(ItemNo: Code[20])
    begin
        GetItem(ItemNo);

        if RecItem."Item Tracking Code" = '' then
            exit;

        if RecItem."Item Tracking Code" <> ItemTrackingCode.Code then
            ItemTrackingCode.Get(RecItem."Item Tracking Code");
    end;

    /// <summary>Retrieves the item record for the specified item number.</summary>
    /// <remarks>This procedure checks whether the current item record matches the given item number and fetches it from the database if not.</remarks>
    /// <param name="ItemNo">The item number of the record to be retrieved.</param>
    procedure GetItem(ItemNo: Code[20])
    begin
        if RecItem."No." <> ItemNo then begin
            if not RecItem.Get(ItemNo) then
                exit;
        end;
    end;

    /// <summary>Assigns the crop information to a Production Order based on package number details.</summary>
    /// <remarks>This procedure searches the Package No. Information table for a record matching the Production Order’s item, variant, and package number, and assigns the corresponding crop value if found.</remarks>
    /// <param name="ProdOrder">The Production Order record to be updated with crop information.</param>
    /// <param name="PackageNo">The package number used to identify the related Package No. Information record.</param>
    procedure GetProdOrderCropfromPkgNoInfo(var ProdOrder: Record "Production Order"; PackageNo: Code[50])
    var
        PkgNoRec: Record "Package No. Information";
    begin
        PkgNoRec.Reset();

        PkgNoRec.SetRange("Item No.", ProdOrder."PMP15 RM Item No.");
        PkgNoRec.SetFilter("Variant Code", ProdOrder."PMP15 RM Variant Code");
        PkgNoRec.SetFilter("Package No.", PackageNo);
        if PkgNoRec.FindFirst() then begin
            ProdOrder."PMP15 Crop" := PkgNoRec."PMP04 Crop";
        end;
    end;


    /// <summary>Retrieves the sub-merk group values from the specified Sortation Production Order Detail Line record.</summary>
    /// <remarks>This procedure extracts the group codes for each sub-merk level based on the provided Sortation Detail Quality record and assigns them to the corresponding array elements.</remarks>
    /// <param name="SubmerkGroup">An array that will store the resulting sub-merk group codes.</param>
    /// <param name="SORProdOrdDetLine">The Sortation Detail Quality record containing the sub-merk and tobacco type data used for group lookup.</param>
    procedure GetSubmerkGROUPfromSORPrdOrdDetLine(var SubmerkGroup: array[5] of Code[50]; SORProdOrdDetLine: Record "PMP15 Sortation Detail Quality")
    var
        SubMerkRec: Record "PMP15 Sub Merk";
    begin
        SubmerkGroup[1] := SORProdOrdDetLine."Sub Merk 1";

        SubMerkRec.Reset();
        SubMerkRec.SetRange(Type, SubMerkRec.Type::"Sub Merk 2");
        SubMerkRec.SetRange(Code, SORProdOrdDetLine."Sub Merk 2");
        SubMerkRec.SetRange("Tobacco Type", SORProdOrdDetLine."Tobacco Type");
        if SubMerkRec.FindFirst() then
            SubmerkGroup[2] := SubMerkRec.Group;

        SubMerkRec.Reset();
        SubMerkRec.SetRange(Type, SubMerkRec.Type::"Sub Merk 3");
        SubMerkRec.SetRange(Code, SORProdOrdDetLine."Sub Merk 3");
        SubMerkRec.SetRange("Tobacco Type", SORProdOrdDetLine."Tobacco Type");
        if SubMerkRec.FindFirst() then
            SubmerkGroup[3] := SubMerkRec.Group;

        SubMerkRec.Reset();
        SubMerkRec.SetRange(Type, SubMerkRec.Type::"Sub Merk 4");
        SubMerkRec.SetRange(Code, SORProdOrdDetLine."Sub Merk 4");
        if SubMerkRec.FindFirst() then
            SubmerkGroup[4] := SubMerkRec.Group;

        SubMerkRec.Reset();
        SubMerkRec.SetRange(Type, SubMerkRec.Type::"Sub Merk 5");
        SubMerkRec.SetRange(Code, SORProdOrdDetLine."Sub Merk 5");
        if SubMerkRec.FindFirst() then
            SubmerkGroup[5] := SubMerkRec.Group;
    end;

    #region REMOVED GetSubmerkGROUPfromSORPrdOrdDetLine()
    // OBSOLATE : REMOVED
    // OBSOLATE STATE : Since the last update for the Sortation Version 2. The Sub Merk records merged into one, divided by Type alone.

    // procedure GetSubmerkGROUPfromSORPrdOrdDetLine(var SubmerkGroup: array[5] of Code[50]; SORProdOrdDetLine: Record "PMP15 Sortation Detail Quality")
    // var
    //     Submerk2Rec: Record "PMP15 Sub Merk 2";
    //     Submerk3Rec: Record "PMP15 Sub Merk 3";
    //     Submerk4Rec: Record "PMP15 Sub Merk 4";
    //     Submerk5Rec: Record "PMP15 Sub Merk 5";
    // begin
    //     Submerk2Rec.Reset();
    //     Submerk3Rec.Reset();
    //     Submerk4Rec.Reset();
    //     Submerk5Rec.Reset();

    //     SubmerkGroup[1] := SORProdOrdDetLine."Sub Merk 1";
    //     if Submerk2Rec.Get(SORProdOrdDetLine."Sub Merk 2", SORProdOrdDetLine."Tobacco Type") then
    //         SubmerkGroup[2] := Submerk2Rec.Group;
    //     if Submerk3Rec.Get(SORProdOrdDetLine."Sub Merk 3", SORProdOrdDetLine."Tobacco Type") then
    //         SubmerkGroup[3] := Submerk3Rec.Group;
    //     if Submerk4Rec.Get(SORProdOrdDetLine."Sub Merk 4") then
    //         SubmerkGroup[4] := Submerk4Rec.Group;
    //     if Submerk5Rec.Get(SORProdOrdDetLine."Sub Merk 5") then
    //         SubmerkGroup[5] := Submerk5Rec.Group;
    // end;
    #endregion REMOVED GetSubmerkGROUPfromSORPrdOrdDetLine()

    /// <summary>Converts a sub-merk code to an integer and appends it to a provided list.</summary>
    /// <remarks>This procedure evaluates the sub-merk code value as an integer and adds it to the list if the conversion is successful.</remarks>
    /// <param name="SubmerkCodes">The sub-merk code to be converted.</param>
    /// <param name="SubMerkList">The list that will store the integer representations of sub-merk codes.</param>
    procedure AddSubmerkCodestoINT(SubmerkCodes: Code[50]; var SubMerkList: List of [Integer])
    var
        SubmerkConversion: Integer;
    begin
        Clear(SubmerkConversion);
        if Evaluate(SubmerkConversion, SubmerkCodes) then
            SubMerkList.Add(SubmerkConversion);
    end;

    ///<summary>Determines the minimum and maximum integer values converted from a list of sub-merk codes.</summary>
    local procedure GetMinMaxSubMerkFromList(SubmerkCodes: array[5] of Code[50]; var MinValue: Integer; var MaxValue: Integer)
    var
        i: Integer;
        A: Integer;
        B: Integer;
        CountList: Integer;
        SubMerkList: List of [Integer];
    begin
        // GET MIN MAX PAIRWISE FOR 5 SUBMERKS
        AddSubmerkCodestoINT(SubmerkCodes[1], SubMerkList);
        AddSubmerkCodestoINT(SubmerkCodes[2], SubMerkList);
        AddSubmerkCodestoINT(SubmerkCodes[3], SubMerkList);
        AddSubmerkCodestoINT(SubmerkCodes[4], SubMerkList);
        AddSubmerkCodestoINT(SubmerkCodes[5], SubMerkList);
        CountList := SubMerkList.Count();

        if CountList = 0 then begin
            MinValue := 0;
            MaxValue := 0;
            exit;
        end;

        SubMerkList.Get(1, MinValue);
        MaxValue := MinValue;
        i := 2;
        while i <= CountList do begin
            SubMerkList.Get(i, A);
            if (i + 1) > CountList then begin
                if A > MaxValue then MaxValue := A;
                if A < MinValue then MinValue := A;
                exit;
            end;

            SubMerkList.Get(i + 1, B);
            if A > B then begin
                if A > MaxValue then MaxValue := A;
                if B < MinValue then MinValue := B;
            end else begin
                if B > MaxValue then MaxValue := B;
                if A < MinValue then MinValue := A;
            end;

            i := i + 2;
        end;
    end;

    /// <summary>Checks whether the total quantity in Sortation Detail Quality records meets or exceeds the specified minimum expected quantity.</summary>
    /// <remarks>This procedure sums the quantity values of the filtered Sortation Detail Quality records and compares the result to the given threshold.</remarks>
    /// <param name="SDR">The Sortation Detail Quality record containing the applied filters for quantity evaluation.</param>
    /// <param name="MinimumExpectedQty_">The minimum expected quantity to be compared against the calculated total.</param>
    /// <returns>True if the total quantity is greater than or equal to the specified minimum; otherwise, false.</returns>
    procedure CheckQtySDRIsBiggerThan(SDR: Record "PMP15 Sortation Detail Quality"; MinimumExpectedQty_: Decimal) IsBigger: Boolean;
    var
        SDR2: Record "PMP15 Sortation Detail Quality";
        SumQty: Decimal;
    begin
        SDR2.Reset();
        Clear(SumQty);
        SDR2.CopyFilters(SDR);
        if SDR2.FindSet() then
            repeat
                SumQty += SDR2.Quantity;
            until SDR2.Next() = 0;
        IsBigger := SumQty >= MinimumExpectedQty_;
        exit(IsBigger);
    end;

    ///<summary>Assigns multiple sub-merk code values into the provided array in sequential order.</summary>
    local procedure SetSubmerkCodes(var SubmerkCodes: array[5] of Code[50]; Submerk1: Code[50]; Submerk2: Code[50]; Submerk3: Code[50]; Submerk4: Code[50]; Submerk5: Code[50])
    begin
        SubmerkCodes[1] := Submerk1;
        SubmerkCodes[2] := Submerk2;
        SubmerkCodes[3] := Submerk3;
        SubmerkCodes[4] := Submerk4;
        SubmerkCodes[5] := Submerk5;
    end;

    ///<summary>Retrieves sub-merk codes corresponding to the record with the highest quantity for a given item, variant, and package number.</summary>
    local procedure GetSubmerkforBiggestRank(var SubmerkCodes: array[5] of Code[50]; ItemNo: Code[20]; VarCode: Code[50]; PkgNo: Code[50])
    var
        SDRQuery: Query "PMP15 SOR-Detail Result Pkg-No";
        MaxQty: Decimal;
    begin
        // MaxQty := 2000000000;
        MaxQty := 0;
        SDRQuery.SetRange(SDRQuery.SDR_ItemNo, ItemNo);
        SDRQuery.SetFilter(SDRQuery.SDR_VariantCode, VarCode);
        SDRQuery.SetFilter(SDRQuery.SDR_PackageNo, PkgNo);
        SDRQuery.Open();
        while SDRQuery.Read() do begin
            if (SDRQuery.SM3_Ranking > MaxQty) AND ((SDRQuery.SDR_SubMerk2 <> '') OR (SDRQuery.SDR_SubMerk3 <> '')) then begin
                MaxQty := SDRQuery.SM3_Ranking;
                SubmerkCodes[1] := SDRQuery.SDR_SubMerk1;
                SubmerkCodes[2] := SDRQuery.SDR_SubMerk2;
                SubmerkCodes[3] := SDRQuery.SDR_SubMerk3;
                SubmerkCodes[4] := SDRQuery.SDR_SubMerk4;
                SubmerkCodes[5] := SDRQuery.SDR_SubMerk5;
            end;
        end;
    end;

    /// <summary>Validates that the Sortation Inspection Package Header contains required item and variant information and has no existing lines before processing.</summary>
    /// <param name="SORInspectPkg">The Sortation Inspection Package Header record to validate.</param>
    /// <return>True if validation succeeds; otherwise, an error is raised.</return>
    procedure ValidateSORInspectInputs(SORInspectPkg: Record "PMP15 SOR Inspection Pkg Headr"): Boolean
    var
        SORInspectPkgLine: Record "PMP15 SOR Inspection Pkg. Line";
    begin
        if SORInspectPkg."Sorted Item No." = '' then begin
            Error('Sorted Item No. must have a value.');
            exit(false);
        end;

        // if SORInspectPkg."Sorted Variant Code" = '' then begin
        //     Error('Sorted Variant Code must have a value.');
        //     exit(false);
        // end;

        SORInspectPkgLine.Reset();
        SORInspectPkgLine.SetRange("Document No.", SORInspectPkg."No.");
        if SORInspectPkgLine.Count > 0 then begin
            Error('Sortation Inspection Packing List Lines must be empty');
            exit(false);
        end;

        exit(true);
    end;

    /// <summary>Converts a single-character Left/Right code into its corresponding PMP15 L__R Enum value.</summary>
    /// <param name="LRCode">The code representing Left ('L') or Right ('R').</param>
    /// <return>The corresponding enum value, or blank if no match is found.</return>
    procedure ConvertLREnumfromCodes(LRCode: Code[1]): Enum "PMP15 L__R Enum"
    var
        LREnum: enum "PMP15 L__R Enum";
    begin
        if LRCode = 'L' then
            exit(LREnum::L)
        else if LRCode = 'R' then
            exit(LREnum::R)
        else
            exit(LREnum::" ");
    end;

    /// <summary>Converts a <b>Sortation Step Enum</b> value to its corresponding <b>integer representation</b> (0-4).</summary>
    /// <remarks>Provides a simple mapping from the "PMP15 Sortation Step Enum" members ("0", "1", "2", "3", "4") to their integer equivalents.</remarks>
    /// <param name="StepEnum">The enumeration value to convert.</param>
    /// <returns>The integer value (0, 1, 2, 3, or 4) corresponding to the provided enum member.</returns>
    procedure ConvertEnumSortationStep_toInteger(StepEnum: Enum "PMP15 Sortation Step Enum"): Integer
    begin
        case StepEnum of
            StepEnum::"0":
                exit(0);
            StepEnum::"1":
                exit(1);
            StepEnum::"2":
                exit(2);
            StepEnum::"3":
                exit(3);
            StepEnum::"4":
                exit(4);
        end;
    end;

    /// <summary>Previews the posting of <b>two sets of Item Journal Lines</b> to validate transaction feasibility before actual posting.</summary>
    /// <remarks> This procedure performs a <b>dry-run validation</b> of both OUTPUT and CONSUMPTION journal lines by utilizing the Item Journal Posting codeunit in preview mode. It attempts to post the first set of journal lines (Rec), and if successful (or if the only error is the expected preview mode error), it proceeds to validate the second set (Rec2). If either preview fails, all marked lines are deleted from both batches, and the function returns FALSE. If both previews succeed, it returns TRUE, indicating that the actual posting can proceed safely.
    /// </remarks>
    /// <param name="Rec">The first set of Item Journal Lines (typically OUTPUT entries) to preview for posting.</param>
    /// <param name="Rec2">The second set of Item Journal Lines (typically CONSUMPTION entries) to preview for posting.</param>
    /// <returns>TRUE if both journal batches pass the preview validation; FALSE if either batch fails preview posting.</returns>
    procedure PreviewPostingItemJournalLine(var Rec: Record "Item Journal Line"; var Rec2: Record "Item Journal Line"): Boolean
    var
        TempIJLRec: Record "Item Journal Line" temporary;
        ItemJnlPost: Codeunit "Item Jnl.-Post";
        ReservationManagement: Codeunit "Reservation Management";
        ItemJnlLineReservelocal: Codeunit "Item Jnl. Line-Reserve";
        Result: Boolean;
    begin
        Rec.MarkedOnly(true);
        // if Rec.FindSet() then
        // repeat
        Commit();
        Clear(Result);

        ItemJnlPost.SetPreviewMode(true);
        if (ItemJnlPost.Run(Rec)) OR (GetLastErrorText() <> PreviewModeErr) then begin
            DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(Rec);
            DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(Rec2);
            ItemJnlPost.Preview(Rec);
            exit(false); // Failed
        end;

        ItemJnlPost.SetPreviewMode(true);
        if (ItemJnlPost.Run(Rec2)) OR (GetLastErrorText() <> PreviewModeErr) then begin
            DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(Rec);
            DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(Rec2);
            ItemJnlPost.Preview(Rec2);
            exit(false); // Failed
        end;
        // until Rec.Next() = 0;
        exit(true); // SuccessGenerateRecReserveEntryItemJnlLine
    end;

    /// <summary>Deletes all <b>marked Item Journal Lines</b> and their associated <b>Reservation Entries</b> before committing the transaction.</summary>
    local procedure DeleteAllMarkedOnlyItemJnlLinePassingByReferenceVar(var Rec: Record "Item Journal Line")
    var
        ReservationManagement: Codeunit "Reservation Management";
    begin
        Rec.MarkedOnly(true);

        if Rec.FindSet() then
            repeat
                ReservationManagement.SetReservSource(Rec);
                ReservationManagement.SetItemTrackingHandling(1);
                // Allow Deletion
                ReservationManagement.DeleteReservEntries(true, 0);
                Rec.CalcFields("Reserved Qty. (Base)");
            until Rec.Next() = 0;
        Rec.DeleteAll();
        Commit();
    end;

    /// <summary>Checks if a specific <b>Package Number</b> already exists in the system for a given Item and Variant combination.</summary>
    /// <remarks>Searches the Package No. Information table for a matching record based on Item No., Variant Code, and Package No. parameters.</remarks>
    /// <param name="ItemNoCode">The item number to search for.</param>
    /// <param name="ItemVariantCode">The item variant code to filter by.</param>
    /// <param name="PackageNo">The package number to verify existence.</param>
    /// <returns>TRUE if the package number exists; FALSE if it does not.</returns>
    procedure PackageNoIsExist(ItemNoCode: Code[20]; ItemVariantCode: Code[10]; PackageNo: Code[50]): Boolean
    var
        PackageNoInfoRec: Record "Package No. Information";
    begin
        PackageNoInfoRec.Reset();
        PackageNoInfoRec.SetRange("Item No.", ItemNoCode);
        PackageNoInfoRec.SetRange("Variant Code", ItemVariantCode);
        PackageNoInfoRec.SetRange("Package No.", PackageNo);
        if PackageNoInfoRec.Count > 0 then begin
            exit(true);
        end else begin
            exit(false);
        end;
    end;

    /// <summary>Creates a new <b>Package No. Information</b> record from an Item Journal Line and temporary Sortation Production Order data.</summary>
    /// <remarks>Initializes a new package record with item details, bin information, sub-brand markers (Merk 1-5), L/R designation, crop data, production order reference, lot number, and links it to the unsorted item from the sortation order.</remarks>
    /// <param name="ItemJnlLineRec">The source Item Journal Line containing package and tracking details.</param>
    /// <param name="SortProdOrderRec">Temporary Sortation Production Order record providing unsorted item references.</param>
    procedure CreateNewPackagefromItemJnlLineOutput(ItemJnlLineRec: Record "Item Journal Line"; var SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary)
    var
        PackageNoInfoRec: Record "Package No. Information";
    begin
        PackageNoInfoRec.Reset();
        PackageNoInfoRec.Init();
        PackageNoInfoRec."Item No." := ItemJnlLineRec."Item No.";
        PackageNoInfoRec."Variant Code" := ItemJnlLineRec."Variant Code";
        PackageNoInfoRec."Package No." := ItemJnlLineRec."Package No.";
        PackageNoInfoRec."PMP04 Bin Code" := ItemJnlLineRec."Bin Code";
        PackageNoInfoRec."PMP04 Sub Merk 1" := ItemJnlLineRec."PMP15 Sub Merk 1";
        PackageNoInfoRec."PMP04 Sub Merk 2" := ItemJnlLineRec."PMP15 Sub Merk 2";
        PackageNoInfoRec."PMP04 Sub Merk 3" := ItemJnlLineRec."PMP15 Sub Merk 3";
        PackageNoInfoRec."PMP04 Sub Merk 4" := ItemJnlLineRec."PMP15 Sub Merk 4";
        PackageNoInfoRec."PMP04 Sub Merk 5" := ItemJnlLineRec."PMP15 Sub Merk 5";
        if ItemJnlLineRec."PMP15 L/R" = ItemJnlLineRec."PMP15 L/R"::L then begin
            PackageNoInfoRec."PMP04 L/R" := 'L';
        end else if ItemJnlLineRec."PMP15 L/R" = ItemJnlLineRec."PMP15 L/R"::R then begin
            PackageNoInfoRec."PMP04 L/R" := 'R';
        end;
        PackageNoInfoRec."PMP04 Crop" := ItemJnlLineRec."PMP15 Crop";
        PackageNoInfoRec."PMP07 Prod. Order No." := ItemJnlLineRec."PMP15 Prod. Order No.";
        PackageNoInfoRec."PMP04 Lot No." := ItemJnlLineRec."Lot No.";

        PackageNoInfoRec."PMP15 Unsorted Item No." := SortProdOrderRec."Unsorted Item No.";
        PackageNoInfoRec."PMP15 Unsorted Variant Code" := SortProdOrderRec."Unsorted Variant Code";
        PackageNoInfoRec.Insert();
    end;

    /// <summary>Converts a <b>string code</b> to a <b>Sortation Step Enum</b> value after extracting a single digit.</summary>
    /// <remarks>Extracts the first digit from the input code using GetSingleDigitFromCode() and maps it to the corresponding enum member ("0"-"4"), or returns a blank enum value for invalid digits.</remarks>
    /// <param name="SORStepCode">The input code containing the step digit (e.g., "1", "2A", "3-B").</param>
    /// <returns>The corresponding Sortation Step Enum value, or blank for invalid/unsupported digits.</returns>
    procedure ConvertCode_toSortationStepEnum(SORStepCode: Code[50]) SORStep: Enum "PMP15 Sortation Step Enum"
    begin
        SORStepCode := GetSingleDigitFromCode(SORStepCode);

        case SORStepCode of
            '0':
                SORStep := SORStep::"0";
            '1':
                SORStep := SORStep::"1";
            '2':
                SORStep := SORStep::"2";
            '3':
                SORStep := SORStep::"3";
            '4':
                SORStep := SORStep::"4";
            else
                SORStep := SORStep::" ";
        end;

        exit(SORStep);
    end;

    /// <summary>Extracts the <b>first numeric digit</b> (0-9) from a given input code string.</summary>
    /// <remarks> Iterates through each character of the input code from left to right and returns the first character that is a numeric digit (0 through 9). If no numeric digit is found in the entire string, the function returns an empty string. This is useful for parsing codes that may contain alphanumeric combinations and extracting the primary numeric identifier.
    /// </remarks>
    /// <param name="InputCode">The alphanumeric code string to search for numeric digits.</param>
    /// <returns>The first numeric digit found as a single character string, or an empty string if no digits are present.</returns>
    procedure GetSingleDigitFromCode(InputCode: Code[50]): Code[1]
    var
        i: Integer;
    begin
        for i := 1 to StrLen(InputCode) do
            if InputCode[i] in ['0' .. '9'] then
                exit(InputCode[i]);

        exit(''); // tidak ada angka sama sekali
    end;

    /// <summary>Checks if an <b>unblocked Lot No. Information</b> record exists for the specified Item/Variant/Lot combination and returns it if found.</summary>
    local procedure LotNoInformationIsExist(var LotNoInfo: Record "Lot No. Information"; ItemNo: Code[20]; VariantCode: Code[10]; LotNoCode: Code[50]): Boolean
    var
        LotNoInfoRec: Record "Lot No. Information";
    begin
        LotNoInfoRec.Reset();
        LotNoInfoRec.SetRange("Item No.", ItemNo);
        LotNoInfoRec.SetRange("Variant Code", VariantCode);
        LotNoInfoRec.SetRange("Lot No.", LotNoCode);
        LotNoInfoRec.SetRange(Blocked, false);
        if LotNoInfoRec.FindFirst() then begin
            LotNoInfo := LotNoInfoRec;
            exit(true);
        end else begin
            exit(false);
        end;
    end;

    /// <summary>Creates a <b>new Lot No. Information</b> record by copying data from an existing record with updated Item, Variant, and Lot No. values.</summary>
    local procedure CreateNewLotNoInformationfromOldLotNoInfo(var OldLotNoInfo: Record "Lot No. Information"; NewItemNo: Code[20]; NewVariantCode: Code[10]; NewLotNoCode: Code[50]): Record "Lot No. Information"
    var
        NewLotNoInfo: Record "Lot No. Information";
    begin
        NewLotNoInfo.Reset();

        NewLotNoInfo.Init();
        NewLotNoInfo := OldLotNoInfo;
        NewLotNoInfo."Item No." := NewItemNo;
        NewLotNoInfo."Variant Code" := NewVariantCode;
        NewLotNoInfo."Lot No." := NewLotNoCode;
        NewLotNoInfo.Insert();
        exit(NewLotNoInfo);
    end;

    /// <summary>Validates whether a <b>Bin Content record with positive quantity</b> exists for a specific Item, Variant, and Location combination.</summary>
    /// <remarks> Searches the Bin Content table for records matching the provided Item No., Variant Code, and Location Code, automatically calculating the base quantity field. It applies a filter to only consider bins where the "Quantity (Base)" is greater than zero. If a matching record is found, it populates the output BinContent parameter with the record data and returns TRUE; otherwise, it returns FALSE.
    /// </remarks>
    /// <param name="BinContent">Output parameter that will contain the found Bin Content record if one exists.</param>
    /// <param name="ItemNo">The item number to search for in bin contents.</param>
    /// <param name="VariantCode">The item variant code to filter by.</param>
    /// <param name="LocationCode">The warehouse location code to search within.</param>
    /// <returns>TRUE if a bin content record with positive quantity exists; FALSE otherwise.</returns>
    procedure ValidateBinContentIsExistforItemJnlLine(var BinContent: Record "Bin Content"; ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10]): Boolean
    var
        BinContentRec: Record "Bin Content";
    begin
        BinContentRec.Reset();
        BinContentRec.SetRange("Location Code", LocationCode);
        BinContentRec.SetRange("Item No.", ItemNo);
        BinContentRec.SetRange("Variant Code", VariantCode);
        BinContentRec.SetAutoCalcFields("Quantity (Base)");
        BinContentRec.SetFilter("Quantity (Base)", '>0');
        if BinContentRec.FindFirst() then begin
            BinContent := BinContentRec;
            exit(true);
        end else begin
            exit(false);
        end;
    end;

    /// <summary>Retrieves the <b>Sub Merk 1 value</b> from the Item Variant record for a given Item and Variant combination.</summary>
    /// <remarks> Looks up the Item Variant table using the provided Item No. and Variant Code, and returns the value stored in the "PMP15 Sub Merk 1" field if the variant exists. If no matching item variant is found, the function returns an empty string.
    /// </remarks>
    /// <param name="ItemNo">The item number to search for.</param>
    /// <param name="VariantCode">The variant code of the item.</param>
    /// <returns>The Sub Merk 1 value as text, or an empty string if the item variant is not found.</returns>
    procedure GetSubmerk1fromItemNVariant(ItemNo: Code[20]; VariantCode: Code[10]): Code[50]
    var
        ItemVariantRec: Record "Item Variant";
    begin
        ItemVariantRec.Reset();
        ItemVariantRec.SetRange("Item No.", ItemNo);
        ItemVariantRec.SetRange(Code, VariantCode);
        if ItemVariantRec.FindFirst() then begin
            exit(ItemVariantRec."PMP15 Sub Merk 1");
        end else
            exit('');
    end;

    #region ERROR HELPER
    /// <summary>Opens the Extended Company Setup page for configuration review.</summary>
    /// <remarks>This procedure retrieves the Extended Company Setup record and opens the corresponding configuration page for user interaction.</remarks>
    /// <param name="ErrorInfo">Reserved parameter for error handling context.</param>
    procedure OpenExtCompanySetupPage(ErrorInfo: ErrorInfo)
    var
        ExtCompanySetup: Record "PMP07 Extended Company Setup";
    begin
        ExtCompanySetup.Get();
        Page.Run(Page::"PMP07 Extended Company Setup", ExtCompanySetup);
    end;

    /// <summary>Opens the Item Card page for the specified item number.</summary>
    /// <remarks>This procedure retrieves the Item record based on the provided item number and opens the Item Card page if the record exists.</remarks>
    /// <param name="ErrorInfo">Reserved parameter for error handling context.</param>
    /// <param name="ItemNo">The item number of the Item record to be displayed on the Item Card page.</param>
    procedure ItemCard(ErrorInfo: ErrorInfo; ItemNo: Code[20])
    var
        Item: Record Item;
    begin
        if Item.Get(ItemNo) then begin
            Page.Run(Page::"Item Card", Item);
        end;
    end;

    /// <summary>Validates and tests the package number setup for the specified item.</summary>
    /// <remarks>This procedure verifies that the item exists and that the related Package Nos. field is defined. If the field is blank, an error is raised with navigation to the corresponding Item Card page.</remarks>
    /// <param name="GetLastNoUsed">The last used Package Nos. value to be validated.</param>
    /// <param name="ItemNo">The item number being validated for package setup consistency.</param>
    local procedure Validate_TestInsertItemJnlLine_ITEMPMP04PackageNos(GetLastNoUsed: Code[20]; ItemNo: Code[20])
    var
        ErrInfo: ErrorInfo;
        Item: Record Item;
    begin
        ExtCompanySetup.Get();

        if not Item.Get(ItemNo) then
            Error('There is no existing Item no. of %1 in the table', ItemNo);

        if GetLastNoUsed = '' then begin
            ErrInfo.DataClassification(DataClassification::SystemMetadata);
            ErrInfo.ErrorType(ErrorType::Client);
            ErrInfo.Verbosity(Verbosity::Error);
            ErrInfo.Title := 'ITEM - Package Nos. is empty';
            ErrInfo.Message := StrSubstNo('The Package Nos. field for item "%1" is blank. Please define the Package Nos. before proceeding with the transaction.', ItemNo);
            ErrInfo.PageNo(Page::"Item Card");
            ErrInfo.FieldNo(Item.FieldNo("No."));
            ErrInfo.RecordId(Item.RecordId());
            ErrInfo.AddNavigationAction('Show Item Card');
            Error(ErrInfo);
            Clear(ErrInfo);
        end;
    end;

    /// <summary>Validates the existence of a specific <b>Production Item Type ("Sortation-Inspection")</b> in the system and raises a navigable error if not found.</summary>
    /// <remarks> This procedure performs a critical system validation check by searching the Production Item Type table for an entry where the "Production Item Type" field equals the "Sortation-Inspection" enum value. If no such record exists, it constructs a comprehensive error message using the ErrorInfo data type, which includes a user-friendly title, detailed message, and a navigation action that allows users to directly open the Production Item Types page to address the missing configuration. This validation ensures that necessary master data is present before proceeding with sortation inspection transactions.
    /// </remarks>
    procedure CheckProductionItemTypeforSortationInspectionisExist()
    var
        ProdItemTypeRec: Record "PMP07 Production Item Type";
        ErrInfo: ErrorInfo;
    begin
        ProdItemTypeRec.Reset();
        ProdItemTypeRec.SetRange("Production Item Type", Enum::"PMP09 Production Item Type"::"Sortation-Inspection");
        if not ProdItemTypeRec.FindFirst() then begin
            ErrInfo.DataClassification(DataClassification::SystemMetadata);
            ErrInfo.ErrorType(ErrorType::Client);
            ErrInfo.Verbosity(Verbosity::Error);
            ErrInfo.Title := 'PROD. ITEM TYPES - Data not found';
            ErrInfo.Message := StrSubstNo('The Production Item Type of "%1" is not found or have not been specified yet. Please define the Production Item Type before proceeding with the transaction.', Enum::"PMP09 Production Item Type"::"Sortation-Inspection");
            ErrInfo.PageNo(Page::"PMP07 Production Item Types");
            ErrInfo.AddNavigationAction('Open Prod. Item Types');
            Error(ErrInfo);
            Clear(ErrInfo);
        end;
    end;
    #endregion ERROR HELPER
    #endregion HELPER

    [IntegrationEvent(false, false)]
    local procedure OnAfterSORInpctPkgLineSetFiltersofPackageNoInfo(var SORInspectHeadr: Record "PMP15 SOR Inspection Pkg Headr"; var PackageNoInfo: Record "Package No. Information")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeInsert(var SORInspectPkg: Record "PMP15 SOR Inspection Pkg Headr"; var IsHandled: Boolean)
    begin
    end;
}
