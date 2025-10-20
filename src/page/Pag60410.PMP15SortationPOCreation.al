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
                    field("Sorted Item No."; Rec."Sorted Item No.")
                    {
                        ApplicationArea = All;
                        Caption = 'Sorted Item No.';
                        ToolTip = 'Specifies the value of the Sorted Item No. field.', Comment = '%';
                        trigger OnValidate()
                        begin
                            Rec."Sorted Variant Code" := '';
                        end;
                    }
                    field("Sorted Variant Code"; Rec."Sorted Variant Code")
                    {
                        ApplicationArea = All;
                        Caption = 'Inspection Packing List No.';
                        ToolTip = 'Specifies the value of the Sorted Variant Code field.', Comment = '%';
                    }
                    field("Sorted Item Description"; Rec."Sorted Item Description")
                    {
                        ApplicationArea = All;
                        Caption = 'Sorted Item Description';
                        ToolTip = 'Specifies the value of the Sorted Item Description field.', Comment = '%';
                        Editable = false;
                    }
                    field(Rework; Rec.Rework)
                    {
                        ApplicationArea = All;
                        Caption = 'Rework';
                        ToolTip = 'Specifies the value of the Rework field.', Comment = '%';
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
                        ToolTip = 'Specifies the value of the RM Item No. field.', Comment = '%';
                        Editable = false;
                    }
                    field("RM Variant Code"; Rec."RM Variant Code")
                    {
                        ApplicationArea = All;
                        Caption = 'RM Variant No.';
                        ToolTip = 'Specifies the value of the RM Variant Code field.', Comment = '%';
                        Editable = false;
                    }
                    field("RM Item Description"; Rec."RM Item Description")
                    {
                        ApplicationArea = All;
                        Caption = 'RM Item Description';
                        ToolTip = 'Specifies the value of the RM Item Description field.', Comment = '%';
                        Editable = false;
                    }
                    field("Lot No."; Rec."Lot No.")
                    {
                        ApplicationArea = All;
                        Caption = 'Lot No.';
                        ToolTip = 'Specifies the value of the Lot No. field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            BinRec: Record Bin;
                            TempLot: Record "Lot Bin Buffer" temporary;
                            LotPage: Page "PMP15 Lot No by Bin Factbox";
                            LotNosByBin: Query "Lot Numbers by Bin";
                            SelectionFilterManagement: Codeunit SelectionFilterManagement;
                            RecRef: RecordRef;
                            Count: Integer;
                        begin
                            Clear(Rec."Lot No.");
                            LotNosByBin.SetRange(Item_No, Rec."Unsorted Item No.");
                            LotNosByBin.SetRange(Variant_Code, Rec."Unsorted Variant Code");
                            LotNosByBin.SetRange(Location_Code, ExtCompanySetup."PMP15 SOR Location Code");
                            LotNosByBin.SetFilter(Lot_No, '<>%1', '');
                            LotNosByBin.Open();
                            TempLot.DeleteAll();
                            while LotNosByBin.Read do begin
                                Count += 1;
                                BinRec.SetRange("Location Code", LotNosByBin.Location_Code);
                                BinRec.SetRange(Code, LotNosByBin.Bin_Code);
                                if BinRec.FindFirst() then begin
                                    if BinRec."PMP15 Bin Type" = BinRec."PMP15 Bin Type"::"0" then begin
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
                                    end;
                                end;
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
                    }
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
                        // trigger OnLookup(var Text: Text): Boolean
                        // var
                        //     UoMRec: Record "Unit of Measure";
                        // begin
                        //     UoMRec.Reset();
                        //     if Page.RunModal(Page::"Units of Measure", UoMRec) = Action::LookupOK then
                        //         UoMCode := UoMRec.Code;
                        // end;
                    }
                    // field(Status; Status)
                    // {
                    //     ApplicationArea = All;
                    //     Caption = 'Status';
                    //     ToolTip = 'Specifies the value of the Production Order Status field.', Comment = '%';
                    //     Editable = false;
                    // }
                    field("Reference No."; Rec."Reference No.")
                    {
                        ApplicationArea = All;
                        Caption = 'Reference No.';
                        ToolTip = 'Specifies the value of the Reference No. field.', Comment = '%';
                    }
                    // field("PMP15 Item Owner Internal"; Rec."PMP15 Item Owner Internal")
                    // {
                    //     ApplicationArea = All;
                    //     Caption = 'Item Owner Internal';
                    // }
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
                    ProdOrderLine: Record "Prod. Order Line";
                    ProdOrderComp: Record "Prod. Order Component";
                begin
                    ProdOrder.Reset();
                    ProdOrderLine.Reset();
                    ProdOrderComp.Reset();
                    if Rec.Quantity = 0 then begin
                        Error('Quantity cannot be empty. Please select an existing unsorted Lot No. before creating a Sortation Production Order.');
                    end;
                    if SimulateInsertSuccess(tempProdOrder) then begin
                        ProdOrder.Init();
                        ProdOrder.Copy(tempProdOrder);
                        ProdOrder.Insert();
                        ProdOrder.Validate("Starting Date", WorkDate());
                        ProdOrder.Validate("Starting Date-Time", CurrentDateTime);
                        ProdOrder.Validate("Ending Date-Time", CurrentDateTime);
                        ProdOrder.Validate("Due Date", CalcDate('<+2D>', WorkDate()));
                        ProdOrder.Modify();
                        // ====================================================================
                        RefreshProdOrder.InitializeRequest(1, true, true, true, false);
                        RefreshProdOrder.SetHideValidationDialog(true);
                        RefreshProdOrder.Run();
                        // ====================================================================
                        ProdOrderLine.SetRange("Prod. Order No.", ProdOrder."No.");
                        ProdOrderLine.SetFilter("Item No.", '<>%1', '');
                        if ProdOrder."PMP15 SOR Rework" then begin
                            if ProdOrderLine.FindSet() then
                                repeat
                                    ProdOrderComp.SetRange("Prod. Order No.", ProdOrder."No.");
                                    ProdOrderComp.SetRange("Prod. Order Line No.", ProdOrderLine."Line No.");
                                    ProdOrderComp.SetRange("Variant Code", Rec."Unsorted Variant Code");
                                    ProdOrderComp.ModifyAll("PMP15 Unsorted Item", true);
                                    ProdOrderComp.SetRange("PMP15 Unsorted Item", true);
                                    ProdOrderComp.ModifyAll("Item No.", ProdOrderLine."Item No.");
                                    ProdOrderComp.ModifyAll("Quantity per", 1);
                                until ProdOrderLine.Next() = 0;
                        end else begin
                            if ProdOrderLine.FindFirst() then begin
                                ProdOrderComp.SetRange("Prod. Order No.", ProdOrder."No.");
                                ProdOrderComp.SetRange("Prod. Order Line No.", ProdOrderLine."Line No.");
                                ProdOrderComp.SetRange("Item No.", Rec."Unsorted Item No.");
                                ProdOrderComp.SetRange("Variant Code", Rec."Unsorted Variant Code");
                                ProdOrderComp.ModifyAll("PMP15 Unsorted Item", true);
                            end;
                        end;
                    end;
                    // CurrPage.Close();
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
            // action(Release)
            // {
            //     ApplicationArea = All;
            //     Caption = 'Release';
            //     Image = ReleaseDoc;
            //     trigger OnAction()
            //     begin
            //         CurrPage.Update();
            //         NewStatus := Status::Released;
            //         NewPostingDate := WorkDate();
            //         NewUpdateUnitCost := true;
            //         ProdOrderStatusMgmt.ChangeProdOrderStatus(ProdOrder, NewStatus, NewPostingDate, NewUpdateUnitCost);
            //         Commit();
            //         Status := ProdOrder.Status;
            //         Message('The Production Order status has been successfully changed.');
            //     end;
            // }
            // action(Completed)
            // {
            //     ApplicationArea = All;
            //     Caption = 'Completed';
            //     Image = Completed;
            //     trigger OnAction()
            //     begin
            //         // 
            //     end;
            // }
        }
        // area(Promoted)
        // {
        //     group(Category_Process)
        //     {
        //         actionref(Post_Promoted; Post) { }
        //         actionref(Release_Promoted; Release) { }
        //         actionref(Completed_Promoted; Completed) { }
        //     }
        // }
    }
    var
        NoSeriesMgmt: Codeunit "No. Series";
        ProdOrderStatusMgmt: Codeunit "Prod. Order Status Management";
        tempProdOrder: Record "Production Order" temporary;
        ProdOrder: Record "Production Order";
        ExtCompanySetup: Record "PMP07 Extended Company Setup";
        PMPCodesOWNINT: Record "PMP04 PMP Codes";
        RefreshProdOrder: Report "Refresh Production Order";
        ChangeStatusForm: Page "Change Status on Prod. Order";
        TarreWeight: Decimal;
        UoMCode: Code[10];
        // Status: Boolean;
        SORStep_Code: Code[50];
        CurrentStep: Integer;
        Status, NewStatus : Enum "Production Order Status";
        NewPostingDate: Date;
        NewUpdateUnitCost: Boolean;
        IsSetRecfromProdOrder: Boolean;

    trigger OnOpenPage()
    begin
        ExtCompanySetup.Get();
        if (ExtCompanySetup."PMP15 Sort-Prod. Order Nos." = '') OR (ExtCompanySetup."PMP15 SOR Location Code" = '') then begin
            Message('The "Sortation Prod. Order Nos." No Series or "SOR Location Code" in the Extended Company Setup is not defined. Please configure it before using Sortation - Prod. Order Creation or Recording.');
        end;
        // ============================================
        if not IsSetRecfromProdOrder then begin
            Rec.Init();
            Rec."PMP15 Item Owner Internal" := ExtCompanySetup."PMP15 SOR Item Owner Internal";
            Status := Status::"Firm Planned";
            Rec.Insert();
        end;
    end;

    trigger OnClosePage()
    begin
        Clear(IsSetRecfromProdOrder);
        Clear(Status);
    end;

    local procedure SimulateInsertSuccess(var tempProdOrderRec: Record "Production Order" temporary) IsInsertSuccess: Boolean
    begin
        tempProdOrderRec.DeleteAll();
        tempProdOrderRec.Reset();
        tempProdOrderRec.Init();
        tempProdOrderRec."No." := NoSeriesMgmt.PeekNextNo(ExtCompanySetup."PMP15 Sort-Prod. Order Nos.", WorkDate());
        tempProdOrderRec."No. Series" := ExtCompanySetup."PMP15 Sort-Prod. Order Nos.";
        tempProdOrderRec.Status := tempProdOrderRec.Status::"Firm Planned";
        tempProdOrderRec."Creation Date" := WorkDate();
        tempProdOrderRec."Last Date Modified" := WorkDate();
        tempProdOrderRec.Validate("Source Type", tempProdOrderRec."Source Type"::Item);
        tempProdOrderRec.Validate("Source No.", Rec."Sorted Item No.");
        tempProdOrderRec.Validate("Variant Code", Rec."Sorted Variant Code");
        tempProdOrderRec.Validate("Location Code", ExtCompanySetup."PMP15 SOR Location Code");
        tempProdOrderRec.Validate(Quantity, Rec.Quantity);
        // tempProdOrderRec.Validate("PMP15 RM Item No.", Rec."RM Item No.");
        // tempProdOrderRec.Validate("PMP15 RM Item Description", Rec."RM Item Description");
        // tempProdOrderRec.Validate("PMP15 RM Variant Code", Rec."RM Variant Code");
        tempProdOrderRec."PMP15 Lot No." := Rec."Lot No.";
        tempProdOrderRec."PMP15 Tarre Weight (Kg)" := Rec."Tarre Weight (Kg)";
        tempProdOrderRec."PMP15 Production Unit" := tempProdOrderRec."PMP15 Production Unit"::"SOR-Sortation";
        tempProdOrderRec."PMP15 SOR Rework" := Rec.Rework;
        tempProdOrderRec."PMP15 Reference No." := Rec."Reference No.";
        tempProdOrderRec."PMP04 Item Owner Internal" := ExtCompanySetup."PMP15 SOR Item Owner Internal";
        exit(tempProdOrderRec.Insert());

        // if tempProdOrder.Insert() then begin
        // Message('Nilai yang didapatkan untuk Prod. Order ialah: %1 | Status: %2 | Source No: %3 | Variant Code: %4 | Location Code: %5 | Qty: %6 | Lot No: %7 | Tarre Kgs: %8 | ProdUnit: %9 | SOR Rew: %10', tempProdOrder."No.", tempProdOrder.Status, tempProdOrder."Source No.", tempProdOrder."Variant Code", tempProdOrder."Location Code", tempProdOrder.Quantity, tempProdOrder."PMP15 Lot No.", tempProdOrder."PMP15 Tarre Weight (Kg)", tempProdOrder."PMP15 Production Unit", tempProdOrder."PMP15 SOR Rework", tempProdOrder."PMP15 Reference No.");
        // end;
    end;

    procedure SetProdOrder(var ProdOrderRec: Record "Production Order")
    begin
        ProdOrder := ProdOrderRec;
    end;

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
        // 
        Rec.Insert();
    end;
}
