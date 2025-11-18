page 60414 "PMP15 Sort-Prod.Ord Recording"
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
    Caption = 'Sortation Prod. Order Recording';
    PageType = NavigatePage;
    // PageType = Card;
    SourceTable = "PMP15 Sortation PO Recording";
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            group(Page01)
            {
                Caption = '';
                Visible = CurrentStep = 0;

                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = All;
                    Caption = 'Posting Date';
                    ToolTip = 'Specifies the value of the Posting Date Sortation Production Order Recording field.', Comment = '%';
                    Editable = false;
                }
                field("Sortation Prod. Order No."; Rec."Sortation Prod. Order No.")
                {
                    ApplicationArea = All;
                    Caption = 'Sortation Prod. Order. No.';
                    ToolTip = 'Specifies the value of the Sortation Prod. Order. No. field.', Comment = '%';
                    NotBlank = true;
                    ExtendedDatatype = Barcode;
                    Editable = true;
                    trigger OnLookup(var Text: Text): Boolean
                    var
                        SortationProdOrder: Record "Production Order";
                    begin
                        SortationProdOrder.Reset();
                        SortationProdOrder.SetRange("PMP04 Item Owner Internal", ExtCompanySetup."PMP15 SOR Item Owner Internal");
                        SortationProdOrder.SetRange("PMP15 Production Unit", SortationProdOrder."PMP15 Production Unit"::"SOR-Sortation");
                        if Page.RunModal(Page::"PMP15 Sort-Prod.Order List", SortationProdOrder) = Action::LookupOK then begin
                            Rec.Validate("Sortation Prod. Order No.", SortationProdOrder."No.");
                            SetProdOrder(SortationProdOrder);
                        end;
                    end;

                    trigger OnValidate()
                    var
                        SortationProdOrder: Record "Production Order";
                    begin
                        SortationProdOrder.Reset();
                        SortationProdOrder.SetRange("PMP04 Item Owner Internal", ExtCompanySetup."PMP15 SOR Item Owner Internal");
                        SortationProdOrder.SetRange("PMP15 Production Unit", SortationProdOrder."PMP15 Production Unit"::"SOR-Sortation");
                        SortationProdOrder.SetRange("No.", Rec."Sortation Prod. Order No.");
                        if SortationProdOrder.FindFirst() then begin
                            Rec.Validate("Sortation Prod. Order No.", SortationProdOrder."No.");
                            SetProdOrder(SortationProdOrder);
                        end;
                    end;
                }
                field("Lot No."; Rec."Lot No.")
                {
                    ApplicationArea = All;
                    Caption = 'Lot No.';
                    ToolTip = 'Specifies the value of the Lot No. field.', Comment = '%';
                    Editable = false;
                }
                field(Rework; Rec.Rework)
                {
                    ApplicationArea = All;
                    Caption = 'Rework';
                    ToolTip = 'Specifies the value of the Rework field.', Comment = '%';
                    Editable = false;
                }
                field("Work Shift Code"; Rec."Work Shift Code")
                {
                    ApplicationArea = All;
                    Caption = 'Work Shift Code';
                    ToolTip = 'Specifies the value of the Work Shift Code field.', Comment = '%';
                }
                field("Sortation Step"; Rec."Sortation Step")
                {
                    ApplicationArea = All;
                    Caption = 'Sortation Step';
                    ToolTip = 'Specifies the value of the Sortation Step field.', Comment = '%';
                    NotBlank = true;
                    trigger OnLookup(var Text: Text): Boolean
                    var
                        SORStepRec: Record "PMP15 Sortation Master Data";
                        BinRec: Record Bin;
                    begin
                        SORStepRec.Reset();
                        if Page.RunModal(Page::"PMP15 Sortation Step", SORStepRec) = Action::LookupOK then begin
                            SORStep_Step := SORStepRec.Step;
                            Rec."SORStep Step" := SORStepRec.Step;
                            SORStep_Code := SORStepRec.Code;
                            Rec."SORStep Code" := SORStepRec.Code;
                            if SORStep_Step = SORStep_Step::" " then begin
                                Rec."Sortation Step" := StrSubstNo('X-%1', SORStepRec.Code);
                            end else begin
                                Rec."Sortation Step" := StrSubstNo('%1-%2', SORStepRec.Step, SORStepRec.Code);
                            end;
                            BinRec.Reset();
                            BinRec.SetRange("PMP15 Bin Type", SORProdOrdMgmt.GetBinTypeBySortationStep(SORStep_Step));
                            if BinRec.FindFirst() then begin
                                Rec."From Bin Code" := BinRec."PMP15 Previous Bin";
                                Rec."To Bin Code" := BinRec.Code;
                            end;
                        end;
                        // CurrPage.Update(true);
                    end;
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    Caption = 'Location Code';
                    ToolTip = 'Specifies the value of the Location Code field.', Comment = '%';
                    Visible = false;
                    trigger OnLookup(var Text: Text): Boolean
                    var
                        LocationRec: Record Location;
                    begin
                        LocationRec.Reset();
                        if Page.RunModal(Page::"Location List", LocationRec) = Action::LookupOK then begin
                            Rec."Location Code" := LocationRec.Code;
                        end;
                    end;
                }
                // field("From Bin Code"; Rec."From Bin Code")
                // {
                //     ApplicationArea = All;
                //     Caption = 'From Bin Code';
                //     ToolTip = 'Specifies the value of the From Bin Code field.', Comment = '%';
                //     LookupPageId = "Bin List";
                //     trigger OnLookup(var Text: Text): Boolean
                //     var
                //         BinRec: Record Bin;
                //     begin
                //         BinRec.Reset();
                //         BinRec.SetRange("PMP15 Bin Type", SORProdOrdMgmt.GetBinTypeBySortationStep(SORStep_Step));
                //         if Page.RunModal(Page::"Bin List", BinRec) = Action::LookupOK then begin
                //             Rec."From Bin Code" := BinRec."PMP15 Previous Bin";
                //             Rec."To Bin Code" := BinRec.Code;
                //         end;
                //     end;
                // }
                // field("To Bin Code"; Rec."To Bin Code")
                // {
                //     ApplicationArea = All;
                //     Caption = 'To Bin Code';
                //     ToolTip = 'Specifies the value of the To Bin Code field.', Comment = '%';
                //     trigger OnLookup(var Text: Text): Boolean
                //     var
                //         BinRec: Record Bin;
                //     begin
                //         BinRec.Reset();
                //         BinRec.SetRange("PMP15 Bin Type", SORProdOrdMgmt.GetBinTypeBySortationStep(SORStep_Step));
                //         if Page.RunModal(Page::"Bin List", BinRec) = Action::LookupOK then begin
                //             Rec."From Bin Code" := BinRec."PMP15 Previous Bin";
                //             Rec."To Bin Code" := BinRec.Code;
                //         end;
                //     end;
                // }
                group(Result_STEP_0)
                {
                    Caption = 'Result';
                    Visible = SORStep_Step = SORStep_Step::"0";
                    field("Package No.0"; Rec."Package No.")
                    {
                        ApplicationArea = All;
                        Caption = 'Package No.';
                        ToolTip = 'Specifies the value of the Package No. field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            PkgNoRec: Record "Package No. Information";
                            BinContent: Record "Bin Content";
                        begin
                            PkgNoRec.Reset();
                            PkgNoRec.SetAutoCalcFields();
                            if SORStep_Step = SORStep_Step::"0" then begin
                                PkgNoRec.SetRange("Item No.", rec."Unsorted Item No.");
                                PkgNoRec.SetRange("Variant Code", Rec."Unsorted Variant Code");
                                PkgNoRec.SetFilter(Inventory, '>%1', 0);
                                PkgNoRec.SetRange("PMP04 Bin Code", Rec."To Bin Code");
                                if Page.RunModal(Page::"Package No. Information List", PkgNoRec) = Action::LookupOK then begin
                                    Rec."Package No." := PkgNoRec."Package No.";
                                    BinContent.Reset();
                                    BinContent.CalcFields("Quantity (Base)");
                                    if SORStep_Step = SORStep_Step::"0" then begin
                                        BinContent.SetRange("Item No.", Rec."Unsorted Item No.");
                                        BinContent.SetFilter("Variant Code", Rec."Unsorted Variant Code");
                                        BinContent.SetFilter("Quantity (Base)", '>%1', 0);
                                        BinContent.SetFilter("Bin Code", Rec."From Bin Code");
                                        // Filter Totals
                                        BinContent.SetFilter("Lot No. Filter", Rec."Lot No.");
                                        BinContent.SetFilter("Package No. Filter", Rec."Package No.");
                                        if BinContent.FindFirst() then begin
                                            BinContent.CalcFields("Quantity (Base)");
                                            Rec.Quantity := BinContent."Quantity (Base)";
                                        end;
                                    end else if SORStep_Step = SORStep_Step::"4" then begin
                                        exit; // most likely would be changed
                                    end;
                                end;
                            end;
                        end;

                        trigger OnValidate()
                        var
                            BinContent: Record "Bin Content";
                        begin
                            BinContent.Reset();
                            BinContent.CalcFields("Quantity (Base)");
                            if SORStep_Step = SORStep_Step::"0" then begin
                                BinContent.SetRange("Item No.", Rec."Unsorted Item No.");
                                BinContent.SetFilter("Variant Code", Rec."Unsorted Variant Code");
                                BinContent.SetFilter("Quantity (Base)", '>%1', 0);
                                BinContent.SetFilter("Bin Code", Rec."From Bin Code");
                                // Filter Totals
                                BinContent.SetFilter("Lot No. Filter", Rec."Lot No.");
                                BinContent.SetFilter("Package No. Filter", Rec."Package No.");
                                if BinContent.FindFirst() then begin
                                    BinContent.CalcFields("Quantity (Base)");
                                    Rec.Quantity := BinContent."Quantity (Base)";
                                end;
                            end else if SORStep_Step = SORStep_Step::"4" then begin
                                exit; // most likely would be changed
                            end;
                        end;
                    }
                    field("Submerk 10"; Rec."Submerk 1")
                    {
                        ApplicationArea = All;
                        Caption = 'Submerk 1';
                        ToolTip = 'Specifies the value of the Submerk 1 field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            Submerk1: Record "PMP15 Sub Merk 1";
                        begin
                            Submerk1.Reset();
                            Submerk1.SetRange("Item Owner Internal", ExtCompanySetup."PMP15 SOR Item Owner Internal");
                            if Page.RunModal(Page::"PMP15 Sub Merk 1", Submerk1) = Action::LookupOK then begin
                                Rec."Submerk 1" := Submerk1.Code;
                            end;
                        end;
                    }
                    field("L/R0"; Rec."L/R")
                    {
                        ApplicationArea = All;
                        Caption = 'L/R';
                        ToolTip = 'Specifies the value of the L/R field.', Comment = '%';
                    }
                    field("Variant Changes0"; Rec."Variant Changes")
                    {
                        ApplicationArea = All;
                        Caption = 'Variant Changes';
                        ToolTip = 'Specifies the value of the Variant Changes field.', Comment = '%';
                    }
                    field("Return to Result Step0"; Rec."Return to Result Step")
                    {
                        ApplicationArea = All;
                        Caption = 'Return to Result Step';
                        ToolTip = 'Specifies the value of the Return to Result Step field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            SORStepRec: Record "PMP15 Sortation Master Data";
                            BinRec: Record Bin;
                        begin
                            SORStepRec.Reset();
                            if Page.RunModal(Page::"PMP15 Sortation Step", SORStepRec) = Action::LookupOK then begin
                                ReturnSORStep_Step := SORStepRec.Step;
                                ReturnSORStep_Code := SORStepRec.Code;
                                Rec."SORStep Return Step" := SORStepRec.Step;
                                Rec."SORStep Return Code" := SORStepRec.Code;
                                Rec."Return to Result Step" := StrSubstNo('%1-%2', SORStepRec.Step, SORStepRec.Code);
                                BinRec.Reset();
                                BinRec.SetRange("PMP15 Bin Type", SORProdOrdMgmt.GetBinTypeBySortationStep(ReturnSORStep_Step));
                                if BinRec.FindFirst() then begin
                                    Rec."To Bin Code" := BinRec.Code;
                                end;
                                BinRec.SetRange("PMP15 Bin Type", SORProdOrdMgmt.GetBinTypeBySortationStep(SORStep_Step));
                                if BinRec.FindFirst() then begin
                                    Rec."From Bin Code" := BinRec.Code;
                                end;
                            end;
                        end;
                    }
                    field(Quantity0; Rec.Quantity)
                    {
                        ApplicationArea = All;
                        Caption = 'Quantity';
                        ToolTip = 'Specifies the value of the Quantity field.', Comment = '%';
                    }
                    field("Unit of Measure Code0"; Rec."Unit of Measure Code")
                    {
                        ApplicationArea = All;
                        Caption = 'Unit of Measure Code';
                        ToolTip = 'Specifies the value of the Unit of Measure Code field.', Comment = '%';
                    }
                } // STEP 0
                group(Result_STEP_1)
                {
                    Caption = 'Result';
                    Visible = SORStep_Step = SORStep_Step::"1";
                    field("Tobacco Type1"; Rec."Tobacco Type")
                    {
                        ApplicationArea = All;
                        Caption = 'Tobacco Type';
                        ToolTip = 'Specifies the value of the Tobacco Type field.', Comment = '%';
                        NotBlank = true;
                        trigger OnValidate()
                        var
                            Bins: Record Bin;
                        begin
                            Bins.Reset();
                            if (SORStep_Step <> SORStep_Step::"4") AND (Rec."Tobacco Type" = Rec."Tobacco Type"::Filler) then begin
                                Bins.SetRange("Location Code", Rec."Location Code");
                                Bins.SetRange("PMP15 Bin Type", Bins."PMP15 Bin Type"::Filler);
                                if Bins.FindFirst() then begin
                                    Rec."To Bin Code" := Bins.Code;
                                end;
                            end;
                            if (SORStep_Step = SORStep_Step::"4") AND (Rec."Tobacco Type" = Rec."Tobacco Type"::Filler) then begin
                                Bins.SetRange("Location Code", Rec."Location Code");
                                Bins.SetRange("PMP15 Bin Type", Bins."PMP15 Bin Type"::Filler);
                                if Bins.FindFirst() then begin
                                    Rec."From Bin Code" := Bins.Code;
                                end;
                            end;
                        end;
                    }
                    field("Submerk 11"; Rec."Submerk 1")
                    {
                        ApplicationArea = All;
                        Caption = 'Submerk 1';
                        ToolTip = 'Specifies the value of the Submerk 1 field.', Comment = '%';
                        // Visible = (SORStep_Step = SORStep_Step::"0") OR (SORStep_Step = SORStep_Step::"1") OR (SORStep_Step = SORStep_Step::"2") OR (SORStep_Step = SORStep_Step::"3") OR (SORStep_Step = SORStep_Step::"4");
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            Submerk1: Record "PMP15 Sub Merk 1";
                        begin
                            Submerk1.Reset();
                            Submerk1.SetRange("Item Owner Internal", ExtCompanySetup."PMP15 SOR Item Owner Internal");
                            if Page.RunModal(Page::"PMP15 Sub Merk 1", Submerk1) = Action::LookupOK then begin
                                Rec."Submerk 1" := Submerk1.Code;
                            end;
                        end;
                    }
                    field("L/R1"; Rec."L/R")
                    {
                        ApplicationArea = All;
                        Caption = 'L/R';
                        ToolTip = 'Specifies the value of the L/R field.', Comment = '%';
                    }
                    field("Variant Changes1"; Rec."Variant Changes")
                    {
                        ApplicationArea = All;
                        Caption = 'Variant Changes';
                        ToolTip = 'Specifies the value of the Variant Changes field.', Comment = '%';
                        // Visible = SORStep_Step = SORStep_Step::"4";
                    }
                    field("Return to Result Step1"; Rec."Return to Result Step")
                    {
                        ApplicationArea = All;
                        Caption = 'Return to Result Step';
                        ToolTip = 'Specifies the value of the Return to Result Step field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            SORStepRec: Record "PMP15 Sortation Master Data";
                            BinRec: Record Bin;
                        begin
                            SORStepRec.Reset();
                            if Page.RunModal(Page::"PMP15 Sortation Step", SORStepRec) = Action::LookupOK then begin
                                ReturnSORStep_Step := SORStepRec.Step;
                                ReturnSORStep_Code := SORStepRec.Code;
                                Rec."SORStep Return Step" := SORStepRec.Step;
                                Rec."SORStep Return Code" := SORStepRec.Code;
                                Rec."Return to Result Step" := StrSubstNo('%1-%2', SORStepRec.Step, SORStepRec.Code);
                                BinRec.Reset();
                                BinRec.SetRange("PMP15 Bin Type", SORProdOrdMgmt.GetBinTypeBySortationStep(ReturnSORStep_Step));
                                if BinRec.FindFirst() then begin
                                    Rec."To Bin Code" := BinRec.Code;
                                end;
                                BinRec.SetRange("PMP15 Bin Type", SORProdOrdMgmt.GetBinTypeBySortationStep(SORStep_Step));
                                if BinRec.FindFirst() then begin
                                    Rec."From Bin Code" := BinRec.Code;
                                end;
                            end;
                        end;
                    }
                    field(Quantity1; Rec.Quantity)
                    {
                        ApplicationArea = All;
                        Caption = 'Quantity';
                        ToolTip = 'Specifies the value of the Quantity field.', Comment = '%';
                    }
                    field("Unit of Measure Code1"; Rec."Unit of Measure Code")
                    {
                        ApplicationArea = All;
                        Caption = 'Unit of Measure Code';
                        ToolTip = 'Specifies the value of the Unit of Measure Code field.', Comment = '%';
                    }
                } // STEP 1
                group(Result_STEP_2)
                {
                    Caption = 'Result';
                    Visible = SORStep_Step = SORStep_Step::"2";
                    field("Tobacco Type2"; Rec."Tobacco Type")
                    {
                        ApplicationArea = All;
                        Caption = 'Tobacco Type';
                        ToolTip = 'Specifies the value of the Tobacco Type field.', Comment = '%';
                        NotBlank = true;
                        trigger OnValidate()
                        var
                            Bins: Record Bin;
                        begin
                            Bins.Reset();
                            if (SORStep_Step <> SORStep_Step::"4") AND (Rec."Tobacco Type" = Rec."Tobacco Type"::Filler) then begin
                                Bins.SetRange("Location Code", Rec."Location Code");
                                Bins.SetRange("PMP15 Bin Type", Bins."PMP15 Bin Type"::Filler);
                                if Bins.FindFirst() then begin
                                    Rec."To Bin Code" := Bins.Code;
                                end;
                            end;
                            if (SORStep_Step = SORStep_Step::"4") AND (Rec."Tobacco Type" = Rec."Tobacco Type"::Filler) then begin
                                Bins.SetRange("Location Code", Rec."Location Code");
                                Bins.SetRange("PMP15 Bin Type", Bins."PMP15 Bin Type"::Filler);
                                if Bins.FindFirst() then begin
                                    Rec."From Bin Code" := Bins.Code;
                                end;
                            end;
                        end;
                    }
                    field("Submerk 12"; Rec."Submerk 1")
                    {
                        ApplicationArea = All;
                        Caption = 'Submerk 1';
                        ToolTip = 'Specifies the value of the Submerk 1 field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            Submerk1: Record "PMP15 Sub Merk 1";
                        begin
                            Submerk1.Reset();
                            Submerk1.SetRange("Item Owner Internal", ExtCompanySetup."PMP15 SOR Item Owner Internal");
                            if Page.RunModal(Page::"PMP15 Sub Merk 1", Submerk1) = Action::LookupOK then begin
                                Rec."Submerk 1" := Submerk1.Code;
                            end;
                        end;
                    }
                    field("Submerk 22"; Rec."Submerk 2")
                    {
                        ApplicationArea = All;
                        Caption = 'Submerk 2';
                        ToolTip = 'Specifies the value of the Submerk 2 field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            Submerk2: Record "PMP15 Sub Merk 2";
                        begin
                            Submerk2.Reset();
                            Submerk2.SetRange("Item Owner Internal", ExtCompanySetup."PMP15 SOR Item Owner Internal");
                            if Page.RunModal(Page::"PMP15 Sub Merk 2", Submerk2) = Action::LookupOK then begin
                                Rec."Submerk 2" := Submerk2.Code;
                            end;
                        end;
                    }
                    field("L/R2"; Rec."L/R")
                    {
                        ApplicationArea = All;
                        Caption = 'L/R';
                        ToolTip = 'Specifies the value of the L/R field.', Comment = '%';
                    }
                    field("Variant Changes2"; Rec."Variant Changes")
                    {
                        ApplicationArea = All;
                        Caption = 'Variant Changes';
                        ToolTip = 'Specifies the value of the Variant Changes field.', Comment = '%';
                    }
                    field("Return to Result Step2"; Rec."Return to Result Step")
                    {
                        ApplicationArea = All;
                        Caption = 'Return to Result Step';
                        ToolTip = 'Specifies the value of the Return to Result Step field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            SORStepRec: Record "PMP15 Sortation Master Data";
                            BinRec: Record Bin;
                        begin
                            SORStepRec.Reset();
                            if Page.RunModal(Page::"PMP15 Sortation Step", SORStepRec) = Action::LookupOK then begin
                                ReturnSORStep_Step := SORStepRec.Step;
                                ReturnSORStep_Code := SORStepRec.Code;
                                Rec."SORStep Return Step" := SORStepRec.Step;
                                Rec."SORStep Return Code" := SORStepRec.Code;
                                Rec."Return to Result Step" := StrSubstNo('%1-%2', SORStepRec.Step, SORStepRec.Code);
                                BinRec.Reset();
                                BinRec.SetRange("PMP15 Bin Type", SORProdOrdMgmt.GetBinTypeBySortationStep(ReturnSORStep_Step));
                                if BinRec.FindFirst() then begin
                                    Rec."To Bin Code" := BinRec.Code;
                                end;
                                BinRec.SetRange("PMP15 Bin Type", SORProdOrdMgmt.GetBinTypeBySortationStep(SORStep_Step));
                                if BinRec.FindFirst() then begin
                                    Rec."From Bin Code" := BinRec.Code;
                                end;
                            end;
                        end;
                    }
                    field(Quantity2; Rec.Quantity)
                    {
                        ApplicationArea = All;
                        Caption = 'Quantity';
                        ToolTip = 'Specifies the value of the Quantity field.', Comment = '%';
                    }
                    field("Unit of Measure Code2"; Rec."Unit of Measure Code")
                    {
                        ApplicationArea = All;
                        Caption = 'Unit of Measure Code';
                        ToolTip = 'Specifies the value of the Unit of Measure Code field.', Comment = '%';
                    }
                } // STEP 2
                group(Result_STEP_3)
                {
                    Caption = 'Result';
                    Visible = SORStep_Step = SORStep_Step::"3";
                    field("Tobacco Type3"; Rec."Tobacco Type")
                    {
                        ApplicationArea = All;
                        Caption = 'Tobacco Type';
                        ToolTip = 'Specifies the value of the Tobacco Type field.', Comment = '%';
                        NotBlank = true;
                        trigger OnValidate()
                        var
                            Bins: Record Bin;
                        begin
                            Bins.Reset();
                            if (SORStep_Step <> SORStep_Step::"4") AND (Rec."Tobacco Type" = Rec."Tobacco Type"::Filler) then begin
                                Bins.SetRange("Location Code", Rec."Location Code");
                                Bins.SetRange("PMP15 Bin Type", Bins."PMP15 Bin Type"::Filler);
                                if Bins.FindFirst() then begin
                                    Rec."To Bin Code" := Bins.Code;
                                end;
                            end;
                            if (SORStep_Step = SORStep_Step::"4") AND (Rec."Tobacco Type" = Rec."Tobacco Type"::Filler) then begin
                                Bins.SetRange("Location Code", Rec."Location Code");
                                Bins.SetRange("PMP15 Bin Type", Bins."PMP15 Bin Type"::Filler);
                                if Bins.FindFirst() then begin
                                    Rec."From Bin Code" := Bins.Code;
                                end;
                            end;
                        end;
                    }
                    field("Submerk 13"; Rec."Submerk 1")
                    {
                        ApplicationArea = All;
                        Caption = 'Submerk 1';
                        ToolTip = 'Specifies the value of the Submerk 1 field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            Submerk1: Record "PMP15 Sub Merk 1";
                        begin
                            Submerk1.Reset();
                            Submerk1.SetRange("Item Owner Internal", ExtCompanySetup."PMP15 SOR Item Owner Internal");
                            if Page.RunModal(Page::"PMP15 Sub Merk 1", Submerk1) = Action::LookupOK then begin
                                Rec."Submerk 1" := Submerk1.Code;
                            end;
                        end;
                    }
                    field("Submerk 23"; Rec."Submerk 2")
                    {
                        ApplicationArea = All;
                        Caption = 'Submerk 2';
                        ToolTip = 'Specifies the value of the Submerk 2 field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            Submerk2: Record "PMP15 Sub Merk 2";
                        begin
                            Submerk2.Reset();
                            Submerk2.SetRange("Item Owner Internal", ExtCompanySetup."PMP15 SOR Item Owner Internal");
                            if Page.RunModal(Page::"PMP15 Sub Merk 2", Submerk2) = Action::LookupOK then begin
                                Rec."Submerk 2" := Submerk2.Code;
                            end;
                        end;
                    }
                    field("Submerk 33"; Rec."Submerk 3")
                    {
                        ApplicationArea = All;
                        Caption = 'Submerk 3';
                        ToolTip = 'Specifies the value of the Submerk 3 field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            Submerk3: Record "PMP15 Sub Merk 3";
                        begin
                            Submerk3.Reset();
                            Submerk3.SetRange("Item Owner Internal", ExtCompanySetup."PMP15 SOR Item Owner Internal");
                            if Page.RunModal(Page::"PMP15 Sub Merk 3", Submerk3) = Action::LookupOK then begin
                                Rec."Submerk 3" := Submerk3.Code;
                            end;
                        end;
                    }
                    field("Submerk 43"; Rec."Submerk 4")
                    {
                        ApplicationArea = All;
                        Caption = 'Submerk 4';
                        ToolTip = 'Specifies the value of the Submerk 4 field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            Submerk4: Record "PMP15 Sub Merk 4";
                        begin
                            Submerk4.Reset();
                            Submerk4.SetRange("Item Owner Internal", ExtCompanySetup."PMP15 SOR Item Owner Internal");
                            if Page.RunModal(Page::"PMP15 Sub Merk 4", Submerk4) = Action::LookupOK then begin
                                Rec."Submerk 4" := Submerk4.Code;
                            end;
                        end;
                    }
                    field("Submerk 53"; Rec."Submerk 5")
                    {
                        ApplicationArea = All;
                        Caption = 'Submerk 5';
                        ToolTip = 'Specifies the value of the Submerk 5 field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            Submerk5: Record "PMP15 Sub Merk 5";
                        begin
                            Submerk5.Reset();
                            Submerk5.SetRange("Item Owner Internal", ExtCompanySetup."PMP15 SOR Item Owner Internal");
                            if Page.RunModal(Page::"PMP15 Sub Merk 5", Submerk5) = Action::LookupOK then begin
                                Rec."Submerk 5" := Submerk5.Code;
                            end;
                        end;
                    }
                    field("L/R3"; Rec."L/R")
                    {
                        ApplicationArea = All;
                        Caption = 'L/R';
                        ToolTip = 'Specifies the value of the L/R field.', Comment = '%';
                    }
                    field("Variant Changes3"; Rec."Variant Changes")
                    {
                        ApplicationArea = All;
                        Caption = 'Variant Changes';
                        ToolTip = 'Specifies the value of the Variant Changes field.', Comment = '%';
                    }
                    field("Return to Result Step3"; Rec."Return to Result Step")
                    {
                        ApplicationArea = All;
                        Caption = 'Return to Result Step';
                        ToolTip = 'Specifies the value of the Return to Result Step field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            SORStepRec: Record "PMP15 Sortation Master Data";
                            BinRec: Record Bin;
                        begin
                            SORStepRec.Reset();
                            if Page.RunModal(Page::"PMP15 Sortation Step", SORStepRec) = Action::LookupOK then begin
                                ReturnSORStep_Step := SORStepRec.Step;
                                ReturnSORStep_Code := SORStepRec.Code;
                                Rec."SORStep Return Step" := SORStepRec.Step;
                                Rec."SORStep Return Code" := SORStepRec.Code;
                                Rec."Return to Result Step" := StrSubstNo('%1-%2', SORStepRec.Step, SORStepRec.Code);
                                BinRec.Reset();
                                BinRec.SetRange("PMP15 Bin Type", SORProdOrdMgmt.GetBinTypeBySortationStep(ReturnSORStep_Step));
                                if BinRec.FindFirst() then begin
                                    Rec."To Bin Code" := BinRec.Code;
                                end;
                                BinRec.SetRange("PMP15 Bin Type", SORProdOrdMgmt.GetBinTypeBySortationStep(SORStep_Step));
                                if BinRec.FindFirst() then begin
                                    Rec."From Bin Code" := BinRec.Code;
                                end;
                            end;
                        end;
                    }
                    field(Quantity3; Rec.Quantity)
                    {
                        ApplicationArea = All;
                        Caption = 'Quantity';
                        ToolTip = 'Specifies the value of the Quantity field.', Comment = '%';
                    }
                    field("Unit of Measure Code3"; Rec."Unit of Measure Code")
                    {
                        ApplicationArea = All;
                        Caption = 'Unit of Measure Code';
                        ToolTip = 'Specifies the value of the Unit of Measure Code field.', Comment = '%';
                    }
                } // STEP 3
                group(Result_STEP_4)
                {
                    Caption = 'Result';
                    Visible = SORStep_Step = SORStep_Step::"4";
                    field("Tobacco Type4"; Rec."Tobacco Type")
                    {
                        ApplicationArea = All;
                        Caption = 'Tobacco Type';
                        ToolTip = 'Specifies the value of the Tobacco Type field.', Comment = '%';
                        NotBlank = true;
                        trigger OnValidate()
                        var
                            Bins: Record Bin;
                        begin
                            Bins.Reset();
                            if (SORStep_Step <> SORStep_Step::"4") AND (Rec."Tobacco Type" = Rec."Tobacco Type"::Filler) then begin
                                Bins.SetRange("Location Code", Rec."Location Code");
                                Bins.SetRange("PMP15 Bin Type", Bins."PMP15 Bin Type"::Filler);
                                if Bins.FindFirst() then begin
                                    Rec."To Bin Code" := Bins.Code;
                                end;
                            end;
                            if (SORStep_Step = SORStep_Step::"4") AND (Rec."Tobacco Type" = Rec."Tobacco Type"::Filler) then begin
                                Bins.SetRange("Location Code", Rec."Location Code");
                                Bins.SetRange("PMP15 Bin Type", Bins."PMP15 Bin Type"::Filler);
                                if Bins.FindFirst() then begin
                                    Rec."From Bin Code" := Bins.Code;
                                end;
                            end;
                        end;
                    }
                    field("Submerk 14"; Rec."Submerk 1")
                    {
                        ApplicationArea = All;
                        Caption = 'Submerk 1';
                        ToolTip = 'Specifies the value of the Submerk 1 field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            Submerk1: Record "PMP15 Sub Merk 1";
                        begin
                            Submerk1.Reset();
                            Submerk1.SetRange("Item Owner Internal", ExtCompanySetup."PMP15 SOR Item Owner Internal");
                            if Page.RunModal(Page::"PMP15 Sub Merk 1", Submerk1) = Action::LookupOK then begin
                                Rec."Submerk 1" := Submerk1.Code;
                            end;
                        end;
                    }
                    field("Submerk 24"; Rec."Submerk 2")
                    {
                        ApplicationArea = All;
                        Caption = 'Submerk 2';
                        ToolTip = 'Specifies the value of the Submerk 2 field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            Submerk2: Record "PMP15 Sub Merk 2";
                        begin
                            Submerk2.Reset();
                            Submerk2.SetRange("Item Owner Internal", ExtCompanySetup."PMP15 SOR Item Owner Internal");
                            if Page.RunModal(Page::"PMP15 Sub Merk 2", Submerk2) = Action::LookupOK then begin
                                Rec."Submerk 2" := Submerk2.Code;
                            end;
                        end;
                    }
                    field("Submerk 34"; Rec."Submerk 3")
                    {
                        ApplicationArea = All;
                        Caption = 'Submerk 3';
                        ToolTip = 'Specifies the value of the Submerk 3 field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            Submerk3: Record "PMP15 Sub Merk 3";
                        begin
                            Submerk3.Reset();
                            Submerk3.SetRange("Item Owner Internal", ExtCompanySetup."PMP15 SOR Item Owner Internal");
                            if Page.RunModal(Page::"PMP15 Sub Merk 3", Submerk3) = Action::LookupOK then begin
                                Rec."Submerk 3" := Submerk3.Code;
                            end;
                        end;
                    }
                    field("Submerk 44"; Rec."Submerk 4")
                    {
                        ApplicationArea = All;
                        Caption = 'Submerk 4';
                        ToolTip = 'Specifies the value of the Submerk 4 field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            Submerk4: Record "PMP15 Sub Merk 4";
                        begin
                            Submerk4.Reset();
                            Submerk4.SetRange("Item Owner Internal", ExtCompanySetup."PMP15 SOR Item Owner Internal");
                            if Page.RunModal(Page::"PMP15 Sub Merk 4", Submerk4) = Action::LookupOK then begin
                                Rec."Submerk 4" := Submerk4.Code;
                            end;
                        end;
                    }
                    field("Submerk 54"; Rec."Submerk 5")
                    {
                        ApplicationArea = All;
                        Caption = 'Submerk 5';
                        ToolTip = 'Specifies the value of the Submerk 5 field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            Submerk5: Record "PMP15 Sub Merk 5";
                        begin
                            Submerk5.Reset();
                            Submerk5.SetRange("Item Owner Internal", ExtCompanySetup."PMP15 SOR Item Owner Internal");
                            if Page.RunModal(Page::"PMP15 Sub Merk 5", Submerk5) = Action::LookupOK then begin
                                Rec."Submerk 5" := Submerk5.Code;
                            end;
                        end;
                    }
                    field("Package No.4"; Rec."Package No.")
                    {
                        ApplicationArea = All;
                        Caption = 'Package No.';
                        ToolTip = 'Specifies the value of the Package No. field.', Comment = '%';
                        trigger OnValidate()
                        var
                            BinContent: Record "Bin Content";
                        begin
                            BinContent.Reset();
                            BinContent.SetAutoCalcFields();
                            BinContent.SetRange("Item No.", Rec."Unsorted Item No.");
                            BinContent.SetFilter("Variant Code", Rec."Unsorted Variant Code");
                            BinContent.SetFilter("Quantity (Base)", '>%1', 0);
                            BinContent.SetFilter("Bin Code", Rec."From Bin Code");
                            // Filter Totals
                            BinContent.SetFilter("Lot No. Filter", Rec."Lot No.");
                            BinContent.SetFilter("Package No. Filter", Rec."Package No.");
                            if BinContent.FindFirst() then begin
                                BinContent.CalcFields("Quantity (Base)");
                                Rec.Quantity := BinContent."Quantity (Base)";
                            end;
                        end;
                    }
                    field("L/R4"; Rec."L/R")
                    {
                        ApplicationArea = All;
                        Caption = 'L/R';
                        ToolTip = 'Specifies the value of the L/R field.', Comment = '%';
                    }
                    field("Variant Changes4"; Rec."Variant Changes")
                    {
                        ApplicationArea = All;
                        Caption = 'Variant Changes';
                        ToolTip = 'Specifies the value of the Variant Changes field.', Comment = '%';
                    }
                    field("Return to Result Step4"; Rec."Return to Result Step")
                    {
                        ApplicationArea = All;
                        Caption = 'Return to Result Step';
                        ToolTip = 'Specifies the value of the Return to Result Step field.', Comment = '%';
                        trigger OnLookup(var Text: Text): Boolean
                        var
                            SORStepRec: Record "PMP15 Sortation Master Data";
                            BinRec: Record Bin;
                        begin
                            SORStepRec.Reset();
                            if Page.RunModal(Page::"PMP15 Sortation Step", SORStepRec) = Action::LookupOK then begin
                                ReturnSORStep_Step := SORStepRec.Step;
                                ReturnSORStep_Code := SORStepRec.Code;
                                Rec."SORStep Return Step" := SORStepRec.Step;
                                Rec."SORStep Return Code" := SORStepRec.Code;
                                Rec."Return to Result Step" := StrSubstNo('%1-%2', SORStepRec.Step, SORStepRec.Code);
                                BinRec.Reset();
                                BinRec.SetRange("PMP15 Bin Type", SORProdOrdMgmt.GetBinTypeBySortationStep(ReturnSORStep_Step));
                                if BinRec.FindFirst() then begin
                                    Rec."To Bin Code" := BinRec.Code;
                                end;
                                BinRec.SetRange("PMP15 Bin Type", SORProdOrdMgmt.GetBinTypeBySortationStep(SORStep_Step));
                                if BinRec.FindFirst() then begin
                                    Rec."From Bin Code" := BinRec.Code;
                                end;
                            end;
                        end;
                    }
                    field(Quantity4; Rec.Quantity)
                    {
                        ApplicationArea = All;
                        Caption = 'Quantity';
                        ToolTip = 'Specifies the value of the Quantity field.', Comment = '%';
                    }
                    field("Unit of Measure Code4"; Rec."Unit of Measure Code")
                    {
                        ApplicationArea = All;
                        Caption = 'Unit of Measure Code';
                        ToolTip = 'Specifies the value of the Unit of Measure Code field.', Comment = '%';
                    }
                } // STEP 3
            }
        }
    }
    actions
    {
        area(Navigation)
        {
            action(Post)
            {
                ApplicationArea = All;
                Caption = 'P&ost';
                Image = Post;
                InFooterBar = true;
                Visible = (SORStep_Step <> SORStep_Step::"4");
                trigger OnAction()
                begin
                    ValidateInputBeforePosting();
                    SORProdOrdMgmt.SortProdOrdRecordingPost(ProdOrder, Rec, SORStep_Step);
                    ResetFields();
                end;
            }
            action("Post & Print")
            {
                // UNDER DESIGN & DEVELOPMENT, STATUS WAITING APP.
                ApplicationArea = All;
                Caption = 'Post & Print';
                Image = PostPrint;
                InFooterBar = true;
                Visible = (SORStep_Step = SORStep_Step::"4");
                trigger OnAction()
                begin
                    ValidateInputBeforePosting();
                    SORProdOrdMgmt.SortProdOrdRecordingPost(ProdOrder, Rec, SORStep_Step);
                    ResetFields();
                end;
            }
        }
    }
    var
        ProdOrder: Record "Production Order";
        ProdOrderLine: Record "Prod. Order Line";
        ExtCompanySetup: Record "PMP07 Extended Company Setup";
        SORStep_Step, ReturnSORStep_Step : Enum "PMP15 Sortation Step Enum";
        SORProdOrdMgmt: Codeunit "PMP15 Sortation PO Mgmt";
        PMPAppLogicMgmt: Codeunit "PMP02 App Logic Management";
        SORStep_Code, ReturnSORStep_Code : Code[50];
        CurrentStep: Integer;
        IsSetRecfromProdOrder: Boolean;

    trigger OnOpenPage()
    begin
        SORStep_Step := SORStep_Step::"0";
        Clear(SORStep_Code);
        ExtCompanySetup.Get();
        PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Item Owner Internal"));

        if IsSetRecfromProdOrder then begin
            Rec.Init();
            Rec."Posting Date" := WorkDate();
            Rec.Validate("Sortation Prod. Order No.", ProdOrder."No.");
            ProdOrderLine.Reset();
            ProdOrderLine.SetRange("Prod. Order No.", ProdOrder."No.");
            ProdOrderLine.SetFilter("Item No.", '<>%1', '');
            if ProdOrderLine.FindFirst() then begin
                Rec."Unit of Measure Code" := ProdOrderLine."Unit of Measure Code";
            end;
            Rec.Insert();
        end else begin
            Rec.Init();
            Rec."Posting Date" := WorkDate();
            Rec.Insert();
        end;
    end;

    trigger OnClosePage()
    begin
        Clear(IsSetRecfromProdOrder);
    end;

    procedure SetProdOrder(var ProdOrderRec: Record "Production Order")
    begin
        ProdOrder := ProdOrderRec;
        IsSetRecfromProdOrder := true;
    end;

    local procedure ResetFields()
    begin
        Rec."Posting Date" := WorkDate();
        Rec."Tobacco Type" := Rec."Tobacco Type"::" ";
        Rec."Submerk 1" := '';
        Rec."Submerk 2" := '';
        Rec."Submerk 3" := '';
        Rec."Submerk 4" := '';
        Rec."Submerk 5" := '';
        Rec."L/R" := Rec."L/R"::" ";
        Rec."Variant Changes" := '';
        Rec."Return to Result Step" := '';
        Rec.Quantity := 0;
        //         Remarks:
        // When user click post, then the Sortation Prod.Order Recording not close but will reset a few field:
        // 1. If previous post, Sortation Step = 4 & the Package No. = Blank then after post fill the Package No.same as Package No.that creates when posting
        // 2. Reset Tobacco Type, Sub Merk 1, Sub Merk 2, Sub Merk 3, Sub Merk 4, Sub Merk 5, L / R, Variant Changes, Return to Result Step, Quantity to blank
    end;

    local procedure ValidateInputBeforePosting()
    var
        ErrInfo: ErrorInfo;
    begin
        ExtCompanySetup.Get();
        if Rec."Sortation Step" = '' then begin
            Error('Sortation Step must be specified before posting.');
        end;

        if (Rec."Tobacco Type" = Rec."Tobacco Type"::" ") AND ((SORStep_Step = SORStep_Step::"1") OR (SORStep_Step = SORStep_Step::"2") OR (SORStep_Step = SORStep_Step::"3") OR (SORStep_Step = SORStep_Step::"4")) then begin
            Error('Tobacco Type must be specified before posting.');
        end;

        PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Location Code"));
        if (SORStep_Step = SORStep_Step::"0") then begin
            PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Assembly Order Nos"));
        end;

        if (ExtCompanySetup."PMP15SORItemReclass.Jnl.Tmpt." = '') AND ((SORStep_Step = SORStep_Step::"1") OR ((SORStep_Step = SORStep_Step::"2")) OR (SORStep_Step = SORStep_Step::"3")) then begin
            PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15SORItemReclass.Jnl.Batch"));
        end;

        if (SORStep_Step = SORStep_Step::"4") then begin
            PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Output Jnl. Template"));
            PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Output Jnl. Batch"));
            PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Consum.Jnl. Template"));
            PMPAppLogicMgmt.ValidateExtendedCompanySetupwithAction(ExtCompanySetup.FieldNo("PMP15 SOR Consum.Jnl. Batch"));
        end;
    end;
}
