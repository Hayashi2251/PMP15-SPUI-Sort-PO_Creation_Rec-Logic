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
        NoSeriesMgmt: Codeunit "No. Series";
        NoSeriesBatchMgmt: Codeunit "No. Series - Batch";
        AssemblyHeaderReserve: Codeunit "Assembly Header-Reserve";
        AssemblyLineReserve: Codeunit "Assembly Line-Reserve";
        ItemTrackingDataCollection: Codeunit "Item Tracking Data Collection";
        ItemJnlLineReserve: Codeunit "Item Jnl. Line-Reserve";
        PkgNoInfoMgmt: Codeunit "Package Info. Management";
        // 
        RefreshProdOrder: Report "Refresh Production Order";
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



    #region SOR CREATION
    // Updates the "Sorted Item Description" and "Unit of Measure Code" fields after validating the "Sorted Item No." by retrieving data from the Item table.
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
        end;
    end;

    // Updates related item, variant, and BOM-linked fields after validating the "Sorted Variant Code" by retrieving corresponding unsorted and raw material item data from SKU and production BOM structures.
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
        IsFound: Boolean;
    begin
        ExtCompanySetup.Get();
        ItemVarRec.Reset();
        // // Fill Sorted Item Description with Description on Item Variant.
        // if Rec."Sorted Variant Code" <> '' then begin
        //     ItemVarRec.SetRange("Item No.", Rec."Sorted Item No.");
        //     ItemVarRec.SetRange(Code, Rec."Sorted Variant Code");
        //     if ItemVarRec.FindFirst() then
        //         Rec."Sorted Item Description" := ItemVarRec.Description;
        // end;
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
                    if ItemRec.Get(ProdBOMLine."No.") then begin
                        // YABAI
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
                            IsFound := true;
                        end;
                    end;
                until (ProdBOMLine.Next() = 0) OR IsFound;
        end;
        // =====================================================================================
        StockkeepingUnit.Reset();
        ProdBOMHead.Reset();
        ProdBOMLine.Reset();
        StockkeepingUnit.SetRange("Item No.", Rec."Unsorted Item No.");
        StockkeepingUnit.SetRange("Variant Code", Rec."Unsorted Variant Code"); // YABAI
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

    // Updates the "Unsorted Item Description" field after validating the "Unsorted Item No." by retrieving the item description from the Item table.
    [EventSubscriber(ObjectType::Table, Database::"PMP15 Sortation PO Creation", OnAfterValidateEvent, "Unsorted Item No.", false, false)]
    local procedure PMP15SortationPOCreation_OnAfterValidateEvent_UnsortedItemNo(CurrFieldNo: Integer; var Rec: Record "PMP15 Sortation PO Creation"; var xRec: Record "PMP15 Sortation PO Creation")
    var
        ItemRec: Record Item;
    begin
        if ItemRec.Get(Rec."Unsorted Item No.") then
            Rec."Unsorted Item Description" := ItemRec.Description;
    end;

    // Updates the "Tarre Weight (Kg)" field after validating the "Lot No." by retrieving the corresponding value from Lot No. Information.
    [EventSubscriber(ObjectType::Table, Database::"PMP15 Sortation PO Creation", OnAfterValidateEvent, "Lot No.", false, false)]
    local procedure PMP15SortationPOCreation_OnAfterValidateEvent_TarreWeight_Kgs_(CurrFieldNo: Integer; var Rec: Record "PMP15 Sortation PO Creation"; var xRec: Record "PMP15 Sortation PO Creation")
    var
        LotNoInfo: Record "Lot No. Information";
    begin
        Clear(Rec."Tarre Weight (Kg)");
        Clear(Rec.Quantity);
        LotNoInfo.SetRange("Item No.", Rec."Unsorted Item No.");
        LotNoInfo.SetRange("Variant Code", Rec."Unsorted Variant Code");
        LotNoInfo.SetRange("Lot No.", Rec."Lot No.");
        if LotNoInfo.FindFirst() then begin
            Rec."Tarre Weight (Kg)" := LotNoInfo."PMP14 Tarre Weight (Kgs)";
        end;
    end;

    /// <summary>Simulates the insertion of a production order record for validation before actual creation.</summary>
    /// <remarks>Initializes a temporary production order based on sortation data and extended company setup, assigns default values, and returns the success result of the simulated insert.</remarks>
    /// <param name="tempProdOrderRec">The temporary production order record to simulate insertion.</param>
    /// <param name="SortProdOrdCreation">The temporary sortation production order creation record used as the data source.</param>
    /// <returns>True if the simulated insert succeeds; otherwise, false.</returns>
    procedure SimulateInsertSuccess(var tempProdOrderRec: Record "Production Order" temporary; var SortProdOrdCreation: Record "PMP15 Sortation PO Creation" temporary) IsInsertSuccess: Boolean
    begin
        ExtCompanySetup.Get();
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
        tempProdOrderRec."PMP15 Crop" := Date2DMY(WorkDate(), 3);
        tempProdOrderRec."PMP15 Lot No." := SortProdOrdCreation."Lot No.";
        tempProdOrderRec."PMP15 Tarre Weight (Kg)" := SortProdOrdCreation."Tarre Weight (Kg)";
        tempProdOrderRec."PMP15 Production Unit" := tempProdOrderRec."PMP15 Production Unit"::"SOR-Sortation";
        tempProdOrderRec."PMP15 SOR Rework" := SortProdOrdCreation.Rework;
        tempProdOrderRec."PMP15 Reference No." := SortProdOrdCreation."Reference No.";
        tempProdOrderRec."PMP04 Item Owner Internal" := ExtCompanySetup."PMP15 SOR Item Owner Internal";
        exit(tempProdOrderRec.Insert());
    end;

    /// <summary>Executes the refresh routine for the specified Production Order.</summary>
    /// <remarks>This procedure locates the Production Order by document number, initializes the refresh process, and runs it without displaying the validation dialog or request page. An error is raised if the document cannot be found.</remarks>
    /// <param name="ProdOrdRec">The Production Order record used to identify the document that will be refreshed.</param>
    procedure RunRefreshProdOrder(ProdOrdRec: Record "Production Order")
    var
        ProdOrder: Record "Production Order";
    begin
        ProdOrder.SetRange("No.", ProdOrdRec."No.");
        if ProdOrder.FindFirst() then begin
            RefreshProdOrder.SetTableView(ProdOrder);
            RefreshProdOrder.InitializeRequest(1, true, true, true, false);
            RefreshProdOrder.SetHideValidationDialog(true);
            RefreshProdOrder.UseRequestPage(false);
            RefreshProdOrder.Run();
        end else
            Error('There is no Production Order with the document number of %1', ProdOrdRec."No.");
    end;

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
        SORBinCode: array[6] of Code[20]; // -- Bin Code = Bin with SOR Step 0 + "|" + Bin with SOR Step 1 + "|" + Bin with SOR Step 2 + "|" + Bin with SOR Step 3 + "|" + Bin with SOR Step 4 + "|" + Previous Bin with SOR Step 0
    begin
        ExtCompanySetup.Get();
        Clear(SORBinCode);
        if Confirm('Do you want to complete Production Order No. %1 for the sorted item of %2 - %3 with Lot No. %4?', TRUE, ProdOrder."No.", ProdOrder."Source No.", ProdOrder."Variant Code", ProdOrder."PMP15 Lot No.") AND (ProdOrder."No." <> '') then begin
            if ExtCompanySetup."PMP15 SOR Inv. Shipment Nos" = '' then begin
                ErrInfo.DataClassification(DataClassification::SystemMetadata);
                ErrInfo.ErrorType(ErrorType::Client);
                ErrInfo.Verbosity(Verbosity::Error);
                ErrInfo.Title := 'Setup Required';
                ErrInfo.Message := 'The SOR Inventory Shipment No. Series has not been defined. Please open the Extended Company Setup page and complete the required configuration before continuing.';
                ErrInfo.AddAction('Open Ext. Company Setup', Codeunit::"PMP15 Sortation PO Mgmt", 'OpenExtCompanySetupPage');
                Error(ErrInfo);
            end;

            InvDocHeader.Init();
            InvDocHeader."Document Type" := InvDocHeader."Document Type"::Shipment; // add
            InvDocHeader."No. Series" := ExtCompanySetup."PMP15 SOR Inv. Shipment Nos";
            InvDocHeader."No." := NoSeriesMgmt.GetNextNo(InvDocHeader."No. Series", WorkDate());
            InvDocHeader."Posting Description" := 'Shipment ' + InvDocHeader."No."; // add
            InvDocHeader."Location Code" := ProdOrder."Location Code";
            InvDocHeader.Validate("Document Date", WorkDate());
            InvDocHeader.Validate("Posting Date", WorkDate());
            // InvDocHeader."Document Date" := WorkDate(); // add
            // InvDocHeader."Posting Date" := WorkDate();
            InvDocHeader."PMP15 Production Order No." := ProdOrder."No.";
            InvDocHeader."PMP18 Reason Code" := ExtCompanySetup."PMP15 SOR Invt.Ship.Reason";
            InvDocHeader.Insert();
            Commit();

            GetSORBinCodes(SORBinCode);
            BinContent.Reset();
            BinContent.SetAutoCalcFields();
            BinContent.SetRange("Location Code", InvDocHeader."Location Code");
            BinContent.SetFilter("Bin Code", '%1 | %2 | %3 | %4 | %5 | %6', SORBinCode[1], SORBinCode[2], SORBinCode[3], SORBinCode[4], SORBinCode[5], SORBinCode[6]);
            if ProdOrder."PMP15 RM Item No." <> '' then
                BinContent.SetRange("Item No.", ProdOrder."PMP15 RM Item No.");
            if ProdOrder."PMP15 RM Variant Code" <> '' then
                BinContent.SetRange("Variant Code", ProdOrder."PMP15 RM Variant Code");
            BinContent.SetFilter("Lot No. Filter", ProdOrder."PMP15 Lot No.");
            BinContent.SetFilter(Quantity, '> 0');

            InvDocLine.Reset();
            InvDocLine.SetRange("Document Type", InvDocLine."Document Type"::Shipment);
            InvDocLine.SetRange("Document No.", InvDocHeader."No.");
            if InvDocLine.Count > 0 then begin
                if InvShipmentPageDoc.AskforConfirmation('Existing inventory shipment lines were found. Do you want to delete them before running Get Bin Content?') = 'YES' then begin
                    InvDocLine.DeleteAll();
                    Commit();
                    Generate_GetBinContent(BinContent, InvDocLine, InvDocHeader);
                end else if ConfirmationPage.GetResult() = 'NO' then begin
                    if InvShipmentPageDoc.AskforConfirmation('If you continue without deleting the existing lines, the inventory shipment may contain inconsistent or duplicate data. Do you want to proceed?') = 'YES' then begin
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



    #endregion SOR CREATION

    #region SOR RECORDING
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
            Rec.Rework := ProdOrder."PMP15 SOR Rework";
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

    // ASSEMBLY HEADER (ORDER) --> POSTED ASSEMBLY HEADER
    // Copies the Sortation fields from Assembly Header into the User ID field of Posted Assembly Header before insert.
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
        PostedAssemblyHeader."PMP15 L/R" := AssemblyHeader."PMP15 L/R";
        PostedAssemblyHeader."PMP15 Rework" := AssemblyHeader."PMP15 Rework";
    end;

    // ASSEMBLY HEADER (ORDER) --> ITEM JOURNAL LINE
    // Transfers the Sortation fields from Assembly Header into Item Journal Line after it is created.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Assembly-Post", OnAfterCreateItemJnlLineFromAssemblyHeader, '', false, false)]
    local procedure PMP15CopyPostAssemblyHeadrtoItemJnlLine_OnAfterCreateItemJnlLineFromAssemblyHeader(var ItemJournalLine: Record "Item Journal Line"; AssemblyHeader: Record "Assembly Header")
    begin
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
    end;

    // ITEM JOURNAL LINE --> ITEM LEDGER ENTRY (ILE)
    // Copies the Sortation fields from Item Journal Line into Item Ledger Entry after initialization.
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
    end;

    // ITEM JOURNAL LINE --> WAREHOUSE JOURNAL LINE to WAREHOUSE ENTRY right after posting ILE.
    // Copies the Sortations fields from Item Journal Line into Warehouse Journal Line after initialization.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"WMS Management", OnInitWhseJnlLineCopyFromItemJnlLine, '', false, false)]
    local procedure PMP15CopyItemJnlLinetoWhsJnlLine_OnInitWhseJnlLineCopyFromItemJnlLine(var WarehouseJournalLine: Record "Warehouse Journal Line"; ItemJournalLine: Record "Item Journal Line")
    begin
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
    end;

    // WAREHOUSE JOURNAL LINE --> WAREHOUSE ENTRY
    // Copies the Sortations fields from Warehouse Journal Line into Warehouse Entry after insert.
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
        WarehouseEntry.Modify();
    end;

    // ITEM JOURNAL LINE --> WAREHOUSE JOURNAL LINE (ITEM JOURNAL POSTING)
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"WMS Management", OnAfterCreateWhseJnlLine, '', false, false)]
    local procedure PMP15CopyWhseJnlLinefromItemJnlLine_OnAfterCreateWhseJnlLine(var WhseJournalLine: Record "Warehouse Journal Line"; ItemJournalLine: Record "Item Journal Line"; ToTransfer: Boolean)
    begin
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
    end;

    // WAREHOUSE JOURNAL LINE --> WAREHOUSE ENTRY (ITEM JOURNAL POSTING)
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
    end;

    // ITEM JOURNAL LINE --> ITEM LEDGER ENTRY (ITEM JOURNAL POSTING)
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
    end;

    /// <summary>Creates an Assembly Header document based on Sortation Order Recording data.</summary>
    /// <remarks>This procedure initializes and populates the Assembly Header fields using Sortation Order information and company setup configuration, then inserts the record.</remarks>
    /// <param name="AssemblyHeader">The Assembly Header record to be created and inserted.</param>
    /// <param name="ProdOrder">The related Production Order record.</param>
    /// <param name="SortProdOrderRec">The temporary Sortation Production Order Recording used as source data.</param>
    /// <param name="SORStep_Step">The Sortation Step Enum value applied to the Assembly Header.</param>
    procedure CreateAssemblyHeadfromSORRecording(var AssemblyHeader: Record "Assembly Header"; var ProdOrder: Record "Production Order"; SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary; SORStep_Step: Enum "PMP15 Sortation Step Enum")
    var
        SORStepEnum: Enum "PMP15 Sortation Step Enum";
        SORStepCode: Code[20];
    begin
        ExtCompanySetup.Get();
        // 
        AssemblyHeader.Init();
        AssemblyHeader."Document Type" := AssemblyHeader."Document Type"::Order;
        AssemblyHeader."No." := NoSeriesMgmt.GetNextNo(ExtCompanySetup."PMP15 SOR Assembly Order Nos", WorkDate());
        AssemblyHeader.Validate("No. Series", ExtCompanySetup."PMP15 SOR Assembly Order Nos");
        AssemblyHeader.Validate("Posting No. Series", ExtCompanySetup."PMP15 SOR Pstd-Asmbly Ord. Nos");
        AssemblyHeader."Posting Date" := WorkDate();
        AssemblyHeader.Validate("Due Date", WorkDate());
        AssemblyHeader.Validate("Starting Date", WorkDate());
        AssemblyHeader.Validate("Ending Date", WorkDate());
        AssemblyHeader."Last Date Modified" := WorkDate();
        AssemblyHeader.Validate("Item No.", SortProdOrderRec."Unsorted Item No.");
        AssemblyHeader.Validate("Variant Code", SortProdOrderRec."Unsorted Variant Code");
        AssemblyHeader.Validate("Location Code", SortProdOrderRec."Location Code");
        AssemblyHeader.Validate("Bin Code", SortProdOrderRec."To Bin Code");
        AssemblyHeader.Validate(Quantity, SortProdOrderRec.Quantity);
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

    // Creates or updates entry summary records based on the provided tracking specification and reservation entry.
    local procedure CreateEntrySummary(TrackingSpecification: Record "Tracking Specification" temporary; TempReservEntry: Record "Reservation Entry" temporary)
    begin
        CreateEntrySummary2(TrackingSpecification, TempReservEntry, true);
        CreateEntrySummary2(TrackingSpecification, TempReservEntry, false);
    end;

    // Updates the bin content quantity in the entry summary based on related warehouse entries.
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

    // Builds or aggregates entry summary data for serial or non-serial tracked items derived from reservation entry details.
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

    // Collects tracking source data from item ledger and reservation entries to initialize temporary tracking structures.
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
    begin
        if AssemblyHeader.ReservEntryExist() then
            Error('Item tracking information already exists for this Assembly Order (%1). Please remove the existing tracking before proceeding.', AssemblyHeader."No.");

        Item.SetLoadFields("Item Tracking Code");
        if not Item.Get(AssemblyHeader."Item No.") then
            Error('The specified Item No. "%1" could not be found. Please verify that the item exists in the system.', AssemblyHeader."Item No.");

        if Item."Item Tracking Code" = '' then
            Error('The Item "%1" does not have an assigned Item Tracking Code. Please configure the Item Tracking Code in the Item Card before continuing.', AssemblyHeader."Item No.");

        AssemblyHeaderReserve.InitFromAsmHeader(TempTrackingSpecification, AssemblyHeader);
        TempTrackingSpecification.Insert();

        RetrieveLookupData(TempTrackingSpecification, true);
        TempTrackingSpecification.Delete();
        TempGlobalEntrySummary.Reset();
        TempGlobalEntrySummary.SetRange("Lot No.", SortProdOrderRec."Lot No.");
        TempGlobalEntrySummary.SetRange("Package No.", SortProdOrderRec."Package No.");
        if TempGlobalEntrySummary.FindSet() then begin
            AssemblyHeaderReserve.InitFromAsmHeader(TempTrackingSpecification, AssemblyHeader);
            TempTrackingSpecification.Validate("Bin Code", AssemblyHeader."Bin Code");
            TempTrackingSpecification.Validate("Lot No.", TempGlobalEntrySummary."Lot No.");
            TempTrackingSpecification.Validate("Package No.", TempGlobalEntrySummary."Package No.");
            TempTrackingSpecification.Positive := true;
            TempTrackingSpecification."Creation Date" := Today();
            TempTrackingSpecification.Insert();

            CreateReservEntryFrom(RecReservEntry, TempTrackingSpecification);
            RecReservEntry."Entry No." := NextReservEntryNo();
            RecReservEntry."Reservation Status" := RecReservEntry."Reservation Status"::Surplus;
            RecReservEntry.Insert();
        end;
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
    begin
        if AssemblyLine.ReservEntryExist() then
            Error('Item tracking information already exists for this Assembly Line (Line No. %1, Doc. No. %2). Please remove the existing tracking before proceeding.', AssemblyLine."Line No.", AssemblyLine."Document No.");

        Item.SetLoadFields("Item Tracking Code");
        if not Item.Get(AssemblyLine."No.") then
            Error('The specified Item No. "%1" could not be found. Please verify that the item exists in the system.', AssemblyLine."No.");

        if Item."Item Tracking Code" = '' then
            Error('The Item "%1" does not have an assigned Item Tracking Code. Please configure the Item Tracking Code in the Item Card before continuing.', AssemblyLine."No.");

        if AssemblyLineReserve.ReservEntryExist(AssemblyLine) then
            Error(
                'Reservation entries already exist for Item "%1" in this Assembly Line. Please cancel or delete the existing reservations before performing this action.', AssemblyLine."No.");

        AssemblyLineReserve.InitFromAsmLine(TempTrackingSpecification, AssemblyLine);
        TempTrackingSpecification.Insert();

        RetrieveLookupData(TempTrackingSpecification, true);
        TempTrackingSpecification.Delete();
        TempGlobalEntrySummary.Reset();
        TempGlobalEntrySummary.SetRange("Lot No.", SortProdOrderRec."Lot No.");
        if TempGlobalEntrySummary.FindSet() then begin
            InsertReservEntryRecfromTempTrackSpecASMLINE(AssemblyLine, SortProdOrderRec, RecReservEntry, TempTrackingSpecification, TempGlobalEntrySummary."Lot No.", TempGlobalEntrySummary."Package No.");
        end else begin
            PackageNoInfo.SetAutoCalcFields();
            PackageNoInfo.SetRange("Item No.", AssemblyLine."No.");
            PackageNoInfo.SetFilter("Variant Code", AssemblyLine."Variant Code");
            PackageNoInfo.SetFilter("PMP04 Bin Code", AssemblyLine."Bin Code");
            PackageNoInfo.SetRange(Inventory, 0);
            if PackageNoInfo.FindFirst() then
                InsertReservEntryRecfromTempTrackSpecASMLINE(AssemblyLine, SortProdOrderRec, RecReservEntry, TempTrackingSpecification, PackageNoInfo."PMP04 Lot No.", PackageNoInfo."Package No.");
        end;
    end;

    local procedure InsertReservEntryRecfromTempTrackSpecASMLINE(var AssemblyLine: Record "Assembly Line"; SortProdOrderRec: Record "PMP15 Sortation PO Recording"; var RecReservEntry: Record "Reservation Entry"; TempTrackingSpecification: Record "Tracking Specification" temporary; LotNo: Code[50]; PackageNo: Code[50])
    begin
        AssemblyLineReserve.InitFromAsmLine(TempTrackingSpecification, AssemblyLine);

        TempTrackingSpecification."Lot No." := SortProdOrderRec."Lot No.";
        TempTrackingSpecification."Entry No." := NextTrackingSpecEntryNo;
        TempTrackingSpecification.Validate("Bin Code", AssemblyLine."Bin Code");
        TempTrackingSpecification.Validate("Lot No.", LotNo);
        TempTrackingSpecification.Validate("Package No.", PackageNo);
        TempTrackingSpecification.Positive := true;
        TempTrackingSpecification."Creation Date" := Today();
        TempTrackingSpecification.Insert();

        CreateReservEntryFrom(RecReservEntry, TempTrackingSpecification);
        RecReservEntry."Entry No." := NextReservEntryNo();
        RecReservEntry."Reservation Status" := RecReservEntry."Reservation Status"::Surplus;
        RecReservEntry.Insert();
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
        SORPackageNo: Code[50];
        LastLineNo, SORCrop : Integer;
        IsInsertSortation: Boolean;
    begin
        IJL.Reset();
        ItemJnlTemplate.Reset();
        ItemJnlBatch.Reset();
        Item.Reset();
        ExtCompanySetup.Reset();
        ProdOrderRec.Reset();
        ProdOrdLine.Reset();
        ProdOrdComp.Reset();
        ProdOrdRoutingLine.Reset();
        Clear(SORPackageNo);
        Clear(SORCrop);
        Clear(IsInsertSortation);

        ExtCompanySetup.Get();

        IJL.SetRange("Journal Template Name", ItemJnlLine."Journal Template Name");
        IJL.SetRange("Journal Batch Name", ItemJnlLine."Journal Batch Name");
        if IJL.FindLast() then begin
            LastLineNo := IJL."Line No.";
        end;

        if LastLineNo mod 10000 > 0 then begin
            LastLineNo += LastLineNo mod 10000;
        end else begin
            LastLineNo += 10000;
        end;

        if (SORStep_Step = SORStep_Step::"1") OR (SORStep_Step = SORStep_Step::"2") OR (SORStep_Step = SORStep_Step::"3") then begin
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
                tempItemJnlLine."Lot No." := SortProdOrderRec."Lot No.";
                // tempItemJnlLine.Validate("New Lot No.", SortProdOrderRec."Lot No.");
                tempItemJnlLine.Validate("Unit of Measure Code", SortProdOrderRec."Unit of Measure Code");

                IsInsertSortation := true;
            end else
                Error('There is no existing Item no. of %1 in the table', SortProdOrderRec."Unsorted Item No.");
        end else if (SORStep_Step = SORStep_Step::"4") AND (SortProdOrderRec."Tobacco Type" = SortProdOrderRec."Tobacco Type"::Wrapper) then begin
            // WRAPPER SECTION
            if IJLEntryType = IJLEntryType::Consumption then begin
                ProdOrderRec.SetRange("No.", SortProdOrderRec."Sortation Prod. Order No.");
                if not ProdOrderRec.FindFirst() then
                    Error('Production Order No. must not be blank. Please specify a valid Production Order No. before continuing.');

                if Item.Get(SortProdOrderRec."Sorted Item No.") then begin
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

                    ProdOrdLine.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                    ProdOrdLine.SetRange("Item No.", Item."No.");
                    ProdOrdLine.SetFilter("Variant Code", SortProdOrderRec."Sorted Variant Code");
                    if ProdOrdLine.FindFirst() then begin
                        tempItemJnlLine.Validate("Order Line No.", ProdOrdLine."Line No.");
                        tempItemJnlLine.Validate("Location Code", ProdOrdLine."Location Code");
                    end;

                    ProdOrdComp.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                    ProdOrdComp.SetRange("PMP15 Unsorted Item", true);
                    if ProdOrdComp.FindFirst() then begin
                        tempItemJnlLine.Validate("Item No.", ProdOrdComp."Item No.");
                        tempItemJnlLine.Validate("Variant Code", ProdOrdComp."Variant Code");
                        tempItemJnlLine.Validate("Prod. Order Comp. Line No.", ProdOrdComp."Line No.");
                    end;
                    tempItemJnlLine.Validate(Quantity, SortProdOrderRec.Quantity);
                    tempItemJnlLine.Validate("Unit of Measure Code", SortProdOrderRec."Unit of Measure Code");
                    tempItemJnlLine."Work Shift Code" := SortProdOrderRec."Work Shift Code";
                    tempItemJnlLine.Validate("Bin Code", SortProdOrderRec."To Bin Code");
                    // tempItemJnlLine."Bin Code" := SortProdOrderRec."To Bin Code";
                    tempItemJnlLine.Validate("Lot No.", SortProdOrderRec."Lot No.");
                    // STOP & CUT IT HERE TO INSERT THE RELATED ITEM JOURNAL LINE
                    if tempItemJnlLine.Insert() then
                        exit(true)
                    else
                        exit(false);
                end;
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

                    if SortProdOrderRec."Package No." <> '' then
                        tempItemJnlLine.Validate("Package No.", SortProdOrderRec."Package No.")
                    else begin
                        Validate_TestInsertItemJnlLine_ITEMPMP04PackageNos(NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos"), Item."No.");
                        if NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos") <> '' then
                            if ProdOrderRec."PMP15 Crop" = 0 then begin
                                SORCrop := Date2DMY(WorkDate(), 3);
                                SORPackageNo := COPYSTR(Format(SORCrop), STRLEN(Format(SORCrop)) - 1, 2) + NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos");
                            end else
                                SORPackageNo := COPYSTR(Format(ProdOrderRec."PMP15 Crop"), STRLEN(Format(ProdOrderRec."PMP15 Crop")) - 1, 2) + NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos");
                        tempItemJnlLine.Validate("Package No.", SORPackageNo);
                    end;
                    tempItemJnlLine."Lot No." := SortProdOrderRec."Lot No.";
                end;

                IsInsertSortation := true;
            end;
        end else if (SORStep_Step = SORStep_Step::"4") AND (SortProdOrderRec."Tobacco Type" = SortProdOrderRec."Tobacco Type"::PW) then begin
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
                        tempItemJnlLine.Validate("Quantity", SortProdOrderRec.Quantity);
                        tempItemJnlLine.Validate("Unit of Measure Code", SortProdOrderRec."Unit of Measure Code");
                        tempItemJnlLine.Validate("Location Code", PrOL."Location Code");
                        tempItemJnlLine.Validate("Operation No.", PrORL."Operation No.");
                        tempItemJnlLine."Work Shift Code" := SortProdOrderRec."Work Shift Code";
                        tempItemJnlLine.Validate("Bin Code", SortProdOrderRec."From Bin Code");
                        // tempItemJnlLine."Bin Code" := SortProdOrderRec."To Bin Code";
                        tempItemJnlLine."Lot No." := SortProdOrderRec."Lot No.";
                    end;
                end;
            end else begin
                ProdOrderRec.SetRange("No.", SortProdOrderRec."Sortation Prod. Order No.");
                if ProdOrderRec.FindFirst() then begin
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
                    tempItemJnlLine.Validate("Operation No.", PrORL."Operation No.");
                    tempItemJnlLine."Work Shift Code" := SortProdOrderRec."Work Shift Code";
                    tempItemJnlLine.Validate("Bin Code", SortProdOrderRec."To Bin Code");
                    if SortProdOrderRec."Package No." <> '' then
                        tempItemJnlLine.Validate("Package No.", SortProdOrderRec."Package No.")
                    else begin
                        Validate_TestInsertItemJnlLine_ITEMPMP04PackageNos(NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos"), Item."No.");
                        if NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos") <> '' then
                            if ProdOrderRec."PMP15 Crop" = 0 then begin
                                SORCrop := Date2DMY(WorkDate(), 3);
                                SORPackageNo := COPYSTR(Format(SORCrop), STRLEN(Format(SORCrop)) - 1, 2) + NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos");
                            end else
                                SORPackageNo := COPYSTR(Format(ProdOrderRec."PMP15 Crop"), STRLEN(Format(ProdOrderRec."PMP15 Crop")) - 1, 2) + NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos");
                        tempItemJnlLine.Validate("Package No.", SORPackageNo);
                    end;
                    tempItemJnlLine."Lot No." := SortProdOrderRec."Lot No.";

                    IsInsertSortation := true;
                end;
            end;
        end else if (SORStep_Step = SORStep_Step::"4") AND (SortProdOrderRec."Tobacco Type" = SortProdOrderRec."Tobacco Type"::Filler) then begin
            // SORTATION FILLER SECTION
            if IJLEntryType = IJLEntryType::Consumption then begin
                ProdOrderRec.SetRange("No.", SortProdOrderRec."Sortation Prod. Order No.");
                if ProdOrderRec.FindFirst() then begin
                    if Item.Get(ProdOrdComp."Item No.") then begin // At this moment, the record is related to the FILLER Item
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
                        tempItemJnlLine.Validate("Order Line No.", PrOL."Line No."); // Doesn't related to the Chosen Item
                        tempItemJnlLine.Validate("Item No.", Item."No.");
                        tempItemJnlLine.Description := Item.Description;
                        tempItemJnlLine.Validate("Variant Code", SortProdOrderRec."Unsorted Variant Code");
                        tempItemJnlLine.Validate("Location Code", PrOL."Location Code");
                        tempItemJnlLine."Work Shift Code" := SortProdOrderRec."Work Shift Code";
                        tempItemJnlLine.Validate("Quantity", SortProdOrderRec.Quantity);
                        tempItemJnlLine.Validate("Unit of Measure Code", SortProdOrderRec."Unit of Measure Code");
                        tempItemJnlLine.Validate("Bin Code", SortProdOrderRec."From Bin Code");
                        // tempItemJnlLine."Bin Code" := SortProdOrderRec."To Bin Code";
                        tempItemJnlLine.Validate("Lot No.", SortProdOrderRec."Lot No.");
                    end;
                end;
            end else begin
                ProdOrderRec.SetRange("No.", SortProdOrderRec."Sortation Prod. Order No.");
                if ProdOrderRec.FindFirst() then begin
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
                    tempItemJnlLine.Validate("Operation No.", PrORL."Operation No.");
                    tempItemJnlLine."Work Shift Code" := SortProdOrderRec."Work Shift Code";
                    tempItemJnlLine.Validate("Bin Code", SortProdOrderRec."To Bin Code");
                    if SortProdOrderRec."Package No." <> '' then
                        tempItemJnlLine.Validate("Package No.", SortProdOrderRec."Package No.")
                    else begin
                        Validate_TestInsertItemJnlLine_ITEMPMP04PackageNos(NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos"), Item."No.");
                        if NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos") <> '' then
                            if ProdOrderRec."PMP15 Crop" = 0 then begin
                                SORCrop := Date2DMY(WorkDate(), 3);
                                SORPackageNo := COPYSTR(Format(SORCrop), STRLEN(Format(SORCrop)) - 1, 2) + NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos");
                            end else
                                SORPackageNo := COPYSTR(Format(ProdOrderRec."PMP15 Crop"), STRLEN(Format(ProdOrderRec."PMP15 Crop")) - 1, 2) + NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos");
                        tempItemJnlLine.Validate("Package No.", SORPackageNo);
                    end;
                    tempItemJnlLine."Lot No." := SortProdOrderRec."Lot No.";
                    IsInsertSortation := true;
                end;
            end;
        end else if (SORStep_Step = SORStep_Step::"4") AND (SortProdOrderRec."Variant Changes" <> '') then begin
            // SORTATION PRODUCTION ORDER - VARIANT CHANGES SECTION
            if IJLEntryType = IJLEntryType::Consumption then begin
                ProdOrderRec.SetRange("No.", SortProdOrderRec."Sortation Prod. Order No.");
                if ProdOrderRec.FindFirst() then begin
                    if Item.Get(ProdOrdComp."Item No.") then begin // At this moment, the record is related to the FILLER Item
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
                        tempItemJnlLine.Validate("Item No.", Item."No.");
                        tempItemJnlLine.Description := Item.Description;
                        tempItemJnlLine.Validate("Variant Code", SortProdOrderRec."Unsorted Variant Code");
                        tempItemJnlLine.Validate("Location Code", PrOL."Location Code");
                        tempItemJnlLine."Work Shift Code" := SortProdOrderRec."Work Shift Code";
                        tempItemJnlLine.Validate("Quantity", SortProdOrderRec.Quantity);
                        tempItemJnlLine.Validate("Unit of Measure Code", SortProdOrderRec."Unit of Measure Code");
                        tempItemJnlLine.Validate("Bin Code", SortProdOrderRec."From Bin Code");
                        // tempItemJnlLine."Bin Code" := SortProdOrderRec."To Bin Code";
                        tempItemJnlLine.Validate("Lot No.", SortProdOrderRec."Lot No.");
                    end;
                end;
            end else begin
                ProdOrderRec.SetRange("No.", SortProdOrderRec."Sortation Prod. Order No.");
                if ProdOrderRec.FindFirst() then begin
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
                    tempItemJnlLine.Validate("Operation No.", PrORL."Operation No.");
                    tempItemJnlLine."Work Shift Code" := SortProdOrderRec."Work Shift Code";
                    tempItemJnlLine.Validate("Bin Code", SortProdOrderRec."To Bin Code");
                    if SortProdOrderRec."Package No." <> '' then
                        tempItemJnlLine.Validate("Package No.", SortProdOrderRec."Package No.")
                    else begin
                        Validate_TestInsertItemJnlLine_ITEMPMP04PackageNos(NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos"), Item."No.");
                        if NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos") <> '' then
                            if ProdOrderRec."PMP15 Crop" = 0 then begin
                                SORCrop := Date2DMY(WorkDate(), 3);
                                SORPackageNo := COPYSTR(Format(SORCrop), STRLEN(Format(SORCrop)) - 1, 2) + NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos");
                            end else
                                SORPackageNo := COPYSTR(Format(ProdOrderRec."PMP15 Crop"), STRLEN(Format(ProdOrderRec."PMP15 Crop")) - 1, 2) + NoSeriesMgmt.GetLastNoUsed(Item."PMP04 Package Nos");
                        tempItemJnlLine.Validate("Package No.", SORPackageNo);
                    end;
                    tempItemJnlLine."Lot No." := SortProdOrderRec."Lot No.";
                    IsInsertSortation := true;
                end;
            end;
        end;

        if IsInsertSortation then begin
            tempItemJnlLine."PMP15 Prod. Order No." := SortProdOrderRec."Sortation Prod. Order No.";
            tempItemJnlLine."PMP15 Production Type" := tempItemJnlLine."PMP15 Production Type"::"SOR-Sortation";
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

            if SortProdOrderRec."Package No." = '' then begin
                SortProdOrderRec."Package No." := tempItemJnlLine."Package No.";
            end;

            if tempItemJnlLine.Insert() then
                exit(true)
            else
                exit(false);
        end;
    end;

    // Creates and inserts a Reservation Entry from temporary tracking and journal line data based on sortation and tracking specifications.
    local procedure InsertReservEntryRecfromTempTrackSpecIJL(var RecReservEntry: Record "Reservation Entry"; var TempTrackingSpecification: Record "Tracking Specification" temporary; var RecItemJnlLine: Record "Item Journal Line"; SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary; SerLotPkgArr: array[3] of Code[50])
    var
        ItemTrackingSetup: Record "Item Tracking Setup";
    begin
        ItemTrackingSetup.CopyTrackingFromItemJnlLine(RecItemJnlLine);
        ItemJnlLineReserve.InitFromItemJnlLine(TempTrackingSpecification, RecItemJnlLine);
        TempTrackingSpecification.CopyTrackingFromItemTrackingSetup(ItemTrackingSetup);
        TempTrackingSpecification."Entry No." := NextTrackingSpecEntryNo;
        if (SortProdOrderRec."SORStep Step" = SortProdOrderRec."SORStep Step"::"1") AND (SortProdOrderRec."SORStep Step" = SortProdOrderRec."SORStep Step"::"2") AND (SortProdOrderRec."SORStep Step" = SortProdOrderRec."SORStep Step"::"3") then begin
            TempTrackingSpecification.Validate("Bin Code", RecItemJnlLine."Bin Code");
            TempTrackingSpecification.Validate("Lot No.", RecItemJnlLine."Lot No.");
            TempTrackingSpecification.Validate("Serial No.", SerLotPkgArr[1]);
            TempTrackingSpecification.Validate("New Lot No.", SerLotPkgArr[2]);
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
        TempTrackingSpecification."Expiration Date" := RecItemJnlLine."Expiration Date";
        TempTrackingSpecification."Warranty Date" := RecItemJnlLine."Warranty Date";
        TempTrackingSpecification."Creation Date" := Today();
        TempTrackingSpecification.Insert();

        CreateReservEntryFrom(RecReservEntry, TempTrackingSpecification);
        RecReservEntry."Entry No." := NextReservEntryNo;

        if (RecItemJnlLine."Entry Type" = RecItemJnlLine."Entry Type"::Transfer) then begin
            RecReservEntry.Positive := true;
            RecReservEntry.Validate("Quantity (Base)", RecReservEntry."Quantity (Base)" * -1);
            RecReservEntry."Reservation Status" := RecReservEntry."Reservation Status"::Prospect;
            RecReservEntry."New Lot No." := SortProdOrderRec."Lot No.";
        end else if (RecItemJnlLine."Entry Type" = RecItemJnlLine."Entry Type"::Output) then begin
            RecReservEntry.Positive := false;
            RecReservEntry."Reservation Status" := RecReservEntry."Reservation Status"::Prospect;
        end else if (RecItemJnlLine."Entry Type" = RecItemJnlLine."Entry Type"::Consumption) then begin
            RecReservEntry.Validate("Quantity (Base)", RecReservEntry."Quantity (Base)" * -1);
            RecReservEntry.Positive := false;
            RecReservEntry."Reservation Status" := RecReservEntry."Reservation Status"::Prospect;
        end;

        RecReservEntry.Insert();
    end;

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
        TempGlobalEntrySummary.SetFilter("Lot No.", RecItemJnlLine."Lot No.");
        TempGlobalEntrySummary.SetFilter("Package No.", RecItemJnlLine."Package No.");
        if TempGlobalEntrySummary.FindSet() then begin
            SerLotPkgArr[1] := TempGlobalEntrySummary."Serial No.";
            SerLotPkgArr[2] := TempGlobalEntrySummary."Lot No.";
            SerLotPkgArr[3] := TempGlobalEntrySummary."Package No.";
            InsertReservEntryRecfromTempTrackSpecIJL(RecReservEntry, TempTrackingSpecification, RecItemJnlLine, SortProdOrderRec, SerLotPkgArr);
        end else begin
            PackageNoInfo.SetAutoCalcFields();
            PackageNoInfo.SetRange("Item No.", RecItemJnlLine."Item No.");
            PackageNoInfo.SetFilter("Variant Code", RecItemJnlLine."Variant Code");
            PackageNoInfo.SetFilter("PMP04 Bin Code", RecItemJnlLine."Bin Code");
            PackageNoInfo.SetRange(Inventory, 0);
            if PackageNoInfo.FindFirst() then begin
                SerLotPkgArr[1] := PackageNoInfo."PMP04 Bin Code";
                SerLotPkgArr[2] := PackageNoInfo."PMP04 Lot No.";
                SerLotPkgArr[3] := PackageNoInfo."Package No.";
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

    // Determines and assigns the appropriate item tracking type to the reservation entry based on the presence of lot, serial, and package numbers.
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
        IJL: Record "Item Journal Line";
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
                            ItemJnlLine."Document No." := NoSeriesBatchMgmt.GetNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
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
                                            ItemJnlLine."Document No." := NoSeriesBatchMgmt.GetNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                                        end;
                                    end;
                                end else begin
                                    ItemJnlLine.Init();
                                    ItemJnlLine := tempItemJnlLine;
                                    if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template", ExtCompanySetup."PMP15 SOR Output Jnl. Batch") then begin
                                        if ItemJnlBatch."No. Series" <> '' then begin
                                            ItemJnlLine."Document No." := NoSeriesBatchMgmt.GetNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
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
                                            ItemJnlLine."Document No." := NoSeriesBatchMgmt.GetNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                                        end;
                                    end;
                                end else begin
                                    ItemJnlLine.Init();
                                    ItemJnlLine := tempItemJnlLine;
                                    if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template", ExtCompanySetup."PMP15 SOR Output Jnl. Batch") then begin
                                        if ItemJnlBatch."No. Series" <> '' then begin
                                            ItemJnlLine."Document No." := NoSeriesBatchMgmt.GetNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
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
                                            ItemJnlLine."Document No." := NoSeriesBatchMgmt.GetNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                                        end;
                                    end;
                                end else begin
                                    ItemJnlLine.Init();
                                    ItemJnlLine := tempItemJnlLine;
                                    if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template", ExtCompanySetup."PMP15 SOR Output Jnl. Batch") then begin
                                        if ItemJnlBatch."No. Series" <> '' then begin
                                            ItemJnlLine."Document No." := NoSeriesBatchMgmt.GetNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
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
                                ItemJnlLine."Document No." := NoSeriesBatchMgmt.GetNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                            end;
                        end;
                    end else begin
                        ItemJnlLine.Init();
                        ItemJnlLine := tempItemJnlLine;
                        if ItemJnlBatch.Get(ExtCompanySetup."PMP15 SOR Output Jnl. Template", ExtCompanySetup."PMP15 SOR Output Jnl. Batch") then begin
                            if ItemJnlBatch."No. Series" <> '' then begin
                                ItemJnlLine."Document No." := NoSeriesBatchMgmt.GetNextNo(ItemJnlBatch."No. Series", SortProdOrderRec."Posting Date");
                            end;
                        end;
                    end;
                end;

        end;
        ItemJnlLine.Insert();
    end;

    /// <summary>Inserts a new Sortation Detail Result record based on the Item Journal Line and validates its relationship to the Sortation Production Order.</summary>
    /// <remarks>Also checks package information eligibility for sale and updates related Package No. Information fields accordingly.</remarks>
    /// <param name="ItemJnlLine">Item Journal Line record containing item and tracking details.</param>
    /// <param name="SortProdOrderRec">Temporary Sortation Production Order record for validation and linkage.</param>
    procedure InsertSORDetailResultfromItemJnlLine(var ItemJnlLine: Record "Item Journal Line"; SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary)
    var
        SORProdOrdDetLine: Record "PMP15 Sortation Detail Quality";
    begin
        SORProdOrdDetLine.Init();
        SORProdOrdDetLine.Validate("Item No.", ItemJnlLine."Item No.");
        SORProdOrdDetLine.Validate("Variant Code", ItemJnlLine."Variant Code");
        SORProdOrdDetLine.Validate("Package No.", ItemJnlLine."Package No.");
        SORProdOrdDetLine.Validate("Lot No.", ItemJnlLine."Lot No.");
        SORProdOrdDetLine.Validate("Sub Merk 1", ItemJnlLine."PMP15 Sub Merk 1");
        SORProdOrdDetLine.Validate("Sub Merk 2", ItemJnlLine."PMP15 Sub Merk 2");
        SORProdOrdDetLine.Validate("Sub Merk 3", ItemJnlLine."PMP15 Sub Merk 3");
        SORProdOrdDetLine.Validate("Sub Merk 4", ItemJnlLine."PMP15 Sub Merk 4");
        SORProdOrdDetLine.Validate("Sub Merk 5", ItemJnlLine."PMP15 Sub Merk 5");
        SORProdOrdDetLine.Validate("L/R", ItemJnlLine."PMP15 L/R");
        SORProdOrdDetLine.Validate(Quantity, ItemJnlLine.Quantity);
        SORProdOrdDetLine.Validate("Unit of Measure Code", ItemJnlLine."Unit of Measure Code");
        SORProdOrdDetLine.Validate(Rework, ItemJnlLine."PMP15 Rework");
        SORProdOrdDetLine.Validate("Tobacco Type", ItemJnlLine."PMP15 Tobacco Type");
        SORProdOrdDetLine.Insert();
        Commit();

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
        Submerk1Rec: Record "PMP15 Sub Merk 1";
        Submerk2Rec: Record "PMP15 Sub Merk 2";
        Submerk3Rec: Record "PMP15 Sub Merk 3";
        Submerk4Rec: Record "PMP15 Sub Merk 4";
        Submerk5Rec: Record "PMP15 Sub Merk 5";
        SubmerkGroups, SubmerkCodes : array[5] of Code[50];
        IsAbletoSell, IsMixed : Boolean;
        BiggestCode, SmallestCode : Integer;
    begin
        Submerk2Rec.Reset();
        Submerk3Rec.Reset();
        Submerk4Rec.Reset();
        Submerk5Rec.Reset();
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
            GetSubmerkGROUPfromSORPrdOrdDetLine(SubmerkGroups, SORProdOrdDetLine); // To be used in "IS ABLE TO SELL" region
            #region IS ABLE TO SELL
            // If there is combination of Sub Merk 2 & Sub Merk 3 on SDR that has different Group (Group field is available on Sub Merk 3 Table) then field able to sell on PANI will be false.
            IsAbletoSell := SubmerkGroups[2] = SubmerkGroups[3];

            // Then check combination of Sub Merk 4 on SDR if there is SDR that has different Group (Group field is available on Sub Merk 4 table) then field able to sell on PANI will be false.
            if IsAbletoSell then begin
                IsAbletoSell := IsAbletoSell AND
                    (SubmerkGroups[3] = SubmerkGroups[4]) AND
                    (SubmerkGroups[2] = SubmerkGroups[4]);
            end;

            // Then check combination of Sub Merk 5 on Sortation Detail Result if the biggest - the lowest > 1 then field able to sell on Package No. Information will be false.
            if IsAbletoSell then begin
                SDR.SetCurrentKey("Sub Merk 5", "Item No.", "Variant Code", "Package No.");
                SDR.SetRange("Item No.", PkgNoInfoList."Item No.");
                SDR.SetRange("Variant Code", PkgNoInfoList."Variant Code");
                SDR.SetRange("Package No.", PkgNoInfoList."Package No.");
                SDR.SetAscending("Sub Merk 5", true);
                if SDR.FindLast() then
                    SetSubmerkCodes(SubmerkCodes, SDR."Sub Merk 1", SDR."Sub Merk 2", SDR."Sub Merk 3", SDR."Sub Merk 4", SDR."Sub Merk 5");
                GetMinMaxSubMerkFromList(SubmerkCodes, SmallestCode, BiggestCode);
                IsAbletoSell := IsAbletoSell AND ((BiggestCode - SmallestCode) > 1);
            end;

            // If not, then check total quantity on Sortation Detail Result >= 35 if yes then set field able to sell on Package No. Information to True. If not, then set to False.
            if IsAbletoSell then begin
                SDR.Reset();
                SDR.SetRange("Item No.", PkgNoInfoList."Item No.");
                SDR.SetRange("Variant Code", PkgNoInfoList."Variant Code");
                SDR.SetRange("Package No.", PkgNoInfoList."Package No.");
                IsAbletoSell := IsAbletoSell AND CheckQtySDRIsBiggerThan(SDR, 35);
            end;
            #endregion IS ABLE TO SELL

            #region MIXED
            // b) If there is different of Sub Merk 1, Sub Merk 2, Sub Merk 3, Sub Merk 4, Sub Merk 5 on Sortation Detail Result then set field Mixed to be True. If all the same then set field Mixed to be False
            if SDR.FindSet() then
                repeat
                    if (SDR."Sub Merk 1" <> SDR."Sub Merk 1") or
                    (SDR."Sub Merk 2" <> SDR."Sub Merk 2") or
                    (SDR."Sub Merk 3" <> SDR."Sub Merk 3") or
                    (SDR."Sub Merk 4" <> SDR."Sub Merk 4") or
                    (SDR."Sub Merk 5" <> SDR."Sub Merk 5") then begin
                        IsMixed := true;
                    end;
                until (SDR.Next() = 0) OR IsMixed;
            #endregion MIXED

            Clear(SubmerkCodes);
            GetSubmerkforBiggestRank(SubmerkCodes, PkgNoInfoList."Item No.", PkgNoInfoList."Variant Code", PkgNoInfoList."Package No.");

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
        ProdOrdLine2.Validate("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
        ProdOrdLine2.Validate("Line No.", LastLineNo);
        ProdOrdLine2.Validate("Item No.", CHOSENItem."Item No.");
        ProdOrdLine2.Validate("Variant Code", CHOSENItem."Variant Code");
        ProdOrdLine2.Validate("Location Code", ProdOrdLine."Location Code");
        ProdOrdLine2.Validate("Bin Code", ProdOrdLine."Bin Code");
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
        ProdOrdLine2.Validate("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
        ProdOrdLine2.Validate("Line No.", LastLineNo);
        ProdOrdLine2.Validate("Item No.", SortProdOrderRec."Sorted Item No.");
        ProdOrdLine2.Validate("Variant Code", SortProdOrderRec."Variant Changes");
        ProdOrdLine2.Validate("Location Code", ProdOrdLine."Location Code");
        ProdOrdLine2.Validate("Bin Code", ProdOrdLine."Bin Code");
        ProdOrdLine2.Validate(Quantity, SortProdOrderRec.Quantity);
        ProdOrdLine2.Validate("Unit of Measure Code", SortProdOrderRec."Unit of Measure Code");
        ProdOrdLine2.Validate("Routing No.", ProdOrdLine."Routing No.");
        ProdOrdLine2.Insert();
    end;

    /// <summary>Creates a new Production Order Routing Line from an existing Production Order Line.</summary>
    /// <remarks> Initializes and inserts a routing line linked to the source production order line with zeroed time values. </remarks>
    /// <param name="ProdOrdRoutLine">The production order routing line to be created and inserted.</param>
    /// <param name="ProdOrdLine">The reference production order line providing base data.</param>
    procedure CreateNEwProdOrdRoutingLinefromProdOrdLine(var ProdOrdRoutLine: Record "Prod. Order Routing Line"; ProdOrdLine: Record "Prod. Order Line")
    begin
        ProdOrdRoutLine.Init();
        // ProdOrdRoutLine.Validate(Status, ProdOrdLine.Status);
        ProdOrdRoutLine.Validate("Prod. Order No.", ProdOrdLine."Prod. Order No.");
        ProdOrdRoutLine.Validate("Run Time", 0);
        ProdOrdRoutLine.Validate("Setup Time", 0);
        ProdOrdRoutLine.Validate("Wait Time", 0);
        ProdOrdRoutLine.Validate("Move Time", 0);
        ProdOrdRoutLine.Insert();
    end;

    // Checks if an existing Assembly Order with matching item, variant, location, date, and production details already exists, returning true if found.
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

    /// <summary>Processes and posts a Sortation Production Order recording according to the specified Sortation Step.</summary>
    /// <remarks>This procedure orchestrates end-to-end handling of a single Sortation Production Order record for the provided step. Behaviour per step: Step "0" creates an Assembly Order and associated lines, generates reservations and tracking, and posts the assembly; Steps "1"–"3" prepare and post item reclassification journals; Step "4" handles output and consumption journals and additional logic for tobacco types (Wrapper, PW, Filler or variant-changed items), including creation of production order lines/routings when required. The procedure performs data lookups, validation, temporary record preparation, insert/commit operations, posting via codeunits/pages, and raises descriptive errors on validation or processing failures. It depends on company setup configuration and multiple helper procedures (for creating assembly records, generating journals, posting routines, and creating SOR detail results). Side effects include inserts, modifications, journal postings, commits, user messages and error conditions; callers should ensure transactional expectations and handle exceptions as appropriate.</remarks>
    /// <param name="ProdOrder">The Production Order record that is the source or target of the sortation processing.</param>
    /// <param name="SortProdOrderRec">Temporary PMP15 Sortation Production Order Recording that contains the sortation details to be processed.</param>
    /// <param name="SORStep_Step">The Sortation Step Enum value indicating which processing branch to execute.</param>
    procedure SortProdOrdRecordingPost(var ProdOrder: Record "Production Order"; SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary; SORStep_Step: Enum "PMP15 Sortation Step Enum")
    var
        // PkgNoRec: Record "Package No. Information";
        SORStepEnum: Enum "PMP15 Sortation Step Enum";
        ExtCompanySetup: Record "PMP07 Extended Company Setup";
        AssemblyHeader: Record "Assembly Header";       // ASSEMBLY
        AssemblyLine: Record "Assembly Line";           // ASSEMBLY
        tempItemJnlLine: Record "Item Journal Line" temporary;  // ITEM JOURNAL LINE
        ItemJnlLine: Record "Item Journal Line";                // ITEM JOURNAL LINE
        ItemJnlLine2: Record "Item Journal Line";
        ProdOrdLine: Record "Prod. Order Line";         // PRODUCTION ORDER LINE
        ProdOrdLine2: Record "Prod. Order Line";         // ------ IDEN ------
        ProdOrdComp: Record "Prod. Order Component";    // PRODUCTION ORDER COMPONENT LINE
        PWItem: Record "Prod. Order Component";    // PW ITEM
        FILLERItem: Record "Prod. Order Component";    // FILLER ITEM
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
                    GetProdOrderCropfromPkgNoInfo(ProdOrder, SortProdOrderRec."Package No.");
                    CreateAssemblyHeadfromSORRecording(AssemblyHeader, ProdOrder, SortProdOrderRec, SORStep_Step);
                    if not IsASOFoundExisting(AssemblyHeader) then begin
                        CreateAssemblyLinefromSORRecording(AssemblyLine, AssemblyHeader, ProdOrder, SortProdOrderRec);

                        GenerateItemReservEntryAssemblyHeader(AssemblyHeader, ProdOrder, SortProdOrderRec);
                        GenerateItemTrackingAssemblyLine(AssemblyHeader, ProdOrder, SortProdOrderRec);
                        Commit();
                    end;

                    if CODEUNIT.Run(CODEUNIT::"Assembly-Post", AssemblyHeader) then
                        Message('The sortation production order posting in the %1-Step for Assembly Item %2  is successfully posted.', SORStep_Step, SortProdOrderRec."Unsorted Item No.")
                    else
                        Message('The sortation production order posting in the %1-Step for Assembly Item %2  is failed to posting.', SORStep_Step, SortProdOrderRec."Unsorted Item No.");
                end;
            SORStep_Step::"1", SORStep_Step::"2", SORStep_Step::"3":
                begin
                    ItemJnlLine.SetRange("Journal Template Name", ExtCompanySetup."PMP15SORItemReclass.Jnl.Tmpt.");
                    ItemJnlLine.SetRange("Journal Batch Name", ExtCompanySetup."PMP15SORItemReclass.Jnl.Batch");
                    if ItemJnlLine.FindLast() OR (ItemJnlLine.Count = 0) then begin // As Validation before insertion
                        IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step);
                    end;
                    if IsSuccessInsertItemJnlLine then begin
                        InsertItemJnlLinefromTemp(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step);
                        GenerateRecReserveEntryItemJnlLine(ItemJnlLine, SortProdOrderRec);
                        Commit();
                    end;
                    PostItemReclassJnlSOR(ItemJnlLine, SortProdOrderRec);
                end;
            SORStep_Step::"4":
                begin
                    case SortProdOrderRec."Tobacco Type" of
                        SortProdOrderRec."Tobacco Type"::Wrapper:
                            begin
                                // // OUTPUT JOURNAL
                                ItemJnlLine.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Output Jnl. Template");
                                ItemJnlLine.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Output Jnl. Batch");
                                if ItemJnlLine.FindLast() OR (ItemJnlLine.Count = 0) then begin // As Validation before insertion
                                    IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step);
                                end;
                                if IsSuccessInsertItemJnlLine then begin
                                    ItemJnlLine.Reset();
                                    InsertItemJnlLinefromTemp(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step);
                                    GenerateRecReserveEntryItemJnlLine(ItemJnlLine, SortProdOrderRec);
                                    Commit();
                                    ItemJnlLine2 := ItemJnlLine;
                                    ItemJnlLine.PostingItemJnlFromProduction(false);
                                    InsertSORDetailResultfromItemJnlLine(ItemJnlLine2, SortProdOrderRec);

                                    Clear(IsSuccessInsertItemJnlLine);
                                    ItemJnlLine2.Reset();
                                    tempItemJnlLine.DeleteAll();
                                end else
                                    Error('Failed to creating the Output Journal before posting.');

                                // CONSUMPTION JOURNAL
                                ItemJnlLine2.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Template");
                                ItemJnlLine2.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch");
                                if ItemJnlLine2.FindLast() OR (ItemJnlLine2.Count = 0) then begin // As Validation before insertion
                                    IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine2, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine2."Entry Type"::Consumption);
                                end;
                                if IsSuccessInsertItemJnlLine then begin
                                    ItemJnlLine2.Reset();
                                    InsertItemJnlLinefromTemp(ItemJnlLine2, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine2."Entry Type"::Consumption);
                                    GenerateRecReserveEntryItemJnlLine(ItemJnlLine2, SortProdOrderRec);
                                    Commit();
                                    ItemJnlLine2.PostingItemJnlFromProduction(false);
                                    Message('The sortation production order posting in the %1-th Step for %2 Tobacco Type is successfully posted.', SORStep_Step, SortProdOrderRec."Tobacco Type");
                                end else
                                    Error('Failed to creating the Consumption Journal after posting the Output Journal.');
                            end;
                        SortProdOrderRec."Tobacco Type"::PW:
                            begin
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
                                            if Item.Get(ProdOrdComp."Item No.") then begin
                                                if (Item."PMP04 Item Group" = ItemProdType."Item Group") and (Item."Item Category Code" = ItemProdType."Item Category Code") and (Item."PMP04 Item Class L1" = ItemProdType."Item Class L1") and (Item."PMP04 Item Class L2" = ItemProdType."Item Class L2") and (Item."PMP04 Item Type L1" = ItemProdType."Item Type L1") and (Item."PMP04 Item Type L2" = ItemProdType."Item Type L2") and (Item."PMP04 Item Type L3" = ItemProdType."Item Type L3") then begin
                                                    PWItem := ProdOrdComp;
                                                    IsPWItemFound := true;
                                                end;
                                            end;
                                        until (ProdOrdComp.Next() = 0) OR IsPWItemFound;
                                end;

                                if IsPWItemFound then begin
                                    ProdOrdLine2.SetRange("Prod. Order No.", SortProdOrderRec."Sortation Prod. Order No.");
                                    ProdOrdLine2.SetRange("Item No.", PWItem."Item No.");
                                    ProdOrdLine2.SetRange("Variant Code", PWItem."Variant Code");
                                    if ProdOrdLine2.FindFirst() then begin
                                        // If found then go to step 5)
                                    end else begin
                                        // If not found then go to step 3)
                                        CreateNewSORProdOrdLine(ProdOrdLine2, SortProdOrderRec, PWItem, ProdOrdLine);
                                        CreateNEwProdOrdRoutingLinefromProdOrdLine(ProdOrdRoutLine, ProdOrdLine);
                                    end;
                                end else
                                    Error('Failed to identify a valid PW Item for the current Sortation process. Item : %1 (%2) | Production Order : %3 | Please ensure that the correct PW Item is configured in the Production Order Component lines and meets the required classification rules defined in the Item Production Type.', SortProdOrderRec."Sorted Item No.", SortProdOrderRec."Sorted Variant Code", SortProdOrderRec."Sortation Prod. Order No.");

                                // OUTPUT JOURNAL
                                ItemJnlLine.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Output Jnl. Template");
                                ItemJnlLine.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Output Jnl. Batch");
                                if ItemJnlLine.FindLast() OR (ItemJnlLine.Count = 0) then begin // As Validation before insertion
                                    IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine."Entry Type"::Output, ProdOrdLine, ProdOrdRoutLine, ProdOrdComp);
                                end;
                                if IsSuccessInsertItemJnlLine then begin
                                    ItemJnlLine.Reset();
                                    InsertItemJnlLinefromTemp(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step);
                                    GenerateRecReserveEntryItemJnlLine(ItemJnlLine, SortProdOrderRec);
                                    ItemJnlLine2 := ItemJnlLine;
                                    ItemJnlLine.PostingItemJnlFromProduction(false);
                                    InsertSORDetailResultfromItemJnlLine(ItemJnlLine2, SortProdOrderRec);

                                    Clear(IsSuccessInsertItemJnlLine);
                                    ItemJnlLine2.Reset();
                                    tempItemJnlLine.DeleteAll();
                                end else
                                    Error('Failed to creating the Output Journal before posting.');

                                // CONSUMPTION JOURNAL
                                ItemJnlLine2.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Template");
                                ItemJnlLine2.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch");
                                if ItemJnlLine2.FindLast() OR (ItemJnlLine2.Count = 0) then begin // As Validation before insertion
                                    IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine2, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine2."Entry Type"::Consumption);
                                end;
                                if IsSuccessInsertItemJnlLine then begin
                                    ItemJnlLine2.Reset();
                                    InsertItemJnlLinefromTemp(ItemJnlLine2, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine2."Entry Type"::Consumption);
                                    GenerateRecReserveEntryItemJnlLine(ItemJnlLine2, SortProdOrderRec);
                                    ItemJnlLine2.PostingItemJnlFromProduction(false);
                                    Message('The sortation production order posting in the %1-th Step for %2 Tobacco Type is successfully posted.', SORStep_Step, SortProdOrderRec."Tobacco Type");
                                end else
                                    Error('Failed to creating the Consumption Journal after posting the Output Journal.');
                            end;
                        SortProdOrderRec."Tobacco Type"::Filler:
                            begin
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
                                            if Item.Get(ProdOrdComp."Item No.") then begin
                                                if (Item."PMP04 Item Group" = ItemProdType."Item Group") and (Item."Item Category Code" = ItemProdType."Item Category Code") and (Item."PMP04 Item Class L1" = ItemProdType."Item Class L1") and (Item."PMP04 Item Class L2" = ItemProdType."Item Class L2") and (Item."PMP04 Item Type L1" = ItemProdType."Item Type L1") and (Item."PMP04 Item Type L2" = ItemProdType."Item Type L2") and (Item."PMP04 Item Type L3" = ItemProdType."Item Type L3") then begin
                                                    FILLERItem := ProdOrdComp;
                                                    IsFILLERItemFound := true;
                                                end;
                                            end;
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
                                        CreateNEwProdOrdRoutingLinefromProdOrdLine(ProdOrdRoutLine, ProdOrdLine);
                                    end;
                                end else
                                    Error('Failed to identify a valid Filler Item for the current Sortation process. Item : %1 (%2) | Production Order : %3 | Please ensure that the correct Filler Item is configured in the Production Order Component lines and meets the required classification rules defined in the Item Production Type.', SortProdOrderRec."Sorted Item No.", SortProdOrderRec."Sorted Variant Code", SortProdOrderRec."Sortation Prod. Order No.");

                                // OUTPUT JOURNAL
                                ItemJnlLine.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Output Jnl. Template");
                                ItemJnlLine.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Output Jnl. Batch");
                                if ItemJnlLine.FindLast() OR (ItemJnlLine.Count = 0) then begin // As Validation before insertion
                                    IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine."Entry Type"::Output, ProdOrdLine, ProdOrdRoutLine, FILLERItem);
                                end;
                                if IsSuccessInsertItemJnlLine then begin
                                    ItemJnlLine.Reset();
                                    InsertItemJnlLinefromTemp(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step);
                                    GenerateRecReserveEntryItemJnlLine(ItemJnlLine, SortProdOrderRec);
                                    ItemJnlLine2 := ItemJnlLine;
                                    ItemJnlLine.PostingItemJnlFromProduction(false);
                                    InsertSORDetailResultfromItemJnlLine(ItemJnlLine2, SortProdOrderRec);

                                    Clear(IsSuccessInsertItemJnlLine);
                                    ItemJnlLine2.Reset();
                                    tempItemJnlLine.DeleteAll();
                                end else
                                    Error('Failed to creating the Output Journal before posting.');

                                // CONSUMPTION JOURNAL
                                ItemJnlLine2.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Template");
                                ItemJnlLine2.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch");
                                if ItemJnlLine2.FindLast() OR (ItemJnlLine2.Count = 0) then begin // As Validation before insertion
                                    IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine2, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine2."Entry Type"::Consumption, ProdOrdLine2, ProdOrdRoutLine, ProdOrdComp);
                                end;
                                if IsSuccessInsertItemJnlLine then begin
                                    ItemJnlLine2.Reset();
                                    InsertItemJnlLinefromTemp(ItemJnlLine2, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine2."Entry Type"::Consumption);
                                    GenerateRecReserveEntryItemJnlLine(ItemJnlLine2, SortProdOrderRec);
                                    ItemJnlLine2.PostingItemJnlFromProduction(false);
                                    Message('The sortation production order posting in the %1-th Step for %2 Tobacco Type is successfully posted.', SORStep_Step, SortProdOrderRec."Tobacco Type");
                                end else
                                    Error('Failed to creating the Consumption Journal after posting the Output Journal.');
                            end;
                        // SortProdOrderRec."Tobacco Type"::"Raw Material":
                        //     begin
                        //         // 
                        //     end;
                        else
                            if (SORStep_Step = SORStep_Step::"4") AND (SortProdOrderRec."Variant Changes" <> '') then begin
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
                                        CreateNEwProdOrdRoutingLinefromProdOrdLine(ProdOrdRoutLine, ProdOrdLine);
                                    end;
                                end;

                                // OUTPUT JOURNAL
                                ItemJnlLine.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Output Jnl. Template");
                                ItemJnlLine.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Output Jnl. Batch");
                                if ItemJnlLine.FindLast() OR (ItemJnlLine.Count = 0) then begin // As Validation before insertion
                                    IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine."Entry Type"::Output, ProdOrdLine2, ProdOrdRoutLine, ProdOrdComp); // FYI, the Production Order Component is not utlized here, so just let it be here.
                                end;
                                if IsSuccessInsertItemJnlLine then begin
                                    ItemJnlLine.Reset();
                                    InsertItemJnlLinefromTemp(ItemJnlLine, tempItemJnlLine, SortProdOrderRec, SORStep_Step);
                                    GenerateRecReserveEntryItemJnlLine(ItemJnlLine, SortProdOrderRec);
                                    ItemJnlLine2 := ItemJnlLine;
                                    ItemJnlLine.PostingItemJnlFromProduction(false);
                                    InsertSORDetailResultfromItemJnlLine(ItemJnlLine2, SortProdOrderRec);

                                    Clear(IsSuccessInsertItemJnlLine);
                                    ItemJnlLine2.Reset();
                                    tempItemJnlLine.DeleteAll();
                                end else
                                    Error('Failed to creating the Output Journal before posting.');

                                // CONSUMPTION JOURNAL
                                ItemJnlLine2.SetRange("Journal Template Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Template");
                                ItemJnlLine2.SetRange("Journal Batch Name", ExtCompanySetup."PMP15 SOR Consum.Jnl. Batch");
                                if ItemJnlLine2.FindLast() OR (ItemJnlLine2.Count = 0) then begin // As Validation before insertion
                                    IsSuccessInsertItemJnlLine := Test_InsertItemJnlLine(ItemJnlLine2, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine2."Entry Type"::Consumption, ProdOrdLine2, ProdOrdRoutLine, ProdOrdComp);
                                end;
                                if IsSuccessInsertItemJnlLine then begin
                                    ItemJnlLine2.Reset();
                                    InsertItemJnlLinefromTemp(ItemJnlLine2, tempItemJnlLine, SortProdOrderRec, SORStep_Step, ItemJnlLine2."Entry Type"::Consumption);
                                    GenerateRecReserveEntryItemJnlLine(ItemJnlLine2, SortProdOrderRec);
                                    ItemJnlLine2.PostingItemJnlFromProduction(false);
                                    Message('The sortation production order posting in the %1-th Step for %2 Tobacco Type is successfully posted.', SORStep_Step, SortProdOrderRec."Tobacco Type");
                                end else
                                    Error('Failed to creating the Consumption Journal after posting the Output Journal.');
                            end;
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
    procedure PostItemReclassJnlSOR(var ItemJnlLine: Record "Item Journal Line"; SortProdOrderRec: Record "PMP15 Sortation PO Recording" temporary)
    var
        ItemJnlBatchPostMgmt: Codeunit "Item Jnl.-Post";
    begin
        if ItemJnlBatchPostMgmt.Run(ItemJnlLine) then
            Message('The Reclassification Journal is successfully posted.')
        else
            Message('The Reclassification failed to post the journal.');
    end;

    #endregion SOR RECORDING


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
    local procedure GetSORBinCodes(var SORBinCode: array[6] of Code[20])
    var
        Bins: Record Bin;
    begin
        Bins.Reset();
        Bins.SetRange("PMP15 Bin Type", Bins."PMP15 Bin Type"::"0");
        if Bins.FindFirst() then begin
            SORBinCode[1] := Bins.Code;
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
        Bins.SetRange("PMP15 Previous Bin", SORBinCode[1]);
        if Bins.FindFirst() then begin
            SORBinCode[6] := Bins.Code;
        end;
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

    // Retrieves and loads the location record corresponding to the provided location code, or clears it if the code is blank.
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

    // <summary>Retrieves the sub-merk group values from the specified Sortation Production Order Detail Line record.</summary>
    /// <remarks>This procedure extracts the group codes for each sub-merk level based on the provided Sortation Detail Quality record and assigns them to the corresponding array elements.</remarks>
    /// <param name="SubmerkGroup">An array that will store the resulting sub-merk group codes.</param>
    /// <param name="SORProdOrdDetLine">The Sortation Detail Quality record containing the sub-merk and tobacco type data used for group lookup.</param>
    procedure GetSubmerkGROUPfromSORPrdOrdDetLine(var SubmerkGroup: array[5] of Code[50]; SORProdOrdDetLine: Record "PMP15 Sortation Detail Quality")
    var
        Submerk2Rec: Record "PMP15 Sub Merk 2";
        Submerk3Rec: Record "PMP15 Sub Merk 3";
        Submerk4Rec: Record "PMP15 Sub Merk 4";
        Submerk5Rec: Record "PMP15 Sub Merk 5";
    begin
        Submerk2Rec.Reset();
        Submerk3Rec.Reset();
        Submerk4Rec.Reset();
        Submerk5Rec.Reset();

        SubmerkGroup[1] := SORProdOrdDetLine."Sub Merk 1";
        if Submerk2Rec.Get(SORProdOrdDetLine."Sub Merk 2", SORProdOrdDetLine."Tobacco Type") then
            SubmerkGroup[2] := Submerk2Rec.Group;
        if Submerk3Rec.Get(SORProdOrdDetLine."Sub Merk 3", SORProdOrdDetLine."Tobacco Type") then
            SubmerkGroup[3] := Submerk3Rec.Group;
        if Submerk4Rec.Get(SORProdOrdDetLine."Sub Merk 4") then
            SubmerkGroup[4] := Submerk4Rec.Group;
        if Submerk5Rec.Get(SORProdOrdDetLine."Sub Merk 5") then
            SubmerkGroup[5] := Submerk5Rec.Group;
    end;

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

    // Determines the minimum and maximum integer values converted from a list of sub-merk codes.
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

    // Assigns multiple sub-merk code values into the provided array in sequential order.
    local procedure SetSubmerkCodes(var SubmerkCodes: array[5] of Code[50]; Submerk1: Code[50]; Submerk2: Code[50]; Submerk3: Code[50]; Submerk4: Code[50]; Submerk5: Code[50])
    begin
        SubmerkCodes[1] := Submerk1;
        SubmerkCodes[2] := Submerk2;
        SubmerkCodes[3] := Submerk3;
        SubmerkCodes[4] := Submerk4;
        SubmerkCodes[5] := Submerk5;
    end;

    // Retrieves sub-merk codes corresponding to the record with the highest quantity for a given item, variant, and package number.
    local procedure GetSubmerkforBiggestRank(var SubmerkCodes: array[5] of Code[50]; ItemNo: Code[20]; VarCode: Code[50]; PkgNo: Code[50])
    var
        SDRQuery: Query "PMP15 SOR-Detail Result Pkg-No";
        MaxQty: Decimal;
    begin
        MaxQty := 0;
        SDRQuery.SetRange(SDRQuery.SDR_ItemNo, ItemNo);
        SDRQuery.SetFilter(SDRQuery.SDR_VariantCode, VarCode);
        SDRQuery.SetFilter(SDRQuery.SDR_PackageNo, PkgNo);
        SDRQuery.Open();
        while SDRQuery.Read() do begin
            if (SDRQuery.SDR_Quantity > MaxQty) AND ((SDRQuery.SDR_SubMerk2 <> '') OR (SDRQuery.SDR_SubMerk3 <> '')) then begin
                MaxQty := SDRQuery.SDR_Quantity;
                SubmerkCodes[1] := SDRQuery.SDR_SubMerk1;
                SubmerkCodes[2] := SDRQuery.SDR_SubMerk2;
                SubmerkCodes[3] := SDRQuery.SDR_SubMerk3;
                SubmerkCodes[4] := SDRQuery.SDR_SubMerk4;
                SubmerkCodes[5] := SDRQuery.SDR_SubMerk5;
            end;
        end;
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
    #endregion ERROR HELPER
    #endregion HELPER

}
