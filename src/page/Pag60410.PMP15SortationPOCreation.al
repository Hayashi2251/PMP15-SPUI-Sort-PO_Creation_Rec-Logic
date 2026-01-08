page 60410 "PMP15 Sortation PO Creation"
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
    Caption = 'Sortation Prod. Order Creation';
    PageType = NavigatePage;
    // PageType = Card;
    SourceTable = "PMP15 Sortation PO Creation";
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            group(Page01)
            {
                Caption = '';
                Visible = CurrentStep = 0;
                group(General)
                {
                    Caption = 'General';
                    field(Rework; Rec.Rework)
                    {
                        ApplicationArea = All;
                        Caption = 'Rework';
                        ToolTip = 'Specifies the value of the Rework field.', Comment = '%';
                    }
                    field("Sorted Item No."; Rec."Sorted Item No.")
                    {
                        ApplicationArea = All;
                        Caption = 'Sorted Item No.';
                        ToolTip = 'Specifies the value of the Sorted Item No. field.', Comment = '%';
                    }
                    field("Sorted Variant Code"; Rec."Sorted Variant Code")
                    {
                        ApplicationArea = All;
                        Caption = 'Sorted Variant Code';
                        ToolTip = 'Specifies the value of the Sorted Variant Code field.', Comment = '%';
                    }
                    field("Sorted Item Description"; Rec."Sorted Item Description")
                    {
                        ApplicationArea = All;
                        Caption = 'Sorted Item Description';
                        ToolTip = 'Specifies the value of the Sorted Item Description field.', Comment = '%';
                        Editable = false;
                    }
                    field("Unsorted Item No."; Rec."Unsorted Item No.")
                    {
                        ApplicationArea = All;
                        Caption = 'Unsorted Item No.';
                        ToolTip = 'Specifies the value of the Unsorted Item No. field.', Comment = '%';
                        Editable = false;
                        // trigger OnValidate()
                        // begin
                        //     Rec."Unsorted Variant Code" := '';
                        // end;
                    }
                    field("Unsorted Variant Code"; Rec."Unsorted Variant Code")
                    {
                        ApplicationArea = All;
                        Caption = 'Unsorted Variant No.';
                        ToolTip = 'Specifies the value of the Unsorted Variant Code field.', Comment = '%';
                        Editable = false;
                    }
                    field("Unsorted Item Description"; Rec."Unsorted Item Description")
                    {
                        ApplicationArea = All;
                        Editable = false;
                        Caption = 'Unsorted Item Description';
                        ToolTip = 'Specifies the value of the Unsorted Item Description field.', Comment = '%';
                    }
                    field("RM Item No."; Rec."RM Item No.")
                    {
                        ApplicationArea = All;
                        Caption = 'RM Item No.';
                        ToolTip = 'Specifies the value of the Raw Material Item No. field.', Comment = '%';
                        Editable = false;
                    }
                    field("RM Variant Code"; Rec."RM Variant Code")
                    {
                        ApplicationArea = All;
                        Caption = 'RM Variant No.';
                        ToolTip = 'Specifies the value of the Raw Material Variant Code field.', Comment = '%';
                        Editable = false;
                    }
                    field("RM Item Description"; Rec."RM Item Description")
                    {
                        ApplicationArea = All;
                        Caption = 'RM Item Description';
                        ToolTip = 'Specifies the value of the Raw Material Item Description field.', Comment = '%';
                        Editable = false;
                    }
                    field("Lot No."; Rec."Lot No.")
                    {
                        ApplicationArea = All;
                        Caption = 'Lot No.';
                        ToolTip = 'Specifies the value of the Lot No. field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            CurrPrevBinQuery: Query "PMP15 Curr & Prev Bin Query";
                            LotNosByBin: Query "Lot Numbers by Bin";
                            // BinRec: Record Bin;
                            TempLot: Record "Lot Bin Buffer" temporary;
                            LotPage: Page "PMP15 Lot No by Bin Factbox";
                            SelectionFilterManagement: Codeunit SelectionFilterManagement;
                            RecRef: RecordRef;
                            PrevBinCode: Code[20];
                            Count: Integer;
                        begin
                            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/06 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                            Clear(Rec."Lot No.");
                            Clear(PrevBinCode);

                            // Get the Bin first | Bin Code = Previous Bin Code that has SOR Bin Type: 0 in Table Bins where Location Code = Location Code
                            CurrPrevBinQuery.SetRange(CurrPrevBinQuery.CURR_LocationCode, ExtCompanySetup."PMP15 SOR Location Code");
                            CurrPrevBinQuery.SetRange(CurrPrevBinQuery.PREV_PMP15BinType, CurrPrevBinQuery.PREV_PMP15BinType::"0");
                            CurrPrevBinQuery.Open();
                            if CurrPrevBinQuery.Read() then begin
                                // Get the LotNosByBin
                                LotNosByBin.SetRange(Item_No, Rec."RM Item No.");
                                LotNosByBin.SetRange(Variant_Code, Rec."RM Variant Code");
                                LotNosByBin.SetRange(Location_Code, ExtCompanySetup."PMP15 SOR Location Code");
                                LotNosByBin.SetFilter(Lot_No, '<>%1', '');
                                LotNosByBin.Open();
                                TempLot.DeleteAll();
                                while LotNosByBin.Read do begin
                                    Count += 1;
                                    // BinRec.SetRange("Location Code", LotNosByBin.Location_Code);
                                    // BinRec.SetRange(Code, LotNosByBin.Bin_Code);
                                    // if BinRec.FindFirst() then begin
                                    // if BinRec."PMP15 Bin Type" = BinRec."PMP15 Bin Type"::"0" then begin
                                    TempLot.Init();
                                    TempLot."Item No." := LotNosByBin.Item_No;
                                    TempLot."Variant Code" := LotNosByBin.Variant_Code;
                                    TempLot."Zone Code" := LotNosByBin.Zone_Code;
                                    TempLot."Bin Code" := LotNosByBin.Bin_Code;
                                    TempLot."Location Code" := LotNosByBin.Location_Code;
                                    TempLot."Lot No." := LotNosByBin.Lot_No;
                                    if TempLot.Find() then begin
                                        TempLot."Qty. (Base)" += LotNosByBin.Sum_Qty_Base;
                                        TempLot.Modify();
                                    end else begin
                                        TempLot."Qty. (Base)" := LotNosByBin.Sum_Qty_Base;
                                        TempLot.Insert();
                                    end;
                                    // end;
                                    // end; // ending statement of BinRec
                                end;

                                LotNosByBin.Close();
                                if Count > 0 then begin
                                    if Page.RunModal(Page::"PMP15 Lot No by Bin Factbox", TempLot) = Action::LookupOK then begin
                                        Rec.Validate("Lot No.", TempLot."Lot No.");
                                        Rec.Validate(Quantity, TempLot."Qty. (Base)");
                                    end;
                                end else
                                    Message('There is No Lot No. found. for the "%1" with the variant of "%2", in the location of "%3" from the Bin Content.', Rec."Unsorted Item No.", Rec."Unsorted Variant Code", ExtCompanySetup."PMP15 SOR Location Code");
                            end;
                            CurrPrevBinQuery.Close();
                            //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/06 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
                        end;
                    }
                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/06 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                    field("PMP15 Allowance Packing Weight"; Rec."PMP15 Allowance Packing Weight")
                    {
                        ApplicationArea = All;
                        Caption = 'Allowance Packing Weight';
                        ToolTip = 'Specifies the value of the Allowance Packing Weight field.', Comment = '%';
                    }
                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/06 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
                    field("Tarre Weight (Kg)"; Rec."Tarre Weight (Kg)")
                    {
                        ApplicationArea = All;
                        Caption = 'Tarre Weight';
                        ToolTip = 'Specifies the value of the Tarre Weight (Kg) field.', Comment = '%';
                    }
                    field(Quantity; Rec.Quantity)
                    {
                        ApplicationArea = All;
                        Caption = 'Quantity';
                        ToolTip = 'Specifies the value of the Quantity field.', Comment = '%';
                    }
                    field("Unit of Measure Code"; Rec."Unit of Measure Code")
                    {
                        ApplicationArea = All;
                        Caption = 'Unit of Measure Code';
                        ToolTip = 'Specifies the value of the Unit of Measure Code field.', Comment = '%';
                        Editable = false;
                    }
                    field("Reference No."; Rec."Reference No.")
                    {
                        ApplicationArea = All;
                        Caption = 'Reference No.';
                        ToolTip = 'Specifies the value of the Reference No. field.', Comment = '%';
                    }

                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/06 - START >>>>>>>>>>>>>>>>>>>>>>>>>>}
                    field("PMP15 Item Owner Internal"; Rec."PMP15 Item Owner Internal")
                    {
                        ApplicationArea = All;
                        Caption = 'Item Owner Internal';
                        ToolTip = 'Specifies the value of the Item Owner Internal field.', Comment = '%';
                        Editable = false;
                        Visible = false;
                    }
                    //{<<<<<<<<<<<<<<<<<<<<<<<<<< PMP15 - SW - 2026/01/06 - FINISH >>>>>>>>>>>>>>>>>>>>>>>>>>}
                }
            }
        }
    }
    actions
    {
        // area(Processing)
        area(Navigation)
        {
            action(Post)
            {
                ApplicationArea = All;
                Caption = 'Create';
                Image = Post;
                // Visible = not IsSetRecfromProdOrder;
                InFooterBar = true;
                trigger OnAction()
                var
                begin
                    ProdOrder.Reset();
                    SortProdOrdMgmt.ValidateInputBeforePosting(Rec);
                    if SortProdOrdMgmt.SimulateInsertSuccess(tempProdOrder, Rec) then begin
                        SortProdOrdMgmt.SortProdOrdCreationPost(ProdOrder, tempProdOrder, Rec);
                    end;
                    SortProdOrdPageCard.SetRecord(ProdOrder);
                    SortProdOrdPageCard.Run();
                    CurrPage.Close();
                end;
            }
            action(Cancel)
            {
                ApplicationArea = All;
                Caption = 'Cancel';
                Image = Cancel;
                InFooterBar = true;
                trigger OnAction()
                begin
                    Rec.Delete();
                    CurrPage.Close();
                end;
            }
            action(Release)
            {
                ApplicationArea = All;
                Caption = 'Release';
                Image = ReleaseDoc;
                InFooterBar = true;
                Visible = Release_Visibility;
                trigger OnAction()
                begin
                    CurrPage.Update();
                    if (ProdOrder."No." <> '') then begin
                        Status := SortProdOrdMgmt.SortChangeProdOrderStatus(ProdOrder, NewStatus::Released, WorkDate(), true);
                        Message('The Production Order status has been successfully changed.');
                    end;
                end;
            }
            action(Completed)
            {
                ApplicationArea = All;
                Caption = 'Completed';
                Image = Completed;
                InFooterBar = true;
                Visible = Completed_Visibility;
                trigger OnAction()
                begin
                    SortProdOrdMgmt.SortProdOrdCreationCompleted(ProdOrder, InvDocHeader);
                end;
            }
        }
    }
    var
        tempProdOrder: Record "Production Order" temporary;
        PMPCodesOWNINT: Record "PMP04 PMP Codes";
        SORStep_Code: Code[50];

    protected var
        NoSeriesMgmt: Codeunit "No. Series";
        PMPAppLogicMgmt: Codeunit "PMP02 App Logic Management";
        SortProdOrdMgmt: Codeunit "PMP15 Sortation PO Mgmt";
        SortProdOrdPageCard: Page "PMP15 Sortation Prod. Order";
        ConfirmationPage: Page "PMP02 Confirmation Page";
        ProdOrder: Record "Production Order";
        ExtCompanySetup: Record "PMP07 Extended Company Setup";
        InvDocHeader: Record "Invt. Document Header";
        TarreWeight: Decimal;
        UoMCode: Code[10];
        CurrentStep: Integer;
        Status, NewStatus : Enum "Production Order Status";
        IsSetRecfromProdOrder, Release_Visibility, Completed_Visibility : Boolean;

    trigger OnOpenPage()
    var
        SORPOCreationRec: Record "PMP15 Sortation PO Creation";
    begin
        SORPOCreationRec.Reset();
        ExtCompanySetup.Get();
        PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Item Owner Internal"));
        PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 Sort-Prod. Order Nos."));
        PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Location Code"));

        if not IsSetRecfromProdOrder then begin
            Rec.Init();
            if SORPOCreationRec.FindLast() then begin
                Rec."Entry No." := SORPOCreationRec."Entry No." + 1;
            end else begin
                Rec."Entry No." := 1;
            end;
            Rec."PMP15 Item Owner Internal" := ExtCompanySetup."PMP15 SOR Item Owner Internal";
            Status := Status::"Firm Planned";
            Rec.Insert();
        end;

        Release_Visibility := ProdOrder."No." <> '';
        Completed_Visibility := ProdOrder."No." <> '';
    end;

    trigger OnClosePage()
    begin
        Clear(IsSetRecfromProdOrder);
        Clear(Status);
    end;

    /// <summary>Assigns the provided Production Order record to the internal variable.</summary>
    /// <param name="ProdOrderRec">Production Order record to be stored for later use.</param>
    procedure SetProdOrder(var ProdOrderRec: Record "Production Order")
    begin
        ProdOrder := ProdOrderRec;
    end;

    /// <summary>Initializes and inserts a new Sortation Production Order record based on data from a Production Order.</summary>
    /// <remarks>Copies key fields such as item, variant, lot number, quantity, and related unsorted component information from the given Production Order and inserts the resulting record.</remarks>
    /// <param name="ProdOrderRec">Production Order record used as the source for populating the new Sortation Production Order record.</param>
    procedure SetRecfromProdOrder(var ProdOrderRec: Record "Production Order")
    var
        ProdOrderComp: Record "Prod. Order Component";
    begin
        ProdOrderComp.Reset();
        Rec.Init();
        IsSetRecfromProdOrder := true;
        // 
        Status := ProdOrderRec.Status;
        Rec.Rework := ProdOrderRec."PMP15 SOR Rework";
        Rec.Validate("Sorted Item No.", ProdOrderRec."Source No.");
        Rec.Validate("Sorted Variant Code", ProdOrderRec."Variant Code");
        Rec.Validate("Lot No.", ProdOrderRec."PMP15 Lot No.");
        Rec.Quantity := ProdOrderRec.Quantity;
        Rec.Validate("Tarre Weight (Kg)", ProdOrderRec."PMP15 Tarre Weight (Kg)");
        Rec.Validate("Reference No.", ProdOrderRec."PMP15 Reference No.");
        // 
        ProdOrderComp.SetRange("Prod. Order No.", ProdOrderRec."No.");
        ProdOrderComp.SetRange("Variant Code", ProdOrderRec."Variant Code");
        ProdOrderComp.SetRange("PMP15 Unsorted Item", true);
        if ProdOrderComp.FindFirst() then begin
            Rec.Validate("Unsorted Item No.", ProdOrderComp."Item No.");
            Rec.Validate("Unsorted Variant Code", ProdOrderComp."Variant Code");
        end;
        Rec.Insert();
    end;
}
